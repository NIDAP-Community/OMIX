# Helper utilities shared across CCBR gene boxplot functions -----------------

boxplot_get_shapelist <- function() {
  setNames(
    0:25,
    c(
      "square",
      "circle",
      "triangle point up",
      "plus",
      "cross",
      "diamond",
      "triangle point down",
      "square cross",
      "star",
      "diamond plus",
      "circle plus",
      "triangles up and down",
      "square plus",
      "circle cross",
      "square and triangle down",
      "filled square",
      "filled circle",
      "filled triangle point-up",
      "filled diamond",
      "solid circle",
      "bullet (smaller circle)",
      "filled circle blue",
      "filled square blue",
      "filled diamond blue",
      "filled triangle point-up blue",
      "filled triangle point down blue"
    )
  )
}

boxplot_load_packages <- function() {
  suppressPackageStartupMessages({
    library(ggplot2)
    library(tidyr)
    library(dplyr)
    library(tibble)
    library(ggbeeswarm)
    library(RColorBrewer)
    library(stringr)
    library(broom)
    library(multcomp)
    library(multcompView)
  })
}

boxplot_get_colorlist <- function() {
  setNames(
    c(
      "#e41a1c",
      "#377eb8",
      "#4daf4a",
      "#984ea3",
      "#ff7f00",
      "#ffff33",
      "#a65628",
      "#f781bf",
      "#999999",
      "#D95F02",
      "#1B9E77",
      "#7570B3",
      "#E7298A",
      "#66A61E",
      "#E6AB02",
      "#A6761D",
      "#666666",
      "#F0027F",
      "#8DD3C7",
      "#000000"
    ),
    c(
      "Deep Red",
      "Vivid Blue",
      "Green",
      "Purple",
      "Bright Orange",
      "Yellow",
      "Brown",
      "Pink",
      "Grey",
      "Burnt Orange",
      "Teal Green",
      "Soft Purple",
      "Hot Pink",
      "Leaf Green",
      "Mustard Yellow",
      "Bronze",
      "Dark Gray",
      "Bright Magenta",
      "Light Aqua",
      "Black"
    )
  )
}

boxplot_maybe_update_genes <- function(genes) {
  if (is.null(genes)) {
    return(NULL)
  }
  if (
    requireNamespace("l2p", quietly = TRUE) &&
      requireNamespace("l2psupp", quietly = TRUE)
  ) {
    updater <- NULL
    if ("updategenes" %in% getNamespaceExports("l2p")) {
      updater <- getExportedValue("l2p", "updategenes")
    }
    if (is.function(updater)) {
      out <- tryCatch(updater(genes), error = function(e) {
        message(
          "Skipping gene symbol update (l2p::updategenes error): ",
          e$message
        )
        return(NULL)
      })
      if (is.data.frame(out) && all(c("oldname", "newname") %in% names(out))) {
        changed <- out[out$oldname != out$newname, , drop = FALSE]
        if (nrow(changed)) {
          apply(changed, 1, function(r) {
            message(
              "Old name: ",
              r[["oldname"]],
              " -> New name: ",
              r[["newname"]]
            )
          })
        }
        return(out$newname)
      }
    }
  }
  genes
}

boxplot_asterisks <- function(p_adj) {
  if (is.na(p_adj)) {
    return(NA_character_)
  }
  if (p_adj < 0.001) {
    return("p < 0.001")
  }
  if (p_adj < 0.01) {
    return(paste0("p = ", format(round(p_adj, 3), nsmall = 3)))
  }
  if (p_adj < 0.05) {
    return(paste0("p = ", format(round(p_adj, 3), nsmall = 3)))
  }
  if (p_adj < 0.10) {
    return(paste0("p = ", format(round(p_adj, 3), nsmall = 3)))
  }
  return(NA_character_)
}

boxplot_anncolor <- function(p, colors) {
  colors <- rep(colors, length.out = 3)
  if (p < 0.001) {
    return(colors[1])
  }
  if (p < 0.01) {
    return(colors[2])
  }
  if (p < 0.05) {
    return(colors[3])
  }
  return(colors[1])
}

boxplot_make_palette <- function(
  levels,
  palette_name = "Set1",
  use_custom_colors = FALSE,
  colors_to_use = NULL
) {
  if (use_custom_colors && !is.null(colors_to_use)) {
    cmap <- boxplot_get_colorlist()
    missing <- setdiff(colors_to_use, names(cmap))
    if (length(missing)) {
      warning("Colors not available: ", paste(missing, collapse = ", "))
    }
    hex <- unname(cmap[intersect(colors_to_use, names(cmap))])
    if (!length(hex)) {
      hex <- RColorBrewer::brewer.pal(max(3, length(levels)), palette_name)
    }
    if (length(levels) > length(hex)) {
      hex <- rep(hex, length.out = length(levels))
    }
    names(hex) <- levels
    return(hex)
  } else {
    pal <- RColorBrewer::brewer.pal(
      max(3, length(levels)),
      palette_name
    )[seq_along(levels)]
    names(pal) <- levels
    return(pal)
  }
}

boxplot_compute_font_sizes <- function(
  n_categories,
  panel_width_inches = 4.5,
  base_reference_width = 6
) {
  n_categories <- max(1, as.integer(n_categories))
  panel_width_inches <- max(0.5, panel_width_inches)
  base_size <- 11 *
    (panel_width_inches / base_reference_width) *
    (1 + (max(0, 4 - n_categories) * 0.05))
  axis_text_size <- round(base_size, 1)
  axis_title_size <- round(base_size + 2, 1)
  title_size <- round(base_size + 4, 1)
  list(
    x_axis_text_size = axis_text_size,
    y_axis_text_size = axis_text_size,
    x_axis_title_size = axis_title_size,
    y_axis_title_size = axis_title_size,
    title_size = title_size,
    legend_text_size = axis_text_size,
    annotation_text_size = max(5, axis_text_size - 1),
    annotation_line_width = 0.6
  )
}

boxplot_calculate_letter_positions <- function(df_long, gene_name) {
  sub <- df_long %>% dplyr::filter(.data$gene == gene_name)
  max_vals <- sub %>%
    dplyr::group_by(.data$category) %>%
    dplyr::summarise(
      max_value = max(.data$value, na.rm = TRUE),
      .groups = "drop"
    )
  max_vals$letter_y <- max_vals$max_value + pmax(max_vals$max_value * 0.08, 0.2)
  max_vals
}

utils::globalVariables(c(
  "category",
  "value",
  "n_samples",
  "q1",
  "q3",
  "iqr",
  "upper_fence",
  "max_val",
  "whisker_top",
  "letter_y",
  "max_value",
  "comparison",
  "p_adj",
  "p_value",
  "group1",
  "group2",
  "sample",
  "gene"
))

boxplot_prepare_long <- function(
  normalized_counts,
  sample_metadata,
  gene_column,
  sample_column,
  category_column,
  genes = NULL,
  sum_duplicates = TRUE,
  categories = NULL,
  samples_to_include = NULL,
  samples_to_exclude = NULL,
  filter_by_metadata = FALSE,
  metadata_filter_column = NULL,
  metadata_filter_values = NULL,
  metadata_filter_operator = c("include", "exclude"),
  extra_metadata_columns = NULL,
  minimum_samples_per_category = 3
) {
  metadata_filter_operator <- match.arg(
    metadata_filter_operator,
    c("include", "exclude")
  )
  genes_updated <- boxplot_maybe_update_genes(genes)

  df <- normalized_counts
  if (!is.null(genes_updated)) {
    df <- df[df[[gene_column]] %in% genes_updated, , drop = FALSE]
  }

  original_category_levels <- NULL
  if (is.factor(sample_metadata[[category_column]])) {
    original_category_levels <- levels(sample_metadata[[category_column]])
  }

  sample_metadata[[sample_column]] <- as.character(sample_metadata[[
    sample_column
  ]])
  sample_metadata[[category_column]] <- as.character(sample_metadata[[
    category_column
  ]])

  available_samples <- unique(sample_metadata[[sample_column]])
  sample_cols <- intersect(available_samples, names(df))
  if (!length(sample_cols)) {
    numeric_cols <- names(df)[vapply(df, is.numeric, logical(1))]
    sample_cols <- intersect(numeric_cols, names(df))
  }
  if (!length(sample_cols)) {
    stop("No overlapping sample columns found between counts and metadata.")
  }

  df_long <- df %>%
    tidyr::pivot_longer(
      cols = tidyselect::all_of(sample_cols),
      names_to = "sample",
      values_to = "value"
    ) %>%
    dplyr::filter(
      !is.na(.data[[gene_column]]),
      .data[[gene_column]] != "---"
    ) %>%
    dplyr::rename(gene = !!rlang::sym(gene_column))

  if (!nrow(df_long)) {
    stop("No data available after filtering by gene selection.")
  }

  if (sum_duplicates) {
    df_long <- df_long %>%
      dplyr::group_by(.data$gene, .data$sample) %>%
      dplyr::summarise(value = sum(.data$value, na.rm = TRUE), .groups = "drop")
  }

  extra_metadata_columns <- unique(stats::na.omit(extra_metadata_columns))
  extra_metadata_columns <- setdiff(
    extra_metadata_columns,
    c(sample_column, category_column)
  )
  extra_metadata_columns <- intersect(extra_metadata_columns, names(sample_metadata))

  meta <- sample_metadata %>%
    dplyr::rename(
      sample = !!rlang::sym(sample_column),
      category = !!rlang::sym(category_column)
    ) %>%
    dplyr::select(dplyr::all_of(c("sample", "category", extra_metadata_columns)))

  if (!length(original_category_levels)) {
    original_category_levels <- unique(meta$category)
  }

  df_long <- df_long %>%
    dplyr::inner_join(meta, by = "sample") %>%
    dplyr::mutate(
      category = ifelse(is.na(.data$category), "NA", .data$category)
    )

  selected_samples <- available_samples
  if (!is.null(samples_to_include)) {
    selected_samples <- intersect(selected_samples, samples_to_include)
  }
  if (!is.null(samples_to_exclude)) {
    selected_samples <- setdiff(selected_samples, samples_to_exclude)
  }

  if (
    filter_by_metadata &&
      !is.null(metadata_filter_column) &&
      !is.null(metadata_filter_values)
  ) {
    if (metadata_filter_operator == "include") {
      keep <- sample_metadata %>%
        dplyr::filter(
          .data[[metadata_filter_column]] %in% metadata_filter_values
        ) %>%
        dplyr::pull(.data[[sample_column]])
      selected_samples <- intersect(selected_samples, keep)
    } else {
      drop <- sample_metadata %>%
        dplyr::filter(
          .data[[metadata_filter_column]] %in% metadata_filter_values
        ) %>%
        dplyr::pull(.data[[sample_column]])
      selected_samples <- setdiff(selected_samples, drop)
    }
  }

  df_long <- df_long %>% dplyr::filter(.data$sample %in% selected_samples)

  valid_categories <- categories
  if (!is.null(categories)) {
    df_long <- df_long %>% dplyr::filter(.data$category %in% categories)
  }

  if (!nrow(df_long)) {
    stop("No data remaining after applying sample or category filters.")
  }

  if (!is.null(minimum_samples_per_category)) {
    counts <- df_long %>% dplyr::count(.data$category, name = "n_samples")
    keep_cats <- counts %>%
      dplyr::filter(.data$n_samples >= minimum_samples_per_category) %>%
      dplyr::pull(.data$category)
    valid_categories <- if (!is.null(categories)) {
      intersect(categories, keep_cats)
    } else {
      keep_cats
    }
    df_long <- df_long %>% dplyr::filter(.data$category %in% valid_categories)
  }

  if (!nrow(df_long)) {
    stop("No data remaining after minimum sample filtering.")
  }

  if (is.null(valid_categories) || !length(valid_categories)) {
    valid_categories <- unique(df_long$category)
  }

  current_categories <- unique(df_long$category)
  level_order <- if (!is.null(categories) && length(categories)) {
    # Honour the user-supplied categories order, keeping only those present
    categories[categories %in% current_categories]
  } else if (!is.null(original_category_levels)) {
    original_category_levels[original_category_levels %in% current_categories]
  } else {
    current_categories
  }
  if (!length(level_order)) {
    level_order <- current_categories
  }
  df_long$category <- factor(df_long$category, levels = level_order)

  valid_categories <- unique(as.character(valid_categories))

  list(
    df_long = df_long,
    valid_categories = valid_categories,
    genes_requested = genes_updated
  )
}

boxplot_extract_deg_stats <- function(
  deg_results,
  gene_column,
  genes = NULL,
  categories = NULL,
  padj_suffix = "_adjpval",
  pval_suffix = "_pval"
) {
  if (!is.null(genes)) {
    deg_results <- deg_results[
      deg_results[[gene_column]] %in% genes,
      ,
      drop = FALSE
    ]
  }
  if (!nrow(deg_results)) {
    return(tibble::tibble())
  }

  padj_cols <- grep(
    paste0(stringr::fixed(padj_suffix), "$"),
    names(deg_results),
    value = TRUE
  )
  if (!length(padj_cols)) {
    return(tibble::tibble())
  }

  adj_long <- deg_results[, c(gene_column, padj_cols), drop = FALSE] %>%
    tidyr::pivot_longer(
      cols = tidyselect::all_of(padj_cols),
      names_to = "comparison",
      values_to = "p_adj"
    ) %>%
    dplyr::mutate(
      comparison = stringr::str_remove(
        .data$comparison,
        paste0(stringr::fixed(padj_suffix), "$")
      )
    ) %>%
    tidyr::separate(
      .data$comparison,
      into = c("group1", "group2"),
      sep = "-(?=[^-]*$)",
      remove = TRUE
    ) %>%
    dplyr::rename(gene = !!rlang::sym(gene_column))

  if (!is.null(categories)) {
    adj_long <- adj_long %>%
      dplyr::filter(.data$group1 %in% categories, .data$group2 %in% categories)
  }

  raw_cols <- grep(
    paste0(stringr::fixed(pval_suffix), "$"),
    names(deg_results),
    value = TRUE
  )
  if (length(raw_cols)) {
    raw_long <- deg_results[, c(gene_column, raw_cols), drop = FALSE] %>%
      tidyr::pivot_longer(
        cols = tidyselect::all_of(raw_cols),
        names_to = "comparison",
        values_to = "p_value"
      ) %>%
      dplyr::mutate(
        comparison = stringr::str_remove(
          .data$comparison,
          paste0(stringr::fixed(pval_suffix), "$")
        )
      ) %>%
      tidyr::separate(
        .data$comparison,
        into = c("group1", "group2"),
        sep = "-(?=[^-]*$)",
        remove = TRUE
      ) %>%
      dplyr::rename(gene = !!rlang::sym(gene_column))

    adj_long <- adj_long %>%
      dplyr::left_join(raw_long, by = c("gene", "group1", "group2"))
  } else {
    adj_long <- adj_long %>% dplyr::mutate(p_value = NA_real_)
  }

  adj_long %>%
    dplyr::filter(!is.na(.data$group1), !is.na(.data$group2)) %>%
    dplyr::distinct()
}

boxplot_covariate_pairwise_stats <- function(
  sub,
  gene_name,
  covariate_columns = NULL,
  padj = "BH"
) {
  covariate_columns <- unique(stats::na.omit(covariate_columns))
  covariate_columns <- covariate_columns[covariate_columns %in% names(sub)]
  category_levels <- levels(sub$category)
  if (is.null(category_levels)) {
    category_levels <- unique(as.character(sub$category))
  }
  category_levels <- category_levels[category_levels %in% unique(as.character(sub$category))]
  if (length(category_levels) < 2) {
    return(tibble::tibble())
  }

  stats_list <- list()
  pair_index <- 0L
  pair_grid <- utils::combn(category_levels, 2, simplify = FALSE)

  for (pair in pair_grid) {
    group2 <- pair[[1]]
    group1 <- pair[[2]]
    model_df <- sub %>%
      dplyr::filter(.data$category %in% c(group2, group1)) %>%
      dplyr::mutate(category = factor(as.character(.data$category), levels = c(group2, group1)))

    model_cols <- c("value", "category", covariate_columns)
    model_df <- model_df[, model_cols, drop = FALSE]
    model_df <- model_df[stats::complete.cases(model_df), , drop = FALSE]
    if (nrow(model_df) < 3 || dplyr::n_distinct(model_df$category) < 2) {
      next
    }

    usable_covariates <- covariate_columns[
      vapply(covariate_columns, function(covar) {
        x <- model_df[[covar]]
        if (is.numeric(x) || is.integer(x)) {
          return(stats::sd(x, na.rm = TRUE) > 0)
        }
        dplyr::n_distinct(x) > 1
      }, logical(1))
    ]

    for (covar in usable_covariates) {
      if (!is.numeric(model_df[[covar]]) && !is.integer(model_df[[covar]])) {
        model_df[[covar]] <- factor(model_df[[covar]])
      }
    }

    formula_text <- paste(
      "value ~ category",
      if (length(usable_covariates)) {
        paste("+", paste(sprintf("`%s`", usable_covariates), collapse = " + "))
      } else {
        ""
      }
    )

    fit <- try(stats::lm(stats::as.formula(formula_text), data = model_df), silent = TRUE)
    if (inherits(fit, "try-error")) {
      next
    }
    coef_tbl <- try(summary(fit)$coefficients, silent = TRUE)
    if (inherits(coef_tbl, "try-error")) {
      next
    }
    category_coef <- grep("^category", rownames(coef_tbl), value = TRUE)
    if (!length(category_coef)) {
      next
    }
    category_coef <- category_coef[[1]]
    if (is.na(coef_tbl[category_coef, "Pr(>|t|)"])) {
      next
    }

    pair_index <- pair_index + 1L
    stats_list[[pair_index]] <- tibble::tibble(
      group1 = group1,
      group2 = group2,
      estimate = unname(coef_tbl[category_coef, "Estimate"]),
      statistic = unname(coef_tbl[category_coef, "t value"]),
      p_value = unname(coef_tbl[category_coef, "Pr(>|t|)"]),
      covariates = if (length(usable_covariates)) {
        paste(usable_covariates, collapse = ";")
      } else {
        ""
      },
      gene = gene_name
    )
  }

  st <- dplyr::bind_rows(stats_list)
  if (!nrow(st)) {
    return(st)
  }
  st %>%
    dplyr::mutate(p_adj = stats::p.adjust(.data$p_value, method = padj))
}

boxplot_pairwise_letters <- function(
  pairwise_stats,
  category_levels,
  gene_name,
  threshold = 0.05
) {
  if (
    is.null(pairwise_stats) ||
      !nrow(pairwise_stats) ||
      !all(c("group1", "group2", "p_adj") %in% names(pairwise_stats))
  ) {
    return(NULL)
  }

  pvals_df <- pairwise_stats %>%
    dplyr::filter(
      !is.na(.data$p_adj),
      .data$group1 %in% category_levels,
      .data$group2 %in% category_levels
    )
  if (!nrow(pvals_df)) {
    return(NULL)
  }

  safe_levels <- stats::setNames(
    paste0("G", seq_along(category_levels)),
    category_levels
  )
  original_levels <- stats::setNames(names(safe_levels), safe_levels)

  pvals <- pvals_df$p_adj
  names(pvals) <- paste(
    safe_levels[pvals_df$group1],
    safe_levels[pvals_df$group2],
    sep = "-"
  )
  out <- try(
    multcompView::multcompLetters(pvals, threshold = threshold),
    silent = TRUE
  )
  if (inherits(out, "try-error")) {
    return(NULL)
  }

  tibble::tibble(
    category = unname(original_levels[names(out$Letters)]),
    letters = unname(out$Letters),
    gene = gene_name
  ) %>%
    dplyr::filter(.data$category %in% category_levels)
}

gene_boxplot_core <- function(
  df_long,
  stats_all,
  letters_all,
  valid_categories,
  categories,
  category_labels,
  palette,
  use_custom_colors,
  colors_to_use,
  shapes_to_use,
  significance_colors_to_use,
  plot_type,
  plot_width,
  draw_jitterplot,
  dot_size,
  jitter_width,
  jitter_height,
  dodge_width,
  beeswarm_spread,
  beeswarm_method,
  add_annotations,
  annotation_line_width,
  annotation_text_size,
  use_significance_letters,
  maximum_pairwise_annotations,
  ylim_cap,
  x_axis_title,
  x_axis_title_size,
  show_x_axis_text,
  x_axis_text_size,
  y_axis_title,
  y_axis_title_size,
  show_y_axis_text,
  y_axis_text_size,
  title,
  title_position,
  title_size,
  title_face,
  legend_text_size,
  legend_text_face,
  legend_position,
  legend_title,
  legend_title_size,
  add_vertical_divider,
  vertical_divider_after,
  vertical_divider_linetype,
  vertical_divider_color,
  vertical_divider_linewidth,
  left_margin,
  right_margin,
  top_margin,
  bottom_margin,
  statistical_method_label,
  significance_threshold = 0.10,
  return_full = FALSE,
  genes_requested = NULL
) {
  if (is.null(stats_all)) {
    stats_all <- tibble::tibble()
  }
  if (!"gene" %in% names(stats_all)) {
    stats_all$gene <- character(nrow(stats_all))
  }
  if (
    nrow(stats_all) &&
      !"p_adj" %in% names(stats_all) &&
      "p.value" %in% names(stats_all)
  ) {
    stats_all <- stats_all %>% dplyr::rename(p_adj = .data$p.value)
  }

  shape_map <- boxplot_get_shapelist()
  plots <- lapply(unique(df_long$gene), function(g) {
    sub <- df_long %>% dplyr::filter(.data$gene == g)
    levels_cat <- levels(sub$category)

    colors <- boxplot_make_palette(
      levels_cat,
      palette_name = palette,
      use_custom_colors = use_custom_colors,
      colors_to_use = colors_to_use
    )

    label_map <- NULL
    if (!is.null(category_labels)) {
      if (
        !is.null(names(category_labels)) && any(nzchar(names(category_labels)))
      ) {
        label_map <- category_labels
      } else if (
        !is.null(categories) && length(category_labels) == length(categories)
      ) {
        label_map <- stats::setNames(category_labels, categories)
      } else if (length(category_labels) == length(levels_cat)) {
        label_map <- stats::setNames(category_labels, levels_cat)
      }
    }

    if (!is.null(label_map)) {
      lbls <- stats::setNames(
        ifelse(
          levels_cat %in% names(label_map),
          label_map[levels_cat],
          levels_cat
        ),
        levels_cat
      )
    } else {
      lbls <- stats::setNames(levels_cat, levels_cat)
    }

    shp <- if (length(shapes_to_use) == 1) {
      rep(shape_map[shapes_to_use], length(levels_cat))
    } else {
      shape_map[shapes_to_use]
    }
    shp <- stats::setNames(unname(shp)[seq_along(levels_cat)], levels_cat)

    gp <- ggplot2::ggplot(
      sub,
      ggplot2::aes(
        x = .data$category,
        y = .data$value,
        color = .data$category,
        fill = .data$category,
        shape = .data$category
      )
    )
    anno_top <- NULL
    if (plot_type == "Box plot") {
      gp <- gp +
        ggplot2::geom_boxplot(
          width = plot_width,
          alpha = 0.3,
          outlier.shape = NA
        )
    } else {
      gp <- gp +
        ggplot2::geom_violin(
          trim = FALSE,
          width = plot_width,
          alpha = 0.3,
          position = ggplot2::position_dodge(width = plot_width),
          scale = "width"
        )
    }

    if (draw_jitterplot) {
      gp <- gp +
        ggplot2::geom_jitter(
          position = ggplot2::position_jitter(
            width = jitter_width,
            height = jitter_height
          ),
          size = dot_size,
          show.legend = c(shape = FALSE, color = TRUE)
        )
    } else {
      gp <- gp +
        ggbeeswarm::geom_beeswarm(
          cex = beeswarm_spread,
          size = dot_size,
          dodge.width = dodge_width,
          priority = beeswarm_method,
          show.legend = c(shape = FALSE, color = TRUE)
        )
    }

    gene_stats <- stats_all %>% dplyr::filter(.data$gene == g)
    if (
      nrow(gene_stats) &&
        !"p_adj" %in% names(gene_stats) &&
        "p.value" %in% names(gene_stats)
    ) {
      gene_stats <- gene_stats %>% dplyr::rename(p_adj = .data$p.value)
    }

    if (add_annotations && nrow(gene_stats)) {
      sig_n <- gene_stats %>%
        dplyr::filter(
          !is.na(.data$p_adj),
          .data$p_adj < significance_threshold
        ) %>%
        nrow()
      use_letters_for_gene <- isTRUE(use_significance_letters) &&
        !is.null(letters_all) &&
        (
          is.null(maximum_pairwise_annotations) ||
            sig_n > maximum_pairwise_annotations
        )
      if (use_letters_for_gene) {
        gene_letters <- letters_all %>% dplyr::filter(.data$gene == g)
        pos <- boxplot_calculate_letter_positions(df_long, g)
        letter_data <- gene_letters %>% dplyr::left_join(pos, by = "category")
        gp <- gp +
          ggplot2::geom_text(
            data = letter_data,
            ggplot2::aes(
              x = .data$category,
              y = .data$letter_y,
              label = .data$letters
            ),
            color = "black",
            size = annotation_text_size * 0.8,
            inherit.aes = FALSE,
            vjust = 0
          )
      } else {
        data_max <- max(sub$value, na.rm = TRUE)
        data_min <- min(sub$value, na.rm = TRUE)

        whisker_tops <- sub %>%
          dplyr::group_by(.data$category) %>%
          dplyr::summarise(
            q1 = stats::quantile(.data$value, 0.25, na.rm = TRUE),
            q3 = stats::quantile(.data$value, 0.75, na.rm = TRUE),
            iqr = .data$q3 - .data$q1,
            upper_fence = .data$q3 + 1.5 * .data$iqr,
            max_val = max(.data$value, na.rm = TRUE),
            whisker_top = pmin(.data$upper_fence, .data$max_val),
            .groups = "drop"
          )
        max_whisker <- max(whisker_tops$whisker_top, na.rm = TRUE)

        if (!is.null(ylim_cap)) {
          effective_max <- max_whisker
          y_range <- ylim_cap
        } else {
          effective_max <- max_whisker
          y_range <- data_max - data_min
        }

        base_pad <- y_range * 0.10
        base_y <- effective_max + base_pad
        line_spacing <- y_range * 0.12
        line_to_text_gap <- y_range * 0.04
        min_clearance <- y_range * 0.02
        current_top <- effective_max

        annos <- gene_stats %>%
          dplyr::filter(
            !is.na(.data$p_adj),
            .data$p_adj < significance_threshold
          )
        if (nrow(annos) && all(c("group1", "group2") %in% names(annos))) {
          for (i in seq_len(nrow(annos))) {
            cmp <- annos[i, ]
            x1 <- which(levels_cat == cmp$group1)
            x2 <- which(levels_cat == cmp$group2)
            if (!length(x1) || !length(x2)) {
              next
            }

            proposed_line_y <- base_y + (i - 1) * line_spacing
            line_y <- max(proposed_line_y, current_top + min_clearance)
            text_y <- line_y + line_to_text_gap

            gp <- gp +
              ggplot2::annotate(
                "segment",
                x = x1,
                xend = x2,
                y = line_y,
                yend = line_y,
                linewidth = annotation_line_width,
                color = boxplot_anncolor(
                  cmp$p_adj,
                  significance_colors_to_use
                )
              ) +
              ggplot2::annotate(
                "text",
                x = mean(c(x1, x2)),
                y = text_y,
                label = boxplot_asterisks(cmp$p_adj),
                size = annotation_text_size * 0.50,
                fontface = "italic",
                color = boxplot_anncolor(
                  cmp$p_adj,
                  significance_colors_to_use
                )
              )
            current_top <- max(current_top, text_y)
            anno_top <- max(c(anno_top, text_y), na.rm = TRUE)
          }
        }
      }
    }

    gp <- gp +
      ggplot2::scale_color_manual(
        values = colors,
        labels = lbls,
        name = ifelse(identical(legend_title, "auto"), "", legend_title)
      ) +
      ggplot2::scale_fill_manual(
        values = colors,
        labels = lbls,
        name = ifelse(identical(legend_title, "auto"), "", legend_title)
      ) +
      ggplot2::scale_shape_manual(values = shp) +
      ggplot2::scale_x_discrete(labels = stringr::str_wrap(lbls, width = 10)) +
      {
        if (!is.null(ylim_cap)) {
          ggplot2::scale_y_continuous(limits = c(0, ylim_cap), expand = c(0, 0))
        } else {
          NULL
        }
      } +
      ggplot2::labs(
        title = ifelse(identical(title, "auto"), g, title),
        x = ifelse(identical(x_axis_title, "auto"), "", x_axis_title),
        y = ifelse(identical(y_axis_title, "auto"), g, y_axis_title)
      ) +
      ggplot2::theme_classic() +
      ggplot2::theme(
        plot.title = ggplot2::element_text(
          hjust = title_position,
          size = title_size,
          face = title_face
        ),
        axis.text.x = if (isTRUE(show_x_axis_text)) {
          ggplot2::element_text(
            size = x_axis_text_size,
            angle = 45,
            hjust = 1,
            vjust = 1
          )
        } else {
          ggplot2::element_blank()
        },
        axis.text.y = if (isTRUE(show_y_axis_text)) {
          ggplot2::element_text(size = y_axis_text_size)
        } else {
          ggplot2::element_blank()
        },
        axis.title.x = ggplot2::element_text(size = x_axis_title_size),
        axis.title.y = ggplot2::element_text(size = y_axis_title_size),
        legend.position = legend_position,
        legend.box = "vertical",
        legend.text = ggplot2::element_text(
          size = legend_text_size,
          face = legend_text_face
        ),
        legend.title = ggplot2::element_text(size = legend_title_size),
        plot.margin = ggplot2::margin(
          t = top_margin,
          r = right_margin,
          b = bottom_margin,
          l = left_margin,
          unit = "cm"
        )
      ) +
      ggplot2::expand_limits(
        y = c(
          min(sub$value, na.rm = TRUE) - 0.5,
          if (!is.null(anno_top)) {
            anno_top + (max(sub$value, na.rm = TRUE) * 0.05)
          } else {
            max(sub$value, na.rm = TRUE) + 0.5
          }
        )
      ) +
      ggplot2::guides(shape = "none")

    if (isTRUE(add_vertical_divider) && length(levels_cat) > 1) {
      xintercept <- NA_real_

      if (is.null(vertical_divider_after)) {
        cd4_idx <- grep("CD4", levels_cat, ignore.case = TRUE)
        cd8_idx <- grep("CD8", levels_cat, ignore.case = TRUE)
        if (length(cd4_idx) && length(cd8_idx)) {
          boundary <- max(cd4_idx)
          if (boundary < length(levels_cat)) {
            xintercept <- boundary + 0.5
          }
        }
      } else if (
        is.numeric(vertical_divider_after) &&
          length(vertical_divider_after) == 1
      ) {
        boundary <- as.integer(vertical_divider_after)
        if (
          !is.na(boundary) && boundary >= 1 && boundary < length(levels_cat)
        ) {
          xintercept <- boundary + 0.5
        }
      } else if (
        is.character(vertical_divider_after) &&
          length(vertical_divider_after) == 1
      ) {
        boundary <- match(vertical_divider_after, levels_cat)
        if (!is.na(boundary) && boundary < length(levels_cat)) {
          xintercept <- boundary + 0.5
        }
      }

      if (!is.na(xintercept)) {
        gp <- gp +
          ggplot2::geom_vline(
            xintercept = xintercept,
            linetype = vertical_divider_linetype,
            color = vertical_divider_color,
            linewidth = vertical_divider_linewidth
          )
      }
    }

    print(gp)
    gp
  })

  names(plots) <- unique(df_long$gene)

  out <- list(
    data = df_long,
    stats = stats_all,
    letters = letters_all,
    plots = plots,
    valid_categories = valid_categories,
    parameters = list(
      statistical_method = statistical_method_label,
      categories = categories,
      category_labels = category_labels,
      genes_requested = genes_requested
    )
  )
  class(out) <- c("gene_boxplot_stats", class(out))

  if (isTRUE(return_full)) {
    out
  } else {
    stats_all
  }
}

# All ccbr_ compatibility aliases removed as requested

#' Gene Boxplot with Statistics [CCBR] [Beta]
#'
#' Given a gene expression matrix/data.frame and sample metadata, compare genes
#' across categories, run chosen statistical tests, draw box/violin + jitter/beeswarm,
#' optionally annotate significance (asterisks or letters), and return stats.
#'
#' Required columns:
#' - normalized_counts: gene_column + one numeric column per sample
#' - sample_metadata: sample_column + category_column (and any filter column used)
#'
#' @param normalized_counts Normalized Gene Expression matrix on which individual genes are compared across groups. (JSON: **Normalized Counts**)
#' @param sample_metadata Sample metadata accompanying normalized counts. At least one column needs to match the column names of the counts matrix. (JSON: **Sample Metadata**)
#' @param gene_column Column that contains Gene Symbol. (JSON: **Gene Column**)
#' @param sample_column Column containing sample name. (JSON: **Sample Column**)
#' @param genes List of genes on which to apply statistical tests. (JSON: **Genes**)
#' @param sum_duplicates For RNA-Seq data, duplicate genes are summed. Otherwise, the maximum values are taken (recommended for microarrays). (JSON: **Sum Duplicates**)
#' @param statistical_method Test to run. Usually "anova" but t-test and kruskal-wallis are also available. (JSON: **Statistical Method**)
#' @param category_column Column from which categories will be chosen to run statistical analysis. (JSON: **Category Column**)
#' @param categories Categories from the Category Column from which gene expression results will be compared. (JSON: **Categories**)
#' @param category_labels Replace original category names with new names. Categories renamed in the order they appear. (JSON: **Category Labels**)
#' @param samples_to_include Select samples to include in the analysis. If left blank, will include all samples in counts table. (JSON: **Samples to Include**)
#' @param samples_to_exclude Select samples to exclude from analysis. If blank, all samples will be included. (JSON: **Samples to exclude**)
#' @param filter_by_metadata If FALSE, will not apply a metadata filter. If TRUE, will apply filter on selected metadata column (below). (JSON: **Filter by Metadata**)
#' @param metadata_filter_column Metadata Column from which to filter metadata values for sample selection. (JSON: **Metadata Filter Column**)
#' @param metadata_filter_values Values to include or exclude from analysis. (JSON: **Metadata Filter Values**)
#' @param metadata_filter_operator If "include", include metadata values in sample selection. (JSON: **Metadata Filter Operator**)
#' @param minimum_samples_per_category Only include categories that have 3 or more samples. (JSON: **Minimum Samples per Category**)
#' @param plot_type Select type of plot. (JSON: **Plot Type**; options: Box plot, Violin Plot)
#' @param plot_width Set width of plot. (JSON: **Plot Width**)
#' @param left_margin Left margin (cm). (JSON: **Left Margin**)
#' @param right_margin Right margin (cm). (JSON: **Right Margin**)
#' @param top_margin Top margin (cm). (JSON: **Top Margin**)
#' @param bottom_margin Bottom margin (cm). (JSON: **Bottom Margin**)
#' @param use_custom_colors TRUE to use colors to use, FALSE to use palette name. (JSON: **Use Custom Colors**)
#' @param palette Select Color Palette for Box Plot. (JSON: **Palette**; e.g., Set1, Set2, Pastel1, Dark2, etc.)
#' @param colors_to_use Select as many colors as needed for plotting. Usually as many as number of categories and assigned in the same order as categories selected. If a single color is selected, it will be used for all categories. (JSON: **Colors to Use**)
#' @param shapes_to_use Select as many shapes as needed for plotting. It can be as many as the number of categories and assigned in the same order as categories selected. If a single shape is selected, it will be used for all categories. (JSON: **Shapes to Use**)
#' @param significance_colors_to_use Select color as needed for plotting significance annotations. (JSON: **Significance Colors to Use**)
#' @param x_axis_title If set to "auto" will use category labels. (JSON: **X-axis Title**)
#' @param x_axis_title_size x-axis Title font size. (JSON: **X-axis Title Size**)
#' @param show_x_axis_text If FALSE, do not add x-axis text. (JSON: **Show x-axis Text**)
#' @param x_axis_text_size Text size for x-axis labels. (JSON: **x-axis Text Size**)
#' @param y_axis_title If "auto" will use gene name. (JSON: **Y-axis Title**)
#' @param y_axis_title_size Y-axis title font size. (JSON: **Y-axis Title Size**)
#' @param show_y_axis_text Show Y-axis text if TRUE. (JSON: **Show y-axis Text**)
#' @param y_axis_text_size Y-axis Text font size. (JSON: **Y-axis Text Size**)
#' @param title If "auto" will use gene name, otherwise, "none". (JSON: **Title**)
#' @param title_position Position of title with relation to plot. Higher numbers result in higher position (mapped here to `hjust`). (JSON: **Title Position**)
#' @param title_size Title size. (JSON: **Title Size**)
#' @param title_face Title face. (JSON: **Title Face**; plain, bold, italic, bold.italic)
#' @param legend_text_size Legend text size. (JSON: **Legend Text Size**)
#' @param legend_text_face Legend text face. (JSON: **Legend Text Face**)
#' @param legend_position Legend position. (JSON: **Legend Position**; none, right, top, bottom)
#' @param legend_title If "auto" no legend title. (JSON: **Legend Title**)
#' @param legend_title_size Legend title size. (JSON: **Legend Title Size**)
#' @param add_vertical_divider If TRUE, draw a vertical divider line between groups on the x-axis. (JSON: **Add Vertical Divider**)
#' @param vertical_divider_after Divider placement control. Use `NULL` for automatic CD4/CD8 boundary detection, a category name (character) to draw after that category, or an integer position to draw after that x-axis index. (JSON: **Vertical Divider After**)
#' @param vertical_divider_linetype Line type for vertical divider (e.g., "dashed", "solid"). (JSON: **Vertical Divider Linetype**)
#' @param vertical_divider_color Color for vertical divider. (JSON: **Vertical Divider Color**)
#' @param vertical_divider_linewidth Line width for vertical divider. (JSON: **Vertical Divider Line Width**)
#' @param draw_jitterplot If TRUE, draw normal jitterplot. If FALSE, draw beeswarm plot. (JSON: **Draw Jitterplot**)
#' @param dot_size Dot size for plot. (JSON: **Dot Size**)
#' @param jitter_width Jitter plot width. (JSON: **Jitter Width**)
#' @param jitter_height Jitter plot height. (JSON: **Jitter Height**)
#' @param dodge_width Dodge width controls sideways spread along the x-axis to avoid overlapping. Larger numbers increase separation between groups. (JSON: **Dodge Width**)
#' @param beeswarm_spread Increasing the spread in a beeswarm plot helps in reducing point overlap and enhancing the visibility of each data point. (JSON: **Beeswarm Spread**)
#' @param beeswarm_method Method determines how points are positioned within the swarm plot (order/priority). (JSON: **Beeswarm Method**; ascending, descending, density, random, none)
#' @param add_annotations If TRUE, add annotations for gene significance on plots. (JSON: **Add Annotations**)
#' @param annotation_line_width Annotation line width for significance results. (JSON: **Annotation Line Width**)
#' @param annotation_text_size Size of asterisks: * for p<0.05, ** for p<0.01, *** for p<0.001. (JSON: **Annotation Text Size**)
#' @param use_significance_letters Use significance letters instead of asterisks on plot. (JSON: **Use Significance Letters**)
#' @param maximum_pairwise_annotations Maximum number of annotations using asterisks. Above this number, use significance letters. (JSON: **Maximum Pairwise Annotations**)
#' @param p_adjust_method Method for p-value adjustment in pairwise comparisons. Use `"none"` for unadjusted p-values, `"BH"` (default) for Benjamini-Hochberg FDR correction, or any method accepted by `p.adjust()`. For `statistical_method = "anova"`, the default uses Tukey HSD; setting this to `"none"` or any other method switches to `pairwise.t.test` with that adjustment. (JSON: **P-Value Adjustment Method**)
#' @param ylim_cap Optional y-axis upper limit for visualization. If NULL (default), uses data range. If specified, caps y-axis at this value while keeping all data for statistics.
#' @param font_scaling Control automatic font scaling. Use "match_anova" to mirror legacy ANOVA script sizing or "none" to honor supplied sizes.
#' @param panel_width_inches Reference panel width (inches) used when `font_scaling = "match_anova"`.
#' @param export_plot_dir Optional output directory to save one PNG per gene plot. If NULL (default), plots are not saved.
#' @param export_plot_prefix Optional prefix added to each exported plot filename.
#' @param export_plot_width Plot width for exported PNG files.
#' @param export_plot_height Plot height for exported PNG files.
#' @param export_plot_dpi Resolution (DPI) for exported PNG files.
#' @param export_stats_file Optional path to export pairwise statistics as CSV. If NULL (default), stats are not saved.
#'
#' @return data.frame of pairwise stats (returned visibly). Additionally, an invisible list is returned:
#'         `list(data, stats, letters, plots, valid_categories)`.
#'
#' @examples
#' # res <- gene_boxplot_with_stats(norm_counts, meta,
#' #   gene_column="Gene", sample_column="SampleID", category_column="Group",
#' #   genes=c("CD3D","MS4A1"))
gene_boxplot_with_stats <- function(
  normalized_counts,
  sample_metadata,
  gene_column,
  sample_column,
  genes = NULL,
  sum_duplicates = TRUE,
  statistical_method = c("anova", "t-test", "kruskal"),
  category_column,
  categories = NULL,
  category_labels = NULL,
  samples_to_include = NULL,
  samples_to_exclude = NULL,
  filter_by_metadata = FALSE,
  metadata_filter_column = NULL,
  metadata_filter_values = NULL,
  metadata_filter_operator = c("include", "exclude"),
  covariate_columns = NULL,
  minimum_samples_per_category = 3,
  plot_type = c("Box plot", "Violin Plot"),
  plot_width = 0.3,
  left_margin = 0.5,
  right_margin = 0.5,
  top_margin = 0.5,
  bottom_margin = 0.5,
  use_custom_colors = TRUE,
  palette = "Dark2",
  colors_to_use = c(
    "Deep Red",
    "Vivid Blue",
    "Green",
    "Purple",
    "Bright Orange",
    "Yellow",
    "Brown",
    "Pink",
    "Grey",
    "Burnt Orange",
    "Teal Green",
    "Soft Purple",
    "Hot Pink",
    "Leaf Green",
    "Mustard Yellow"
  ),
  shapes_to_use = c("filled circle"),
  significance_colors_to_use = "black",
  x_axis_title = "auto",
  x_axis_title_size = 13,
  show_x_axis_text = TRUE,
  x_axis_text_size = 11,
  y_axis_title = "auto",
  y_axis_title_size = 13,
  show_y_axis_text = TRUE,
  y_axis_text_size = 11,
  title = "auto",
  title_position = 0.5,
  title_size = 13,
  title_face = "italic",
  legend_text_size = 11,
  legend_text_face = "plain",
  legend_position = "right",
  legend_title = "auto",
  legend_title_size = 12,
  add_vertical_divider = FALSE,
  vertical_divider_after = NULL,
  vertical_divider_linetype = "dashed",
  vertical_divider_color = "grey40",
  vertical_divider_linewidth = 0.5,
  draw_jitterplot = TRUE,
  dot_size = 1,
  jitter_width = 0.10,
  jitter_height = 0.1,
  dodge_width = 0.75,
  beeswarm_spread = 3,
  beeswarm_method = "density",
  add_annotations = TRUE,
  annotation_line_width = 1.5,
  annotation_text_size = 5,
  use_significance_letters = TRUE,
  maximum_pairwise_annotations = 3,
  p_adjust_method = c(
    "BH",
    "none",
    "bonferroni",
    "holm",
    "fdr",
    "hochberg",
    "hommel",
    "BY"
  ),
  ylim_cap = NULL,
  return_full = FALSE,
  font_scaling = c("none", "match_anova"),
  panel_width_inches = 4.5,
  export_plot_dir = NULL,
  export_plot_prefix = "",
  export_plot_width = 5,
  export_plot_height = 5.5,
  export_plot_dpi = 300,
  export_stats_file = NULL
) {
  font_scaling <- match.arg(font_scaling)
  p_adjust_method <- match.arg(p_adjust_method)
  suppressPackageStartupMessages({
    library(ggplot2)
    library(tidyr)
    library(dplyr)
    library(tibble)
    library(ggbeeswarm)
    library(RColorBrewer)
    library(stringr)
    library(broom)
    library(multcomp)
    library(multcompView)
  })

  statistical_method <- match.arg(statistical_method)
  metadata_filter_operator <- match.arg(metadata_filter_operator)
  plot_type <- match.arg(plot_type)

  if (!is.null(categories)) {
    if (
      length(colors_to_use) != 1 && length(categories) > length(colors_to_use)
    ) {
      stop("Need more colors to accommodate more categories.")
    }
    if (
      length(shapes_to_use) != 1 && length(categories) > length(shapes_to_use)
    ) {
      stop("Need more shapes to accommodate more categories.")
    }
  }

  prep <- boxplot_prepare_long(
    normalized_counts = normalized_counts,
    sample_metadata = sample_metadata,
    gene_column = gene_column,
    sample_column = sample_column,
    category_column = category_column,
    genes = genes,
    sum_duplicates = sum_duplicates,
    categories = categories,
    samples_to_include = samples_to_include,
    samples_to_exclude = samples_to_exclude,
    filter_by_metadata = filter_by_metadata,
    metadata_filter_column = metadata_filter_column,
    metadata_filter_values = metadata_filter_values,
    metadata_filter_operator = metadata_filter_operator,
    extra_metadata_columns = covariate_columns,
    minimum_samples_per_category = minimum_samples_per_category
  )

  df_long <- prep$df_long
  valid_categories <- prep$valid_categories
  genes_updated <- prep$genes_requested
  missing_covariates <- setdiff(covariate_columns, names(df_long))
  if (length(missing_covariates)) {
    warning(
      "Covariate column(s) not found in sample metadata and will be ignored: ",
      paste(missing_covariates, collapse = ", ")
    )
  }
  covariate_columns <- intersect(covariate_columns, names(df_long))

  compute_stats <- function(
    df_long,
    method = c("anova", "ttest", "kruskal"),
    padj = "BH",
    covariate_columns = NULL
  ) {
    method <- match.arg(method, c("anova", "ttest", "kruskal"))
    stats_list <- list()
    letters_list <- list()
    covariate_columns <- unique(stats::na.omit(covariate_columns))

    for (g in unique(df_long$gene)) {
      sub <- df_long %>% dplyr::filter(.data$gene == g)
      if (dplyr::n_distinct(sub$category) < 2) {
        next
      }
      category_levels <- levels(sub$category)
      if (is.null(category_levels)) {
        category_levels <- unique(as.character(sub$category))
      }

      if (length(covariate_columns)) {
        st <- boxplot_covariate_pairwise_stats(
          sub = sub,
          gene_name = g,
          covariate_columns = covariate_columns,
          padj = padj
        )
        stats_list[[g]] <- st
        letters_list[[g]] <- boxplot_pairwise_letters(
          pairwise_stats = st,
          category_levels = category_levels,
          gene_name = g
        )
      } else if (method == "anova") {
        if (padj == "BH" || padj == "fdr") {
          # Use TukeyHSD for default adjusted comparisons
          fit <- stats::aov(value ~ category, data = sub)
          tk <- stats::TukeyHSD(fit)$category
          st <- as.data.frame(tk) %>%
            tibble::rownames_to_column("comparison") %>%
            tidyr::separate(
              .data$comparison,
              into = c("group1", "group2"),
              sep = "-"
            ) %>%
            dplyr::rename(
              diff = .data$diff,
              lwr = .data$lwr,
              upr = .data$upr,
              p_adj = .data[["p adj"]]
            ) %>%
            dplyr::mutate(gene = g)
          stats_list[[g]] <- st
          pvals <- tk[, "p adj"]
          names(pvals) <- rownames(tk)
        } else {
          # Use pairwise.t.test with the requested adjustment for CLD
          pw <- stats::pairwise.t.test(
            sub$value,
            sub$category,
            p.adjust.method = padj
          )
          st <- broom::tidy(pw) %>%
            dplyr::rename(p_adj = .data$p.value) %>%
            dplyr::mutate(gene = g)
          stats_list[[g]] <- st
          pmat <- pw$p.value
          pvals <- c()
          for (i in rownames(pmat)) {
            for (j in colnames(pmat)) {
              if (!is.na(pmat[i, j])) {
                pvals[paste(i, j, sep = "-")] <- pmat[i, j]
              }
            }
          }
        }
        out <- try(
          multcompView::multcompLetters(pvals, threshold = 0.05),
          silent = TRUE
        )
        if (!inherits(out, "try-error")) {
          letters_list[[g]] <- tibble::tibble(
            category = names(out$Letters),
            letters = unname(out$Letters),
            gene = g
          )
        }
      } else if (method == "ttest") {
        pw <- stats::pairwise.t.test(
          sub$value,
          sub$category,
          p.adjust.method = padj
        )
        st <- broom::tidy(pw) %>%
          dplyr::rename(p_adj = .data$p.value) %>%
          dplyr::mutate(gene = g)
        stats_list[[g]] <- st
        letters_list[[g]] <- boxplot_pairwise_letters(
          pairwise_stats = st,
          category_levels = category_levels,
          gene_name = g
        )
      } else {
        pw <- stats::pairwise.wilcox.test(
          sub$value,
          sub$category,
          p.adjust.method = padj
        )
        st <- broom::tidy(pw) %>%
          dplyr::rename(p_adj = .data$p.value) %>%
          dplyr::mutate(gene = g)
        stats_list[[g]] <- st
        letters_list[[g]] <- boxplot_pairwise_letters(
          pairwise_stats = st,
          category_levels = category_levels,
          gene_name = g
        )
      }
    }
    list(
      stats = dplyr::bind_rows(stats_list),
      letters = if (length(letters_list)) {
        dplyr::bind_rows(letters_list)
      } else {
        NULL
      }
    )
  }

  stats_result <- compute_stats(
    df_long,
    method = switch(
      statistical_method,
      "t-test" = "ttest",
      "kruskal" = "kruskal",
      "anova"
    ),
    padj = p_adjust_method,
    covariate_columns = covariate_columns
  )
  stats_all <- stats_result$stats
  letters_all <- stats_result$letters
  genes_param <- if (is.null(genes_updated)) genes else genes_updated

  if (identical(font_scaling, "match_anova")) {
    n_categories <- length(unique(stats::na.omit(df_long$category)))
    size_map <- boxplot_compute_font_sizes(
      n_categories,
      panel_width_inches = panel_width_inches
    )
    x_axis_text_size <- size_map$x_axis_text_size
    y_axis_text_size <- size_map$y_axis_text_size
    x_axis_title_size <- size_map$x_axis_title_size
    y_axis_title_size <- size_map$y_axis_title_size
    title_size <- size_map$title_size
    legend_text_size <- size_map$legend_text_size
    annotation_text_size <- size_map$annotation_text_size
    annotation_line_width <- size_map$annotation_line_width
  }

  out <- gene_boxplot_core(
    df_long = df_long,
    stats_all = stats_all,
    letters_all = letters_all,
    valid_categories = valid_categories,
    categories = categories,
    category_labels = category_labels,
    palette = palette,
    use_custom_colors = use_custom_colors,
    colors_to_use = colors_to_use,
    shapes_to_use = shapes_to_use,
    significance_colors_to_use = significance_colors_to_use,
    plot_type = plot_type,
    plot_width = plot_width,
    draw_jitterplot = draw_jitterplot,
    dot_size = dot_size,
    jitter_width = jitter_width,
    jitter_height = jitter_height,
    dodge_width = dodge_width,
    beeswarm_spread = beeswarm_spread,
    beeswarm_method = beeswarm_method,
    add_annotations = add_annotations,
    annotation_line_width = annotation_line_width,
    annotation_text_size = annotation_text_size,
    use_significance_letters = use_significance_letters,
    maximum_pairwise_annotations = maximum_pairwise_annotations,
    ylim_cap = ylim_cap,
    x_axis_title = x_axis_title,
    x_axis_title_size = x_axis_title_size,
    show_x_axis_text = show_x_axis_text,
    x_axis_text_size = x_axis_text_size,
    y_axis_title = y_axis_title,
    y_axis_title_size = y_axis_title_size,
    show_y_axis_text = show_y_axis_text,
    y_axis_text_size = y_axis_text_size,
    title = title,
    title_position = title_position,
    title_size = title_size,
    title_face = title_face,
    legend_text_size = legend_text_size,
    legend_text_face = legend_text_face,
    legend_position = legend_position,
    legend_title = legend_title,
    legend_title_size = legend_title_size,
    add_vertical_divider = add_vertical_divider,
    vertical_divider_after = vertical_divider_after,
    vertical_divider_linetype = vertical_divider_linetype,
    vertical_divider_color = vertical_divider_color,
    vertical_divider_linewidth = vertical_divider_linewidth,
    left_margin = left_margin,
    right_margin = right_margin,
    top_margin = top_margin,
    bottom_margin = bottom_margin,
    statistical_method_label = if (length(covariate_columns)) {
      paste0(
        statistical_method,
        " adjusted for ",
        paste(covariate_columns, collapse = ", ")
      )
    } else {
      statistical_method
    },
    significance_threshold = 0.10,
    return_full = TRUE,
    genes_requested = genes_param
  )

  if (!is.null(export_plot_dir)) {
    if (!dir.exists(export_plot_dir)) {
      dir.create(export_plot_dir, recursive = TRUE, showWarnings = FALSE)
    }
    safe_name <- function(x) {
      gsub("[^A-Za-z0-9._-]+", "_", as.character(x))
    }
    for (nm in names(out$plots)) {
      plot_file <- file.path(
        export_plot_dir,
        paste0(export_plot_prefix, safe_name(nm), ".png")
      )
      ggplot2::ggsave(
        filename = plot_file,
        plot = out$plots[[nm]],
        width = export_plot_width,
        height = export_plot_height,
        units = "in",
        dpi = export_plot_dpi
      )
    }
  }

  if (!is.null(export_stats_file)) {
    out_dir <- dirname(export_stats_file)
    if (!dir.exists(out_dir)) {
      dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
    }
    utils::write.csv(out$stats, export_stats_file, row.names = FALSE)
  }

  if (isTRUE(return_full)) {
    out
  } else {
    out$stats
  }
}

#' Gene Boxplot with Precomputed DEG Statistics [CCBR] [Beta]
#'
#' Mirror `gene_boxplot_with_stats()` aesthetics but apply precomputed differential
#' expression results (e.g., limma contrasts) instead of running new hypothesis tests.
#'
#' @inheritParams gene_boxplot_with_stats
#' @param deg_results Data frame containing precomputed statistics with columns for
#'   adjusted/raw p-values whose names end in `_adjpval`/`_pval` (configurable).
#' @param deg_gene_column Column name in `deg_results` containing gene identifiers.
#' @param padj_suffix Suffix pattern identifying adjusted p-value columns within
#'   `deg_results` (default `_adjpval`).
#' @param pval_suffix Suffix pattern identifying raw p-value columns within
#'   `deg_results` (default `_pval`).
#' @param pvalue_to_plot Which p-value source to display on plot annotations and
#'   use for significance filtering: `"adjusted"` (default) or `"raw"`.
#' @param significance_threshold P-value threshold used for determining which
#'   comparisons are annotated on the plot (default 0.10).
#' @param font_scaling Control automatic font scaling. Use "match_anova" (default)
#'   to mirror legacy ANOVA sizing or "none" to keep explicit font values.
#' @param panel_width_inches Reference panel width (inches) used when
#'   `font_scaling = "match_anova"`.
#' @param export_plot_dir Optional output directory to save one PNG per gene plot.
#'   If NULL (default), plots are not saved.
#' @param export_plot_prefix Optional prefix added to each exported plot filename.
#' @param export_plot_width Plot width for exported PNG files.
#' @param export_plot_height Plot height for exported PNG files.
#' @param export_plot_dpi Resolution (DPI) for exported PNG files.
#' @param export_stats_file Optional path to export DEG-based statistics as CSV.
#'   If NULL (default), stats are not saved.
#'
#' @examples
#' # deg_res <- gene_boxplot_with_deg_results(
#' #   normalized_counts = norm_counts,
#' #   sample_metadata = meta,
#' #   deg_results = deg_tbl,
#' #   gene_column = "Gene",
#' #   sample_column = "SampleID",
#' #   category_column = "Group",
#' #   genes = c("CD3D", "MS4A1"),
#' #   export_plot_dir = "boxplots_deg",
#' #   export_stats_file = "boxplots_deg/deg_stats.csv",
#' #   return_full = TRUE
#' # )
gene_boxplot_with_deg_results <- function(
  normalized_counts,
  sample_metadata,
  deg_results,
  gene_column,
  sample_column,
  deg_gene_column = gene_column,
  genes = NULL,
  sum_duplicates = TRUE,
  category_column,
  categories = NULL,
  category_labels = NULL,
  samples_to_include = NULL,
  samples_to_exclude = NULL,
  filter_by_metadata = FALSE,
  metadata_filter_column = NULL,
  metadata_filter_values = NULL,
  metadata_filter_operator = c("include", "exclude"),
  minimum_samples_per_category = 3,
  plot_type = c("Box plot", "Violin Plot"),
  plot_width = 0.3,
  left_margin = 0.5,
  right_margin = 0.5,
  top_margin = 0.5,
  bottom_margin = 0.5,
  use_custom_colors = TRUE,
  palette = "Dark2",
  colors_to_use = c(
    "Deep Red",
    "Vivid Blue",
    "Green",
    "Purple",
    "Bright Orange",
    "Yellow",
    "Brown",
    "Pink",
    "Grey",
    "Burnt Orange",
    "Teal Green",
    "Soft Purple",
    "Hot Pink",
    "Leaf Green",
    "Mustard Yellow"
  ),
  shapes_to_use = c("filled circle"),
  significance_colors_to_use = "black",
  x_axis_title = "auto",
  x_axis_title_size = 13,
  show_x_axis_text = TRUE,
  x_axis_text_size = 11,
  y_axis_title = "auto",
  y_axis_title_size = 13,
  show_y_axis_text = TRUE,
  y_axis_text_size = 11,
  title = "auto",
  title_position = 0.5,
  title_size = 13,
  title_face = "italic",
  legend_text_size = 11,
  legend_text_face = "plain",
  legend_position = "right",
  legend_title = "auto",
  legend_title_size = 12,
  add_vertical_divider = FALSE,
  vertical_divider_after = NULL,
  vertical_divider_linetype = "dashed",
  vertical_divider_color = "grey40",
  vertical_divider_linewidth = 0.5,
  draw_jitterplot = TRUE,
  dot_size = 1,
  jitter_width = 0.10,
  jitter_height = 0.1,
  dodge_width = 0.75,
  beeswarm_spread = 3,
  beeswarm_method = "density",
  add_annotations = TRUE,
  annotation_line_width = 1.5,
  annotation_text_size = 5,
  use_significance_letters = TRUE,
  maximum_pairwise_annotations = 3,
  ylim_cap = NULL,
  padj_suffix = "_adjpval",
  pval_suffix = "_pval",
  pvalue_to_plot = c("adjusted", "raw"),
  significance_threshold = 0.10,
  return_full = FALSE,
  font_scaling = c("match_anova", "none"),
  panel_width_inches = 4.5,
  export_plot_dir = NULL,
  export_plot_prefix = "",
  export_plot_width = 5,
  export_plot_height = 5.5,
  export_plot_dpi = 300,
  export_stats_file = NULL
) {
  if (missing(deg_results)) {
    stop(
      "Argument 'deg_results' must be supplied when using precomputed statistics."
    )
  }

  boxplot_load_packages()

  metadata_filter_operator <- match.arg(metadata_filter_operator)
  plot_type <- match.arg(plot_type)
  font_scaling <- match.arg(font_scaling)
  pvalue_to_plot <- match.arg(pvalue_to_plot)

  if (!is.data.frame(deg_results)) {
    stop(
      "'deg_results' must be a data frame containing precomputed statistics."
    )
  }

  prep <- boxplot_prepare_long(
    normalized_counts = normalized_counts,
    sample_metadata = sample_metadata,
    gene_column = gene_column,
    sample_column = sample_column,
    category_column = category_column,
    genes = genes,
    sum_duplicates = sum_duplicates,
    categories = categories,
    samples_to_include = samples_to_include,
    samples_to_exclude = samples_to_exclude,
    filter_by_metadata = filter_by_metadata,
    metadata_filter_column = metadata_filter_column,
    metadata_filter_values = metadata_filter_values,
    metadata_filter_operator = metadata_filter_operator,
    minimum_samples_per_category = minimum_samples_per_category
  )

  df_long <- prep$df_long
  valid_categories <- prep$valid_categories
  genes_updated <- prep$genes_requested
  category_levels <- levels(df_long$category)
  if (is.null(category_levels)) {
    category_levels <- unique(df_long$category)
  }
  category_levels <- as.character(category_levels)
  genes_in_plot <- unique(as.character(df_long$gene))

  stats_all <- boxplot_extract_deg_stats(
    deg_results = deg_results,
    gene_column = deg_gene_column,
    genes = genes_in_plot,
    categories = category_levels,
    padj_suffix = padj_suffix,
    pval_suffix = pval_suffix
  )

  if (!nrow(stats_all)) {
    warning(
      "No DEG-based statistics matched the selected genes/categories; returning plots without annotations."
    )
  }

  stats_for_plot <- stats_all
  if (identical(pvalue_to_plot, "raw") && nrow(stats_for_plot)) {
    if (!"p_value" %in% names(stats_for_plot)) {
      warning(
        "Raw p-values are unavailable in 'deg_results'; falling back to adjusted p-values for plot annotations."
      )
    } else {
      stats_for_plot <- stats_for_plot %>%
        dplyr::mutate(p_adj = .data$p_value)
    }
  }

  genes_param <- if (is.null(genes_updated)) genes else genes_updated

  if (identical(font_scaling, "match_anova")) {
    n_categories <- length(unique(stats::na.omit(df_long$category)))
    size_map <- boxplot_compute_font_sizes(
      n_categories,
      panel_width_inches = panel_width_inches
    )
    x_axis_text_size <- size_map$x_axis_text_size
    y_axis_text_size <- size_map$y_axis_text_size
    x_axis_title_size <- size_map$x_axis_title_size
    y_axis_title_size <- size_map$y_axis_title_size
    title_size <- size_map$title_size
    legend_text_size <- size_map$legend_text_size
    annotation_text_size <- size_map$annotation_text_size
    annotation_line_width <- size_map$annotation_line_width
  }

  out <- gene_boxplot_core(
    df_long = df_long,
    stats_all = stats_for_plot,
    letters_all = NULL,
    valid_categories = valid_categories,
    categories = categories,
    category_labels = category_labels,
    palette = palette,
    use_custom_colors = use_custom_colors,
    colors_to_use = colors_to_use,
    shapes_to_use = shapes_to_use,
    significance_colors_to_use = significance_colors_to_use,
    plot_type = plot_type,
    plot_width = plot_width,
    draw_jitterplot = draw_jitterplot,
    dot_size = dot_size,
    jitter_width = jitter_width,
    jitter_height = jitter_height,
    dodge_width = dodge_width,
    beeswarm_spread = beeswarm_spread,
    beeswarm_method = beeswarm_method,
    add_annotations = add_annotations,
    annotation_line_width = annotation_line_width,
    annotation_text_size = annotation_text_size,
    use_significance_letters = use_significance_letters,
    maximum_pairwise_annotations = maximum_pairwise_annotations,
    ylim_cap = ylim_cap,
    x_axis_title = x_axis_title,
    x_axis_title_size = x_axis_title_size,
    show_x_axis_text = show_x_axis_text,
    x_axis_text_size = x_axis_text_size,
    y_axis_title = y_axis_title,
    y_axis_title_size = y_axis_title_size,
    show_y_axis_text = show_y_axis_text,
    y_axis_text_size = y_axis_text_size,
    title = title,
    title_position = title_position,
    title_size = title_size,
    title_face = title_face,
    legend_text_size = legend_text_size,
    legend_text_face = legend_text_face,
    legend_position = legend_position,
    legend_title = legend_title,
    legend_title_size = legend_title_size,
    add_vertical_divider = add_vertical_divider,
    vertical_divider_after = vertical_divider_after,
    vertical_divider_linetype = vertical_divider_linetype,
    vertical_divider_color = vertical_divider_color,
    vertical_divider_linewidth = vertical_divider_linewidth,
    left_margin = left_margin,
    right_margin = right_margin,
    top_margin = top_margin,
    bottom_margin = bottom_margin,
    statistical_method_label = "precomputed",
    significance_threshold = significance_threshold,
    return_full = TRUE,
    genes_requested = genes_param
  )

  if (!is.null(export_plot_dir)) {
    if (!dir.exists(export_plot_dir)) {
      dir.create(export_plot_dir, recursive = TRUE, showWarnings = FALSE)
    }
    safe_name <- function(x) {
      gsub("[^A-Za-z0-9._-]+", "_", as.character(x))
    }
    for (nm in names(out$plots)) {
      plot_file <- file.path(
        export_plot_dir,
        paste0(export_plot_prefix, safe_name(nm), ".png")
      )
      ggplot2::ggsave(
        filename = plot_file,
        plot = out$plots[[nm]],
        width = export_plot_width,
        height = export_plot_height,
        units = "in",
        dpi = export_plot_dpi
      )
    }
  }

  if (!is.null(export_stats_file)) {
    out_dir <- dirname(export_stats_file)
    if (!dir.exists(out_dir)) {
      dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
    }
    utils::write.csv(out$stats, export_stats_file, row.names = FALSE)
  }

  if (isTRUE(return_full)) {
    out
  } else {
    out$stats
  }
}
