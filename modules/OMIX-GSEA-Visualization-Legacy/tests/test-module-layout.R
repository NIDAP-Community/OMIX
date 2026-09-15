#!/usr/bin/env Rscript

test_args <- commandArgs(FALSE)
test_file <- sub("^--file=", "", test_args[grepl("^--file=", test_args)])
module_dir <- normalizePath(file.path(dirname(test_file), ".."))
function_file <- file.path(module_dir, "R", "gsea_enrichment_plot.R")
cli_file <- file.path(module_dir, "scripts", "run_gsea_visualization.R")

stopifnot(file.exists(function_file), file.exists(cli_file))
invisible(parse(file = function_file))
invisible(parse(file = cli_file))

cli_text <- paste(readLines(cli_file, warn = FALSE), collapse = "\n")
stopifnot(!grepl('"/data', cli_text, fixed = TRUE))
stopifnot(!grepl('"/results', cli_text, fixed = TRUE))
stopifnot(grepl("--msigdb_database", cli_text, fixed = TRUE))
stopifnot(grepl("--sample_metadata", cli_text, fixed = TRUE))
stopifnot(grepl("--top_n_pathways", cli_text, fixed = TRUE))
stopifnot(grepl('make_option("--top_n_pathways", type = "integer", default = 20L,', cli_text, fixed = TRUE))
stopifnot(grepl("--pathway_bubble_plots", cli_text, fixed = TRUE))
stopifnot(grepl("--pathway_bubble_top_n", cli_text, fixed = TRUE))
stopifnot(grepl('make_option("--pathway_bubble_top_n", type = "integer", default = 20L,', cli_text, fixed = TRUE))
stopifnot(grepl("--pathway_bubble_significance_statistic", cli_text, fixed = TRUE))
stopifnot(grepl('default = "padj"', cli_text, fixed = TRUE))
stopifnot(grepl("--collection_color_scale", cli_text, fixed = TRUE))
stopifnot(grepl("OmixPathwayPlots::plot_pathway_bubble_set", cli_text, fixed = TRUE))
stopifnot(grepl("OmixPathwayPlots::save_pathway_bubble_set", cli_text, fixed = TRUE))
stopifnot(grepl('"across_all_collections"', cli_text, fixed = TRUE))

source(function_file)
selection_fixture <- data.frame(
  contrast = rep("B-A", 25L),
  collection = rep("H", 25L),
  pathway = paste("pathway", seq_len(25L)),
  pval = seq_len(25L) / 100,
  stringsAsFactors = FALSE
)
default_selected <- gsea_vis_select_rows(selection_fixture)
stopifnot(nrow(default_selected) == 20L)
stopifnot(identical(as.character(default_selected$pathway), paste("pathway", seq_len(20L))))

message("OMIX-GSEA-Visualization-Legacy module layout checks passed")
