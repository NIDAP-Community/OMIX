#!/usr/bin/env Rscript

# This runtime compatibility smoke test exercises the Pseudobulk collection
# source against the exact OmixSeurat package installed in the candidate image.
# It deliberately creates a synthetic object at run time and never stores a
# serialized Seurat object or study data in the repository.

arguments <- commandArgs(trailingOnly = TRUE)
if (length(arguments) != 2L || !identical(arguments[[1L]], "--module_root")) {
  stop(
    "Usage: test-pseudobulk-collection-candidate.R --module_root PATH",
    call. = FALSE
  )
}
module_root <- normalizePath(arguments[[2L]], mustWork = TRUE)
module_source <- file.path(module_root, "R", "Seurat_Pseudobulk.R")
if (!file.exists(module_source)) {
  stop("Pseudobulk module source is missing: ", module_source, call. = FALSE)
}

required_packages <- c("Matrix", "SeuratObject", "OmixSeurat")
missing_packages <- required_packages[
  !vapply(required_packages, requireNamespace, logical(1), quietly = TRUE)
]
if (length(missing_packages) > 0L) {
  stop(
    "Candidate collection fixture requires: ",
    paste(missing_packages, collapse = ", "),
    call. = FALSE
  )
}
stopifnot(identical(as.character(utils::packageVersion("OmixSeurat")), "0.4.0"))
source(module_source)

set.seed(20261022)
feature_ids <- paste0("Gene", seq_len(120L))
donors <- paste0("D", seq_len(3L))
groups <- c("ctrl", "stim")
cell_types <- c("CD4 T cells", "Monocytes")
profile_metadata <- expand.grid(
  donor = donors,
  condition = groups,
  cell_type = cell_types,
  KEEP.OUT.ATTRS = FALSE,
  stringsAsFactors = FALSE
)
metadata <- profile_metadata[rep(seq_len(nrow(profile_metadata)), each = 2L), , drop = FALSE]
cell_ids <- paste0("Cell", seq_len(nrow(metadata)))
row.names(metadata) <- cell_ids
counts <- Matrix::Matrix(
  matrix(
    stats::rpois(length(feature_ids) * length(cell_ids), lambda = 6L),
    nrow = length(feature_ids),
    dimnames = list(feature_ids, cell_ids)
  ),
  sparse = TRUE
)
seurat_object <- SeuratObject::CreateSeuratObject(
  counts = counts,
  meta.data = metadata,
  assay = "RNA"
)
rds_path <- tempfile(fileext = ".rds")
saveRDS(seurat_object, rds_path)
on.exit(unlink(rds_path), add = TRUE)

selection_path <- tempfile(fileext = ".csv")
utils::write.csv(
  data.frame(CellType = c("Monocytes", "CD4 T cells"), check.names = FALSE),
  selection_path,
  row.names = FALSE,
  quote = TRUE
)
on.exit(unlink(selection_path), add = TRUE)

run_collection <- function(mode, output_dir, selection = NULL) {
  omix_seurat_pseudobulk_collection(
    seurat_rds = rds_path,
    donor_column = "donor",
    group_column = "condition",
    cell_type_column = "cell_type",
    cell_type_mode = mode,
    cell_type_selection = selection,
    aggregation_method = "sum_counts",
    min_cells = 2L,
    output_dir = output_dir
  )
}

selected_result <- run_collection(
  mode = "selected",
  output_dir = tempfile("omix-selected-cell-types-"),
  selection = selection_path
)
on.exit(unlink(dirname(selected_result$catalog_path), recursive = TRUE), add = TRUE)
stopifnot(identical(
  selected_result$selected_cell_types,
  c("Monocytes", "CD4 T cells")
))
selected_catalog <- utils::read.csv(selected_result$catalog_path, check.names = FALSE)
stopifnot(
  identical(unique(as.character(selected_catalog$CellType)), selected_result$selected_cell_types),
  nrow(selected_catalog) == 12L,
  all(selected_catalog$Cells == 2L),
  all(selected_catalog$ProfileEligibility == "eligible"),
  all(file.exists(file.path(dirname(selected_result$catalog_path), selected_catalog$MatrixPath))),
  all(file.exists(file.path(dirname(selected_result$catalog_path), selected_catalog$MetadataPath)))
)
selected_manifest <- base::read.dcf(selected_result$collection_manifest_path)
stopifnot(
  identical(unname(selected_manifest[1L, "cell_type_selection_mode"]), "selected"),
  identical(unname(selected_manifest[1L, "selected_cell_type_count"]), "2")
)

all_result <- run_collection(
  mode = "all",
  output_dir = tempfile("omix-all-cell-types-")
)
on.exit(unlink(dirname(all_result$catalog_path), recursive = TRUE), add = TRUE)
stopifnot(identical(
  all_result$selected_cell_types,
  c("CD4 T cells", "Monocytes")
))
all_catalog <- utils::read.csv(all_result$catalog_path, check.names = FALSE)
stopifnot(
  identical(unique(as.character(all_catalog$CellType)), all_result$selected_cell_types),
  nrow(all_catalog) == 12L,
  all(all_catalog$Cells == 2L),
  all(all_catalog$ProfileEligibility == "eligible")
)
all_manifest <- base::read.dcf(all_result$collection_manifest_path)
stopifnot(
  identical(unname(all_manifest[1L, "cell_type_selection_mode"]), "all"),
  identical(unname(all_manifest[1L, "selected_cell_type_count"]), "2")
)

message(
  "Synthetic Pseudobulk collection compatibility fixture passed ",
  "(selected order: Monocytes, CD4 T cells; ",
  "all order: CD4 T cells, Monocytes; 2 cells/profile; exact assertions)."
)
