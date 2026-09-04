#!/usr/bin/env Rscript

test_args <- commandArgs(FALSE)
test_file <- sub("^--file=", "", test_args[grepl("^--file=", test_args)])
module_dir <- normalizePath(file.path(dirname(test_file), ".."))
function_file <- file.path(module_dir, "R", "gsea_enrichment_plot.R")
cli_file <- file.path(module_dir, "scripts", "run_gsea_visualization.R")

stopifnot(file.exists(function_file), file.exists(cli_file))
invisible(parse(file = function_file))
invisible(parse(file = cli_file))

cli_text <- paste(readLines(cli_file, warn = FALSE), collapse = "\n")
stopifnot(!grepl('"/data', cli_text, fixed = TRUE))
stopifnot(!grepl('"/results', cli_text, fixed = TRUE))
stopifnot(grepl("--msigdb_database", cli_text, fixed = TRUE))
stopifnot(grepl("--sample_metadata", cli_text, fixed = TRUE))

message("OMIX-GSEA-Visualization-Legacy module layout checks passed")
