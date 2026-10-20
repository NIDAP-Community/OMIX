#!/usr/bin/env Rscript

test_args <- commandArgs(FALSE)
test_file <- sub("^--file=", "", test_args[grepl("^--file=", test_args)])
module_dir <- normalizePath(file.path(dirname(test_file), ".."))
source(file.path(module_dir, "R", "OMIX_Limma_Analysis.R"))

expression <- data.frame(
  GeneName = c("Gene1", "Gene2", "Gene3"),
  A1 = c(5.0, 6.2, 7.1), A2 = c(5.1, 6.0, 7.3), A3 = c(4.9, 6.1, 7.2),
  B1 = c(6.0, 6.4, 7.0), B2 = c(6.1, 6.5, 7.1), B3 = c(5.9, 6.3, 7.2),
  check.names = FALSE
)
metadata <- data.frame(
  Sample = c("A1", "A2", "A3", "B1", "B2", "B3"),
  Group = c("A", "A", "A", "B", "B", "B"),
  stringsAsFactors = FALSE
)

result <- omix_limma_analysis(
  Dataset = expression,
  Metadata_Table = metadata,
  sample_names_column = "Sample",
  samples_to_include = metadata$Sample,
  gene_names_column = "GeneName",
  contrast_variable_columns = "Group",
  contrasts = "B-A"
)

expected_columns <- c(
  "Gene", "A_Mean", "B_Mean", "A_SE", "B_SE", "B-A_FC", "B-A_logFC",
  "B-A_SE", "B-A_tstat", "B-A_pval", "B-A_adjpval", metadata$Sample
)
stopifnot(identical(names(result), expected_columns))
stopifnot(isTRUE(all.equal(result[["B-A_logFC"]], c(1, 0.3, -0.1), tolerance = 1e-12)))
stopifnot(isTRUE(all.equal(result[["B-A_FC"]], c(2, 2^0.3, -1 / 2^-0.1), tolerance = 1e-12)))
stopifnot(identical(attr(result, "omix_limma_run")$variance_model, "ebayes"))
stopifnot(identical(attr(result, "omix_limma_run")$model_type, "linear"))
stopifnot(identical(attr(result, "omix_limma_run")$input_data_type, "normalized_bulk_expression"))
variance_diagnostic <- attr(result, "omix_limma_variance_diagnostic")
stopifnot(identical(names(variance_diagnostic), c("Feature", "Average_Signal", "Residual_SD")))
stopifnot(nrow(variance_diagnostic) == nrow(expression))

# A blank contrast is safe only when exactly one replicated two-group
# comparison exists. Its direction follows the deterministic factor order.
inferred_result <- omix_limma_analysis(
  Dataset = expression,
  Metadata_Table = metadata,
  sample_names_column = "Sample",
  samples_to_include = metadata$Sample,
  gene_names_column = "GeneName",
  contrast_variable_columns = "Group",
  contrasts = NULL
)
stopifnot("B-A_logFC" %in% names(inferred_result))
stopifnot(identical(attr(inferred_result, "omix_limma_run")$contrast_source, "inferred"))
stopifnot(identical(attr(inferred_result, "omix_limma_run")$contrasts, "B-A"))
stopifnot(length(attr(inferred_result, "omix_limma_run")$requested_contrasts) == 0L)

three_group_metadata <- transform(metadata, Group = c("A", "A", "B", "B", "C", "C"))
ambiguous_blank <- tryCatch(
  omix_limma_analysis(
    Dataset = expression,
    Metadata_Table = three_group_metadata,
    sample_names_column = "Sample",
    samples_to_include = three_group_metadata$Sample,
    gene_names_column = "GeneName",
    contrast_variable_columns = "Group",
    contrasts = NULL
  ),
  error = identity
)
stopifnot(inherits(ambiguous_blank, "error"))
stopifnot(grepl("A=2, B=2, C=2", conditionMessage(ambiguous_blank), fixed = TRUE))

singleton_metadata <- transform(metadata, Group = LETTERS[seq_len(nrow(metadata))])
singleton_blank <- tryCatch(
  omix_limma_analysis(
    Dataset = expression,
    Metadata_Table = singleton_metadata,
    sample_names_column = "Sample",
    samples_to_include = singleton_metadata$Sample,
    gene_names_column = "GeneName",
    contrast_variable_columns = "Group",
    contrasts = NULL
  ),
  error = identity
)
stopifnot(inherits(singleton_blank, "error"))
stopifnot(grepl("A=1, B=1", conditionMessage(singleton_blank), fixed = TRUE))

# Numeric arithmetic must not be accepted as a contrast unless those numeric
# labels are actual modeled groups.
mismatched_numeric_contrast <- tryCatch(
  omix_limma_analysis(
    Dataset = expression,
    Metadata_Table = metadata,
    sample_names_column = "Sample",
    samples_to_include = metadata$Sample,
    gene_names_column = "GeneName",
    contrast_variable_columns = "Group",
    contrasts = "1-0"
  ),
  error = identity
)
stopifnot(inherits(mismatched_numeric_contrast, "error"))
stopifnot(grepl("do not compare modeled group coefficients", conditionMessage(mismatched_numeric_contrast), fixed = TRUE))

reference_design <- stats::model.matrix(~0 + Group, data = metadata)
colnames(reference_design) <- sub("^Group", "", colnames(reference_design))
reference_fit <- limma::lmFit(as.matrix(expression[, metadata$Sample]), reference_design)
reference_fit <- limma::contrasts.fit(reference_fit, limma::makeContrasts(`B-A` = B - A, levels = reference_design))
reference_fit <- limma::eBayes(reference_fit)
stopifnot(isTRUE(all.equal(result[["B-A_logFC"]], as.numeric(reference_fit$coefficients[, 1L]), tolerance = 1e-12)))
stopifnot(isTRUE(all.equal(result[["B-A_pval"]], as.numeric(reference_fit$p.value[, 1L]), tolerance = 1e-12)))

# Numeric upstream group labels must remain usable as their natural contrast
# expression even though limma requires syntactically valid design names.
numeric_metadata <- transform(metadata, Group = ifelse(Group == "A", "0", "1"))
numeric_result <- omix_limma_analysis(
  Dataset = expression,
  Metadata_Table = numeric_metadata,
  sample_names_column = "Sample",
  samples_to_include = numeric_metadata$Sample,
  gene_names_column = "GeneName",
  contrast_variable_columns = "Group",
  contrasts = "1-0"
)
stopifnot(all(c(
  "0_Mean", "1_Mean", "1-0_FC", "1-0_logFC", "1-0_pval", "1-0_adjpval"
) %in% names(numeric_result)))
stopifnot(isTRUE(all.equal(
  numeric_result[["1-0_logFC"]],
  result[["B-A_logFC"]],
  tolerance = 1e-12
)))
stopifnot(identical(
  unname(attr(numeric_result, "omix_limma_run")$group_label_mapping),
  c("X0", "X1")
))

# When the shared Templates checkout is available, compare the portable
# extraction directly with the source template. The core test above remains
# self-contained for a standalone OMIX checkout.
template_file <- Sys.getenv(
  "OMIX_LIMMA_TEMPLATE",
  unset = file.path(dirname(dirname(dirname(module_dir))), "Templates", "Limma_Analysis_v41.R")
)
template_packages <- c("dplyr", "tidyr", "ggplot2", "gridExtra", "reshape2", "plotly")
if (file.exists(template_file) && all(vapply(template_packages, requireNamespace, logical(1), quietly = TRUE))) {
  legacy_environment <- new.env(parent = globalenv())
  sys.source(template_file, envir = legacy_environment)
  original_working_directory <- getwd()
  template_output_directory <- tempfile("omix-limma-template-")
  dir.create(template_output_directory)
  setwd(template_output_directory)
  on.exit(setwd(original_working_directory), add = TRUE)
  legacy_result <- legacy_environment$Limma_Analysis(
    Dataset = expression,
    Metadata_Table = metadata,
    sample_names_column = "Sample",
    samples_to_include = metadata$Sample,
    gene_names_column = "GeneName",
    contrast_variable_columns = "Group",
    contrasts = "B-A"
  )
  stopifnot(isTRUE(all.equal(result, legacy_result, check.attributes = FALSE, tolerance = 1e-12)))
}

score_result <- omix_limma_analysis(
  Dataset = expression,
  Metadata_Table = metadata,
  sample_names_column = "Sample",
  samples_to_include = metadata$Sample,
  gene_names_column = "GeneName",
  contrast_variable_columns = "Group",
  contrasts = "B-A",
  input_kind = "enrichment_score"
)
stopifnot("B-A_effect" %in% names(score_result))
stopifnot(!"B-A_logFC" %in% names(score_result))
stopifnot(isTRUE(all.equal(score_result[["B-A_effect"]], result[["B-A_logFC"]], tolerance = 1e-12)))

trend_result <- omix_limma_analysis(
  Dataset = expression,
  Metadata_Table = metadata,
  sample_names_column = "Sample",
  samples_to_include = metadata$Sample,
  gene_names_column = "GeneName",
  contrast_variable_columns = "Group",
  contrasts = "B-A",
  variance_model = "ebayes_trend"
)
stopifnot(identical(attr(trend_result, "omix_limma_run")$variance_model, "ebayes_trend"))

# Auto resolution is contract-based rather than guessed from matrix values.
sct_contract <- omix_limma_resolve_input_contract(
  input_data_type = "auto",
  input_kind = "auto",
  variance_model = "auto",
  manifest_matrix_type = "sctransform_mean_log2_expression",
  manifest_recommended_variance_model = "ebayes_trend"
)
stopifnot(identical(sct_contract$input_data_type, "sctransform_mean_expression"))
stopifnot(identical(sct_contract$input_kind, "log2_expression"))
stopifnot(identical(sct_contract$variance_model, "ebayes_trend"))
stopifnot(identical(sct_contract$input_data_type_source, "manifest"))

manifest_type_mismatch <- tryCatch(
  omix_limma_resolve_input_contract(
    input_data_type = "harmony_corrected_mean_expression",
    manifest_matrix_type = "sctransform_mean_log2_expression",
    variance_model = "auto"
  ),
  error = identity
)
stopifnot(inherits(manifest_type_mismatch, "error"))
stopifnot(grepl("does not match the manifest", conditionMessage(manifest_type_mismatch), fixed = TRUE))

harmony_contract <- omix_limma_resolve_input_contract(
  input_data_type = "harmony_corrected_mean_expression",
  variance_model = "auto"
)
stopifnot(identical(harmony_contract$variance_model, "ebayes"))

gsva_contract <- omix_limma_resolve_input_contract(
  input_data_type = "gsva_enrichment_scores",
  variance_model = "auto"
)
stopifnot(identical(gsva_contract$input_kind, "enrichment_score"))
stopifnot(identical(gsva_contract$variance_model, "ebayes"))

other_auto <- tryCatch(
  omix_limma_resolve_input_contract(
    input_data_type = "other_continuous",
    variance_model = "auto"
  ),
  error = identity
)
stopifnot(inherits(other_auto, "error"))
stopifnot(grepl("Select ebayes or ebayes_trend", conditionMessage(other_auto), fixed = TRUE))

# Fraction-only CIBERSORT tables use a boundary-safe arcsine-square-root
# transform by default. An explicit logit remains available when the user can
# justify and report its boundary pseudocount.
fraction_expression <- data.frame(
  GeneName = c("B_cells", "T_cells", "Myeloid"),
  A1 = c(0.20, 0.50, 0.30), A2 = c(0.10, 0.55, 0.35), A3 = c(0.00, 0.60, 0.40),
  B1 = c(0.40, 0.40, 0.20), B2 = c(0.35, 0.45, 0.20), B3 = c(0.30, 0.50, 0.20),
  check.names = FALSE
)
fraction_contract <- omix_limma_resolve_input_contract(
  input_data_type = "cibersort_relative_fractions",
  variance_model = "auto",
  fraction_transform = "auto"
)
stopifnot(identical(fraction_contract$input_kind, "continuous_score"))
stopifnot(identical(fraction_contract$variance_model, "ebayes"))
stopifnot(identical(fraction_contract$fraction_transform, "arcsin_sqrt"))
fraction_result <- omix_limma_analysis(
  Dataset = fraction_expression,
  Metadata_Table = metadata,
  sample_names_column = "Sample",
  samples_to_include = metadata$Sample,
  gene_names_column = "GeneName",
  contrast_variable_columns = "Group",
  contrasts = "B-A",
  input_kind = fraction_contract$input_kind,
  input_data_type = fraction_contract$input_data_type,
  fraction_transform = fraction_contract$fraction_transform,
  variance_model = fraction_contract$variance_model
)
stopifnot("B-A_effect" %in% names(fraction_result))
stopifnot(all(is.finite(fraction_result$A1)))
stopifnot(isTRUE(all.equal(fraction_result$A1, asin(sqrt(fraction_expression$A1)), tolerance = 1e-12)))

missing_other_scale <- tryCatch(
  omix_limma_analysis(
    Dataset = expression,
    Metadata_Table = metadata,
    sample_names_column = "Sample",
    samples_to_include = metadata$Sample,
    gene_names_column = "GeneName",
    contrast_variable_columns = "Group",
    contrasts = "B-A",
    input_kind = "continuous_score",
    input_data_type = "other_continuous",
    variance_model = "ebayes"
  ),
  error = identity
)
stopifnot(inherits(missing_other_scale, "error"))
stopifnot(grepl("measurement_scale is required", conditionMessage(missing_other_scale), fixed = TRUE))

invalid_kind <- tryCatch(
  omix_limma_analysis(
    Dataset = expression,
    Metadata_Table = metadata,
    sample_names_column = "Sample",
    samples_to_include = metadata$Sample,
    gene_names_column = "GeneName",
    contrast_variable_columns = "Group",
    contrasts = "B-A",
    input_kind = "proportion"
  ),
  error = identity
)
stopifnot(inherits(invalid_kind, "error"))

covariate_metadata <- transform(metadata, Batch = c("Batch1", "Batch2", "Batch1", "Batch2", "Batch1", "Batch2"))
covariate_result <- omix_limma_analysis(
  Dataset = expression,
  Metadata_Table = covariate_metadata,
  sample_names_column = "Sample",
  samples_to_include = covariate_metadata$Sample,
  gene_names_column = "GeneName",
  contrast_variable_columns = "Group",
  contrasts = "B-A",
  covariate_columns = "Batch"
)
stopifnot("BatchBatch2_Mean" %in% names(covariate_result))
stopifnot(identical(attr(covariate_result, "omix_limma_run")$covariate_columns, "Batch"))

# Technical batch columns are modeled in the DE fit and can be removed only
# from an explicit downstream matrix. The biological group design is protected
# during removal, so the DE coefficient itself cannot depend on this optional
# handoff output.
batch_expression <- expression
batch_expression[, c("A2", "B1", "B3")] <- batch_expression[, c("A2", "B1", "B3")] + 2
batch_metadata <- transform(
  metadata,
  Batch = c("Batch1", "Batch2", "Batch1", "Batch2", "Batch1", "Batch2")
)
batch_model_only <- omix_limma_analysis(
  Dataset = batch_expression,
  Metadata_Table = batch_metadata,
  sample_names_column = "Sample",
  samples_to_include = batch_metadata$Sample,
  gene_names_column = "GeneName",
  contrast_variable_columns = "Group",
  contrasts = "B-A",
  batch_effect_columns = "Batch",
  return_batch_corrected_values = FALSE
)
batch_corrected_result <- omix_limma_analysis(
  Dataset = batch_expression,
  Metadata_Table = batch_metadata,
  sample_names_column = "Sample",
  samples_to_include = batch_metadata$Sample,
  gene_names_column = "GeneName",
  contrast_variable_columns = "Group",
  contrasts = "B-A",
  batch_effect_columns = "Batch",
  return_batch_corrected_values = TRUE
)
expected_batch_corrected <- limma::removeBatchEffect(
  as.matrix(batch_expression[, batch_metadata$Sample]),
  batch = factor(batch_metadata$Batch),
  design = stats::model.matrix(~ 0 + Group, data = batch_metadata)
)
rownames(expected_batch_corrected) <- batch_expression$GeneName
stopifnot(isTRUE(all.equal(
  attr(batch_corrected_result, "omix_limma_downstream_expression"),
  expected_batch_corrected,
  tolerance = 1e-12
)))
stopifnot(isTRUE(all.equal(
  batch_model_only[["B-A_logFC"]],
  batch_corrected_result[["B-A_logFC"]],
  tolerance = 1e-12
)))
stopifnot(identical(
  attr(batch_corrected_result, "omix_limma_run")$adjusted_batch_columns,
  "Batch"
))

batch_as_group <- tryCatch(
  omix_limma_analysis(
    Dataset = batch_expression,
    Metadata_Table = batch_metadata,
    sample_names_column = "Sample",
    samples_to_include = batch_metadata$Sample,
    gene_names_column = "GeneName",
    contrast_variable_columns = "Batch",
    contrasts = "Batch2-Batch1",
    batch_effect_columns = "Batch"
  ),
  error = identity
)
stopifnot(inherits(batch_as_group, "error"))
stopifnot(grepl("cannot also define", conditionMessage(batch_as_group), fixed = TRUE))

donor_metadata <- data.frame(
  Sample = c("A1", "A2", "A3", "B1", "B2", "B3"),
  Group = c("A", "A", "A", "B", "B", "B"),
  Donor = c("D1", "D2", "D3", "D1", "D2", "D3"),
  stringsAsFactors = FALSE
)
donor_result <- omix_limma_analysis(
  Dataset = expression,
  Metadata_Table = donor_metadata,
  sample_names_column = "Sample",
  samples_to_include = donor_metadata$Sample,
  gene_names_column = "GeneName",
  contrast_variable_columns = "Group",
  contrasts = "B-A",
  donor_variable_column = "Donor"
)
stopifnot(identical(attr(donor_result, "omix_limma_run")$model_type, "repeated_measures"))

unrepeated_donors <- tryCatch(
  omix_limma_analysis(
    Dataset = expression,
    Metadata_Table = transform(metadata, Donor = paste0("D", seq_len(nrow(metadata)))),
    sample_names_column = "Sample",
    samples_to_include = metadata$Sample,
    gene_names_column = "GeneName",
    contrast_variable_columns = "Group",
    contrasts = "B-A",
    donor_variable_column = "Donor"
  ),
  error = identity
)
stopifnot(inherits(unrepeated_donors, "error"))

message("OMIX-Limma-Analysis template-compatible checks passed")
