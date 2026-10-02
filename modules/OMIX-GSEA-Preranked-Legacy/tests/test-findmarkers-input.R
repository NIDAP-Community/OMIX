#!/usr/bin/env Rscript

test_args <- commandArgs(FALSE)
test_file <- sub("^--file=", "", test_args[grepl("^--file=", test_args)])
module_dir <- normalizePath(file.path(dirname(test_file), ".."))
repo_root <- normalizePath(file.path(module_dir, "..", ".."))

source(file.path(repo_root, "packages", "OmixPathwayInputs", "R", "findmarkers-input.R"))
source(file.path(module_dir, "R", "GSEA_Preranked.R"))

fixture <- file.path(
  repo_root, "tests", "fixtures", "findmarkers", "deg_findmarkers_wide.csv"
)
deg <- utils::read.csv(fixture, check.names = FALSE)
profile <- normalize_findmarkers_deg_input(deg)
ranked <- resolve_gsea_rank_columns(
  names(profile$data),
  score_suffix = "_logFC",
  contrasts = profile$comparisons,
  contrasts_filter = "keep"
)
stopifnot(
  identical(ranked$contrasts, c("C_1_vs_2", "C_3_vs_all")),
  identical(ranked$columns, c("C_1_vs_2_logFC", "C_3_vs_all_logFC"))
)

reordered <- resolve_gsea_rank_columns(
  names(profile$data),
  score_suffix = "_logFC",
  contrasts = c("C_3_vs_all", "C_1_vs_2"),
  contrasts_filter = "keep"
)
stopifnot(
  identical(reordered$contrasts, c("C_3_vs_all", "C_1_vs_2")),
  identical(reordered$columns, c("C_3_vs_all_logFC", "C_1_vs_2_logFC"))
)

message("OMIX-GSEA-Preranked-Legacy FindMarkers compatibility checks passed")
