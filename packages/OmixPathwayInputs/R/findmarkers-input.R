# Shared Seurat FindMarkers DEG-table compatibility for pathway modules.
#
# This file intentionally uses base R only. Canonical pathway CLIs source this
# one implementation so L2P Single, L2P Multi, and GSEA do not maintain three
# independent guesses about Seurat column names. The statistical modules still
# own their analysis thresholds and enrichment methods.

.omix_findmarkers_nonempty <- function(x) {
  !is.null(x) && length(x) > 0L && !is.na(x[[1L]]) &&
    nzchar(trimws(as.character(x[[1L]])))
}

.omix_findmarkers_labels <- function(x) {
  if (is.null(x) || length(x) == 0L) {
    return(character())
  }
  if (length(x) == 1L && !is.na(x[[1L]])) {
    x <- strsplit(as.character(x[[1L]]), ",", fixed = TRUE)[[1L]]
  }
  x <- trimws(as.character(x))
  x <- x[!is.na(x) & nzchar(x)]
  if (anyDuplicated(x)) {
    stop(
      "ERROR: Comparison labels must be unique: ",
      paste(x, collapse = ", "),
      call. = FALSE
    )
  }
  x
}

.omix_findmarkers_default_rownames <- function(x) {
  identical(rownames(x), as.character(seq_len(nrow(x))))
}

.omix_findmarkers_gene_column <- function(data, requested, native_profile) {
  columns <- names(data)
  if (.omix_findmarkers_nonempty(requested)) {
    requested <- trimws(as.character(requested[[1L]]))
    exact <- which(columns == requested)
    if (length(exact) != 1L) {
      stop(
        "ERROR: Explicit gene column `", requested,
        "` was not found exactly once. Available columns: ",
        paste(columns, collapse = ", "),
        call. = FALSE
      )
    }
    return(list(data = data, column = columns[[exact]]))
  }

  candidates <- c(
    "GeneName", "Gene Symbols", "Gene", "gene", "GeneSymbol",
    "gene_symbol", "Gene_Symbol", "symbol", "Symbol", "gene_name",
    "Gene_Name", "gene_names", "Gene_Names", "gene_id", "GeneID",
    "Gene_ID"
  )
  detected <- unique(candidates[candidates %in% columns])
  if (length(detected) > 1L) {
    stop(
      "ERROR: Multiple possible gene columns were found: ",
      paste(detected, collapse = ", "),
      ". Supply an explicit gene-column override.",
      call. = FALSE
    )
  }
  if (length(detected) == 1L) {
    return(list(data = data, column = detected[[1L]]))
  }

  # read.csv(check.names = FALSE) preserves the empty header written by
  # write.csv(..., row.names = TRUE). Treat it as a gene column only after the
  # table has already been identified as a native FindMarkers result.
  unnamed <- which(!nzchar(columns))
  if (isTRUE(native_profile) && length(unnamed) == 1L) {
    alias <- ".omix_gene"
    if (alias %in% columns) {
      stop(
        "ERROR: Cannot create the internal gene alias `", alias,
        "` because that column already exists.",
        call. = FALSE
      )
    }
    data[[alias]] <- data[[unnamed]]
    return(list(data = data, column = alias))
  }

  # Some CSV readers repair the empty row-name header to `X`. Accept it only
  # as the first column of an already-recognized native profile; never treat a
  # generic `X` column as a gene identifier in other DEG layouts.
  if (isTRUE(native_profile) && length(columns) > 0L && identical(columns[[1L]], "X")) {
    return(list(data = data, column = "X"))
  }

  # Native R FindMarkers objects commonly keep genes in row names. Sequential
  # row numbers are not biological identifiers and are deliberately rejected.
  if (isTRUE(native_profile) && !.omix_findmarkers_default_rownames(data)) {
    alias <- ".omix_gene"
    if (alias %in% columns) {
      stop(
        "ERROR: Cannot create the internal gene alias `", alias,
        "` because that column already exists.",
        call. = FALSE
      )
    }
    data[[alias]] <- rownames(data)
    return(list(data = data, column = alias))
  }

  stop(
    "ERROR: A gene identifier could not be resolved for the FindMarkers table. ",
    "Supply an explicit gene-column override, retain gene row names in an RDS, ",
    "or export genes in a named column such as `Gene`.",
    call. = FALSE
  )
}

.omix_findmarkers_suffix_specs <- function() {
  list(
    nominal = c("_pval", "_p_val"),
    adjusted = c("_adjpval", "_p_val_adj"),
    fold_change = c("_logFC", "_avg_log2FC", "_avg_logFC"),
    pct1 = c("_pct1", "_pct.1"),
    pct2 = c("_pct2", "_pct.2")
  )
}

.omix_findmarkers_match_wide_columns <- function(columns) {
  specs <- .omix_findmarkers_suffix_specs()
  matches <- vector("list", length(columns))
  for (index in seq_along(columns)) {
    column <- columns[[index]]
    found <- NULL
    for (statistic in names(specs)) {
      suffix_hits <- specs[[statistic]][endsWith(column, specs[[statistic]])]
      if (length(suffix_hits) > 1L) {
        stop(
          "ERROR: FindMarkers column `", column,
          "` matches more than one supported suffix.",
          call. = FALSE
        )
      }
      if (length(suffix_hits) == 1L) {
        suffix <- suffix_hits[[1L]]
        prefix <- substr(column, 1L, nchar(column) - nchar(suffix))
        if (nzchar(prefix)) {
          found <- list(
            column = column,
            comparison = prefix,
            statistic = statistic,
            suffix = suffix,
            column_index = index
          )
        }
      }
    }
    matches[[index]] <- found
  }
  Filter(Negate(is.null), matches)
}

.omix_findmarkers_one_column <- function(matches, comparison, statistic) {
  selected <- vapply(
    matches,
    function(x) identical(x$comparison, comparison) &&
      identical(x$statistic, statistic),
    logical(1)
  )
  columns <- vapply(matches[selected], `[[`, character(1), "column")
  if (length(columns) > 1L) {
    stop(
      "ERROR: FindMarkers comparison `", comparison,
      "` has multiple candidate ", statistic, " columns: ",
      paste(columns, collapse = ", "),
      ". Use explicit pathway-module column controls.",
      call. = FALSE
    )
  }
  if (length(columns) == 0L) NA_character_ else columns[[1L]]
}

.omix_findmarkers_add_alias <- function(data, alias, source) {
  if (is.na(source) || !nzchar(source)) {
    return(data)
  }
  if (alias %in% names(data)) {
    # The alias may already be the source column in the supplied wide table.
    if (!identical(alias, source) && !identical(data[[alias]], data[[source]])) {
      stop(
        "ERROR: Cannot normalize FindMarkers column `", source,
        "` to `", alias, "` because the alias already contains different values.",
        call. = FALSE
      )
    }
    return(data)
  }
  data[[alias]] <- data[[source]]
  data
}

#' Normalize a Seurat FindMarkers DEG table for OMIX pathway modules
#'
#' Recognizes comparison-prefixed wide exports and native one-comparison
#' Seurat `FindMarkers()` tables. The returned profile identifies source
#' columns and adds deterministic `<comparison>_pval`, `_adjpval`, and
#' `_logFC` aliases where needed. Percentage-detection columns are recorded but
#' are never used as pathway statistics.
#'
#' Native unprefixed tables require exactly one caller-supplied comparison
#' label. Wide-table comparisons are returned in first source-column order;
#' an explicit comparison list selects and reorders them.
#'
#' @param data A differential-expression data frame.
#' @param gene_column Optional exact gene-identifier column.
#' @param comparison_labels Optional character vector or comma-separated list.
#' @return `NULL` when the table is not a recognized FindMarkers profile;
#'   otherwise a list containing normalized data, format, gene column,
#'   ordered comparisons, source mappings, canonical analysis mappings, and
#'   ignored percentage-detection columns.
#' @export
normalize_findmarkers_deg_input <- function(
    data,
    gene_column = NULL,
    comparison_labels = character()) {
  if (!is.data.frame(data)) {
    stop("ERROR: `data` must be a data frame.", call. = FALSE)
  }
  if (anyDuplicated(names(data))) {
    duplicated_names <- unique(names(data)[duplicated(names(data))])
    stop(
      "ERROR: DEG table contains duplicate column names: ",
      paste(duplicated_names, collapse = ", "),
      call. = FALSE
    )
  }

  requested <- .omix_findmarkers_labels(comparison_labels)
  columns <- names(data)
  native_fold <- intersect(c("avg_log2FC", "avg_logFC"), columns)
  native_signature <- any(c(
    "p_val", "p_val_adj", "avg_log2FC", "avg_logFC", "pct.1", "pct.2"
  ) %in% columns)

  if (isTRUE(native_signature)) {
    required_missing <- character()
    if (!any(c("p_val", "p_val_adj") %in% columns)) {
      required_missing <- c(required_missing, "p_val or p_val_adj")
    }
    if (length(native_fold) == 0L) {
      required_missing <- c(required_missing, "avg_log2FC or avg_logFC")
    }
    if (length(required_missing) > 0L) {
      stop(
        "ERROR: The table resembles a native Seurat FindMarkers result but is missing: ",
        paste(required_missing, collapse = ", "), ".",
        call. = FALSE
      )
    }
    if (length(native_fold) > 1L) {
      stop(
        "ERROR: Native FindMarkers input has both `avg_log2FC` and `avg_logFC`. ",
        "Remove one or use an explicit custom mapping outside automatic mode.",
        call. = FALSE
      )
    }
    if (length(requested) != 1L) {
      stop(
        "ERROR: A native unprefixed FindMarkers table requires exactly one ",
        "user-supplied comparison label for output naming.",
        call. = FALSE
      )
    }

    gene <- .omix_findmarkers_gene_column(data, gene_column, native_profile = TRUE)
    data <- gene$data
    comparison <- requested[[1L]]
    nominal <- if ("p_val" %in% columns) "p_val" else NA_character_
    adjusted <- if ("p_val_adj" %in% columns) "p_val_adj" else NA_character_
    fold <- native_fold[[1L]]
    data <- .omix_findmarkers_add_alias(data, paste0(comparison, "_pval"), nominal)
    data <- .omix_findmarkers_add_alias(data, paste0(comparison, "_adjpval"), adjusted)
    data <- .omix_findmarkers_add_alias(data, paste0(comparison, "_logFC"), fold)

    ignored <- intersect(c("pct.1", "pct.2"), columns)
    return(list(
      data = data,
      format = "seurat_findmarkers_native",
      gene_column = gene$column,
      comparisons = comparison,
      source_columns = list(
        nominal = stats::setNames(nominal, comparison),
        adjusted = stats::setNames(adjusted, comparison),
        fold_change = stats::setNames(fold, comparison)
      ),
      analysis_columns = list(
        nominal = stats::setNames(
          if (is.na(nominal)) NA_character_ else paste0(comparison, "_pval"),
          comparison
        ),
        adjusted = stats::setNames(
          if (is.na(adjusted)) NA_character_ else paste0(comparison, "_adjpval"),
          comparison
        ),
        fold_change = stats::setNames(paste0(comparison, "_logFC"), comparison),
        rank = stats::setNames(paste0(comparison, "_logFC"), comparison)
      ),
      ignored_percentage_columns = ignored
    ))
  }

  matches <- .omix_findmarkers_match_wide_columns(columns)
  if (length(matches) == 0L) {
    return(NULL)
  }

  comparison_order <- unique(vapply(matches, `[[`, character(1), "comparison"))
  mappings <- lapply(comparison_order, function(comparison) {
    c(
      nominal = .omix_findmarkers_one_column(matches, comparison, "nominal"),
      adjusted = .omix_findmarkers_one_column(matches, comparison, "adjusted"),
      fold_change = .omix_findmarkers_one_column(matches, comparison, "fold_change"),
      pct1 = .omix_findmarkers_one_column(matches, comparison, "pct1"),
      pct2 = .omix_findmarkers_one_column(matches, comparison, "pct2")
    )
  })
  names(mappings) <- comparison_order

  looks_findmarkers <- vapply(mappings, function(x) {
    distinctive_fold <- !is.na(x[["fold_change"]]) &&
      grepl("_(avg_log2FC|avg_logFC)$", x[["fold_change"]])
    percentage_pair <- !is.na(x[["pct1"]]) && !is.na(x[["pct2"]])
    distinctive_fold || percentage_pair
  }, logical(1))
  complete <- vapply(mappings, function(x) {
    !is.na(x[["fold_change"]]) &&
      (!is.na(x[["nominal"]]) || !is.na(x[["adjusted"]]))
  }, logical(1))

  if (!any(looks_findmarkers)) {
    return(NULL)
  }
  incomplete_findmarkers <- names(mappings)[looks_findmarkers & !complete]
  if (length(incomplete_findmarkers) > 0L) {
    stop(
      "ERROR: FindMarkers comparison(s) lack a log-fold-change column or a ",
      "nominal/adjusted p-value column: ",
      paste(incomplete_findmarkers, collapse = ", "), ".",
      call. = FALSE
    )
  }

  available <- comparison_order[looks_findmarkers & complete]
  if (length(requested) > 0L) {
    unknown <- setdiff(requested, available)
    if (length(unknown) > 0L) {
      stop(
        "ERROR: Requested FindMarkers comparison(s) were not found: ",
        paste(unknown, collapse = ", "),
        ". Available comparisons: ", paste(available, collapse = ", "),
        call. = FALSE
      )
    }
    available <- requested
  }

  gene <- .omix_findmarkers_gene_column(data, gene_column, native_profile = FALSE)
  data <- gene$data
  source_nominal <- source_adjusted <- source_fold <- character(length(available))
  names(source_nominal) <- names(source_adjusted) <- names(source_fold) <- available
  ignored <- character()

  for (comparison in available) {
    mapping <- mappings[[comparison]]
    source_nominal[[comparison]] <- mapping[["nominal"]]
    source_adjusted[[comparison]] <- mapping[["adjusted"]]
    source_fold[[comparison]] <- mapping[["fold_change"]]
    data <- .omix_findmarkers_add_alias(
      data, paste0(comparison, "_pval"), mapping[["nominal"]]
    )
    data <- .omix_findmarkers_add_alias(
      data, paste0(comparison, "_adjpval"), mapping[["adjusted"]]
    )
    data <- .omix_findmarkers_add_alias(
      data, paste0(comparison, "_logFC"), mapping[["fold_change"]]
    )
    ignored <- c(ignored, mapping[c("pct1", "pct2")])
  }
  ignored <- unique(unname(ignored[!is.na(ignored)]))

  list(
    data = data,
    format = "seurat_findmarkers_wide",
    gene_column = gene$column,
    comparisons = available,
    source_columns = list(
      nominal = source_nominal,
      adjusted = source_adjusted,
      fold_change = source_fold
    ),
    analysis_columns = list(
      nominal = stats::setNames(
        ifelse(is.na(source_nominal), NA_character_, paste0(available, "_pval")),
        available
      ),
      adjusted = stats::setNames(
        ifelse(is.na(source_adjusted), NA_character_, paste0(available, "_adjpval")),
        available
      ),
      fold_change = stats::setNames(paste0(available, "_logFC"), available),
      rank = stats::setNames(paste0(available, "_logFC"), available)
    ),
    ignored_percentage_columns = ignored
  )
}
