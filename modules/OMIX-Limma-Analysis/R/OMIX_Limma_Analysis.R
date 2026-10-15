#' Limma analysis for declared continuous feature-by-sample matrices.
#'
#' The implementation aligns samples, summarizes duplicate features, constructs
#' the requested design and contrasts, optionally models repeated donors, and
#' applies limma empirical-Bayes moderation. The caller must declare what the
#' continuous measurements represent; raw count matrices are not accepted.
#'
#' @param Dataset A feature-by-sample data frame with one feature-ID column.
#' @param Metadata_Table Sample metadata with one row per supplied sample.
#' @param sample_names_column Metadata sample-ID column.
#' @param samples_to_include Sample IDs to model.
#' @param gene_names_column Feature-ID column in Dataset.
#' @param contrast_variable_columns One or two metadata columns defining groups.
#' @param contrasts Optional limma contrast expressions. When omitted, the only
#'   comparison is inferred if exactly two modeled groups have replication.
#' @param covariate_columns Optional fixed-effect metadata columns.
#' @param donor_variable_column Optional repeated-measure blocking column.
#' @param summarization_method Duplicate-feature summary function.
#' @param return_matrix Append modeled sample values to the result table.
#' @param fold_change_threshold Effect threshold recorded as provenance.
#' @param first_pvalue_threshold Primary p-value threshold recorded as provenance.
#' @param second_pvalue_threshold Secondary p-value threshold recorded as provenance.
#' @param input_kind Effect-size interpretation: log2_expression,
#'   enrichment_score, or continuous_score.
#' @param input_data_type Scientific type of the supplied continuous matrix.
#' @param measurement_scale Short user-facing description of the measurement
#'   scale, required for other_continuous inputs.
#' @param fraction_transform Transformation applied to CIBERSORT relative
#'   fractions: none, arcsin_sqrt, or logit.
#' @param fraction_pseudocount Boundary value used only for a logit transform.
#' @param variance_model ebayes uses a constant prior variance; ebayes_trend
#'   allows the prior variance to vary with average signal.
#' @return A result data frame with OMIX provenance attached.

.omix_limma_require <- function(package) {
  if (!requireNamespace(package, quietly = TRUE)) {
    stop("OMIX Limma Analysis requires the R package '", package, "'.", call. = FALSE)
  }
}

.omix_limma_as_character <- function(values, argument, allow_empty = FALSE) {
  values <- trimws(as.character(values))
  values <- values[nzchar(values)]
  if (!allow_empty && length(values) == 0L) {
    stop(argument, " must contain at least one value.", call. = FALSE)
  }
  unique(values)
}

.omix_limma_input_data_types <- c(
  "microarray_log2_expression",
  "normalized_bulk_expression",
  "log2_cpm_without_voom_weights",
  "sctransform_mean_expression",
  "harmony_corrected_mean_expression",
  "gsva_enrichment_scores",
  "cibersort_relative_fractions",
  "cibersort_absolute_scores",
  "methylation_m_values",
  "normalized_proteomics",
  "normalized_metabolomics",
  "qpcr_delta_ct",
  "copy_number_log2_ratios",
  "normalized_chromatin_accessibility",
  "normalized_crispr_scores",
  "other_continuous"
)

.omix_limma_manifest_type_aliases <- c(
  harmony_corrected_mean_expression = "harmony_corrected_mean_expression",
  sctransform_mean_log2_expression = "sctransform_mean_expression",
  gsva_enrichment_scores = "gsva_enrichment_scores",
  cibersort_relative_fractions = "cibersort_relative_fractions",
  cibersort_absolute_scores = "cibersort_absolute_scores",
  raw_integer_counts = "raw_integer_counts"
)

.omix_limma_default_variance_model <- function(input_data_type) {
  trend_types <- c(
    "log2_cpm_without_voom_weights",
    "sctransform_mean_expression",
    "normalized_chromatin_accessibility"
  )
  if (identical(input_data_type, "other_continuous")) return(NA_character_)
  if (input_data_type %in% trend_types) "ebayes_trend" else "ebayes"
}

.omix_limma_default_input_kind <- function(input_data_type) {
  if (input_data_type %in% c(
    "microarray_log2_expression", "normalized_bulk_expression",
    "log2_cpm_without_voom_weights", "sctransform_mean_expression",
    "harmony_corrected_mean_expression"
  )) return("log2_expression")
  if (identical(input_data_type, "gsva_enrichment_scores")) return("enrichment_score")
  "continuous_score"
}

# Resolve user and manifest declarations before the model is fitted. This is
# deliberately contract-based: SCT, Harmony, and GSVA cannot be distinguished
# reliably by inspecting an arbitrary numeric matrix.
omix_limma_resolve_input_contract <- function(
    input_data_type = "auto",
    input_kind = "auto",
    variance_model = "auto",
    fraction_transform = "auto",
    manifest_matrix_type = "",
    manifest_recommended_variance_model = "") {
  input_data_type <- tolower(trimws(as.character(input_data_type)))
  input_kind <- tolower(trimws(as.character(input_kind)))
  variance_model <- tolower(trimws(as.character(variance_model)))
  fraction_transform <- tolower(trimws(as.character(fraction_transform)))
  manifest_matrix_type <- tolower(trimws(as.character(manifest_matrix_type)))
  manifest_recommended_variance_model <- tolower(trimws(as.character(manifest_recommended_variance_model)))

  if (length(input_data_type) != 1L || !input_data_type %in% c("auto", .omix_limma_input_data_types)) {
    stop("input_data_type must be auto or a supported declared continuous data type.", call. = FALSE)
  }
  if (length(input_kind) != 1L || !input_kind %in% c("auto", "log2_expression", "enrichment_score", "continuous_score")) {
    stop("input_kind must be auto, log2_expression, enrichment_score, or continuous_score.", call. = FALSE)
  }
  if (length(variance_model) != 1L || !variance_model %in% c("auto", "ebayes", "ebayes_trend")) {
    stop("variance_model must be auto, ebayes, or ebayes_trend.", call. = FALSE)
  }
  if (length(fraction_transform) != 1L || !fraction_transform %in% c("auto", "none", "arcsin_sqrt", "logit")) {
    stop("fraction_transform must be auto, none, arcsin_sqrt, or logit.", call. = FALSE)
  }

  resolved_type <- input_data_type
  type_source <- "explicit"
  manifest_resolved_type <- ""
  if (nzchar(manifest_matrix_type)) {
    if (!manifest_matrix_type %in% names(.omix_limma_manifest_type_aliases)) {
      stop("The manifest declares unsupported matrix_type '", manifest_matrix_type, "'.", call. = FALSE)
    }
    manifest_resolved_type <- unname(.omix_limma_manifest_type_aliases[[manifest_matrix_type]])
    if (identical(manifest_resolved_type, "raw_integer_counts")) {
      stop(
        "Raw integer counts are not valid for direct lmFit. Run OMIX-DEG-Analysis in raw-count mode so count filtering, library normalization, and limma-voom can be applied.",
        call. = FALSE
      )
    }
    if (!identical(resolved_type, "auto") && !identical(resolved_type, manifest_resolved_type)) {
      stop(
        "input_data_type ('", resolved_type, "') does not match the manifest matrix_type ('",
        manifest_matrix_type, "').",
        call. = FALSE
      )
    }
  }
  if (identical(resolved_type, "auto")) {
    if (nzchar(manifest_resolved_type)) {
      resolved_type <- manifest_resolved_type
      type_source <- "manifest"
    } else if (identical(input_kind, "enrichment_score")) {
      resolved_type <- "gsva_enrichment_scores"
      type_source <- "input_kind_fallback"
    } else if (identical(input_kind, "log2_expression")) {
      # Backward-compatible interpretation for callers predating
      # input_data_type. New runs should make the type explicit or use a
      # manifest, especially for SCT and Harmony handoffs.
      resolved_type <- "normalized_bulk_expression"
      type_source <- "input_kind_fallback"
    } else {
      stop(
        "input_data_type=auto could not resolve the matrix type. Supply a compatible manifest or select an explicit input_data_type.",
        call. = FALSE
      )
    }
  }
  if (identical(resolved_type, "raw_integer_counts")) {
    stop(
      "Raw integer counts are not valid for direct lmFit. Run OMIX-DEG-Analysis in raw-count mode so count filtering, library normalization, and limma-voom can be applied.",
      call. = FALSE
    )
  }

  resolved_kind <- if (identical(input_kind, "auto")) {
    .omix_limma_default_input_kind(resolved_type)
  } else {
    input_kind
  }
  recommended_variance_model <- .omix_limma_default_variance_model(resolved_type)
  variance_source <- "input_data_type"
  if (manifest_recommended_variance_model %in% c("ebayes", "ebayes_trend")) {
    recommended_variance_model <- manifest_recommended_variance_model
    variance_source <- "manifest"
  }
  resolved_variance_model <- variance_model
  if (identical(resolved_variance_model, "auto")) {
    if (is.na(recommended_variance_model)) {
      stop(
        "variance_model=auto is not available for input_data_type=other_continuous. Select ebayes or ebayes_trend after considering the measurement scale and variance diagnostic.",
        call. = FALSE
      )
    }
    resolved_variance_model <- recommended_variance_model
  } else {
    variance_source <- "explicit"
  }

  resolved_fraction_transform <- fraction_transform
  if (identical(resolved_fraction_transform, "auto")) {
    resolved_fraction_transform <- if (identical(resolved_type, "cibersort_relative_fractions")) "arcsin_sqrt" else "none"
  }
  if (!identical(resolved_type, "cibersort_relative_fractions") && !identical(resolved_fraction_transform, "none")) {
    stop("fraction_transform is only valid for cibersort_relative_fractions.", call. = FALSE)
  }

  list(
    requested_input_data_type = input_data_type,
    input_data_type = resolved_type,
    input_data_type_source = type_source,
    input_kind = resolved_kind,
    requested_variance_model = variance_model,
    recommended_variance_model = recommended_variance_model,
    variance_model = resolved_variance_model,
    variance_model_source = variance_source,
    requested_fraction_transform = fraction_transform,
    fraction_transform = resolved_fraction_transform
  )
}

.omix_limma_transform_relative_fractions <- function(expression, method, pseudocount) {
  tolerance <- sqrt(.Machine$double.eps)
  if (any(expression < -tolerance | expression > 1 + tolerance)) {
    stop("CIBERSORT relative fractions must be between 0 and 1 before transformation.", call. = FALSE)
  }
  expression <- pmin(pmax(expression, 0), 1)
  sample_sums <- colSums(expression)
  if (any(abs(sample_sums - 1) > 0.02)) {
    warning(
      "At least one CIBERSORT relative-fraction sample does not sum to approximately 1; verify whether the input contains relative fractions or absolute scores.",
      call. = FALSE
    )
  }
  if (identical(method, "none")) {
    warning("Untransformed relative fractions were requested explicitly; inference may be sensitive to bounded, nonconstant variance.", call. = FALSE)
    return(expression)
  }
  if (identical(method, "arcsin_sqrt")) return(asin(sqrt(expression)))
  if (!is.numeric(pseudocount) || length(pseudocount) != 1L || !is.finite(pseudocount) || pseudocount <= 0 || pseudocount >= 0.5) {
    stop("fraction_pseudocount must be one finite number greater than 0 and less than 0.5.", call. = FALSE)
  }
  clipped <- pmin(pmax(expression, pseudocount), 1 - pseudocount)
  log(clipped / (1 - clipped))
}

.omix_limma_collapse_features <- function(dataset, gene_names_column, sample_ids, method) {
  feature_ids <- as.character(dataset[[gene_names_column]])
  if (anyNA(feature_ids) || any(!nzchar(feature_ids))) {
    stop("Feature identifiers must be non-missing and non-empty.", call. = FALSE)
  }
  summary_function <- match.fun(method)
  feature_order <- unique(feature_ids)
  feature_rows <- split(seq_len(nrow(dataset)), factor(feature_ids, levels = feature_order))
  values <- vapply(
    feature_rows,
    function(rows) {
      vapply(
        sample_ids,
        function(sample_id) summary_function(dataset[rows, sample_id]),
        numeric(1)
      )
    },
    numeric(length(sample_ids))
  )
  if (is.null(dim(values))) values <- matrix(values, nrow = 1L)
  expression <- t(values)
  rownames(expression) <- feature_order
  colnames(expression) <- sample_ids
  storage.mode(expression) <- "double"
  expression
}

.omix_limma_rewrite_contrast <- function(contrast, label_map) {
  rewritten <- contrast
  changed_labels <- names(label_map)[names(label_map) != unname(label_map)]
  if (length(changed_labels) == 0L) return(rewritten)

  # A non-syntactic label can always be referenced explicitly with backticks.
  # Numeric group labels are also accepted without backticks so an upstream
  # 0/1 grouping can use the natural contrast expression `1-0`.
  changed_labels <- changed_labels[order(nchar(changed_labels), decreasing = TRUE)]
  for (label in changed_labels) {
    safe_label <- unname(label_map[[label]])
    rewritten <- gsub(paste0("`", label, "`"), safe_label, rewritten, fixed = TRUE)
    if (grepl("^[0-9]+(?:\\.[0-9]+)?$", label, perl = TRUE)) {
      numeric_token <- paste0(
        "(?<![[:alnum:]_.])", label, "(?![[:alnum:]_.])"
      )
      rewritten <- gsub(numeric_token, safe_label, rewritten, perl = TRUE)
    }
  }
  rewritten
}

.omix_limma_group_counts <- function(metadata, contrast_variable_columns) {
  labels <- if (length(contrast_variable_columns) > 1L) {
    paste0(
      metadata[[contrast_variable_columns[[1L]]]], ".",
      metadata[[contrast_variable_columns[[2L]]]]
    )
  } else {
    metadata[[contrast_variable_columns[[1L]]]]
  }
  table(factor(labels))
}

.omix_limma_format_group_counts <- function(group_counts) {
  paste0(names(group_counts), "=", as.integer(group_counts), collapse = ", ")
}

.omix_limma_resolve_contrasts <- function(contrasts, group_counts) {
  requested <- .omix_limma_as_character(contrasts, "contrasts", allow_empty = TRUE)
  if (length(requested) > 0L) {
    return(list(requested = requested, resolved = requested, source = "explicit"))
  }

  estimable_groups <- names(group_counts)[group_counts > 1L]
  if (length(estimable_groups) == 2L) {
    inferred <- paste0(estimable_groups[[2L]], "-", estimable_groups[[1L]])
    return(list(requested = character(), resolved = inferred, source = "inferred"))
  }

  stop(
    "No contrast was supplied and a single comparison cannot be inferred. ",
    "Modeled group replicate counts: ", .omix_limma_format_group_counts(group_counts), ". ",
    "Blank contrast inference requires exactly two groups with at least two samples each; ",
    "otherwise provide an explicit contrast such as B-A.",
    call. = FALSE
  )
}

.omix_limma_design <- function(metadata, sample_names_column, contrast_variable_columns, covariate_columns) {
  if (length(contrast_variable_columns) > 1L) {
    metadata$contmerge <- paste0(
      metadata[[contrast_variable_columns[[1L]]]], ".",
      metadata[[contrast_variable_columns[[2L]]]]
    )
  } else {
    metadata$contmerge <- metadata[[contrast_variable_columns[[1L]]]]
  }
  metadata$contmerge <- factor(metadata$contmerge)
  original_group_labels <- levels(metadata$contmerge)
  safe_group_labels <- make.names(original_group_labels, unique = TRUE)
  group_label_map <- stats::setNames(safe_group_labels, original_group_labels)
  for (column in covariate_columns) metadata[[column]] <- factor(metadata[[column]])
  rownames(metadata) <- metadata[[sample_names_column]]
  design_formula <- if (length(covariate_columns) > 0L) {
    stats::as.formula(paste("~0 + contmerge +", paste(covariate_columns, collapse = " + ")))
  } else {
    stats::as.formula("~0 + contmerge")
  }
  design <- stats::model.matrix(design_formula, metadata)
  for (column in contrast_variable_columns) colnames(design) <- sub(paste0("^", column), "", colnames(design))
  colnames(design) <- gsub(":", ".", colnames(design), fixed = TRUE)
  colnames(design) <- sub("contmerge", "", colnames(design), fixed = TRUE)
  group_columns <- seq_along(original_group_labels)
  colnames(design)[group_columns] <- safe_group_labels
  list(
    metadata = metadata,
    design = design,
    formula = design_formula,
    group_label_map = group_label_map
  )
}

.omix_limma_signed_fold_change <- function(coefficients) {
  fold_change <- 2^coefficients
  fold_change <- apply(fold_change, c(1L, 2L), function(value) ifelse(value < 1, -1 / value, value))
  if (is.null(dim(fold_change))) fold_change <- matrix(fold_change, ncol = 1L, dimnames = dimnames(coefficients))
  fold_change
}

#' Run limma analysis on a declared continuous matrix.
#'
#' The public argument names and defaults through second_pvalue_threshold retain
#' the established analysis interface. The additional declarations make the
#' measurement scale, input type, transformation, and variance assumption
#' explicit without changing direct-function defaults for existing callers.
Limma_Analysis <- function(
    Dataset,
    Metadata_Table,
    sample_names_column,
    samples_to_include,
    gene_names_column,
    contrast_variable_columns,
    contrasts = NULL,
    covariate_columns = NULL,
    donor_variable_column = NULL,
    summarization_method = "mean",
    return_matrix = TRUE,
    fold_change_threshold = 1.2,
    first_pvalue_threshold = 0.05,
    second_pvalue_threshold = 0.01,
    input_kind = c("log2_expression", "enrichment_score", "continuous_score"),
    variance_model = c("ebayes", "ebayes_trend"),
    input_data_type = "auto",
    measurement_scale = "",
    fraction_transform = c("auto", "none", "arcsin_sqrt", "logit"),
    fraction_pseudocount = 1e-04) {
  .omix_limma_require("limma")
  input_kind <- match.arg(input_kind)
  variance_model <- match.arg(variance_model)
  input_data_type <- match.arg(input_data_type, c("auto", .omix_limma_input_data_types))
  fraction_transform <- match.arg(fraction_transform)
  input_contract <- omix_limma_resolve_input_contract(
    input_data_type = input_data_type,
    input_kind = input_kind,
    variance_model = variance_model,
    fraction_transform = fraction_transform
  )
  input_kind <- input_contract$input_kind
  variance_model <- input_contract$variance_model
  input_data_type <- input_contract$input_data_type
  fraction_transform <- input_contract$fraction_transform
  measurement_scale <- trimws(as.character(measurement_scale))
  if (length(measurement_scale) != 1L) stop("measurement_scale must contain one value.", call. = FALSE)
  if (identical(input_data_type, "other_continuous") && !nzchar(measurement_scale)) {
    stop("measurement_scale is required for input_data_type=other_continuous.", call. = FALSE)
  }
  if (!identical(input_data_type, "cibersort_relative_fractions") && !identical(fraction_transform, "none")) {
    stop("fraction_transform is only valid for cibersort_relative_fractions.", call. = FALSE)
  }
  dataset <- as.data.frame(Dataset, check.names = FALSE, stringsAsFactors = FALSE)
  metadata <- as.data.frame(Metadata_Table, check.names = FALSE, stringsAsFactors = FALSE)
  contrast_variable_columns <- .omix_limma_as_character(contrast_variable_columns, "contrast_variable_columns")
  if (length(contrast_variable_columns) > 2L) stop("contrast_variable_columns may contain one or two columns.", call. = FALSE)
  contrasts <- .omix_limma_as_character(contrasts, "contrasts", allow_empty = TRUE)
  covariate_columns <- .omix_limma_as_character(covariate_columns, "covariate_columns", allow_empty = TRUE)
  donor_variable_column <- .omix_limma_as_character(donor_variable_column, "donor_variable_column", allow_empty = TRUE)
  if (length(donor_variable_column) > 1L) stop("donor_variable_column may name at most one metadata column.", call. = FALSE)
  samples_to_include <- .omix_limma_as_character(samples_to_include, "samples_to_include")
  if (!is.character(gene_names_column) || length(gene_names_column) != 1L || !gene_names_column %in% names(dataset)) {
    stop("gene_names_column must name a column in Dataset.", call. = FALSE)
  }
  if (!is.character(sample_names_column) || length(sample_names_column) != 1L || !sample_names_column %in% names(metadata)) {
    stop("sample_names_column must name a column in Metadata_Table.", call. = FALSE)
  }
  if (!all(make.names(names(dataset)) == names(dataset))) {
    invalid <- names(dataset)[make.names(names(dataset)) != names(dataset)]
    stop("Dataset has non-syntactic column names: ", paste(invalid, collapse = ", "), ".", call. = FALSE)
  }
  required_metadata <- unique(c(sample_names_column, contrast_variable_columns, covariate_columns, donor_variable_column))
  missing_metadata <- setdiff(required_metadata, names(metadata))
  if (length(missing_metadata) > 0L) stop("Metadata_Table lacks required column(s): ", paste(missing_metadata, collapse = ", "), ".", call. = FALSE)
  missing_samples <- setdiff(samples_to_include, names(dataset))
  if (length(missing_samples) > 0L) stop("Dataset lacks selected sample column(s): ", paste(missing_samples, collapse = ", "), ".", call. = FALSE)
  metadata[[sample_names_column]] <- as.character(metadata[[sample_names_column]])
  if (anyDuplicated(metadata[[sample_names_column]])) stop("Metadata_Table must contain unique sample IDs for direct limma analysis.", call. = FALSE)
  metadata <- metadata[metadata[[sample_names_column]] %in% samples_to_include, , drop = FALSE]
  if (nrow(metadata) != length(samples_to_include)) {
    missing_metadata_samples <- setdiff(samples_to_include, metadata[[sample_names_column]])
    stop("Metadata_Table lacks selected sample ID(s): ", paste(missing_metadata_samples, collapse = ", "), ".", call. = FALSE)
  }
  metadata <- metadata[match(samples_to_include, metadata[[sample_names_column]]), , drop = FALSE]
  if (anyNA(metadata[, required_metadata, drop = FALSE])) stop("Required metadata values must be non-missing.", call. = FALSE)

  group_counts <- .omix_limma_group_counts(metadata, contrast_variable_columns)
  contrast_details <- .omix_limma_resolve_contrasts(contrasts, group_counts)
  contrasts <- contrast_details$resolved

  expression <- .omix_limma_collapse_features(dataset, gene_names_column, samples_to_include, summarization_method)
  if (!all(is.finite(expression))) stop("The selected continuous matrix contains non-finite values after duplicate-feature summarization.", call. = FALSE)
  if (identical(input_data_type, "cibersort_relative_fractions")) {
    expression <- .omix_limma_transform_relative_fractions(
      expression,
      method = fraction_transform,
      pseudocount = fraction_pseudocount
    )
  }
  design_details <- .omix_limma_design(metadata, sample_names_column, contrast_variable_columns, covariate_columns)
  metadata <- design_details$metadata
  design <- design_details$design
  rewritten_contrasts <- vapply(
    contrasts,
    .omix_limma_rewrite_contrast,
    character(1),
    label_map = design_details$group_label_map,
    USE.NAMES = FALSE
  )
  non_estimable <- colnames(design)[colSums(design) %in% c(0, 1)]
  if (length(non_estimable) > 0L) {
    design <- design[, !colnames(design) %in% non_estimable, drop = FALSE]
    if (ncol(design) == 0L) stop("No estimable design terms remain after singleton removal.", call. = FALSE)
    expression <- expression[, rownames(design), drop = FALSE]
    metadata <- metadata[rownames(design), , drop = FALSE]
  }
  if (qr(design)$rank < ncol(design)) stop("The design matrix is rank deficient; revise confounded groups or covariates.", call. = FALSE)
  contrast_ok <- vapply(rewritten_contrasts, function(contrast) tryCatch({ limma::makeContrasts(contrasts = contrast, levels = design); TRUE }, error = function(error) FALSE), logical(1))
  if (!all(contrast_ok)) {
    stop(
      "At least one requested contrast is not estimable from the design matrix. ",
      "Modeled group replicate counts: ", .omix_limma_format_group_counts(group_counts), ".",
      call. = FALSE
    )
  }

  if (length(donor_variable_column) == 1L) {
    donor <- metadata[[donor_variable_column]]
    if (all(table(donor) < 2L)) stop("donor_variable_column was supplied, but no donor has repeated modeled profiles. Omit it for an ordinary linear model.", call. = FALSE)
    correlation_fit <- limma::duplicateCorrelation(expression, design, block = donor)
    fit <- limma::lmFit(expression, design, block = donor, correlation = correlation_fit$consensus.correlation)
    model_type <- "repeated_measures"
  } else {
    correlation_fit <- NULL
    fit <- limma::lmFit(expression, design)
    model_type <- "linear"
  }
  contrast_matrix <- limma::makeContrasts(contrasts = rewritten_contrasts, levels = design)
  group_design_rows <- intersect(unname(design_details$group_label_map), rownames(contrast_matrix))
  valid_group_comparisons <- vapply(seq_len(ncol(contrast_matrix)), function(index) {
    coefficients <- contrast_matrix[group_design_rows, index]
    any(coefficients > 1e-12) && any(coefficients < -1e-12)
  }, logical(1))
  if (!all(valid_group_comparisons)) {
    invalid <- contrasts[!valid_group_comparisons]
    stop(
      "Contrast expression(s) do not compare modeled group coefficients: ",
      paste(invalid, collapse = ", "), ". Available groups: ",
      paste(names(group_counts), collapse = ", "), ".",
      call. = FALSE
    )
  }
  colnames(contrast_matrix) <- contrasts
  fit <- limma::contrasts.fit(fit, contrast_matrix)
  variance_diagnostic <- data.frame(
    Feature = rownames(expression),
    Average_Signal = rowMeans(expression),
    Residual_SD = fit$sigma,
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  fit <- limma::eBayes(fit, trend = identical(variance_model, "ebayes_trend"))

  group_means <- lapply(colnames(design), function(group_name) rowMeans(expression[, which(design[, group_name] == 1), drop = FALSE]))
  display_design_names <- colnames(design)
  group_display <- stats::setNames(
    names(design_details$group_label_map),
    unname(design_details$group_label_map)
  )
  mapped_groups <- display_design_names %in% names(group_display)
  display_design_names[mapped_groups] <- unname(group_display[display_design_names[mapped_groups]])
  names(group_means) <- paste0(display_design_names, "_Mean")
  group_se <- lapply(colnames(design), function(group_name) {
    values <- expression[, which(design[, group_name] == 1), drop = FALSE]
    apply(values, 1L, function(value) stats::sd(value) / sqrt(sum(!is.na(value))))
  })
  names(group_se) <- paste0(display_design_names, "_SE")
  coefficients <- fit$coefficients
  standard_errors <- sqrt(fit$s2.post) * fit$stdev.unscaled
  p_values <- fit$p.value
  adjusted_p_values <- apply(p_values, 2L, stats::p.adjust, method = "BH")
  if (is.null(dim(adjusted_p_values))) adjusted_p_values <- matrix(adjusted_p_values, ncol = 1L, dimnames = dimnames(p_values))
  if (identical(input_kind, "log2_expression")) {
    fold_changes <- .omix_limma_signed_fold_change(coefficients)
    colnames(fold_changes) <- paste0(colnames(coefficients), "_FC")
    colnames(coefficients) <- paste0(colnames(coefficients), "_logFC")
    result_effects <- cbind(fold_changes, coefficients)
  } else {
    colnames(coefficients) <- paste0(colnames(coefficients), "_effect")
    result_effects <- coefficients
  }
  colnames(standard_errors) <- paste0(colnames(fit$coefficients), "_SE")
  colnames(fit$t) <- paste0(colnames(fit$t), "_tstat")
  colnames(p_values) <- paste0(colnames(p_values), "_pval")
  colnames(adjusted_p_values) <- paste0(colnames(fit$coefficients), "_adjpval")
  results <- as.data.frame(cbind(do.call(cbind, group_means), do.call(cbind, group_se), result_effects, standard_errors, fit$t, p_values, adjusted_p_values), check.names = FALSE)
  results <- data.frame(Gene = rownames(expression), results, check.names = FALSE, stringsAsFactors = FALSE)
  if (isTRUE(return_matrix)) {
    results <- data.frame(results, as.data.frame(expression, check.names = FALSE), check.names = FALSE, stringsAsFactors = FALSE)
  }
  colnames(results) <- gsub(" - ", "-", colnames(results), fixed = TRUE)
  colnames(results) <- gsub("\\(", "", gsub("\\)", "", colnames(results)))
  attr(results, "omix_limma_run") <- list(
    input_kind = input_kind, input_data_type = input_data_type,
    measurement_scale = measurement_scale,
    fraction_transform = fraction_transform,
    fraction_pseudocount = if (identical(fraction_transform, "logit")) fraction_pseudocount else NA_real_,
    variance_model = variance_model, model_type = model_type,
    design_formula = paste(deparse(design_details$formula), collapse = " "),
    group_label_mapping = design_details$group_label_map,
    group_replicate_counts = group_counts,
    requested_contrasts = contrast_details$requested,
    contrasts = contrasts,
    contrast_source = contrast_details$source,
    contrast_variable_columns = contrast_variable_columns, covariate_columns = covariate_columns,
    donor_variable_column = donor_variable_column,
    consensus_correlation = if (is.null(correlation_fit)) NA_real_ else correlation_fit$consensus.correlation,
    genes_modelled = nrow(expression), samples_modelled = ncol(expression),
    summarization_method = summarization_method, fold_change_threshold = fold_change_threshold,
    first_pvalue_threshold = first_pvalue_threshold, second_pvalue_threshold = second_pvalue_threshold
  )
  attr(results, "omix_limma_variance_diagnostic") <- variance_diagnostic
  results
}

omix_limma_analysis <- Limma_Analysis
