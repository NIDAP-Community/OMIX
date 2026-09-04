#!/usr/bin/env Rscript

# Platform-neutral command-line entry point for legacy OMIX GSEA visualization.
# All inputs are explicit paths; workflow-result discovery belongs only in a
# deployment adapter.

suppressPackageStartupMessages({
  library(optparse)
})

script_argument <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
if (length(script_argument) != 1L) {
  stop("ERROR: Could not determine the location of scripts/run_gsea_visualization.R")
}
module_root <- normalizePath(file.path(dirname(sub("^--file=", "", script_argument)), ".."))
source(file.path(module_root, "R", "gsea_enrichment_plot.R"))

option_list <- list(
  make_option("--msigdb_database", type = "character", help = "MSigDB database (CSV or RDS) used to restore absent pathway membership"),
  make_option("--gsea_filter_results", type = "character", help = "Filtered GSEA results (CSV or RDS)"),
  make_option("--deg_table", type = "character", help = "DEG Analysis table with ranking statistics and sample-level expression (CSV or RDS)"),
  make_option("--sample_metadata", type = "character", help = "Sample metadata matching DEG-expression columns (CSV or RDS)"),
  make_option("--output_dir", type = "character", default = "results", help = "Output directory [default: %default]"),
  make_option("--contrast_filter", type = "character", default = "none", help = "none, keep, or remove [default: %default]"),
  make_option("--contrasts", type = "character", default = NULL, help = "Comma-separated contrasts for keep/remove mode"),
  make_option("--top_n_pathways", type = "integer", default = 1L, help = "Top pathways per contrast and collection; 0 means all [default: %default]"),
  make_option("--top_n_by_sign", type = "logical", default = FALSE, help = "Apply top N separately to positive and negative ES [default: %default]"),
  make_option("--max_plots_in_pdf", type = "integer", default = 0L, help = "Global plot limit; 0 means unlimited [default: %default]"),
  make_option("--plots_to_include", type = "character", default = "ES+RNK+LE", help = "ES, ES+RNK, ES+LE, ES+RNK+LE, or LE [default: %default]"),
  make_option("--running_score_line_color", type = "character", default = "ES sign", help = "ES sign or green [default: %default]"),
  make_option("--add_max_deviation_line", type = "character", default = "both", help = "coordinate, horizontal, both, or none [default: %default]"),
  make_option("--rank_area_color", type = "character", default = "red/blue by Gene score", help = "grey or red/blue by Gene score [default: %default]"),
  make_option("--show_es_rank_bar", type = "logical", default = FALSE, help = "Show ranked-score strip in ES panel [default: %default]"),
  make_option("--show_rnk_peak_line", type = "logical", default = TRUE, help = "Show peak ES guide in RNK panel [default: %default]"),
  make_option("--show_rnk_le_highlight", type = "logical", default = TRUE, help = "Show leading-edge highlight in RNK panel [default: %default]"),
  make_option("--show_es_le_highlight", type = "logical", default = TRUE, help = "Show leading-edge highlight in ES panel [default: %default]"),
  make_option("--heatmap_transform", type = "character", default = "z-score", help = "z-score, center by row mean, center by row median, or none [default: %default]"),
  make_option("--max_le_genes_heatmap", type = "integer", default = 50L, help = "Maximum leading-edge genes in heatmap [default: %default]"),
  make_option("--heatmap_gene_order", type = "character", default = "rank", help = "rank, cluster, or input [default: %default]"),
  make_option("--heatmap_sample_order", type = "character", default = "group", help = "group, cluster, or input [default: %default]"),
  make_option("--heatmap_gene_clustering_distance", type = "character", default = "euclidean", help = "Gene clustering distance [default: %default]"),
  make_option("--heatmap_gene_clustering_method", type = "character", default = "complete", help = "Gene clustering method [default: %default]"),
  make_option("--heatmap_sample_clustering_distance", type = "character", default = "euclidean", help = "Sample clustering distance [default: %default]"),
  make_option("--heatmap_sample_clustering_method", type = "character", default = "complete", help = "Sample clustering method [default: %default]"),
  make_option("--show_le_heatmap_gene_names", type = "logical", default = TRUE, help = "Show heatmap gene names [default: %default]"),
  make_option("--show_le_heatmap_sample_names", type = "logical", default = FALSE, help = "Show heatmap sample names [default: %default]"),
  make_option("--show_le_heatmap_rank_labels", type = "logical", default = TRUE, help = "Show leading-edge rank labels [default: %default]"),
  make_option("--heatmap_gene_names_column", type = "character", default = "GeneName", help = "Gene column in the DEG table [default: %default]"),
  make_option("--heatmap_sample_names_column", type = "character", default = "Sample", help = "Sample column in metadata [default: %default]"),
  make_option("--heatmap_group_column", type = "character", default = "Group", help = "Group column in metadata [default: %default]"),
  make_option("--pdf_width", type = "double", default = 8.5, help = "PDF width in inches [default: %default]"),
  make_option("--pdf_height", type = "double", default = 6.5, help = "PDF height in inches [default: %default]")
)
opt <- parse_args(OptionParser(option_list = option_list))

require_file <- function(path, label) {
  if (is.null(path) || !nzchar(trimws(path))) {
    stop("ERROR: --", label, " is required", call. = FALSE)
  }
  if (!file.exists(path)) {
    stop("ERROR: ", label, " was not found: ", path, call. = FALSE)
  }
  normalizePath(path, winslash = "/", mustWork = TRUE)
}

parse_comma_list <- function(value) {
  if (is.null(value) || !nzchar(trimws(value))) return(character(0))
  values <- trimws(strsplit(value, ",", fixed = TRUE)[[1L]])
  unique(values[!is.na(values) & nzchar(values)])
}

read_table_input <- function(path, label) {
  extension <- tolower(tools::file_ext(path))
  value <- if (identical(extension, "rds")) {
    readRDS(path)
  } else if (identical(extension, "csv")) {
    utils::read.csv(path, check.names = FALSE, stringsAsFactors = FALSE)
  } else {
    stop("ERROR: ", label, " must be CSV or RDS: ", path, call. = FALSE)
  }
  if (is.matrix(value)) value <- as.data.frame(value, check.names = FALSE, stringsAsFactors = FALSE)
  if (!is.data.frame(value)) stop("ERROR: ", label, " must contain a data frame or matrix.", call. = FALSE)
  value
}

normalize_identifier_column <- function(data, default_name) {
  if (!is.data.frame(data) || ncol(data) == 0L) return(data)
  first_name <- names(data)[[1L]]
  unnamed <- is.na(first_name) || !nzchar(first_name) || first_name %in% c("...1", "row.names")
  if (unnamed && (is.character(data[[1L]]) || is.factor(data[[1L]]))) names(data)[[1L]] <- default_name
  data
}

read_msigdb_database <- function(path) {
  database <- read_table_input(path, "MSigDB database")
  required <- c("collection", "gene_set_name", "gene_symbol")
  missing <- setdiff(required, names(database))
  if (length(missing) > 0L) {
    stop("ERROR: MSigDB database is missing required column(s): ", paste(missing, collapse = ", "), call. = FALSE)
  }
  database
}

has_pathway_membership <- function(row) {
  fields <- intersect(c("inPathway_orthologs", "inPathway"), names(row))
  any(vapply(fields, function(field) length(gsea_vis_gene_vector(row[[field]])) > 0L, logical(1)))
}

same_text <- function(values, target) {
  tolower(trimws(as.character(values))) == tolower(trimws(as.character(target)))
}

restore_msigdb_membership <- function(gsea_rows, database) {
  missing_membership <- !vapply(seq_len(nrow(gsea_rows)), function(i) has_pathway_membership(gsea_rows[i, , drop = FALSE]), logical(1))
  if (!any(missing_membership)) return(gsea_rows)
  if (!"inPathway" %in% names(gsea_rows)) gsea_rows$inPathway <- NA_character_
  for (index in which(missing_membership)) {
    row <- gsea_rows[index, , drop = FALSE]
    candidates <- database[
      same_text(database$collection, row$collection[[1L]]) &
        same_text(database$gene_set_name, row$pathway[[1L]]),
      , drop = FALSE
    ]
    for (field in c("pathways_database", "species")) {
      if (field %in% names(row) && field %in% names(candidates) && !is.na(row[[field]][[1L]]) && nzchar(as.character(row[[field]][[1L]]))) {
        candidates <- candidates[same_text(candidates[[field]], row[[field]][[1L]]), , drop = FALSE]
      }
    }
    genes <- unique(as.character(candidates$gene_symbol))
    genes <- genes[!is.na(genes) & nzchar(genes)]
    if (length(genes) == 0L) {
      stop("ERROR: MSigDB did not provide genes for ", row$collection[[1L]], " / ", row$pathway[[1L]], call. = FALSE)
    }
    gsea_rows$inPathway[[index]] <- paste(genes, collapse = ",")
  }
  gsea_rows
}

find_gene_column <- function(column_names) {
  candidates <- intersect(c("GeneName", "Gene", "gene", "gene_name", "gene_id", "gene_symbol", "symbol", "Symbol", "SYMBOL", "GENE"), column_names)
  if (length(candidates) > 0L) candidates[[1L]] else column_names[[1L]]
}

load_ranked_statistics <- function(deg_table, requested_contrasts = character(0)) {
  deg_table <- normalize_identifier_column(deg_table, "GeneName")
  gene_column <- find_gene_column(names(deg_table))
  suffixes <- c("_tstat", "_logFC", "_log2FC", "_logFoldChange", "_FC")
  statistic_columns <- character(0)
  selected_suffix <- NULL
  for (suffix in suffixes) {
    hits <- grep(paste0(suffix, "$"), names(deg_table), value = TRUE, ignore.case = TRUE)
    if (length(hits) > 0L) {
      statistic_columns <- hits
      selected_suffix <- suffix
      break
    }
  }
  if (length(statistic_columns) == 0L) {
    stop("ERROR: DEG table has no recognized wide ranking columns (for example, B-A_tstat or B-A_logFC).", call. = FALSE)
  }
  contrast_names <- sub(paste0(selected_suffix, "$"), "", statistic_columns, ignore.case = TRUE)
  if (length(requested_contrasts) > 0L) {
    keep <- contrast_names %in% requested_contrasts
    statistic_columns <- statistic_columns[keep]
    contrast_names <- contrast_names[keep]
  }
  if (length(statistic_columns) == 0L) {
    stop("ERROR: None of the requested contrast(s) were found in the DEG table.", call. = FALSE)
  }
  genes <- as.character(deg_table[[gene_column]])
  stats <- setNames(lapply(statistic_columns, function(column_name) {
    values <- suppressWarnings(as.numeric(deg_table[[column_name]]))
    ranked <- setNames(values, genes)
    ranked <- ranked[!is.na(ranked) & !duplicated(names(ranked)) & !is.na(names(ranked)) & nzchar(names(ranked))]
    sort(ranked, decreasing = TRUE)
  }), contrast_names)
  stats[vapply(stats, length, integer(1)) > 0L]
}

validate_choice <- function(value, choices, parameter) {
  if (!value %in% choices) {
    stop("ERROR: Invalid ", parameter, ". Allowed values: ", paste(choices, collapse = ", "), call. = FALSE)
  }
  value
}

main <- function() {
  paths <- list(
    msigdb = require_file(opt$msigdb_database, "msigdb_database"),
    gsea = require_file(opt$gsea_filter_results, "gsea_filter_results"),
    deg = require_file(opt$deg_table, "deg_table"),
    metadata = require_file(opt$sample_metadata, "sample_metadata")
  )
  opt$contrast_filter <- validate_choice(opt$contrast_filter, c("none", "keep", "remove"), "contrast_filter")
  opt$plots_to_include <- validate_choice(opt$plots_to_include, c("ES", "ES+RNK", "ES+LE", "ES+RNK+LE", "LE"), "plots_to_include")
  opt$heatmap_transform <- validate_choice(opt$heatmap_transform, c("z-score", "center by row mean", "center by row median", "none"), "heatmap_transform")
  opt$heatmap_gene_order <- validate_choice(opt$heatmap_gene_order, c("rank", "cluster", "input"), "heatmap_gene_order")
  opt$heatmap_sample_order <- validate_choice(opt$heatmap_sample_order, c("group", "cluster", "input"), "heatmap_sample_order")
  opt$running_score_line_color <- switch(opt$running_score_line_color, "red/blue by ES" = "ES sign", "ES sign" = "ES sign", "green" = "green", stop("ERROR: Invalid running_score_line_color.", call. = FALSE))
  opt$add_max_deviation_line <- switch(opt$add_max_deviation_line, "x-coordinate" = "coordinate", "y-coordinate" = "horizontal", "xy-coordinate" = "both", "coordinate" = "coordinate", "horizontal" = "horizontal", "both" = "both", "none" = FALSE, stop("ERROR: Invalid add_max_deviation_line.", call. = FALSE))

  gsea <- read_table_input(paths$gsea, "filtered GSEA results")
  required_gsea <- c("contrast", "collection", "pathway")
  missing_gsea <- setdiff(required_gsea, names(gsea))
  if (length(missing_gsea) > 0L) stop("ERROR: Filtered GSEA results are missing: ", paste(missing_gsea, collapse = ", "), call. = FALSE)

  contrast_names <- parse_comma_list(opt$contrasts)
  if (identical(opt$contrast_filter, "keep") && length(contrast_names) == 0L) stop("ERROR: --contrast_filter keep requires --contrasts.", call. = FALSE)
  available <- unique(as.character(gsea$contrast))
  plot_contrasts <- switch(opt$contrast_filter, keep = contrast_names, remove = setdiff(available, contrast_names), none = character(0))
  plot_all <- is.na(opt$top_n_pathways) || opt$top_n_pathways <= 0L
  selected <- gsea_vis_select_rows(gsea, plot_contrasts = plot_contrasts, plot_all_pathways = plot_all, top_n_pathways = if (plot_all) 1L else opt$top_n_pathways, top_n_by_sign = isTRUE(opt$top_n_by_sign))
  if (!is.data.frame(selected) || nrow(selected) == 0L) stop("ERROR: No GSEA rows matched the selected contrasts and pathway settings.", call. = FALSE)
  if (!is.na(opt$max_plots_in_pdf) && opt$max_plots_in_pdf > 0L) selected <- utils::head(selected, opt$max_plots_in_pdf)

  selected <- restore_msigdb_membership(selected, read_msigdb_database(paths$msigdb))
  deg <- read_table_input(paths$deg, "DEG table")
  metadata <- normalize_identifier_column(read_table_input(paths$metadata, "sample metadata"), "Sample")
  ranked_stats <- load_ranked_statistics(deg, unique(as.character(selected$contrast)))
  missing_stats <- setdiff(unique(as.character(selected$contrast)), names(ranked_stats))
  if (length(missing_stats) > 0L) stop("ERROR: DEG table lacks ranking statistics for: ", paste(missing_stats, collapse = ", "), call. = FALSE)

  dir.create(opt$output_dir, recursive = TRUE, showWarnings = FALSE)
  result <- GSEA_Visualization_Local(
    gsea_filter_result = gsea,
    gsea_preranked_result = list(ranked_stats = ranked_stats),
    batch_result = list(final_expression = deg, metadata = metadata),
    selected_rows = selected,
    max_plots_in_pdf = 0L,
    stop_if_too_many_plots = FALSE,
    plots_to_include = opt$plots_to_include,
    running_score_line_color = opt$running_score_line_color,
    add_max_deviation_line = opt$add_max_deviation_line,
    rank_area_color = opt$rank_area_color,
    show_es_rank_bar = opt$show_es_rank_bar,
    show_rnk_peak_line = opt$show_rnk_peak_line,
    show_rnk_le_highlight = opt$show_rnk_le_highlight,
    show_es_le_highlight = opt$show_es_le_highlight,
    heatmap_gene_names_column = opt$heatmap_gene_names_column,
    heatmap_sample_names_column = opt$heatmap_sample_names_column,
    heatmap_group_column = opt$heatmap_group_column,
    heatmap_transform = opt$heatmap_transform,
    max_le_genes_heatmap = opt$max_le_genes_heatmap,
    heatmap_gene_order = opt$heatmap_gene_order,
    heatmap_sample_order = opt$heatmap_sample_order,
    heatmap_gene_clustering_distance = opt$heatmap_gene_clustering_distance,
    heatmap_gene_clustering_method = opt$heatmap_gene_clustering_method,
    heatmap_sample_clustering_distance = opt$heatmap_sample_clustering_distance,
    heatmap_sample_clustering_method = opt$heatmap_sample_clustering_method,
    show_le_heatmap_gene_names = opt$show_le_heatmap_gene_names,
    show_le_heatmap_sample_names = opt$show_le_heatmap_sample_names,
    show_le_heatmap_rank_labels = opt$show_le_heatmap_rank_labels,
    pdf_width = opt$pdf_width,
    pdf_height = opt$pdf_height,
    output_dir = opt$output_dir
  )
  message(result$message)
  if (!is.null(result$files$pdf)) message("PDF: ", result$files$pdf)
  if (!is.null(result$files$running_es)) message("Running ES: ", result$files$running_es)
}

tryCatch(main(), error = function(error) {
  message("ERROR: ", conditionMessage(error))
  quit(status = 1)
})
