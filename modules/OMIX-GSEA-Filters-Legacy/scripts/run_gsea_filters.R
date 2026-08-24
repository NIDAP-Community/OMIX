#!/usr/bin/env Rscript

# Platform-neutral command-line entry point for OMIX GSEA result filtering.

suppressPackageStartupMessages({
  library(optparse)
})

script_argument <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
if (length(script_argument) != 1L) {
  stop("ERROR: Could not determine the location of scripts/run_gsea_filters.R")
}
module_root <- normalizePath(file.path(dirname(sub("^--file=", "", script_argument)), ".."))
source(file.path(module_root, "R", "filter_gsea_function.R"))

option_list <- list(
  make_option("--input", type = "character", help = "GSEA results table (CSV, TSV, or RDS)"),
  make_option("--output_dir", type = "character", default = "results", help = "Directory for outputs [default: %default]"),
  make_option("--p_value_filter", type = "character", default = "adjusted p-value"),
  make_option("--p_value_threshold", type = "double", default = 0.05),
  make_option("--enrichment_score_filter", type = "character", default = "NES (Normalized Enrichment Score)"),
  make_option("--enrichment_score_threshold", type = "double", default = 0),
  make_option("--enrichment_score_sign", type = "character", default = "+/-"),
  make_option("--size_filter", type = "character", default = "Pathway size"),
  make_option("--size_cutoff", type = "integer", default = 0L),
  make_option("--top_rank_filter", type = "character", default = "all"),
  make_option("--collections_to_include", type = "character", default = NULL),
  make_option("--pathways_to_include", type = "character", default = NULL),
  make_option("--gene_filter_universe", type = "character", default = "Leading Edge (LE)"),
  make_option("--genes_to_include", type = "character", default = NULL),
  make_option("--contrast_filter", type = "character", default = "none"),
  make_option("--contrasts", type = "character", default = NULL)
)
opt <- parse_args(OptionParser(option_list = option_list))

if (is.null(opt$input) || !nzchar(opt$input)) {
  stop("ERROR: --input is required")
}
if (!file.exists(opt$input)) {
  stop("ERROR: Input file was not found: ", opt$input)
}

parse_comma_list <- function(value) {
  if (is.null(value) || !nzchar(trimws(value)) || identical(value, "NULL")) {
    return(NULL)
  }
  trimws(strsplit(value, ",", fixed = TRUE)[[1L]])
}

read_gsea_results <- function(path) {
  extension <- tolower(tools::file_ext(path))
  if (extension == "rds") {
    value <- readRDS(path)
    if (!is.data.frame(value)) {
      stop("ERROR: RDS input must contain a data frame: ", path)
    }
    return(value)
  }
  if (extension == "csv") {
    return(read.csv(path, stringsAsFactors = FALSE, check.names = FALSE))
  }
  if (extension %in% c("tsv", "txt")) {
    return(read.delim(path, stringsAsFactors = FALSE, check.names = FALSE))
  }
  stop("ERROR: Unsupported input format: ", path)
}

gsea_table <- read_gsea_results(opt$input)
required_columns <- c("contrast", "collection", "pathway")
selected_p_value <- if (opt$p_value_filter %in% c("raw p-value", "p-value", "nominal p-value")) "pval" else "padj"
selected_score <- if (opt$enrichment_score_filter == "ES (Enrichment Score)") "ES" else "NES"
selected_size <- if (opt$size_filter == "Leading Edge (LE) size") "size_leadingEdge" else "size"
required_columns <- unique(c(required_columns, selected_p_value, selected_score, selected_size))
missing_columns <- setdiff(required_columns, names(gsea_table))
if (length(missing_columns) > 0L) {
  stop("ERROR: Input is missing required columns: ", paste(missing_columns, collapse = ", "))
}

dir.create(opt$output_dir, recursive = TRUE, showWarnings = FALSE)
filtered_results <- GSEA_Filters(
  gsea_table = gsea_table,
  columns_to_sort_output_by = c("padj", "pval"),
  sort_output_in_decreasing_order = FALSE,
  p_value_filter = opt$p_value_filter,
  p_value_threshold = opt$p_value_threshold,
  enrichment_score_filter = opt$enrichment_score_filter,
  enrichment_score_threshold = opt$enrichment_score_threshold,
  enrichment_score_sign = opt$enrichment_score_sign,
  size_filter = opt$size_filter,
  size_cutoff = opt$size_cutoff,
  top_rank_filter = opt$top_rank_filter,
  collections_to_include = parse_comma_list(opt$collections_to_include),
  pathways_to_include = parse_comma_list(opt$pathways_to_include),
  gene_filter_universe = opt$gene_filter_universe,
  genes_to_include = parse_comma_list(opt$genes_to_include),
  contrast_filter = opt$contrast_filter,
  contrasts = parse_comma_list(opt$contrasts)
)

csv_output <- file.path(opt$output_dir, "filtered_gsea_results.csv")
rds_output <- file.path(opt$output_dir, "filtered_gsea_results.rds")
write.csv(filtered_results, csv_output, row.names = FALSE)
saveRDS(filtered_results, rds_output)
message("GSEA filtering complete. Results saved to: ", csv_output)
