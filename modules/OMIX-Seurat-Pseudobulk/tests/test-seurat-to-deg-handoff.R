#!/usr/bin/env Rscript

script_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
if (length(script_arg) != 1L) {
  stop("Run this test with Rscript tests/test-seurat-to-deg-handoff.R")
}
module_root <- normalizePath(file.path(dirname(sub("^--file=", "", script_arg)), ".."))
repo_root <- normalizePath(file.path(module_root, "..", ".."))
required_packages <- c("OmixSeurat", "SeuratObject", "Matrix", "edgeR", "limma")
missing_packages <- required_packages[
  !vapply(required_packages, requireNamespace, logical(1), quietly = TRUE)
]
if (length(missing_packages) > 0L) {
  message(
    "SKIP: Seurat-to-DEG handoff integration requires: ",
    paste(missing_packages, collapse = ", ")
  )
} else {
  source(file.path(module_root, "R", "Seurat_Pseudobulk.R"))
  source(file.path(repo_root, "modules", "OMIX-DEG-Analysis", "R", "OMIX_DEG_Analysis.R"))
  source(file.path(repo_root, "modules", "OMIX-Limma-Analysis", "R", "OMIX_Limma_Analysis.R"))

  set.seed(17)
  metadata <- data.frame(
    donor = rep(c("D1", "D2", "D3"), each = 4L),
    condition = rep(rep(c("A", "B"), each = 2L), 3L),
    cell_type = "Mono",
    Batch = rep(c("Run1", "Run2", "Run3"), each = 4L),
    row.names = paste0("Cell", seq_len(12L)),
    stringsAsFactors = FALSE
  )
  counts <- matrix(
    stats::rpois(200L * nrow(metadata), lambda = 12),
    nrow = 200L,
    dimnames = list(paste0("Gene", seq_len(200L)), rownames(metadata))
  )
  counts[seq_len(30L), metadata$condition == "B"] <-
    counts[seq_len(30L), metadata$condition == "B"] + 15L
  object <- SeuratObject::CreateSeuratObject(
    counts = Matrix::Matrix(counts, sparse = TRUE),
    meta.data = metadata,
    assay = "RNA"
  )
  rds_path <- tempfile(fileext = ".rds")
  output_dir <- tempfile("omix-seurat-to-deg-")
  saveRDS(object, rds_path)

  pseudobulk <- omix_seurat_pseudobulk(
    seurat_rds = rds_path,
    donor_column = "donor",
    group_column = "condition",
    cell_type_column = "cell_type",
    cell_type = "Mono",
    metadata_columns = "Batch",
    min_cells = 2L,
    output_dir = output_dir
  )
  deg <- omix_deg_analysis(
    Dataset = pseudobulk$input$counts,
    Metadata_Table = pseudobulk$input$metadata,
    sample_names_column = "Sample",
    samples_to_include = pseudobulk$input$sample_columns,
    gene_names_column = "GeneName",
    contrast_variable_columns = "Group",
    contrasts = "B-A",
    batch_effect_columns = "Batch"
  )
  stopifnot(all(c("GeneName", "B-A_logFC", "B-A_pval", "B-A_adjpval") %in% names(deg)))
  stopifnot(identical(tail(names(deg), 6L), pseudobulk$input$sample_columns))

  corrected_expression <- log2(as.matrix(counts) + 1)
  object[["Harmony"]] <- SeuratObject::CreateAssayObject(
    counts = Matrix::Matrix(counts, sparse = TRUE)
  )
  object <- SeuratObject::SetAssayData(
    object,
    assay = "Harmony",
    layer = "data",
    new.data = corrected_expression
  )
  saveRDS(object, rds_path)
  harmony_means <- omix_seurat_pseudobulk(
    seurat_rds = rds_path,
    donor_column = "donor",
    group_column = "condition",
    cell_type_column = "cell_type",
    cell_type = "Mono",
    metadata_columns = "Batch",
    aggregation_method = "mean_harmony_corrected_expression",
    min_cells = 2L,
    output_dir = tempfile("omix-seurat-harmony-means-")
  )
  harmony_manifest <- base::read.dcf(harmony_means$manifest_path)
  stopifnot(identical(unname(harmony_manifest[1L, "expected_downstream_module"]), "OMIX-Limma-Analysis"))
  stopifnot(identical(unname(harmony_manifest[1L, "recommended_variance_model"]), "ebayes"))
  harmony_limma <- omix_limma_analysis(
    Dataset = harmony_means$input$expression,
    Metadata_Table = harmony_means$input$metadata,
    sample_names_column = "Sample",
    samples_to_include = harmony_means$input$sample_columns,
    gene_names_column = "GeneName",
    contrast_variable_columns = "Group",
    contrasts = "B-A",
    donor_variable_column = "Donor",
    input_kind = "log2_expression",
    variance_model = "ebayes"
  )
  stopifnot(all(c("Gene", "B-A_logFC", "B-A_pval", "B-A_adjpval") %in% names(harmony_limma)))
  stopifnot(identical(attr(harmony_limma, "omix_limma_run")$variance_model, "ebayes"))

  sct_data <- log1p(as.matrix(counts))
  object[["SCT"]] <- SeuratObject::CreateAssayObject(
    counts = Matrix::Matrix(counts, sparse = TRUE)
  )
  object <- SeuratObject::SetAssayData(
    object,
    assay = "SCT",
    layer = "data",
    new.data = sct_data
  )
  saveRDS(object, rds_path)
  sct_means <- omix_seurat_pseudobulk(
    seurat_rds = rds_path,
    donor_column = "donor",
    group_column = "condition",
    cell_type_column = "cell_type",
    cell_type = "Mono",
    metadata_columns = "Batch",
    aggregation_method = "mean_sctransform_expression",
    min_cells = 2L,
    output_dir = tempfile("omix-seurat-sct-means-")
  )
  sct_expected <- rowMeans(sct_data[, metadata$donor == "D1" & metadata$condition == "A", drop = FALSE]) / log(2)
  stopifnot(isTRUE(all.equal(
    sct_means$input$expression$D1__A,
    unname(sct_expected)
  )))
  sct_manifest <- base::read.dcf(sct_means$manifest_path)
  stopifnot(identical(unname(sct_manifest[1L, "matrix_type"]), "sctransform_mean_log2_expression"))
  stopifnot(identical(unname(sct_manifest[1L, "expected_downstream_module"]), "OMIX-Limma-Analysis"))
  stopifnot(identical(unname(sct_manifest[1L, "recommended_variance_model"]), "ebayes_trend"))
  sct_limma <- omix_limma_analysis(
    Dataset = sct_means$input$expression,
    Metadata_Table = sct_means$input$metadata,
    sample_names_column = "Sample",
    samples_to_include = sct_means$input$sample_columns,
    gene_names_column = "GeneName",
    contrast_variable_columns = "Group",
    contrasts = "B-A",
    donor_variable_column = "Donor",
    input_kind = "log2_expression",
    variance_model = "ebayes_trend"
  )
  stopifnot(all(c("Gene", "B-A_logFC", "B-A_pval", "B-A_adjpval") %in% names(sct_limma)))
  stopifnot(identical(attr(sct_limma, "omix_limma_run")$variance_model, "ebayes_trend"))
  message("OMIX Seurat pseudobulk handoff checks passed")
}
