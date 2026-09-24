#' Convert an MOObject MOO to the OMIX standard tabular input
#'
#' @description
#' Converts an `MOObject::multiOmicDataSet` (MOO) count layer into an
#' `omix_standard_input`. This bridge imports the lightweight MOObject package,
#' not the MOSuite analysis package. The historical function name is retained
#' for compatibility.
#'
#' @param moo An `MOObject::multiOmicDataSet` object.
#' @param count_type Name of the MOObject count layer, normally `"raw"` for a
#'   raw-count differential-expression workflow.
#' @param sub_count_type Optional subtype when the selected count layer is a
#'   named list.
#' @param annotation_columns Optional feature-annotation columns to append to
#'   the count table, for example `"GeneName"`.
#' @param annotation_feature_id_column Feature ID column in MOObject annotation.
#'   Defaults to the first count-table column.
#'
#' @return An `omix_standard_input` object. Its provenance records the MOObject
#'   and bridge versions, selected layer, and handoff type.
#' @export
omix_mosuite_to_input <- function(
  moo,
  count_type = "raw",
  sub_count_type = NULL,
  annotation_columns = NULL,
  annotation_feature_id_column = NULL
) {
  extracted <- .omix_moobject_extract(
    moo = moo,
    count_type = count_type,
    sub_count_type = sub_count_type,
    annotation_columns = annotation_columns,
    annotation_feature_id_column = annotation_feature_id_column
  )
  .omix_moobject_validate_values(
    extracted$table,
    extracted$sample_columns,
    integer_like = TRUE,
    label = "count"
  )

  Omix::new_omix_standard_input(
    counts = extracted$table,
    metadata = extracted$metadata,
    feature_id_column = extracted$feature_id_column,
    sample_columns = extracted$sample_columns,
    provenance = list(
      bridge = "OmixMOSuite",
      bridge_version = as.character(utils::packageVersion("OmixMOSuite")),
      source_package = "MOObject",
      moobject_version = as.character(utils::packageVersion("MOObject")),
      count_type = extracted$count_type,
      sub_count_type = extracted$sub_count_type,
      handoff_type = "counts"
    )
  )
}

#' Convert an MOObject MOO continuous layer to an OMIX expression input
#'
#' @description
#' Extracts a declared continuous-expression layer from an
#' `MOObject::multiOmicDataSet`, aligns its sample metadata, and returns an
#' `omix_expression_input`. This function does not normalize or transform the
#' values. The caller must declare the source scale for provenance.
#'
#' @inheritParams omix_mosuite_to_input
#' @param count_type Name of the MOObject layer containing continuous
#'   expression values, for example `"norm"` or `"batch"`.
#' @param expression_scale Non-empty description of the selected layer's scale,
#'   for example `"log2"`, `"log2_cpm"`, or `"batch_corrected_log2"`.
#'
#' @return An `omix_expression_input` containing `expression`, aligned
#'   `metadata`, explicit column names, and conversion provenance.
#' @export
omix_mosuite_to_expression_input <- function(
  moo,
  count_type,
  expression_scale,
  sub_count_type = NULL,
  annotation_columns = NULL,
  annotation_feature_id_column = NULL
) {
  expression_scale <- .omix_moobject_single_string(expression_scale, "expression_scale")
  extracted <- .omix_moobject_extract(
    moo = moo,
    count_type = count_type,
    sub_count_type = sub_count_type,
    annotation_columns = annotation_columns,
    annotation_feature_id_column = annotation_feature_id_column
  )
  .omix_moobject_validate_values(
    extracted$table,
    extracted$sample_columns,
    integer_like = FALSE,
    label = "expression"
  )
  validated <- Omix::new_omix_standard_input(
    counts = extracted$table,
    metadata = extracted$metadata,
    feature_id_column = extracted$feature_id_column,
    sample_columns = extracted$sample_columns,
    provenance = list(
      bridge = "OmixMOSuite",
      bridge_version = as.character(utils::packageVersion("OmixMOSuite")),
      source_package = "MOObject",
      moobject_version = as.character(utils::packageVersion("MOObject")),
      count_type = extracted$count_type,
      sub_count_type = extracted$sub_count_type,
      handoff_type = "continuous_expression",
      expression_scale = expression_scale
    )
  )
  structure(
    list(
      expression = validated$counts,
      metadata = validated$metadata,
      feature_id_column = validated$feature_id_column,
      sample_id_column = validated$sample_id_column,
      sample_columns = validated$sample_columns,
      provenance = validated$provenance
    ),
    class = "omix_expression_input"
  )
}

#' Read a serialized MOO as an OMIX standard input
#'
#' @param path Path to an `.rds` file containing a current MOObject MOO or a
#'   compatible legacy MOSuite MOO supported by
#'   [MOObject::read_multiOmicDataSet()].
#' @param ... Arguments passed to [omix_mosuite_to_input()].
#'
#' @return An `omix_standard_input` object.
#' @export
omix_read_mosuite_rds <- function(path, ...) {
  path <- .omix_moobject_single_string(path, "path")
  if (!file.exists(path)) {
    stop("MOO RDS file does not exist: ", path, call. = FALSE)
  }
  moo <- tryCatch(
    MOObject::read_multiOmicDataSet(path),
    error = function(error) {
      stop("Could not read the MOO with MOObject: ", conditionMessage(error), call. = FALSE)
    }
  )
  omix_mosuite_to_input(moo, ...)
}

#' Read a serialized MOO as an OMIX continuous-expression input
#'
#' @param path Path to an `.rds` file containing a current MOObject MOO or a
#'   compatible legacy MOSuite MOO supported by
#'   [MOObject::read_multiOmicDataSet()].
#' @param ... Arguments passed to [omix_mosuite_to_expression_input()].
#'
#' @return An `omix_expression_input` object.
#' @export
omix_read_mosuite_expression_rds <- function(path, ...) {
  path <- .omix_moobject_single_string(path, "path")
  if (!file.exists(path)) {
    stop("MOO RDS file does not exist: ", path, call. = FALSE)
  }
  moo <- tryCatch(
    MOObject::read_multiOmicDataSet(path),
    error = function(error) {
      stop("Could not read the MOO with MOObject: ", conditionMessage(error), call. = FALSE)
    }
  )
  omix_mosuite_to_expression_input(moo, ...)
}

.omix_moobject_extract <- function(
  moo,
  count_type,
  sub_count_type,
  annotation_columns,
  annotation_feature_id_column
) {
  if (!S7::S7_inherits(moo, MOObject::multiOmicDataSet)) {
    stop("moo must be an MOObject::multiOmicDataSet.", call. = FALSE)
  }
  tryCatch(
    S7::validate(moo),
    error = function(error) {
      stop("MOObject validation failed: ", conditionMessage(error), call. = FALSE)
    }
  )
  count_type <- .omix_moobject_single_string(count_type, "count_type")
  if (!is.null(sub_count_type)) {
    sub_count_type <- .omix_moobject_single_string(sub_count_type, "sub_count_type")
  }
  values <- tryCatch(
    MOObject::extract_counts(moo, count_type, sub_count_type),
    error = function(error) {
      stop("Could not extract the MOObject layer: ", conditionMessage(error), call. = FALSE)
    }
  )
  metadata <- tryCatch(
    S7::prop(moo, "sample_meta"),
    error = function(error) {
      stop("Could not read MOObject sample metadata: ", conditionMessage(error), call. = FALSE)
    }
  )
  values <- as.data.frame(values, check.names = FALSE, stringsAsFactors = FALSE)
  metadata <- as.data.frame(metadata, check.names = FALSE, stringsAsFactors = FALSE)
  if (ncol(values) < 2L) {
    stop("The selected MOObject layer must contain one feature-ID column and at least one sample column.", call. = FALSE)
  }
  feature_id_column <- names(values)[[1L]]
  sample_columns <- names(values)[-1L]
  feature_ids <- as.character(values[[feature_id_column]])
  if (anyNA(feature_ids) || any(feature_ids == "") || anyDuplicated(feature_ids)) {
    stop("The selected MOObject layer must contain unique, non-empty feature IDs.", call. = FALSE)
  }

  if (!is.null(annotation_columns)) {
    annotation_columns <- unique(as.character(annotation_columns))
    if (length(annotation_columns) == 0L || anyNA(annotation_columns) || any(annotation_columns == "")) {
      stop("annotation_columns must contain one or more non-empty column names.", call. = FALSE)
    }
    annotation <- tryCatch(
      S7::prop(moo, "annotation"),
      error = function(error) {
        stop("Could not read MOObject feature annotation: ", conditionMessage(error), call. = FALSE)
      }
    )
    annotation <- as.data.frame(annotation, check.names = FALSE, stringsAsFactors = FALSE)
    if (is.null(annotation_feature_id_column)) {
      annotation_feature_id_column <- feature_id_column
    }
    annotation_feature_id_column <- .omix_moobject_single_string(
      annotation_feature_id_column,
      "annotation_feature_id_column"
    )
    required_columns <- unique(c(annotation_feature_id_column, annotation_columns))
    missing_columns <- setdiff(required_columns, names(annotation))
    if (length(missing_columns) > 0L) {
      stop(
        "MOObject annotation is missing requested column(s): ",
        paste(missing_columns, collapse = ", "),
        ". Available columns: ", paste(names(annotation), collapse = ", "),
        call. = FALSE
      )
    }
    annotation_ids <- as.character(annotation[[annotation_feature_id_column]])
    if (anyNA(annotation_ids) || any(annotation_ids == "") || anyDuplicated(annotation_ids)) {
      stop("MOObject annotation feature IDs must be unique and non-empty.", call. = FALSE)
    }
    match_index <- match(feature_ids, annotation_ids)
    if (anyNA(match_index)) {
      missing_features <- unique(feature_ids[is.na(match_index)])
      stop(
        "MOObject annotation is missing ", length(missing_features),
        " feature ID(s), including: ", paste(utils::head(missing_features, 5L), collapse = ", "),
        call. = FALSE
      )
    }
    annotations_to_append <- annotation[match_index, annotation_columns, drop = FALSE]
    conflicting_columns <- intersect(names(annotations_to_append), names(values))
    if (length(conflicting_columns) > 0L) {
      stop("Requested annotation columns already exist in the selected layer: ", paste(conflicting_columns, collapse = ", "), call. = FALSE)
    }
    values <- cbind(
      values[, feature_id_column, drop = FALSE],
      annotations_to_append,
      values[, sample_columns, drop = FALSE]
    )
  }

  list(
    table = values,
    metadata = metadata,
    feature_id_column = feature_id_column,
    sample_columns = sample_columns,
    count_type = count_type,
    sub_count_type = sub_count_type
  )
}

.omix_moobject_validate_values <- function(table, sample_columns, integer_like, label) {
  non_numeric <- sample_columns[!vapply(table[sample_columns], is.numeric, logical(1))]
  if (length(non_numeric) > 0L) {
    stop(label, " sample columns are not numeric: ", paste(non_numeric, collapse = ", "), call. = FALSE)
  }
  values <- unlist(table[sample_columns], use.names = FALSE)
  if (anyNA(values) || any(!is.finite(values))) {
    stop(label, " sample values must be finite and non-missing.", call. = FALSE)
  }
  if (integer_like && (any(values < 0) || any(abs(values - round(values)) > sqrt(.Machine$double.eps)))) {
    stop(
      "Count handoff requires non-negative integer-like values. ",
      "Use omix_mosuite_to_expression_input() for normalized or continuous data.",
      call. = FALSE
    )
  }
  invisible(TRUE)
}

.omix_moobject_single_string <- function(value, name) {
  if (!is.character(value) || length(value) != 1L || is.na(value) || value == "") {
    stop(name, " must be one non-empty character value.", call. = FALSE)
  }
  value
}
