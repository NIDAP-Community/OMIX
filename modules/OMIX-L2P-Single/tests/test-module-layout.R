#!/usr/bin/env Rscript

test_args <- commandArgs(FALSE)
test_file <- sub("^--file=", "", test_args[grepl("^--file=", test_args)])
module_dir <- normalizePath(file.path(dirname(test_file), ".."))
function_file <- file.path(module_dir, "R", "L2P_Analysis.R")
cli_file <- file.path(module_dir, "scripts", "run_l2p_single.R")
schema_file <- file.path(module_dir, "schemas", "interface.yml")

stopifnot(file.exists(function_file), file.exists(cli_file), file.exists(schema_file))
invisible(parse(file = function_file))
invisible(parse(file = cli_file))

cli_text <- paste(readLines(cli_file, warn = FALSE), collapse = "\n")
stopifnot(grepl("--deg_table", cli_text, fixed = TRUE))
stopifnot(grepl("--comparison", cli_text, fixed = TRUE))
stopifnot(grepl("--output_dir", cli_text, fixed = TRUE))
stopifnot(!grepl('"/data/', cli_text, fixed = TRUE))
stopifnot(!grepl('"/results"', cli_text, fixed = TRUE))

message("OMIX-L2P-Single module layout checks passed")
