#!/usr/bin/env Rscript

# Platform-neutral command-line entry point for OMIX GSEA preranked analysis.

suppressPackageStartupMessages({
  library(optparse)
})

script_argument <- commandArgs(FALSE)
script_file <- sub("^--file=", "", script_argument[grepl("^--file=", script_argument)])
if (length(script_file) != 1L) {
  stop("ERROR: Could not determine the location of scripts/run_gsea.R")
}
module_root <- normalizePath(file.path(dirname(script_file), ".."))
source(file.path(module_root, "R", "GSEA_Preranked.R"))
if (!requireNamespace("OmixPathwayInputs", quietly = TRUE)) {
  stop(
    "ERROR: OmixPathwayInputs is required for pathway DEG-table compatibility. ",
    "Install packages/OmixPathwayInputs from the same OMIX checkout.",
    call. = FALSE
  )
}

option_list <- list(
  make_option("--deg_table", type = "character", help = "Path to the DEG table (CSV, TSV, or RDS)"),
  make_option("--pathways_database", type = "character", help = "Path to the pathways database (CSV, TSV, or RDS)"),
  make_option("--output_dir", type = "character", default = "results", help = "Directory for result files [default: %default]"),
  make_option("--gene_names_column", type = "character", default = NULL, help = "Gene-symbol column; auto-detects GeneName, then Gene Symbols when omitted"),
  make_option("--species", type = "character", default = "Human", help = "Species in the DEG table [default: %default]"),
  make_option("--gene_scores_suffix", type = "character", default = "_tstat", help = "Suffix for ranking-score columns [default: %default]. Recognized FindMarkers input uses _logFC when this option is not explicitly supplied."),
  make_option("--contrasts", type = "character", default = NULL, help = "Optional ordered contrast names. Recognized wide FindMarkers tables use source order when omitted; native unprefixed FindMarkers input requires exactly one label."),
  make_option("--pathways_species", type = "character", default = "Human", help = "Species in the pathways database [default: %default]"),
  make_option("--collections", type = "character", default = "H: hallmark gene sets,C2:CP:REACTOME: Reactome gene sets", help = "Comma-separated collections [default: %default]"),
  make_option("--min_geneset_size", type = "integer", default = 15L, help = "Minimum geneset size [default: %default]"),
  make_option("--max_geneset_size", type = "integer", default = 500L, help = "Maximum geneset size [default: %default]"),
  make_option("--n_permutations", type = "integer", default = 5000L, help = "Number of permutations [default: %default]"),
  make_option("--random_seed", type = "integer", default = 246642L, help = "Random seed [default: %default]"),
  make_option("--fdr_mode", type = "character", default = "within each collection", help = "FDR correction mode [default: %default]"),
  make_option("--collapse_redundancy", type = "character", default = "false", help = "Collapse pathway redundancy [default: %default]"),
  make_option("--sort_by", type = "character", default = "pval", help = "Result sort column [default: %default]"),
  make_option("--image_width", type = "integer", default = 2500L, help = "Image width in pixels [default: %default]"),
  make_option("--image_height", type = "integer", default = 2500L, help = "Image height in pixels [default: %default]"),
  make_option("--image_resolution", type = "integer", default = 300L, help = "Image resolution in dpi [default: %default]")
)

parser <- OptionParser(
  usage = "Usage: %prog --deg_table PATH --pathways_database PATH [options]",
  option_list = option_list,
  description = "Run OMIX GSEA preranked analysis"
)
opt <- parse_args(parser)

for (required_option in c("deg_table", "pathways_database")) {
  if (is.null(opt[[required_option]]) || !nzchar(opt[[required_option]])) {
    stop("ERROR: `--", required_option, "` is required")
  }
}

if (!file.exists(opt$deg_table)) {
  stop("ERROR: DEG table was not found: ", opt$deg_table)
}
if (!file.exists(opt$pathways_database)) {
  stop("ERROR: Pathways database was not found: ", opt$pathways_database)
}

read_deg_table <- function(path) {
  extension <- tolower(tools::file_ext(path))
  if (extension == "rds") {
    object <- readRDS(path)
    if (is.list(object) && !is.data.frame(object)) {
      data_frames <- Filter(is.data.frame, object)
      if (length(data_frames) == 0L) {
        stop("ERROR: DEG RDS does not contain a data frame: ", path)
      }
      object <- data_frames[[1L]]
    }
    if (!is.data.frame(object)) {
      stop("ERROR: DEG RDS does not contain a data frame: ", path)
    }
    return(object)
  }
  if (extension == "csv") {
    return(read.csv(path, stringsAsFactors = FALSE, check.names = FALSE))
  }
  if (extension %in% c("tsv", "txt")) {
    return(read.delim(path, stringsAsFactors = FALSE, check.names = FALSE))
  }
  stop("ERROR: Unsupported DEG table format: ", path)
}

resolve_gene_names_column <- function(data, requested) {
  if (!is.null(requested) && nzchar(requested) && tolower(requested) != "auto") {
    if (!requested %in% names(data)) {
      stop(
        "ERROR: Requested gene-name column was not found: ", requested,
        ". Available columns: ", paste(names(data), collapse = ", ")
      )
    }
    return(requested)
  }

  available_columns <- names(data)

  candidates <- c("GeneName", "Gene Symbols", "Gene", "gene_name", "GeneSymbol", "gene_symbol")
  detected <- candidates[candidates %in% available_columns]
  if (length(detected) == 0L) {
    stop(
      "ERROR: Could not auto-detect the gene-name column. ",
      "Specify --gene_names_column. Available columns: ",
      paste(available_columns, collapse = ", ")
    )
  }

  message("Auto-detected gene-name column: ", detected[[1L]])
  detected[[1L]]
}

collections <- trimws(strsplit(opt$collections, ",", fixed = TRUE)[[1]])
contrasts <- if (is.null(opt$contrasts) || !nzchar(trimws(opt$contrasts))) {
  character()
} else {
  trimws(strsplit(opt$contrasts, ",", fixed = TRUE)[[1]])
}
deg_table <- read_deg_table(opt$deg_table)
findmarkers_profile <- OmixPathwayInputs::normalize_findmarkers_deg_input(
  deg_table,
  gene_column = opt$gene_names_column,
  comparison_labels = contrasts
)
raw_cli_arguments <- commandArgs(trailingOnly = TRUE)
score_suffix_was_supplied <- any(
  raw_cli_arguments == "--gene_scores_suffix" |
    startsWith(raw_cli_arguments, "--gene_scores_suffix=")
)
if (!is.null(findmarkers_profile)) {
  deg_table <- findmarkers_profile$data
  opt$gene_names_column <- findmarkers_profile$gene_column
  contrasts <- findmarkers_profile$comparisons
  if (!score_suffix_was_supplied) {
    opt$gene_scores_suffix <- "_logFC"
  }
  message(
    "Using ", findmarkers_profile$format, " input profile for contrast(s): ",
    paste(contrasts, collapse = ", "),
    "; ranking suffix: ", opt$gene_scores_suffix
  )
} else {
  opt$gene_names_column <- resolve_gene_names_column(deg_table, opt$gene_names_column)
}
collapse_redundancy <- tolower(opt$collapse_redundancy) == "true"
dir.create(opt$output_dir, showWarnings = FALSE, recursive = TRUE)

results <- GSEA_Preranked(
  DEG_Table = deg_table,
  Pathways_Database = opt$pathways_database,
  Gene_Names_Column = opt$gene_names_column,
  species = opt$species,
  Gene_Scores_Column_s_Suffix = opt$gene_scores_suffix,
  Contrasts_Filter = if (length(contrasts) == 0L) "none" else "keep",
  Contrasts = contrasts,
  Pathways_Database_Species = opt$pathways_species,
  Collections_to_Include = collections,
  Minimum_Gene_Set_Size = opt$min_geneset_size,
  Maximum_Gene_Set_Size = opt$max_geneset_size,
  FDR_Correction_Mode = opt$fdr_mode,
  Number_of_Permutations = opt$n_permutations,
  Random_Seed = opt$random_seed,
  Collapse_Pathway_Redundancy = collapse_redundancy,
  Sort_Output_By = opt$sort_by,
  Image_Width = opt$image_width,
  Image_Height = opt$image_height,
  Image_Resolution = opt$image_resolution,
  Output_Directory = opt$output_dir
)

output_file <- file.path(opt$output_dir, "gsea_results.csv")
write.csv(results, output_file, row.names = FALSE)
message("GSEA analysis complete. Results saved to: ", output_file)
