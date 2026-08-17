#!/usr/bin/env Rscript

# OMIX GSEA - CLI-first Gene Set Enrichment Analysis
# Accepts parameters via command-line arguments from App Panel

suppressPackageStartupMessages({
  library(optparse)
})

# Source the GSEA function
source("functions/GSEA_Preranked.R")

# Define CLI options
option_list <- list(
  make_option("--deg_table", type = "character", default = NULL, help = "Path to DEG table (TSV/CSV/RDS) - uploaded file or data asset"),
  make_option("--pathways_database", type = "character", default = "/data/msigdb/var_GSEA_MSigDB_v2023_2_CCBR_.rds", help = "Path to pathways database (TSV/CSV/RDS)"),
  make_option("--gene_names_column", type = "character", default = "Gene", help = "Gene name column in DEG table"),
  make_option("--species", type = "character", default = "Human", help = "Species in DEG table"),
  make_option("--gene_scores_suffix", type = "character", default = "_tstat", help = "Suffix for gene score columns"),
  make_option("--pathways_species", type = "character", default = "Human", help = "Species in pathways database"),
  make_option("--collections", type = "character", default = "H: hallmark gene sets,CP:REACTOME: Reactome gene sets", help = "Comma-separated collections"),
  make_option("--min_geneset_size", type = "integer", default = 15L, help = "Minimum geneset size"),
  make_option("--max_geneset_size", type = "integer", default = 500L, help = "Maximum geneset size"),
  make_option("--n_permutations", type = "integer", default = 5000L, help = "Number of permutations"),
  make_option("--random_seed", type = "integer", default = 246642L, help = "Random seed"),
  make_option("--fdr_mode", type = "character", default = "within each collection", help = "FDR correction mode"),
  make_option("--collapse_redundancy", type = "character", default = "false", help = "Collapse pathway redundancy"),
  make_option("--sort_by", type = "character", default = "pval", help = "Sort output by"),
  make_option("--image_width", type = "integer", default = 2500L, help = "Image width in pixels"),
  make_option("--image_height", type = "integer", default = 2500L, help = "Image height in pixels"),
  make_option("--image_resolution", type = "integer", default = 300L, help = "Image resolution (dpi)")
)

parser <- OptionParser(
  usage = "Usage: %prog --deg_table PATH --pathways_database PATH [options]",
  option_list = option_list,
  description = "Run GSEA pre-ranked analysis on gene expression data"
)

# Filter out empty string arguments before optparse sees them
# Code Ocean passes --param "" for blank file uploads, which optparse rejects
args <- commandArgs(trailingOnly = TRUE)
filtered_args <- character()
i <- 1
while (i <= length(args)) {
  # Skip standalone empty strings
  if (args[i] == "") {
    i <- i + 1
  } else if (i < length(args) && startsWith(args[i], "--") && args[i+1] == "") {
    # Skip flag + empty value pairs
    i <- i + 2
  } else {
    filtered_args <- c(filtered_args, args[i])
    i <- i + 1
  }
}

opt <- parse_args(parser, args = filtered_args)

# Uploaded file takes priority. Otherwise, locate DEG_Analysis.csv passed
# from the upstream workflow capsule anywhere under this capsule's /data.
find_upstream_deg <- function() {
  files <- list.files(
    "/data",
    recursive = TRUE,
    full.names = TRUE,
    all.files = FALSE
  )

  matches <- files[tolower(basename(files)) == "deg_analysis.csv"]

  if (length(matches) > 0) {
    return(matches[1])
  }

  NULL
}

if (is.null(opt$deg_table) || opt$deg_table == "") {
  upstream_deg <- find_upstream_deg()
  demo_deg <- "/data/deg_table/var_DEGAnalysis.rds"

  if (!is.null(upstream_deg)) {
    opt$deg_table <- upstream_deg
    message("Using upstream DEG table: ", opt$deg_table)
  } else if (file.exists(demo_deg)) {
    opt$deg_table <- demo_deg
    message("No DEG file uploaded. Using example data asset.")
  } else {
    stop(
      "ERROR: No DEG_Analysis.csv was received from the upstream capsule.\n",
      "Visible files under /data:\n",
      paste(
        list.files("/data", recursive = TRUE, full.names = TRUE),
        collapse = "\n"
      )
    )
  }
}

# Parse comma-separated collections
collections <- trimws(strsplit(opt$collections, ",")[[1]])

# Convert string booleans
collapse_redundancy <- tolower(opt$collapse_redundancy) == "true"

# Results directory
results_dir <- "/results"
dir.create(results_dir, showWarnings = FALSE, recursive = TRUE)

message("========================================")
message("OMIX GSEA - Pre-ranked Analysis")
message("========================================")
message("DEG Table: ", opt$deg_table)
message("Pathways Database: ", opt$pathways_database)
message("Species: ", opt$species)
message("Collections: ", paste(collections, collapse = ", "))
message("========================================\n")

# Run GSEA
results <- GSEA_Preranked(
  DEG_Table = opt$deg_table,
  Pathways_Database = opt$pathways_database,
  Gene_Names_Column = opt$gene_names_column,
  species = opt$species,
  Gene_Scores_Column_s_Suffix = opt$gene_scores_suffix,
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
  Image_Resolution = opt$image_resolution
)

# Save results
output_file <- file.path(results_dir, "gsea_results.csv")
write.csv(results, output_file, row.names = FALSE)

message("\n========================================")
message("✓ GSEA analysis complete!")
message("Results saved to: ", output_file)
message("========================================")
