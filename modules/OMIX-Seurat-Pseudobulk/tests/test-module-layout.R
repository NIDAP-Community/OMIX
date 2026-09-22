#!/usr/bin/env Rscript

script_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
if (length(script_arg) != 1L) {
  stop("Run this test with Rscript tests/test-module-layout.R")
}
module_root <- normalizePath(file.path(dirname(sub("^--file=", "", script_arg)), ".."))
function_file <- file.path(module_root, "R", "Seurat_Pseudobulk.R")
cli_file <- file.path(module_root, "scripts", "run_seurat_pseudobulk.R")
schema_file <- file.path(module_root, "schemas", "interface.yml")

stopifnot(file.exists(function_file), file.exists(cli_file), file.exists(schema_file))
invisible(parse(file = function_file))
invisible(parse(file = cli_file))

cli_text <- paste(readLines(cli_file, warn = FALSE), collapse = "\n")
for (option in c(
  "--seurat_rds", "--donor_column", "--group_column", "--cell_type_column",
  "--cell_type", "--metadata_columns", "--aggregation_method", "--output_dir"
)) {
  stopifnot(grepl(option, cli_text, fixed = TRUE))
}
stopifnot(!grepl('"/data/', cli_text, fixed = TRUE))
stopifnot(!grepl('"/results"', cli_text, fixed = TRUE))

message("OMIX-Seurat-Pseudobulk module layout checks passed")
