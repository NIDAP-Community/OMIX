test_that("standard input aligns metadata to explicit sample columns", {
  counts <- data.frame(
    feature_id = c("gene_1", "gene_2"),
    GeneName = c("GeneA", "GeneB"),
    B1 = c(30L, 40L),
    A1 = c(10L, 20L),
    check.names = FALSE
  )
  metadata <- data.frame(
    Sample = c("A1", "B1"),
    Group = c("A", "B"),
    stringsAsFactors = FALSE
  )

  input <- new_omix_standard_input(
    counts,
    metadata,
    sample_columns = c("B1", "A1"),
    provenance = list(source = "test")
  )

  expect_s3_class(input, "omix_standard_input")
  expect_equal(input$metadata$Sample, c("B1", "A1"))
  expect_equal(input$sample_columns, c("B1", "A1"))
  expect_equal(input$provenance$source, "test")
})

test_that("standard input rejects mismatched sample IDs", {
  counts <- data.frame(feature_id = "gene_1", A1 = 10L, check.names = FALSE)
  metadata <- data.frame(Sample = "B1")

  expect_error(
    new_omix_standard_input(counts, metadata),
    "different sample IDs"
  )
})
