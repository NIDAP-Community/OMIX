make_seurat_fixture <- function() {
  counts <- Matrix::Matrix(
    c(
      10L, 12L, 15L, 20L, 21L, 25L, 30L, 31L, 35L, 40L, 42L, 45L,
      2L, 3L, 1L, 5L, 5L, 7L, 1L, 1L, 2L, 3L, 2L, 4L,
      0L, 1L, 0L, 2L, 1L, 1L, 0L, 1L, 1L, 2L, 2L, 3L
    ),
    nrow = 3L,
    dimnames = list(
      c("GeneA", "GeneB", "GeneC"),
      paste0("Cell", seq_len(12L))
    ),
    sparse = TRUE
  )
  metadata <- data.frame(
    donor = rep(c("D1", "D2", "D3"), each = 4L),
    condition = rep(rep(c("ctrl", "stim"), each = 2L), 3L),
    cell_type = rep("Mono", 12L),
    qc_status = rep("pass", 12L),
    row.names = colnames(counts),
    stringsAsFactors = FALSE
  )
  SeuratObject::CreateSeuratObject(counts = counts, meta.data = metadata, assay = "RNA")
}

test_that("Seurat bridge extracts raw RNA counts without full Seurat", {
  object <- make_seurat_fixture()
  extracted <- omix_seurat_extract(object, assay = "RNA", layer = "counts")

  expect_s3_class(extracted, "omix_seurat_cells")
  expect_s4_class(extracted$counts, "dgCMatrix")
  expect_identical(rownames(extracted$metadata), colnames(extracted$counts))
  expect_equal(extracted$provenance$assay, "RNA")
  expect_false("Seurat" %in% loadedNamespaces())
})

test_that("Seurat bridge creates aligned donor-by-condition pseudobulk input", {
  object <- make_seurat_fixture()
  input <- omix_seurat_to_input(
    object,
    donor_column = "donor",
    group_column = "condition",
    cell_type_column = "cell_type",
    cell_type = "Mono",
    cell_filter_column = "qc_status",
    cell_filter_values = "pass",
    min_cells = 2L
  )

  expect_s3_class(input, "omix_standard_input")
  expect_equal(input$sample_columns, c("D1__ctrl", "D1__stim", "D2__ctrl", "D2__stim", "D3__ctrl", "D3__stim"))
  expect_equal(input$metadata$Cells, rep(2L, 6L))
  expect_equal(input$counts$D1__ctrl, c(30, 33, 40))
  expect_equal(input$provenance$aggregation, "sum_by_donor_and_group")
  expect_equal(input$provenance$cell_filter_values, "pass")
})

test_that("Seurat bridge reports under-populated donor-by-group profiles", {
  object <- make_seurat_fixture()
  expect_error(
    omix_seurat_to_input(
      object,
      donor_column = "donor",
      group_column = "condition",
      cell_type_column = "cell_type",
      cell_type = "Mono",
      min_cells = 3L
    ),
    "fewer than 3 cells"
  )
})

test_that("Seurat bridge reads serialized objects", {
  path <- tempfile(fileext = ".rds")
  saveRDS(make_seurat_fixture(), path)
  input <- omix_read_seurat_rds(
    path,
    donor_column = "donor",
    group_column = "condition",
    cell_type_column = "cell_type",
    cell_type = "Mono",
    min_cells = 2L
  )

  expect_s3_class(input, "omix_standard_input")
  expect_equal(ncol(input$counts), 7L)
})
