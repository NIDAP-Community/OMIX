#!/usr/bin/env Rscript

test_args <- commandArgs(FALSE)
test_file <- sub("^--file=", "", test_args[grepl("^--file=", test_args)])
module_dir <- normalizePath(file.path(dirname(test_file), ".."))
repo_root <- normalizePath(file.path(module_dir, "..", ".."))

source(file.path(repo_root, "packages", "OmixPathwayInputs", "R", "findmarkers-input.R"))

fixture <- file.path(
  repo_root, "tests", "fixtures", "findmarkers", "deg_findmarkers_wide.csv"
)
deg <- utils::read.csv(fixture, check.names = FALSE)
profile <- normalize_findmarkers_deg_input(deg)

stopifnot(
  identical(profile$comparisons, c("C_1_vs_2", "C_3_vs_all")),
  identical(
    unname(profile$analysis_columns$nominal),
    c("C_1_vs_2_pval", "C_3_vs_all_pval")
  ),
  identical(
    unname(profile$analysis_columns$fold_change),
    c("C_1_vs_2_logFC", "C_3_vs_all_logFC")
  )
)

reordered <- normalize_findmarkers_deg_input(
  deg,
  comparison_labels = c("C_3_vs_all", "C_1_vs_2")
)
stopifnot(
  identical(reordered$comparisons, c("C_3_vs_all", "C_1_vs_2")),
  identical(
    unname(reordered$analysis_columns$fold_change),
    c("C_3_vs_all_logFC", "C_1_vs_2_logFC")
  )
)

message("OMIX-L2P-Multi FindMarkers compatibility checks passed")
