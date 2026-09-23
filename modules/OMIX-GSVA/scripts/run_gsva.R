#!/usr/bin/env Rscript

# Platform-neutral command-line entry point for OMIX GSVA.

suppressPackageStartupMessages(library(optparse))

script_argument <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
if (length(script_argument) != 1L) {
  stop("Could not determine the location of scripts/run_gsva.R")
}
module_root <- normalizePath(file.path(dirname(sub("^--file=", "", script_argument)), ".."))
source(file.path(module_root, "R", "GSVA_v1.R"))

split_csv <- function(value) {
  if (is.null(value) || !nzchar(trimws(value))) return(character())
  trimws(strsplit(value, ",", fixed = TRUE)[[1L]])
}

as_logical <- function(value, argument) {
  normalized <- tolower(trimws(value))
  if (normalized %in% c("true", "t", "1", "yes")) return(TRUE)
  if (normalized %in% c("false", "f", "0", "no")) return(FALSE)
  stop("--", argument, " must be true or false.")
}

required_path <- function(path, argument) {
  if (is.null(path) || !nzchar(trimws(path))) stop("--", argument, " is required.")
  if (!file.exists(path)) stop(argument, " file does not exist: ", path)
  normalizePath(path, mustWork = TRUE)
}

option_list <- list(
  make_option("--normalized_data", type = "character", default = "", help = "Normalized expression CSV, TSV, or TXT table"),
  make_option("--sample_metadata", type = "character", default = "", help = "Sample metadata CSV, TSV, or TXT table"),
  make_option("--pathways_database", type = "character", default = "", help = "Long gene-set membership CSV, TSV, or TXT table"),
  make_option("--gene_column", type = "character", default = "Gene"),
  make_option("--sample_name_column", type = "character", default = "Sample"),
  make_option("--samples_to_include", type = "character", default = "", help = "Optional comma-separated sample IDs"),
  make_option("--species", type = "character", default = "Human"),
  make_option("--database_species", type = "character", default = "Human"),
  make_option("--collections_to_include", type = "character", default = "H: hallmark gene sets", help = "Comma-separated exact collection names"),
  make_option("--custom_pathways_database", type = "character", default = "false", help = "true or false [default: %default]"),
  make_option("--custom_species", type = "character", default = "Mouse"),
  make_option("--method", type = "character", default = "gsva", help = "gsva, ssgsea, zscore, or plage [default: %default]"),
  make_option("--minimum_geneset_size", type = "integer", default = 15L),
  make_option("--maximum_geneset_size", type = "integer", default = 1200L),
  make_option("--update_genes", type = "character", default = "true", help = "true or false [default: %default]"),
  make_option("--display_warnings", type = "integer", default = -1L),
  make_option("--input_delim", type = "character", default = "\t", help = "Delimiter shared by input tables [default: tab]"),
  make_option("--image_width", type = "double", default = 12),
  make_option("--image_height", type = "double", default = 10),
  make_option("--output_dir", type = "character", default = "results")
)
opt <- parse_args(OptionParser(option_list = option_list))

normalized_path <- required_path(opt$normalized_data, "normalized_data")
metadata_path <- required_path(opt$sample_metadata, "sample_metadata")
pathways_path <- required_path(opt$pathways_database, "pathways_database")

normalized_preview <- utils::read.delim(
  normalized_path,
  sep = opt$input_delim,
  check.names = FALSE,
  stringsAsFactors = FALSE
)
metadata_preview <- utils::read.delim(
  metadata_path,
  sep = opt$input_delim,
  check.names = FALSE,
  stringsAsFactors = FALSE
)
if (!opt$gene_column %in% names(normalized_preview)) {
  stop("Gene column '", opt$gene_column, "' was not found in --normalized_data.")
}
if (!opt$sample_name_column %in% names(metadata_preview)) {
  stop("Sample ID column '", opt$sample_name_column, "' was not found in --sample_metadata.")
}

samples_to_include <- split_csv(opt$samples_to_include)
if (length(samples_to_include) == 0L) {
  samples_to_include <- intersect(
    as.character(metadata_preview[[opt$sample_name_column]]),
    names(normalized_preview)
  )
}
if (length(samples_to_include) == 0L) {
  stop("No sample IDs in --sample_metadata occur as columns in --normalized_data.")
}

collections_to_include <- split_csv(opt$collections_to_include)
if (length(collections_to_include) == 0L) {
  stop("--collections_to_include must name at least one collection.")
}
if (opt$minimum_geneset_size < 1L) stop("--minimum_geneset_size must be at least 1.")
if (opt$maximum_geneset_size < opt$minimum_geneset_size) {
  stop("--maximum_geneset_size must be greater than or equal to --minimum_geneset_size.")
}
if (!is.finite(opt$image_width) || opt$image_width <= 0) stop("--image_width must be positive.")
if (!is.finite(opt$image_height) || opt$image_height <= 0) stop("--image_height must be positive.")

dir.create(opt$output_dir, recursive = TRUE, showWarnings = FALSE)
output_dir <- normalizePath(opt$output_dir, mustWork = TRUE)
results_path <- file.path(output_dir, "gsva_v1_results.csv")
plot_path <- file.path(output_dir, "gsva_v1_heatmap.png")

results <- run_gsva(
  normalized_data_file = normalized_path,
  sample_metadata_file = metadata_path,
  pathways_database_file = pathways_path,
  gene_column = opt$gene_column,
  sample_name_column = opt$sample_name_column,
  samples_to_include = samples_to_include,
  species = opt$species,
  database_species = opt$database_species,
  collections_to_include = collections_to_include,
  custom_pathways_database = as_logical(opt$custom_pathways_database, "custom_pathways_database"),
  custom_species = opt$custom_species,
  method = opt$method,
  minimum_geneset_size = opt$minimum_geneset_size,
  maximum_geneset_size = opt$maximum_geneset_size,
  update_genes = as_logical(opt$update_genes, "update_genes"),
  display_warnings = opt$display_warnings,
  input_delim = opt$input_delim,
  export_results_file = results_path,
  export_plot_file = plot_path,
  export_plot_width = opt$image_width,
  export_plot_height = opt$image_height
)

summary_lines <- c(
  "OMIX GSVA run summary",
  paste("normalized data:", normalized_path),
  paste("sample metadata:", metadata_path),
  paste("pathways database:", pathways_path),
  paste("samples:", paste(samples_to_include, collapse = ", ")),
  paste("collections:", paste(collections_to_include, collapse = ", ")),
  paste("expression species:", opt$species),
  paste("database species:", opt$database_species),
  paste("method:", tolower(opt$method)),
  paste("minimum gene-set size:", opt$minimum_geneset_size),
  paste("maximum gene-set size:", opt$maximum_geneset_size),
  paste("gene updating:", as_logical(opt$update_genes, "update_genes")),
  paste("gene sets scored:", nrow(results)),
  "source template: NIDAP/Templates/GSVA_v1.R",
  "source template SHA-256: 0d536870e979daa3a949e2a86aa12d72f25b160d26eec1148c0db33fc24b0c5d"
)
writeLines(summary_lines, file.path(output_dir, "gsva_run_summary.txt"))
message("Wrote GSVA results to ", output_dir)
