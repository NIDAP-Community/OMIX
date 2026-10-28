# OMIX 3D PCA
#
# Portable implementation derived from the established CCBR 3D PCA template.
# It deliberately retains the template's analysis sequence: optional edgeR CPM,
# removal of zero-mean and zero-variance features, scaled `prcomp()`, and
# deterministic palette extension for groups beyond the selected named colors.

omix_pca_3d_require <- function(package) {
  if (!requireNamespace(package, quietly = TRUE)) {
    stop("OMIX PCA 3D requires package ", package, ".", call. = FALSE)
  }
}

omix_pca_3d_named_colors <- function() {
  c(
    indigo = "#5954d6", carrot = "#e1562c", lipstick = "#b80058",
    turquoise = "#00c6f8", lavender = "#d163e6", jade = "#00a76c",
    coral = "#ff9287", azure = "#008cf9", green = "#006e00",
    rum = "#796880", orange = "#FFA500", olive = "#878500"
  )
}

# This is the template's palette-extension algorithm.  Keeping its fixed seed
# means that the same number of groups gets the same generated colors.
omix_pca_3d_random_colors <- function(k) {
  if (k < 1L) return(character())
  omix_pca_3d_require("colorspace")
  seed <- 10
  n <- 2e3
  set.seed(seed)
  our_color_space <- colorspace::RGB(stats::runif(n), stats::runif(n), stats::runif(n))
  our_color_space <- methods::as(our_color_space, "LAB")
  current_color_space <- our_color_space@coords
  centers <- stats::kmeans(current_color_space, k, iter.max = 20)$centers
  unname(colorspace::hex(colorspace::LAB(centers)))
}

omix_pca_3d_parse_renames <- function(rename_specs) {
  if (!length(rename_specs)) return(matrix(character(), ncol = 2L, dimnames = list(NULL, c("old", "new"))))
  entries <- trimws(rename_specs[nzchar(trimws(rename_specs))])
  if (!length(entries)) return(matrix(character(), ncol = 2L, dimnames = list(NULL, c("old", "new"))))
  pairs <- lapply(entries, function(entry) {
    match <- regexec("^([^:]+):[[:space:]]*(.+)$", entry)
    pieces <- regmatches(entry, match)[[1L]]
    if (length(pieces) != 3L || !nzchar(trimws(pieces[[2L]])) || !nzchar(trimws(pieces[[3L]]))) {
      stop("Each manual label rename must use old_label:new_label; invalid entry: ", entry, call. = FALSE)
    }
    trimws(pieces[2:3])
  })
  result <- do.call(rbind, pairs)
  colnames(result) <- c("old", "new")
  result
}

omix_pca_3d_apply_renames <- function(labels, rename_specs) {
  rename_map <- omix_pca_3d_parse_renames(rename_specs)
  if (!nrow(rename_map)) return(labels)
  for (index in seq_len(nrow(rename_map))) {
    labels[labels == rename_map[index, "old"]] <- rename_map[index, "new"]
  }
  labels
}

omix_pca_3d_prepare <- function(
  feature_matrix,
  sample_metadata,
  feature_id_column,
  sample_id_column,
  sample_label_column,
  group_column,
  samples_to_include = character(),
  outlier_sample_ids = character(),
  use_cpm = FALSE,
  point_color_names = c(
    "indigo", "carrot", "lipstick", "turquoise", "lavender", "jade",
    "coral", "azure", "green", "rum", "orange", "olive"
  ),
  manual_label_renames = character()
) {
  required_matrix_columns <- c(feature_id_column, samples_to_include)
  missing_matrix_columns <- setdiff(required_matrix_columns, names(feature_matrix))
  if (length(missing_matrix_columns)) {
    stop("Feature-matrix columns not found: ", paste(missing_matrix_columns, collapse = ", "), call. = FALSE)
  }
  required_metadata_columns <- c(sample_id_column, sample_label_column, group_column)
  missing_metadata_columns <- setdiff(required_metadata_columns, names(sample_metadata))
  if (length(missing_metadata_columns)) {
    stop("Sample-metadata columns not found: ", paste(missing_metadata_columns, collapse = ", "), call. = FALSE)
  }

  if (!length(samples_to_include)) {
    samples_to_include <- intersect(as.character(sample_metadata[[sample_id_column]]), names(feature_matrix))
  }
  samples_to_include <- samples_to_include[!samples_to_include %in% outlier_sample_ids]
  samples_to_include <- samples_to_include[samples_to_include != feature_id_column]
  if (length(samples_to_include) < 3L) {
    stop("At least three selected samples are required for a 3D PCA plot.", call. = FALSE)
  }
  missing_samples <- setdiff(samples_to_include, names(feature_matrix))
  if (length(missing_samples)) {
    stop("Feature-matrix sample columns not found: ", paste(missing_samples, collapse = ", "), call. = FALSE)
  }
  if (anyDuplicated(samples_to_include)) {
    stop("Selected sample IDs must be unique.", call. = FALSE)
  }
  if (!all(vapply(feature_matrix[samples_to_include], is.numeric, logical(1)))) {
    stop("Selected feature-matrix sample columns must be numeric.", call. = FALSE)
  }
  if (anyNA(as.matrix(feature_matrix[samples_to_include]))) {
    stop("Selected feature-matrix sample columns must not contain missing values.", call. = FALSE)
  }

  metadata <- sample_metadata[
    as.character(sample_metadata[[sample_id_column]]) %in% samples_to_include,
    , drop = FALSE
  ]
  if (anyDuplicated(as.character(metadata[[sample_id_column]]))) {
    stop("Selected sample metadata contain duplicated sample IDs.", call. = FALSE)
  }
  metadata <- metadata[match(samples_to_include, as.character(metadata[[sample_id_column]])), , drop = FALSE]
  if (anyNA(metadata[[sample_id_column]]) || nrow(metadata) != length(samples_to_include)) {
    stop("Every selected matrix sample must have exactly one metadata row.", call. = FALSE)
  }
  if (anyNA(metadata[[sample_label_column]]) || anyNA(metadata[[group_column]])) {
    stop("Selected sample labels and groups must not be missing.", call. = FALSE)
  }

  expression <- as.matrix(feature_matrix[samples_to_include])
  storage.mode(expression) <- "double"
  if (isTRUE(use_cpm)) {
    if (any(expression < 0)) {
      stop("--use_cpm requires non-negative raw counts.", call. = FALSE)
    }
    omix_pca_3d_require("edgeR")
    expression <- edgeR::cpm(expression)
  }

  feature_ids <- as.character(feature_matrix[[feature_id_column]])
  if (anyNA(feature_ids) || any(!nzchar(feature_ids))) {
    stop("Feature identifiers must be non-missing, non-empty values.", call. = FALSE)
  }
  # This preserves the imported template rule (`!rowMeans(edf) == 0`):
  # rows with an exactly zero mean are removed before the variance filter.
  keep_mean <- rowMeans(expression) != 0
  expression <- expression[keep_mean, , drop = FALSE]
  feature_ids <- feature_ids[keep_mean]
  keep_variance <- apply(expression, 1L, stats::var) != 0
  expression <- expression[keep_variance, , drop = FALSE]
  feature_ids <- feature_ids[keep_variance]
  if (nrow(expression) < 3L) {
    stop("At least three non-zero, variable features are required for a 3D PCA plot.", call. = FALSE)
  }

  transposed <- t(expression)
  colnames(transposed) <- feature_ids
  # `prcomp()` cannot represent duplicate feature names reliably in a table;
  # make them unique without changing the input values or their ordering.
  colnames(transposed) <- make.unique(colnames(transposed), sep = ".duplicate_")
  pca <- stats::prcomp(transposed, scale. = TRUE)
  if (ncol(pca$x) < 3L) {
    stop("The selected input does not yield three principal components.", call. = FALSE)
  }
  coordinates <- as.data.frame(pca$x, check.names = FALSE)
  coordinates$group <- as.character(metadata[[group_column]])
  coordinates$sample <- omix_pca_3d_apply_renames(
    as.character(metadata[[sample_label_column]]),
    manual_label_renames
  )

  eigenvalue <- pca$sdev ^ 2
  variance <- eigenvalue * 100 / sum(eigenvalue)
  components <- data.frame(
    id = paste0("PC", seq_along(pca$sdev)),
    eigenvalue = eigenvalue,
    variance = variance,
    cumvariance = cumsum(variance),
    variance_label = sprintf("PC%s (%.1f%% variance)", seq_along(variance), variance),
    cumvariance_label = sprintf("PC%s (%.1f%% cumulative variance)", seq_along(variance), cumsum(variance)),
    check.names = FALSE
  )

  palette <- omix_pca_3d_named_colors()
  point_color_names <- trimws(point_color_names[nzchar(trimws(point_color_names))])
  if (!length(point_color_names)) point_color_names <- names(palette)
  missing_colors <- setdiff(point_color_names, names(palette))
  if (length(missing_colors)) {
    stop("Unknown point color name(s): ", paste(missing_colors, collapse = ", "), call. = FALSE)
  }
  point_colors <- unname(palette[point_color_names])
  groups <- unique(coordinates$group)
  if (length(groups) > length(point_colors)) {
    point_colors <- c(point_colors, omix_pca_3d_random_colors(length(groups) - length(point_colors)))
  } else {
    point_colors <- point_colors[seq_len(length(groups))]
  }
  names(point_colors) <- groups

  list(
    coordinates = coordinates,
    components = components,
    axis_titles = sub(" variance", "", components$variance_label[1:3]),
    point_colors = point_colors,
    selected_samples = samples_to_include,
    feature_count = nrow(expression)
  )
}

omix_pca_3d_render <- function(prepared, plot_title, point_size, label_font_size) {
  omix_pca_3d_require("plotly")
  if (!is.finite(point_size) || point_size <= 0) stop("point_size must be positive.", call. = FALSE)
  if (!is.finite(label_font_size) || label_font_size <= 0) stop("label_font_size must be positive.", call. = FALSE)
  fig <- plotly::plot_ly(
    prepared$coordinates,
    x = ~PC1,
    y = ~PC2,
    z = ~PC3,
    color = ~group,
    colors = prepared$point_colors,
    type = "scatter3d",
    mode = "markers",
    marker = list(size = point_size),
    hoverinfo = "text",
    text = ~sample,
    size = label_font_size
  )
  plotly::layout(
    fig,
    title = list(text = plot_title, size = 5),
    scene = list(
      xaxis = list(title = prepared$axis_titles[[1L]]),
      yaxis = list(title = prepared$axis_titles[[2L]]),
      zaxis = list(title = prepared$axis_titles[[3L]])
    ),
    legend = list(itemsizing = "constant", size = 12, y = 0.5)
  )
}

run_omix_pca_3d <- function(
  prepared,
  output_dir,
  plot_title,
  point_size,
  label_font_size,
  self_contained_html,
  run_summary
) {
  omix_pca_3d_require("htmlwidgets")
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  output_dir <- normalizePath(output_dir, mustWork = TRUE)
  figure <- omix_pca_3d_render(prepared, plot_title, point_size, label_font_size)
  # The published r-visualization image does not provide Pandoc, which
  # htmlwidgets needs for a self-contained HTML file.  The default therefore
  # writes the standard HTML plus its companion asset directory; callers with
  # Pandoc may opt into the historical self-contained form.
  htmlwidgets::saveWidget(
    figure,
    file.path(output_dir, "pca_3d.html"),
    selfcontained = self_contained_html
  )
  utils::write.csv(prepared$components, file.path(output_dir, "pca_3d_components.csv"), row.names = FALSE)
  utils::write.csv(prepared$coordinates, file.path(output_dir, "pca_3d_coordinates.csv"), row.names = FALSE)
  writeLines(run_summary, file.path(output_dir, "pca_3d_run_summary.txt"))
  invisible(figure)
}
