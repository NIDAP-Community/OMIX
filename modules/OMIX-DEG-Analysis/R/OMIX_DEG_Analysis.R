#' OMIX bulk RNA-seq differential-expression analysis from raw counts
#'
#' @description
#' A raw-count implementation based on the model-selection approach in
#' `Limma_Analysis_v41.R`. It performs design-aware filtering, edgeR TMM
#' normalisation, and limma-voom modelling before choosing either a standard
#' linear model or a repeated-measures model with `duplicateCorrelation`.
#'
#' The differential-expression model is always fitted to voom expression with
#' all requested covariates. The sample-expression block appended to the right
#' side of the returned DEG table is intended for downstream analysis. When
#' requested and estimable, it has donor and/or technical-batch effects removed
#' while preserving the biological comparison groups.
#'
#' @param Dataset Data frame containing one gene identifier column and raw
#'   integer-like RNA-seq count columns.
#' @param Metadata_Table Sample-level metadata table.
#' @param sample_names_column Metadata column containing sample identifiers.
#' @param samples_to_include Count-matrix sample columns to analyse.
#' @param gene_names_column Dataset column containing gene identifiers.
#' @param contrast_variable_columns One or two metadata columns defining the
#'   comparison groups.
#' @param contrasts Character vector of requested contrasts, for example
#'   `"Treatment-Control"` or `"Treatment.Responder-Control.Responder"`.
#' @param covariate_columns Optional metadata columns included in the
#'   differential-expression model as fixed effects.
#' @param donor_variable_column Optional donor/patient metadata column. When
#'   supplied, a repeated-measures model is fit using `duplicateCorrelation`.
#' @param batch_effect_columns Optional technical batch columns. They are added
#'   to the DE model and removed from the downstream expression values.
#' @param filter_low_expression Apply `edgeR::filterByExpr()` using the
#'   biological group design. Default: `TRUE`.
#' @param normalization_method Combined normalization profile. `"TMM"` is the
#'   default. The recommended alternative order is `"Quantile"`, then
#'   `"TMM + Quantile"`; other supported profiles are
#'   `"TMM + Scale"`, `"TMM + Cyclic Loess"`, `"TMMwsp"`, `"RLE"`, and
#'   `"Upper Quartile"`.
#' @param normalization_diagnostics Write before-and-after normalization
#'   diagnostics when `diagnostics_output_dir` is supplied. The diagnostics
#'   include boxplots and density plots of filtered log-CPM values before
#'   library-size normalization and after voom processing, plus the voom
#'   mean-variance trend used to estimate precision weights. Default: `FALSE`.
#' @param diagnostics_output_dir Existing or new directory for normalization
#'   diagnostic PNG files. Has no effect unless `normalization_diagnostics` is
#'   `TRUE`.
#' @param return_expression_matrix Append downstream expression values to the
#'   right of the returned DEG table. Default: `TRUE`.
#' @param return_batch_corrected_values Remove requested technical batches, and
#'   optionally donor effects, from returned expression values. This does not
#'   alter the DE model. Default: `TRUE`.
#' @param remove_donor_effect_for_downstream When a donor column is supplied,
#'   remove its effect from downstream expression values. Default: `TRUE` for
#'   repeated-measures analyses and `FALSE` otherwise.
#' @param summarization_method How duplicate gene IDs are summarised before
#'   modelling. Raw counts should normally use `"sum"`.
#'
#' @return A data frame with gene-level statistics followed by one downstream
#'   expression column per selected sample. A run summary is attached in the
#'   `omix_deg_run` attribute.
.omix_deg_analysis_raw_counts <- function(
  Dataset,
  Metadata_Table,
  sample_names_column,
  samples_to_include,
  gene_names_column,
  contrast_variable_columns,
  contrasts,
  covariate_columns = NULL,
  donor_variable_column = NULL,
  batch_effect_columns = NULL,
  filter_low_expression = TRUE,
  normalization_method = "TMM",
  normalization_diagnostics = FALSE,
  diagnostics_output_dir = NULL,
  return_expression_matrix = TRUE,
  return_batch_corrected_values = TRUE,
  remove_donor_effect_for_downstream = !is.null(donor_variable_column),
  summarization_method = "sum"
) {
  required_packages <- c("edgeR", "limma")
  unavailable <- required_packages[!vapply(
    required_packages,
    requireNamespace,
    logical(1),
    quietly = TRUE
  )]
  if (length(unavailable) > 0L) {
    stop("Required package(s) not installed: ", paste(unavailable, collapse = ", "))
  }

  Dataset <- as.data.frame(Dataset, check.names = FALSE)
  Metadata_Table <- as.data.frame(Metadata_Table, check.names = FALSE)
  samples_to_include <- as.character(samples_to_include)
  contrast_variable_columns <- as.character(contrast_variable_columns)
  covariate_columns <- unique(as.character(covariate_columns))
  batch_effect_columns <- unique(as.character(batch_effect_columns))
  donor_variable_column <- as.character(donor_variable_column)

  if (length(contrast_variable_columns) < 1L || length(contrast_variable_columns) > 2L) {
    stop("contrast_variable_columns must contain one or two metadata columns.")
  }
  if (length(donor_variable_column) > 1L) {
    stop("Specify at most one donor_variable_column.")
  }
  if (!summarization_method %in% c("sum", "mean", "max")) {
    stop("summarization_method must be one of: sum, mean, max.")
  }
  if (!is.logical(normalization_diagnostics) || length(normalization_diagnostics) != 1L || is.na(normalization_diagnostics)) {
    stop("normalization_diagnostics must be TRUE or FALSE.")
  }
  if (!is.null(diagnostics_output_dir) && (length(diagnostics_output_dir) != 1L || is.na(diagnostics_output_dir))) {
    stop("diagnostics_output_dir must be one path or NULL.")
  }
  normalization_profile <- .omix_deg_normalization_profile(normalization_method)

  required_dataset_columns <- c(gene_names_column, samples_to_include)
  missing_dataset_columns <- setdiff(required_dataset_columns, colnames(Dataset))
  if (length(missing_dataset_columns) > 0L) {
    stop("Dataset is missing required column(s): ", paste(missing_dataset_columns, collapse = ", "))
  }

  required_metadata_columns <- unique(c(
    sample_names_column,
    contrast_variable_columns,
    covariate_columns,
    batch_effect_columns,
    donor_variable_column
  ))
  missing_metadata_columns <- setdiff(required_metadata_columns, colnames(Metadata_Table))
  if (length(missing_metadata_columns) > 0L) {
    stop(
      "Metadata_Table is missing required column(s): ",
      paste(missing_metadata_columns, collapse = ", ")
    )
  }
  if (anyDuplicated(samples_to_include)) {
    stop("samples_to_include contains duplicate sample names.")
  }
  if (anyDuplicated(Metadata_Table[[sample_names_column]])) {
    stop("Metadata_Table contains duplicate sample identifiers.")
  }
  if (anyNA(Dataset[[gene_names_column]]) || any(Dataset[[gene_names_column]] == "")) {
    stop("Gene identifiers must be present and non-empty.")
  }

  raw_counts <- as.matrix(Dataset[, samples_to_include, drop = FALSE])
  storage.mode(raw_counts) <- "numeric"
  if (any(!is.finite(raw_counts)) || any(raw_counts < 0)) {
    stop("Raw counts must be finite, non-negative numeric values.")
  }
  if (any(abs(raw_counts - round(raw_counts)) > 1e-8)) {
    stop("Raw-count input must be integer-like; use a transformed-expression workflow instead.")
  }

  sample_metadata <- Metadata_Table[
    match(samples_to_include, Metadata_Table[[sample_names_column]]),
    ,
    drop = FALSE
  ]
  if (anyNA(sample_metadata[[sample_names_column]])) {
    missing_metadata <- samples_to_include[is.na(sample_metadata[[sample_names_column]])]
    stop("Metadata is missing selected sample(s): ", paste(missing_metadata, collapse = ", "))
  }
  rownames(sample_metadata) <- sample_metadata[[sample_names_column]]

  if (length(contrast_variable_columns) == 1L) {
    raw_groups <- as.character(sample_metadata[[contrast_variable_columns]])
  } else {
    raw_groups <- paste(
      sample_metadata[[contrast_variable_columns[1L]]],
      sample_metadata[[contrast_variable_columns[2L]]],
      sep = "."
    )
  }
  if (anyNA(raw_groups) || any(raw_groups == "")) {
    stop("Comparison-group metadata contains missing or empty values.")
  }

  contrast_terms <- unique(unlist(strsplit(as.character(contrasts), "-", fixed = TRUE)))
  absent_groups <- setdiff(contrast_terms, unique(raw_groups))
  if (length(absent_groups) > 0L) {
    stop("Requested contrast group(s) absent from metadata: ", paste(absent_groups, collapse = ", "))
  }
  include <- raw_groups %in% contrast_terms
  sample_metadata <- sample_metadata[include, , drop = FALSE]
  raw_counts <- raw_counts[, rownames(sample_metadata), drop = FALSE]
  raw_groups <- raw_groups[include]

  samples_per_group <- table(raw_groups)
  under_replicated_groups <- names(samples_per_group)[samples_per_group < 2L]
  if (length(under_replicated_groups) > 0L) {
    group_summary <- paste0(
      under_replicated_groups,
      " (n=",
      unname(samples_per_group[under_replicated_groups]),
      ")"
    )
    stop(
      "Each comparison group must contain at least two biological samples. ",
      "Under-replicated group(s): ",
      paste(group_summary, collapse = ", "),
      ". For single-cell input, aggregate raw counts by donor and condition ",
      "before running OMIX-DEG-Analysis."
    )
  }

  group_levels_raw <- unique(contrast_terms)
  group_levels <- make.names(group_levels_raw, unique = FALSE)
  if (anyDuplicated(group_levels)) {
    stop("Comparison group labels become ambiguous after R name conversion.")
  }
  names(group_levels) <- group_levels_raw
  group_labels <- unname(group_levels[raw_groups])
  sample_metadata$.omix_group <- factor(group_labels, levels = unname(group_levels))

  contrast_labels <- vapply(as.character(contrasts), function(contrast) {
    terms <- strsplit(contrast, "-", fixed = TRUE)[[1L]]
    paste(unname(group_levels[terms]), collapse = "-")
  }, character(1))

  if (length(donor_variable_column) == 1L) {
    donor <- as.character(sample_metadata[[donor_variable_column]])
    if (anyNA(donor) || any(donor == "")) {
      stop("The donor column contains missing or empty values.")
    }
    donor_group_key <- paste(donor, group_labels, sep = "\r")
    duplicated_pairs <- unique(donor_group_key[duplicated(donor_group_key)])
    if (length(duplicated_pairs) > 0L) {
      stop(
        "Technical replicates detected within donor-by-group combinations. ",
        "Aggregate them before analysis; OMIX-DEG-Analysis will not silently select one."
      )
    }
    if (length(unique(donor)) < 2L) {
      stop("A repeated-measures model requires at least two donors.")
    }
  }

  gene_ids <- as.character(Dataset[[gene_names_column]])
  raw_counts <- switch(
    summarization_method,
    sum = rowsum(raw_counts, group = gene_ids, reorder = FALSE),
    mean = rowsum(raw_counts, group = gene_ids, reorder = FALSE) /
      as.numeric(table(factor(gene_ids, levels = rownames(rowsum(raw_counts, group = gene_ids, reorder = FALSE))))),
    max = do.call(rbind, lapply(split(seq_along(gene_ids), gene_ids), function(indices) {
      apply(raw_counts[indices, , drop = FALSE], 2L, max)
    }))
  )
  storage.mode(raw_counts) <- "numeric"

  group_design <- stats::model.matrix(~ 0 + .omix_group, data = sample_metadata)
  colnames(group_design) <- unname(group_levels)

  if (length(intersect(batch_effect_columns, contrast_variable_columns)) > 0L) {
    stop("A batch-effect column cannot also define the biological comparison group.")
  }
  if (length(donor_variable_column) == 1L && donor_variable_column %in% batch_effect_columns) {
    stop("The donor column is handled separately; do not also specify it as a batch-effect column.")
  }

  model_covariates <- unique(c(covariate_columns, batch_effect_columns))
  model_covariates <- setdiff(model_covariates, contrast_variable_columns)
  if (length(donor_variable_column) == 1L && donor_variable_column %in% model_covariates) {
    stop("Do not include the donor column as a fixed covariate when using donor_variable_column.")
  }
  if (length(model_covariates) > 0L) {
    covariate_data <- lapply(model_covariates, function(column) {
      value <- sample_metadata[[column]]
      if (anyNA(value)) {
        stop("Covariate '", column, "' contains missing values.")
      }
      factor(value)
    })
    names(covariate_data) <- paste0(".omix_cov_", seq_along(covariate_data))
    # Use treatment coding for covariates. The biological group design already
    # spans the intercept, so a full set of covariate indicator columns would
    # create an artificial rank deficiency.
    covariate_design <- stats::model.matrix(
      stats::reformulate(names(covariate_data), intercept = TRUE),
      data = as.data.frame(covariate_data)
    )
    covariate_design <- covariate_design[, colnames(covariate_design) != "(Intercept)", drop = FALSE]
    colnames(covariate_design) <- paste0("covariate_", seq_len(ncol(covariate_design)))
    design <- cbind(group_design, covariate_design)
  } else {
    design <- group_design
  }
  if (!limma::is.fullrank(design)) {
    non_estimable <- limma::nonEstimable(design)
    stop(
      "The design is not full rank; biological groups and covariates are confounded. ",
      "Non-estimable coefficient(s): ",
      paste(non_estimable, collapse = ", ")
    )
  }

  dge <- edgeR::DGEList(counts = raw_counts)
  genes_before_filtering <- nrow(dge)
  if (isTRUE(filter_low_expression)) {
    keep <- edgeR::filterByExpr(dge, design = group_design)
    if (!any(keep)) {
      stop("No genes passed design-aware low-expression filtering.")
    }
    dge <- dge[keep, , keep.lib.sizes = FALSE]
  }
  pre_normalization_log_cpm <- edgeR::cpm(
    dge,
    log = TRUE,
    prior.count = 0.5,
    normalized.lib.sizes = FALSE
  )
  dge <- edgeR::calcNormFactors(dge, method = normalization_profile[["library_size"]])
  write_diagnostics <- isTRUE(normalization_diagnostics) && !is.null(diagnostics_output_dir)

  if (length(donor_variable_column) == 1L) {
    donor <- factor(sample_metadata[[donor_variable_column]])
    voom_first_pass <- limma::voom(
      dge,
      design,
      normalize.method = normalization_profile[["voom_scale"]]
    )
    correlation_fit <- limma::duplicateCorrelation(
      voom_first_pass,
      design,
      block = donor
    )
    voom_expression <- limma::voom(
      dge,
      design,
      normalize.method = normalization_profile[["voom_scale"]],
      block = donor,
      correlation = correlation_fit$consensus.correlation,
      save.plot = write_diagnostics
    )
    correlation_fit <- limma::duplicateCorrelation(
      voom_expression,
      design,
      block = donor
    )
    fit <- limma::lmFit(
      voom_expression,
      design,
      block = donor,
      correlation = correlation_fit$consensus.correlation
    )
    model_type <- "repeated_measures"
  } else {
    voom_expression <- limma::voom(
      dge,
      design,
      normalize.method = normalization_profile[["voom_scale"]],
      save.plot = write_diagnostics
    )
    fit <- limma::lmFit(voom_expression, design)
    correlation_fit <- NULL
    model_type <- "linear"
  }

  diagnostic_files <- character()
  if (write_diagnostics) {
    diagnostic_files <- .omix_deg_write_normalization_diagnostics(
      pre_normalization_log_cpm = pre_normalization_log_cpm,
      post_normalization_log_cpm = voom_expression$E,
      voom_xy = voom_expression$voom.xy,
      voom_line = voom_expression$voom.line,
      output_dir = diagnostics_output_dir,
      profile_label = normalization_profile[["label"]]
    )
  }

  contrast_matrix <- limma::makeContrasts(contrasts = contrast_labels, levels = design)
  fit <- limma::contrasts.fit(fit, contrast_matrix)
  fit <- limma::eBayes(fit)

  expression_for_downstream <- voom_expression$E
  adjustment_columns <- batch_effect_columns[vapply(
    batch_effect_columns,
    function(column) length(unique(sample_metadata[[column]])) > 1L,
    logical(1)
  )]
  if (isTRUE(return_batch_corrected_values)) {
    adjustment_values <- lapply(adjustment_columns, function(column) factor(sample_metadata[[column]]))
    if (isTRUE(remove_donor_effect_for_downstream) && length(donor_variable_column) == 1L) {
      adjustment_values <- c(list(factor(sample_metadata[[donor_variable_column]])), adjustment_values)
    }
    if (length(adjustment_values) > 0L) {
      extra_covariates <- NULL
      if (length(adjustment_values) > 2L) {
        extra_covariates <- stats::model.matrix(
          ~ 0 + .,
          data = as.data.frame(adjustment_values[-c(1L, 2L)])
        )
      }
      expression_for_downstream <- limma::removeBatchEffect(
        voom_expression$E,
        batch = adjustment_values[[1L]],
        batch2 = if (length(adjustment_values) >= 2L) adjustment_values[[2L]] else NULL,
        covariates = extra_covariates,
        design = group_design
      )
    }
  }

  calculate_standard_error <- function(values) {
    values <- values[is.finite(values)]
    if (length(values) < 2L) return(NA_real_)
    stats::sd(values) / sqrt(length(values))
  }
  group_means <- lapply(colnames(group_design), function(group) {
    indices <- group_design[, group] == 1
    rowMeans(expression_for_downstream[, indices, drop = FALSE])
  })
  names(group_means) <- paste0(colnames(group_design), "_Mean")
  group_standard_errors <- lapply(colnames(group_design), function(group) {
    indices <- group_design[, group] == 1
    apply(expression_for_downstream[, indices, drop = FALSE], 1L, calculate_standard_error)
  })
  names(group_standard_errors) <- paste0(colnames(group_design), "_SE")

  log_fc <- fit$coefficients
  fold_change <- 2^log_fc
  fold_change[fold_change < 1] <- -1 / fold_change[fold_change < 1]
  standard_error <- sqrt(fit$s2.post) * fit$stdev.unscaled
  p_values <- fit$p.value
  adjusted_p_values <- apply(p_values, 2L, stats::p.adjust, method = "BH")

  colnames(fold_change) <- paste0(colnames(fold_change), "_FC")
  colnames(log_fc) <- paste0(colnames(log_fc), "_logFC")
  colnames(standard_error) <- paste0(colnames(standard_error), "_SE")
  colnames(fit$t) <- paste0(colnames(fit$t), "_tstat")
  colnames(p_values) <- paste0(colnames(p_values), "_pval")
  colnames(adjusted_p_values) <- paste0(colnames(adjusted_p_values), "_adjpval")

  results <- data.frame(
    GeneName = rownames(voom_expression$E),
    do.call(cbind, group_means),
    do.call(cbind, group_standard_errors),
    fold_change,
    log_fc,
    standard_error,
    fit$t,
    p_values,
    adjusted_p_values,
    check.names = FALSE
  )
  if (isTRUE(return_expression_matrix)) {
    results <- cbind(results, expression_for_downstream[, colnames(voom_expression$E), drop = FALSE])
  }

  attr(results, "omix_deg_run") <- list(
    analysis_mode = "raw_counts",
    input_matrix_type = "raw_integer_counts",
    model_type = model_type,
    normalization_method = normalization_profile[["label"]],
    library_size_normalization = normalization_profile[["library_size"]],
    voom_scale_normalization = normalization_profile[["voom_scale"]],
    genes_before_filtering = genes_before_filtering,
    genes_modelled = nrow(voom_expression$E),
    expression_output = if (identical(expression_for_downstream, voom_expression$E)) {
      "normalized_voom"
    } else {
      "batch_adjusted_voom"
    },
    adjusted_columns = unique(c(
      if (isTRUE(remove_donor_effect_for_downstream) && length(donor_variable_column) == 1L) donor_variable_column,
      adjustment_columns
    )),
    modeled_covariates = model_covariates,
    consensus_correlation = if (is.null(correlation_fit)) NULL else correlation_fit$consensus.correlation,
    normalization_diagnostic_files = unname(diagnostic_files)
  )
  results
}

#' Fit OMIX differential-expression models for raw counts or donor-level means
#'
#' @description
#' Selects one of three deliberately separate analysis paths. `raw_counts` uses
#' edgeR normalization and limma-voom for integer count matrices.
#' `harmony_mean_expression` uses donor-level means from a declared
#' Harmony-corrected, log2-scale gene-expression matrix and fits limma directly.
#' The `sct_mean_expression` path uses log2-scale donor means derived from
#' Seurat's SCT/data layer and also fits limma directly. Neither continuous
#' path applies count normalization or voom. Harmony means reject a second
#' batch adjustment; SCTransform means preserve the supplied values and can
#' model an unhandled technical variable through `covariate_columns`.
#'
#' @param analysis_mode `"raw_counts"` (default),
#'   `"harmony_mean_expression"`, or `"sct_mean_expression"`.
#' @param filter_low_expression For raw counts, whether to use
#'   `edgeR::filterByExpr()`. Defaults to `TRUE` for raw counts and `FALSE` for
#'   continuous donor means.
#' @param normalization_method Raw-count normalization profile. Defaults to
#'   `"TMM"` for raw counts and `"None"` for continuous donor means.
#' @param return_batch_corrected_values Whether to remove fitted batch/donor
#'   effects from the expression block. Defaults to `TRUE` for raw counts and
#'   `FALSE` for continuous donor means.
#' @param summarization_method Duplicate-gene summarization. Defaults to `sum`
#'   for raw counts and `mean` for Harmony-corrected expression.
#'
#' @inheritParams .omix_deg_analysis_raw_counts
#' @return A standardized DEG table with a run-provenance attribute.
omix_deg_analysis <- function(
  Dataset,
  Metadata_Table,
  sample_names_column,
  samples_to_include,
  gene_names_column,
  contrast_variable_columns,
  contrasts,
  covariate_columns = NULL,
  donor_variable_column = NULL,
  batch_effect_columns = NULL,
  analysis_mode = c("raw_counts", "harmony_mean_expression", "sct_mean_expression"),
  filter_low_expression = NULL,
  normalization_method = NULL,
  normalization_diagnostics = NULL,
  diagnostics_output_dir = NULL,
  return_expression_matrix = TRUE,
  return_batch_corrected_values = NULL,
  remove_donor_effect_for_downstream = NULL,
  summarization_method = NULL
) {
  analysis_mode <- match.arg(analysis_mode)
  batch_effect_columns <- .omix_deg_optional_columns(batch_effect_columns)
  covariate_columns <- .omix_deg_optional_columns(covariate_columns)
  donor_variable_column <- .omix_deg_optional_columns(donor_variable_column)

  if (is.null(filter_low_expression)) {
    filter_low_expression <- identical(analysis_mode, "raw_counts")
  }
  if (is.null(normalization_method) || identical(normalization_method, "auto")) {
    normalization_method <- if (identical(analysis_mode, "raw_counts")) "TMM" else "None"
  }
  if (is.null(normalization_diagnostics)) {
    normalization_diagnostics <- FALSE
  }
  if (is.null(return_batch_corrected_values)) {
    return_batch_corrected_values <- identical(analysis_mode, "raw_counts")
  }
  if (is.null(remove_donor_effect_for_downstream)) {
    remove_donor_effect_for_downstream <- identical(analysis_mode, "raw_counts") &&
      length(donor_variable_column) == 1L
  }
  if (is.null(summarization_method) || identical(summarization_method, "auto")) {
    summarization_method <- if (identical(analysis_mode, "raw_counts")) "sum" else "mean"
  }

  if (!is.logical(filter_low_expression) || length(filter_low_expression) != 1L || is.na(filter_low_expression)) {
    stop("filter_low_expression must be TRUE or FALSE.", call. = FALSE)
  }
  if (!is.logical(normalization_diagnostics) || length(normalization_diagnostics) != 1L || is.na(normalization_diagnostics)) {
    stop("normalization_diagnostics must be TRUE or FALSE.", call. = FALSE)
  }
  if (!is.logical(return_batch_corrected_values) || length(return_batch_corrected_values) != 1L || is.na(return_batch_corrected_values)) {
    stop("return_batch_corrected_values must be TRUE or FALSE.", call. = FALSE)
  }
  if (!is.logical(remove_donor_effect_for_downstream) || length(remove_donor_effect_for_downstream) != 1L || is.na(remove_donor_effect_for_downstream)) {
    stop("remove_donor_effect_for_downstream must be TRUE or FALSE.", call. = FALSE)
  }

  if (identical(analysis_mode, "raw_counts")) {
    if (identical(normalization_method, "None")) {
      stop("normalization_method = 'None' is only valid for continuous-expression modes.", call. = FALSE)
    }
    return(.omix_deg_analysis_raw_counts(
      Dataset = Dataset,
      Metadata_Table = Metadata_Table,
      sample_names_column = sample_names_column,
      samples_to_include = samples_to_include,
      gene_names_column = gene_names_column,
      contrast_variable_columns = contrast_variable_columns,
      contrasts = contrasts,
      covariate_columns = covariate_columns,
      donor_variable_column = donor_variable_column,
      batch_effect_columns = batch_effect_columns,
      filter_low_expression = filter_low_expression,
      normalization_method = normalization_method,
      normalization_diagnostics = normalization_diagnostics,
      diagnostics_output_dir = diagnostics_output_dir,
      return_expression_matrix = return_expression_matrix,
      return_batch_corrected_values = return_batch_corrected_values,
      remove_donor_effect_for_downstream = remove_donor_effect_for_downstream,
      summarization_method = summarization_method
    ))
  }

  if (length(batch_effect_columns) > 0L) {
    if (identical(analysis_mode, "harmony_mean_expression")) {
      stop(
        "harmony_mean_expression already represents batch-corrected expression; ",
        "leave batch_effect_columns empty rather than applying a second batch adjustment.",
        call. = FALSE
      )
    }
    stop(
      "sct_mean_expression preserves donor means from Seurat SCT/data and does not ",
      "remove another batch effect. If technical batch was not handled upstream, model ",
      "it as a fixed covariate through covariate_columns (for example, 'Batch').",
      call. = FALSE
    )
  }
  if (!identical(normalization_method, "None")) {
    stop(
      analysis_mode, " requires normalization_method = 'None'; ",
      "do not apply TMM, voom-scale normalization, or another normalization.",
      call. = FALSE
    )
  }
  if (isTRUE(filter_low_expression)) {
    stop(
      analysis_mode, " does not use edgeR count filtering; set filter_low_expression = FALSE.",
      call. = FALSE
    )
  }
  if (isTRUE(normalization_diagnostics)) {
    stop(
      analysis_mode, " has no normalization or voom diagnostics; set normalization_diagnostics = FALSE.",
      call. = FALSE
    )
  }
  if (isTRUE(return_batch_corrected_values) || isTRUE(remove_donor_effect_for_downstream)) {
    stop(
      analysis_mode, " returns the supplied continuous expression unchanged; ",
      "set return_batch_corrected_values and remove_donor_effect_for_downstream to FALSE.",
      call. = FALSE
    )
  }
  continuous_details <- switch(
    analysis_mode,
    harmony_mean_expression = list(
      input_matrix_type = "harmony_corrected_mean_expression",
      input_label = "Harmony-corrected mean expression",
      expression_output = "input_harmony_corrected_expression"
    ),
    sct_mean_expression = list(
      input_matrix_type = "sctransform_mean_log2_expression",
      input_label = "SCTransform mean log2 expression",
      expression_output = "input_sctransform_log2_expression"
    )
  )
  .omix_deg_analysis_continuous_means(
    Dataset = Dataset,
    Metadata_Table = Metadata_Table,
    sample_names_column = sample_names_column,
    samples_to_include = samples_to_include,
    gene_names_column = gene_names_column,
    contrast_variable_columns = contrast_variable_columns,
    contrasts = contrasts,
    covariate_columns = covariate_columns,
    donor_variable_column = donor_variable_column,
    return_expression_matrix = return_expression_matrix,
    summarization_method = summarization_method,
    analysis_mode = analysis_mode,
    input_matrix_type = continuous_details$input_matrix_type,
    input_label = continuous_details$input_label,
    expression_output = continuous_details$expression_output
  )
}

.omix_deg_analysis_continuous_means <- function(
  Dataset,
  Metadata_Table,
  sample_names_column,
  samples_to_include,
  gene_names_column,
  contrast_variable_columns,
  contrasts,
  covariate_columns,
  donor_variable_column,
  return_expression_matrix,
  summarization_method,
  analysis_mode,
  input_matrix_type,
  input_label,
  expression_output
) {
  if (!requireNamespace("limma", quietly = TRUE)) {
    stop("Required package is not installed: limma", call. = FALSE)
  }
  Dataset <- as.data.frame(Dataset, check.names = FALSE)
  Metadata_Table <- as.data.frame(Metadata_Table, check.names = FALSE)
  samples_to_include <- as.character(samples_to_include)
  contrast_variable_columns <- .omix_deg_optional_columns(contrast_variable_columns)
  covariate_columns <- .omix_deg_optional_columns(covariate_columns)
  donor_variable_column <- .omix_deg_optional_columns(donor_variable_column)

  if (length(contrast_variable_columns) < 1L || length(contrast_variable_columns) > 2L) {
    stop("contrast_variable_columns must contain one or two metadata columns.", call. = FALSE)
  }
  if (length(donor_variable_column) > 1L) {
    stop("Specify at most one donor_variable_column.", call. = FALSE)
  }
  if (!summarization_method %in% c("sum", "mean", "max")) {
    stop("summarization_method must be one of: sum, mean, max.", call. = FALSE)
  }
  if (!is.logical(return_expression_matrix) || length(return_expression_matrix) != 1L || is.na(return_expression_matrix)) {
    stop("return_expression_matrix must be TRUE or FALSE.", call. = FALSE)
  }

  required_dataset_columns <- c(gene_names_column, samples_to_include)
  missing_dataset_columns <- setdiff(required_dataset_columns, names(Dataset))
  if (length(missing_dataset_columns) > 0L) {
    stop("Dataset is missing required column(s): ", paste(missing_dataset_columns, collapse = ", "), call. = FALSE)
  }
  required_metadata_columns <- unique(c(sample_names_column, contrast_variable_columns, covariate_columns, donor_variable_column))
  missing_metadata_columns <- setdiff(required_metadata_columns, names(Metadata_Table))
  if (length(missing_metadata_columns) > 0L) {
    stop("Metadata_Table is missing required column(s): ", paste(missing_metadata_columns, collapse = ", "), call. = FALSE)
  }
  if (anyDuplicated(samples_to_include)) {
    stop("samples_to_include contains duplicate sample names.", call. = FALSE)
  }
  if (anyDuplicated(Metadata_Table[[sample_names_column]])) {
    stop("Metadata_Table contains duplicate sample identifiers.", call. = FALSE)
  }
  if (anyNA(Dataset[[gene_names_column]]) || any(Dataset[[gene_names_column]] == "")) {
    stop("Gene identifiers must be present and non-empty.", call. = FALSE)
  }

  expression <- as.matrix(Dataset[, samples_to_include, drop = FALSE])
  storage.mode(expression) <- "numeric"
  if (any(!is.finite(expression))) {
    stop(input_label, " must contain only finite numeric values.", call. = FALSE)
  }
  sample_metadata <- Metadata_Table[match(samples_to_include, Metadata_Table[[sample_names_column]]), , drop = FALSE]
  if (anyNA(sample_metadata[[sample_names_column]])) {
    missing_metadata <- samples_to_include[is.na(sample_metadata[[sample_names_column]])]
    stop("Metadata is missing selected sample(s): ", paste(missing_metadata, collapse = ", "), call. = FALSE)
  }
  rownames(sample_metadata) <- sample_metadata[[sample_names_column]]

  raw_groups <- if (length(contrast_variable_columns) == 1L) {
    as.character(sample_metadata[[contrast_variable_columns]])
  } else {
    paste(
      sample_metadata[[contrast_variable_columns[[1L]]]],
      sample_metadata[[contrast_variable_columns[[2L]]]],
      sep = "."
    )
  }
  if (anyNA(raw_groups) || any(raw_groups == "")) {
    stop("Comparison-group metadata contains missing or empty values.", call. = FALSE)
  }
  if (length(contrasts) == 0L || anyNA(contrasts) || any(!nzchar(contrasts))) {
    stop("contrasts must contain one or more non-empty comparisons.", call. = FALSE)
  }
  contrast_terms <- unique(unlist(strsplit(as.character(contrasts), "-", fixed = TRUE)))
  absent_groups <- setdiff(contrast_terms, unique(raw_groups))
  if (length(absent_groups) > 0L) {
    stop("Requested contrast group(s) absent from metadata: ", paste(absent_groups, collapse = ", "), call. = FALSE)
  }
  include <- raw_groups %in% contrast_terms
  sample_metadata <- sample_metadata[include, , drop = FALSE]
  expression <- expression[, rownames(sample_metadata), drop = FALSE]
  raw_groups <- raw_groups[include]

  samples_per_group <- table(raw_groups)
  under_replicated_groups <- names(samples_per_group)[samples_per_group < 2L]
  if (length(under_replicated_groups) > 0L) {
    group_summary <- paste0(under_replicated_groups, " (n=", unname(samples_per_group[under_replicated_groups]), ")")
    stop(
      "Each comparison group must contain at least two biological donor-level profiles. ",
      "Under-replicated group(s): ", paste(group_summary, collapse = ", "), ".",
      call. = FALSE
    )
  }

  group_levels_raw <- unique(contrast_terms)
  group_levels <- make.names(group_levels_raw, unique = FALSE)
  if (anyDuplicated(group_levels)) {
    stop("Comparison group labels become ambiguous after R name conversion.", call. = FALSE)
  }
  names(group_levels) <- group_levels_raw
  group_labels <- unname(group_levels[raw_groups])
  sample_metadata$.omix_group <- factor(group_labels, levels = unname(group_levels))
  contrast_labels <- vapply(as.character(contrasts), function(contrast) {
    terms <- strsplit(contrast, "-", fixed = TRUE)[[1L]]
    paste(unname(group_levels[terms]), collapse = "-")
  }, character(1))

  if (length(donor_variable_column) == 1L) {
    donor <- as.character(sample_metadata[[donor_variable_column]])
    if (anyNA(donor) || any(donor == "")) {
      stop("The donor column contains missing or empty values.", call. = FALSE)
    }
    donor_group_key <- paste(donor, group_labels, sep = "\r")
    if (anyDuplicated(donor_group_key)) {
      stop(
        "Multiple donor-level profiles occur within donor-by-group combinations. ",
        "Aggregate or resolve technical replicates before direct limma analysis.",
        call. = FALSE
      )
    }
    if (length(unique(donor)) < 2L) {
      stop("A repeated-measures model requires at least two donors.", call. = FALSE)
    }
  }

  gene_ids <- as.character(Dataset[[gene_names_column]])
  expression <- .omix_deg_summarize_rows(expression, gene_ids, summarization_method)
  group_design <- stats::model.matrix(~ 0 + .omix_group, data = sample_metadata)
  colnames(group_design) <- unname(group_levels)

  if (length(intersect(covariate_columns, contrast_variable_columns)) > 0L) {
    stop("A covariate column cannot also define the biological comparison group.", call. = FALSE)
  }
  if (length(donor_variable_column) == 1L && donor_variable_column %in% covariate_columns) {
    stop("Do not include the donor column as a fixed covariate when using donor_variable_column.", call. = FALSE)
  }
  if (length(covariate_columns) > 0L) {
    covariate_data <- lapply(covariate_columns, function(column) {
      value <- sample_metadata[[column]]
      if (anyNA(value)) stop("Covariate '", column, "' contains missing values.", call. = FALSE)
      factor(value)
    })
    names(covariate_data) <- paste0(".omix_cov_", seq_along(covariate_data))
    covariate_design <- stats::model.matrix(
      stats::reformulate(names(covariate_data), intercept = TRUE),
      data = as.data.frame(covariate_data)
    )
    covariate_design <- covariate_design[, colnames(covariate_design) != "(Intercept)", drop = FALSE]
    colnames(covariate_design) <- paste0("covariate_", seq_len(ncol(covariate_design)))
    design <- cbind(group_design, covariate_design)
  } else {
    design <- group_design
  }
  if (!limma::is.fullrank(design)) {
    non_estimable <- limma::nonEstimable(design)
    stop(
      "The design is not full rank; biological groups and covariates are confounded. ",
      "Non-estimable coefficient(s): ", paste(non_estimable, collapse = ", "),
      call. = FALSE
    )
  }

  if (length(donor_variable_column) == 1L) {
    donor <- factor(sample_metadata[[donor_variable_column]])
    correlation_fit <- limma::duplicateCorrelation(expression, design, block = donor)
    fit <- limma::lmFit(expression, design, block = donor, correlation = correlation_fit$consensus.correlation)
    model_type <- "continuous_repeated_measures"
  } else {
    correlation_fit <- NULL
    fit <- limma::lmFit(expression, design)
    model_type <- "continuous_linear"
  }
  contrast_matrix <- limma::makeContrasts(contrasts = contrast_labels, levels = design)
  fit <- limma::contrasts.fit(fit, contrast_matrix)
  fit <- limma::eBayes(fit)

  calculate_standard_error <- function(values) {
    values <- values[is.finite(values)]
    if (length(values) < 2L) return(NA_real_)
    stats::sd(values) / sqrt(length(values))
  }
  group_means <- lapply(colnames(group_design), function(group) {
    rowMeans(expression[, group_design[, group] == 1, drop = FALSE])
  })
  names(group_means) <- paste0(colnames(group_design), "_Mean")
  group_standard_errors <- lapply(colnames(group_design), function(group) {
    apply(expression[, group_design[, group] == 1, drop = FALSE], 1L, calculate_standard_error)
  })
  names(group_standard_errors) <- paste0(colnames(group_design), "_SE")

  log_fc <- fit$coefficients
  fold_change <- 2^log_fc
  fold_change[fold_change < 1] <- -1 / fold_change[fold_change < 1]
  standard_error <- sqrt(fit$s2.post) * fit$stdev.unscaled
  p_values <- fit$p.value
  adjusted_p_values <- apply(p_values, 2L, stats::p.adjust, method = "BH")
  colnames(fold_change) <- paste0(colnames(fold_change), "_FC")
  colnames(log_fc) <- paste0(colnames(log_fc), "_logFC")
  colnames(standard_error) <- paste0(colnames(standard_error), "_SE")
  colnames(fit$t) <- paste0(colnames(fit$t), "_tstat")
  colnames(p_values) <- paste0(colnames(p_values), "_pval")
  colnames(adjusted_p_values) <- paste0(colnames(adjusted_p_values), "_adjpval")

  results <- data.frame(
    GeneName = rownames(expression),
    do.call(cbind, group_means),
    do.call(cbind, group_standard_errors),
    fold_change,
    log_fc,
    standard_error,
    fit$t,
    p_values,
    adjusted_p_values,
    check.names = FALSE
  )
  if (isTRUE(return_expression_matrix)) {
    results <- cbind(results, expression[, colnames(expression), drop = FALSE])
  }
  attr(results, "omix_deg_run") <- list(
    analysis_mode = analysis_mode,
    input_matrix_type = input_matrix_type,
    model_type = model_type,
    normalization_method = "None",
    library_size_normalization = "not_applicable",
    voom_scale_normalization = "not_applicable",
    genes_before_filtering = nrow(expression),
    genes_modelled = nrow(expression),
    expression_output = expression_output,
    adjusted_columns = character(),
    modeled_covariates = covariate_columns,
    consensus_correlation = if (is.null(correlation_fit)) NULL else correlation_fit$consensus.correlation,
    normalization_diagnostic_files = character()
  )
  results
}

.omix_deg_optional_columns <- function(value) {
  values <- unique(as.character(value))
  values <- values[!is.na(values) & nzchar(values)]
  values
}

.omix_deg_summarize_rows <- function(matrix, gene_ids, method) {
  if (anyNA(gene_ids) || any(gene_ids == "")) {
    stop("Gene identifiers must be present and non-empty.", call. = FALSE)
  }
  summed <- rowsum(matrix, group = gene_ids, reorder = FALSE)
  if (identical(method, "sum")) return(summed)
  if (identical(method, "mean")) {
    occurrences <- as.numeric(table(factor(gene_ids, levels = rownames(summed))))
    return(summed / occurrences)
  }
  if (identical(method, "max")) {
    return(do.call(rbind, lapply(split(seq_along(gene_ids), gene_ids), function(indices) {
      apply(matrix[indices, , drop = FALSE], 2L, max)
    })))
  }
  stop("summarization_method must be one of: sum, mean, max.", call. = FALSE)
}

.omix_deg_write_normalization_diagnostics <- function(
  pre_normalization_log_cpm,
  post_normalization_log_cpm,
  voom_xy,
  voom_line,
  output_dir,
  profile_label
) {
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  sample_names <- colnames(post_normalization_log_cpm)
  colors <- grDevices::hcl.colors(length(sample_names), palette = "Dark 3")
  y_limits <- range(c(pre_normalization_log_cpm, post_normalization_log_cpm), finite = TRUE)
  x_limits <- y_limits

  write_png <- function(path, draw) {
    grDevices::png(path, width = 2400, height = 1200, res = 180)
    on.exit(grDevices::dev.off(), add = TRUE)
    draw()
  }

  boxplot_path <- file.path(output_dir, "normalization_boxplots.png")
  write_png(boxplot_path, function() {
    graphics::par(mfrow = c(1L, 2L), mar = c(8, 4, 4, 1) + 0.1)
    graphics::boxplot(
      pre_normalization_log_cpm,
      col = colors,
      las = 2,
      ylim = y_limits,
      main = "Before normalization",
      ylab = "log2-CPM"
    )
    graphics::boxplot(
      post_normalization_log_cpm,
      col = colors,
      las = 2,
      ylim = y_limits,
      main = paste("After", profile_label),
      ylab = "log2-CPM"
    )
  })

  density_path <- file.path(output_dir, "normalization_densities.png")
  write_png(density_path, function() {
    graphics::par(mfrow = c(1L, 2L), mar = c(4, 4, 4, 1) + 0.1)
    limma::plotDensities(
      pre_normalization_log_cpm,
      col = colors,
      xlim = x_limits,
      main = "Before normalization",
      xlab = "log2-CPM"
    )
    limma::plotDensities(
      post_normalization_log_cpm,
      col = colors,
      xlim = x_limits,
      main = paste("After", profile_label),
      xlab = "log2-CPM"
    )
  })

  mean_variance_path <- file.path(output_dir, "voom_mean_variance.png")
  write_png(mean_variance_path, function() {
    graphics::plot(
      voom_xy$x,
      voom_xy$y,
      pch = 16,
      cex = 0.35,
      col = grDevices::adjustcolor("black", alpha.f = 0.2),
      xlab = voom_xy$xlab,
      ylab = voom_xy$ylab,
      main = paste("voom mean-variance trend:", profile_label)
    )
    graphics::lines(voom_line$x, voom_line$y, col = "red", lwd = 2)
  })

  c(boxplots = boxplot_path, densities = density_path, mean_variance = mean_variance_path)
}

.omix_deg_normalization_profile <- function(value) {
  profiles <- list(
    "TMM" = c(label = "TMM", library_size = "TMM", voom_scale = "none"),
    "Quantile" = c(label = "Quantile", library_size = "none", voom_scale = "quantile"),
    "TMM + Quantile" = c(label = "TMM + Quantile", library_size = "TMM", voom_scale = "quantile"),
    "TMM + Scale" = c(label = "TMM + Scale", library_size = "TMM", voom_scale = "scale"),
    "TMM + Cyclic Loess" = c(label = "TMM + Cyclic Loess", library_size = "TMM", voom_scale = "cyclicloess"),
    "TMMwsp" = c(label = "TMMwsp", library_size = "TMMwsp", voom_scale = "none"),
    "RLE" = c(label = "RLE", library_size = "RLE", voom_scale = "none"),
    "Upper Quartile" = c(label = "Upper Quartile", library_size = "upperquartile", voom_scale = "none")
  )
  aliases <- c(upperquartile = "Upper Quartile")
  value <- trimws(as.character(value))
  if (length(value) != 1L || is.na(value)) {
    stop("normalization_method must be one normalization profile.")
  }
  if (value %in% names(aliases)) value <- aliases[[value]]
  if (!value %in% names(profiles)) {
    stop("normalization_method must be one of: ", paste(names(profiles), collapse = ", "), ".")
  }
  profiles[[value]]
}
