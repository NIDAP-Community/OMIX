#!/usr/bin/env Rscript

# Platform-neutral command-line entry point for OMIX PCA 3D.

suppressPackageStartupMessages(library(optparse))

script_argument <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
if (length(script_argument) != 1L) {
  stop("Could not determine the location of scripts/run_pca_3d.R", call. = FALSE)
}
module_root <- normalizePath(file.path(dirname(sub("^--file=", "", script_argument)), ".."))
source(file.path(module_root, "R", "OMIX_PCA_3D.R"))

split_csv <- function(value) {
  if (is.null(value) || !nzchar(trimws(value))) return(character())
  trimws(strsplit(value, ",", fixed = TRUE)[[1L]])
}

as_logical <- function(value, argument) {
  value <- tolower(trimws(value))
  if (value %in% c("true", "t", "1", "yes")) return(TRUE)
  if (value %in% c("false", "f", "0", "no")) return(FALSE)
  stop("--", argument, " must be true or false.", call. = FALSE)
}

read_table <- function(path, label) {
  if (!file.exists(path)) stop(label, " file does not exist: ", path, call. = FALSE)
  extension <- tolower(tools::file_ext(path))
  delimiter <- if (extension == "csv") "," else "\t"
  utils::read.delim(path, sep = delimiter, check.names = FALSE, stringsAsFactors = FALSE)
}

resolve_feature_id_column <- function(matrix_table, requested) {
  if (!identical(requested, "auto")) return(requested)
  candidates <- c("Gene", "GeneName")
  candidate <- candidates[candidates %in% names(matrix_table)][1L]
  if (is.na(candidate) || !nzchar(candidate)) names(matrix_table)[1L] else candidate
}

option_list <- list(
  make_option("--feature_matrix", type = "character", default = ""),
  make_option("--sample_metadata", type = "character", default = ""),
  make_option("--feature_id_column", type = "character", default = "auto"),
  make_option("--sample_id_column", type = "character", default = "Sample"),
  make_option("--sample_label_column", type = "character", default = "Sample"),
  make_option("--group_column", type = "character", default = "Group"),
  make_option("--samples_to_include", type = "character", default = ""),
  make_option("--outlier_sample_ids", type = "character", default = ""),
  make_option("--use_cpm", type = "character", default = "false"),
  make_option("--manual_label_renames", type = "character", default = ""),
  make_option("--point_colors", type = "character", default = "indigo,carrot,lipstick,turquoise,lavender,jade,coral,azure,green,rum,orange,olive"),
  make_option("--point_size", type = "double", default = 8),
  make_option("--plot_title", type = "character", default = "PCA 3D"),
  make_option("--self_contained_html", type = "character", default = "false"),
  make_option("--output_dir", type = "character", default = "results")
)
options <- parse_args(OptionParser(option_list = option_list))

if (!nzchar(options$feature_matrix) || !nzchar(options$sample_metadata)) {
  stop("--feature_matrix and --sample_metadata are required.", call. = FALSE)
}
if (!is.finite(options$point_size) || options$point_size <= 0) {
  stop("--point_size must be positive.", call. = FALSE)
}

feature_matrix <- read_table(options$feature_matrix, "feature_matrix")
sample_metadata <- read_table(options$sample_metadata, "sample_metadata")
feature_id_column <- resolve_feature_id_column(feature_matrix, options$feature_id_column)
if (!feature_id_column %in% names(feature_matrix)) {
  stop("Feature-ID column not found: ", feature_id_column, call. = FALSE)
}

samples_to_include <- split_csv(options$samples_to_include)
prepared <- omix_pca_3d_prepare(
  feature_matrix = feature_matrix,
  sample_metadata = sample_metadata,
  feature_id_column = feature_id_column,
  sample_id_column = options$sample_id_column,
  sample_label_column = options$sample_label_column,
  group_column = options$group_column,
  samples_to_include = samples_to_include,
  outlier_sample_ids = split_csv(options$outlier_sample_ids),
  use_cpm = as_logical(options$use_cpm, "use_cpm"),
  point_color_names = split_csv(options$point_colors),
  manual_label_renames = split_csv(options$manual_label_renames)
)

run_summary <- c(
  "module=omix-pca-3d",
  paste("feature_matrix=", normalizePath(options$feature_matrix), sep = ""),
  paste("sample_metadata=", normalizePath(options$sample_metadata), sep = ""),
  paste("feature_id_column=", feature_id_column, sep = ""),
  paste("sample_id_column=", options$sample_id_column, sep = ""),
  paste("sample_label_column=", options$sample_label_column, sep = ""),
  paste("group_column=", options$group_column, sep = ""),
  paste("selected_samples=", paste(prepared$selected_samples, collapse = ","), sep = ""),
  paste("outlier_sample_ids=", options$outlier_sample_ids, sep = ""),
  paste("use_cpm=", options$use_cpm, sep = ""),
  paste("manual_label_renames=", options$manual_label_renames, sep = ""),
  paste("point_colors=", paste(names(prepared$point_colors), prepared$point_colors, sep = ":", collapse = ","), sep = ""),
  paste("point_size=", options$point_size, sep = ""),
  "label_font_size=24",
  paste("plot_title=", options$plot_title, sep = ""),
  paste("self_contained_html=", options$self_contained_html, sep = ""),
  paste("features_after_template_filters=", prepared$feature_count, sep = "")
)

run_omix_pca_3d(
  prepared = prepared,
  output_dir = options$output_dir,
  plot_title = options$plot_title,
  point_size = options$point_size,
  label_font_size = 24,
  self_contained_html = as_logical(options$self_contained_html, "self_contained_html"),
  run_summary = run_summary
)
message("PCA 3D outputs saved to: ", normalizePath(options$output_dir))
