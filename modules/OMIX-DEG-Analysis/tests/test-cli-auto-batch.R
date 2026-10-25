#!/usr/bin/env Rscript

script_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
if (length(script_arg) != 1L) {
  stop("Run this test with Rscript tests/test-cli-auto-batch.R")
}

module_root <- normalizePath(file.path(dirname(sub("^--file=", "", script_arg)), ".."))
entrypoint <- file.path(module_root, "scripts", "run_deg_analysis.R")

set.seed(20261004)
sample_ids <- c("A1", "A2", "A3", "B1", "B2", "B3")
counts <- matrix(
  stats::rpois(120L * length(sample_ids), lambda = 60L),
  nrow = 120L,
  dimnames = list(paste0("Gene", seq_len(120L)), sample_ids)
)
counts[seq_len(20L), 4:6] <- counts[seq_len(20L), 4:6] + 50L
count_table <- data.frame(GeneName = rownames(counts), counts, check.names = FALSE)
rsem_expected_count_table <- count_table
rsem_expected_count_table[, sample_ids] <- rsem_expected_count_table[, sample_ids] + 0.25
metadata_with_batch <- data.frame(
  Sample = sample_ids,
  Group = rep(c("A", "B"), each = 3L),
  Batch = rep(c("Run1", "Run2"), 3L),
  stringsAsFactors = FALSE
)
metadata_without_batch <- metadata_with_batch[, c("Sample", "Group"), drop = FALSE]

working_dir <- tempfile("omix-deg-cli-auto-batch-")
dir.create(working_dir, recursive = TRUE)
on.exit(unlink(working_dir, recursive = TRUE), add = TRUE)
counts_path <- file.path(working_dir, "counts.csv")
rsem_expected_counts_path <- file.path(working_dir, "rsem-expected-counts.csv")
metadata_with_batch_path <- file.path(working_dir, "metadata-with-batch.csv")
metadata_without_batch_path <- file.path(working_dir, "metadata-without-batch.csv")
utils::write.csv(count_table, counts_path, row.names = FALSE)
utils::write.csv(rsem_expected_count_table, rsem_expected_counts_path, row.names = FALSE)
utils::write.csv(metadata_with_batch, metadata_with_batch_path, row.names = FALSE)
utils::write.csv(metadata_without_batch, metadata_without_batch_path, row.names = FALSE)

run_cli <- function(metadata_path, output_dir, batch_effect_columns = NULL, counts_input = counts_path) {
  arguments <- c(
    entrypoint,
    "--counts", counts_input,
    "--metadata", metadata_path,
    "--write_normalization_diagnostics", "false",
    "--output_dir", output_dir
  )
  if (!is.null(batch_effect_columns)) {
    arguments <- c(arguments, "--batch_effect_columns", batch_effect_columns)
  }
  output <- suppressWarnings(system2(
    file.path(R.home("bin"), "Rscript"),
    arguments,
    stdout = TRUE,
    stderr = TRUE
  ))
  status <- attr(output, "status")
  if (is.null(status)) status <- 0L
  list(status = status, output = output)
}

with_batch_output <- file.path(working_dir, "with-batch")
with_batch <- run_cli(metadata_with_batch_path, with_batch_output)
stopifnot(
  identical(with_batch$status, 0L),
  file.exists(file.path(with_batch_output, "DEG_Analysis.csv")),
  file.exists(file.path(with_batch_output, "Sample_Metadata.csv")),
  "voom trend span: 0.5" %in% readLines(file.path(with_batch_output, "run_summary.txt")),
  "voom adaptive span: false" %in% readLines(file.path(with_batch_output, "run_summary.txt"))
)

# RSEM expected_count output is a fractional count-scale input. The public CLI
# must pass it through the raw-count edgeR/voom path without rounding.
rsem_expected_counts <- run_cli(
  metadata_with_batch_path,
  file.path(working_dir, "rsem-expected-counts"),
  counts_input = rsem_expected_counts_path
)
stopifnot(
  identical(rsem_expected_counts$status, 0L),
  file.exists(file.path(working_dir, "rsem-expected-counts", "DEG_Analysis.csv"))
)

without_batch_output <- file.path(working_dir, "without-batch")
without_batch <- run_cli(metadata_without_batch_path, without_batch_output)
stopifnot(
  identical(without_batch$status, 0L),
  file.exists(file.path(without_batch_output, "DEG_Analysis.csv")),
  file.exists(file.path(without_batch_output, "Sample_Metadata.csv"))
)

explicit_missing <- run_cli(
  metadata_without_batch_path,
  file.path(working_dir, "explicit-missing"),
  batch_effect_columns = "Batch"
)
stopifnot(
  explicit_missing$status != 0L,
  grepl(
    "Metadata_Table is missing required column(s): Batch",
    paste(explicit_missing$output, collapse = "\n"),
    fixed = TRUE
  )
)

# Continuous-expression modes must record their deterministic empirical-Bayes
# choice in the portable CLI summary. The same numeric fixture is sufficient
# here because this test verifies routing and provenance, not assay origin.
continuous_table <- count_table
continuous_table[, sample_ids] <- log2(as.matrix(continuous_table[, sample_ids]) + 1)
continuous_path <- file.path(working_dir, "continuous.csv")
utils::write.csv(continuous_table, continuous_path, row.names = FALSE)
run_continuous_cli <- function(analysis_mode, output_dir) {
  output <- suppressWarnings(system2(
    file.path(R.home("bin"), "Rscript"),
    c(
      entrypoint,
      "--counts", continuous_path,
      "--metadata", metadata_without_batch_path,
      "--analysis_mode", analysis_mode,
      "--output_dir", output_dir
    ),
    stdout = TRUE,
    stderr = TRUE
  ))
  status <- attr(output, "status")
  if (is.null(status)) status <- 0L
  list(status = status, output = output)
}

harmony_output <- file.path(working_dir, "harmony")
harmony <- run_continuous_cli("harmony_mean_expression", harmony_output)
stopifnot(
  identical(harmony$status, 0L),
  "variance model: ebayes" %in% readLines(file.path(harmony_output, "run_summary.txt"))
)

sct_output <- file.path(working_dir, "sct")
sct <- run_continuous_cli("sct_mean_expression", sct_output)
stopifnot(
  identical(sct$status, 0L),
  "variance model: ebayes_trend" %in% readLines(file.path(sct_output, "run_summary.txt"))
)

message("OMIX DEG CLI automatic batch-selection checks passed")
