#!/usr/bin/env Rscript

test_args <- commandArgs(FALSE)
test_file <- sub("^--file=", "", test_args[grepl("^--file=", test_args)])
module_dir <- normalizePath(file.path(dirname(test_file), ".."))
source(file.path(module_dir, "R", "OMIX_Limma_Analysis.R"))

write_manifest <- function(path) {
  base::write.dcf(data.frame(
    matrix_type = "sctransform_mean_log2_expression",
    expected_downstream_module = "OMIX-Limma-Analysis",
    expected_downstream_mode = "continuous_expression",
    downstream_input_kind = "log2_expression",
    recommended_variance_model = "ebayes_trend",
    stringsAsFactors = FALSE
  ), path)
}

make_collection <- function(root, second_genes = c("Gene1", "Gene2", "Gene3"), f_profiles = 3L) {
  dir.create(root, recursive = TRUE, showWarnings = FALSE)
  ids <- c("ct-t-cells-11111111111111111111111111111111", "ct-monocytes-22222222222222222222222222222222")
  labels <- c("T cells", "Monocytes")
  catalog_rows <- list()
  for (index in seq_along(ids)) {
    id <- ids[[index]]
    bundle_dir <- file.path(root, "cell_types", id)
    dir.create(bundle_dir, recursive = TRUE, showWarnings = FALSE)
    genes <- if (index == 1L) c("Gene1", "Gene2", "Gene3") else second_genes
    samples <- c(paste0("M", seq_len(3L)), paste0("F", seq_len(f_profiles)))
    matrix <- data.frame(
      GeneName = genes,
      setNames(lapply(seq_along(samples), function(sample_index) {
        # Cell-type-specific values retain the same ordered gene universe while
        # giving both comparisons a finite, non-zero M-F effect.
        c(5, 6, 7) + (sample_index <= 3L) * (index / 3)
      }), samples),
      check.names = FALSE
    )
    metadata <- data.frame(
      Sample = samples,
      Donor = samples,
      Group = c(rep("M", 3L), rep("F", f_profiles)),
      CellType = labels[[index]],
      Cells = 40L,
      stringsAsFactors = FALSE,
      check.names = FALSE
    )
    utils::write.csv(matrix, file.path(bundle_dir, "SCT_Mean_Log2_Expression.csv"), row.names = FALSE)
    utils::write.csv(metadata, file.path(bundle_dir, "Pseudobulk_Sample_Metadata.csv"), row.names = FALSE)
    write_manifest(file.path(bundle_dir, "Pseudobulk_Manifest.dcf"))
    catalog_rows[[index]] <- data.frame(
      CellTypeID = id,
      CellType = labels[[index]],
      SelectionMode = "selected",
      Donor = metadata$Donor,
      Group = metadata$Group,
      Cells = metadata$Cells,
      MinCells = 20L,
      ProfileEligibility = "eligible",
      MatrixPath = file.path("cell_types", id, "SCT_Mean_Log2_Expression.csv"),
      MetadataPath = file.path("cell_types", id, "Pseudobulk_Sample_Metadata.csv"),
      BundleManifestPath = file.path("cell_types", id, "Pseudobulk_Manifest.dcf"),
      AggregationMethod = "mean_sctransform_expression",
      SourceAssay = "SCT",
      SourceLayer = "data",
      SourceSeuratRds = "/not-a-real-study-object.rds",
      stringsAsFactors = FALSE,
      check.names = FALSE
    )
  }
  catalog <- do.call(rbind, catalog_rows)
  utils::write.csv(catalog, file.path(root, "Cell_Type_Profile_Catalog.csv"), row.names = FALSE)
  base::write.dcf(data.frame(
    format_version = "1",
    collection_kind = "cell_type_pseudobulk",
    cell_type_selection_mode = "selected",
    selected_cell_type_count = "2",
    aggregation_method = "mean_sctransform_expression",
    source_assay = "SCT",
    source_layer = "data",
    source_seurat_rds = "/not-a-real-study-object.rds",
    min_cells = "20",
    on_insufficient_cells = "error",
    profile_catalog = "Cell_Type_Profile_Catalog.csv",
    stringsAsFactors = FALSE
  ), file.path(root, "Pseudobulk_Collection_Manifest.dcf"))
  invisible(catalog)
}

work_dir <- tempfile("omix-limma-cell-type-collection-")
dir.create(work_dir)
collection_root <- file.path(work_dir, "collection")
make_collection(collection_root)
manifest_path <- file.path(collection_root, "Pseudobulk_Collection_Manifest.dcf")
output_dir <- file.path(work_dir, "result")

# The direct function is the scientific contract; its output must preserve the
# selected-cell-type order and the exact suffixes L2P Multi resolves by default.
result <- omix_limma_cell_type_collection(manifest_path, output_dir)
expected_comparisons <- c(
  "ct-t-cells-11111111111111111111111111111111__M-F",
  "ct-monocytes-22222222222222222222222222222222__M-F"
)
stopifnot(identical(result$comparisons, expected_comparisons))
wide <- utils::read.csv(result$l2p_multi_input, check.names = FALSE, stringsAsFactors = FALSE)
expected_columns <- c("GeneName", unlist(lapply(expected_comparisons, function(comparison) {
  paste0(comparison, c("_tstat", "_pval", "_FC"))
}), use.names = FALSE))
stopifnot(identical(names(wide), expected_columns))
stopifnot(identical(wide$GeneName, c("Gene1", "Gene2", "Gene3")))

# This direct shape validation encodes the public L2P Multi conventional input
# contract: a GeneName column and one tstat/pval/FC family per ordered label.
.omix_limma_collection_validate_l2p_multi_shape(wide, expected_comparisons)
provenance <- utils::read.csv(result$provenance, check.names = FALSE, stringsAsFactors = FALSE)
stopifnot(identical(provenance$Comparison, expected_comparisons))
stopifnot(all(c(
  "CellTypeID", "CellType", "SelectionMode", "SourceMatrixPath", "SourceMatrixSHA256",
  "SourceBundleManifestPath", "SourceLimmaAnalysisPath", "InputDataType", "VarianceModel",
  "ModelType", "MProfiles", "FProfiles", "TestedGeneCount", "SourceLimmaAnalysisSHA256"
) %in% names(provenance)))
catalog_output <- utils::read.csv(result$catalog, check.names = FALSE, stringsAsFactors = FALSE)
stopifnot(all(c("ProfileEligibility", "LimmaAnalysisPath", "L2PComparison") %in% names(catalog_output)))
stopifnot(file.exists(file.path(output_dir, "cell_types", provenance$CellTypeID[[1L]], "Limma_Analysis.csv")))

# Exercise the portable explicit-path CLI separately from the direct function.
cli_output_dir <- file.path(work_dir, "cli-result")
cli_output <- system2(
  file.path(R.home("bin"), "Rscript"),
  c(
    file.path(module_dir, "scripts", "run_limma_cell_type_collection.R"),
    "--pseudobulk_collection_manifest", manifest_path,
    "--contrast", "M-F",
    "--output_dir", cli_output_dir
  ),
  stdout = TRUE,
  stderr = TRUE
)
stopifnot(is.null(attr(cli_output, "status")))
stopifnot(file.exists(file.path(cli_output_dir, "L2P_Multi_Input.csv")))

expect_error <- function(expression, pattern) {
  error <- tryCatch(force(expression), error = identity)
  stopifnot(inherits(error, "error"))
  stopifnot(grepl(pattern, conditionMessage(error), fixed = TRUE))
}

# Invalid collection routing is rejected before any analysis is written.
missing_catalog_root <- file.path(work_dir, "missing-catalog")
make_collection(missing_catalog_root)
missing_manifest <- file.path(missing_catalog_root, "Pseudobulk_Collection_Manifest.dcf")
manifest <- base::read.dcf(missing_manifest)
manifest[1L, "profile_catalog"] <- "not-present.csv"
base::write.dcf(manifest, missing_manifest)
expect_error(
  omix_limma_cell_type_collection(missing_manifest, file.path(work_dir, "missing-catalog-output")),
  "profile_catalog was not found"
)

duplicate_root <- file.path(work_dir, "duplicate-catalog")
catalog <- make_collection(duplicate_root)
utils::write.csv(rbind(catalog, catalog[1L, , drop = FALSE]), file.path(duplicate_root, "Cell_Type_Profile_Catalog.csv"), row.names = FALSE)
expect_error(
  omix_limma_cell_type_collection(file.path(duplicate_root, "Pseudobulk_Collection_Manifest.dcf"), file.path(work_dir, "duplicate-output")),
  "duplicate CellTypeID/Donor/Group"
)

missing_source_root <- file.path(work_dir, "missing-source")
catalog <- make_collection(missing_source_root)
catalog$MatrixPath[catalog$CellTypeID == catalog$CellTypeID[[1L]]] <- "cell_types/missing/SCT_Mean_Log2_Expression.csv"
utils::write.csv(catalog, file.path(missing_source_root, "Cell_Type_Profile_Catalog.csv"), row.names = FALSE)
expect_error(
  omix_limma_cell_type_collection(file.path(missing_source_root, "Pseudobulk_Collection_Manifest.dcf"), file.path(work_dir, "missing-source-output")),
  "MatrixPath was not found"
)

insufficient_root <- file.path(work_dir, "insufficient")
make_collection(insufficient_root, f_profiles = 1L)
expect_error(
  omix_limma_cell_type_collection(file.path(insufficient_root, "Pseudobulk_Collection_Manifest.dcf"), file.path(work_dir, "insufficient-output")),
  "requires at least two donor-level profiles"
)

mismatch_root <- file.path(work_dir, "feature-mismatch")
make_collection(mismatch_root, second_genes = c("Gene1", "GeneX", "Gene3"))
expect_error(
  omix_limma_cell_type_collection(file.path(mismatch_root, "Pseudobulk_Collection_Manifest.dcf"), file.path(work_dir, "mismatch-output")),
  "exact same ordered tested-gene universe"
)

nonfinite <- wide
nonfinite[[expected_columns[[2L]]]][[1L]] <- NA_real_
expect_error(
  .omix_limma_collection_validate_l2p_multi_shape(nonfinite, expected_comparisons),
  "non-finite numeric values"
)

message("OMIX-Limma-Analysis cell-type collection checks passed")
