#!/usr/bin/env Rscript

script_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
if (length(script_arg) != 1L) {
  stop("Run this test with Rscript tests/test-seurat-pseudobulk.R")
}
module_root <- normalizePath(file.path(dirname(sub("^--file=", "", script_arg)), ".."))
source(file.path(module_root, "R", "Seurat_Pseudobulk.R"))

output_dir <- tempfile("omix-seurat-pseudobulk-")
input <- structure(
  list(
    counts = data.frame(
      GeneName = c("GeneA", "GeneB"),
      Donor1__A = c(10, 4),
      Donor1__B = c(14, 3),
      Donor2__A = c(12, 5),
      Donor2__B = c(17, 2),
      check.names = FALSE
    ),
    metadata = data.frame(
      Sample = c("Donor1__A", "Donor1__B", "Donor2__A", "Donor2__B"),
      Donor = c("Donor1", "Donor1", "Donor2", "Donor2"),
      Group = c("A", "B", "A", "B"),
      Batch = c("Run1", "Run1", "Run2", "Run2"),
      CellType = rep("Monocytes", 4L),
      Cells = c(40L, 42L, 45L, 47L),
      stringsAsFactors = FALSE
    ),
    feature_id_column = "GeneName",
    sample_id_column = "Sample",
    sample_columns = c("Donor1__A", "Donor1__B", "Donor2__A", "Donor2__B"),
    provenance = list(bridge = "OmixSeurat", aggregation = "sum_by_donor_and_group")
  ),
  class = "omix_standard_input"
)

result <- .omix_write_seurat_pseudobulk_bundle(
  input = input,
  output_dir = output_dir,
  seurat_rds = "fixture.rds"
)
stopifnot(all(file.exists(unlist(result[c("counts_path", "metadata_path", "manifest_path", "run_summary_path")]))) )
counts <- utils::read.csv(result$counts_path, check.names = FALSE)
metadata <- utils::read.csv(result$metadata_path, check.names = FALSE)
manifest <- base::read.dcf(result$manifest_path)
stopifnot(identical(names(counts)[[1L]], "GeneName"))
stopifnot(identical(as.character(metadata$Sample), input$sample_columns))
stopifnot(identical(as.character(metadata$Batch), c("Run1", "Run1", "Run2", "Run2")))
stopifnot(identical(unname(manifest[1L, "matrix_type"]), "raw_integer_counts"))
stopifnot(identical(unname(manifest[1L, "expected_downstream_module"]), "OMIX-DEG-Analysis"))
stopifnot(identical(unname(manifest[1L, "expected_downstream_mode"]), "raw_counts"))
stopifnot(identical(unname(manifest[1L, "downstream_input_kind"]), "raw_integer_counts"))
stopifnot(identical(unname(manifest[1L, "recommended_variance_model"]), "voom_precision_weights"))
stopifnot(grepl("Pseudobulk profiles: 4", paste(readLines(result$run_summary_path), collapse = "\n"), fixed = TRUE))

invalid_input <- input
invalid_input$feature_id_column <- "Gene"
invalid_error <- tryCatch(
  .omix_write_seurat_pseudobulk_bundle(invalid_input, output_dir, "fixture.rds"),
  error = conditionMessage
)
stopifnot(grepl("GeneName", invalid_error, fixed = TRUE))

continuous_input <- structure(
  list(
    expression = transform(input$counts, Donor1__A = Donor1__A / 10),
    metadata = input$metadata,
    feature_id_column = "GeneName",
    sample_id_column = "Sample",
    sample_columns = input$sample_columns,
    provenance = list(
      bridge = "OmixSeurat",
      assay = "Harmony",
      layer = "data",
      aggregation = "mean_by_donor_and_group"
    )
  ),
  class = "omix_expression_input"
)
continuous_result <- .omix_write_seurat_pseudobulk_bundle(
  input = continuous_input,
  output_dir = tempfile("omix-seurat-mean-expression-"),
  seurat_rds = "fixture.rds",
  aggregation_method = "mean_harmony_corrected_expression"
)
continuous_manifest <- base::read.dcf(continuous_result$manifest_path)
stopifnot(file.exists(continuous_result$expression_path))
stopifnot(is.null(continuous_result$counts_path))
stopifnot(identical(unname(continuous_manifest[1L, "matrix_type"]), "harmony_corrected_mean_expression"))
stopifnot(identical(unname(continuous_manifest[1L, "expected_downstream_module"]), "OMIX-Limma-Analysis"))
stopifnot(identical(unname(continuous_manifest[1L, "expected_downstream_mode"]), "continuous_expression"))
stopifnot(identical(unname(continuous_manifest[1L, "downstream_input_kind"]), "log2_expression"))
stopifnot(identical(unname(continuous_manifest[1L, "recommended_variance_model"]), "ebayes"))

sct_input <- .omix_seurat_sctransform_log2_input(continuous_input)
sct_result <- .omix_write_seurat_pseudobulk_bundle(
  input = sct_input,
  output_dir = tempfile("omix-seurat-sct-expression-"),
  seurat_rds = "fixture.rds",
  aggregation_method = "mean_sctransform_expression"
)
sct_manifest <- base::read.dcf(sct_result$manifest_path)
sct_expression <- utils::read.csv(sct_result$expression_path, check.names = FALSE)
stopifnot(file.exists(sct_result$expression_path))
stopifnot(identical(basename(sct_result$expression_path), "SCT_Mean_Log2_Expression.csv"))
stopifnot(identical(unname(sct_manifest[1L, "matrix_type"]), "sctransform_mean_log2_expression"))
stopifnot(identical(unname(sct_manifest[1L, "expected_downstream_module"]), "OMIX-Limma-Analysis"))
stopifnot(identical(unname(sct_manifest[1L, "expected_downstream_mode"]), "continuous_expression"))
stopifnot(identical(unname(sct_manifest[1L, "recommended_variance_model"]), "ebayes_trend"))
stopifnot(identical(unname(sct_manifest[1L, "upstream_batch_correction"]), "SCTransform_depth_correction_only"))
stopifnot(isTRUE(all.equal(
  sct_expression$Donor1__A,
  continuous_input$expression$Donor1__A / log(2)
)))

message("OMIX-Seurat-Pseudobulk output-bundle checks passed")
