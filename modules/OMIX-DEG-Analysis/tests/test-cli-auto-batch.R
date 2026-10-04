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
metadata_with_batch_path <- file.path(working_dir, "metadata-with-batch.csv")
metadata_without_batch_path <- file.path(working_dir, "metadata-without-batch.csv")
utils::write.csv(count_table, counts_path, row.names = FALSE)
utils::write.csv(metadata_with_batch, metadata_with_batch_path, row.names = FALSE)
utils::write.csv(metadata_without_batch, metadata_without_batch_path, row.names = FALSE)

run_cli <- function(metadata_path, output_dir, batch_effect_columns = NULL) {
  arguments <- c(
    entrypoint,
    "--counts", counts_path,
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
  file.exists(file.path(with_batch_output, "Sample_Metadata.csv"))
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

message("OMIX DEG CLI automatic batch-selection checks passed")
