#!/usr/bin/env Rscript

# Platform-neutral command-line entry point for OMIX Gene Boxplots.

suppressPackageStartupMessages(library(optparse))

script_argument <- commandArgs(FALSE)
script_file <- sub("^--file=", "", script_argument[grepl("^--file=", script_argument)])
if (length(script_file) != 1L) {
  stop("ERROR: Could not determine the location of scripts/run_gene_boxplots.R")
}
module_root <- normalizePath(file.path(dirname(script_file), ".."))
source(file.path(module_root, "R", "OMIX_Gene_Boxplots.R"))

read_table_file <- function(path, label) {
  if (is.null(path) || !nzchar(path) || !file.exists(path)) {
    stop("ERROR: `", label, "` was not found: ", path)
  }
  extension <- tolower(tools::file_ext(path))
  if (identical(extension, "rds")) {
    object <- readRDS(path)
    if (!is.data.frame(object)) {
      stop("ERROR: `", label, "` RDS must contain a data frame")
    }
    return(object)
  }
  if (identical(extension, "csv")) {
    return(utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE))
  }
  utils::read.delim(path, stringsAsFactors = FALSE, check.names = FALSE)
}

option_list <- list(
  make_option("--expression_table", type = "character", help = "Expression table (CSV, TSV, or RDS)"),
  make_option("--metadata_table", type = "character", help = "Sample metadata table (CSV, TSV, or RDS)"),
  make_option("--deg_table", type = "character", default = "", help = "Optional DEG table; may be the same path as expression_table"),
  make_option("--genes", type = "character", help = "Comma-separated gene identifiers"),
  make_option("--gene_column", type = "character", default = "GeneName"),
  make_option("--sample_column", type = "character", default = "Sample"),
  make_option("--category_column", type = "character", default = "Group"),
  make_option("--categories", type = "character", default = "", help = "Optional comma-separated categories"),
  make_option("--statistics_mode", type = "character", default = "precomputed_deg", help = "precomputed_deg, within_plot, or none [default: %default]"),
  make_option("--pvalue_type", type = "character", default = "nominal", help = "nominal or adjusted [default: %default]"),
  make_option("--statistical_method", type = "character", default = "anova", help = "anova, t-test, or kruskal [default: %default]"),
  make_option("--p_adjust_method", type = "character", default = "BH"),
  make_option("--minimum_samples_per_category", type = "integer", default = 2L),
  make_option("--plot_type", type = "character", default = "box", help = "box or violin [default: %default]"),
  make_option("--plot_title_prefix", type = "character", default = "Expression: "),
  make_option("--y_axis_label", type = "character", default = "Expression"),
  make_option("--colors", type = "character", default = "", help = "Optional comma-separated colors"),
  make_option("--output_dir", type = "character", default = "results"),
  make_option("--image_width", type = "double", default = 6),
  make_option("--image_height", type = "double", default = 5),
  make_option("--image_dpi", type = "integer", default = 300L)
)
parser <- OptionParser(
  usage = "Usage: %prog --expression_table PATH --metadata_table PATH --genes GENE1,GENE2 [options]",
  option_list = option_list,
  description = "Create gene-expression boxplots with model-consistent DEG annotations or independent within-plot tests."
)
opt <- parse_args(parser)

for (name in c("expression_table", "metadata_table", "genes")) {
  if (is.null(opt[[name]]) || !nzchar(opt[[name]])) {
    stop("ERROR: `--", name, "` is required")
  }
}
if (!opt$statistics_mode %in% c("precomputed_deg", "within_plot", "none")) {
  stop("ERROR: `--statistics_mode` must be precomputed_deg, within_plot, or none")
}
if (!opt$pvalue_type %in% c("nominal", "adjusted")) {
  stop("ERROR: `--pvalue_type` must be nominal or adjusted")
}

expression_table <- read_table_file(opt$expression_table, "expression_table")
metadata_table <- read_table_file(opt$metadata_table, "metadata_table")
deg_table <- if (nzchar(opt$deg_table)) read_table_file(opt$deg_table, "deg_table") else NULL
if (identical(opt$statistics_mode, "precomputed_deg") && is.null(deg_table)) {
  stop("ERROR: `--deg_table` is required for --statistics_mode precomputed_deg")
}

result <- omix_gene_boxplots(
  expression_table = expression_table,
  sample_metadata = metadata_table,
  genes = omix_parse_csv_values(opt$genes),
  gene_column = opt$gene_column,
  sample_column = opt$sample_column,
  category_column = opt$category_column,
  categories = opt$categories,
  statistics_mode = opt$statistics_mode,
  deg_results = deg_table,
  deg_gene_column = opt$gene_column,
  pvalue_type = opt$pvalue_type,
  statistical_method = opt$statistical_method,
  p_adjust_method = opt$p_adjust_method,
  minimum_samples_per_category = opt$minimum_samples_per_category,
  plot_type = opt$plot_type,
  plot_title_prefix = opt$plot_title_prefix,
  y_axis_label = opt$y_axis_label,
  colors = omix_parse_csv_values(opt$colors),
  output_dir = opt$output_dir,
  image_width = opt$image_width,
  image_height = opt$image_height,
  image_dpi = opt$image_dpi
)
message(
  "Saved ", length(result$plots), " gene boxplot(s) and ",
  nrow(result$statistics), " statistical comparison(s) to: ", opt$output_dir
)
