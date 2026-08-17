#!/usr/bin/env Rscript

test_args <- commandArgs(FALSE)
test_file <- sub("^--file=", "", test_args[grepl("^--file=", test_args)])
module_dir <- normalizePath(file.path(dirname(test_file), ".."))
function_file <- file.path(module_dir, "R", "GSEA_Preranked.R")
cli_file <- file.path(module_dir, "scripts", "run_gsea.R")

stopifnot(file.exists(function_file), file.exists(cli_file))
invisible(parse(file = function_file))
invisible(parse(file = cli_file))

function_text <- paste(readLines(function_file, warn = FALSE), collapse = "\n")
stopifnot(grepl("Output_Directory", function_text, fixed = TRUE))
stopifnot(!grepl('file.path("/results"', function_text, fixed = TRUE))

message("OMIX-GSEA-Preranked-Legacy module layout checks passed")
