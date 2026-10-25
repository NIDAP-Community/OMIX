#!/usr/bin/env Rscript

test_file <- sub("^--file=", "", commandArgs(FALSE)[grepl("^--file=", commandArgs(FALSE))])
module_dir <- normalizePath(file.path(dirname(test_file), ".."))
result_dir <- tempfile("omix-expression-heatmap-")
on.exit(unlink(result_dir, recursive = TRUE), add = TRUE)

command <- c(
  file.path(module_dir, "scripts", "run_expression_heatmap.R"),
  paste0("--expression_matrix=", file.path(module_dir, "tests", "fixtures", "expression_matrix.csv")),
  paste0("--sample_metadata=", file.path(module_dir, "tests", "fixtures", "sample_metadata.csv")),
  "--group_columns=Group,Batch",
  "--include_all_genes=true",
  "--filter_top_genes_by_variance=false",
  paste0("--output_dir=", result_dir)
)
status <- system2("Rscript", command)
stopifnot(identical(status, 0L))
expected <- c("expression_heatmap.png", "expression_heatmap_matrix.csv", "expression_heatmap_run_summary.txt")
stopifnot(all(file.exists(file.path(result_dir, expected))))
plotted <- utils::read.csv(file.path(result_dir, "expression_heatmap_matrix.csv"), check.names = FALSE)
stopifnot(identical(names(plotted), c("Gene", "Sample_A", "Sample_B", "Sample_C", "Sample_D")))
stopifnot(nrow(plotted) == 6L)
run_summary <- readLines(file.path(result_dir, "expression_heatmap_run_summary.txt"))
stopifnot(all(c(
  "display_gene_names=auto",
  "gene_name_font_size=auto",
  "row_label_max_length=30"
) %in% run_summary))

# Preserve the established explicit controls while the defaults are automatic.
explicit_result_dir <- tempfile("omix-expression-heatmap-explicit-")
on.exit(unlink(explicit_result_dir, recursive = TRUE), add = TRUE)
explicit_command <- c(
  command[!grepl("^--output_dir=", command)],
  "--display_gene_names=true",
  "--gene_name_font_size=7",
  "--row_label_max_length=18",
  paste0("--output_dir=", explicit_result_dir)
)
status <- system2("Rscript", explicit_command)
stopifnot(identical(status, 0L))
explicit_summary <- readLines(file.path(
  explicit_result_dir,
  "expression_heatmap_run_summary.txt"
))
stopifnot(all(c(
  "display_gene_names=true",
  "gene_name_font_size=7",
  "row_label_max_length=18"
) %in% explicit_summary))
message("OMIX Expression Heatmap CLI fixture test passed")
