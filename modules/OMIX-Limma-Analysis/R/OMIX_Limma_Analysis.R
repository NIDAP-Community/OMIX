#' Template-preserving limma analysis for declared continuous matrices.
#'
#' This module is a portable extraction of the analytical core of
#' `Templates/Limma_Analysis_v41.R`. It intentionally retains the template's
#' data alignment, duplicate-feature summary, design, contrast, donor-blocking,
#' empirical-Bayes, and result-column conventions. Interactive notebook plots,
#' Sankey diagrams, and printed tables are replaced by explicit CLI outputs.
#'
#' @param Dataset A feature-by-sample data frame with one feature-ID column.
#' @param Metadata_Table Sample metadata with one row per supplied sample.
#' @param sample_names_column Metadata sample-ID column.
#' @param samples_to_include Sample IDs to model.
#' @param gene_names_column Feature-ID column in Dataset.
#' @param contrast_variable_columns One or two metadata columns defining groups.
#' @param contrasts limma contrast expressions.
#' @param covariate_columns Optional fixed-effect metadata columns.
#' @param donor_variable_column Optional repeated-measure blocking column.
#' @param summarization_method Duplicate-feature summary, as in the template.
#' @param return_matrix Append modeled sample values to the result table.
#' @param fold_change_threshold Preserved template threshold recorded as provenance.
#' @param first_pvalue_threshold Preserved template threshold recorded as provenance.
#' @param second_pvalue_threshold Preserved template threshold recorded as provenance.
#' @param input_kind Matrix interpretation: log2_expression, enrichment_score,
#'   or continuous_score. Raw counts and untransformed proportions are rejected.
#' @param variance_model eBayes reproduces the template default. ebayes_trend is
#'   an explicit limma-trend option for a declared mean-dependent variance model.
#' @return A template-compatible result data frame with OMIX provenance attached.

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
  list(metadata = metadata, design = design, formula = design_formula)
}

.omix_limma_signed_fold_change <- function(coefficients) {
  fold_change <- 2^coefficients
  fold_change <- apply(fold_change, c(1L, 2L), function(value) ifelse(value < 1, -1 / value, value))
  if (is.null(dim(fold_change))) fold_change <- matrix(fold_change, ncol = 1L, dimnames = dimnames(coefficients))
  fold_change
}

#' Run the template-compatible limma analysis.
#'
#' The public argument names and defaults through second_pvalue_threshold match
#' Limma_Analysis_v41.R. `input_kind` and `variance_model` make the scale and
#' variance assumption explicit without changing the template-equivalent default.
Limma_Analysis <- function(
    Dataset,
    Metadata_Table,
    sample_names_column,
    samples_to_include,
    gene_names_column,
    contrast_variable_columns,
    contrasts,
    covariate_columns = NULL,
    donor_variable_column = NULL,
    summarization_method = "mean",
    return_matrix = TRUE,
    fold_change_threshold = 1.2,
    first_pvalue_threshold = 0.05,
    second_pvalue_threshold = 0.01,
    input_kind = c("log2_expression", "enrichment_score", "continuous_score"),
    variance_model = c("ebayes", "ebayes_trend")) {
  .omix_limma_require("limma")
  input_kind <- match.arg(input_kind)
  variance_model <- match.arg(variance_model)
  dataset <- as.data.frame(Dataset, check.names = FALSE, stringsAsFactors = FALSE)
  metadata <- as.data.frame(Metadata_Table, check.names = FALSE, stringsAsFactors = FALSE)
  contrast_variable_columns <- .omix_limma_as_character(contrast_variable_columns, "contrast_variable_columns")
  if (length(contrast_variable_columns) > 2L) stop("contrast_variable_columns may contain one or two columns.", call. = FALSE)
  contrasts <- .omix_limma_as_character(contrasts, "contrasts")
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
    stop("Dataset has non-syntactic column names, as rejected by Limma_Analysis_v41.R: ", paste(invalid, collapse = ", "), ".", call. = FALSE)
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

  expression <- .omix_limma_collapse_features(dataset, gene_names_column, samples_to_include, summarization_method)
  if (!all(is.finite(expression))) stop("The selected continuous matrix contains non-finite values after duplicate-feature summarization.", call. = FALSE)
  design_details <- .omix_limma_design(metadata, sample_names_column, contrast_variable_columns, covariate_columns)
  metadata <- design_details$metadata
  design <- design_details$design
  non_estimable <- colnames(design)[colSums(design) %in% c(0, 1)]
  if (length(non_estimable) > 0L) {
    design <- design[, !colnames(design) %in% non_estimable, drop = FALSE]
    if (ncol(design) == 0L) stop("No estimable design terms remain after template-compatible singleton removal.", call. = FALSE)
    expression <- expression[, rownames(design), drop = FALSE]
    metadata <- metadata[rownames(design), , drop = FALSE]
  }
  if (qr(design)$rank < ncol(design)) stop("The design matrix is rank deficient; revise confounded groups or covariates.", call. = FALSE)
  contrast_ok <- vapply(contrasts, function(contrast) tryCatch({ limma::makeContrasts(contrasts = contrast, levels = design); TRUE }, error = function(error) FALSE), logical(1))
  if (!all(contrast_ok)) stop("At least one requested contrast is not estimable from the design matrix.", call. = FALSE)

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
  contrast_matrix <- limma::makeContrasts(contrasts = contrasts, levels = design)
  fit <- limma::contrasts.fit(fit, contrast_matrix)
  fit <- limma::eBayes(fit, trend = identical(variance_model, "ebayes_trend"))

  group_means <- lapply(colnames(design), function(group_name) rowMeans(expression[, which(design[, group_name] == 1), drop = FALSE]))
  names(group_means) <- paste0(colnames(design), "_Mean")
  group_se <- lapply(colnames(design), function(group_name) {
    values <- expression[, which(design[, group_name] == 1), drop = FALSE]
    apply(values, 1L, function(value) stats::sd(value) / sqrt(sum(!is.na(value))))
  })
  names(group_se) <- paste0(colnames(design), "_SE")
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
    input_kind = input_kind, variance_model = variance_model, model_type = model_type,
    design_formula = paste(deparse(design_details$formula), collapse = " "),
    contrast_variable_columns = contrast_variable_columns, covariate_columns = covariate_columns,
    donor_variable_column = donor_variable_column,
    consensus_correlation = if (is.null(correlation_fit)) NA_real_ else correlation_fit$consensus.correlation,
    genes_modelled = nrow(expression), samples_modelled = ncol(expression),
    summarization_method = summarization_method, fold_change_threshold = fold_change_threshold,
    first_pvalue_threshold = first_pvalue_threshold, second_pvalue_threshold = second_pvalue_threshold
  )
  results
}

omix_limma_analysis <- Limma_Analysis
