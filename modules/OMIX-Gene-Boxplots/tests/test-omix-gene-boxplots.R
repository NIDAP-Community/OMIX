#!/usr/bin/env Rscript

test_args <- commandArgs(FALSE)
test_file <- sub("^--file=", "", test_args[grepl("^--file=", test_args)])
module_dir <- normalizePath(file.path(dirname(test_file), ".."))
source(file.path(module_dir, "R", "OMIX_Gene_Boxplots.R"))

expression <- data.frame(
  GeneName = c("GeneA", "GeneB"),
  A1 = c(3.1, 4.2), A2 = c(3.3, 4.0), A3 = c(3.2, 4.1),
  B1 = c(6.1, 2.3), B2 = c(5.9, 2.4), B3 = c(6.2, 2.5),
  `B-A_pval` = c(0.001, 0.02),
  `B-A_adjpval` = c(0.002, 0.04),
  check.names = FALSE
)
metadata <- data.frame(
  Sample = c("A1", "A2", "A3", "B1", "B2", "B3"),
  Group = c("A", "A", "A", "B", "B", "B"),
  stringsAsFactors = FALSE
)
out_dir <- tempfile("omix-gene-boxplots-")
result <- omix_gene_boxplots(
  expression_table = expression,
  sample_metadata = metadata,
  genes = c("GeneA", "GeneB"),
  statistics_mode = "precomputed_deg",
  deg_results = expression,
  pvalue_type = "nominal",
  output_dir = out_dir,
  image_dpi = 72
)
stopifnot(length(result$plots) == 2L)
stopifnot(nrow(result$statistics) == 2L)
stopifnot(all(result$statistics$source == "precomputed_deg"))
stopifnot(file.exists(file.path(out_dir, "gene_boxplots", "GeneA.png")))
stopifnot(file.exists(file.path(out_dir, "gene_boxplot_statistics.csv")))

within_plot <- omix_gene_boxplots(
  expression_table = expression,
  sample_metadata = metadata,
  genes = "GeneA",
  statistics_mode = "within_plot",
  statistical_method = "t-test"
)
stopifnot(nrow(within_plot$statistics) == 1L)
stopifnot(within_plot$statistics$source[[1L]] == "within_plot_t-test")

message("OMIX-Gene-Boxplots behavior checks passed")
