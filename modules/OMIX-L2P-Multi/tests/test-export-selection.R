#!/usr/bin/env Rscript

test_args <- commandArgs(FALSE)
test_file <- sub("^--file=", "", test_args[grepl("^--file=", test_args)])
module_dir <- normalizePath(file.path(dirname(test_file), ".."))
source(file.path(module_dir, "R", "analysis_functions.R"))

make_result <- function(pathways, hits, p_values) {
  data.frame(
    pathway_name = pathways,
    number_hits = hits,
    pval = p_values,
    fdr = p_values,
    stringsAsFactors = FALSE
  )
}

l2p_results <- list(
  "B-A" = list(
    up = make_result(c("PATH_A", "PATH_B", "PATH_C"), c(6, 6, 6), c(0.001, 0.020, 0.200)),
    down = make_result(c("PATH_D"), c(6), c(0.030))
  ),
  "C-A" = list(
    up = make_result(c("PATH_A", "PATH_C", "PATH_E"), c(6, 6, 4), c(0.040, 0.010, 0.001)),
    down = make_result(character(), numeric(), numeric())
  )
)

selected_once <- select_l2p_multi_export_pathways(
  l2p_results,
  comparison_labels = names(l2p_results),
  p_value_limit = 0.05,
  minimum_pathway_hit_count = 5,
  number_of_significant_events = 1L
)
selected_twice <- select_l2p_multi_export_pathways(
  l2p_results,
  comparison_labels = names(l2p_results),
  p_value_limit = 0.05,
  minimum_pathway_hit_count = 5,
  number_of_significant_events = 2L
)

stopifnot(identical(selected_once, c("PATH_A", "PATH_B", "PATH_C", "PATH_D")))
stopifnot(identical(selected_twice, "PATH_A"))
message("OMIX-L2P-Multi export-selection checks passed")
