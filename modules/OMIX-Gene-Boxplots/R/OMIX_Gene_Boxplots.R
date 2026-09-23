# OMIX Gene Boxplots workflow wrapper
#
# The scientific and visual implementation is preserved verbatim in
# Boxplot_with_Stats.R. This file intentionally contains only the small
# platform-neutral boundary used by OMIX scripts and deployment adapters.

.omix_gene_boxplots_file <- tryCatch(sys.frame(1L)$ofile, error = function(e) NULL)
if (is.null(.omix_gene_boxplots_file) || !nzchar(.omix_gene_boxplots_file)) {
  stop("ERROR: Source OMIX_Gene_Boxplots.R with source(); its module location is required")
}
.omix_gene_boxplots_dir <- dirname(normalizePath(.omix_gene_boxplots_file, mustWork = TRUE))
source(file.path(.omix_gene_boxplots_dir, "Boxplot_with_Stats.R"))
rm(.omix_gene_boxplots_file, .omix_gene_boxplots_dir)

omix_parse_csv_values <- function(value) {
  if (is.null(value) || !length(value)) return(NULL)
  if (length(value) > 1L) return(as.character(value))
  if (!nzchar(trimws(value[[1L]]))) return(NULL)
  values <- trimws(strsplit(value[[1L]], ",", fixed = TRUE)[[1L]])
  values[nzchar(values)]
}

omix_safe_filename <- function(value) {
  gsub("[^A-Za-z0-9._-]+", "_", as.character(value))
}

omix_validate_table <- function(table, label) {
  if (!is.data.frame(table)) stop("ERROR: `", label, "` must be a data frame")
  if (!nrow(table) || !ncol(table)) stop("ERROR: `", label, "` cannot be empty")
  invisible(table)
}

omix_aggregate_duplicate_genes <- function(
    expression_table,
    sample_metadata,
    gene_column,
    sample_column,
    duplicate_aggregation = c("mean", "sum", "keep")) {
  duplicate_aggregation <- match.arg(duplicate_aggregation)
  if (!gene_column %in% names(expression_table)) {
    stop("ERROR: Gene column not found in expression table: ", gene_column)
  }
  if (!sample_column %in% names(sample_metadata)) {
    stop("ERROR: Sample column not found in metadata table: ", sample_column)
  }

  sample_columns <- sort(intersect(
    unique(as.character(sample_metadata[[sample_column]])),
    names(expression_table)
  ))
  if (!length(sample_columns)) {
    stop("ERROR: No overlapping sample columns found between expression and metadata tables")
  }
  non_numeric <- sample_columns[!vapply(expression_table[sample_columns], is.numeric, logical(1))]
  if (length(non_numeric)) {
    stop(
      "ERROR: Expression sample column(s) must be numeric: ",
      paste(non_numeric, collapse = ", ")
    )
  }
  if (identical(duplicate_aggregation, "keep")) {
    return(expression_table)
  }

  expression_long <- expression_table[, c(gene_column, sample_columns), drop = FALSE] |>
    tidyr::pivot_longer(
      cols = tidyselect::all_of(sample_columns),
      names_to = ".omix_sample",
      values_to = ".omix_value"
    ) |>
    dplyr::group_by(.data[[gene_column]], .data$.omix_sample)

  if (identical(duplicate_aggregation, "mean")) {
    expression_long <- expression_long |>
      dplyr::summarise(
        .omix_value = if (all(is.na(.data$.omix_value))) {
          NA_real_
        } else {
          mean(.data$.omix_value, na.rm = TRUE)
        },
        .groups = "drop"
      )
  } else {
    # Match the preserved legacy behavior exactly, including all-missing
    # gene/sample groups becoming zero under sum(..., na.rm = TRUE).
    expression_long <- expression_long |>
      dplyr::summarise(
        .omix_value = sum(.data$.omix_value, na.rm = TRUE),
        .groups = "drop"
      )
  }

  expression_long |>
    tidyr::pivot_wider(
      names_from = tidyselect::all_of(".omix_sample"),
      values_from = tidyselect::all_of(".omix_value")
    ) |>
    as.data.frame(stringsAsFactors = FALSE)
}

omix_plot_type_to_legacy <- function(plot_type) {
  switch(match.arg(plot_type, c("box", "violin")), "box" = "Box plot", "violin" = "Violin Plot")
}

omix_pvalue_to_legacy <- function(pvalue_type) {
  switch(match.arg(pvalue_type, c("nominal", "adjusted")), "nominal" = "raw", "adjusted" = "adjusted")
}

omix_resolve_legacy_colors <- function(colors) {
  colors <- omix_parse_csv_values(colors)
  if (is.null(colors)) return(NULL)
  known_colors <- names(boxplot_get_colorlist())
  unknown <- setdiff(colors, known_colors)
  if (length(unknown)) {
    stop(
      "ERROR: `colors` must use the original named colors: ",
      paste(known_colors, collapse = ", "),
      ". Unknown value(s): ", paste(unknown, collapse = ", ")
    )
  }
  colors
}

omix_output_files <- function(
    result,
    output_dir,
    statistics_mode,
    duplicate_aggregation) {
  if (is.null(output_dir) || !nzchar(output_dir)) return(list())
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  data_file <- file.path(output_dir, "gene_boxplot_expression_long.csv")
  summary_file <- file.path(output_dir, "gene_boxplot_run_summary.csv")
  utils::write.csv(result$data, data_file, row.names = FALSE)
  utils::write.csv(
    data.frame(
      statistics_mode = statistics_mode,
      duplicate_aggregation = duplicate_aggregation,
      genes_plotted = length(result$plots),
      samples_included = length(unique(result$data$sample)),
      categories = paste(result$valid_categories, collapse = ","),
      stringsAsFactors = FALSE
    ),
    summary_file,
    row.names = FALSE
  )
  list(
    plot_directory = file.path(output_dir, "gene_boxplots"),
    statistics = file.path(output_dir, "gene_boxplot_statistics.csv"),
    expression_long = data_file,
    summary = summary_file
  )
}

#' Run the preserved CCBR gene-boxplot implementation through a compact OMIX
#' workflow interface.
#'
#' The legacy public functions `gene_boxplot_with_stats()` and
#' `gene_boxplot_with_deg_results()` remain available unchanged after sourcing
#' this file. This wrapper only maps portable inputs and standardized outputs.
#'
#' The canonical wrapper intentionally defaults to nominal precomputed p-values
#' and mean aggregation for duplicate gene identifiers in normalized log-space
#' expression. Select `duplicate_aggregation = "sum"` to reproduce the legacy
#' duplicate-row behavior.
omix_gene_boxplots <- function(
    expression_table,
    sample_metadata,
    genes = NULL,
    gene_column = "GeneName",
    sample_column = "Sample",
    category_column = "Group",
    categories = NULL,
    statistics_mode = c("precomputed_deg", "within_plot", "none"),
    deg_results = NULL,
    deg_gene_column = gene_column,
    pvalue_type = c("nominal", "adjusted"),
    statistical_method = c("anova", "t-test", "kruskal"),
    p_adjust_method = "BH",
    duplicate_aggregation = c("mean", "sum", "keep"),
    minimum_samples_per_category = 3L,
    plot_type = c("box", "violin"),
    title = "auto",
    y_axis_label = "auto",
    colors = NULL,
    output_dir = NULL,
    image_width = 5,
    image_height = 5.5,
    image_dpi = 300,
    ...) {
  omix_validate_table(expression_table, "expression_table")
  omix_validate_table(sample_metadata, "sample_metadata")
  duplicate_aggregation_supplied <- !missing(duplicate_aggregation)
  extra_arguments <- list(...)
  if ("sum_duplicates" %in% names(extra_arguments)) {
    legacy_sum_duplicates <- extra_arguments$sum_duplicates
    extra_arguments$sum_duplicates <- NULL
    if (duplicate_aggregation_supplied) {
      stop("ERROR: Supply only `duplicate_aggregation`, not both it and legacy `sum_duplicates`")
    }
    if (!is.logical(legacy_sum_duplicates) || length(legacy_sum_duplicates) != 1L || is.na(legacy_sum_duplicates)) {
      stop("ERROR: Legacy `sum_duplicates` must be one non-missing logical value")
    }
    duplicate_aggregation <- if (legacy_sum_duplicates) "sum" else "keep"
    warning(
      "`sum_duplicates` is deprecated; use `duplicate_aggregation = 'sum'` or 'keep'",
      call. = FALSE
    )
  }
  statistics_mode <- match.arg(statistics_mode)
  pvalue_type <- match.arg(pvalue_type)
  statistical_method <- match.arg(statistical_method)
  duplicate_aggregation <- match.arg(duplicate_aggregation)
  categories <- omix_parse_csv_values(categories)
  colors <- omix_resolve_legacy_colors(colors)
  legacy_plot_type <- omix_plot_type_to_legacy(plot_type)
  expression_table <- omix_aggregate_duplicate_genes(
    expression_table = expression_table,
    sample_metadata = sample_metadata,
    gene_column = gene_column,
    sample_column = sample_column,
    duplicate_aggregation = duplicate_aggregation
  )
  plot_directory <- if (!is.null(output_dir) && nzchar(output_dir)) file.path(output_dir, "gene_boxplots") else NULL
  statistics_file <- if (!is.null(output_dir) && nzchar(output_dir)) file.path(output_dir, "gene_boxplot_statistics.csv") else NULL
  legacy_arguments <- list(
    normalized_counts = expression_table,
    sample_metadata = sample_metadata,
    gene_column = gene_column,
    sample_column = sample_column,
    genes = genes,
    category_column = category_column,
    categories = categories,
    minimum_samples_per_category = as.integer(minimum_samples_per_category),
    plot_type = legacy_plot_type,
    title = title,
    y_axis_title = y_axis_label,
    export_plot_dir = plot_directory,
    export_plot_width = image_width,
    export_plot_height = image_height,
    export_plot_dpi = image_dpi,
    export_stats_file = statistics_file,
    sum_duplicates = identical(duplicate_aggregation, "sum"),
    return_full = TRUE
  )
  if (!is.null(colors)) legacy_arguments$colors_to_use <- colors

  if (identical(statistics_mode, "precomputed_deg")) {
    if (is.null(deg_results)) {
      stop("ERROR: `deg_results` is required when statistics_mode = 'precomputed_deg'")
    }
    omix_validate_table(deg_results, "deg_results")
    legacy_result <- do.call(
      gene_boxplot_with_deg_results,
      c(
        legacy_arguments,
        list(
          deg_results = deg_results,
          deg_gene_column = deg_gene_column,
          pvalue_to_plot = omix_pvalue_to_legacy(pvalue_type)
        ),
        extra_arguments
      )
    )
  } else {
    if (identical(statistics_mode, "none")) legacy_arguments$add_annotations <- FALSE
    legacy_result <- do.call(
      gene_boxplot_with_stats,
      c(
        legacy_arguments,
        list(
          statistical_method = statistical_method,
          p_adjust_method = p_adjust_method
        ),
        extra_arguments
      )
    )
  }

  output_files <- omix_output_files(
    legacy_result,
    output_dir,
    statistics_mode,
    duplicate_aggregation
  )
  invisible(list(
    data = legacy_result$data,
    statistics = legacy_result$stats,
    letters = legacy_result$letters,
    plots = legacy_result$plots,
    output_files = output_files,
    categories = legacy_result$valid_categories,
    duplicate_aggregation = duplicate_aggregation,
    legacy_result = legacy_result
  ))
}
