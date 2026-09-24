#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 2L) {
  stop(
    "Usage: Rscript validate-real-mosuite-artifacts.R ",
    "<filtered-count-moo.rds> <continuous-expression-moo.rds>",
    call. = FALSE
  )
}

count_path <- normalizePath(args[[1L]], mustWork = TRUE)
expression_path <- normalizePath(args[[2L]], mustWork = TRUE)

required_packages <- c("MOObject", "Omix", "OmixMOSuite", "S7")
missing_packages <- required_packages[
  !vapply(required_packages, requireNamespace, logical(1), quietly = TRUE)
]
if (length(missing_packages) > 0L) {
  stop(
    "Missing required package(s): ",
    paste(missing_packages, collapse = ", "),
    call. = FALSE
  )
}
if (nzchar(system.file(package = "MOSuite"))) {
  stop(
    "This validation must run in a minimal runtime without the full MOSuite package.",
    call. = FALSE
  )
}

assert_identical <- function(actual, expected, label) {
  if (!identical(actual, expected)) {
    stop(label, " did not match the expected value.", call. = FALSE)
  }
}

count_moo <- MOObject::read_multiOmicDataSet(count_path)
if (!S7::S7_inherits(count_moo, MOObject::multiOmicDataSet)) {
  stop("The filtered-count artifact was not coerced to MOObject::multiOmicDataSet.", call. = FALSE)
}
S7::validate(count_moo)

count_input <- OmixMOSuite::omix_read_mosuite_rds(
  count_path,
  count_type = "filt"
)
if (!inherits(count_input, "omix_standard_input")) {
  stop("The filtered-count handoff did not return omix_standard_input.", call. = FALSE)
}
count_values <- unlist(
  count_input$counts[count_input$sample_columns],
  use.names = FALSE
)
if (
  anyNA(count_values) || any(!is.finite(count_values)) ||
  any(count_values < 0) ||
  any(abs(count_values - round(count_values)) > sqrt(.Machine$double.eps))
) {
  stop("The filtered-count handoff is not finite, non-negative, and integer-like.", call. = FALSE)
}
assert_identical(
  as.character(count_input$metadata[[count_input$sample_id_column]]),
  count_input$sample_columns,
  "Filtered-count sample alignment"
)
assert_identical(count_input$provenance$source_package, "MOObject", "Count provenance source")
assert_identical(count_input$provenance$count_type, "filt", "Count provenance layer")
assert_identical(count_input$provenance$handoff_type, "counts", "Count handoff provenance")

expression_moo <- MOObject::read_multiOmicDataSet(expression_path)
if (!S7::S7_inherits(expression_moo, MOObject::multiOmicDataSet)) {
  stop("The expression artifact was not coerced to MOObject::multiOmicDataSet.", call. = FALSE)
}
S7::validate(expression_moo)

expression_input <- OmixMOSuite::omix_read_mosuite_expression_rds(
  expression_path,
  count_type = "batch",
  expression_scale = "batch_corrected_log2"
)
if (!inherits(expression_input, "omix_expression_input")) {
  stop("The continuous handoff did not return omix_expression_input.", call. = FALSE)
}
expression_values <- unlist(
  expression_input$expression[expression_input$sample_columns],
  use.names = FALSE
)
if (anyNA(expression_values) || any(!is.finite(expression_values))) {
  stop("The continuous-expression handoff contains missing or non-finite values.", call. = FALSE)
}
if (!any(abs(expression_values - round(expression_values)) > sqrt(.Machine$double.eps))) {
  stop("The declared continuous-expression fixture did not contain continuous values.", call. = FALSE)
}
assert_identical(
  as.character(expression_input$metadata[[expression_input$sample_id_column]]),
  expression_input$sample_columns,
  "Continuous-expression sample alignment"
)
assert_identical(
  expression_input$provenance$handoff_type,
  "continuous_expression",
  "Expression handoff provenance"
)
assert_identical(
  expression_input$provenance$expression_scale,
  "batch_corrected_log2",
  "Expression scale provenance"
)

rejected_batch_as_counts <- tryCatch(
  {
    OmixMOSuite::omix_read_mosuite_rds(
      expression_path,
      count_type = "batch"
    )
    FALSE
  },
  error = function(error) {
    grepl("non-negative integer-like", conditionMessage(error), fixed = TRUE)
  }
)
if (!isTRUE(rejected_batch_as_counts)) {
  stop("The count handoff did not reject the continuous batch layer.", call. = FALSE)
}

cat("Real MOSuite artifact validation passed.\n")
cat("MOSuite installed: FALSE\n")
cat("MOObject version:", as.character(utils::packageVersion("MOObject")), "\n")
cat("OmixMOSuite version:", as.character(utils::packageVersion("OmixMOSuite")), "\n")
cat(
  "Filtered-count handoff:", nrow(count_input$counts), "features x",
  length(count_input$sample_columns), "samples\n"
)
cat(
  "Continuous-expression handoff:", nrow(expression_input$expression), "features x",
  length(expression_input$sample_columns), "samples\n"
)
