#!/usr/bin/env Rscript

# Platform-neutral command-line entry point for OMIX L2P Single.

suppressPackageStartupMessages({
  library(optparse)
  library(dplyr)
  library(ggplot2)
  library(stringr)
  library(magrittr)
  library(grid)
  library(l2p)
  library(l2psupp)
})

script_argument <- commandArgs(FALSE)
script_file <- sub("^--file=", "", script_argument[grepl("^--file=", script_argument)])
if (length(script_file) != 1L) {
  stop("ERROR: Could not determine the location of scripts/run_l2p_single.R")
}
module_root <- normalizePath(file.path(dirname(script_file), ".."))
source(file.path(module_root, "R", "L2P_Analysis.R"))

option_list <- list(
  make_option("--deg_table", type = "character", help = "Path to the DEG table (CSV, TSV, TXT, or RDS)"),
  make_option("--comparison", type = "character", default = NULL, help = "One comparison identifier to analyze; mutually exclusive with --comparisons"),
  make_option("--comparisons", type = "character", default = NULL, help = "Comma-separated comparison identifiers for independent batched runs; mutually exclusive with --comparison"),
  make_option("--output_dir", type = "character", default = "results", help = "Directory for result files [default: %default]"),
  make_option("--species", type = "character", default = "Human"),
  make_option("--collections_to_include", type = "character", default = "GO,REACTOME,KEGG"),
  make_option("--gene_names_column", type = "character", default = NULL),
  make_option("--t_statistic_column", type = "character", default = NULL),
  make_option("--significance_column", type = "character", default = NULL),
  make_option("--fold_change_column", type = "character", default = NULL),
  make_option("--select_by_rank", type = "character", default = "false"),
  make_option("--select_top_percentage_of_genes", type = "character", default = "true"),
  make_option("--select_top_genes", type = "integer", default = 500L),
  make_option("--significance_threshold", type = "double", default = 0.05),
  make_option("--fold_change_threshold", type = "double", default = 1.2),
  make_option("--minimum_number_of_deg_genes", type = "integer", default = 50L),
  make_option("--minimum_pathway_hit_count", type = "integer", default = 5L),
  make_option("--p_value_threshold_for_output", type = "double", default = 0.05),
  make_option("--use_built_in_gene_universe", type = "character", default = "false"),
  make_option("--use_fdr_p_values", type = "character", default = "false"),
  make_option("--custom_pathways", type = "character", default = NULL),
  make_option("--custom_pathway_name_column", type = "character", default = "gene_set_name"),
  make_option("--custom_pathway_gene_column", type = "character", default = "gene_symbol"),
  make_option("--number_of_pathways_to_plot", type = "integer", default = 20L),
  make_option("--pathway_axis_label_max_length", type = "integer", default = 50L),
  make_option("--pathway_axis_label_font_size", type = "integer", default = 15L),
  make_option("--x_axis_title_font_size", type = "integer", default = 20L),
  make_option("--y_axis_title_font_size", type = "integer", default = 20L),
  make_option("--x_axis_tick_font_size", type = "integer", default = 15L),
  make_option("--plot_top_pathways_up", type = "character", default = "true"),
  make_option("--pathways_to_use_up", type = "character", default = NULL),
  make_option("--plot_top_pathways_down", type = "character", default = "true"),
  make_option("--pathways_to_use_down", type = "character", default = NULL),
  make_option("--sort_bubble_plot_by", type = "character", default = "percent gene hits per pathway"),
  make_option("--plot_bubble_size", type = "character", default = "number of hits"),
  make_option("--plot_bubble_color", type = "character", default = "Fisher's Exact pval"),
  make_option("--bubble_colors", type = "character", default = "blues"),
  make_option("--color_for_bar", type = "character", default = "GreentoBlue"),
  make_option("--export_plot_width", type = "double", default = 12),
  make_option("--export_plot_height", type = "double", default = 12)
)

parser <- OptionParser(
  usage = "Usage: %prog --deg_table PATH (--comparison NAME | --comparisons A-B,C-B) [options]",
  option_list = option_list,
  description = "Run single-comparison L2P over-representation analysis"
)
opt <- parse_args(parser)

if (is.null(opt$deg_table) || !nzchar(opt$deg_table)) {
  stop("ERROR: `--deg_table` is required")
}
if (!file.exists(opt$deg_table)) {
  stop("ERROR: DEG table was not found: ", opt$deg_table)
}
if (!is.null(opt$custom_pathways) && nzchar(opt$custom_pathways) && !file.exists(opt$custom_pathways)) {
  stop("ERROR: Custom pathways file was not found: ", opt$custom_pathways)
}

read_deg_table <- function(path) {
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

as_logical <- function(value, option_name) {
  normalized <- tolower(value)
  if (!normalized %in% c("true", "false")) stop("ERROR: `--", option_name, "` must be true or false")
  identical(normalized, "true")
}

as_list <- function(value) {
  if (is.null(value) || !nzchar(trimws(value))) return(NULL)
  values <- trimws(strsplit(value, ",", fixed = TRUE)[[1]])
  values[nzchar(values)]
}

# Use exact list indexing: `$comparison` would partially match the plural
# option when `--comparison` is omitted.
single_comparison <- as_list(opt[["comparison"]])
batch_comparisons <- as_list(opt[["comparisons"]])
if (length(single_comparison) > 1L) {
  stop("ERROR: `--comparison` accepts exactly one identifier; use --comparisons for a batch")
}
if (length(single_comparison) > 0L && length(batch_comparisons) > 0L) {
  stop("ERROR: Supply either `--comparison` or `--comparisons`, not both")
}
comparisons <- if (length(batch_comparisons) > 0L) batch_comparisons else single_comparison
if (length(comparisons) == 0L) {
  stop("ERROR: Supply one comparison with `--comparison` or a comma-separated batch with `--comparisons`")
}
if (anyDuplicated(comparisons)) {
  stop("ERROR: Comparison identifiers must be unique: ", paste(comparisons, collapse = ", "))
}

is_batched_run <- length(comparisons) > 1L
comparison_specific_overrides <- c(
  t_statistic_column = opt$t_statistic_column,
  significance_column = opt$significance_column,
  fold_change_column = opt$fold_change_column
)
if (is_batched_run && any(!is.na(comparison_specific_overrides) & nzchar(comparison_specific_overrides))) {
  stop(
    "ERROR: Batched `--comparisons` uses comparison-prefixed DEG columns automatically. ",
    "Do not supply --t_statistic_column, --significance_column, or --fold_change_column."
  )
}

comparison_slug <- function(comparison) {
  slug <- gsub("[^A-Za-z0-9._-]+", "_", trimws(comparison))
  slug <- gsub("_+", "_", slug)
  slug <- gsub("^_+|_+$", "", slug)
  if (!nzchar(slug)) stop("ERROR: Comparison identifier cannot be converted into a safe output directory name")
  slug
}
comparison_slugs <- vapply(comparisons, comparison_slug, character(1))
if (anyDuplicated(comparison_slugs)) {
  stop("ERROR: Comparison identifiers resolve to duplicate output directory names: ", paste(comparison_slugs, collapse = ", "))
}

deg_table <- read_deg_table(opt$deg_table)
if (!is.data.frame(deg_table)) stop("ERROR: Loaded DEG table is not a data frame")
dir.create(opt$output_dir, recursive = TRUE, showWarnings = FALSE)

run_manifest <- lapply(seq_along(comparisons), function(index) {
  comparison <- comparisons[[index]]
  run_dir <- if (is_batched_run) file.path(opt$output_dir, comparison_slugs[[index]]) else opt$output_dir
  dir.create(run_dir, recursive = TRUE, showWarnings = FALSE)
  results_file <- file.path(run_dir, "l2p_results.csv")

  results <- l2p_single(
    deg_table = deg_table,
    gene_names_column = opt$gene_names_column,
    t_statistic_column = opt$t_statistic_column,
    significance_column = opt$significance_column,
    fold_change_column = opt$fold_change_column,
    comparison = comparison,
    plot_title_prefix = if (is_batched_run) comparison else NULL,
    species = opt$species,
    collections_to_include = as_list(opt$collections_to_include),
    custom_pathways = opt$custom_pathways,
    custom_pathway_name_column = opt$custom_pathway_name_column,
    custom_pathway_gene_column = opt$custom_pathway_gene_column,
    select_by_rank = as_logical(opt$select_by_rank, "select_by_rank"),
    select_top_percentage_of_genes = as_logical(opt$select_top_percentage_of_genes, "select_top_percentage_of_genes"),
    select_top_genes = opt$select_top_genes,
    significance_threshold = opt$significance_threshold,
    fold_change_threshold = opt$fold_change_threshold,
    minimum_number_of_deg_genes = opt$minimum_number_of_deg_genes,
    number_of_pathways_to_plot = opt$number_of_pathways_to_plot,
    pathway_axis_label_max_length = opt$pathway_axis_label_max_length,
    plot_top_pathways_up = as_logical(opt$plot_top_pathways_up, "plot_top_pathways_up"),
    pathways_to_use_up = as_list(opt$pathways_to_use_up),
    plot_top_pathways_down = as_logical(opt$plot_top_pathways_down, "plot_top_pathways_down"),
    pathways_to_use_down = as_list(opt$pathways_to_use_down),
    sort_bubble_plot_by = opt$sort_bubble_plot_by,
    plot_bubble_size = opt$plot_bubble_size,
    plot_bubble_color = opt$plot_bubble_color,
    bubble_colors = opt$bubble_colors,
    pathway_axis_label_font_size = opt$pathway_axis_label_font_size,
    x_axis_title_font_size = opt$x_axis_title_font_size,
    y_axis_title_font_size = opt$y_axis_title_font_size,
    x_axis_tick_font_size = opt$x_axis_tick_font_size,
    use_fdr_p_values = as_logical(opt$use_fdr_p_values, "use_fdr_p_values"),
    color_for_bar = opt$color_for_bar,
    use_built_in_gene_universe = as_logical(opt$use_built_in_gene_universe, "use_built_in_gene_universe"),
    minimum_pathway_hit_count = opt$minimum_pathway_hit_count,
    p_value_threshold_for_output = opt$p_value_threshold_for_output,
    export_plot_file = file.path(run_dir, "l2p_plots.png"),
    export_plot_width = opt$export_plot_width,
    export_plot_height = opt$export_plot_height,
    export_results_file = results_file
  )

  data.frame(
    comparison = comparison,
    output_directory = normalizePath(run_dir, winslash = "/", mustWork = FALSE),
    results_file = normalizePath(results_file, winslash = "/", mustWork = FALSE),
    provenance_file = normalizePath(file.path(run_dir, "l2p_results_provenance.csv"), winslash = "/", mustWork = FALSE),
    plot_prefix = normalizePath(file.path(run_dir, "l2p_plots.png"), winslash = "/", mustWork = FALSE),
    result_status = if (is.null(results)) "no_pathway_results" else "completed",
    result_row_count = if (is.null(results)) 0L else nrow(results),
    stringsAsFactors = FALSE
  )
})
run_manifest <- do.call(rbind, run_manifest)
manifest_file <- file.path(opt$output_dir, "l2p_single_run_manifest.csv")
utils::write.csv(run_manifest, manifest_file, row.names = FALSE)

message("L2P Single analysis complete. Run manifest: ", manifest_file)
invisible(run_manifest)
