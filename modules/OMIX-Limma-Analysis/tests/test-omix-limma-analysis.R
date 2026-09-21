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

reference_design <- stats::model.matrix(~0 + Group, data = metadata)
colnames(reference_design) <- sub("^Group", "", colnames(reference_design))
reference_fit <- limma::lmFit(as.matrix(expression[, metadata$Sample]), reference_design)
reference_fit <- limma::contrasts.fit(reference_fit, limma::makeContrasts(`B-A` = B - A, levels = reference_design))
reference_fit <- limma::eBayes(reference_fit)
stopifnot(isTRUE(all.equal(result[["B-A_logFC"]], as.numeric(reference_fit$coefficients[, 1L]), tolerance = 1e-12)))
stopifnot(isTRUE(all.equal(result[["B-A_pval"]], as.numeric(reference_fit$p.value[, 1L]), tolerance = 1e-12)))

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
