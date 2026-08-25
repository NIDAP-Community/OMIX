#' Convert a MOSuite MOO to the OMIX standard tabular input
#'
#' @description
#' Converts a MOSuite `multiOmicDataSet` (MOO) into an `omix_standard_input`.
#' MOSuite is required only by this bridge package; ordinary OMIX utilities and
#' modules that consume exported count and metadata tables do not depend on it.
#'
#' @param moo A MOSuite `multiOmicDataSet` object.
#' @param count_type Name of the MOSuite count layer, normally `"raw"` for a
#'   raw-count differential-expression workflow.
#' @param sub_count_type Optional subtype when the selected count layer is a
#'   named list.
#' @param annotation_columns Optional feature-annotation columns to append to
#'   the count table, for example `"GeneName"`.
#' @param annotation_feature_id_column Feature ID column in MOSuite annotation.
#'   Defaults to the first count-table column.
#'
#' @return An `omix_standard_input` object. Its provenance records the MOSuite
#'   and bridge versions and the selected count layer.
#' @export
omix_mosuite_to_input <- function(
  moo,
  count_type = "raw",
  sub_count_type = NULL,
  annotation_columns = NULL,
  annotation_feature_id_column = NULL
) {
  count_type <- .omix_mosuite_single_string(count_type, "count_type")
  if (!is.null(sub_count_type)) {
    sub_count_type <- .omix_mosuite_single_string(sub_count_type, "sub_count_type")
  }
  counts <- tryCatch(
    MOSuite::extract_counts(moo, count_type, sub_count_type),
    error = function(error) {
      stop("Could not extract the MOSuite count layer: ", conditionMessage(error), call. = FALSE)
    }
  )
  metadata <- tryCatch(
    S7::prop(moo, "sample_meta"),
    error = function(error) {
      stop("Could not read MOSuite sample metadata: ", conditionMessage(error), call. = FALSE)
    }
  )
  annotation <- tryCatch(
    S7::prop(moo, "annotation"),
    error = function(error) {
      stop("Could not read MOSuite feature annotation: ", conditionMessage(error), call. = FALSE)
    }
  )

  counts <- as.data.frame(counts, check.names = FALSE, stringsAsFactors = FALSE)
  annotation <- as.data.frame(annotation, check.names = FALSE, stringsAsFactors = FALSE)
  feature_id_column <- names(counts)[[1L]]
  sample_columns <- names(counts)[-1L]
  if (!is.null(annotation_columns)) {
    annotation_columns <- unique(as.character(annotation_columns))
    if (length(annotation_columns) == 0L || anyNA(annotation_columns) || any(annotation_columns == "")) {
      stop("annotation_columns must contain one or more non-empty column names.", call. = FALSE)
    }
    if (is.null(annotation_feature_id_column)) {
      annotation_feature_id_column <- feature_id_column
    }
    annotation_feature_id_column <- .omix_mosuite_single_string(
      annotation_feature_id_column,
      "annotation_feature_id_column"
    )
    required_columns <- unique(c(annotation_feature_id_column, annotation_columns))
    missing_columns <- setdiff(required_columns, names(annotation))
    if (length(missing_columns) > 0L) {
      stop(
        "MOSuite annotation is missing requested column(s): ",
        paste(missing_columns, collapse = ", "),
        ". Available columns: ", paste(names(annotation), collapse = ", "),
        call. = FALSE
      )
    }
    if (anyDuplicated(annotation[[annotation_feature_id_column]])) {
      stop("MOSuite annotation feature IDs are duplicated; cannot safely append annotations.", call. = FALSE)
    }
    match_index <- match(counts[[feature_id_column]], annotation[[annotation_feature_id_column]])
    if (anyNA(match_index)) {
      missing_features <- unique(counts[[feature_id_column]][is.na(match_index)])
      stop(
        "MOSuite annotation is missing ", length(missing_features),
        " feature ID(s), including: ", paste(utils::head(missing_features, 5L), collapse = ", "),
        call. = FALSE
      )
    }
    annotations_to_append <- annotation[match_index, annotation_columns, drop = FALSE]
    conflicting_columns <- intersect(names(annotations_to_append), names(counts))
    if (length(conflicting_columns) > 0L) {
      stop("Requested annotation columns already exist in the count table: ", paste(conflicting_columns, collapse = ", "), call. = FALSE)
    }
    counts <- cbind(
      counts[, feature_id_column, drop = FALSE],
      annotations_to_append,
      counts[, sample_columns, drop = FALSE]
    )
  }

  Omix::new_omix_standard_input(
    counts = counts,
    metadata = metadata,
    feature_id_column = feature_id_column,
    sample_columns = sample_columns,
    provenance = list(
      bridge = "OmixMOSuite",
      bridge_version = as.character(utils::packageVersion("OmixMOSuite")),
      mosuite_version = as.character(utils::packageVersion("MOSuite")),
      count_type = count_type,
      sub_count_type = sub_count_type
    )
  )
}

#' Read a serialized MOSuite MOO as an OMIX standard input
#'
#' @inheritParams omix_mosuite_to_input
#' @param path Path to an `.rds` file containing a MOSuite MOO.
#'
#' @return An `omix_standard_input` object.
#' @export
omix_read_mosuite_rds <- function(path, ...) {
  path <- .omix_mosuite_single_string(path, "path")
  if (!file.exists(path)) {
    stop("MOSuite RDS file does not exist: ", path, call. = FALSE)
  }
  omix_mosuite_to_input(readRDS(path), ...)
}

.omix_mosuite_single_string <- function(value, name) {
  if (!is.character(value) || length(value) != 1L || is.na(value) || value == "") {
    stop(name, " must be one non-empty character value.", call. = FALSE)
  }
  value
}
