.make_moobject_fixture <- function(nested_expression = FALSE) {
  metadata <- data.frame(
    Sample = c("A1", "B1"),
    Group = c("A", "B"),
    stringsAsFactors = FALSE
  )
  raw <- data.frame(
    feature_id = c("gene_1", "gene_2"),
    A1 = c(10L, 20L),
    B1 = c(30L, 40L),
    check.names = FALSE
  )
  normalized <- data.frame(
    feature_id = c("gene_1", "gene_2"),
    A1 = c(-0.25, 1.5),
    B1 = c(0.75, 2.25),
    check.names = FALSE
  )
  annotation <- data.frame(
    feature_id = c("gene_1", "gene_2"),
    GeneName = c("GeneA", "GeneB"),
    stringsAsFactors = FALSE
  )
  normalized_layer <- if (nested_expression) list(voom = normalized) else normalized

  MOObject::multiOmicDataSet(
    sample_metadata = metadata,
    anno_dat = annotation,
    counts_lst = list(raw = raw, norm = normalized_layer)
  )
}

test_that("MOObject count bridge returns an aligned portable standard input", {
  moo <- .make_moobject_fixture()

  input <- omix_mosuite_to_input(
    moo,
    count_type = "raw",
    annotation_columns = "GeneName"
  )

  expect_s3_class(input, "omix_standard_input")
  expect_equal(names(input$counts), c("feature_id", "GeneName", "A1", "B1"))
  expect_equal(input$metadata$Sample, c("A1", "B1"))
  expect_equal(input$provenance$bridge, "OmixMOSuite")
  expect_equal(input$provenance$source_package, "MOObject")
  expect_equal(input$provenance$handoff_type, "counts")
})

test_that("continuous MOObject layers use the expression handoff", {
  moo <- .make_moobject_fixture()

  input <- omix_mosuite_to_expression_input(
    moo,
    count_type = "norm",
    expression_scale = "batch_corrected_log2",
    annotation_columns = "GeneName"
  )

  expect_s3_class(input, "omix_expression_input")
  expect_equal(names(input$expression), c("feature_id", "GeneName", "A1", "B1"))
  expect_equal(input$expression$A1, c(-0.25, 1.5))
  expect_equal(input$metadata$Sample, c("A1", "B1"))
  expect_equal(input$provenance$handoff_type, "continuous_expression")
  expect_equal(input$provenance$expression_scale, "batch_corrected_log2")
})

test_that("nested continuous layers can be selected explicitly", {
  moo <- .make_moobject_fixture(nested_expression = TRUE)

  input <- omix_mosuite_to_expression_input(
    moo,
    count_type = "norm",
    sub_count_type = "voom",
    expression_scale = "log2_cpm"
  )

  expect_equal(input$provenance$sub_count_type, "voom")
  expect_equal(input$expression$B1, c(0.75, 2.25))
})

test_that("count handoff rejects normalized values", {
  moo <- .make_moobject_fixture()

  expect_error(
    omix_mosuite_to_input(moo, count_type = "norm"),
    "non-negative integer-like"
  )
})

test_that("bridge rejects invalid objects and missing scale provenance", {
  expect_error(
    omix_mosuite_to_input(list()),
    "MOObject::multiOmicDataSet"
  )
  expect_error(
    omix_mosuite_to_expression_input(
      .make_moobject_fixture(),
      count_type = "norm"
    ),
    "expression_scale"
  )
})

test_that("MOObject bridge can read a serialized current MOO", {
  moo <- .make_moobject_fixture()
  path <- tempfile(fileext = ".rds")
  MOObject::write_multiOmicDataSet(moo, path)

  count_input <- omix_read_mosuite_rds(path)
  expression_input <- omix_read_mosuite_expression_rds(
    path,
    count_type = "norm",
    expression_scale = "log2"
  )

  expect_equal(names(count_input$counts), c("feature_id", "A1", "B1"))
  expect_equal(expression_input$expression$A1, c(-0.25, 1.5))
})

test_that("serialized legacy class labels are delegated to MOObject coercion", {
  moo <- .make_moobject_fixture()
  class(moo) <- c("MOSuite::multiOmicDataSet", "S7_object")
  path <- tempfile(fileext = ".rds")
  saveRDS(moo, path)

  input <- omix_read_mosuite_rds(path)

  expect_s3_class(input, "omix_standard_input")
  expect_equal(input$metadata$Sample, c("A1", "B1"))
})
