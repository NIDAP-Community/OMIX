#!/usr/bin/env Rscript

# This deliberately creates a small object at test time instead of committing a
# serialized study object. It verifies that the full-Seurat compatibility
# runtime can deserialize an SCTAssay object and convert each supported
# expression representation to the portable OMIX handoff.
set.seed(20260923)

# The same legacy conversion fixture validates both a source-built candidate
# and a published immutable image.  The calling workflow must therefore state
# the bridge version it expects for the exact image under test rather than
# assuming the current checkout's bridge version.
expected_omix_seurat_version <- Sys.getenv("OMIX_EXPECTED_OMIX_SEURAT_VERSION", unset = "")
if (!nzchar(expected_omix_seurat_version)) {
  stop(
    "Set OMIX_EXPECTED_OMIX_SEURAT_VERSION to the exact image's OmixSeurat version.",
    call. = FALSE
  )
}
observed_omix_seurat_version <- as.character(utils::packageVersion("OmixSeurat"))
if (!identical(observed_omix_seurat_version, expected_omix_seurat_version)) {
  stop(
    "Expected OmixSeurat ", expected_omix_seurat_version,
    " but image contains ", observed_omix_seurat_version, ".",
    call. = FALSE
  )
}

feature_ids <- paste0("Gene", seq_len(120L))
cell_ids <- paste0("Cell", seq_len(12L))
counts <- Matrix::Matrix(
  matrix(
    stats::rpois(length(feature_ids) * length(cell_ids), lambda = 6L),
    nrow = length(feature_ids),
    dimnames = list(feature_ids, cell_ids)
  ),
  sparse = TRUE
)
metadata <- data.frame(
  donor = rep(c("D1", "D2", "D3"), each = 4L),
  condition = rep(rep(c("ctrl", "stim"), each = 2L), 3L),
  cell_type = "Mono",
  row.names = cell_ids,
  stringsAsFactors = FALSE
)

seurat_object <- SeuratObject::CreateSeuratObject(
  counts = counts,
  meta.data = metadata,
  assay = "RNA"
)
harmony_expression <- log2(as.matrix(counts) + 1)
harmony_assay <- SeuratObject::CreateAssayObject(counts = counts)
methods::slot(harmony_assay, "data") <- Matrix::Matrix(
  harmony_expression,
  sparse = TRUE
)
seurat_object[["Harmony"]] <- harmony_assay
stopifnot(
  inherits(seurat_object[["Harmony"]], "Assay"),
  "data" %in% methods::slotNames(seurat_object[["Harmony"]])
)
seurat_object <- Seurat::SCTransform(
  object = seurat_object,
  assay = "RNA",
  new.assay.name = "SCT",
  vst.flavor = "v1",
  variable.features.n = 50L,
  return.only.var.genes = FALSE,
  verbose = FALSE
)
stopifnot(inherits(seurat_object[["SCT"]], "SCTAssay"))

rds_path <- tempfile(fileext = ".rds")
saveRDS(seurat_object, rds_path)
on.exit(unlink(rds_path), add = TRUE)

common_arguments <- list(
  donor_column = "donor",
  group_column = "condition",
  cell_type_column = "cell_type",
  cell_type = "Mono",
  min_cells = 2L
)

raw_input <- do.call(
  OmixSeurat::omix_read_seurat_rds,
  c(list(path = rds_path, assay = "RNA", layer = "counts"), common_arguments)
)
expected_profiles <- c("D1__ctrl", "D1__stim", "D2__ctrl", "D2__stim", "D3__ctrl", "D3__stim")
stopifnot(
  inherits(raw_input, "omix_standard_input"),
  identical(raw_input$sample_columns, expected_profiles),
  identical(raw_input$metadata$Cells, rep(2L, length(expected_profiles))),
  isTRUE(all.equal(
    unname(raw_input$counts$D1__ctrl),
    unname(as.numeric(Matrix::rowSums(counts[, c("Cell1", "Cell2"), drop = FALSE])))
  ))
)

harmony_input <- do.call(
  OmixSeurat::omix_read_seurat_expression_rds,
  c(
    list(path = rds_path, assay = "Harmony", layer = "data"),
    common_arguments
  )
)
stopifnot(
  inherits(harmony_input, "omix_expression_input"),
  identical(harmony_input$provenance$source_matrix_type, "continuous_gene_expression"),
  isTRUE(all.equal(
    unname(harmony_input$expression$D1__ctrl),
    unname(rowMeans(harmony_expression[, c("Cell1", "Cell2"), drop = FALSE]))
  ))
)

sct_data <- SeuratObject::LayerData(seurat_object, assay = "SCT", layer = "data")
sct_input <- do.call(
  OmixSeurat::omix_read_seurat_expression_rds,
  c(list(path = rds_path, assay = "SCT", layer = "data"), common_arguments)
)
stopifnot(
  inherits(sct_input, "omix_expression_input"),
  inherits(readRDS(rds_path)[["SCT"]], "SCTAssay"),
  isTRUE(all.equal(
    unname(sct_input$expression$D1__ctrl),
    unname(rowMeans(as.matrix(sct_data[, c("Cell1", "Cell2"), drop = FALSE])))
  ))
)

message("Synthetic serialized Seurat conversion smoke test passed.")
