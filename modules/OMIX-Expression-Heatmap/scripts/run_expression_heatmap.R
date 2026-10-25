#!/usr/bin/env Rscript

# Platform-neutral command-line entry point for OMIX Expression Heatmap.

suppressPackageStartupMessages(library(optparse))

script_argument <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
if (length(script_argument) != 1L) {
  stop("Could not determine the location of scripts/run_expression_heatmap.R")
}
module_root <- normalizePath(file.path(dirname(sub("^--file=", "", script_argument)), ".."))
source(file.path(module_root, "R", "OMIX_Expression_Heatmap.R"))

split_csv <- function(value) {
  if (is.null(value) || !nzchar(trimws(value))) return(character())
  trimws(strsplit(value, ",", fixed = TRUE)[[1L]])
}

as_logical <- function(value, argument) {
  value <- tolower(trimws(value))
  if (value %in% c("true", "t", "1", "yes")) return(TRUE)
  if (value %in% c("false", "f", "0", "no")) return(FALSE)
  stop("--", argument, " must be true or false.")
}

read_table <- function(path, label) {
  if (!file.exists(path)) stop(label, " file does not exist: ", path)
  extension <- tolower(tools::file_ext(path))
  delimiter <- if (extension == "csv") "," else "\t"
  utils::read.delim(path, sep = delimiter, check.names = FALSE, stringsAsFactors = FALSE)
}

option_list <- list(
  make_option("--expression_matrix", type = "character", default = ""),
  make_option("--sample_metadata", type = "character", default = ""),
  make_option("--gene_column", type = "character", default = "auto"),
  make_option("--sample_name_column", type = "character", default = "Sample"),
  make_option("--sample_label_column", type = "character", default = "Sample"),
  make_option("--samples_to_include", type = "character", default = ""),
  make_option("--group_columns", type = "character", default = ""),
  make_option("--include_all_genes", type = "character", default = "false"),
  make_option("--filter_top_genes_by_variance", type = "character", default = "true"),
  make_option("--top_genes_by_variance_to_include", type = "integer", default = 500L),
  make_option("--specific_genes_to_include", type = "character", default = "None"),
  make_option("--cluster_genes", type = "character", default = "true"),
  make_option("--cluster_samples", type = "character", default = "true"),
  make_option("--arrange_sample_columns", type = "character", default = "false"),
  make_option("--order_by_gene_expression", type = "character", default = "false"),
  make_option("--gene_to_order_columns", type = "character", default = ""),
  make_option("--gene_expression_order", type = "character", default = "low_to_high"),
  make_option("--reorder_sample_dendrogram", type = "character", default = "false"),
  make_option("--reorder_sample_dendrogram_order", type = "character", default = ""),
  make_option("--center_and_rescale", type = "character", default = "true"),
  make_option("--display_gene_names", type = "character", default = "auto"),
  make_option("--display_sample_names", type = "character", default = "true"),
  make_option("--heatmap_color_scheme", type = "character", default = "Bu Yl Rd"),
  make_option("--autoscale_heatmap_color", type = "character", default = "true"),
  make_option("--set_min_heatmap_color", type = "double", default = -2),
  make_option("--set_max_heatmap_color", type = "double", default = 2),
  make_option("--gene_name_font_size", type = "character", default = "auto"),
  make_option("--row_label_max_length", type = "integer", default = 30L),
  make_option("--sample_name_font_size", type = "character", default = "auto"),
  make_option("--legend_font_size", type = "double", default = 10),
  make_option("--heatmap_title", type = "character", default = ""),
  make_option("--image_width", type = "double", default = 12),
  make_option("--image_height", type = "double", default = 10),
  make_option("--output_dir", type = "character", default = "results")
)
opt <- parse_args(OptionParser(option_list = option_list))

if (!nzchar(opt$expression_matrix) || !nzchar(opt$sample_metadata)) {
  stop("--expression_matrix and --sample_metadata are required.")
}
if (opt$top_genes_by_variance_to_include < 1L) {
  stop("--top_genes_by_variance_to_include must be at least 1.")
}
if (opt$row_label_max_length < 1L) {
  stop("--row_label_max_length must be at least 1.")
}
if (!is.finite(opt$image_width) || !is.finite(opt$image_height) ||
    opt$image_width <= 0 || opt$image_height <= 0) {
  stop("--image_width and --image_height must be positive.")
}

expression <- read_table(opt$expression_matrix, "expression_matrix")
metadata <- read_table(opt$sample_metadata, "sample_metadata")
gene_column <- opt$gene_column
if (identical(gene_column, "auto")) {
  candidates <- c("Gene", "GeneName")
  gene_column <- candidates[candidates %in% names(expression)][1L]
  if (is.na(gene_column) || !nzchar(gene_column)) gene_column <- names(expression)[1L]
}
if (!gene_column %in% names(expression)) stop("Gene column not found: ", gene_column)
if (!opt$sample_name_column %in% names(metadata)) {
  stop("Sample-ID column not found in metadata: ", opt$sample_name_column)
}
if (!opt$sample_label_column %in% names(metadata)) {
  stop("Sample-label column not found in metadata: ", opt$sample_label_column)
}
group_columns <- split_csv(opt$group_columns)
missing_groups <- setdiff(group_columns, names(metadata))
if (length(missing_groups)) stop("Metadata grouping column(s) not found: ", paste(missing_groups, collapse = ", "))
reorder_sample_dendrogram_order <- split_csv(opt$reorder_sample_dendrogram_order)

if (!identical(gene_column, "Gene")) names(expression)[names(expression) == gene_column] <- "Gene"
samples_to_include <- split_csv(opt$samples_to_include)
if (!length(samples_to_include)) {
  samples_to_include <- intersect(as.character(metadata[[opt$sample_name_column]]), names(expression))
}
if (!length(samples_to_include)) stop("No metadata sample IDs matched expression-matrix columns.")
missing_samples <- setdiff(samples_to_include, names(expression))
if (length(missing_samples)) stop("Expression-matrix sample columns not found: ", paste(missing_samples, collapse = ", "))
if (!all(vapply(expression[samples_to_include], is.numeric, logical(1)))) {
  stop("Selected expression-matrix sample columns must be numeric.")
}

dir.create(opt$output_dir, recursive = TRUE, showWarnings = FALSE)
output_dir <- normalizePath(opt$output_dir, mustWork = TRUE)
matrix_path <- file.path(output_dir, "expression_heatmap_matrix.csv")
plot_path <- file.path(output_dir, "expression_heatmap.png")

result <- Expression_Heatmap_ComplexHeatmap(
  counts_matrix = expression,
  sample_metadata = metadata,
  gene_column_name = "Gene",
  sample_name_column = opt$sample_name_column,
  sample_label_column = opt$sample_label_column,
  samples_to_include = samples_to_include,
  group_columns = group_columns,
  include_all_genes = as_logical(opt$include_all_genes, "include_all_genes"),
  filter_top_genes_by_variance = as_logical(opt$filter_top_genes_by_variance, "filter_top_genes_by_variance"),
  top_genes_by_variance_to_include = opt$top_genes_by_variance_to_include,
  specific_genes_to_include = opt$specific_genes_to_include,
  cluster_genes = as_logical(opt$cluster_genes, "cluster_genes"),
  cluster_samples = as_logical(opt$cluster_samples, "cluster_samples"),
  arrange_sample_columns = as_logical(opt$arrange_sample_columns, "arrange_sample_columns"),
  order_by_gene_expression = as_logical(opt$order_by_gene_expression, "order_by_gene_expression"),
  gene_to_order_columns = if (nzchar(trimws(opt$gene_to_order_columns))) opt$gene_to_order_columns else NULL,
  gene_expression_order = opt$gene_expression_order,
  reorder_sample_dendrogram = as_logical(opt$reorder_sample_dendrogram, "reorder_sample_dendrogram"),
  reorder_sample_dendrogram_order = reorder_sample_dendrogram_order,
  center_and_rescale = as_logical(opt$center_and_rescale, "center_and_rescale"),
  display_gene_names = opt$display_gene_names,
  display_sample_names = as_logical(opt$display_sample_names, "display_sample_names"),
  heatmap_color_scheme = opt$heatmap_color_scheme,
  autoscale_heatmap_color = as_logical(opt$autoscale_heatmap_color, "autoscale_heatmap_color"),
  set_min_heatmap_color = opt$set_min_heatmap_color,
  set_max_heatmap_color = opt$set_max_heatmap_color,
  gene_name_font_size = opt$gene_name_font_size,
  row_label_max_length = opt$row_label_max_length,
  sample_name_font_size = opt$sample_name_font_size,
  legend_font_size = opt$legend_font_size,
  heatmap_title = if (nzchar(opt$heatmap_title)) opt$heatmap_title else NULL,
  export_results_file = matrix_path,
  export_plot_file = plot_path,
  export_plot_width = opt$image_width,
  export_plot_height = opt$image_height
)

writeLines(c(
  paste("module=omix-expression-heatmap"),
  paste("expression_matrix=", normalizePath(opt$expression_matrix), sep = ""),
  paste("sample_metadata=", normalizePath(opt$sample_metadata), sep = ""),
  paste("selected_samples=", paste(samples_to_include, collapse = ","), sep = ""),
  paste("group_columns=", paste(group_columns, collapse = ","), sep = ""),
  paste("cluster_samples=", opt$cluster_samples, sep = ""),
  paste("arrange_sample_columns=", opt$arrange_sample_columns, sep = ""),
  paste("order_by_gene_expression=", opt$order_by_gene_expression, sep = ""),
  paste("gene_to_order_columns=", opt$gene_to_order_columns, sep = ""),
  paste("gene_expression_order=", opt$gene_expression_order, sep = ""),
  paste("reorder_sample_dendrogram=", opt$reorder_sample_dendrogram, sep = ""),
  paste("reorder_sample_dendrogram_order=", paste(reorder_sample_dendrogram_order, collapse = ","), sep = ""),
  paste("display_gene_names=", opt$display_gene_names, sep = ""),
  paste("gene_name_font_size=", opt$gene_name_font_size, sep = ""),
  paste("row_label_max_length=", opt$row_label_max_length, sep = ""),
  paste("sample_name_font_size=", opt$sample_name_font_size, sep = ""),
  paste("resolved_sample_name_font_size=", attr(result, "effective_sample_name_font_size"), sep = ""),
  paste("plotted_features=", nrow(result), sep = "")
), file.path(output_dir, "expression_heatmap_run_summary.txt"))
message("Expression heatmap outputs saved to: ", output_dir)
