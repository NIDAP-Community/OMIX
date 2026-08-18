#!/usr/bin/env Rscript

# Platform-neutral command-line entry point for OMIX L2P Multi.

suppressPackageStartupMessages({
  library(optparse)
  library(dplyr)
  library(tidyr)
  library(ggplot2)
  library(stringr)
  library(magrittr)
  library(l2p)
  library(l2psupp)
})

script_argument <- commandArgs(FALSE)
script_file <- sub("^--file=", "", script_argument[grepl("^--file=", script_argument)])
if (length(script_file) != 1L) stop("ERROR: Could not determine the location of scripts/run_l2p_multi.R")
module_root <- normalizePath(file.path(dirname(script_file), ".."))
source(file.path(module_root, "R", "analysis_functions.R"))

option_list <- list(
  make_option("--deg_table", type = "character", help = "Path to the DEG table (CSV, TSV, TXT, or RDS)"),
  make_option("--comparisons", type = "character", help = "Comma-separated comparison identifiers"),
  make_option("--output_dir", type = "character", default = "results", help = "Directory for result files [default: %default]"),
  make_option("--gene_names_column", type = "character", default = NULL),
  make_option("--t_statistic_columns", type = "character", default = NULL),
  make_option("--significance_columns", type = "character", default = NULL),
  make_option("--fold_change_columns", type = "character", default = NULL),
  make_option("--species", type = "character", default = "Human"),
  make_option("--update_genes", type = "character", default = "true"),
  make_option("--collections_to_include", type = "character", default = "H"),
  make_option("--select_by_rank", type = "character", default = "true"),
  make_option("--select_top_percentage_of_genes", type = "character", default = "true"),
  make_option("--select_top_genes", type = "integer", default = 500L),
  make_option("--significance_threshold", type = "double", default = 0.05),
  make_option("--fold_change_threshold", type = "double", default = 1.2),
  make_option("--minimum_number_of_deg_genes", type = "integer", default = 100L),
  make_option("--top_pathways", type = "integer", default = 10L),
  make_option("--number_of_significant_events", type = "integer", default = 1L),
  make_option("--maximum_pathways_to_plot", type = "integer", default = 15L),
  make_option("--plot_bubble_size", type = "character", default = "pval"),
  make_option("--plot_bubble_color", type = "character", default = "enrichment_score"),
  make_option("--plot_bubble_max_color", type = "double", default = 1),
  make_option("--pathway_axis_label_max_length", type = "integer", default = 45L),
  make_option("--pathway_axis_label_font_size", type = "double", default = 5),
  make_option("--use_built_in_gene_universe", type = "character", default = "false"),
  make_option("--minimum_pathway_hit_count", type = "integer", default = 5L),
  make_option("--pathway_size_limit", type = "integer", default = 500L),
  make_option("--p_value_limit", type = "double", default = 0.05),
  make_option("--use_fdr_for_significance", type = "character", default = "false"),
  make_option("--custom_pathways", type = "character", default = NULL),
  make_option("--custom_pathway_name_column", type = "character", default = "gene_set_name"),
  make_option("--custom_pathway_gene_column", type = "character", default = "gene_symbol"),
  make_option("--pathways_to_remove", type = "character", default = NULL),
  make_option("--rename_groups", type = "character", default = NULL),
  make_option("--vertical_line_placement", type = "character", default = NULL),
  make_option("--use_panel_plot", type = "character", default = "false"),
  make_option("--use_dynamic_pathway_font_size", type = "character", default = "true"),
  make_option("--custom_pathway_order", type = "character", default = NULL),
  make_option("--x_axis_title", type = "character", default = NULL),
  make_option("--y_axis_title", type = "character", default = NULL),
  make_option("--x_axis_title_font_size", type = "double", default = 14),
  make_option("--y_axis_title_font_size", type = "double", default = 14),
  make_option("--x_axis_tick_font_size", type = "double", default = 14),
  make_option("--x_axis_tick_labels", type = "character", default = NULL),
  make_option("--y_axis_tick_labels", type = "character", default = NULL),
  make_option("--plot_width", type = "double", default = 14),
  make_option("--plot_height", type = "double", default = 16),
  make_option("--column_spacing", type = "double", default = 0.5)
)

parser <- OptionParser(
  usage = "Usage: %prog --deg_table PATH --comparisons A-B,C-B [options]",
  option_list = option_list,
  description = "Run multi-comparison L2P over-representation analysis"
)
opt <- parse_args(parser)
for (required_option in c("deg_table", "comparisons")) {
  if (is.null(opt[[required_option]]) || !nzchar(opt[[required_option]])) stop("ERROR: `--", required_option, "` is required")
}
if (!file.exists(opt$deg_table)) stop("ERROR: DEG table was not found: ", opt$deg_table)
if (!is.null(opt$custom_pathways) && nzchar(opt$custom_pathways) && !file.exists(opt$custom_pathways)) stop("ERROR: Custom pathways file was not found: ", opt$custom_pathways)

as_list <- function(value) {
  if (is.null(value) || !nzchar(trimws(value))) return(NULL)
  trimws(strsplit(value, ",", fixed = TRUE)[[1]])
}
as_numeric_list <- function(value) {
  values <- as_list(value)
  if (is.null(values)) return(numeric())
  as.numeric(values)
}
as_logical <- function(value, option_name) {
  normalized <- tolower(value)
  if (!normalized %in% c("true", "false")) stop("ERROR: `--", option_name, "` must be true or false")
  identical(normalized, "true")
}
read_table <- function(path) {
  extension <- tolower(tools::file_ext(path))
  if (extension == "rds") {
    object <- readRDS(path)
    if (is.list(object) && !is.data.frame(object)) {
      table_indices <- which(vapply(object, is.data.frame, logical(1)))
      if (length(table_indices) == 0L) stop("ERROR: RDS file does not contain a data frame")
      object <- object[[table_indices[1]]]
    }
    return(object)
  }
  if (extension == "csv") return(read.csv(path, stringsAsFactors = FALSE, check.names = FALSE))
  read.delim(path, stringsAsFactors = FALSE, check.names = FALSE)
}
load_custom_pathways <- function(path) {
  if (is.null(path) || !nzchar(path)) return(NULL)
  extension <- tolower(tools::file_ext(path))
  if (extension == "rds") return(readRDS(path))
  if (extension == "csv") return(read.csv(path, stringsAsFactors = FALSE, check.names = FALSE))
  read.delim(path, stringsAsFactors = FALSE, check.names = FALSE)
}

deg_table <- read_table(opt$deg_table)
if (!is.data.frame(deg_table)) stop("ERROR: Loaded DEG table is not a data frame")
dir.create(opt$output_dir, recursive = TRUE, showWarnings = FALSE)

results <- l2p_multi(
  deg_table = deg_table,
  gene_names_column = opt$gene_names_column,
  t_statistic_columns = as_list(opt$t_statistic_columns),
  significance_columns = as_list(opt$significance_columns),
  fold_change_columns = as_list(opt$fold_change_columns),
  comparisons = as_list(opt$comparisons),
  species = opt$species,
  update_genes = as_logical(opt$update_genes, "update_genes"),
  collections_to_include = as_list(opt$collections_to_include),
  custom_pathways = load_custom_pathways(opt$custom_pathways),
  custom_pathway_name_column = opt$custom_pathway_name_column,
  custom_pathway_gene_column = opt$custom_pathway_gene_column,
  select_by_rank = as_logical(opt$select_by_rank, "select_by_rank"),
  top_pathways = opt$top_pathways,
  number_of_significant_events = opt$number_of_significant_events,
  select_top_percentage_of_genes = as_logical(opt$select_top_percentage_of_genes, "select_top_percentage_of_genes"),
  select_top_genes = opt$select_top_genes,
  significance_threshold = opt$significance_threshold,
  fold_change_threshold = opt$fold_change_threshold,
  minimum_number_of_deg_genes = opt$minimum_number_of_deg_genes,
  plot_bubble_size = opt$plot_bubble_size,
  plot_bubble_color = opt$plot_bubble_color,
  plot_bubble_max_color = opt$plot_bubble_max_color,
  pathway_axis_label_max_length = opt$pathway_axis_label_max_length,
  pathway_axis_label_font_size = opt$pathway_axis_label_font_size,
  use_built_in_gene_universe = as_logical(opt$use_built_in_gene_universe, "use_built_in_gene_universe"),
  minimum_pathway_hit_count = opt$minimum_pathway_hit_count,
  pathway_size_limit = opt$pathway_size_limit,
  p_value_limit = opt$p_value_limit,
  use_fdr_for_significance = as_logical(opt$use_fdr_for_significance, "use_fdr_for_significance"),
  maximum_pathways_to_plot = opt$maximum_pathways_to_plot,
  pathways_to_remove = as_list(opt$pathways_to_remove),
  rename_groups = as_list(opt$rename_groups),
  vertical_line_placement = as_numeric_list(opt$vertical_line_placement),
  use_panel_plot = as_logical(opt$use_panel_plot, "use_panel_plot"),
  use_dynamic_pathway_font_size = as_logical(opt$use_dynamic_pathway_font_size, "use_dynamic_pathway_font_size"),
  custom_pathway_order = as_list(opt$custom_pathway_order),
  x_axis_title = opt$x_axis_title,
  y_axis_title = opt$y_axis_title,
  x_axis_title_font_size = opt$x_axis_title_font_size,
  y_axis_title_font_size = opt$y_axis_title_font_size,
  x_axis_tick_font_size = opt$x_axis_tick_font_size,
  x_axis_tick_labels = as_list(opt$x_axis_tick_labels),
  y_axis_tick_labels = as_list(opt$y_axis_tick_labels),
  export_plot_file = file.path(opt$output_dir, "l2p_multi_plot.png"),
  export_plot_width = opt$plot_width,
  export_plot_height = opt$plot_height,
  column_spacing = opt$column_spacing,
  export_results_file = file.path(opt$output_dir, "l2p_multi_results.csv")
)

message("L2P Multi analysis complete. Results saved to: ", opt$output_dir)
invisible(results)
