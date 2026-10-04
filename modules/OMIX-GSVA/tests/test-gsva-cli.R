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

expression_path <- file.path(test_root, "normalized.csv")
metadata_path <- file.path(test_root, "metadata.csv")
pathways_path <- file.path(test_root, "pathways.tsv")
utils::write.csv(expression, expression_path, row.names = FALSE, quote = FALSE)
utils::write.csv(metadata, metadata_path, row.names = FALSE, quote = FALSE)
utils::write.table(pathways, pathways_path, sep = "\t", row.names = FALSE, quote = FALSE)

run_cli <- function(
  normalized_path,
  sample_metadata_path,
  pathway_membership_path,
  results_dir,
  capture_output = FALSE
) {
  arguments <- c(
    "--vanilla", shQuote(cli_file),
    "--normalized_data", shQuote(normalized_path),
    "--sample_metadata", shQuote(sample_metadata_path),
    "--pathways_database", shQuote(pathway_membership_path),
    "--gene_column", "Gene",
    "--minimum_geneset_size", "5",
    "--maximum_geneset_size", "100",
    "--update_genes", "false",
    "--output_dir", shQuote(results_dir)
  )
  if (capture_output) {
    return(suppressWarnings(system2(
      file.path(R.home("bin"), "Rscript"),
      arguments,
      stdout = TRUE,
      stderr = TRUE
    )))
  }
  system2(file.path(R.home("bin"), "Rscript"), arguments)
}

# The representative run deliberately mixes CSV expression/metadata with a
# TSV pathway table and relies on independent auto-detection.
status <- run_cli(expression_path, metadata_path, pathways_path, output_dir)
stopifnot(identical(status, 0L))

results_path <- file.path(output_dir, "gsva_results.csv")
plot_path <- file.path(output_dir, "gsva_heatmap.png")
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
stopifnot(any(grepl("OMIX module: OMIX-GSVA", summary_text, fixed = TRUE)))
stopifnot(any(grepl("normalized data delimiter: ,", summary_text, fixed = TRUE)))
stopifnot(any(grepl("sample metadata delimiter: ,", summary_text, fixed = TRUE)))
stopifnot(any(grepl("pathways database delimiter: \\t (tab)", summary_text, fixed = TRUE)))
stopifnot(any(grepl("OMIX module version: 0.3.0", summary_text, fixed = TRUE)))
stopifnot(!any(grepl("source template", summary_text, fixed = TRUE)))

# Uniform TSV and CSV inputs remain supported without delimiter flags.
for (format in c("tsv", "csv")) {
  uniform_dir <- file.path(test_root, paste0("uniform-", format))
  uniform_expression <- file.path(test_root, paste0("normalized-all.", format))
  uniform_metadata <- file.path(test_root, paste0("metadata-all.", format))
  uniform_pathways <- file.path(test_root, paste0("pathways-all.", format))
  if (identical(format, "csv")) {
    utils::write.csv(expression, uniform_expression, row.names = FALSE, quote = FALSE)
    utils::write.csv(metadata, uniform_metadata, row.names = FALSE, quote = FALSE)
    utils::write.csv(pathways, uniform_pathways, row.names = FALSE, quote = FALSE)
  } else {
    utils::write.table(expression, uniform_expression, sep = "\t", row.names = FALSE, quote = FALSE)
    utils::write.table(metadata, uniform_metadata, sep = "\t", row.names = FALSE, quote = FALSE)
    utils::write.table(pathways, uniform_pathways, sep = "\t", row.names = FALSE, quote = FALSE)
  }
  uniform_status <- run_cli(
    uniform_expression,
    uniform_metadata,
    uniform_pathways,
    uniform_dir
  )
  stopifnot(identical(uniform_status, 0L))
  stopifnot(file.exists(file.path(uniform_dir, "gsva_results.csv")))
}

# Ambiguous delimiter detection fails before parsing and names the affected
# input so users know which override to provide.
ambiguous_expression <- file.path(test_root, "normalized-ambiguous.txt")
writeLines("Gene,S1\tS2", ambiguous_expression)
ambiguous_output <- run_cli(
  ambiguous_expression,
  metadata_path,
  pathways_path,
  file.path(test_root, "ambiguous-results"),
  capture_output = TRUE
)
stopifnot(!is.null(attr(ambiguous_output, "status")))
stopifnot(any(grepl("normalized data", ambiguous_output, fixed = TRUE)))

message("OMIX-GSVA representative CLI test passed")
