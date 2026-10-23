#!/usr/bin/env Rscript

# Platform-neutral CLI for an ordered, donor-level M-F Limma cell-type
# collection. This deliberately consumes explicit portable paths; Code Ocean
# or another deployment adapter owns any mounted-input discovery.

suppressPackageStartupMessages(library(optparse))

script_argument <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
if (length(script_argument) != 1L) {
  stop("Could not determine the location of scripts/run_limma_cell_type_collection.R")
}
module_root <- normalizePath(file.path(dirname(sub("^--file=", "", script_argument)), ".."))
source(file.path(module_root, "R", "OMIX_Limma_Analysis.R"))

split_csv <- function(value) {
  if (is.null(value) || !nzchar(trimws(value))) return(character())
  trimws(strsplit(value, ",", fixed = TRUE)[[1L]])
}

option_list <- list(
  make_option("--pseudobulk_collection_manifest", type = "character", default = "", help = "Pseudobulk_Collection_Manifest.dcf from selected/all OMIX Seurat Pseudobulk"),
  make_option("--contrast", type = "character", default = "M-F", help = "Fixed donor-level comparison for the current collection contract [default: %default]"),
  make_option("--sample_names_column", type = "character", default = "Sample"),
  make_option("--gene_names_column", type = "character", default = "GeneName"),
  make_option("--covariate_columns", type = "character", default = "", help = "Optional comma-separated covariate columns"),
  make_option("--batch_effect_columns", type = "character", default = "", help = "Optional comma-separated technical batch columns"),
  make_option("--donor_variable_column", type = "character", default = "", help = "Optional repeated-measure donor blocking column"),
  make_option("--output_dir", type = "character", default = "results")
)
opt <- parse_args(OptionParser(option_list = option_list))

result <- omix_limma_cell_type_collection(
  pseudobulk_collection_manifest = opt$pseudobulk_collection_manifest,
  output_dir = opt$output_dir,
  contrast = opt$contrast,
  sample_names_column = opt$sample_names_column,
  gene_names_column = opt$gene_names_column,
  covariate_columns = split_csv(opt$covariate_columns),
  batch_effect_columns = split_csv(opt$batch_effect_columns),
  donor_variable_column = split_csv(opt$donor_variable_column)
)

message("Wrote L2P Multi input to ", normalizePath(result$l2p_multi_input, mustWork = TRUE))
message("Ordered comparisons: ", paste(result$comparisons, collapse = ","))
