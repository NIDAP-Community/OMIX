#' Construct a portable OMIX standard input
#'
#' @description
#' Validates and stores the platform-neutral tabular contract shared by OMIX
#' modules: a feature-by-sample table and sample metadata. The feature ID and
#' sample columns are explicit, and metadata is reordered to match the count
#' table. This constructor deliberately has no dependencies on data-object
#' ecosystems such as MOSuite or Seurat.
#'
#' @param counts A data frame with one feature-ID column, optional annotation
#'   columns, and numeric sample columns.
#' @param metadata A data frame with a unique sample-ID column.
#' @param feature_id_column Name of the feature-ID column in `counts`. Defaults
#'   to the first column.
#' @param sample_id_column Name of the sample-ID column in `metadata`. Defaults
#'   to the first column.
#' @param sample_columns Names of the sample columns in `counts`. Defaults to
#'   every column other than `feature_id_column`; provide it explicitly when the
#'   table also contains annotation columns.
#' @param provenance Optional named list recording the source and conversion of
#'   the input.
#'
#' @return An object of class `omix_standard_input` containing `counts`,
#'   aligned `metadata`, column names, and provenance.
#' @export
new_omix_standard_input <- function(
  counts,
  metadata,
  feature_id_column = NULL,
  sample_id_column = NULL,
  sample_columns = NULL,
  provenance = list()
) {
  counts <- as.data.frame(counts, check.names = FALSE, stringsAsFactors = FALSE)
  metadata <- as.data.frame(metadata, check.names = FALSE, stringsAsFactors = FALSE)
  if (ncol(counts) < 2L) {
    stop("counts must contain one feature-ID column and at least one sample column.", call. = FALSE)
  }
  if (ncol(metadata) < 1L) {
    stop("metadata must contain a sample-ID column.", call. = FALSE)
  }

  if (is.null(feature_id_column)) {
    feature_id_column <- names(counts)[[1L]]
  }
  if (is.null(sample_id_column)) {
    sample_id_column <- names(metadata)[[1L]]
  }
  feature_id_column <- .omix_single_string(feature_id_column, "feature_id_column")
  sample_id_column <- .omix_single_string(sample_id_column, "sample_id_column")
  if (!(feature_id_column %in% names(counts))) {
    stop("feature_id_column is not present in counts: ", feature_id_column, call. = FALSE)
  }
  if (!(sample_id_column %in% names(metadata))) {
    stop("sample_id_column is not present in metadata: ", sample_id_column, call. = FALSE)
  }

  if (is.null(sample_columns)) {
    sample_columns <- setdiff(names(counts), feature_id_column)
  }
  sample_columns <- unique(as.character(sample_columns))
  if (length(sample_columns) == 0L || anyNA(sample_columns) || any(sample_columns == "")) {
    stop("sample_columns must contain one or more non-empty column names.", call. = FALSE)
  }
  missing_sample_columns <- setdiff(sample_columns, names(counts))
  if (length(missing_sample_columns) > 0L) {
    stop("sample_columns are missing from counts: ", paste(missing_sample_columns, collapse = ", "), call. = FALSE)
  }
  if (feature_id_column %in% sample_columns) {
    stop("feature_id_column cannot also be a sample column.", call. = FALSE)
  }

  metadata_sample_ids <- as.character(metadata[[sample_id_column]])
  if (anyNA(metadata_sample_ids) || any(metadata_sample_ids == "") || anyDuplicated(metadata_sample_ids)) {
    stop("metadata must contain unique, non-empty sample IDs.", call. = FALSE)
  }
  missing_from_counts <- setdiff(metadata_sample_ids, sample_columns)
  missing_from_metadata <- setdiff(sample_columns, metadata_sample_ids)
  if (length(missing_from_counts) > 0L || length(missing_from_metadata) > 0L) {
    details <- c(
      if (length(missing_from_counts) > 0L) paste0("metadata only: ", paste(missing_from_counts, collapse = ", ")),
      if (length(missing_from_metadata) > 0L) paste0("counts only: ", paste(missing_from_metadata, collapse = ", "))
    )
    stop("counts and metadata have different sample IDs (", paste(details, collapse = "; "), ").", call. = FALSE)
  }
  non_numeric_samples <- sample_columns[!vapply(counts[sample_columns], is.numeric, logical(1))]
  if (length(non_numeric_samples) > 0L) {
    stop("sample columns are not numeric: ", paste(non_numeric_samples, collapse = ", "), call. = FALSE)
  }
  if (!is.list(provenance)) {
    stop("provenance must be a list.", call. = FALSE)
  }

  metadata <- metadata[match(sample_columns, metadata_sample_ids), , drop = FALSE]
  structure(
    list(
      counts = counts,
      metadata = metadata,
      feature_id_column = feature_id_column,
      sample_id_column = sample_id_column,
      sample_columns = sample_columns,
      provenance = provenance
    ),
    class = "omix_standard_input"
  )
}

.omix_single_string <- function(value, name) {
  if (!is.character(value) || length(value) != 1L || is.na(value) || value == "") {
    stop(name, " must be one non-empty character value.", call. = FALSE)
  }
  value
}
