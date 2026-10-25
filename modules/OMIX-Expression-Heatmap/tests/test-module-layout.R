#!/usr/bin/env Rscript

test_file <- sub("^--file=", "", commandArgs(FALSE)[grepl("^--file=", commandArgs(FALSE))])
module_dir <- normalizePath(file.path(dirname(test_file), ".."))
required <- c("R", "schemas", "scripts", "tests", "module.yml", "README.md", "CHANGELOG.md")
stopifnot(all(file.exists(file.path(module_dir, required))))
stopifnot(file.exists(file.path(module_dir, "R", "OMIX_Expression_Heatmap.R")))
stopifnot(file.exists(file.path(module_dir, "scripts", "run_expression_heatmap.R")))
stopifnot(file.exists(file.path(module_dir, "schemas", "interface.yml")))

# Keep the required Bioconductor package in the exact nested form understood
# by scripts/restore-omix-runtime.R when it builds a reproducible run project.
module_yml <- readLines(file.path(module_dir, "module.yml"), warn = FALSE)
stopifnot(all(c(
  "runtime_overlay:",
  "  bioconductor:",
  "    - package: ComplexHeatmap",
  "      version: 2.22.0"
) %in% module_yml))
message("OMIX-Expression-Heatmap module layout check passed")
