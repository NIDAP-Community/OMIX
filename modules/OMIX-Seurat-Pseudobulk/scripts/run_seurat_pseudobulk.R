#!/usr/bin/env Rscript

# Platform-neutral command-line entry point for OMIX Seurat Pseudobulk.

suppressPackageStartupMessages(library(optparse))

script_argument <- commandArgs(FALSE)
script_file <- sub("^--file=", "", script_argument[grepl("^--file=", script_argument)])
if (length(script_file) != 1L) {
  stop("ERROR: Could not determine the location of scripts/run_seurat_pseudobulk.R")
}
module_root <- normalizePath(file.path(dirname(script_file), ".."))
source(file.path(module_root, "R", "Seurat_Pseudobulk.R"))

parse_csv_values <- function(value) {
  if (is.null(value) || !nzchar(value)) {
    return(NULL)
  }
  values <- trimws(strsplit(value, ",", fixed = TRUE)[[1L]])
  values <- values[nzchar(values)]
  if (length(values) == 0L) {
    return(NULL)
  }
  unique(values)
}

option_list <- list(
  make_option("--seurat_rds", type = "character", help = "Serialized Seurat object (.rds)"),
  make_option("--donor_column", type = "character", help = "Cell-metadata donor column"),
  make_option("--group_column", type = "character", help = "Cell-metadata group column"),
  make_option("--cell_type_column", type = "character", help = "Cell-metadata cell-type column"),
  make_option("--cell_type_mode", type = "character", default = "one", help = "one, selected, or all [default: %default]"),
  make_option("--cell_type", type = "character", default = "", help = "One exact cell type for --cell_type_mode one"),
  make_option("--cell_type_selection", type = "character", default = "", help = "Ordered one-column CellType CSV, TSV, or TXT table for --cell_type_mode selected"),
  make_option("--metadata_columns", type = "character", default = "", help = "Optional comma-separated invariant sample metadata columns, e.g. Batch,Sex"),
  make_option("--cell_filter_column", type = "character", default = "", help = "Optional cell-level filter column"),
  make_option("--cell_filter_values", type = "character", default = "", help = "Comma-separated values retained from --cell_filter_column"),
  make_option("--aggregation_method", type = "character", default = "sum_counts", help = "sum_counts, mean_harmony_corrected_expression, or mean_sctransform_expression [default: %default]"),
  make_option("--assay", type = "character", default = "auto", help = "Source assay; auto resolves to RNA for raw/Harmony and SCT for SCTransform"),
  make_option("--layer", type = "character", default = "auto", help = "Source layer; auto resolves to counts for sum_counts and data for continuous-expression modes"),
  make_option("--feature_id_column", type = "character", default = "GeneName", help = "Fixed downstream feature-ID column [default: %default]"),
  make_option("--min_cells", type = "integer", default = 20L),
  make_option("--on_insufficient_cells", type = "character", default = "error", help = "error or drop [default: %default]"),
  make_option("--output_dir", type = "character", default = "results")
)
parser <- OptionParser(
  usage = "Usage: %prog --seurat_rds OBJECT.rds --donor_column DONOR --group_column GROUP --cell_type_column CELLTYPE --cell_type VALUE [options]",
  option_list = option_list,
  description = "Create a donor-level raw-count, Harmony-expression, or SCTransform-expression bundle from one Seurat cell type for OMIX DEG Analysis."
)
opt <- parse_args(parser)

for (name in c("seurat_rds", "donor_column", "group_column", "cell_type_column")) {
  if (is.null(opt[[name]]) || !nzchar(opt[[name]])) {
    stop("ERROR: --", name, " is required")
  }
}
if (!opt$cell_type_mode %in% c("one", "selected", "all")) {
  stop("ERROR: --cell_type_mode must be one, selected, or all")
}
if (identical(opt$cell_type_mode, "one") && !nzchar(opt$cell_type)) {
  stop("ERROR: --cell_type is required when --cell_type_mode one")
}
if (identical(opt$cell_type_mode, "selected") && !nzchar(opt$cell_type_selection)) {
  stop("ERROR: --cell_type_selection is required when --cell_type_mode selected")
}
if (!identical(opt$cell_type_mode, "one") && nzchar(opt$cell_type)) {
  stop("ERROR: --cell_type is only valid when --cell_type_mode one")
}
if (!identical(opt$cell_type_mode, "selected") && nzchar(opt$cell_type_selection)) {
  stop("ERROR: --cell_type_selection is only valid when --cell_type_mode selected")
}
if (!opt$on_insufficient_cells %in% c("error", "drop")) {
  stop("ERROR: --on_insufficient_cells must be error or drop")
}
if (!opt$aggregation_method %in% c("sum_counts", "mean_harmony_corrected_expression", "mean_sctransform_expression")) {
  stop("ERROR: --aggregation_method must be sum_counts, mean_harmony_corrected_expression, or mean_sctransform_expression")
}
if (!identical(opt$feature_id_column, "GeneName")) {
  stop("ERROR: --feature_id_column is fixed to GeneName for compatible downstream handoffs")
}
cell_filter_column <- if (nzchar(opt$cell_filter_column)) opt$cell_filter_column else NULL
cell_filter_values <- parse_csv_values(opt$cell_filter_values)
if (xor(is.null(cell_filter_column), is.null(cell_filter_values))) {
  stop("ERROR: Supply both --cell_filter_column and --cell_filter_values, or neither")
}

common_arguments <- list(
  seurat_rds = opt$seurat_rds,
  donor_column = opt$donor_column,
  group_column = opt$group_column,
  cell_type_column = opt$cell_type_column,
  metadata_columns = parse_csv_values(opt$metadata_columns),
  cell_filter_column = cell_filter_column,
  cell_filter_values = cell_filter_values,
  aggregation_method = opt$aggregation_method,
  assay = opt$assay,
  layer = opt$layer,
  feature_id_column = opt$feature_id_column,
  min_cells = opt$min_cells,
  on_insufficient_cells = opt$on_insufficient_cells,
  output_dir = opt$output_dir
)
if (identical(opt$cell_type_mode, "one")) {
  result <- do.call(omix_seurat_pseudobulk, c(common_arguments, list(cell_type = opt$cell_type)))
  message(
    "Saved DEG-ready donor-level matrix to ", result$matrix_path,
    ", aligned metadata to ", result$metadata_path,
    ", and the mode manifest to ", result$manifest_path
  )
} else {
  result <- do.call(omix_seurat_pseudobulk_collection, c(
    common_arguments,
    list(
      cell_type_mode = opt$cell_type_mode,
      cell_type_selection = if (nzchar(opt$cell_type_selection)) opt$cell_type_selection else NULL
    )
  ))
  message(
    "Saved cell-type pseudobulk collection catalog to ", result$catalog_path,
    " and collection manifest to ", result$collection_manifest_path
  )
}
