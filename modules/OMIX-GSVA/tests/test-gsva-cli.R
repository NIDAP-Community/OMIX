#!/usr/bin/env Rscript

required_packages <- c("GSVA", "dplyr", "l2psupp", "stringr", "tibble", "optparse")
missing_packages <- required_packages[
  !vapply(required_packages, requireNamespace, logical(1), quietly = TRUE)
]
if (length(missing_packages) > 0L) {
  message("SKIP: missing package(s): ", paste(missing_packages, collapse = ", "))
  quit(status = 0L)
}

script_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
if (length(script_arg) != 1L) stop("Run this test with Rscript tests/test-gsva-cli.R")
module_root <- normalizePath(file.path(dirname(sub("^--file=", "", script_arg)), ".."))
cli_file <- file.path(module_root, "scripts", "run_gsva.R")

test_root <- tempfile("omix-gsva-test-")
dir.create(test_root, recursive = TRUE)
on.exit(unlink(test_root, recursive = TRUE), add = TRUE)
output_dir <- file.path(test_root, "results")

set.seed(20260923)
samples <- paste0("S", seq_len(6L))
genes <- paste0("G", seq_len(40L))
expression <- data.frame(
  Gene = genes,
  matrix(stats::rnorm(length(genes) * length(samples), mean = 6, sd = 1),
    nrow = length(genes), dimnames = list(NULL, samples)),
  check.names = FALSE
)
metadata <- data.frame(
  Sample = c("S3", "S1", "S6", "S2", "S5", "S4"),
  Group = c("B", "A", "B", "A", "B", "A"),
  stringsAsFactors = FALSE
)
pathways <- rbind(
  data.frame(
    collection = "H: hallmark gene sets",
    gene_set_name = "TEST_SET_A",
    gene_symbol = genes[1:20],
    species = "Human"
  ),
  data.frame(
    collection = "H: hallmark gene sets",
    gene_set_name = "TEST_SET_B",
    gene_symbol = genes[21:40],
    species = "Human"
  )
)

expression_path <- file.path(test_root, "normalized.tsv")
metadata_path <- file.path(test_root, "metadata.tsv")
pathways_path <- file.path(test_root, "pathways.tsv")
utils::write.table(expression, expression_path, sep = "\t", row.names = FALSE, quote = FALSE)
utils::write.table(metadata, metadata_path, sep = "\t", row.names = FALSE, quote = FALSE)
utils::write.table(pathways, pathways_path, sep = "\t", row.names = FALSE, quote = FALSE)

status <- system2(
  file.path(R.home("bin"), "Rscript"),
  c(
    "--vanilla", shQuote(cli_file),
    "--normalized_data", shQuote(expression_path),
    "--sample_metadata", shQuote(metadata_path),
    "--pathways_database", shQuote(pathways_path),
    "--gene_column", "Gene",
    "--minimum_geneset_size", "5",
    "--maximum_geneset_size", "100",
    "--update_genes", "false",
    "--output_dir", shQuote(output_dir)
  )
)
stopifnot(identical(status, 0L))

results_path <- file.path(output_dir, "gsva_v1_results.csv")
plot_path <- file.path(output_dir, "gsva_v1_heatmap.png")
summary_path <- file.path(output_dir, "gsva_run_summary.txt")
stopifnot(file.exists(results_path), file.info(results_path)$size > 0L)
stopifnot(file.exists(plot_path), file.info(plot_path)$size > 0L)
stopifnot(file.exists(summary_path), file.info(summary_path)$size > 0L)

results <- utils::read.csv(results_path, check.names = FALSE)
stopifnot(identical(results$Geneset, c("TEST_SET_A", "TEST_SET_B")))
stopifnot(identical(names(results)[-1L], metadata$Sample))
stopifnot(all(vapply(results[-1L], is.numeric, logical(1))))
stopifnot(all(is.finite(as.matrix(results[-1L]))))

summary_text <- readLines(summary_path, warn = FALSE)
stopifnot(any(grepl("method: gsva", summary_text, fixed = TRUE)))
stopifnot(any(grepl("gene sets scored: 2", summary_text, fixed = TRUE)))

message("OMIX-GSVA representative CLI test passed")
