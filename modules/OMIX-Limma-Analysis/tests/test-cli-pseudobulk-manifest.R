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
summary_lines <- readLines(file.path(output_dir, "run_summary.txt"))
stopifnot(any(grepl("requested variance model: auto", summary_lines, fixed = TRUE)))
stopifnot(any(grepl("variance model: ebayes_trend", summary_lines, fixed = TRUE)))

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

message("OMIX-Limma-Analysis CLI manifest handoff checks passed")
