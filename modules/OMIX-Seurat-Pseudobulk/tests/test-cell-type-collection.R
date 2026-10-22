#!/usr/bin/env Rscript

script_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
if (length(script_arg) != 1L) {
  stop("Run this test with Rscript tests/test-cell-type-collection.R")
}
module_root <- normalizePath(file.path(dirname(sub("^--file=", "", script_arg)), ".."))
source(file.path(module_root, "R", "Seurat_Pseudobulk.R"))

selection_path <- tempfile(fileext = ".csv")
utils::write.csv(
  data.frame(CellType = c("CD4 T cells", "CD14+ Monocytes"), check.names = FALSE),
  selection_path,
  row.names = FALSE,
  quote = TRUE
)
stopifnot(identical(
  .omix_read_cell_type_selection(selection_path),
  c("CD4 T cells", "CD14+ Monocytes")
))

duplicate_path <- tempfile(fileext = ".csv")
utils::write.csv(data.frame(CellType = c("Mono", "Mono")), duplicate_path, row.names = FALSE)
duplicate_error <- tryCatch(.omix_read_cell_type_selection(duplicate_path), error = identity)
stopifnot(inherits(duplicate_error, "error"))
stopifnot(grepl("duplicate", conditionMessage(duplicate_error), ignore.case = TRUE))

invalid_column_path <- tempfile(fileext = ".csv")
utils::write.csv(data.frame(Label = "Mono"), invalid_column_path, row.names = FALSE)
invalid_column_error <- tryCatch(.omix_read_cell_type_selection(invalid_column_path), error = identity)
stopifnot(inherits(invalid_column_error, "error"))
stopifnot(grepl("exactly one column named 'CellType'", conditionMessage(invalid_column_error), fixed = TRUE))

empty_path <- tempfile(fileext = ".csv")
utils::write.csv(data.frame(CellType = ""), empty_path, row.names = FALSE)
empty_error <- tryCatch(.omix_read_cell_type_selection(empty_path), error = identity)
stopifnot(inherits(empty_error, "error"))
stopifnot(grepl("non-empty", conditionMessage(empty_error), fixed = TRUE))

# Different display labels that normalize to the same readable slug still have
# different deterministic IDs because the exact UTF-8 label is hashed.
first_id <- .omix_cell_type_stable_id("CD4 T cells")
second_id <- .omix_cell_type_stable_id("CD4-T-cells")
stopifnot(identical(first_id, .omix_cell_type_stable_id("CD4 T cells")))
stopifnot(!identical(first_id, second_id))
stopifnot(grepl("^ct-cd4-t-cells-[0-9a-f]{32}$", first_id))

message("OMIX-Seurat-Pseudobulk collection helper checks passed")
