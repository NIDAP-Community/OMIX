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
cell_categories <- c("CD4 T cells", "Monocytes")
profile_metadata <- expand.grid(
  donor = donors,
  condition = groups,
  cell_category = cell_categories,
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
  data.frame(CellCategory = c("Monocytes", "CD4 T cells"), check.names = FALSE),
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
    cell_category_column = "cell_category",
    cell_category_mode = mode,
    cell_category_selection = selection,
    aggregation_method = "sum_counts",
    min_cells = 2L,
    output_dir = output_dir
  )
}

selected_result <- run_collection(
  mode = "selected",
  output_dir = tempfile("omix-selected-cell-categories-"),
  selection = selection_path
)
on.exit(unlink(dirname(selected_result$catalog_path), recursive = TRUE), add = TRUE)
stopifnot(identical(
  selected_result$selected_cell_categories,
  c("Monocytes", "CD4 T cells")
))
selected_catalog <- utils::read.csv(selected_result$catalog_path, check.names = FALSE)
stopifnot(
  identical(unique(as.character(selected_catalog$CellCategory)), selected_result$selected_cell_categories),
  nrow(selected_catalog) == 12L,
  all(selected_catalog$Cells == 2L),
  all(selected_catalog$ProfileEligibility == "eligible"),
  all(file.exists(file.path(dirname(selected_result$catalog_path), selected_catalog$MatrixPath))),
  all(file.exists(file.path(dirname(selected_result$catalog_path), selected_catalog$MetadataPath)))
)
selected_manifest <- base::read.dcf(selected_result$collection_manifest_path)
stopifnot(
  identical(unname(selected_manifest[1L, "cell_category_selection_mode"]), "selected"),
  identical(unname(selected_manifest[1L, "selected_cell_category_count"]), "2")
)

all_result <- run_collection(
  mode = "all",
  output_dir = tempfile("omix-all-cell-categories-")
)
on.exit(unlink(dirname(all_result$catalog_path), recursive = TRUE), add = TRUE)
stopifnot(identical(
  all_result$selected_cell_categories,
  c("CD4 T cells", "Monocytes")
))
all_catalog <- utils::read.csv(all_result$catalog_path, check.names = FALSE)
stopifnot(
  identical(unique(as.character(all_catalog$CellCategory)), all_result$selected_cell_categories),
  nrow(all_catalog) == 12L,
  all(all_catalog$Cells == 2L),
  all(all_catalog$ProfileEligibility == "eligible")
)
all_manifest <- base::read.dcf(all_result$collection_manifest_path)
stopifnot(
  identical(unname(all_manifest[1L, "cell_category_selection_mode"]), "all"),
  identical(unname(all_manifest[1L, "selected_cell_category_count"]), "2")
)

# Drop mode must keep a category with two eligible groups while recording a
# category that retains exactly one group after sparse-profile exclusion.
drop_metadata <- do.call(rbind, lapply(donors, function(donor) {
  data.frame(
    donor = donor,
    condition = c(rep("ctrl", 4L), rep("stim", 3L)),
    cell_category = c(
      "B cells", "B cells", "Monocytes", "Monocytes",
      "B cells", "Monocytes", "Monocytes"
    ),
    stringsAsFactors = FALSE
  )
}))
row.names(drop_metadata) <- paste0("DropCell", seq_len(nrow(drop_metadata)))
drop_counts <- Matrix::Matrix(
  matrix(
    stats::rpois(length(feature_ids) * nrow(drop_metadata), lambda = 6L),
    nrow = length(feature_ids),
    dimnames = list(feature_ids, row.names(drop_metadata))
  ),
  sparse = TRUE
)
drop_object <- SeuratObject::CreateSeuratObject(
  counts = drop_counts,
  meta.data = drop_metadata,
  assay = "RNA"
)
drop_rds_path <- tempfile(fileext = ".rds")
saveRDS(drop_object, drop_rds_path)
on.exit(unlink(drop_rds_path), add = TRUE)
drop_result <- omix_seurat_pseudobulk_collection(
  seurat_rds = drop_rds_path,
  donor_column = "donor",
  group_column = "condition",
  cell_category_column = "cell_category",
  cell_category_mode = "all",
  aggregation_method = "sum_counts",
  min_cells = 2L,
  on_insufficient_cells = "drop",
  output_dir = tempfile("omix-drop-cell-categories-")
)
on.exit(unlink(dirname(drop_result$catalog_path), recursive = TRUE), add = TRUE)
drop_catalog <- utils::read.csv(drop_result$catalog_path, check.names = FALSE)
drop_summary <- readLines(drop_result$run_summary_path)
stopifnot(
  identical(drop_result$written_cell_categories, "Monocytes"),
  identical(drop_result$dropped_cell_categories, "B cells"),
  all(drop_catalog$CellCategoryEligibility[drop_catalog$CellCategory == "B cells"] == "dropped_fewer_than_two_groups"),
  identical(
    unique(drop_catalog$Group[
      drop_catalog$CellCategory == "B cells" &
        drop_catalog$ProfileEligibility == "eligible"
    ]),
    "ctrl"
  ),
  any(grepl("B cells \\(eligible groups: ctrl\\)", drop_summary))
)

message(
  "Synthetic Pseudobulk collection compatibility fixture passed ",
  "(selected order: Monocytes, CD4 T cells; ",
  "all order: CD4 T cells, Monocytes; drop mode retains Monocytes and records B cells with ctrl only; exact assertions)."
)
