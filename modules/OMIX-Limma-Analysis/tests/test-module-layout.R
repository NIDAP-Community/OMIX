#!/usr/bin/env Rscript

test_args <- commandArgs(FALSE)
test_file <- sub("^--file=", "", test_args[grepl("^--file=", test_args)])
module_dir <- normalizePath(file.path(dirname(test_file), ".."))
required <- c("R", "schemas", "scripts", "tests", "module.yml", "README.md", "CHANGELOG.md")
stopifnot(all(file.exists(file.path(module_dir, required))))
stopifnot(file.exists(file.path(module_dir, "R", "OMIX_Limma_Analysis.R")))
stopifnot(file.exists(file.path(module_dir, "schemas", "interface.yml")))
stopifnot(file.exists(file.path(module_dir, "scripts", "run_limma_analysis.R")))
message("OMIX-Limma-Analysis module layout check passed")
