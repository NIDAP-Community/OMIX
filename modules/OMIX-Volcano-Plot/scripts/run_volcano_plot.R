#!/usr/bin/env Rscript

# Platform-neutral command-line entry point for OMIX Volcano Plot.

suppressPackageStartupMessages({
  library(optparse)
  library(dplyr)
  library(tidyr)
  library(ggplot2)
  library(ggrepel)
})

script_argument <- commandArgs(FALSE)
script_file <- sub("^--file=", "", script_argument[grepl("^--file=", script_argument)])
if (length(script_file) != 1L) {
  stop("ERROR: Could not determine the location of scripts/run_volcano_plot.R")
}
module_root <- normalizePath(file.path(dirname(script_file), ".."))
source(file.path(module_root, "R", "Volcano_Plot_Enhanced.R"))

option_list <- list(
  make_option("--deg_table", type = "character", help = "Path to the DEG table (CSV, TSV, TXT, or RDS)"),
  make_option("--output_dir", type = "character", default = "results", help = "Directory for result files [default: %default]"),
  make_option("--pvalue_type", type = "character", default = "nominal", help = "P-value type used for inference [default: %default]"),
  make_option("--column_with_feature_id", type = "character", default = NULL),
  make_option("--significance_column", type = "character", default = NULL, help = "One or more comma-separated significance columns"),
  make_option("--log2_fold_change_column", type = "character", default = NULL, help = "One or more comma-separated log2 fold-change columns"),
  make_option("--p_value_threshold", type = "double", default = 0.05),
  make_option("--log2_fold_change_threshold", type = "double", default = 1.0),
  make_option("--choose_feature_to_label_by", type = "character", default = "p-value"),
  make_option("--number_of_features_to_label", type = "integer", default = 30L),
  make_option("--label_only_my_feature_list", type = "character", default = "false"),
  make_option("--my_feature_list", type = "character", default = ""),
  make_option("--top_genes_labeled_only_if_passing_thresholds", type = "character", default = "true"),
  make_option("--label_size", type = "double", default = 4),
  make_option("--label_box_padding", type = "double", default = 1),
  make_option("--label_force", type = "double", default = 1),
  make_option("--label_max_overlaps", type = "double", default = Inf),
  make_option("--use_custom_axis_label", type = "character", default = "false"),
  make_option("--custom_significance_label", type = "character", default = "p-value"),
  make_option("--custom_log_fold_change_label", type = "character", default = "log2FC"),
  make_option("--plot_title", type = "character", default = "Volcano Plot"),
  make_option("--plot_subtitle", type = "character", default = ""),
  make_option("--y_limit", type = "double", default = 0),
  make_option("--use_auto_axis_capping", type = "character", default = "true"),
  make_option("--auto_axis_capping_quantile", type = "double", default = 0.9999),
  make_option("--auto_axis_capping_symmetric_x", type = "character", default = "true"),
  make_option("--custom_x_axis_limits", type = "character", default = ""),
  make_option("--x_limit_padding", type = "double", default = 0),
  make_option("--y_limit_padding", type = "double", default = 0),
  make_option("--plot_title_size", type = "double", default = 16),
  make_option("--axis_title_size", type = "double", default = 14),
  make_option("--axis_text_size", type = "double", default = 12),
  make_option("--point_size", type = "double", default = 2),
  make_option("--image_width", type = "integer", default = 3000L),
  make_option("--image_height", type = "integer", default = 3000L),
  make_option("--resolution_dpi", type = "integer", default = 300L),
  make_option("--color_not_significant", type = "character", default = "gray"),
  make_option("--color_fold_change_only", type = "character", default = "orange"),
  make_option("--color_significant_only", type = "character", default = "green4"),
  make_option("--color_significant_and_fold_change", type = "character", default = "red3")
)

parser <- OptionParser(
  usage = "Usage: %prog --deg_table PATH [options]",
  option_list = option_list,
  description = "Generate enhanced volcano plots from a differential-expression table"
)
opt <- parse_args(parser)

if (is.null(opt$deg_table) || !nzchar(opt$deg_table)) {
  stop("ERROR: `--deg_table` is required")
}
if (!file.exists(opt$deg_table)) {
  stop("ERROR: DEG table was not found: ", opt$deg_table)
}

read_deg_table <- function(path) {
  extension <- tolower(tools::file_ext(path))
  if (extension == "rds") {
    object <- readRDS(path)
    if (is.list(object) && !is.data.frame(object)) {
      table_indices <- which(vapply(object, is.data.frame, logical(1)))
      if (length(table_indices) == 0L) {
        stop("ERROR: RDS file does not contain a data frame")
      }
      object <- object[[table_indices[1]]]
    }
    return(object)
  }
  if (extension == "csv") {
    return(read.csv(path, stringsAsFactors = FALSE, check.names = FALSE))
  }
  read.delim(path, stringsAsFactors = FALSE, check.names = FALSE)
}

as_logical <- function(value, option_name) {
  normalized <- tolower(value)
  if (!normalized %in% c("true", "false")) {
    stop("ERROR: `--", option_name, "` must be true or false")
  }
  identical(normalized, "true")
}

as_columns <- function(value) {
  if (is.null(value) || !nzchar(trimws(value))) {
    return(NULL)
  }
  trimws(strsplit(value, ",", fixed = TRUE)[[1]])
}

deg_table <- read_deg_table(opt$deg_table)
if (!is.data.frame(deg_table)) {
  stop("ERROR: Loaded DEG table is not a data frame")
}
dir.create(opt$output_dir, recursive = TRUE, showWarnings = FALSE)

results <- volcano_plot_enhanced(
  deg_table = deg_table,
  pvalue_type = opt$pvalue_type,
  column_with_feature_id = opt$column_with_feature_id,
  significance_column = as_columns(opt$significance_column),
  log2_fold_change_column = as_columns(opt$log2_fold_change_column),
  p_value_threshold = opt$p_value_threshold,
  log2_fold_change_threshold = opt$log2_fold_change_threshold,
  choose_feature_to_label_by = opt$choose_feature_to_label_by,
  number_of_features_to_label = opt$number_of_features_to_label,
  label_only_my_feature_list = as_logical(opt$label_only_my_feature_list, "label_only_my_feature_list"),
  my_feature_list = opt$my_feature_list,
  top_genes_labeled_only_if_passing_thresholds = as_logical(opt$top_genes_labeled_only_if_passing_thresholds, "top_genes_labeled_only_if_passing_thresholds"),
  label_size = opt$label_size,
  label_box_padding = opt$label_box_padding,
  label_force = opt$label_force,
  label_max_overlaps = opt$label_max_overlaps,
  use_custom_axis_label = as_logical(opt$use_custom_axis_label, "use_custom_axis_label"),
  custom_significance_label = opt$custom_significance_label,
  custom_log_fold_change_label = opt$custom_log_fold_change_label,
  plot_title = opt$plot_title,
  plot_subtitle = opt$plot_subtitle,
  y_limit = opt$y_limit,
  use_auto_axis_capping = as_logical(opt$use_auto_axis_capping, "use_auto_axis_capping"),
  auto_axis_capping_quantile = opt$auto_axis_capping_quantile,
  auto_axis_capping_min_y_limit = 0,
  auto_axis_capping_symmetric_x = as_logical(opt$auto_axis_capping_symmetric_x, "auto_axis_capping_symmetric_x"),
  custom_x_axis_limits = opt$custom_x_axis_limits,
  x_limit_padding = opt$x_limit_padding,
  y_limit_padding = opt$y_limit_padding,
  plot_title_size = opt$plot_title_size,
  axis_title_size = opt$axis_title_size,
  axis_text_size = opt$axis_text_size,
  point_size = opt$point_size,
  image_width = opt$image_width,
  image_height = opt$image_height,
  resolution_dpi_ = opt$resolution_dpi,
  output_file_path = file.path(opt$output_dir, "volcano_plot.png"),
  color_not_significant = opt$color_not_significant,
  color_fold_change_only = opt$color_fold_change_only,
  color_significant_only = opt$color_significant_only,
  color_significant_and_fold_change = opt$color_significant_and_fold_change
)

output_table <- file.path(opt$output_dir, "volcano_plot_data.csv")
write.csv(results, output_table, row.names = FALSE)
message("Volcano plots and data saved to: ", opt$output_dir)
