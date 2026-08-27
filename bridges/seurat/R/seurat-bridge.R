#' Extract raw counts and cell metadata from a Seurat object
#'
#' @description
#' Extracts one explicit assay and layer from a Seurat object without importing
#' the full Seurat package. The returned counts remain feature-by-cell and are
#' intended for inspection or for `omix_seurat_to_input()`.
#'
#' @param seurat_object A Seurat object supported by SeuratObject.
#' @param assay Assay containing raw counts. Default: `"RNA"`.
#' @param layer Assay layer containing raw counts. Default: `"counts"`.
#'
#' @return A list with sparse `counts`, aligned cell `metadata`, and conversion
#'   `provenance`.
#' @export
omix_seurat_extract <- function(
  seurat_object,
  assay = "RNA",
  layer = "counts"
) {
  assay <- .omix_seurat_single_string(assay, "assay")
  layer <- .omix_seurat_single_string(layer, "layer")
  if (!inherits(seurat_object, "Seurat")) {
    stop("seurat_object must inherit from class 'Seurat'.", call. = FALSE)
  }

  counts <- .omix_seurat_extract_layer(seurat_object, assay, layer)
  if (!is.matrix(counts) && !inherits(counts, "Matrix")) {
    stop("The requested Seurat layer is not a matrix-like count matrix.", call. = FALSE)
  }
  if (is.null(rownames(counts)) || is.null(colnames(counts))) {
    stop("The requested Seurat layer must have feature and cell names.", call. = FALSE)
  }
  if (anyNA(rownames(counts)) || any(rownames(counts) == "")) {
    stop("Seurat feature names must be non-empty.", call. = FALSE)
  }
  if (anyDuplicated(colnames(counts))) {
    stop("Seurat cell names must be unique.", call. = FALSE)
  }
  .omix_seurat_validate_raw_counts(counts)

  cell_metadata <- tryCatch(
    as.data.frame(methods::slot(seurat_object, "meta.data"), check.names = FALSE, stringsAsFactors = FALSE),
    error = function(error) {
      stop("Could not read Seurat cell metadata: ", conditionMessage(error), call. = FALSE)
    }
  )
  if (is.null(rownames(cell_metadata)) || anyDuplicated(rownames(cell_metadata))) {
    stop("Seurat cell metadata must have unique row names matching the count matrix.", call. = FALSE)
  }
  missing_metadata <- setdiff(colnames(counts), rownames(cell_metadata))
  extra_metadata <- setdiff(rownames(cell_metadata), colnames(counts))
  if (length(missing_metadata) > 0L || length(extra_metadata) > 0L) {
    details <- c(
      if (length(missing_metadata) > 0L) paste0("counts only: ", paste(utils::head(missing_metadata, 5L), collapse = ", ")),
      if (length(extra_metadata) > 0L) paste0("metadata only: ", paste(utils::head(extra_metadata, 5L), collapse = ", "))
    )
    stop("Seurat counts and cell metadata have different cell names (", paste(details, collapse = "; "), ").", call. = FALSE)
  }
  cell_metadata <- cell_metadata[colnames(counts), , drop = FALSE]

  structure(
    list(
      counts = counts,
      metadata = cell_metadata,
      provenance = list(
        bridge = "OmixSeurat",
        bridge_version = as.character(utils::packageVersion("OmixSeurat")),
        seuratobject_version = as.character(utils::packageVersion("SeuratObject")),
        source_class = class(seurat_object),
        assay = assay,
        layer = layer
      )
    ),
    class = "omix_seurat_cells"
  )
}

#' Create an OMIX pseudobulk input from one Seurat cell type
#'
#' @description
#' Selects one cell type, sums raw counts by donor and condition, and returns an
#' `omix_standard_input` suitable for OMIX count-based modules. Cells are never
#' treated as independent DEG replicates.
#'
#' @param seurat_object A Seurat object supported by SeuratObject.
#' @param donor_column Cell-metadata column identifying biological donors.
#' @param group_column Cell-metadata column identifying the experimental group.
#' @param cell_type_column Cell-metadata column identifying cell types.
#' @param cell_type One exact cell-type value to aggregate.
#' @param cell_filter_column Optional cell-metadata column used for an explicit
#'   pre-aggregation filter.
#' @param cell_filter_values Values to retain from `cell_filter_column`. Supply
#'   both filter arguments or neither.
#' @param assay Assay containing raw counts. Default: `"RNA"`.
#' @param layer Assay layer containing raw counts. Default: `"counts"`.
#' @param feature_id_column Output feature-ID column name. Default: `"Gene"`.
#' @param min_cells Minimum selected cells per donor-by-group profile. Default:
#'   `20`.
#' @param on_insufficient_cells Whether under-populated profiles cause an error
#'   (default) or are dropped.
#'
#' @return An `omix_standard_input` whose metadata contains `Sample`, `Donor`,
#'   `Group`, `CellType`, and `Cells` columns.
#' @export
omix_seurat_to_input <- function(
  seurat_object,
  donor_column,
  group_column,
  cell_type_column,
  cell_type,
  cell_filter_column = NULL,
  cell_filter_values = NULL,
  assay = "RNA",
  layer = "counts",
  feature_id_column = "Gene",
  min_cells = 20L,
  on_insufficient_cells = c("error", "drop")
) {
  donor_column <- .omix_seurat_single_string(donor_column, "donor_column")
  group_column <- .omix_seurat_single_string(group_column, "group_column")
  cell_type_column <- .omix_seurat_single_string(cell_type_column, "cell_type_column")
  cell_type <- .omix_seurat_single_string(cell_type, "cell_type")
  feature_id_column <- .omix_seurat_single_string(feature_id_column, "feature_id_column")
  if (xor(is.null(cell_filter_column), is.null(cell_filter_values))) {
    stop("Supply both cell_filter_column and cell_filter_values, or neither.", call. = FALSE)
  }
  if (!is.null(cell_filter_column)) {
    cell_filter_column <- .omix_seurat_single_string(cell_filter_column, "cell_filter_column")
    cell_filter_values <- unique(as.character(cell_filter_values))
    if (length(cell_filter_values) == 0L || anyNA(cell_filter_values) || any(cell_filter_values == "")) {
      stop("cell_filter_values must contain one or more non-empty values.", call. = FALSE)
    }
  }
  if (!is.numeric(min_cells) || length(min_cells) != 1L || is.na(min_cells) || min_cells < 1L || min_cells != as.integer(min_cells)) {
    stop("min_cells must be one positive integer.", call. = FALSE)
  }
  min_cells <- as.integer(min_cells)
  on_insufficient_cells <- match.arg(on_insufficient_cells)

  extracted <- omix_seurat_extract(seurat_object, assay = assay, layer = layer)
  metadata <- extracted$metadata
  required_columns <- c(donor_column, group_column, cell_type_column, cell_filter_column)
  missing_columns <- setdiff(required_columns, names(metadata))
  if (length(missing_columns) > 0L) {
    stop(
      "Seurat cell metadata is missing required column(s): ",
      paste(missing_columns, collapse = ", "),
      ". Available columns: ", paste(names(metadata), collapse = ", "),
      call. = FALSE
    )
  }

  selected <- as.character(metadata[[cell_type_column]]) == cell_type
  selected[is.na(selected)] <- FALSE
  if (!is.null(cell_filter_column)) {
    selected <- selected & as.character(metadata[[cell_filter_column]]) %in% cell_filter_values
    selected[is.na(selected)] <- FALSE
  }
  if (!any(selected)) {
    stop("No cells match ", cell_type_column, " = '", cell_type, "'.", call. = FALSE)
  }
  metadata <- metadata[selected, , drop = FALSE]
  counts <- extracted$counts[, rownames(metadata), drop = FALSE]
  donor <- as.character(metadata[[donor_column]])
  group <- as.character(metadata[[group_column]])
  if (anyNA(donor) || any(donor == "") || anyNA(group) || any(group == "")) {
    stop("Selected cells contain missing or empty donor or group values.", call. = FALSE)
  }

  profile_key <- paste(donor, group, sep = "\r")
  profile_levels <- unique(profile_key)
  aggregation_design <- Matrix::sparseMatrix(
    i = seq_along(profile_key),
    j = match(profile_key, profile_levels),
    x = 1,
    dims = c(length(profile_key), length(profile_levels)),
    dimnames = list(colnames(counts), profile_levels)
  )
  cells_per_profile <- as.integer(Matrix::colSums(aggregation_design))
  profile_indices <- match(profile_levels, profile_key)
  profile_metadata <- data.frame(
    Donor = donor[profile_indices],
    Group = group[profile_indices],
    CellType = cell_type,
    Cells = cells_per_profile,
    stringsAsFactors = FALSE
  )
  insufficient <- profile_metadata$Cells < min_cells
  if (any(insufficient)) {
    profile_summary <- paste0(
      profile_metadata$Donor[insufficient], " / ",
      profile_metadata$Group[insufficient], " (", profile_metadata$Cells[insufficient], " cells)"
    )
    if (identical(on_insufficient_cells, "error")) {
      stop(
        "Selected donor-by-group profile(s) have fewer than ", min_cells,
        " cells: ", paste(profile_summary, collapse = ", "),
        ". Set on_insufficient_cells = 'drop' only when that exclusion is intentional.",
        call. = FALSE
      )
    }
    aggregation_design <- aggregation_design[, !insufficient, drop = FALSE]
    profile_metadata <- profile_metadata[!insufficient, , drop = FALSE]
  }
  if (ncol(aggregation_design) == 0L) {
    stop("No donor-by-group pseudobulk profiles remain after cell-count filtering.", call. = FALSE)
  }

  pseudobulk_counts <- counts %*% aggregation_design
  sample_ids <- paste(profile_metadata$Donor, profile_metadata$Group, sep = "__")
  if (anyDuplicated(sample_ids)) {
    stop("Donor and group labels produce duplicate pseudobulk sample IDs.", call. = FALSE)
  }
  colnames(pseudobulk_counts) <- sample_ids
  profile_metadata <- data.frame(
    Sample = sample_ids,
    profile_metadata,
    check.names = FALSE,
    stringsAsFactors = FALSE
  )

  Omix::new_omix_standard_input(
    counts = data.frame(
      stats::setNames(list(rownames(pseudobulk_counts)), feature_id_column),
      as.data.frame(as.matrix(pseudobulk_counts), check.names = FALSE),
      check.names = FALSE,
      stringsAsFactors = FALSE
    ),
    metadata = profile_metadata,
    feature_id_column = feature_id_column,
    sample_id_column = "Sample",
    sample_columns = sample_ids,
    provenance = c(
      extracted$provenance,
      list(
        donor_column = donor_column,
        group_column = group_column,
        cell_type_column = cell_type_column,
        cell_type = cell_type,
        cell_filter_column = cell_filter_column,
        cell_filter_values = cell_filter_values,
        min_cells = min_cells,
        on_insufficient_cells = on_insufficient_cells,
        aggregation = "sum_by_donor_and_group"
      )
    )
  )
}

#' Read a serialized Seurat object as an OMIX pseudobulk input
#'
#' @inheritParams omix_seurat_to_input
#' @param path Path to an `.rds` file containing a Seurat object.
#'
#' @return An `omix_standard_input` object.
#' @export
omix_read_seurat_rds <- function(path, ...) {
  path <- .omix_seurat_single_string(path, "path")
  if (!file.exists(path)) {
    stop("Seurat RDS file does not exist: ", path, call. = FALSE)
  }
  omix_seurat_to_input(readRDS(path), ...)
}

.omix_seurat_extract_layer <- function(seurat_object, assay, layer) {
  accessor_error <- NULL
  counts <- tryCatch(
    SeuratObject::LayerData(seurat_object, assay = assay, layer = layer),
    error = function(error) {
      accessor_error <<- error
      NULL
    }
  )
  if (!is.null(counts)) {
    return(counts)
  }

  assays <- tryCatch(methods::slot(seurat_object, "assays"), error = function(error) NULL)
  if (!is.null(assays) && assay %in% names(assays)) {
    assay_object <- assays[[assay]]
    assay_slots <- methods::slotNames(assay_object)
    if (identical(layer, "counts") && "counts" %in% assay_slots) {
      return(methods::slot(assay_object, "counts"))
    }
    if ("layers" %in% assay_slots) {
      layers <- methods::slot(assay_object, "layers")
      if (layer %in% names(layers)) {
        return(layers[[layer]])
      }
    }
  }

  detail <- if (is.null(accessor_error)) "unknown error" else conditionMessage(accessor_error)
  stop(
    "Could not extract layer '", layer, "' from assay '", assay,
    "' using SeuratObject. Details: ", detail,
    call. = FALSE
  )
}

.omix_seurat_validate_raw_counts <- function(counts) {
  values <- if (inherits(counts, "sparseMatrix")) counts@x else as.numeric(counts)
  if (any(!is.finite(values)) || any(values < 0)) {
    stop("Seurat raw counts must be finite, non-negative values.", call. = FALSE)
  }
  if (any(abs(values - round(values)) > 1e-8)) {
    stop("The requested Seurat layer is not integer-like raw counts. Use layer = 'counts'.", call. = FALSE)
  }
}

.omix_seurat_single_string <- function(value, name) {
  if (!is.character(value) || length(value) != 1L || is.na(value) || value == "") {
    stop(name, " must be one non-empty character value.", call. = FALSE)
  }
  value
}
