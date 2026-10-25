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
  "row_label_max_length=30",
  "sample_name_font_size=auto",
  "resolved_sample_name_font_size=12"
) %in% run_summary))

# Preserve the established explicit controls while the defaults are automatic.
explicit_result_dir <- tempfile("omix-expression-heatmap-explicit-")
on.exit(unlink(explicit_result_dir, recursive = TRUE), add = TRUE)
explicit_command <- c(
  command[!grepl("^--output_dir=", command)],
  "--display_gene_names=true",
  "--gene_name_font_size=7",
  "--row_label_max_length=18",
  "--sample_name_font_size=13",
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
  "row_label_max_length=18",
  "sample_name_font_size=13",
  "resolved_sample_name_font_size=13"
) %in% explicit_summary))

# Use real pathway-database-style identifiers to exercise display-only label
# spacing and intuitive word wrapping without conflating this layout fixture
# with a scientific pathway-score calculation.
long_pathway_result_dir <- tempfile("omix-expression-heatmap-long-pathways-")
on.exit(unlink(long_pathway_result_dir, recursive = TRUE), add = TRUE)
long_pathway_command <- c(
  command[!grepl("^--(expression_matrix|output_dir)=", command)],
  paste0(
    "--expression_matrix=",
    file.path(module_dir, "tests", "fixtures", "long_pathway_expression_matrix.csv")
  ),
  paste0("--output_dir=", long_pathway_result_dir)
)
status <- system2("Rscript", long_pathway_command)
stopifnot(identical(status, 0L))
long_pathway_matrix <- utils::read.csv(
  file.path(long_pathway_result_dir, "expression_heatmap_matrix.csv"),
  check.names = FALSE
)
expected_long_pathways <- utils::read.csv(
  file.path(module_dir, "tests", "fixtures", "long_pathway_expression_matrix.csv"),
  check.names = FALSE
)$Gene
stopifnot(setequal(long_pathway_matrix$Gene, expected_long_pathways))
stopifnot(!any(grepl("[\\r\\n]", long_pathway_matrix$Gene)))

# Verify portable group and single-feature ordering through the emitted matrix.
group_order_result_dir <- tempfile("omix-expression-heatmap-group-order-")
on.exit(unlink(group_order_result_dir, recursive = TRUE), add = TRUE)
group_order_command <- c(
  command[!grepl("^--output_dir=", command)],
  "--samples_to_include=Sample_C,Sample_A,Sample_D,Sample_B",
  "--cluster_samples=false",
  "--arrange_sample_columns=true",
  paste0("--output_dir=", group_order_result_dir)
)
status <- system2("Rscript", group_order_command)
stopifnot(identical(status, 0L))
group_order_matrix <- utils::read.csv(
  file.path(group_order_result_dir, "expression_heatmap_matrix.csv"),
  check.names = FALSE
)
stopifnot(identical(
  names(group_order_matrix),
  c("Gene", "Sample_C", "Sample_D", "Sample_A", "Sample_B")
))

feature_order_result_dir <- tempfile("omix-expression-heatmap-feature-order-")
on.exit(unlink(feature_order_result_dir, recursive = TRUE), add = TRUE)
feature_order_command <- c(
  command[!grepl("^--output_dir=", command)],
  "--samples_to_include=Sample_D,Sample_B,Sample_C,Sample_A",
  "--cluster_samples=false",
  "--order_by_gene_expression=true",
  "--gene_to_order_columns=Gene1",
  "--gene_expression_order=low_to_high",
  paste0("--output_dir=", feature_order_result_dir)
)
status <- system2("Rscript", feature_order_command)
stopifnot(identical(status, 0L))
feature_order_matrix <- utils::read.csv(
  file.path(feature_order_result_dir, "expression_heatmap_matrix.csv"),
  check.names = FALSE
)
stopifnot(identical(
  names(feature_order_matrix),
  c("Gene", "Sample_A", "Sample_B", "Sample_C", "Sample_D")
))

# Dendrogram rotation affects the visual leaf order while preserving the
# exported matrix's sample columns; require a complete, explicit leaf vector.
dendrogram_result_dir <- tempfile("omix-expression-heatmap-dendrogram-")
on.exit(unlink(dendrogram_result_dir, recursive = TRUE), add = TRUE)
dendrogram_command <- c(
  command[!grepl("^--output_dir=", command)],
  "--reorder_sample_dendrogram=true",
  "--reorder_sample_dendrogram_order=Sample_D,Sample_C,Sample_B,Sample_A",
  paste0("--output_dir=", dendrogram_result_dir)
)
status <- system2("Rscript", dendrogram_command)
stopifnot(identical(status, 0L))
stopifnot(file.exists(file.path(dendrogram_result_dir, "expression_heatmap.png")))
message("OMIX Expression Heatmap CLI fixture test passed")
