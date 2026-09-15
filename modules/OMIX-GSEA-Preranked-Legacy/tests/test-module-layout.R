#!/usr/bin/env Rscript

test_args <- commandArgs(FALSE)
test_file <- sub("^--file=", "", test_args[grepl("^--file=", test_args)])
module_dir <- normalizePath(file.path(dirname(test_file), ".."))
function_file <- file.path(module_dir, "R", "GSEA_Preranked.R")
cli_file <- file.path(module_dir, "scripts", "run_gsea.R")

stopifnot(file.exists(function_file), file.exists(cli_file))
invisible(parse(file = function_file))
invisible(parse(file = cli_file))
source(function_file)

available_columns <- c("GeneName", "C-B_tstat", "B-A_tstat", "C-A_tstat", "B-A_pval")
default_resolution <- resolve_gsea_rank_columns(available_columns)
requested_resolution <- resolve_gsea_rank_columns(
  available_columns,
  contrasts = c("B-A", "C-A", "C-B"),
  contrasts_filter = "keep"
)
stopifnot(identical(default_resolution$contrasts, c("C-B", "B-A", "C-A")))
stopifnot(identical(requested_resolution$contrasts, c("B-A", "C-A", "C-B")))
stopifnot(identical(requested_resolution$columns, c("B-A_tstat", "C-A_tstat", "C-B_tstat")))
missing_contrast_error <- tryCatch(
  resolve_gsea_rank_columns(
    available_columns,
    contrasts = c("B-A", "B-C"),
    contrasts_filter = "keep"
  ),
  error = conditionMessage
)
stopifnot(is.character(missing_contrast_error), grepl("B-C", missing_contrast_error, fixed = TRUE))

function_text <- paste(readLines(function_file, warn = FALSE), collapse = "\n")
stopifnot(grepl("Output_Directory", function_text, fixed = TRUE))
stopifnot(!grepl('file.path("/results"', function_text, fixed = TRUE))
stopifnot(grepl("--contrasts", paste(readLines(cli_file, warn = FALSE), collapse = "\n"), fixed = TRUE))

message("OMIX-GSEA-Preranked-Legacy module layout checks passed")
