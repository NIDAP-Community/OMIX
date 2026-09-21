#!/usr/bin/env Rscript

# Platform-neutral command-line entry point for OMIX Limma Analysis.

suppressPackageStartupMessages(library(optparse))

script_argument <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
if (length(script_argument) != 1L) stop("Could not determine the location of scripts/run_limma_analysis.R")
module_root <- normalizePath(file.path(dirname(sub("^--file=", "", script_argument)), ".."))
source(file.path(module_root, "R", "OMIX_Limma_Analysis.R"))

split_csv <- function(value) {
  if (is.null(value) || !nzchar(trimws(value))) return(character())
  trimws(strsplit(value, ",", fixed = TRUE)[[1L]])
}

read_tabular_input <- function(path) {
  extension <- tolower(tools::file_ext(path))
  if (extension == "rds") {
    object <- readRDS(path)
    if (is.matrix(object)) return(as.data.frame(object, check.names = FALSE))
    if (is.data.frame(object)) return(object)
    stop("RDS input must contain a data frame or matrix: ", path)
  }
  if (extension == "csv") return(utils::read.csv(path, check.names = FALSE, stringsAsFactors = FALSE))
  if (extension %in% c("tsv", "txt")) return(utils::read.delim(path, check.names = FALSE, stringsAsFactors = FALSE))
  stop("Unsupported table input extension for ", path, ". Use CSV, TSV, TXT, or RDS.")
}

required_path <- function(path, label) {
  if (!nzchar(path)) stop("--", label, " is required.")
  if (!file.exists(path)) stop(label, " file does not exist: ", path)
  normalizePath(path, mustWork = TRUE)
}

read_manifest <- function(path) {
  manifest <- base::read.dcf(path)
  if (nrow(manifest) != 1L) {
    stop("Pseudobulk manifest must contain exactly one record: ", path)
  }
  as.list(manifest[1L, , drop = TRUE])
}

manifest_value <- function(manifest, field) {
  if (is.null(manifest) || !field %in% names(manifest)) return("")
  trimws(as.character(manifest[[field]]))
}

option_list <- list(
  make_option("--matrix", type = "character", default = "", help = "Continuous feature-by-sample CSV, TSV, TXT, or RDS table"),
  make_option("--metadata", type = "character", default = "", help = "Aligned sample-metadata CSV, TSV, TXT, or RDS table"),
  make_option("--gene_names_column", type = "character", default = "GeneName"),
  make_option("--sample_names_column", type = "character", default = "Sample"),
  make_option("--samples_to_include", type = "character", default = "", help = "Optional comma-separated sample IDs; default selects all metadata samples found in --matrix"),
  make_option("--contrast_variable_columns", type = "character", default = "Group", help = "One or two comma-separated metadata columns"),
  make_option("--contrasts", type = "character", default = "B-A", help = "Comma-separated limma contrasts"),
  make_option("--covariate_columns", type = "character", default = ""),
  make_option("--donor_variable_column", type = "character", default = ""),
  make_option("--summarization_method", type = "character", default = "mean", help = "mean, max, or sum [default: %default]"),
  make_option("--input_kind", type = "character", default = "log2_expression", help = "log2_expression, enrichment_score, or continuous_score [default: %default]"),
  make_option("--variance_model", type = "character", default = "auto", help = "auto, ebayes, or ebayes_trend [default: %default]"),
  make_option("--pseudobulk_manifest", type = "character", default = "", help = "Optional Pseudobulk_Manifest.dcf that validates a continuous-expression handoff"),
  make_option("--return_matrix", type = "character", default = "true", help = "Append modeled sample values to results [default: %default]"),
  make_option("--output_dir", type = "character", default = "results")
)
opt <- parse_args(OptionParser(option_list = option_list))

as_logical <- function(value, argument) {
  normalized <- tolower(trimws(value))
  if (normalized %in% c("true", "t", "1", "yes")) return(TRUE)
  if (normalized %in% c("false", "f", "0", "no")) return(FALSE)
  stop("--", argument, " must be true or false.")
}

matrix_path <- required_path(opt$matrix, "matrix")
metadata_path <- required_path(opt$metadata, "metadata")
manifest_path <- if (nzchar(trimws(opt$pseudobulk_manifest))) {
  required_path(opt$pseudobulk_manifest, "pseudobulk_manifest")
} else {
  ""
}
manifest <- if (nzchar(manifest_path)) read_manifest(manifest_path) else NULL
input_kind <- tolower(trimws(opt$input_kind))
requested_variance_model <- tolower(trimws(opt$variance_model))
if (!requested_variance_model %in% c("auto", "ebayes", "ebayes_trend")) {
  stop("--variance_model must be auto, ebayes, or ebayes_trend.")
}
if (!is.null(manifest)) {
  matrix_type <- manifest_value(manifest, "matrix_type")
  if (identical(matrix_type, "raw_integer_counts")) {
    stop(
      "Pseudobulk_Manifest.dcf declares raw_integer_counts. Run OMIX-DEG-Analysis ",
      "in raw-count mode so edgeR TMM and limma-voom are used instead."
    )
  }
  if (!matrix_type %in% c("harmony_corrected_mean_expression", "sctransform_mean_log2_expression")) {
    stop("Unsupported Pseudobulk matrix_type for direct limma: ", matrix_type)
  }
  downstream_module <- manifest_value(manifest, "expected_downstream_module")
  if (nzchar(downstream_module) && !identical(downstream_module, "OMIX-Limma-Analysis")) {
    stop("Pseudobulk manifest expects downstream module '", downstream_module, "', not OMIX-Limma-Analysis.")
  }
  downstream_mode <- manifest_value(manifest, "expected_downstream_mode")
  if (nzchar(downstream_mode) && !identical(downstream_mode, "continuous_expression")) {
    stop("Pseudobulk manifest does not declare a continuous-expression handoff.")
  }
  declared_input_kind <- manifest_value(manifest, "downstream_input_kind")
  if (nzchar(declared_input_kind) && !identical(declared_input_kind, input_kind)) {
    stop(
      "--input_kind ('", input_kind, "') does not match the pseudobulk manifest ('",
      declared_input_kind, "')."
    )
  }
}
recommended_variance_model <- manifest_value(manifest, "recommended_variance_model")
variance_model <- if (identical(requested_variance_model, "auto")) {
  if (recommended_variance_model %in% c("ebayes", "ebayes_trend")) recommended_variance_model else "ebayes"
} else {
  requested_variance_model
}
matrix_input <- read_tabular_input(matrix_path)
metadata_input <- read_tabular_input(metadata_path)
if (!opt$sample_names_column %in% names(metadata_input)) {
  stop("Sample ID column '", opt$sample_names_column, "' was not found in --metadata.")
}
selected_samples <- split_csv(opt$samples_to_include)
if (length(selected_samples) == 0L) {
  selected_samples <- intersect(as.character(metadata_input[[opt$sample_names_column]]), names(matrix_input))
}
if (length(selected_samples) == 0L) stop("No metadata sample IDs occur as columns in --matrix.")
dir.create(opt$output_dir, recursive = TRUE, showWarnings = FALSE)

results <- omix_limma_analysis(
  Dataset = matrix_input,
  Metadata_Table = metadata_input,
  sample_names_column = opt$sample_names_column,
  samples_to_include = selected_samples,
  gene_names_column = opt$gene_names_column,
  contrast_variable_columns = split_csv(opt$contrast_variable_columns),
  contrasts = split_csv(opt$contrasts),
  covariate_columns = split_csv(opt$covariate_columns),
  donor_variable_column = split_csv(opt$donor_variable_column),
  summarization_method = opt$summarization_method,
  return_matrix = as_logical(opt$return_matrix, "return_matrix"),
  input_kind = input_kind,
  variance_model = variance_model
)

utils::write.csv(results, file.path(opt$output_dir, "Limma_Analysis.csv"), row.names = FALSE, na = "")
output_metadata <- metadata_input[match(selected_samples, as.character(metadata_input[[opt$sample_names_column]])), , drop = FALSE]
utils::write.csv(output_metadata, file.path(opt$output_dir, "Sample_Metadata.csv"), row.names = FALSE, na = "")
run_summary <- attr(results, "omix_limma_run")
writeLines(c(
  "OMIX Limma Analysis run summary",
  paste("matrix input:", matrix_path),
  paste("metadata input:", metadata_path),
  paste("pseudobulk manifest:", if (nzchar(manifest_path)) manifest_path else "<none>"),
  paste("pseudobulk matrix type:", if (!is.null(manifest)) manifest_value(manifest, "matrix_type") else "<none>"),
  paste("input kind:", run_summary$input_kind),
  paste("requested variance model:", requested_variance_model),
  paste("manifest recommended variance model:", if (nzchar(recommended_variance_model)) recommended_variance_model else "<none>"),
  paste("variance model:", run_summary$variance_model),
  paste("model type:", run_summary$model_type),
  paste("design formula:", run_summary$design_formula),
  paste("genes modelled:", run_summary$genes_modelled),
  paste("samples modelled:", run_summary$samples_modelled),
  paste("consensus donor correlation:", run_summary$consensus_correlation)
), file.path(opt$output_dir, "run_summary.txt"))
message("Wrote results to ", normalizePath(opt$output_dir, mustWork = TRUE))
