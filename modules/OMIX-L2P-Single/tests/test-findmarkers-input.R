#!/usr/bin/env Rscript

test_args <- commandArgs(FALSE)
test_file <- sub("^--file=", "", test_args[grepl("^--file=", test_args)])
module_dir <- normalizePath(file.path(dirname(test_file), ".."))
repo_root <- normalizePath(file.path(module_dir, "..", ".."))

source(file.path(repo_root, "packages", "OmixPathwayInputs", "R", "findmarkers-input.R"))
source(file.path(module_dir, "R", "L2P_Analysis.R"))

fixture <- file.path(
  repo_root, "tests", "fixtures", "findmarkers", "deg_findmarkers_wide.csv"
)
deg <- utils::read.csv(fixture, check.names = FALSE)
profile <- normalize_findmarkers_deg_input(deg)

# Blank comparison controls analyze every recognized wide family in source
# order; each family remains an independent L2P Single run.
stopifnot(identical(profile$comparisons, c("C_1_vs_2", "C_3_vs_all")))
for (comparison in profile$comparisons) {
  columns <- resolve_l2p_comparison_columns(
    comparison = comparison,
    significance_column = profile$analysis_columns$nominal[[comparison]],
    fold_change_column = profile$analysis_columns$fold_change[[comparison]]
  )
  stopifnot(
    identical(columns$significance_column, paste0(comparison, "_pval")),
    identical(columns$fold_change_column, paste0(comparison, "_logFC"))
  )
}

# The explicit comparison order wins over source order.
reordered <- normalize_findmarkers_deg_input(
  deg,
  comparison_labels = c("C_3_vs_all", "C_1_vs_2")
)
stopifnot(identical(reordered$comparisons, c("C_3_vs_all", "C_1_vs_2")))

message("OMIX-L2P-Single FindMarkers compatibility checks passed")
