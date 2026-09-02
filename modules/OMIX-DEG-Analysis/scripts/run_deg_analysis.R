#!/usr/bin/env Rscript

# Platform-neutral command-line entry point for OMIX DEG Analysis.

suppressPackageStartupMessages(library(optparse))

script_argument <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
if (length(script_argument) != 1L) {
  stop("Could not determine the location of scripts/run_deg_analysis.R")
}
module_root <- normalizePath(file.path(dirname(sub("^--file=", "", script_argument)), ".."))
source(file.path(module_root, "R", "OMIX_DEG_Analysis.R"))

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

read_tabular_input <- function(path) {
  extension <- tolower(tools::file_ext(path))
  if (extension == "rds") {
    object <- readRDS(path)
    if (is.matrix(object)) return(as.data.frame(object, check.names = FALSE))
    if (is.data.frame(object)) return(object)
    stop("RDS table input must contain a data frame or matrix: ", path)
  }
  if (extension == "csv") return(utils::read.csv(path, check.names = FALSE, stringsAsFactors = FALSE))
  if (extension %in% c("tsv", "txt")) return(utils::read.delim(path, check.names = FALSE, stringsAsFactors = FALSE))
  stop("Unsupported table input extension for ", path, ". Use CSV, TSV, TXT, or RDS.")
}

required_path <- function(path, label) {
  if (!nzchar(path)) stop("--", label, " is required for table input.")
  if (!file.exists(path)) stop(label, " file does not exist: ", path)
  normalizePath(path, mustWork = TRUE)
}

option_list <- list(
  make_option("--input_type", type = "character", default = "table", help = "table or moo [default: %default]"),
  make_option("--counts", type = "character", default = "", help = "Raw counts table for table input"),
  make_option("--metadata", type = "character", default = "", help = "Sample metadata table for table input"),
  make_option("--moo", type = "character", default = "", help = "MOSuite multiOmicDataSet RDS for MOO input"),
  make_option("--gene_names_column", type = "character", default = "GeneName"),
  make_option("--sample_names_column", type = "character", default = "Sample"),
  make_option("--samples_to_include", type = "character", default = ""),
  make_option("--contrast_variable_columns", type = "character", default = "Group"),
  make_option("--contrasts", type = "character", default = "B-A"),
  make_option("--covariate_columns", type = "character", default = ""),
  make_option("--batch_effect_columns", type = "character", default = "Batch"),
  make_option("--donor_variable_column", type = "character", default = ""),
  make_option("--filter_low_expression", type = "character", default = "true"),
  make_option("--return_batch_corrected_values", type = "character", default = "true"),
  make_option("--remove_donor_effect_for_downstream", type = "character", default = "true"),
  make_option("--normalization_method", type = "character", default = "TMM"),
  make_option("--write_normalization_diagnostics", type = "character", default = "true"),
  make_option("--summarization_method", type = "character", default = "sum"),
  make_option("--output_dir", type = "character", default = "results")
)
opt <- parse_args(OptionParser(option_list = option_list))

input_type <- tolower(trimws(opt$input_type))
if (!input_type %in% c("table", "moo")) stop("--input_type must be table or moo.")
if (input_type == "moo") {
  if (!nzchar(opt$moo)) stop("--moo is required for MOO input.")
  if (!file.exists(opt$moo)) stop("MOO file does not exist: ", opt$moo)
  if (!requireNamespace("OmixMOSuite", quietly = TRUE)) {
    stop("MOO input requires the optional OmixMOSuite bridge and its MOSuite dependency.")
  }
  moo_path <- normalizePath(opt$moo, mustWork = TRUE)
  standard_input <- OmixMOSuite::omix_read_mosuite_rds(moo_path, count_type = "raw")
  counts <- standard_input$counts
  metadata <- standard_input$metadata
  opt$gene_names_column <- standard_input$feature_id_column
  opt$sample_names_column <- standard_input$sample_id_column
  input_summary <- c(
    paste("input type: MOO"),
    paste("MOO file:", moo_path),
    paste("MOO count layer:", standard_input$provenance$count_type)
  )
} else {
  counts_path <- required_path(opt$counts, "counts")
  metadata_path <- required_path(opt$metadata, "metadata")
  counts <- read_tabular_input(counts_path)
  metadata <- read_tabular_input(metadata_path)
  input_summary <- c(
    paste("input type: table"),
    paste("counts input:", counts_path),
    paste("metadata input:", metadata_path)
  )
}

selected_samples <- split_csv(opt$samples_to_include)
if (length(selected_samples) == 0L) {
  if (!opt$sample_names_column %in% names(metadata)) {
    stop("Sample ID column '", opt$sample_names_column, "' was not found in metadata.")
  }
  selected_samples <- intersect(as.character(metadata[[opt$sample_names_column]]), names(counts))
}
if (length(selected_samples) == 0L) stop("No selected metadata sample IDs occur in the count table.")
dir.create(opt$output_dir, recursive = TRUE, showWarnings = FALSE)

results <- omix_deg_analysis(
  Dataset = counts,
  Metadata_Table = metadata,
  sample_names_column = opt$sample_names_column,
  samples_to_include = selected_samples,
  gene_names_column = opt$gene_names_column,
  contrast_variable_columns = split_csv(opt$contrast_variable_columns),
  contrasts = split_csv(opt$contrasts),
  covariate_columns = split_csv(opt$covariate_columns),
  donor_variable_column = split_csv(opt$donor_variable_column),
  batch_effect_columns = split_csv(opt$batch_effect_columns),
  filter_low_expression = as_logical(opt$filter_low_expression, "filter_low_expression"),
  normalization_method = opt$normalization_method,
  normalization_diagnostics = as_logical(opt$write_normalization_diagnostics, "write_normalization_diagnostics"),
  diagnostics_output_dir = opt$output_dir,
  return_batch_corrected_values = as_logical(opt$return_batch_corrected_values, "return_batch_corrected_values"),
  remove_donor_effect_for_downstream = as_logical(opt$remove_donor_effect_for_downstream, "remove_donor_effect_for_downstream"),
  summarization_method = opt$summarization_method
)

utils::write.csv(results, file.path(opt$output_dir, "DEG_Analysis.csv"), row.names = FALSE, na = "")
output_samples <- selected_samples[selected_samples %in% names(results)]
if (length(output_samples) == 0L) {
  stop("The DEG result does not contain any modeled sample-expression columns for metadata export.")
}
output_metadata <- metadata[
  match(output_samples, as.character(metadata[[opt$sample_names_column]])),
  ,
  drop = FALSE
]
utils::write.csv(
  output_metadata,
  file.path(opt$output_dir, "Sample_Metadata.csv"),
  row.names = FALSE,
  na = ""
)
run_summary <- attr(results, "omix_deg_run")
writeLines(c(
  "OMIX DEG Analysis run summary",
  input_summary,
  paste("model type:", run_summary$model_type),
  paste("normalization profile:", opt$normalization_method),
  paste("library-size normalization:", run_summary$library_size_normalization),
  paste("voom-scale normalization:", run_summary$voom_scale_normalization),
  paste("normalization diagnostics:", if (length(run_summary$normalization_diagnostic_files) == 0L) "not written" else paste(basename(run_summary$normalization_diagnostic_files), collapse = ", ")),
  paste("genes before filtering:", run_summary$genes_before_filtering),
  paste("genes modelled:", run_summary$genes_modelled),
  paste("expression output:", run_summary$expression_output),
  paste("adjusted columns:", paste(run_summary$adjusted_columns, collapse = ", "))
), file.path(opt$output_dir, "DEG_Analysis_run_summary.txt"))
message("Wrote results to ", normalizePath(opt$output_dir, mustWork = TRUE))
