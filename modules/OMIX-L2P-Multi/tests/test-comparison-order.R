#!/usr/bin/env Rscript

test_args <- commandArgs(FALSE)
test_file <- sub("^--file=", "", test_args[grepl("^--file=", test_args)])
module_dir <- normalizePath(file.path(dirname(test_file), ".."))
source(file.path(module_dir, "R", "analysis_functions.R"))

requested_comparisons <- c("B-A", "C-A", "B-C")

# Use a deterministic L2P stand-in so this regression exercises both full
# gene-list selection paths without making pathway-database contents part of
# the ordering contract. The first selected gene identifies the comparison
# and direction and deliberately assigns cross-comparison p-values that would
# reproduce the former globally p-value-sorted export.
l2p <- function(a, ...) {
  selected_genes <- as.character(a)
  selected_id <- selected_genes[[1L]]
  comparison <- sub("_(UP|DOWN)_.*$", "", selected_id)
  direction <- sub("^[^_]+_", "", selected_id)
  direction <- sub("_.*$", "", direction)

  comparison_p <- c("B-A" = 0.030, "C-A" = 0.001, "B-C" = 0.010)
  direction_offset <- if (identical(direction, "DOWN")) 0.001 else 0
  pathway_prefix <- paste0("PATH_", gsub("-", "_", comparison))
  pathway_name <- paste0(pathway_prefix, c("_ZETA", "_ALPHA"))
  pathway_p <- unname(comparison_p[[comparison]]) +
    c(0.004, 0) + direction_offset

  data.frame(
    pathway_name = pathway_name,
    pathway_id = pathway_name,
    category = "CUSTOM",
    enrichment_score = if (identical(direction, "UP")) c(2, 3) else c(1, 2),
    number_hits = rep(length(selected_genes), 2L),
    number_misses = rep(20L, 2L),
    percent_gene_hits_per_pathway = rep(length(selected_genes) / 30, 2L),
    pval = pathway_p,
    fdr = pathway_p,
    allgenesinpw = rep(paste(selected_genes, collapse = " "), 2L),
    stringsAsFactors = FALSE
  )
}

make_deg_table <- function(
  t_statistic_suffix = "_tstat",
  significance_suffix = "_pval",
  fold_change_suffix = "_FC"
) {
  rows <- unlist(lapply(requested_comparisons, function(comparison) {
    c(
      paste0(comparison, "_UP_", seq_len(6L)),
      paste0(comparison, "_DOWN_", seq_len(6L))
    )
  }), use.names = FALSE)
  deg <- data.frame(GeneName = rows, stringsAsFactors = FALSE)

  for (comparison in requested_comparisons) {
    is_up <- grepl(paste0("^", comparison, "_UP_"), deg$GeneName)
    is_down <- grepl(paste0("^", comparison, "_DOWN_"), deg$GeneName)
    deg[[paste0(comparison, t_statistic_suffix)]] <- ifelse(
      is_up,
      10,
      ifelse(is_down, -10, 0)
    )
    deg[[paste0(comparison, significance_suffix)]] <- ifelse(
      is_up | is_down,
      0.001,
      1
    )
    deg[[paste0(comparison, fold_change_suffix)]] <- ifelse(
      is_up,
      2,
      ifelse(is_down, -2, 0)
    )
  }

  deg
}

assert_requested_order <- function(results, csv_file) {
  observed_groups <- unique(as.character(results$group))
  stopifnot(identical(observed_groups, requested_comparisons))

  for (comparison in requested_comparisons) {
    comparison_p <- results$pval[as.character(results$group) == comparison]
    stopifnot(length(comparison_p) == 2L)
    stopifnot(identical(comparison_p, sort(comparison_p)))
  }

  serialized <- utils::read.csv(csv_file, stringsAsFactors = FALSE)
  stopifnot(identical(unique(serialized$group), requested_comparisons))
  stopifnot(identical(serialized$pval, results$pval))
}

run_case <- function(
  select_by_rank,
  t_statistic_suffix = "_tstat",
  significance_suffix = "_pval",
  fold_change_suffix = "_FC",
  exact_column_overrides = FALSE
) {
  output_file <- tempfile(fileext = ".csv")
  on.exit({
    unlink(output_file)
    unlink(sub("\\.csv$", "_provenance.csv", output_file))
  }, add = TRUE)

  results <- suppressWarnings(l2p_multi(
    deg_table = make_deg_table(
      t_statistic_suffix = t_statistic_suffix,
      significance_suffix = significance_suffix,
      fold_change_suffix = fold_change_suffix
    ),
    comparisons = requested_comparisons,
    t_statistic_columns = if (exact_column_overrides) {
      paste0(requested_comparisons, t_statistic_suffix)
    } else {
      NULL
    },
    significance_columns = if (exact_column_overrides) {
      paste0(requested_comparisons, significance_suffix)
    } else {
      NULL
    },
    fold_change_columns = if (exact_column_overrides) {
      paste0(requested_comparisons, fold_change_suffix)
    } else {
      NULL
    },
    t_statistic_suffix = if (exact_column_overrides) "_unused_rank" else t_statistic_suffix,
    significance_suffix = if (exact_column_overrides) "_unused_significance" else significance_suffix,
    fold_change_suffix = if (exact_column_overrides) "_unused_fold_change" else fold_change_suffix,
    gene_names_column = "GeneName",
    species = "Human",
    update_genes = FALSE,
    collections_to_include = "H",
    select_by_rank = select_by_rank,
    select_top_percentage_of_genes = FALSE,
    select_top_genes = 6L,
    significance_threshold = 0.05,
    fold_change_threshold = 1.2,
    minimum_number_of_deg_genes = 0,
    minimum_pathway_hit_count = 0,
    p_value_limit = 0.05,
    export_results_file = output_file
  ))

  assert_requested_order(results, output_file)
}

run_case(select_by_rank = FALSE)
run_case(select_by_rank = TRUE)
run_case(
  select_by_rank = FALSE,
  t_statistic_suffix = "_statistic",
  significance_suffix = "_adjpval",
  fold_change_suffix = "_logFC"
)
run_case(
  select_by_rank = TRUE,
  t_statistic_suffix = "_statistic",
  significance_suffix = "_adjpval",
  fold_change_suffix = "_logFC"
)
run_case(
  select_by_rank = FALSE,
  t_statistic_suffix = "_statistic",
  significance_suffix = "_adjpval",
  fold_change_suffix = "_logFC",
  exact_column_overrides = TRUE
)
run_case(
  select_by_rank = TRUE,
  t_statistic_suffix = "_statistic",
  significance_suffix = "_adjpval",
  fold_change_suffix = "_logFC",
  exact_column_overrides = TRUE
)

message("OMIX-L2P-Multi comparison-order checks passed")
