#!/usr/bin/env Rscript

test_args <- commandArgs(FALSE)
test_file <- sub("^--file=", "", test_args[grepl("^--file=", test_args)])
module_dir <- normalizePath(file.path(dirname(test_file), ".."))
legacy_file <- file.path(module_dir, "R", "Boxplot_with_Stats.R")
source(file.path(module_dir, "R", "OMIX_Gene_Boxplots.R"))

fixture_dir <- file.path(module_dir, "tests", "fixtures")
test_device_file <- tempfile("omix-gene-boxplots-test-", fileext = ".pdf")
grDevices::pdf(test_device_file)

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
wrapped_sum <- omix_gene_boxplots(
  expression_table = expression,
  sample_metadata = metadata,
  genes = "GeneA",
  statistics_mode = "precomputed_deg",
  deg_results = deg_results,
  pvalue_type = "nominal",
  duplicate_aggregation = "sum",
  output_dir = out_dir,
  image_dpi = 72
)

stopifnot(isTRUE(all.equal(wrapped_sum$data, legacy$data, check.attributes = FALSE)))
stopifnot(isTRUE(all.equal(wrapped_sum$statistics, legacy$stats, check.attributes = FALSE)))
stopifnot(identical(levels(wrapped_sum$data$category), c("B", "A")))
set.seed(1001)
legacy_layers <- ggplot2::ggplot_build(legacy$plots[["GeneA"]])$data
set.seed(1001)
wrapped_layers <- ggplot2::ggplot_build(wrapped_sum$plots[["GeneA"]])$data
stopifnot(isTRUE(all.equal(wrapped_layers, legacy_layers, check.attributes = FALSE)))
# Explicit sum retains the original duplicate-row behavior.
stopifnot(identical(sort(round(wrapped_sum$data$value, 1)), c(3, 3.3, 3.3, 7, 7.2, 7.4)))
stopifnot(file.exists(file.path(out_dir, "gene_boxplots", "GeneA.png")))
stopifnot(file.exists(file.path(out_dir, "gene_boxplot_statistics.csv")))
stopifnot(file.exists(file.path(out_dir, "gene_boxplot_expression_long.csv")))
stopifnot(file.exists(file.path(out_dir, "gene_boxplot_run_summary.csv")))

# The canonical default averages duplicate log-space rows before entering the
# preserved plotting functions.
wrapped_mean <- omix_gene_boxplots(
  expression_table = expression,
  sample_metadata = metadata,
  genes = "GeneA",
  statistics_mode = "precomputed_deg",
  deg_results = deg_results,
  pvalue_type = "nominal"
)
stopifnot(identical(wrapped_mean$duplicate_aggregation, "mean"))
stopifnot(isTRUE(all.equal(
  sort(wrapped_mean$data$value),
  c(1.5, 1.65, 1.65, 3.5, 3.6, 3.7),
  check.attributes = FALSE
)))

# Fixture regressions cover default mean, explicit legacy sum, keep,
# no-duplicate identity, and partial/all-missing input.
duplicate_expression <- utils::read.csv(
  file.path(fixture_dir, "duplicate-expression.csv"),
  stringsAsFactors = FALSE,
  check.names = FALSE
)
duplicate_metadata <- utils::read.csv(
  file.path(fixture_dir, "duplicate-metadata.csv"),
  stringsAsFactors = FALSE,
  check.names = FALSE
)
expected_summed <- utils::read.csv(
  file.path(fixture_dir, "duplicate-expected-summed-long.csv"),
  stringsAsFactors = FALSE,
  check.names = FALSE
)
expected_mean <- utils::read.csv(
  file.path(fixture_dir, "duplicate-expected-mean-long.csv"),
  stringsAsFactors = FALSE,
  check.names = FALSE,
  na.strings = "NA"
)

prepare_fixture_long <- function(method) {
  aggregated <- omix_aggregate_duplicate_genes(
    expression_table = duplicate_expression,
    sample_metadata = duplicate_metadata,
    gene_column = "GeneName",
    sample_column = "Sample",
    duplicate_aggregation = method
  )
  out <- boxplot_prepare_long(
    normalized_counts = aggregated,
    sample_metadata = duplicate_metadata,
    gene_column = "GeneName",
    sample_column = "Sample",
    category_column = "Group",
    sum_duplicates = FALSE,
    minimum_samples_per_category = 1L
  )$df_long
  out$category <- as.character(out$category)
  as.data.frame(out[, names(expected_mean), drop = FALSE])
}

averaged <- prepare_fixture_long("mean")
summed <- prepare_fixture_long("sum")
stopifnot(isTRUE(all.equal(averaged, expected_mean, check.attributes = FALSE)))
stopifnot(isTRUE(all.equal(summed, expected_summed, check.attributes = FALSE)))

kept <- prepare_fixture_long("keep")
gene_dup_a1 <- kept$value[
  kept$gene == "GeneDup" & kept$sample == "A1"
]
stopifnot(identical(sort(gene_dup_a1), c(0.8, 1.2)))

unique_expression <- duplicate_expression[
  duplicate_expression$GeneName == "GeneSolo",
  ,
  drop = FALSE
]
unique_after_mean <- omix_aggregate_duplicate_genes(
  expression_table = unique_expression,
  sample_metadata = duplicate_metadata,
  gene_column = "GeneName",
  sample_column = "Sample",
  duplicate_aggregation = "mean"
)
stopifnot(isTRUE(all.equal(
  unique_after_mean[, names(unique_expression), drop = FALSE],
  unique_expression,
  check.attributes = FALSE
)))

legacy_flag <- suppressWarnings(omix_gene_boxplots(
  expression_table = expression,
  sample_metadata = metadata,
  genes = "GeneA",
  statistics_mode = "precomputed_deg",
  deg_results = deg_results,
  pvalue_type = "nominal",
  sum_duplicates = TRUE
))
stopifnot(identical(legacy_flag$duplicate_aggregation, "sum"))
stopifnot(isTRUE(all.equal(
  legacy_flag$data,
  wrapped_sum$data,
  check.attributes = FALSE
)))

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

invisible(grDevices::dev.off())
unlink(test_device_file)
message("OMIX-Gene-Boxplots legacy compatibility checks passed")
