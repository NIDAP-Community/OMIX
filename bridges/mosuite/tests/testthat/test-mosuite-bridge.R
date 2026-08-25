test_that("MOSuite bridge returns an aligned portable standard input", {
  metadata <- data.frame(
    Sample = c("A1", "B1"),
    Group = c("A", "B"),
    stringsAsFactors = FALSE
  )
  count_table <- data.frame(
    feature_id = c("gene_1", "gene_2"),
    GeneName = c("GeneA", "GeneB"),
    A1 = c(10L, 20L),
    B1 = c(30L, 40L),
    check.names = FALSE
  )
  moo <- MOSuite::create_multiOmicDataSet_from_dataframes(
    sample_metadata = metadata,
    counts_dat = count_table,
    sample_id_colname = "Sample",
    feature_id_colname = "feature_id"
  )

  input <- omix_mosuite_to_input(
    moo,
    count_type = "raw",
    annotation_columns = "GeneName"
  )

  expect_s3_class(input, "omix_standard_input")
  expect_equal(names(input$counts), c("feature_id", "GeneName", "A1", "B1"))
  expect_equal(input$metadata$Sample, c("A1", "B1"))
  expect_equal(input$provenance$bridge, "OmixMOSuite")
})

test_that("MOSuite bridge can read a serialized MOO", {
  metadata <- data.frame(Sample = c("A1", "B1"), Group = c("A", "B"))
  count_table <- data.frame(feature_id = "gene_1", A1 = 10L, B1 = 30L, check.names = FALSE)
  moo <- MOSuite::create_multiOmicDataSet_from_dataframes(metadata, count_table)
  path <- tempfile(fileext = ".rds")
  saveRDS(moo, path)

  input <- omix_read_mosuite_rds(path)

  expect_equal(names(input$counts), c("feature_id", "A1", "B1"))
  expect_equal(input$metadata$Sample, c("A1", "B1"))
})
