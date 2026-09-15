.omix_pathway_palettes <- list(
  blue_vermilion = list(label = "Blue-Vermilion (default)", colors = c("#053061", "#2166AC", "#92C5DE", "#F7F7F7", "#FDDBC7", "#EF8A62", "#B2182B")),
  blue_red = list(label = "Blue-Red (classic)", colors = c("#08306B", "#2171B5", "#9ECAE1", "#F7F7F7", "#F4C2C2", "#E05A6A", "#B2182B")),
  green_purple = list(label = "Green-Purple", colors = c("#1B5E20", "#43A047", "#A5D6A7", "#F7F7F7", "#CE93D8", "#7B1FA2", "#4A1486")),
  blue_red_muted = list(label = "Blue-Red (muted)", colors = c("#365A7D", "#6F8FAF", "#B9CDDD", "#F5F3F3", "#E5C5C8", "#C97782", "#8F414D")),
  blue_orange_cb = list(label = "Blue-Orange (colorblind-friendly)", colors = c("#004488", "#2B83BA", "#ABD9E9", "#F7F7F7", "#FDD17A", "#F28E2B", "#A64B00"))
)

#' Get a curated pathway bubble-plot palette
#'
#' @param palette Palette identifier. `blue_vermilion` is the established default.
#' @return A list containing the palette id, label, and seven colour anchors.
#' @export
pathway_bubble_palette <- function(palette = "blue_vermilion") {
  palette <- as.character(palette)[1L]
  if (is.na(palette) || !palette %in% names(.omix_pathway_palettes)) {
    stop("Choose one of: ", paste(names(.omix_pathway_palettes), collapse = ", "), call. = FALSE)
  }
  c(list(id = palette), .omix_pathway_palettes[[palette]])
}

#' Compute an automatic pathway-label size
#' @param n_pathways Number of unique displayed pathways.
#' @return An integer font size from 6 to 20.
#' @export
pathway_bubble_dynamic_font_size <- function(n_pathways, min_font_size = 6, max_font_size = 20) {
  n_pathways <- as.numeric(n_pathways)[1L]
  if (!is.finite(n_pathways) || n_pathways < 0) stop("`n_pathways` must be a non-negative finite number.", call. = FALSE)
  if (n_pathways == 0) return(as.integer(max_font_size))
  font_size <- if (n_pathways <= 10) {
    max_font_size / (n_pathways ^ 0.1)
  } else if (n_pathways <= 20) {
    14
  } else if (n_pathways <= 35) {
    12
  } else if (n_pathways <= 55) {
    10
  } else {
    8
  }
  as.integer(round(max(min(font_size, max_font_size), min_font_size)))
}

#' Choose an automatic pathway-label wrap width
#'
#' @param n_pathways Number of unique displayed pathways.
#' @return A maximum number of characters per displayed label line.
#' @export
pathway_bubble_wrap_width <- function(n_pathways) {
  n_pathways <- suppressWarnings(as.integer(n_pathways)[1L])
  if (is.na(n_pathways) || n_pathways < 1L) {
    stop("`n_pathways` must be a positive integer.", call. = FALSE)
  }
  if (n_pathways <= 10L) return(28L)
  if (n_pathways <= 20L) return(26L)
  if (n_pathways <= 35L) return(24L)
  if (n_pathways <= 55L) return(22L)
  22L
}

.omix_pathway_source_labels <- c(
  H = "Hallmark",
  HALLMARK = "Hallmark",
  REACTOME = "Reactome",
  KEGG = "KEGG",
  GO = "GO"
)

.pathway_sentence_case <- function(value) {
  value <- stringr::str_squish(gsub("_", " ", as.character(value), fixed = TRUE))
  if (is.na(value) || !nzchar(value)) return(value)
  is_all_upper <- !grepl("[[:lower:]]", value) && grepl("[[:upper:]]", value)
  label <- if (is_all_upper) {
    # An all-uppercase source label can contain ordinary words and biological
    # identifiers alike. Without source-provided display metadata, a general
    # function cannot distinguish the two reliably, so retain its exact case.
    value
  } else {
    paste0(toupper(substr(value, 1L, 1L)), substr(value, 2L, nchar(value)))
  }
  label
}

#' Format pathway labels for a consistent plot axis
#'
#' The source data remain unchanged. This formatter only standardizes the
#' displayed label: it preserves the capitalization of all-uppercase source
#' labels, capitalizes lower-case labels, and turns recognized MSigDB source
#' prefixes into a consistent `Source: term` form. Source prefixes can be
#' suppressed when a figure already represents a single collection.
#'
#' @param pathways Character vector of raw pathway labels.
#' @param include_source_prefix Whether to retain a recognized source prefix in
#'   the displayed label.
#' @param collections Optional source-collection vector parallel to `pathways`.
#'   This supports result formats, such as L2P, that record the source in a
#'   separate collection column rather than in each pathway name.
#' @return A character vector of formatted labels.
#' @export
pathway_bubble_format_labels <- function(pathways, include_source_prefix = TRUE, collections = NULL) {
  pathways <- as.character(pathways)
  include_source_prefix <- isTRUE(include_source_prefix)
  if (is.null(collections)) {
    collections <- rep(NA_character_, length(pathways))
  } else {
    collections <- as.character(collections)
    if (length(collections) == 1L) collections <- rep(collections, length(pathways))
    if (length(collections) != length(pathways)) {
      stop("`collections` must have length one or the same length as `pathways`.", call. = FALSE)
    }
  }
  vapply(seq_along(pathways), function(index) {
    pathway <- pathways[[index]]
    collection <- collections[[index]]
    raw <- stringr::str_squish(gsub("_", " ", pathway, fixed = TRUE))
    if (is.na(raw) || !nzchar(raw)) return(raw)
    source_match <- regexec("^([[:upper:]]+)[[:space:]:_-]+(.+)$", raw, perl = TRUE)
    components <- regmatches(raw, source_match)[[1L]]
    embedded_source <- if (length(components) == 3L && components[[2L]] %in% names(.omix_pathway_source_labels)) components[[2L]] else NA_character_
    term <- if (!is.na(embedded_source)) components[[3L]] else raw
    collection_key <- toupper(trimws(collection))
    collection_source <- if (!is.na(collection_key) && collection_key %in% names(.omix_pathway_source_labels)) {
      collection_key
    } else if (!is.na(collection_key) && grepl("REACTOME", collection_key, fixed = TRUE)) {
      "REACTOME"
    } else if (!is.na(collection_key) && grepl("HALLMARK", collection_key, fixed = TRUE)) {
      "HALLMARK"
    } else {
      NA_character_
    }
    source <- if (!is.na(embedded_source)) embedded_source else collection_source
    label <- .pathway_sentence_case(term)
    if (!include_source_prefix || is.na(source)) return(label)
    paste0(.omix_pathway_source_labels[[source]], ": ", label)
  }, character(1L), USE.NAMES = FALSE)
}

#' Calculate automatic pathway bubble-plot dimensions
#'
#' The legacy bubble diameter is retained. Rather than reducing it as more
#' pathways are shown, this helper increases the output height enough to keep
#' neighbouring pathway rows distinct. The width grows with the number of
#' visible collection panels.
#'
#' @param n_pathways Number of unique displayed pathways.
#' @param n_collections Number of visible collection panels.
#' @param minimum_width Minimum output width in inches.
#' @param width_per_additional_collection Additional width in inches for each
#'   collection after the first.
#' @param minimum_height Minimum output height in inches.
#' @param height_per_pathway Output height allocated to each displayed pathway
#'   in inches.
#' @param vertical_padding Fixed vertical space in inches for titles, axes, and
#'   legends.
#' @param longest_pathway_label Number of characters in the longest displayed
#'   pathway label. This lets the width reserve space for unwrapped labels.
#' @param figure_aspect Height-to-width ratio of each pathway panel.
#' @param label_character_width Estimated width in inches per pathway-label
#'   character.
#' @param legend_width Width in inches reserved for legends.
#' @return A list containing recommended `width` and `height` in inches and the
#'   counts used to calculate them.
#' @export
pathway_bubble_dimensions <- function(
    n_pathways,
    n_collections = 1L,
    minimum_width = 11,
    width_per_additional_collection = 3.5,
    minimum_height = 7,
    height_per_pathway = 0.65,
    vertical_padding = 2.5,
    longest_pathway_label = 0L,
    figure_aspect = 2.5,
    label_character_width = 0.08,
    legend_width = 1.8) {
  n_pathways <- suppressWarnings(as.integer(n_pathways)[1L])
  n_collections <- suppressWarnings(as.integer(n_collections)[1L])
  longest_pathway_label <- suppressWarnings(as.integer(longest_pathway_label)[1L])
  numeric_arguments <- c(
    minimum_width = minimum_width,
    width_per_additional_collection = width_per_additional_collection,
    minimum_height = minimum_height,
    height_per_pathway = height_per_pathway,
    vertical_padding = vertical_padding,
    figure_aspect = figure_aspect,
    label_character_width = label_character_width,
    legend_width = legend_width
  )
  numeric_arguments <- vapply(
    numeric_arguments,
    function(value) suppressWarnings(as.numeric(value)[1L]),
    numeric(1L)
  )
  if (is.na(n_pathways) || n_pathways < 1L) {
    stop("`n_pathways` must be a positive integer.", call. = FALSE)
  }
  if (is.na(n_collections) || n_collections < 1L) {
    stop("`n_collections` must be a positive integer.", call. = FALSE)
  }
  if (is.na(longest_pathway_label) || longest_pathway_label < 0L) {
    stop("`longest_pathway_label` must be a non-negative integer.", call. = FALSE)
  }
  if (any(!is.finite(numeric_arguments)) || any(numeric_arguments < 0) ||
      numeric_arguments[["minimum_width"]] == 0 || numeric_arguments[["minimum_height"]] == 0 ||
      numeric_arguments[["height_per_pathway"]] == 0 || numeric_arguments[["figure_aspect"]] == 0) {
    stop("Dimension arguments must be finite, non-negative values with positive minimum dimensions and row height.", call. = FALSE)
  }

  height <- max(
    numeric_arguments[["minimum_height"]],
    numeric_arguments[["vertical_padding"]] +
      n_pathways * numeric_arguments[["height_per_pathway"]]
  )
  base_width <- numeric_arguments[["minimum_width"]] +
    (n_collections - 1L) * numeric_arguments[["width_per_additional_collection"]]
  label_aware_width <-
    longest_pathway_label * numeric_arguments[["label_character_width"]] +
    (height - numeric_arguments[["vertical_padding"]]) /
      numeric_arguments[["figure_aspect"]] * n_collections +
    numeric_arguments[["legend_width"]]

  list(
    width = max(base_width, label_aware_width),
    height = height,
    units = "in",
    n_pathways = n_pathways,
    n_collections = n_collections,
    longest_pathway_label = longest_pathway_label,
    height_per_pathway = numeric_arguments[["height_per_pathway"]],
    vertical_padding = numeric_arguments[["vertical_padding"]],
    figure_aspect = numeric_arguments[["figure_aspect"]]
  )
}

#' Save a pathway bubble plot at its recommended dimensions
#'
#' @param filename Output file path passed to [ggplot2::ggsave()].
#' @param plot A plot returned by [plot_pathway_bubble()] or one member of
#'   [plot_pathway_bubble_set()].
#' @param width Optional explicit width in inches. Defaults to the plot's
#'   recommended width.
#' @param height Optional explicit height in inches. Defaults to the plot's
#'   recommended height.
#' @param dpi Output resolution passed to [ggplot2::ggsave()].
#' @param ... Other arguments passed to [ggplot2::ggsave()].
#' @return The output path, invisibly.
#' @export
save_pathway_bubble <- function(filename, plot, width = NULL, height = NULL, dpi = 300, ...) {
  if (!inherits(plot, "ggplot")) stop("`plot` must be a ggplot object.", call. = FALSE)
  dimensions <- attr(plot, "omix_pathway_plot_dimensions")
  if (is.null(width)) width <- dimensions$width
  if (is.null(height)) height <- dimensions$height
  width <- as.numeric(width)[1L]
  height <- as.numeric(height)[1L]
  if (!is.finite(width) || width <= 0 || !is.finite(height) || height <= 0) {
    stop("Provide positive finite `width` and `height`, or use a plot returned by `plot_pathway_bubble()`.", call. = FALSE)
  }
  ggplot2::ggsave(
    filename = filename,
    plot = plot,
    width = width,
    height = height,
    units = "in",
    dpi = dpi,
    limitsize = FALSE,
    ...
  )
  invisible(filename)
}

#' Save every plot in an OMIX pathway bubble-plot set
#'
#' @param plots An `omix_pathway_bubble_set` returned by
#'   [plot_pathway_bubble_set()].
#' @param output_dir Existing or new directory for the plots and manifest.
#' @param file_prefix Prefix for generated PNG and CSV filenames.
#' @param dpi PNG resolution.
#' @return A list containing the written plot paths and manifest path.
#' @export
save_pathway_bubble_set <- function(
    plots,
    output_dir,
    file_prefix = "pathway_bubble",
    dpi = 300) {
  if (!inherits(plots, "omix_pathway_bubble_set")) {
    stop("`plots` must be returned by `plot_pathway_bubble_set()`.", call. = FALSE)
  }
  output_dir <- as.character(output_dir)[1L]
  file_prefix <- as.character(file_prefix)[1L]
  if (is.na(output_dir) || !nzchar(output_dir)) {
    stop("`output_dir` must be a non-empty path.", call. = FALSE)
  }
  if (is.na(file_prefix) || !nzchar(file_prefix)) {
    stop("`file_prefix` must be a non-empty filename prefix.", call. = FALSE)
  }
  dpi <- as.numeric(dpi)[1L]
  if (!is.finite(dpi) || dpi <= 0) {
    stop("`dpi` must be a positive finite number.", call. = FALSE)
  }
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

  safe_name <- function(value) {
    value <- tolower(trimws(as.character(value)))
    value <- gsub("[^a-z0-9]+", "_", value)
    value <- gsub("^_+|_+$", "", value)
    if (!nzchar(value)) "plot" else value
  }

  selection <- attr(plots, "omix_pathway_bubble_selection")
  color_scales <- attr(plots, "omix_pathway_bubble_color_scales")
  dimensions <- attr(plots, "omix_pathway_bubble_dimensions")
  plot_names <- names(plots)
  written_paths <- vapply(seq_along(plots), function(index) {
    plot_name <- plot_names[[index]]
    file_path <- file.path(
      output_dir,
      paste0(file_prefix, "_", safe_name(plot_name), ".png")
    )
    save_pathway_bubble(file_path, plots[[index]], dpi = dpi)
    file_path
  }, character(1))

  manifest <- do.call(rbind, lapply(seq_along(plots), function(index) {
    plot_name <- plot_names[[index]]
    detail <- selection$details[[plot_name]]
    color_limits <- color_scales[[plot_name]]
    dimension <- dimensions[[plot_name]]
    data.frame(
      plot_name = plot_name,
      selection_scope = detail$scope,
      significance_statistic = selection$p_value_column,
      significance_threshold = selection$p_value_cutoff,
      selected_pathway_count = length(detail$selected_pathways),
      selected_row_count = detail$selected_row_count,
      color_min = color_limits[[1L]],
      color_max = color_limits[[2L]],
      width_inches = dimension$width,
      height_inches = dimension$height,
      file = basename(written_paths[[index]]),
      stringsAsFactors = FALSE
    )
  }))
  manifest_path <- file.path(
    output_dir,
    paste0(file_prefix, "_manifest.csv")
  )
  utils::write.csv(manifest, manifest_path, row.names = FALSE)

  invisible(list(files = unname(written_paths), manifest = manifest_path))
}

.pathway_color_anchor_values <- function(color_limits, n_colors = 7L) {
  color_limits <- as.numeric(color_limits)
  if (length(color_limits) != 2L || any(!is.finite(color_limits)) || color_limits[[1L]] >= 0 || color_limits[[2L]] <= 0) {
    stop("Colour limits must span zero with a negative lower and positive upper limit.", call. = FALSE)
  }
  if (!identical(as.integer(n_colors), 7L)) stop("The pathway bubble scale requires exactly seven colour anchors.", call. = FALSE)
  anchor_scores <- c(color_limits[[1L]], color_limits[[1L]] * 2 / 3, color_limits[[1L]] / 3, 0, color_limits[[2L]] / 3, color_limits[[2L]] * 2 / 3, color_limits[[2L]])
  scales::rescale(anchor_scores, from = color_limits)
}

#' Resolve bubble-plot score colour limits
#' @param scores Numeric enrichment scores represented in the plot.
#' @param method `symmetric_percentile` (default), `symmetric_fixed`, or `custom`.
#' @param percentile Percentile of absolute scores for the default method.
#' @param fixed_limit Positive maximum absolute score for fixed symmetric limits.
#' @param custom_limits Explicit lower and upper limits spanning zero.
#' @return A list containing resolved limits and calculation provenance.
#' @export
pathway_bubble_color_limits <- function(scores, method = c("symmetric_percentile", "symmetric_fixed", "custom"), percentile = 99, fixed_limit = 2, custom_limits = c(-2, 2)) {
  method <- match.arg(method)
  scores <- as.numeric(scores)
  scores <- scores[is.finite(scores)]
  if (length(scores) == 0L) stop("No finite score values are available to set the colour scale.", call. = FALSE)
  if (identical(method, "symmetric_percentile")) {
    percentile <- as.numeric(percentile)[1L]
    if (!is.finite(percentile) || percentile <= 0 || percentile > 100) stop("`percentile` must be greater than 0 and no more than 100.", call. = FALSE)
    limit <- as.numeric(stats::quantile(abs(scores), probs = percentile / 100, na.rm = TRUE, names = FALSE, type = 7))
    if (!is.finite(limit) || limit <= 0) stop("The selected score percentile is zero; supply fixed or custom limits.", call. = FALSE)
    limits <- c(-limit, limit)
  } else if (identical(method, "symmetric_fixed")) {
    fixed_limit <- as.numeric(fixed_limit)[1L]
    if (!is.finite(fixed_limit) || fixed_limit <= 0) stop("`fixed_limit` must be a positive finite number.", call. = FALSE)
    limits <- c(-fixed_limit, fixed_limit)
  } else {
    limits <- as.numeric(custom_limits)
    if (length(limits) != 2L || any(!is.finite(limits)) || limits[[1L]] >= 0 || limits[[2L]] <= 0) stop("`custom_limits` must have a negative lower and positive upper limit.", call. = FALSE)
  }
  list(limits = limits, method = method, percentile = if (identical(method, "symmetric_percentile")) percentile else NULL, plotted_score_count = length(scores), saturated_score_count = sum(scores < limits[[1L]] | scores > limits[[2L]]), saturated_score_fraction = mean(scores < limits[[1L]] | scores > limits[[2L]]))
}

.resolve_pathway_plot_field <- function(data, field, preferred) {
  if (!is.null(field)) {
    field <- as.character(field)[1L]
    if (!field %in% names(data)) stop("Requested column is unavailable: `", field, "`.", call. = FALSE)
    return(field)
  }
  found <- preferred[preferred %in% names(data)]
  if (length(found) == 0L) stop("No supported column is available: ", paste(preferred, collapse = ", "), ".", call. = FALSE)
  found[[1L]]
}

#' Render a shared OMIX pathway bubble plot
#'
#' The defaults reproduce the established Multi-Pathway Bubble Plot display:
#' split collection facets, Blue-Vermilion colours, symmetric 99th-percentile
#' score limits, hit-count bubble sizes, retained non-significant points, no
#' reference lines, and dynamic pathway-label sizing. Pathway selection is
#' deliberately external to this renderer so GSEA and L2P retain their own
#' scientific selection rules.
#'
#' @param data A supported GSEA, L2P, or canonical pathway-result data frame.
#' @param input_format Input layout; `auto` detects published GSEA and L2P schemas.
#' @param mapping Optional canonical-to-source mapping for a custom table.
#' @param p_value_column `pval` or `padj`; nominal p-values are preferred when omitted.
#' @param p_value_cutoff Significance threshold used only for point shapes.
#' @param show_non_significant Whether non-significant rows remain as X-shaped points.
#' @param contrast_order Optional raw contrast order.
#' @param retain_empty_contrasts Whether contrast labels supplied in
#'   `contrast_order` without retained rows are still drawn as empty x-axis
#'   columns. This is useful for selected plot sets, where a contrast can have
#'   valid enrichment results but none for the selected pathways.
#' @param contrast_labels Optional named raw-contrast to display-label mapping.
#' @param layout_style `facet` (default) or `panel`.
#' @param facet_title_mode `full collection name` (default) or `main collection`.
#' @param dynamic_pathway_font_size Whether to apply legacy dynamic label sizing.
#' @param pathway_font_size Fixed label size when dynamic sizing is disabled.
#' @param pathway_wrap_width Optional maximum characters per pathway-label line.
#'   When omitted, an automatic width is chosen from the displayed row count.
#' @param include_source_prefix Whether recognized source prefixes are retained
#'   in pathway-axis labels. Set this to `FALSE` for a single-collection plot.
#' @param pathway_label_angle Pathway-axis label angle.
#' @param contrast_font_size Contrast-axis label size.
#' @param contrast_label_angle Contrast-axis label angle.
#' @param vertical_lines Numeric contrast positions; the default has none.
#' @param vertical_line_type Line type for `vertical_lines`.
#' @param figure_aspect ggplot panel height-to-width ratio; default is 2.5.
#' @param palette Curated palette identifier.
#' @param color_range_method Score-colour limit method.
#' @param color_percentile Absolute-score percentile for the default method.
#' @param color_symmetric_limit Fixed symmetric maximum absolute score.
#' @param color_limits Optional explicit lower and upper limits overriding the method.
#' @param size_by `size` (default) or `fraction`; first available field used when omitted.
#' @param size_range Legacy point-size range; the established renderer uses its upper value.
#' @return A `ggplot` object with `omix_pathway_plot_settings` provenance.
#' @export
plot_pathway_bubble <- function(data, input_format = c("auto", "gsea", "l2p", "l2p_single", "canonical"), mapping = NULL, p_value_column = NULL, p_value_cutoff = 0.05, show_non_significant = TRUE, contrast_order = NULL, retain_empty_contrasts = FALSE, contrast_labels = NULL, layout_style = c("facet", "panel"), facet_title_mode = c("full collection name", "main collection"), dynamic_pathway_font_size = TRUE, pathway_font_size = 6, pathway_wrap_width = NULL, include_source_prefix = TRUE, pathway_label_angle = 0, contrast_font_size = 12, contrast_label_angle = 30, vertical_lines = numeric(), vertical_line_type = c("dashed", "solid", "dotted"), figure_aspect = 2.5, palette = "blue_vermilion", color_range_method = c("symmetric_percentile", "symmetric_fixed", "custom"), color_percentile = 99, color_symmetric_limit = 2, color_limits = NULL, size_by = NULL, size_range = c(2, 14)) {
  input_format <- match.arg(input_format)
  layout_style <- match.arg(layout_style)
  facet_title_mode <- match.arg(facet_title_mode)
  vertical_line_type <- match.arg(vertical_line_type)
  color_range_method <- match.arg(color_range_method)
  dat <- standardize_pathway_results(data, input_format = input_format, mapping = mapping)
  p_value_column <- .resolve_pathway_plot_field(dat, p_value_column, c("pval", "padj"))
  size_by <- .resolve_pathway_plot_field(dat, size_by, c("size", "fraction"))
  p_value_cutoff <- as.numeric(p_value_cutoff)[1L]
  if (!is.finite(p_value_cutoff) || p_value_cutoff < 0 || p_value_cutoff > 1) stop("`p_value_cutoff` must be between 0 and 1.", call. = FALSE)
  size_range <- as.numeric(size_range)
  if (length(size_range) != 2L || any(!is.finite(size_range)) || size_range[[1L]] >= size_range[[2L]]) stop("`size_range` must contain two increasing finite values.", call. = FALSE)
  raw_contrasts <- unique(as.character(dat$contrast))
  if (is.null(contrast_order)) {
    contrast_order <- raw_contrasts
  } else {
    contrast_order <- as.character(contrast_order)
    unknown_contrasts <- setdiff(contrast_order, raw_contrasts)
    if (length(unknown_contrasts) > 0L && !isTRUE(retain_empty_contrasts)) stop("`contrast_order` contains unknown contrast(s): ", paste(unknown_contrasts, collapse = ", "), call. = FALSE)
    dat <- dat[dat$contrast %in% contrast_order, , drop = FALSE]
  }
  if (nrow(dat) == 0L) stop("No pathway rows remain for the requested contrasts.", call. = FALSE)
  display_labels <- gsub("_", " ", contrast_order, fixed = TRUE)
  names(display_labels) <- contrast_order
  if (!is.null(contrast_labels)) {
    if (is.null(names(contrast_labels))) stop("`contrast_labels` must be a named vector of raw contrast labels.", call. = FALSE)
    known_labels <- contrast_labels[names(contrast_labels) %in% contrast_order]
    display_labels[names(known_labels)] <- as.character(known_labels)
  }
  if (any(is.na(display_labels) | !nzchar(trimws(display_labels)))) stop("Contrast display labels must be non-empty.", call. = FALSE)
  if (anyDuplicated(display_labels)) stop("Contrast display labels must be unique.", call. = FALSE)
  significant_label <- paste0(p_value_column, "<", p_value_cutoff)
  non_significant_label <- paste0(p_value_column, ">", p_value_cutoff)
  dat$Significance <- factor(ifelse(dat[[p_value_column]] <= p_value_cutoff, significant_label, non_significant_label), levels = c(significant_label, non_significant_label))
  dat$contrast_name <- factor(unname(display_labels[as.character(dat$contrast)]), levels = unname(display_labels))
  if (!isTRUE(show_non_significant)) dat <- dat[dat[[p_value_column]] <= p_value_cutoff, , drop = FALSE]
  if (nrow(dat) == 0L) stop("No pathway rows satisfy the requested display threshold.", call. = FALSE)
  if (identical(layout_style, "facet")) {
    dat$.facet_group <- if (identical(facet_title_mode, "main collection")) stringr::word(dat$collection, 1L, sep = ":") else dat$collection
  }
  dat <- dat[order(dat$contrast_name, dat$collection, dat$pathway), , drop = FALSE]
  # The source collection can be separate from the pathway label (for example,
  # L2P Reactome rows). Keep that information in the discrete y key so labels
  # remain unambiguous in combined views even if two sources share a pathway.
  dat$.pathway_key <- paste(dat$collection, dat$pathway, sep = "\034")
  dat$.pathway_label <- pathway_bubble_format_labels(
    dat$pathway,
    include_source_prefix = include_source_prefix,
    collections = dat$collection
  )
  pathway_labels <- stats::setNames(
    dat$.pathway_label[!duplicated(dat$.pathway_key)],
    dat$.pathway_key[!duplicated(dat$.pathway_key)]
  )
  pathway_wrap_width <- if (is.null(pathway_wrap_width)) {
    pathway_bubble_wrap_width(length(unique(dat$.pathway_key)))
  } else {
    suppressWarnings(as.integer(pathway_wrap_width)[1L])
  }
  if (is.na(pathway_wrap_width) || pathway_wrap_width < 1L) {
    stop("`pathway_wrap_width` must be a positive integer or NULL.", call. = FALSE)
  }
  palette_values <- pathway_bubble_palette(palette)
  color_scale <- if (is.null(color_limits)) {
    pathway_bubble_color_limits(dat$score, method = color_range_method, percentile = color_percentile, fixed_limit = color_symmetric_limit)
  } else {
    pathway_bubble_color_limits(dat$score, method = "custom", custom_limits = color_limits)
  }
  font_size <- if (isTRUE(dynamic_pathway_font_size)) pathway_bubble_dynamic_font_size(length(unique(dat$.pathway_key))) else as.numeric(pathway_font_size)[1L]
  if (!is.finite(font_size) || font_size <= 0) stop("`pathway_font_size` must be a positive finite number.", call. = FALSE)
  max_size_value <- max(dat[[size_by]], na.rm = TRUE)
  breaks <- if (identical(size_by, "fraction")) c(0.05, 0.10, 0.25, 0.50, 0.75, 1.00) else { template <- c(1, 5, 10, 50, 100, 200, 500, 1000); candidate <- template[template <= max_size_value]; if (length(candidate) == 0L) max_size_value else candidate }
  size_label <- if (identical(size_by, "fraction")) "Fraction" else "Count"
  contrast_hjust <- if (contrast_label_angle == 0) 0.5 else 1
  plot <- ggplot2::ggplot(dat, ggplot2::aes(x = contrast_name, y = stats::reorder(.pathway_key, -score), size = .data[[size_by]], colour = score)) +
    ggplot2::theme_bw() +
    ggplot2::theme(panel.grid.major = ggplot2::element_blank(), panel.grid.minor = ggplot2::element_blank())
  # An unused factor level does not consistently produce a key glyph in a
  # ggplot legend. Supply both levels through a transparent overlay at an
  # existing coordinate so the circle/X key remains interpretable even when
  # every plotted row is on one side of the selected threshold. The legend
  # guide restores the key opacity, while the plotted data are unaffected.
  significance_legend_data <- data.frame(
    .legend_x = as.character(dat$contrast_name[[1L]]),
    .legend_y = dat$.pathway_key[[1L]],
    Significance = factor(
      c(significant_label, non_significant_label),
      levels = c(significant_label, non_significant_label)
    )
  )
  plot <- plot +
    ggplot2::geom_point(ggplot2::aes(shape = Significance)) +
    ggplot2::geom_point(
      data = significance_legend_data,
      mapping = ggplot2::aes(x = .legend_x, y = .legend_y, shape = Significance),
      inherit.aes = FALSE,
      colour = "#000000",
      size = 4.5,
      alpha = 0,
      show.legend = TRUE
    ) +
    ggplot2::scale_shape_manual(
      name = "Significance",
      values = stats::setNames(c(19, 4), c(significant_label, non_significant_label)),
      breaks = c(significant_label, non_significant_label),
      limits = c(significant_label, non_significant_label),
      drop = FALSE
    ) +
    ggplot2::guides(
      shape = ggplot2::guide_legend(
        override.aes = list(
          shape = c(19, 4),
          size = c(4.5, 4.5),
          colour = c("#000000", "#000000"),
          alpha = c(1, 1)
        )
      )
    ) +
    ggplot2::ylab("Pathways") +
    ggplot2::scale_colour_gradientn(colours = palette_values$colors, values = .pathway_color_anchor_values(color_scale$limits, length(palette_values$colors)), limits = color_scale$limits, oob = scales::squish) +
    ggplot2::scale_size_area(name = size_label, max_size = size_range[[2L]], oob = scales::squish, breaks = breaks) +
    ggplot2::scale_x_discrete(drop = !isTRUE(retain_empty_contrasts)) +
    ggplot2::scale_y_discrete(expand = c(0.05, 0.05), labels = function(x) stringr::str_wrap(unname(pathway_labels[x]), width = pathway_wrap_width)) +
    ggplot2::theme(axis.title = ggplot2::element_blank(), axis.text.x = ggplot2::element_text(angle = contrast_label_angle, hjust = contrast_hjust, vjust = 1, size = contrast_font_size), axis.text.y = ggplot2::element_text(angle = pathway_label_angle, colour = "#000000", face = "plain", size = font_size, hjust = 1, vjust = 0.5), aspect.ratio = figure_aspect)
  if (length(vertical_lines) > 0L) plot <- plot + ggplot2::geom_vline(xintercept = as.numeric(vertical_lines) + 0.5, linetype = vertical_line_type, linewidth = 0.5, color = "gray")
  if (identical(layout_style, "facet")) {
    plot <- plot + ggplot2::facet_wrap(
      ~.facet_group,
      nrow = 1,
      labeller = ggplot2::labeller(.facet_group = function(values) {
        stringr::str_wrap(values, width = 30L)
      })
    )
  }
  visible_collections <- if (identical(layout_style, "facet")) dat$.facet_group else "single_panel"
  dimensions <- pathway_bubble_dimensions(
    n_pathways = length(unique(dat$.pathway_key)),
    n_collections = length(unique(visible_collections)),
    longest_pathway_label = min(
      max(nchar(as.character(dat$.pathway_label)), na.rm = TRUE),
      pathway_wrap_width
    ),
    figure_aspect = figure_aspect
  )
  attr(plot, "omix_pathway_plot_dimensions") <- dimensions
  attr(plot, "omix_pathway_plot_settings") <- list(p_value_column = p_value_column, p_value_cutoff = p_value_cutoff, show_non_significant = isTRUE(show_non_significant), layout_style = layout_style, facet_title_mode = facet_title_mode, palette = palette_values$id, color_scale = color_scale, size_by = size_by, size_range = size_range, dynamic_pathway_font_size = isTRUE(dynamic_pathway_font_size), pathway_font_size = font_size, pathway_wrap_width = pathway_wrap_width, include_source_prefix = isTRUE(include_source_prefix), retain_empty_contrasts = isTRUE(retain_empty_contrasts), vertical_lines = as.numeric(vertical_lines), figure_aspect = figure_aspect, dimensions = dimensions)
  plot
}
