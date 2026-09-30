#!/usr/bin/env Rscript

test_args <- commandArgs(FALSE)
test_file <- sub("^--file=", "", test_args[grepl("^--file=", test_args)])
module_dir <- normalizePath(file.path(dirname(test_file), ".."))
source(file.path(module_dir, "R", "L2P_Analysis.R"))

threshold_columns <- c(
  "GeneName", "B-A_pval", "B-A_FC", "B-A_tstat", "B-A_adjpval"
)
stopifnot(identical(
  detect_l2p_comparisons(threshold_columns, select_by_rank = FALSE),
  "B-A"
))
stopifnot(identical(
  resolve_l2p_comparisons(
    column_names = threshold_columns,
    select_by_rank = FALSE
  ),
  "B-A"
))

rank_columns <- c("GeneName", "Treatment-Control_tstat")
stopifnot(identical(
  detect_l2p_comparisons(rank_columns, select_by_rank = TRUE),
  "Treatment-Control"
))

explicit_order <- resolve_l2p_comparisons(
  comparisons = "B-A,C-A,C-B",
  column_names = threshold_columns
)
stopifnot(identical(explicit_order, c("B-A", "C-A", "C-B")))
stopifnot(identical(
  resolve_l2p_comparisons(
    comparison = "C-A",
    column_names = threshold_columns
  ),
  "C-A"
))

ambiguous_columns <- c(
  threshold_columns,
  "C-A_pval", "C-A_FC", "C-A_tstat"
)
ambiguous_error <- tryCatch(
  {
    resolve_l2p_comparisons(column_names = ambiguous_columns)
    NULL
  },
  error = identity
)
stopifnot(
  inherits(ambiguous_error, "error"),
  grepl("Multiple comparison prefixes were detected: B-A, C-A", conditionMessage(ambiguous_error), fixed = TRUE),
  grepl("--comparison", conditionMessage(ambiguous_error), fixed = TRUE)
)

missing_error <- tryCatch(
  {
    resolve_l2p_comparisons(column_names = c("GeneName", "pval", "FC"))
    NULL
  },
  error = identity
)
stopifnot(
  inherits(missing_error, "error"),
  grepl("No comparison was supplied", conditionMessage(missing_error), fixed = TRUE)
)

duplicate_error <- tryCatch(
  {
    resolve_l2p_comparisons(
      comparisons = "B-A,B-A",
      column_names = threshold_columns
    )
    NULL
  },
  error = identity
)
stopifnot(
  inherits(duplicate_error, "error"),
  grepl("must be unique", conditionMessage(duplicate_error), fixed = TRUE)
)

message("OMIX-L2P-Single comparison resolution checks passed")
