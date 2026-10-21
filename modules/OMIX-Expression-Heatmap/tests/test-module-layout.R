#!/usr/bin/env Rscript

test_file <- sub("^--file=", "", commandArgs(FALSE)[grepl("^--file=", commandArgs(FALSE))])
module_dir <- normalizePath(file.path(dirname(test_file), ".."))
required <- c("R", "schemas", "scripts", "tests", "module.yml", "README.md", "CHANGELOG.md")
stopifnot(all(file.exists(file.path(module_dir, required))))
stopifnot(file.exists(file.path(module_dir, "R", "OMIX_Expression_Heatmap.R")))
stopifnot(file.exists(file.path(module_dir, "scripts", "run_expression_heatmap.R")))
stopifnot(file.exists(file.path(module_dir, "schemas", "interface.yml")))
message("OMIX-Expression-Heatmap module layout check passed")
