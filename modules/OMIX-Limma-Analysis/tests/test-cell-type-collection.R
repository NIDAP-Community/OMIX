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

make_collection <- function(
  root,
  second_genes = c("Gene1", "Gene2", "Gene3"),
  group_labels = c("M", "F"),
  profiles_per_group = rep(3L, length(group_labels)),
  omit_first = FALSE
) {
  stopifnot(length(group_labels) == length(profiles_per_group), all(profiles_per_group >= 1L))
  dir.create(root, recursive = TRUE, showWarnings = FALSE)
  ids <- c("ct-t-cells-11111111111111111111111111111111", "ct-monocytes-22222222222222222222222222222222")
  labels <- c("T cells", "Monocytes")
  catalog_rows <- list()
  for (index in seq_along(ids)) {
    id <- ids[[index]]
    bundle_dir <- file.path(root, "cell_categories", id)
    dir.create(bundle_dir, recursive = TRUE, showWarnings = FALSE)
    genes <- if (index == 1L) c("Gene1", "Gene2", "Gene3") else second_genes
    sample_groups <- rep(group_labels, profiles_per_group)
    samples <- unlist(Map(
      function(group, count) paste0("sample_", gsub("[^A-Za-z0-9]", "", group), "_", seq_len(count)),
      group_labels,
      profiles_per_group
    ), use.names = FALSE)
    matrix <- data.frame(
      GeneName = genes,
      setNames(lapply(seq_along(samples), function(sample_index) {
        # Cell-category-specific values retain the same ordered gene universe while
        # giving both comparisons a finite, non-zero M-F effect.
        c(5, 6, 7) + (sample_groups[[sample_index]] == group_labels[[1L]]) * (index / 3)
      }), samples),
      check.names = FALSE
    )
    metadata <- data.frame(
      Sample = samples,
      Donor = samples,
      Group = sample_groups,
      CellCategory = labels[[index]],
      Cells = 40L,
      stringsAsFactors = FALSE,
      check.names = FALSE
    )
    utils::write.csv(matrix, file.path(bundle_dir, "SCT_Mean_Log2_Expression.csv"), row.names = FALSE)
    utils::write.csv(metadata, file.path(bundle_dir, "Pseudobulk_Sample_Metadata.csv"), row.names = FALSE)
    write_manifest(file.path(bundle_dir, "Pseudobulk_Manifest.dcf"))
    omitted <- isTRUE(omit_first) && index == 1L
    catalog_rows[[index]] <- data.frame(
      CellCategoryID = id,
      CellCategory = labels[[index]],
      SelectionMode = "selected",
      Donor = metadata$Donor,
      Group = metadata$Group,
      Cells = metadata$Cells,
      MinCells = 20L,
      ProfileEligibility = "eligible",
      CellCategoryEligibility = if (omitted) "dropped_fewer_than_two_groups" else "included",
      MatrixPath = if (omitted) NA_character_ else file.path("cell_categories", id, "SCT_Mean_Log2_Expression.csv"),
      MetadataPath = if (omitted) NA_character_ else file.path("cell_categories", id, "Pseudobulk_Sample_Metadata.csv"),
      BundleManifestPath = if (omitted) NA_character_ else file.path("cell_categories", id, "Pseudobulk_Manifest.dcf"),
      AggregationMethod = "mean_sctransform_expression",
      SourceAssay = "SCT",
      SourceLayer = "data",
      SourceSeuratRds = "/not-a-real-study-object.rds",
      stringsAsFactors = FALSE,
      check.names = FALSE
    )
  }
  catalog <- do.call(rbind, catalog_rows)
  utils::write.csv(catalog, file.path(root, "Cell_Category_Profile_Catalog.csv"), row.names = FALSE)
  base::write.dcf(data.frame(
    format_version = "2",
    collection_kind = "cell_category_pseudobulk",
    cell_category_selection_mode = "selected",
    selected_cell_category_count = "2",
    aggregation_method = "mean_sctransform_expression",
    source_assay = "SCT",
    source_layer = "data",
    source_seurat_rds = "/not-a-real-study-object.rds",
    min_cells = "20",
    on_insufficient_cells = "error",
    profile_catalog = "Cell_Category_Profile_Catalog.csv",
    stringsAsFactors = FALSE
  ), file.path(root, "Pseudobulk_Collection_Manifest.dcf"))
  invisible(catalog)
}

work_dir <- tempfile("omix-limma-cell-category-collection-")
dir.create(work_dir)
collection_root <- file.path(work_dir, "collection")
make_collection(collection_root)
manifest_path <- file.path(collection_root, "Pseudobulk_Collection_Manifest.dcf")
output_dir <- file.path(work_dir, "result")

# The direct function is the scientific contract; a blank contrast infers the
# only replicated pair and preserves the exact suffixes L2P Multi resolves.
result <- omix_limma_cell_category_collection(manifest_path, output_dir)
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

# A Pseudobulk collection may preserve an omitted cell category as audit metadata
# when its drop policy leaves fewer than two groups. Limma must analyze the
# remaining bundle without attempting to resolve blank paths for the omission.
dropped_collection_root <- file.path(work_dir, "collection-with-omission")
make_collection(dropped_collection_root, omit_first = TRUE)
dropped_result <- omix_limma_cell_category_collection(
  file.path(dropped_collection_root, "Pseudobulk_Collection_Manifest.dcf"),
  file.path(work_dir, "result-with-omission")
)
stopifnot(identical(
  dropped_result$comparisons,
  "ct-monocytes-22222222222222222222222222222222__M-F"
))

# This direct shape validation encodes the public L2P Multi conventional input
# contract: a GeneName column and one tstat/pval/FC family per ordered label.
.omix_limma_collection_validate_l2p_multi_shape(wide, expected_comparisons)
provenance <- utils::read.csv(result$provenance, check.names = FALSE, stringsAsFactors = FALSE)
stopifnot(identical(provenance$Comparison, expected_comparisons))
stopifnot(all(c(
  "CellCategoryID", "CellCategory", "SelectionMode", "SourceMatrixPath", "SourceMatrixSHA256",
  "SourceBundleManifestPath", "SourceLimmaAnalysisPath", "InputDataType", "VarianceModel",
  "ModelType", "RequestedContrast", "ResolvedContrast", "ContrastSource", "ModeledGroups",
  "ExcludedGroups", "EligibleGroupProfileCounts", "ModeledGroupProfileCounts", "TestedGeneCount",
  "SourceLimmaAnalysisSHA256"
) %in% names(provenance)))
catalog_output <- utils::read.csv(result$catalog, check.names = FALSE, stringsAsFactors = FALSE)
stopifnot(all(c("ProfileEligibility", "LimmaAnalysisPath", "L2PComparison", "CollectionContrastMembership") %in% names(catalog_output)))
stopifnot(file.exists(file.path(output_dir, "cell_categories", provenance$CellCategoryID[[1L]], "Limma_Analysis.csv")))

# Exercise the portable explicit-path CLI separately from the direct function.
cli_output_dir <- file.path(work_dir, "cli-result")
cli_output <- system2(
  file.path(R.home("bin"), "Rscript"),
  c(
    file.path(module_dir, "scripts", "run_limma_cell_category_collection.R"),
    "--pseudobulk_collection_manifest", manifest_path,
    "--output_dir", cli_output_dir
  ),
  stdout = TRUE,
  stderr = TRUE
)
stopifnot(is.null(attr(cli_output, "status")))
stopifnot(file.exists(file.path(cli_output_dir, "L2P_Multi_Input.csv")))

cli_missing_output <- suppressWarnings(system2(
  file.path(R.home("bin"), "Rscript"),
  c(
    file.path(module_dir, "scripts", "run_limma_cell_category_collection.R"),
    "--pseudobulk_collection_manifest", manifest_path
  ),
  stdout = TRUE,
  stderr = TRUE
))
stopifnot(!is.null(attr(cli_missing_output, "status")))
stopifnot(any(grepl("--output_dir is required", cli_missing_output, fixed = TRUE)))

# Numeric group labels use the natural explicit/inferred comparison labels from
# the ordinary Limma contract.  The collection export qualifies those labels
# with the stable cell-category ID for L2P Multi.
numeric_root <- file.path(work_dir, "numeric-groups")
make_collection(numeric_root, group_labels = c("0", "1"), profiles_per_group = c(3L, 3L))
numeric_result <- omix_limma_cell_category_collection(
  file.path(numeric_root, "Pseudobulk_Collection_Manifest.dcf"),
  file.path(work_dir, "numeric-result")
)
numeric_comparisons <- paste0(c(
  "ct-t-cells-11111111111111111111111111111111",
  "ct-monocytes-22222222222222222222222222222222"
), "__1-0")
stopifnot(identical(numeric_result$comparisons, numeric_comparisons))
stopifnot(identical(numeric_result$requested_contrast, ""))
stopifnot(identical(numeric_result$resolved_contrast, "1-0"))
stopifnot(identical(numeric_result$contrast_source, "inferred"))
numeric_provenance <- utils::read.csv(numeric_result$provenance, check.names = FALSE, stringsAsFactors = FALSE)
stopifnot(all(is.na(numeric_provenance$RequestedContrast) | numeric_provenance$RequestedContrast == ""))
stopifnot(identical(numeric_provenance$ResolvedContrast, c("1-0", "1-0")))
stopifnot(identical(numeric_provenance$ModeledGroups, c("0,1", "0,1")))

# An explicit pair selects only the named groups when a category has a third
# replicated group.  The excluded profiles remain visible in the collection
# catalog instead of becoming silent nuisance-model rows.
three_group_root <- file.path(work_dir, "three-groups")
make_collection(
  three_group_root,
  group_labels = c("Control", "Treated", "Reference"),
  profiles_per_group = c(3L, 3L, 3L)
)
three_group_result <- omix_limma_cell_category_collection(
  file.path(three_group_root, "Pseudobulk_Collection_Manifest.dcf"),
  file.path(work_dir, "three-group-result"),
  contrast = "Treated-Control"
)
stopifnot(identical(three_group_result$resolved_contrast, "Treated-Control"))
three_group_provenance <- utils::read.csv(three_group_result$provenance, check.names = FALSE, stringsAsFactors = FALSE)
stopifnot(identical(three_group_provenance$ExcludedGroups, c("Reference", "Reference")))
three_group_catalog <- utils::read.csv(three_group_result$catalog, check.names = FALSE, stringsAsFactors = FALSE)
stopifnot(all(three_group_catalog$CollectionContrastMembership[three_group_catalog$Group == "Reference"] == "excluded_not_in_contrast"))
stopifnot(all(three_group_catalog$CollectionContrastMembership[three_group_catalog$Group %in% c("Control", "Treated")] == "included"))
three_group_metadata <- utils::read.csv(
  file.path(dirname(three_group_result$l2p_multi_input), "cell_categories", "ct-t-cells-11111111111111111111111111111111", "Sample_Metadata.csv"),
  stringsAsFactors = FALSE
)
stopifnot(identical(sort(unique(three_group_metadata$Group)), c("Control", "Treated")))

expect_error <- function(expression, pattern) {
  error <- tryCatch(force(expression), error = identity)
  stopifnot(inherits(error, "error"))
  stopifnot(grepl(pattern, conditionMessage(error), fixed = TRUE))
}

# A collection never reuses a populated directory, avoiding stale category
# bundles being mixed with a later run.
populated_output_dir <- file.path(work_dir, "populated-output")
dir.create(populated_output_dir)
writeLines("old result", file.path(populated_output_dir, "old.txt"))
expect_error(
  omix_limma_cell_category_collection(manifest_path, populated_output_dir),
  "output_dir must be new or empty"
)

# Invalid collection routing is rejected before any analysis is written.
missing_catalog_root <- file.path(work_dir, "missing-catalog")
make_collection(missing_catalog_root)
missing_manifest <- file.path(missing_catalog_root, "Pseudobulk_Collection_Manifest.dcf")
manifest <- base::read.dcf(missing_manifest)
manifest[1L, "profile_catalog"] <- "not-present.csv"
base::write.dcf(manifest, missing_manifest)
expect_error(
  omix_limma_cell_category_collection(missing_manifest, file.path(work_dir, "missing-catalog-output")),
  "profile_catalog was not found"
)

# The collection interface accepts only Pseudobulk selected/all bundles and
# requires catalog provenance to agree with the manifest routing declaration.
malformed_mode_root <- file.path(work_dir, "malformed-mode")
make_collection(malformed_mode_root)
malformed_mode_manifest <- file.path(malformed_mode_root, "Pseudobulk_Collection_Manifest.dcf")
manifest <- base::read.dcf(malformed_mode_manifest)
manifest[1L, "cell_category_selection_mode"] <- "one"
base::write.dcf(manifest, malformed_mode_manifest)
expect_error(
  omix_limma_cell_category_collection(malformed_mode_manifest, file.path(work_dir, "malformed-mode-output")),
  "cell_category_selection_mode as selected or all"
)

discordant_mode_root <- file.path(work_dir, "discordant-mode")
catalog <- make_collection(discordant_mode_root)
catalog$SelectionMode <- "all"
utils::write.csv(catalog, file.path(discordant_mode_root, "Cell_Category_Profile_Catalog.csv"), row.names = FALSE)
expect_error(
  omix_limma_cell_category_collection(file.path(discordant_mode_root, "Pseudobulk_Collection_Manifest.dcf"), file.path(work_dir, "discordant-mode-output")),
  "SelectionMode must match the collection manifest"
)

duplicate_root <- file.path(work_dir, "duplicate-catalog")
catalog <- make_collection(duplicate_root)
utils::write.csv(rbind(catalog, catalog[1L, , drop = FALSE]), file.path(duplicate_root, "Cell_Category_Profile_Catalog.csv"), row.names = FALSE)
expect_error(
  omix_limma_cell_category_collection(file.path(duplicate_root, "Pseudobulk_Collection_Manifest.dcf"), file.path(work_dir, "duplicate-output")),
  "duplicate CellCategoryID/Donor/Group"
)

missing_source_root <- file.path(work_dir, "missing-source")
catalog <- make_collection(missing_source_root)
catalog$MatrixPath[catalog$CellCategoryID == catalog$CellCategoryID[[1L]]] <- "cell_categories/missing/SCT_Mean_Log2_Expression.csv"
utils::write.csv(catalog, file.path(missing_source_root, "Cell_Category_Profile_Catalog.csv"), row.names = FALSE)
expect_error(
  omix_limma_cell_category_collection(file.path(missing_source_root, "Pseudobulk_Collection_Manifest.dcf"), file.path(work_dir, "missing-source-output")),
  "MatrixPath was not found"
)

insufficient_root <- file.path(work_dir, "insufficient")
make_collection(insufficient_root, profiles_per_group = c(3L, 1L))
expect_error(
  omix_limma_cell_category_collection(
    file.path(insufficient_root, "Pseudobulk_Collection_Manifest.dcf"),
    file.path(work_dir, "insufficient-output"),
    contrast = "M-F"
  ),
  "requires at least two donor-level profiles"
)

ambiguous_root <- file.path(work_dir, "ambiguous")
make_collection(ambiguous_root, group_labels = c("Control", "Treated", "Reference"), profiles_per_group = c(3L, 3L, 3L))
expect_error(
  omix_limma_cell_category_collection(
    file.path(ambiguous_root, "Pseudobulk_Collection_Manifest.dcf"),
    file.path(work_dir, "ambiguous-output")
  ),
  "a single comparison cannot be inferred"
)

expect_error(
  omix_limma_cell_category_collection(
    file.path(ambiguous_root, "Pseudobulk_Collection_Manifest.dcf"),
    file.path(work_dir, "absent-group-output"),
    contrast = "Unknown-Control"
  ),
  "Collection contrast is not estimable"
)

mismatch_root <- file.path(work_dir, "feature-mismatch")
make_collection(mismatch_root, second_genes = c("Gene1", "GeneX", "Gene3"))
expect_error(
  omix_limma_cell_category_collection(file.path(mismatch_root, "Pseudobulk_Collection_Manifest.dcf"), file.path(work_dir, "mismatch-output")),
  "exact same ordered tested-gene universe"
)

nonfinite <- wide
nonfinite[[expected_columns[[2L]]]][[1L]] <- NA_real_
expect_error(
  .omix_limma_collection_validate_l2p_multi_shape(nonfinite, expected_comparisons),
  "non-finite numeric values"
)

message("OMIX-Limma-Analysis cell-category collection checks passed")
