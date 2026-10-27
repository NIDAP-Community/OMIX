#!/usr/bin/env Rscript

test_file <- sub("^--file=", "", commandArgs(FALSE)[grepl("^--file=", commandArgs(FALSE))])
module_dir <- normalizePath(file.path(dirname(test_file), ".."))
required <- c("R", "schemas", "scripts", "tests", "module.yml", "README.md", "CHANGELOG.md")
stopifnot(all(file.exists(file.path(module_dir, required))))
function_file <- file.path(module_dir, "R", "OMIX_PCA_3D.R")
cli_file <- file.path(module_dir, "scripts", "run_pca_3d.R")
schema_file <- file.path(module_dir, "schemas", "interface.yml")
stopifnot(file.exists(function_file), file.exists(cli_file), file.exists(schema_file))
invisible(parse(file = function_file))
invisible(parse(file = cli_file))

module_yml <- readLines(file.path(module_dir, "module.yml"), warn = FALSE)
stopifnot(all(c(
  "runtime_overlay:",
  "  bioconductor:",
  "    - package: edgeR",
  "      version: 4.4.2"
) %in% module_yml))

cli_text <- paste(readLines(cli_file, warn = FALSE), collapse = "\n")
stopifnot(grepl("--feature_matrix", cli_text, fixed = TRUE))
stopifnot(grepl("--sample_metadata", cli_text, fixed = TRUE))
stopifnot(grepl("--output_dir", cli_text, fixed = TRUE))
stopifnot(!grepl('"/data/', cli_text, fixed = TRUE))
stopifnot(!grepl('"/results"', cli_text, fixed = TRUE))
message("OMIX-PCA-3D module layout checks passed")
