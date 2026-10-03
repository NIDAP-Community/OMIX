#!/usr/bin/env Rscript

script_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
if (length(script_arg) != 1L) {
  stop("Run this test with Rscript tests/test-module-layout.R")
}
module_root <- normalizePath(file.path(dirname(sub("^--file=", "", script_arg)), ".."))
function_file <- file.path(module_root, "R", "Seurat_Pseudobulk.R")
cli_file <- file.path(module_root, "scripts", "run_seurat_pseudobulk.R")
schema_file <- file.path(module_root, "schemas", "interface.yml")
metadata_file <- file.path(module_root, "module.yml")
readme_file <- file.path(module_root, "README.md")

stopifnot(
  file.exists(function_file), file.exists(cli_file), file.exists(schema_file),
  file.exists(metadata_file), file.exists(readme_file)
)
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
stopifnot(grepl('--feature_id_column", type = "character", default = "GeneName"', cli_text, fixed = TRUE))
stopifnot(grepl("--feature_id_column is fixed to GeneName", cli_text, fixed = TRUE))

schema_text <- paste(readLines(schema_file, warn = FALSE), collapse = "\n")
stopifnot(grepl("allowed: [GeneName]", schema_text, fixed = TRUE))

invalid_feature_output <- suppressWarnings(system2(
  file.path(R.home("bin"), "Rscript"),
  c(
    shQuote(cli_file),
    "--seurat_rds", "not-used.rds",
    "--donor_column", "Donor",
    "--group_column", "Group",
    "--cell_type_column", "CellType",
    "--cell_type", "Monocytes",
    "--feature_id_column", "Gene"
  ),
  stdout = TRUE,
  stderr = TRUE
))
invalid_feature_status <- attr(invalid_feature_output, "status")
stopifnot(!is.null(invalid_feature_status), invalid_feature_status != 0L)
stopifnot(any(grepl("fixed to GeneName", invalid_feature_output, fixed = TRUE)))

adapter_url <- "https://github.com/NIDAP-Community/OMIX-Seurat-Pseudobulk"
metadata_text <- paste(readLines(metadata_file, warn = FALSE), collapse = "\n")
readme_text <- paste(readLines(readme_file, warn = FALSE), collapse = "\n")
stopifnot(
  grepl("platform: code-ocean", metadata_text, fixed = TRUE),
  grepl(adapter_url, metadata_text, fixed = TRUE),
  grepl(adapter_url, readme_text, fixed = TRUE),
  !grepl("is under review", readme_text, fixed = TRUE)
)

message("OMIX-Seurat-Pseudobulk module layout checks passed")
