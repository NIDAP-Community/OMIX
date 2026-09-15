# Internal canonical pathway-result fields. The mapping follows the validated
# Multi-Pathway Bubble Plot application bundle and is intentionally limited to
# stable GSEA, L2P, and canonical OMIX field names.
.omix_pathway_fields <- c(
  "contrast", "collection", "pathway", "pval", "padj", "score", "size", "fraction"
)

.omix_pathway_presets <- list(
  gsea = c(
    contrast = "contrast",
    collection = "collection",
    pathway = "pathway",
    pval = "pval",
    padj = "padj",
    score = "NES",
    size = "size_leadingEdge",
    fraction = "fraction_leadingEdge"
  ),
  l2p = c(
    contrast = "group",
    collection = "categ",
    pathway = "pathway_name",
    pval = "pval",
    padj = "fdr",
    score = "enrichment_score",
    size = "number_hits",
    fraction = "percent_gene_hits_per_pathway"
  ),
  l2p_single = c(
    contrast = "direction",
    collection = "category",
    pathway = "pathway_name",
    pval = "pval",
    padj = "fdr",
    score = "enrichment_score",
    size = "number_hits",
    fraction = "percent_gene_hits_per_pathway"
  ),
  canonical = c(
    contrast = "contrast",
    collection = "collection",
    pathway = "pathway",
    pval = "pval",
    padj = "padj",
    score = "score",
    size = "size",
    fraction = "fraction"
  )
)

.omix_pathway_signatures <- list(
  gsea = c("contrast", "pathway", "NES", "size_leadingEdge", "fraction_leadingEdge"),
  l2p = c("group", "categ", "pathway_name", "fdr", "enrichment_score", "number_hits"),
  l2p_single = c("direction", "category", "pathway_name", "fdr", "enrichment_score", "number_hits")
)

.match_pathway_column <- function(columns, candidate) {
  candidate <- as.character(candidate)[1L]
  if (is.na(candidate) || !nzchar(candidate)) return(NA_character_)
  exact <- which(columns == candidate)
  if (length(exact) == 1L) return(columns[[exact]])
  key <- tolower(trimws(as.character(columns)))
  candidate_key <- tolower(trimws(candidate))
  case_insensitive <- which(key == candidate_key)
  if (length(case_insensitive) == 1L) return(columns[[case_insensitive]])
  NA_character_
}

.resolve_pathway_mapping <- function(columns, input_format, mapping) {
  if (!is.null(mapping)) {
    if (is.null(names(mapping))) {
      stop("`mapping` must be a named character vector of canonical field names.", call. = FALSE)
    }
    unknown_fields <- setdiff(names(mapping), .omix_pathway_fields)
    if (length(unknown_fields) > 0L) {
      stop("`mapping` contains unknown canonical field(s): ", paste(unknown_fields, collapse = ", "), call. = FALSE)
    }
    resolved <- setNames(rep("", length(.omix_pathway_fields)), .omix_pathway_fields)
    for (field in names(mapping)) {
      source <- .match_pathway_column(columns, mapping[[field]])
      if (is.na(source)) stop("Mapped column not found for `", field, "`: ", mapping[[field]], call. = FALSE)
      resolved[[field]] <- source
    }
    return(list(format = "custom", mapping = resolved))
  }

  has_all <- function(signature) all(tolower(signature) %in% tolower(columns))
  detected <- input_format
  if (identical(input_format, "auto")) {
    matches <- names(.omix_pathway_signatures)[vapply(
      .omix_pathway_signatures, has_all, logical(1)
    )]
    if (length(matches) == 1L) {
      detected <- matches[[1L]]
    } else if (length(matches) == 0L) {
      detected <- "canonical"
    } else {
      stop("Could not auto-detect one pathway-result format. Specify `input_format` or `mapping`.", call. = FALSE)
    }
  }
  requested <- .omix_pathway_presets[[detected]]
  resolved <- vapply(requested, function(candidate) {
    source <- .match_pathway_column(columns, candidate)
    if (is.na(source)) "" else source
  }, character(1))
  list(format = detected, mapping = resolved)
}

.coerce_pathway_numeric <- function(x, field) {
  if (is.numeric(x)) return(as.numeric(x))
  raw <- trimws(as.character(x))
  raw[raw == ""] <- NA_character_
  out <- suppressWarnings(as.numeric(raw))
  invalid <- !is.na(raw) & is.na(out)
  if (any(invalid)) {
    examples <- head(unique(raw[invalid]), 5L)
    stop("Column mapped to `", field, "` contains non-numeric value(s), for example: ", paste(examples, collapse = ", "), call. = FALSE)
  }
  out
}

.validate_pathway_probability <- function(x, field) {
  values <- x[is.finite(x)]
  if (length(values) == 0L || any(values < 0 | values > 1)) {
    stop("Column mapped to `", field, "` must contain numeric probability values from 0 to 1.", call. = FALSE)
  }
}

.normalize_pathway_fraction <- function(x, source, allow_signed = FALSE) {
  values <- x[is.finite(x)]
  if (length(values) == 0L) stop("Column mapped to `fraction` contains no finite numeric values.", call. = FALSE)
  transformations <- character()
  if (any(values < 0)) {
    if (!allow_signed) stop("Column mapped to `fraction` contains negative values.", call. = FALSE)
    x <- abs(x)
    values <- x[is.finite(x)]
    transformations <- c(transformations, paste0("Converted signed L2P fraction source `", source, "` to absolute values."))
  }
  if (all(values <= 1)) return(list(values = x, transformations = transformations))
  if (all(values <= 100)) {
    return(list(
      values = x / 100,
      transformations = c(transformations, paste0("Converted fraction source `", source, "` from percent to fraction scale."))
    ))
  }
  stop("Column mapped to `fraction` must use a 0-1 fraction or 0-100 percent scale.", call. = FALSE)
}

#' Standardize a supported pathway-result table
#'
#' @param data A non-empty data frame in the GSEA, L2P, or canonical OMIX
#'   pathway-result layout.
#' @param input_format One of `auto`, `gsea`, `l2p` (L2P-Multi),
#'   `l2p_single`, or `canonical`.
#' @param mapping Optional named vector mapping canonical fields to source
#'   columns. It is useful for a stable custom upstream table.
#'
#' @return A data frame with canonical `contrast`, `collection`, `pathway`,
#'   `pval` and/or `padj`, `score`, and `size` and/or `fraction` columns.
#' @export
standardize_pathway_results <- function(data, input_format = c("auto", "gsea", "l2p", "l2p_single", "canonical"), mapping = NULL) {
  input_format <- match.arg(input_format)
  if (!is.data.frame(data) || nrow(data) == 0L) stop("`data` must be a non-empty data frame.", call. = FALSE)
  if (anyDuplicated(names(data))) stop("Pathway-result columns must have unique names.", call. = FALSE)
  resolved <- .resolve_pathway_mapping(names(data), input_format, mapping)
  mapping <- resolved$mapping
  required <- c("contrast", "pathway", "score")
  missing_required <- required[!nzchar(mapping[required])]
  if (length(missing_required) > 0L) {
    stop("Pathway-result input is missing required field(s): ", paste(missing_required, collapse = ", "), call. = FALSE)
  }
  if (!any(nzchar(mapping[c("pval", "padj")]))) stop("Pathway-result input needs `pval` or `padj`/FDR.", call. = FALSE)
  if (!any(nzchar(mapping[c("size", "fraction")]))) stop("Pathway-result input needs a hit `size` or `fraction` field.", call. = FALSE)
  mapped_sources <- mapping[nzchar(mapping)]
  duplicated_sources <- unique(mapped_sources[duplicated(mapped_sources)])
  if (length(duplicated_sources) > 0L) {
    stop("One source column cannot map to multiple pathway fields: ", paste(duplicated_sources, collapse = ", "), call. = FALSE)
  }
  out <- data.frame(.row = seq_len(nrow(data)), stringsAsFactors = FALSE)
  for (field in .omix_pathway_fields[nzchar(mapping)]) out[[field]] <- data[[mapping[[field]]]]
  out$.row <- NULL
  transformations <- character()
  if (!"collection" %in% names(out)) {
    out$collection <- "Uncategorized"
    transformations <- c(transformations, "No collection column mapped; assigned `Uncategorized`.")
  }
  for (field in c("contrast", "collection", "pathway")) out[[field]] <- trimws(as.character(out[[field]]))
  out$collection[is.na(out$collection) | !nzchar(out$collection)] <- "Uncategorized"
  if (any(is.na(out$contrast) | !nzchar(out$contrast))) stop("The mapped `contrast` column has missing or empty values.", call. = FALSE)
  if (any(is.na(out$pathway) | !nzchar(out$pathway))) stop("The mapped `pathway` column has missing or empty values.", call. = FALSE)
  for (field in intersect(c("pval", "padj", "score", "size", "fraction"), names(out))) out[[field]] <- .coerce_pathway_numeric(out[[field]], field)
  for (field in intersect(c("pval", "padj"), names(out))) .validate_pathway_probability(out[[field]], field)
  if (!any(is.finite(out$score))) stop("The mapped `score` column contains no finite numeric values.", call. = FALSE)
  if ("size" %in% names(out)) {
    size_values <- out$size[is.finite(out$size)]
    if (length(size_values) == 0L || any(size_values < 0)) stop("The mapped `size` column must contain non-negative numeric values.", call. = FALSE)
  }
  if ("fraction" %in% names(out)) {
    fraction <- .normalize_pathway_fraction(out$fraction, mapping[["fraction"]], allow_signed = identical(resolved$format, "l2p"))
    out$fraction <- fraction$values
    transformations <- c(transformations, fraction$transformations)
  }
  ordered_fields <- c(intersect(c("contrast", "collection", "pathway"), names(out)), intersect(c("pval", "padj", "score", "size", "fraction"), names(out)))
  out <- out[ordered_fields]
  class(out) <- c("omix_pathway_results", class(out))
  attr(out, "omix_pathway_input") <- list(input_format = resolved$format, mapping = mapping, transformations = transformations)
  out
}
