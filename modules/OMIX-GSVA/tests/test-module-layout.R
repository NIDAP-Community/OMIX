#!/usr/bin/env Rscript

script_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
if (length(script_arg) != 1L) stop("Run this test with Rscript tests/test-module-layout.R")
module_root <- normalizePath(file.path(dirname(sub("^--file=", "", script_arg)), ".."))
function_file <- file.path(module_root, "R", "GSVA_v1.R")
cli_file <- file.path(module_root, "scripts", "run_gsva.R")
schema_file <- file.path(module_root, "schemas", "interface.yml")

stopifnot(file.exists(function_file), file.exists(cli_file), file.exists(schema_file))
invisible(parse(file = function_file))
invisible(parse(file = cli_file))
source(function_file, local = TRUE)

gsva_defaults <- formals(run_gsva)
stopifnot(identical(eval(gsva_defaults$species), "Human"))
stopifnot(identical(eval(gsva_defaults$database_species), "Human"))
stopifnot(identical(eval(gsva_defaults$collections_to_include), "H: hallmark gene sets"))
stopifnot(identical(eval(gsva_defaults$custom_pathways_database), FALSE))
stopifnot(identical(eval(gsva_defaults$custom_species), "Mouse"))
stopifnot(identical(eval(gsva_defaults$method), "gsva"))
stopifnot(identical(eval(gsva_defaults$minimum_geneset_size), 15))
stopifnot(identical(eval(gsva_defaults$maximum_geneset_size), 1200))
stopifnot(identical(eval(gsva_defaults$update_genes), TRUE))
stopifnot(identical(eval(gsva_defaults$display_warnings), -1))

function_text <- paste(readLines(function_file, warn = FALSE), collapse = "\n")
stopifnot(!grepl("@import", function_text, fixed = TRUE))
stopifnot(!grepl("@export", function_text, fixed = TRUE))

cli_text <- paste(readLines(cli_file, warn = FALSE), collapse = "\n")
for (option in c(
  "--normalized_data", "--sample_metadata", "--pathways_database",
  "--gene_column", "--sample_name_column", "--samples_to_include",
  "--collections_to_include", "--method", "--minimum_geneset_size",
  "--maximum_geneset_size", "--update_genes", "--output_dir"
)) {
  stopifnot(grepl(option, cli_text, fixed = TRUE))
}
stopifnot(!grepl('"/data/', cli_text, fixed = TRUE))
stopifnot(!grepl('"/results', cli_text, fixed = TRUE))

message("OMIX-GSVA module layout checks passed")
