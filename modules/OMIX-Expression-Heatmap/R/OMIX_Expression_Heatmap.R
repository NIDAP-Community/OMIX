# Expression heatmap renderer for normalized continuous expression matrices.
#
# The module accepts a feature-by-sample matrix plus matching sample metadata.
# It is agnostic to the origin of the continuous values: for example, bulk
# normalized expression, batch-corrected expression, or single-cell-derived
# pseudobulk profiles. It deliberately does not extract values from Seurat
# objects; OMIX-Seurat-Pseudobulk is the explicit upstream conversion step.
Expression_Heatmap_ComplexHeatmap <- function(
  counts_matrix = NULL,
  sample_metadata = NULL,
  gene_column_name,
  sample_name_column,
  sample_label_column,
  samples_to_include,
  reorder_sample_dendrogram_order = character(0),
  group_columns,
  include_all_genes = FALSE,
  filter_top_genes_by_variance = TRUE,
  top_genes_by_variance_to_include = 500,
  specific_genes_to_include = "None",
  cluster_genes = TRUE,
  gene_clustering_method = "average",
  gene_distance_metric = "correlation",
  display_gene_dendrogram = TRUE,
  display_gene_names = "auto",
  center_and_rescale = TRUE,
  center_and_rescale_by_column = NULL,
  center_and_rescale_by_order = NULL,
  cluster_samples = TRUE,
  arrange_sample_columns = FALSE,
  order_by_gene_expression = FALSE,
  gene_to_order_columns = NULL,
  gene_expression_order = "low_to_high",
  sample_clustering_method = "complete",
  sample_distance_metric = "correlation",
  display_sample_dendrograms = TRUE,
  reorder_sample_dendrogram = FALSE,
  display_sample_names = TRUE,
  manually_rename_samples = FALSE,
  samples_to_rename = c(""),
  assign_group_colors = FALSE,
  assign_color_to_sample_groups = c(),
  group_colors = c(
    "indigo",
    "carrot",
    "lipstick",
    "turquoise",
    "lavender",
    "jade",
    "coral",
    "azure",
    "green",
    "rum",
    "orange",
    "olive"
  ),
  heatmap_color_scheme = "Bu Yl Rd",
  autoscale_heatmap_color = TRUE,
  set_max_heatmap_color = 2,
  set_min_heatmap_color = -2,
  column_split_by_column = NULL,
  column_split_order = NULL,
  column_gap = 4,
  display_numbers = FALSE,
  gene_name_font_size = "auto",
  row_label_max_length = 30,
  legend_font_size = 10,
  sample_name_font_size = "auto",
  heatmap_title = NULL,
  annotation_legend_title = NULL,
  annotation_legend_order = NULL,
  return_z_scores = FALSE,
  counts_matrix_file = NULL,
  sample_metadata_file = NULL,
  input_delim = "\t",
  export_results_file = NULL,
  export_plot_file = NULL,
  export_plot_width = 12,
  export_plot_height = 10
) {
  library(circlize)
  library(colorspace)
  library(ComplexHeatmap)
  library(dendsort)
  library(dplyr)
  library(grid)
  library(matrixStats)
  library(RColorBrewer)
  library(stringr)
  library(tibble)

  read_input_table <- function(tbl, file_path, delim) {
    if (!is.null(file_path) && nzchar(file_path)) {
      return(utils::read.delim(
        file_path,
        sep = delim,
        check.names = FALSE,
        stringsAsFactors = FALSE
      ))
    }
    tbl
  }

  normalize_display_gene_names <- function(value) {
    if (length(value) != 1L || is.na(value)) {
      stop("ERROR: `display_gene_names` must be `auto`, TRUE, or FALSE.")
    }
    if (is.logical(value)) {
      return(isTRUE(value))
    }
    value <- tolower(trimws(as.character(value)))
    if (identical(value, "auto")) {
      return("auto")
    }
    if (value %in% c("true", "t", "1", "yes")) {
      return(TRUE)
    }
    if (value %in% c("false", "f", "0", "no")) {
      return(FALSE)
    }
    stop("ERROR: `display_gene_names` must be `auto`, TRUE, or FALSE.")
  }

  resolve_gene_name_font_size <- function(value, n_features) {
    value_character <- tolower(trimws(as.character(value)[1L]))
    if (identical(value_character, "auto")) {
      if (n_features <= 20L) {
        return(8)
      }
      if (n_features <= 50L) {
        return(6)
      }
      return(4)
    }
    value_numeric <- suppressWarnings(as.numeric(value)[1L])
    if (!is.finite(value_numeric) || value_numeric <= 0) {
      stop("ERROR: `gene_name_font_size` must be `auto` or a positive number.")
    }
    value_numeric
  }

  resolve_sample_name_font_size <- function(value, n_samples, labels) {
    value_character <- tolower(trimws(as.character(value)[1L]))
    if (!identical(value_character, "auto")) {
      value_numeric <- suppressWarnings(as.numeric(value)[1L])
      if (!is.finite(value_numeric) || value_numeric <= 0) {
        stop("ERROR: `sample_name_font_size` must be `auto` or a positive number.")
      }
      return(value_numeric)
    }

    base_size <- if (n_samples <= 12L) {
      12
    } else if (n_samples <= 40L) {
      11
    } else if (n_samples <= 80L) {
      10
    } else if (n_samples <= 160L) {
      8
    } else {
      6
    }
    label_lengths <- nchar(gsub("[\\r\\n]+", " ", as.character(labels)))
    max_label_length <- if (length(label_lengths)) max(label_lengths, na.rm = TRUE) else 0L
    if (!is.finite(max_label_length)) {
      max_label_length <- 0L
    }
    if (max_label_length > 30L) {
      return(max(6, base_size - 2))
    }
    if (max_label_length > 18L) {
      return(max(6, base_size - 1))
    }
    base_size
  }

  format_row_labels <- function(feature_ids, max_length, font_size) {
    max_length <- suppressWarnings(as.integer(max_length)[1L])
    if (is.na(max_length) || max_length < 1L) {
      stop("ERROR: `row_label_max_length` must be a positive integer.")
    }
    effective_length <- min(
      max_length,
      max(15L, floor(max_length * 8 / font_size))
    )
    labels <- gsub("_", " ", as.character(feature_ids), fixed = TRUE)
    labels <- gsub("[\r\n]+", " ", labels)
    stringr::str_wrap(labels, width = effective_length)
  }

  row_zscore <- function(mat) {
    scaled <- t(scale(t(mat)))
    scaled[is.infinite(scaled)] <- NA_real_
    scaled
  }

  split_row_zscore <- function(mat, split_values, split_order = NULL) {
    if (length(split_values) != ncol(mat)) {
      stop("ERROR: Split vector length must match the number of heatmap columns.")
    }
    if (is.null(split_order)) {
      split_order <- unique(as.character(split_values))
    }
    split_factor <- factor(split_values, levels = split_order)
    scaled <- matrix(
      NA_real_,
      nrow = nrow(mat),
      ncol = ncol(mat),
      dimnames = dimnames(mat)
    )
    for (level in levels(split_factor)) {
      idx <- which(split_factor == level)
      if (length(idx) == 0) {
        next
      }
      scaled[, idx] <- row_zscore(mat[, idx, drop = FALSE])
    }
    scaled
  }

  make_distance <- function(mat, metric, margin = c("row", "column")) {
    margin <- match.arg(margin)
    if (metric != "correlation") {
      if (margin == "row") {
        return(stats::dist(mat, method = metric))
      }
      return(stats::dist(t(mat), method = metric))
    }

    cor_mat <- if (margin == "row") {
      stats::cor(t(mat), use = "pairwise.complete.obs")
    } else {
      stats::cor(mat, use = "pairwise.complete.obs")
    }
    cor_mat[is.na(cor_mat)] <- 0
    stats::as.dist(1 - cor_mat)
  }

  make_hclust <- function(mat, metric, method, margin = c("row", "column")) {
    margin <- match.arg(margin)
    n_items <- if (margin == "row") nrow(mat) else ncol(mat)
    if (n_items < 2) {
      return(FALSE)
    }
    hc <- stats::hclust(
      make_distance(mat, metric = metric, margin = margin),
      method = method
    )
    stats::as.hclust(dendsort::dendsort(stats::as.dendrogram(hc)))
  }

  get_random_colors <- function(k) {
    n <- 2e3
    color_space <- colorspace::RGB(runif(n), runif(n), runif(n))
    color_space <- as(color_space, "LAB")
    set.seed(10)
    km <- stats::kmeans(color_space@coords, k, iter.max = 20)
    unname(colorspace::hex(colorspace::LAB(km$centers)))
  }

  pal <- function(n, h = c(237, 43), c = 100, l = c(70, 90), power = 1) {
    if (n < 1L) {
      return(character(0L))
    }
    h <- rep(h, length.out = 2L)
    l <- rep(l, length.out = 2L)
    power <- rep(power, length.out = 2L)
    rval <- seq(1, -1, length = n)
    colorspace::hex(colorspace::polarLUV(
      L = l[2L] - diff(l) * abs(rval)^power[2L],
      C = c * abs(rval)^power[1L],
      H = ifelse(rval > 0, h[1L], h[2L])
    ))
  }

  counts_matrix <- read_input_table(counts_matrix, counts_matrix_file, input_delim)
  sample_metadata <- read_input_table(sample_metadata, sample_metadata_file, input_delim)

  if (is.null(counts_matrix)) {
    stop("ERROR: `counts_matrix` is required.")
  }
  if (is.null(sample_metadata)) {
    stop("ERROR: `sample_metadata` is required.")
  }
  if (include_all_genes && filter_top_genes_by_variance) {
    stop(
      "ERROR: Set only one of `include_all_genes` or ",
      "`filter_top_genes_by_variance` to TRUE."
    )
  }

  n_sample_ordering <- sum(c(
    cluster_samples,
    arrange_sample_columns,
    order_by_gene_expression
  ))
  if (n_sample_ordering > 1) {
    stop(
      "ERROR: Only one of `cluster_samples`, `arrange_sample_columns`, or ",
      "`order_by_gene_expression` may be TRUE at one time."
    )
  }
  if (order_by_gene_expression &&
      (is.null(gene_to_order_columns) ||
       length(gene_to_order_columns) != 1L ||
       !nzchar(trimws(gene_to_order_columns)))) {
    stop(
      "ERROR: `gene_to_order_columns` must name one plotted feature when ",
      "`order_by_gene_expression` is TRUE."
    )
  }
  if (!gene_expression_order %in% c("low_to_high", "high_to_low")) {
    stop(
      "ERROR: `gene_expression_order` must be `low_to_high` or `high_to_low`."
    )
  }
  if (reorder_sample_dendrogram && !cluster_samples) {
    stop(
      "ERROR: `reorder_sample_dendrogram` requires `cluster_samples = TRUE`."
    )
  }
  if (reorder_sample_dendrogram && length(reorder_sample_dendrogram_order) == 0L) {
    stop(
      "ERROR: `reorder_sample_dendrogram_order` is required when ",
      "`reorder_sample_dendrogram` is TRUE."
    )
  }

  required_metadata_cols <- unique(c(
    sample_name_column,
    sample_label_column,
    group_columns,
    center_and_rescale_by_column,
    column_split_by_column
  ))
  missing_metadata_cols <- setdiff(required_metadata_cols, colnames(sample_metadata))
  if (length(missing_metadata_cols) > 0) {
    stop(
      "ERROR: Missing required metadata columns: ",
      paste(missing_metadata_cols, collapse = ", ")
    )
  }

  if (gene_column_name != "Gene") {
    counts_matrix <- counts_matrix[, !(colnames(counts_matrix) %in% "Gene")]
    colnames(counts_matrix)[colnames(counts_matrix) == gene_column_name] <- "Gene"
  }

  samples_to_include <- samples_to_include[
    !samples_to_include %in% c(gene_column_name, "Gene", "GeneName")
  ]
  missing_samples <- setdiff(samples_to_include, colnames(counts_matrix))
  if (length(missing_samples) > 0) {
    stop(
      "ERROR: Missing requested sample columns in counts matrix: ",
      paste(missing_samples, collapse = ", ")
    )
  }

  color_palettes <- list(
    "Default" = pal(100),
    "Blue to Red" = colorspace::diverge_hcl(
      100,
      c = 100,
      l = c(30, 80),
      power = 1
    ),
    "Red to Vanilla" = colorspace::heat_hcl(
      100,
      c = c(80, 30),
      l = c(30, 90),
      power = c(1 / 5, 2)
    ),
    "Violet to Pink" = rev(colorspace::heat_hcl(
      100,
      h = c(0, -100),
      c = c(40, 80),
      l = c(75, 40),
      power = 1
    )),
    "Bu Yl Rd" = rev(
      grDevices::colorRampPalette(RColorBrewer::brewer.pal(10, "RdYlBu"))(100)
    ),
    "Bu Wt Rd" = grDevices::colorRampPalette(
      c("steelblue", "white", "red")
    )(100)
  )
  if (!heatmap_color_scheme %in% names(color_palettes)) {
    stop("ERROR: Unknown `heatmap_color_scheme`: ", heatmap_color_scheme)
  }

  df1 <- counts_matrix[, c("Gene", samples_to_include)]
  df <- df1 |>
    dplyr::group_by(.data$Gene) |>
    dplyr::summarise(
      dplyr::across(dplyr::everything(), mean),
      .groups = "drop"
    )

  df_mat <- df[, colnames(df) != "Gene"] |> as.data.frame()
  # Preserve exact identifiers for feature selection and exported matrices.
  # Display-only wrapping is applied later through `row_labels`.
  rownames(df_mat) <- df$Gene

  if (!include_all_genes) {
    genes_parsed <- strsplit(specific_genes_to_include, " ")[[1]]
    genes_parsed <- genes_parsed[nzchar(genes_parsed)]
    extra_genes <- df_mat[genes_parsed, , drop = FALSE]

    if (filter_top_genes_by_variance) {
      rv <- matrixStats::rowVars(as.matrix(df_mat))
      df_var <- df_mat
      df_var$var <- rv
      df_var <- df_var |>
        tibble::rownames_to_column("Gene") |>
        dplyr::arrange(dplyr::desc(.data$var))
      extra_genes <- dplyr::filter(df_var, .data$Gene %in% genes_parsed)
      df_var <- df_var[seq_len(top_genes_by_variance_to_include), ]
      df_var <- df_var[stats::complete.cases(df_var), ]
      df_selected <- dplyr::bind_rows(df_var, extra_genes) |>
        dplyr::distinct()
      rownames(df_selected) <- df_selected$Gene
      df_selected$Gene <- NULL
      df_selected$var <- NULL
    } else {
      df_selected <- extra_genes[!duplicated(extra_genes), ]
      df_selected <- df_selected[genes_parsed, , drop = FALSE]
    }
  } else {
    df_selected <- df_mat
  }

  mat_selected <- as.matrix(df_selected)

  annot <- sample_metadata |>
    dplyr::filter(.data[[sample_name_column]] %in% samples_to_include)
  annot <- annot[match(samples_to_include, annot[[sample_name_column]]), , drop = FALSE]
  if (anyNA(annot[[sample_name_column]])) {
    stop("ERROR: Some selected samples are missing from sample metadata.")
  }

  if (center_and_rescale) {
    if (is.null(center_and_rescale_by_column)) {
      mat_plot <- row_zscore(mat_selected)
    } else {
      mat_plot <- split_row_zscore(
        mat_selected,
        split_values = annot[[center_and_rescale_by_column]],
        split_order = center_and_rescale_by_order
      )
    }
    mat_plot <- mat_plot[stats::complete.cases(mat_plot), , drop = FALSE]
  } else {
    mat_plot <- mat_selected
  }

  display_gene_names <- normalize_display_gene_names(display_gene_names)
  show_row_names <- if (identical(display_gene_names, "auto")) {
    nrow(mat_plot) <= 50L
  } else {
    display_gene_names
  }
  effective_gene_name_font_size <- resolve_gene_name_font_size(
    gene_name_font_size,
    nrow(mat_plot)
  )
  row_labels <- stats::setNames(
    format_row_labels(
      rownames(mat_plot),
      row_label_max_length,
      effective_gene_name_font_size
    ),
    rownames(mat_plot)
  )

  if (order_by_gene_expression) {
    gene_to_order_columns <- stringr::str_wrap(gsub(" ", "", gene_to_order_columns), 30)
    if (!gene_to_order_columns %in% rownames(mat_plot)) {
      stop(
        "ERROR: `gene_to_order_columns` is not a plotted feature: ",
        gene_to_order_columns
      )
    }
    order_idx <- if (gene_expression_order == "low_to_high") {
      order(mat_plot[gene_to_order_columns, ])
    } else {
      order(-mat_plot[gene_to_order_columns, ])
    }
    mat_plot <- mat_plot[, order_idx, drop = FALSE]
    annot <- annot[match(colnames(mat_plot), annot[[sample_name_column]]), , drop = FALSE]
  }

  if (arrange_sample_columns) {
    for (x in group_columns) {
      annot[, x] <- factor(annot[[x]], levels = unique(annot[[x]]))
    }
    annot <- dplyr::arrange(annot, dplyr::across(dplyr::all_of(group_columns)))
    mat_plot <- mat_plot[, match(annot[[sample_name_column]], colnames(mat_plot)), drop = FALSE]
  }

  annotation_col <- NULL
  annot_col <- NULL
  if (length(group_columns) > 0) {
    colorlist <- c(
      indigo = "#5954d6",
      carrot = "#e1562c",
      lipstick = "#b80058",
      turquoise = "#00c6f8",
      lavender = "#d163e6",
      jade = "#00a76c",
      coral = "#ff9287",
      azure = "#008cf9",
      green = "#006e00",
      rum = "#796880",
      orange = "#FFA500",
      olive = "#878500"
    )
    group_colors <- ifelse(
      group_colors %in% names(colorlist),
      unname(colorlist[group_colors]),
      group_colors
    )

    annotation_col <- annot |>
      dplyr::select(dplyr::all_of(group_columns)) |>
      as.data.frame()

    annotation_display_names <- group_columns
    if (!is.null(annotation_legend_title)) {
      if (length(annotation_legend_title) != length(group_columns)) {
        stop(
          "ERROR: `annotation_legend_title` must have one value per ",
          "`group_columns` entry."
        )
      }
      annotation_display_names <- annotation_legend_title
    }

    get_annotation_level_order <- function(column_name, display_name) {
      if (is.null(annotation_legend_order)) {
        return(NULL)
      }
      if (is.list(annotation_legend_order)) {
        if (!is.null(annotation_legend_order[[column_name]])) {
          return(annotation_legend_order[[column_name]])
        }
        if (!is.null(annotation_legend_order[[display_name]])) {
          return(annotation_legend_order[[display_name]])
        }
        return(NULL)
      }
      if (length(group_columns) != 1) {
        stop(
          "ERROR: For multiple `group_columns`, `annotation_legend_order` ",
          "must be a named list."
        )
      }
      annotation_legend_order
    }

    for (i in seq_along(group_columns)) {
      column_name <- group_columns[i]
      level_order <- get_annotation_level_order(
        column_name,
        annotation_display_names[i]
      )
      values <- annotation_col[[column_name]]
      if (is.null(level_order)) {
        annotation_col[[column_name]] <- factor(values)
      } else {
        annotation_col[[column_name]] <- factor(
          values,
          levels = c(level_order, setdiff(unique(values), level_order))
        )
      }
    }
    colnames(annotation_col) <- annotation_display_names
    rownames(annotation_col) <- annot[[sample_name_column]]

    n_levels <- length(unlist(lapply(annotation_col, levels)))
    if (n_levels > length(group_colors)) {
      group_colors <- c(
        group_colors,
        get_random_colors(n_levels - length(group_colors))
      )
    }

    annot_col <- list()
    b <- 1
    for (i in seq_along(group_columns)) {
      nm <- colnames(annotation_col)[i]
      grp <- as.factor(annotation_col[, i])
      idx <- seq(b, b + length(levels(grp)) - 1)
      col <- group_colors[idx]
      names(col) <- levels(grp)
      annot_col[[nm]] <- col
      b <- b + length(levels(grp))
    }

    if (assign_group_colors) {
      for (entry in assign_color_to_sample_groups) {
        parts <- strsplit(entry, ": ?")[[1]]
        annot_col[[1]][trimws(parts[1])] <- trimws(parts[2])
      }
    }
  }

  if (manually_rename_samples) {
    labels_col <- colnames(mat_plot)
    for (entry in samples_to_rename) {
      parts <- strsplit(entry, ": ?")[[1]]
      if (length(parts) >= 2) {
        old_nm <- trimws(parts[1])
        new_nm <- trimws(parts[2])
        labels_col[labels_col == old_nm] <- new_nm
      }
    }
  } else {
    label_map <- stats::setNames(
      annot[[sample_label_column]],
      annot[[sample_name_column]]
    )
    labels_col <- unname(label_map[colnames(mat_plot)])
  }
  effective_sample_name_font_size <- resolve_sample_name_font_size(
    sample_name_font_size,
    ncol(mat_plot),
    labels_col
  )

  column_split <- NULL
  if (!is.null(column_split_by_column)) {
    split_values <- annot[[column_split_by_column]][
      match(colnames(mat_plot), annot[[sample_name_column]])
    ]
    split_levels <- if (is.null(column_split_order)) {
      unique(as.character(split_values))
    } else {
      column_split_order
    }
    column_split <- factor(split_values, levels = split_levels)
  }

  col_pal <- color_palettes[[heatmap_color_scheme]]
  if (autoscale_heatmap_color) {
    breaks <- seq(min(mat_plot), max(mat_plot), length.out = length(col_pal))
    legbreaks <- seq(min(mat_plot), max(mat_plot), length.out = 5)
  } else {
    breaks <- seq(
      set_min_heatmap_color,
      set_max_heatmap_color,
      length.out = length(col_pal)
    )
    legbreaks <- seq(set_min_heatmap_color, set_max_heatmap_color, length.out = 5)
  }
  col_fun <- circlize::colorRamp2(breaks, col_pal)
  legbreaks <- as.numeric(formatC(legbreaks, 2))

  row_cluster <- if (cluster_genes) {
    make_hclust(
      mat_plot,
      metric = gene_distance_metric,
      method = gene_clustering_method,
      margin = "row"
    )
  } else {
    FALSE
  }
  column_cluster <- if (cluster_samples) {
    make_hclust(
      mat_plot,
      metric = sample_distance_metric,
      method = sample_clustering_method,
      margin = "column"
    )
  } else {
    FALSE
  }

  if (reorder_sample_dendrogram && cluster_samples && !identical(column_cluster, FALSE)) {
    if (length(reorder_sample_dendrogram_order) != ncol(mat_plot) ||
        anyDuplicated(reorder_sample_dendrogram_order) ||
        !setequal(reorder_sample_dendrogram_order, colnames(mat_plot))) {
      stop(
        "ERROR: `reorder_sample_dendrogram_order` must contain each selected ",
        "sample ID exactly once."
      )
    }
    column_cluster <- stats::as.hclust(dendextend::rotate(
      stats::as.dendrogram(column_cluster),
      reorder_sample_dendrogram_order
    ))
  }

  top_annotation <- NULL
  if (!is.null(annotation_col)) {
    top_annotation <- ComplexHeatmap::HeatmapAnnotation(
      df = annotation_col[colnames(mat_plot), , drop = FALSE],
      col = annot_col,
      annotation_name_gp = grid::gpar(fontsize = legend_font_size),
      annotation_legend_param = lapply(
        names(annot_col),
        function(nm) list(title = nm, title_gp = grid::gpar(fontsize = legend_font_size))
      ) |>
        stats::setNames(names(annot_col))
    )
  }

  cell_fun <- NULL
  if (display_numbers) {
    cell_fun <- function(j, i, x, y, width, height, fill) {
      grid::grid.text(
        sprintf("%.2f", mat_plot[i, j]),
        x,
        y,
        gp = grid::gpar(fontsize = 8)
      )
    }
  }

  message(sprintf("Total number of genes in heatmap: %d", nrow(mat_plot)))
  message(sprintf(
    "Feature labels: %s; font size: %g",
    if (show_row_names) "shown" else "hidden",
    effective_gene_name_font_size
  ))
  message(sprintf(
    "Sample labels: %s; font size: %g",
    if (display_sample_names) "shown" else "hidden",
    effective_sample_name_font_size
  ))

  render_heatmap <- function() {
    heatmap_obj <- ComplexHeatmap::Heatmap(
      mat_plot,
      name = " ",
      col = col_fun,
      heatmap_legend_param = list(
        at = legbreaks,
        labels_gp = grid::gpar(fontsize = legend_font_size),
        title_gp = grid::gpar(fontsize = legend_font_size)
      ),
      cluster_rows = row_cluster,
      cluster_columns = column_cluster,
      show_row_dend = display_gene_dendrogram,
      show_column_dend = display_sample_dendrograms,
      show_row_names = show_row_names,
      show_column_names = display_sample_names,
      row_labels = row_labels,
      row_names_gp = grid::gpar(fontsize = effective_gene_name_font_size),
      column_names_gp = grid::gpar(fontsize = effective_sample_name_font_size),
      column_labels = labels_col,
      top_annotation = top_annotation,
      column_split = column_split,
      column_gap = grid::unit(column_gap, "mm"),
      column_title_gp = grid::gpar(fontsize = 10),
      cell_fun = cell_fun,
      use_raster = nrow(mat_plot) > 200
    )
    ComplexHeatmap::draw(
      heatmap_obj,
      heatmap_legend_side = "right",
      annotation_legend_side = "right",
      padding = grid::unit(c(14, 4, 4, 4), "mm"),
      column_title = heatmap_title,
      column_title_gp = grid::gpar(fontsize = 12, fontface = "bold")
    )
  }

  if (!is.null(export_plot_file) && nzchar(export_plot_file)) {
    grDevices::png(
      filename = export_plot_file,
      width = export_plot_width,
      height = export_plot_height,
      units = "in",
      res = 300
    )
    render_heatmap()
    grDevices::dev.off()
  } else {
    render_heatmap()
  }

  df_out <- tibble::rownames_to_column(as.data.frame(mat_plot), "Gene")

  if (!is.null(export_results_file) && nzchar(export_results_file)) {
    utils::write.csv(df_out, export_results_file, row.names = FALSE)
  }

  attr(df_out, "effective_sample_name_font_size") <- effective_sample_name_font_size
  df_out
}
