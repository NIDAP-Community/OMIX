.normalize_pathway_values <- function(values) {
  values <- unique(trimws(as.character(values)))
  values[!is.na(values) & nzchar(values)]
}

.validate_pathway_values <- function(values, available, label) {
  unknown <- setdiff(values, available)
  if (length(unknown) > 0L) {
    stop("Unknown ", label, ": ", paste(unknown, collapse = ", "), call. = FALSE)
  }
  values
}

.top_pathway_names <- function(data, p_value_column, top_n, p_value_cutoff) {
  if (nrow(data) == 0L) return(character())
  pathway_values <- as.character(data$pathway)
  if (top_n == 0L) return(unique(pathway_values))

  valid <- which(
    is.finite(data[[p_value_column]]) &
      data[[p_value_column]] <= p_value_cutoff &
      !is.na(pathway_values) &
      nzchar(pathway_values)
  )
  if (length(valid) == 0L) return(character())
  pathway_p_values <- split(data[[p_value_column]][valid], pathway_values[valid])
  ranked <- data.frame(
    pathway = names(pathway_p_values),
    p_value = vapply(pathway_p_values, min, numeric(1L), na.rm = TRUE),
    stringsAsFactors = FALSE
  )
  ranked <- ranked[order(ranked$p_value, ranked$pathway), , drop = FALSE]
  utils::head(ranked$pathway, top_n)
}

.select_pathway_sources <- function(data, p_value_column, selected_pathways) {
  if (length(selected_pathways) == 0L) {
    return(data.frame(pathway = character(), collection = character(), stringsAsFactors = FALSE))
  }
  candidates <- data[
    as.character(data$pathway) %in% selected_pathways &
      is.finite(data[[p_value_column]]) &
      !is.na(data$collection) &
      nzchar(as.character(data$collection)),
    c("pathway", "collection", p_value_column),
    drop = FALSE
  ]
  names(candidates)[[3L]] <- "p_value"
  candidates <- candidates[order(candidates$pathway, candidates$p_value, candidates$collection), , drop = FALSE]
  candidates <- candidates[!duplicated(candidates$pathway), c("pathway", "collection"), drop = FALSE]
  rownames(candidates) <- NULL
  candidates
}

#' Select pathway rows for legacy-style bubble plots
#'
#' This helper preserves the established application selection policy. It
#' ranks nominal p-values when available (otherwise FDR), applies a 0.05
#' significance cutoff, and retains the top 10 distinct pathway rows by
#' default. Each pathway is ranked by its lowest selected p-value across the
#' selected contrasts. The
#' default scopes return one unfaceted combined-pathway data frame, one
#' cross-collection data frame, and one data frame per collection. The
#' combined-pathway view ranks pathway names across all selected collections,
#' then keeps the collection in which each selected pathway has its lowest
#' selected p-value.
#'
#' @param data A supported GSEA, L2P-Multi, L2P-Single, or canonical pathway
#'   result table.
#' @param input_format Supported input layout or `auto`.
#' @param mapping Optional canonical-to-source column mapping.
#' @param p_value_column `pval` or `padj`; nominal p-values are preferred when
#'   omitted.
#' @param p_value_cutoff Significance threshold for automatic selection.
#' @param top_n_pathways Top ranked distinct pathways per selection scope
#'   (default 20). Use zero to retain all pathways after contrast and
#'   collection filtering.
#' @param selection_scopes Any combination of `combined_single_panel`,
#'   `across_all_collections`, and `within_each_collection`.
#' @param selection_contrasts Contrasts used to identify pathways. Defaults to
#'   all available contrasts.
#' @param plot_contrasts Contrasts shown after pathways are selected, in this
#'   order. Defaults to all available contrasts. A requested contrast with no
#'   retained rows is shown as an empty column.
#' @param collections Collections included in selection and display. Defaults
#'   to all available collections.
#'
#' @return A named list of canonical data frames, with selection provenance in
#'   the `omix_pathway_bubble_selection` attribute.
#' @export
select_pathway_bubble_data <- function(
    data,
    input_format = c("auto", "gsea", "l2p", "l2p_single", "canonical"),
    mapping = NULL,
    p_value_column = NULL,
    p_value_cutoff = 0.05,
    top_n_pathways = 20L,
    selection_scopes = c("combined_single_panel", "across_all_collections", "within_each_collection"),
    selection_contrasts = NULL,
    plot_contrasts = NULL,
    collections = NULL) {
  input_format <- match.arg(input_format)
  data <- standardize_pathway_results(data, input_format = input_format, mapping = mapping)
  p_value_column <- .resolve_pathway_plot_field(data, p_value_column, c("pval", "padj"))
  p_value_cutoff <- as.numeric(p_value_cutoff)[1L]
  if (!is.finite(p_value_cutoff) || p_value_cutoff < 0 || p_value_cutoff > 1) {
    stop("`p_value_cutoff` must be between 0 and 1.", call. = FALSE)
  }
  top_n_pathways <- suppressWarnings(as.integer(top_n_pathways)[1L])
  if (is.na(top_n_pathways) || top_n_pathways < 0L) {
    stop("`top_n_pathways` must be a non-negative integer.", call. = FALSE)
  }

  valid_scopes <- c("combined_single_panel", "across_all_collections", "within_each_collection")
  selection_scopes <- .normalize_pathway_values(selection_scopes)
  if (length(selection_scopes) == 0L || any(!selection_scopes %in% valid_scopes)) {
    stop("`selection_scopes` must include combined_single_panel, across_all_collections, and/or within_each_collection.", call. = FALSE)
  }

  available_contrasts <- unique(as.character(data$contrast))
  available_collections <- unique(as.character(data$collection))
  selection_contrasts <- if (is.null(selection_contrasts)) available_contrasts else .normalize_pathway_values(selection_contrasts)
  plot_contrasts <- if (is.null(plot_contrasts)) available_contrasts else .normalize_pathway_values(plot_contrasts)
  collections <- if (is.null(collections)) available_collections else .normalize_pathway_values(collections)
  selection_contrasts <- .validate_pathway_values(selection_contrasts, available_contrasts, "selection contrast(s)")
  # Plot contrast order may intentionally include a requested contrast with no
  # retained rows, so the renderer can draw an empty column rather than imply
  # that the comparison was never part of the analysis. Selection contrasts,
  # by contrast, must have data available for pathway ranking.
  if (length(plot_contrasts) == 0L) {
    stop("At least one plot contrast is required.", call. = FALSE)
  }
  collections <- .validate_pathway_values(collections, available_collections, "collection(s)")

  base_data <- data[
    as.character(data$collection) %in% collections,
    , drop = FALSE
  ]
  ranking_data <- base_data[
    as.character(base_data$contrast) %in% selection_contrasts,
    , drop = FALSE
  ]
  output <- list()
  selection_details <- list()

  if ("combined_single_panel" %in% selection_scopes) {
    selected_pathways <- .top_pathway_names(
      ranking_data, p_value_column, top_n_pathways, p_value_cutoff
    )
    selected_sources <- .select_pathway_sources(
      ranking_data, p_value_column, selected_pathways
    )
    source_lookup <- stats::setNames(selected_sources$collection, selected_sources$pathway)
    rows <- base_data[
      as.character(base_data$contrast) %in% plot_contrasts &
        as.character(base_data$pathway) %in% selected_pathways &
        as.character(base_data$collection) == unname(source_lookup[as.character(base_data$pathway)]),
      , drop = FALSE
    ]
    if (nrow(rows) > 0L) output[["Combined Pathways"]] <- rows
    selection_details[["Combined Pathways"]] <- list(
      scope = "combined_single_panel",
      selected_pathways = selected_pathways,
      selected_pathway_sources = selected_sources,
      selected_row_count = nrow(rows)
    )
  }

  if ("across_all_collections" %in% selection_scopes) {
    selected_pathways <- .top_pathway_names(
      ranking_data, p_value_column, top_n_pathways, p_value_cutoff
    )
    rows <- base_data[
      as.character(base_data$contrast) %in% plot_contrasts &
        as.character(base_data$pathway) %in% selected_pathways,
      , drop = FALSE
    ]
    if (nrow(rows) > 0L) output[["Across Collections"]] <- rows
    selection_details[["Across Collections"]] <- list(
      scope = "across_all_collections",
      selected_pathways = selected_pathways,
      selected_row_count = nrow(rows)
    )
  }

  if ("within_each_collection" %in% selection_scopes) {
    for (collection in collections) {
      collection_base <- base_data[as.character(base_data$collection) == collection, , drop = FALSE]
      collection_ranking <- ranking_data[as.character(ranking_data$collection) == collection, , drop = FALSE]
      selected_pathways <- .top_pathway_names(
        collection_ranking, p_value_column, top_n_pathways, p_value_cutoff
      )
      rows <- collection_base[
        as.character(collection_base$contrast) %in% plot_contrasts &
          as.character(collection_base$pathway) %in% selected_pathways,
        , drop = FALSE
      ]
      if (nrow(rows) > 0L) output[[collection]] <- rows
      selection_details[[collection]] <- list(
        scope = "within_each_collection",
        selected_pathways = selected_pathways,
        selected_row_count = nrow(rows)
      )
    }
  }

  if (length(output) == 0L) {
    stop(
      "No pathway rows passed the automatic selection. Consider a larger `top_n_pathways`, a higher `p_value_cutoff`, or `top_n_pathways = 0`.",
      call. = FALSE
    )
  }

  attr(output, "omix_pathway_bubble_selection") <- list(
    p_value_column = p_value_column,
    p_value_cutoff = p_value_cutoff,
    top_n_pathways = top_n_pathways,
    selection_scopes = selection_scopes,
    selection_contrasts = selection_contrasts,
    plot_contrasts = plot_contrasts,
    collections = collections,
    details = selection_details
  )
  class(output) <- c("omix_pathway_bubble_selection", class(output))
  output
}

#' Create legacy-style selected pathway bubble plots
#'
#' @inheritParams select_pathway_bubble_data
#' @inheritParams plot_pathway_bubble
#' @param collection_color_scale Whether collection-specific plots use an
#'   `"independent"` color scale based on their displayed pathways or the
#'   `"shared"` scale used by combined plots. An explicit `color_limits`
#'   always takes precedence.
#'
#' @return A named list of `ggplot` objects. Defaults return one unfaceted
#'   `Combined Pathways` plot, one `Across Collections` plot, and one plot per
#'   collection. Combined and across-collection plots use a shared colour
#'   range; collection-specific plots use their own range unless sharing is
#'   requested.
#' @export
plot_pathway_bubble_set <- function(
    data,
    input_format = c("auto", "gsea", "l2p", "l2p_single", "canonical"),
    mapping = NULL,
    p_value_column = NULL,
    p_value_cutoff = 0.05,
    top_n_pathways = 20L,
    selection_scopes = c("combined_single_panel", "across_all_collections", "within_each_collection"),
    selection_contrasts = NULL,
    plot_contrasts = NULL,
    collections = NULL,
    show_non_significant = TRUE,
    contrast_labels = NULL,
    layout_style = c("facet", "panel"),
    facet_title_mode = c("full collection name", "main collection"),
    dynamic_pathway_font_size = TRUE,
    pathway_font_size = 6,
    pathway_wrap_width = NULL,
    pathway_label_angle = 0,
    contrast_font_size = 12,
    contrast_label_angle = 30,
    vertical_lines = numeric(),
    vertical_line_type = c("dashed", "solid", "dotted"),
    figure_aspect = 2.5,
    palette = "blue_vermilion",
    color_range_method = c("symmetric_percentile", "symmetric_fixed", "custom"),
    color_percentile = 99,
    color_symmetric_limit = 2,
    color_limits = NULL,
    collection_color_scale = c("independent", "shared"),
    size_by = NULL,
    size_range = c(2, 14)) {
  input_format <- match.arg(input_format)
  layout_style <- match.arg(layout_style)
  facet_title_mode <- match.arg(facet_title_mode)
  vertical_line_type <- match.arg(vertical_line_type)
  color_range_method <- match.arg(color_range_method)
  collection_color_scale <- match.arg(collection_color_scale)

  selected <- select_pathway_bubble_data(
    data = data,
    input_format = input_format,
    mapping = mapping,
    p_value_column = p_value_column,
    p_value_cutoff = p_value_cutoff,
    top_n_pathways = top_n_pathways,
    selection_scopes = selection_scopes,
    selection_contrasts = selection_contrasts,
    plot_contrasts = plot_contrasts,
    collections = collections
  )
  selection <- attr(selected, "omix_pathway_bubble_selection")
  p_value_column <- selection$p_value_column
  combined <- do.call(rbind, unname(selected))
  color_rows <- combined[!duplicated(combined[c("contrast", "collection", "pathway", "score")]), , drop = FALSE]
  shared_color_limits <- if (is.null(color_limits)) {
    pathway_bubble_color_limits(
      color_rows$score,
      method = color_range_method,
      percentile = color_percentile,
      fixed_limit = color_symmetric_limit
    )$limits
  } else {
    as.numeric(color_limits)
  }

  plot_color_limits <- lapply(names(selected), function(name) {
    scope <- selection$details[[name]]$scope
    if (!is.null(color_limits) ||
        !identical(scope, "within_each_collection") ||
        identical(collection_color_scale, "shared")) {
      return(shared_color_limits)
    }

    rows <- selected[[name]]
    color_rows <- rows[!duplicated(rows[c("contrast", "collection", "pathway", "score")]), , drop = FALSE]
    pathway_bubble_color_limits(
      color_rows$score,
      method = color_range_method,
      percentile = color_percentile,
      fixed_limit = color_symmetric_limit
    )$limits
  })
  names(plot_color_limits) <- names(selected)

  plots <- lapply(names(selected), function(name) {
    rows <- selected[[name]]
    scope <- selection$details[[name]]$scope
    # A selected pathway set need not have a row in every requested contrast.
    # Keep those empty contrast columns visible so their absence is not
    # mistaken for a comparison that was never run.
    plot_contrast_order <- selection$plot_contrasts
    plot_pathway_bubble(
      data = rows,
      input_format = "canonical",
      p_value_column = p_value_column,
      p_value_cutoff = p_value_cutoff,
      show_non_significant = show_non_significant,
      contrast_order = plot_contrast_order,
      retain_empty_contrasts = TRUE,
      contrast_labels = contrast_labels,
      layout_style = if (identical(scope, "combined_single_panel")) "panel" else layout_style,
      facet_title_mode = facet_title_mode,
      dynamic_pathway_font_size = dynamic_pathway_font_size,
      pathway_font_size = pathway_font_size,
      pathway_wrap_width = pathway_wrap_width,
      # Combined single-panel plots need source prefixes for row identity.
      # Faceted views and one-collection figures already identify the source
      # in their facet strip or title, so a repeated prefix is redundant.
      include_source_prefix = identical(scope, "combined_single_panel"),
      pathway_label_angle = pathway_label_angle,
      contrast_font_size = contrast_font_size,
      contrast_label_angle = contrast_label_angle,
      vertical_lines = vertical_lines,
      vertical_line_type = vertical_line_type,
      figure_aspect = figure_aspect,
      palette = palette,
      color_limits = plot_color_limits[[name]],
      size_by = size_by,
      size_range = size_range
    )
  })
  names(plots) <- names(selected)
  attr(plots, "omix_pathway_bubble_selection") <- selection
  attr(plots, "omix_pathway_bubble_color_limits") <- shared_color_limits
  attr(plots, "omix_pathway_bubble_color_scales") <- plot_color_limits
  attr(plots, "omix_pathway_bubble_collection_color_scale") <- collection_color_scale
  attr(plots, "omix_pathway_bubble_dimensions") <- lapply(
    plots,
    attr,
    which = "omix_pathway_plot_dimensions"
  )
  class(plots) <- c("omix_pathway_bubble_set", class(plots))
  plots
}
