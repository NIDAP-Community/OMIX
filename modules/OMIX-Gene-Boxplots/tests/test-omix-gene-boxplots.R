#!/usr/bin/env Rscript

test_args <- commandArgs(FALSE)
test_file <- sub("^--file=", "", test_args[grepl("^--file=", test_args)])
module_dir <- normalizePath(file.path(dirname(test_file), ".."))
legacy_file <- file.path(module_dir, "R", "Boxplot_with_Stats.R")
source(file.path(module_dir, "R", "OMIX_Gene_Boxplots.R"))

stopifnot(file.exists(legacy_file))
stopifnot(exists("gene_boxplot_with_stats", mode = "function"))
stopifnot(exists("gene_boxplot_with_deg_results", mode = "function"))
stopifnot(exists("omix_gene_boxplots", mode = "function"))

# Factor levels deliberately use B then A. The wrapper must not alphabetize
# them, because that would change the original color assignment.
expression <- data.frame(
  GeneName = c("GeneA", "GeneA", "GeneB"),
  A1 = c(1.0, 2.0, 4.2), A2 = c(1.2, 2.1, 4.0), A3 = c(1.1, 2.2, 4.1),
  B1 = c(3.0, 4.0, 2.3), B2 = c(3.1, 4.1, 2.4), B3 = c(3.2, 4.2, 2.5),
  `B-A_pval` = c(0.001, 0.001, 0.02),
  `B-A_adjpval` = c(0.002, 0.002, 0.04),
  check.names = FALSE
)
metadata <- data.frame(
  Sample = c("B1", "B2", "B3", "A1", "A2", "A3"),
  Group = factor(c("B", "B", "B", "A", "A", "A"), levels = c("B", "A")),
  stringsAsFactors = FALSE
)
deg_results <- expression[1L, , drop = FALSE]

legacy <- gene_boxplot_with_deg_results(
  normalized_counts = expression,
  sample_metadata = metadata,
  deg_results = deg_results,
  gene_column = "GeneName",
  sample_column = "Sample",
  category_column = "Group",
  genes = "GeneA",
  pvalue_to_plot = "raw",
  return_full = TRUE
)
out_dir <- tempfile("omix-gene-boxplots-")
wrapped <- omix_gene_boxplots(
  expression_table = expression,
  sample_metadata = metadata,
  genes = "GeneA",
  statistics_mode = "precomputed_deg",
  deg_results = deg_results,
  pvalue_type = "nominal",
  output_dir = out_dir,
  image_dpi = 72
)

stopifnot(isTRUE(all.equal(wrapped$data, legacy$data, check.attributes = FALSE)))
stopifnot(isTRUE(all.equal(wrapped$statistics, legacy$stats, check.attributes = FALSE)))
stopifnot(identical(levels(wrapped$data$category), c("B", "A")))
set.seed(1001)
legacy_layers <- ggplot2::ggplot_build(legacy$plots[["GeneA"]])$data
set.seed(1001)
wrapped_layers <- ggplot2::ggplot_build(wrapped$plots[["GeneA"]])$data
stopifnot(isTRUE(all.equal(wrapped_layers, legacy_layers, check.attributes = FALSE)))
# Duplicate GeneA rows retain the original sum-duplicates behavior.
stopifnot(identical(sort(round(wrapped$data$value, 1)), c(3, 3.3, 3.3, 7, 7.2, 7.4)))
stopifnot(file.exists(file.path(out_dir, "gene_boxplots", "GeneA.png")))
stopifnot(file.exists(file.path(out_dir, "gene_boxplot_statistics.csv")))
stopifnot(file.exists(file.path(out_dir, "gene_boxplot_expression_long.csv")))
stopifnot(file.exists(file.path(out_dir, "gene_boxplot_run_summary.csv")))

# Regression check for the original ANOVA/Tukey workflow. This prevents the
# former simplified wrapper's erroneous fallback from ANOVA to t-tests.
legacy_anova <- gene_boxplot_with_stats(
  normalized_counts = expression,
  sample_metadata = metadata,
  gene_column = "GeneName",
  sample_column = "Sample",
  category_column = "Group",
  genes = "GeneB",
  statistical_method = "anova",
  return_full = TRUE
)
wrapped_anova <- omix_gene_boxplots(
  expression_table = expression,
  sample_metadata = metadata,
  genes = "GeneB",
  statistics_mode = "within_plot",
  statistical_method = "anova"
)
stopifnot(isTRUE(all.equal(wrapped_anova$statistics, legacy_anova$stats, check.attributes = FALSE)))

message("OMIX-Gene-Boxplots legacy compatibility checks passed")
