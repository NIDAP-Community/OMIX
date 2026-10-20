#!/usr/bin/env Rscript

test_args <- commandArgs(FALSE)
test_file <- sub("^--file=", "", test_args[grepl("^--file=", test_args)])
module_dir <- normalizePath(file.path(dirname(test_file), ".."))
cli <- file.path(module_dir, "scripts", "run_limma_analysis.R")
work_dir <- tempfile("omix-limma-manifest-")
dir.create(work_dir)

matrix <- data.frame(
  GeneName = c("Gene1", "Gene2", "Gene3"),
  D1__A = c(4.8, 6.1, 7.2), D2__A = c(5.0, 6.0, 7.3), D3__A = c(4.9, 6.2, 7.1),
  D1__B = c(5.8, 6.4, 7.0), D2__B = c(6.0, 6.5, 7.1), D3__B = c(5.9, 6.3, 7.2),
  check.names = FALSE
)
metadata <- data.frame(
  Sample = names(matrix)[-1L],
  Group = rep(c("A", "B"), each = 3L),
  Donor = rep(paste0("D", seq_len(3L)), 2L),
  stringsAsFactors = FALSE
)
matrix_path <- file.path(work_dir, "SCT_Mean_Log2_Expression.csv")
metadata_path <- file.path(work_dir, "Pseudobulk_Sample_Metadata.csv")
manifest_path <- file.path(work_dir, "Pseudobulk_Manifest.dcf")
output_dir <- file.path(work_dir, "results")
utils::write.csv(matrix, matrix_path, row.names = FALSE)
utils::write.csv(metadata, metadata_path, row.names = FALSE)
base::write.dcf(data.frame(
  matrix_type = "sctransform_mean_log2_expression",
  expected_downstream_module = "OMIX-Limma-Analysis",
  expected_downstream_mode = "continuous_expression",
  downstream_input_kind = "log2_expression",
  recommended_variance_model = "ebayes_trend",
  stringsAsFactors = FALSE
), manifest_path)

run_cli <- function(manifest, output) {
  command <- file.path(R.home("bin"), "Rscript")
  system2(command, c(
    cli,
    "--matrix", matrix_path,
    "--metadata", metadata_path,
    "--contrasts", "B-A",
    "--donor_variable_column", "Donor",
    "--pseudobulk_manifest", manifest,
    "--output_dir", output
  ), stdout = TRUE, stderr = TRUE)
}

success_output <- run_cli(manifest_path, output_dir)
stopifnot(is.null(attr(success_output, "status")))
stopifnot(file.exists(file.path(output_dir, "Limma_Analysis.csv")))
stopifnot(file.exists(file.path(output_dir, "Variance_Diagnostic.csv")))
stopifnot(file.exists(file.path(output_dir, "variance_diagnostic.png")))
summary_lines <- readLines(file.path(output_dir, "run_summary.txt"))
stopifnot(any(grepl("requested input data type: auto", summary_lines, fixed = TRUE)))
stopifnot(any(grepl("input data type: sctransform_mean_expression", summary_lines, fixed = TRUE)))
stopifnot(any(grepl("input data type source: manifest", summary_lines, fixed = TRUE)))
stopifnot(any(grepl("requested variance model: auto", summary_lines, fixed = TRUE)))
stopifnot(any(grepl("recommended variance model: ebayes_trend", summary_lines, fixed = TRUE)))
stopifnot(any(grepl("variance model: ebayes_trend", summary_lines, fixed = TRUE)))

# A declared technical batch produces a dedicated continuous matrix for a
# downstream tool, while retaining the standard Limma result bundle.
batch_metadata_path <- file.path(work_dir, "Batch_Pseudobulk_Sample_Metadata.csv")
batch_output_dir <- file.path(work_dir, "batch-results")
utils::write.csv(
  transform(metadata, Batch = c("Batch1", "Batch2", "Batch1", "Batch2", "Batch1", "Batch2")),
  batch_metadata_path,
  row.names = FALSE
)
batch_output <- system2(file.path(R.home("bin"), "Rscript"), c(
  cli,
  "--matrix", matrix_path,
  "--metadata", batch_metadata_path,
  "--contrasts", "B-A",
  "--pseudobulk_manifest", manifest_path,
  "--batch_effect_columns", "Batch",
  "--return_batch_corrected_values", "true",
  "--output_dir", batch_output_dir
), stdout = TRUE, stderr = TRUE)
stopifnot(is.null(attr(batch_output, "status")))
stopifnot(file.exists(file.path(batch_output_dir, "Batch_Corrected_Expression.csv")))
batch_matrix <- utils::read.csv(
  file.path(batch_output_dir, "Batch_Corrected_Expression.csv"),
  check.names = FALSE
)
stopifnot(identical(names(batch_matrix), c("Gene", metadata$Sample)))
batch_summary <- readLines(file.path(batch_output_dir, "run_summary.txt"))
stopifnot(any(grepl("batch effect columns: Batch", batch_summary, fixed = TRUE)))
stopifnot(any(grepl("adjusted batch columns: Batch", batch_summary, fixed = TRUE)))

# Omitting --contrasts must infer the only replicated two-group comparison and
# make that decision explicit in the run summary.
inferred_output_dir <- file.path(work_dir, "inferred-results")
inferred_output <- system2(file.path(R.home("bin"), "Rscript"), c(
  cli,
  "--matrix", matrix_path,
  "--metadata", metadata_path,
  "--contrast_variable_columns", "Group",
  "--pseudobulk_manifest", manifest_path,
  "--output_dir", inferred_output_dir
), stdout = TRUE, stderr = TRUE)
stopifnot(is.null(attr(inferred_output, "status")))
inferred_summary <- readLines(file.path(inferred_output_dir, "run_summary.txt"))
stopifnot(any(grepl("requested contrasts: <blank>", inferred_summary, fixed = TRUE)))
stopifnot(any(grepl("resolved contrasts: B-A", inferred_summary, fixed = TRUE)))
stopifnot(any(grepl("contrast source: inferred", inferred_summary, fixed = TRUE)))
stopifnot(any(grepl("group replicate counts: A=3,B=3", inferred_summary, fixed = TRUE)))

# A Seurat-derived 0/1 grouping must work through the complete CLI handoff.
numeric_metadata_path <- file.path(work_dir, "Numeric_Pseudobulk_Sample_Metadata.csv")
numeric_output_dir <- file.path(work_dir, "numeric-results")
utils::write.csv(
  transform(metadata, Group = ifelse(Group == "A", "0", "1")),
  numeric_metadata_path,
  row.names = FALSE
)
numeric_output <- system2(file.path(R.home("bin"), "Rscript"), c(
  cli,
  "--matrix", matrix_path,
  "--metadata", numeric_metadata_path,
  "--contrast_variable_columns", "Group",
  "--contrasts", "1-0",
  "--pseudobulk_manifest", manifest_path,
  "--output_dir", numeric_output_dir
), stdout = TRUE, stderr = TRUE)
stopifnot(is.null(attr(numeric_output, "status")))
numeric_results <- utils::read.csv(
  file.path(numeric_output_dir, "Limma_Analysis.csv"),
  check.names = FALSE
)
stopifnot(all(c("0_Mean", "1_Mean", "1-0_logFC") %in% names(numeric_results)))

raw_manifest_path <- file.path(work_dir, "raw-counts-manifest.dcf")
base::write.dcf(data.frame(
  matrix_type = "raw_integer_counts",
  expected_downstream_module = "OMIX-DEG-Analysis",
  expected_downstream_mode = "raw_counts",
  stringsAsFactors = FALSE
), raw_manifest_path)
raw_output <- suppressWarnings(run_cli(raw_manifest_path, file.path(work_dir, "raw-results")))
stopifnot(identical(attr(raw_output, "status"), 1L))
stopifnot(any(grepl("OMIX-DEG-Analysis", raw_output, fixed = TRUE)))

# Unknown continuous measurements must document their scale and make an
# explicit variance-model decision rather than letting auto guess from values.
other_output <- suppressWarnings(system2(file.path(R.home("bin"), "Rscript"), c(
  cli,
  "--matrix", matrix_path,
  "--metadata", metadata_path,
  "--contrast_variable_columns", "Group",
  "--contrasts", "B-A",
  "--input_data_type", "other_continuous",
  "--input_kind", "continuous_score",
  "--measurement_scale", shQuote("normalized arbitrary assay score"),
  "--variance_model", "auto",
  "--output_dir", file.path(work_dir, "other-results")
), stdout = TRUE, stderr = TRUE))
stopifnot(identical(attr(other_output, "status"), 1L))
stopifnot(any(grepl("Select ebayes or ebayes_trend", other_output, fixed = TRUE)))

other_success_dir <- file.path(work_dir, "other-explicit-results")
other_success <- system2(file.path(R.home("bin"), "Rscript"), c(
  cli,
  "--matrix", matrix_path,
  "--metadata", metadata_path,
  "--contrast_variable_columns", "Group",
  "--contrasts", "B-A",
  "--input_data_type", "other_continuous",
  "--input_kind", "continuous_score",
  "--measurement_scale", shQuote("normalized arbitrary assay score"),
  "--variance_model", "ebayes",
  "--output_dir", other_success_dir
), stdout = TRUE, stderr = TRUE)
stopifnot(is.null(attr(other_success, "status")))
other_summary <- readLines(file.path(other_success_dir, "run_summary.txt"))
stopifnot(any(grepl("input data type: other_continuous", other_summary, fixed = TRUE)))
stopifnot(any(grepl("measurement scale: normalized arbitrary assay score", other_summary, fixed = TRUE)))

fraction_path <- file.path(work_dir, "CIBERSORT_Relative_Fractions.csv")
fraction_output_dir <- file.path(work_dir, "fraction-results")
utils::write.csv(data.frame(
  GeneName = c("B_cells", "T_cells", "Myeloid"),
  D1__A = c(0.2, 0.5, 0.3), D2__A = c(0.1, 0.55, 0.35), D3__A = c(0, 0.6, 0.4),
  D1__B = c(0.4, 0.4, 0.2), D2__B = c(0.35, 0.45, 0.2), D3__B = c(0.3, 0.5, 0.2),
  check.names = FALSE
), fraction_path, row.names = FALSE)
fraction_output <- system2(file.path(R.home("bin"), "Rscript"), c(
  cli,
  "--matrix", fraction_path,
  "--metadata", metadata_path,
  "--contrast_variable_columns", "Group",
  "--contrasts", "B-A",
  "--input_data_type", "cibersort_relative_fractions",
  "--variance_model", "auto",
  "--fraction_transform", "auto",
  "--output_dir", fraction_output_dir
), stdout = TRUE, stderr = TRUE)
stopifnot(is.null(attr(fraction_output, "status")))
fraction_summary <- readLines(file.path(fraction_output_dir, "run_summary.txt"))
stopifnot(any(grepl("input kind: continuous_score", fraction_summary, fixed = TRUE)))
stopifnot(any(grepl("fraction transform: arcsin_sqrt", fraction_summary, fixed = TRUE)))
stopifnot(any(grepl("variance model: ebayes", fraction_summary, fixed = TRUE)))

message("OMIX-Limma-Analysis CLI manifest handoff checks passed")
