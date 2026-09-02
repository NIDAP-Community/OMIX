# OMIX Gene Boxplots
#
# Platform-neutral gene-expression boxplots. The implementation deliberately
# separates visualization data from statistical evidence: a plot can either
# annotate statistics calculated from the plotted data or, preferably for DEG
# results, use statistics already produced by the differential-expression model.

omix_parse_csv_values <- function(value) {
  if (is.null(value) || length(value) == 0L || !nzchar(trimws(value[[1L]]))) {
    return(NULL)
  }
  values <- trimws(strsplit(value[[1L]], ",", fixed = TRUE)[[1L]])
  values[nzchar(values)]
}

omix_safe_filename <- function(value) {
  gsub("[^A-Za-z0-9._-]+", "_", as.character(value))
}

omix_validate_table <- function(table, label) {
  if (!is.data.frame(table)) {
    stop("ERROR: `", label, "` must be a data frame")
  }
  if (nrow(table) == 0L || ncol(table) == 0L) {
    stop("ERROR: `", label, "` cannot be empty")
  }
  invisible(table)
}

omix_prepare_boxplot_data <- function(
    expression_table,
    sample_metadata,
    genes,
    gene_column,
    sample_column,
    category_column,
    categories = NULL,
    minimum_samples_per_category = 2L) {
  omix_validate_table(expression_table, "expression_table")
  omix_validate_table(sample_metadata, "sample_metadata")

  required_metadata <- c(sample_column, category_column)
  missing_metadata <- setdiff(required_metadata, names(sample_metadata))
  if (length(missing_metadata)) {
    stop(
      "ERROR: `sample_metadata` is missing required column(s): ",
      paste(missing_metadata, collapse = ", ")
    )
  }
  if (!gene_column %in% names(expression_table)) {
    stop("ERROR: `expression_table` is missing the gene identifier column: ", gene_column)
  }

  genes <- unique(as.character(genes))
  genes <- genes[nzchar(genes)]
  if (!length(genes)) {
    stop("ERROR: Supply at least one gene to plot")
  }
  expression_table[[gene_column]] <- as.character(expression_table[[gene_column]])
  missing_genes <- setdiff(genes, expression_table[[gene_column]])
  if (length(missing_genes)) {
    warning("Requested gene(s) not found and skipped: ", paste(missing_genes, collapse = ", "))
  }
  expression_table <- expression_table[expression_table[[gene_column]] %in% genes, , drop = FALSE]
  if (!nrow(expression_table)) {
    stop("ERROR: None of the requested genes were present in `expression_table`")
  }

  # Aggregate duplicate identifiers by mean. For a displayed expression scale
  # this is clearer than silently selecting an arbitrary duplicate row.
  sample_columns <- setdiff(names(expression_table), gene_column)
  metadata <- sample_metadata[, required_metadata, drop = FALSE]
  metadata[[sample_column]] <- as.character(metadata[[sample_column]])
  metadata[[category_column]] <- as.character(metadata[[category_column]])
  metadata <- metadata[
    !is.na(metadata[[sample_column]]) & nzchar(metadata[[sample_column]]) &
      !is.na(metadata[[category_column]]) & nzchar(metadata[[category_column]]),
    ,
    drop = FALSE
  ]
  metadata <- metadata[!duplicated(metadata[[sample_column]]), , drop = FALSE]

  shared_samples <- intersect(sample_columns, metadata[[sample_column]])
  if (!length(shared_samples)) {
    stop(
      "ERROR: No sample IDs overlap between expression columns and `sample_metadata$",
      sample_column, "`"
    )
  }
  metadata <- metadata[match(shared_samples, metadata[[sample_column]]), , drop = FALSE]
  if (!is.null(categories)) {
    categories <- unique(as.character(categories))
    metadata <- metadata[metadata[[category_column]] %in% categories, , drop = FALSE]
    shared_samples <- metadata[[sample_column]]
  }
  if (!length(shared_samples)) {
    stop("ERROR: No samples remain after applying the category filter")
  }

  group_sizes <- table(metadata[[category_column]])
  valid_categories <- names(group_sizes)[group_sizes >= minimum_samples_per_category]
  if (length(valid_categories) < 2L) {
    stop(
      "ERROR: At least two categories with ", minimum_samples_per_category,
      " sample(s) each are required for a boxplot comparison"
    )
  }
  metadata <- metadata[metadata[[category_column]] %in% valid_categories, , drop = FALSE]
  shared_samples <- metadata[[sample_column]]

  expression_values <- expression_table[, shared_samples, drop = FALSE]
  for (column in names(expression_values)) {
    expression_values[[column]] <- suppressWarnings(as.numeric(expression_values[[column]]))
  }
  if (all(vapply(expression_values, function(x) all(is.na(x)), logical(1)))) {
    stop("ERROR: No numeric expression columns were found for the selected samples")
  }

  long_rows <- lapply(seq_len(nrow(expression_table)), function(index) {
    data.frame(
      gene = expression_table[[gene_column]][[index]],
      sample = shared_samples,
      category = metadata[[category_column]],
      value = unlist(expression_values[index, shared_samples, drop = FALSE], use.names = FALSE),
      stringsAsFactors = FALSE,
      check.names = FALSE
    )
  })
  data_long <- do.call(rbind, long_rows)
  data_long <- data_long[is.finite(data_long$value), , drop = FALSE]
  if (!nrow(data_long)) {
    stop("ERROR: All selected expression values are missing or non-numeric")
  }
  data_long$category <- factor(data_long$category, levels = valid_categories)
  rownames(data_long) <- NULL

  list(
    data = data_long,
    genes_found = unique(data_long$gene),
    categories = valid_categories,
    sample_count = length(unique(data_long$sample))
  )
}

omix_pairwise_table <- function(values, groups, method, p_adjust_method) {
  groups <- droplevels(as.factor(groups))
  group_levels <- levels(groups)
  if (length(group_levels) < 2L) {
    return(data.frame())
  }
  pairs <- utils::combn(group_levels, 2L, simplify = FALSE)
  results <- lapply(pairs, function(pair) {
    one <- values[groups == pair[[1L]]]
    two <- values[groups == pair[[2L]]]
    if (length(one) < 2L || length(two) < 2L) {
      return(NULL)
    }
    p_value <- switch(
      method,
      "t-test" = stats::t.test(one, two)$p.value,
      "kruskal" = stats::wilcox.test(one, two, exact = FALSE)$p.value,
      stats::t.test(one, two)$p.value
    )
    data.frame(
      group1 = pair[[1L]],
      group2 = pair[[2L]],
      p_value = as.numeric(p_value),
      stringsAsFactors = FALSE
    )
  })
  results <- Filter(Negate(is.null), results)
  if (!length(results)) {
    return(data.frame())
  }
  results <- do.call(rbind, results)
  results$p_adjusted <- stats::p.adjust(results$p_value, method = p_adjust_method)
  results
}

omix_calculate_within_plot_stats <- function(data_long, method, p_adjust_method) {
  pieces <- lapply(unique(data_long$gene), function(gene) {
    one_gene <- data_long[data_long$gene == gene, , drop = FALSE]
    stats <- omix_pairwise_table(
      values = one_gene$value,
      groups = one_gene$category,
      method = method,
      p_adjust_method = p_adjust_method
    )
    if (!nrow(stats)) {
      return(NULL)
    }
    stats$gene <- gene
    stats$source <- paste0("within_plot_", method)
    stats
  })
  pieces <- Filter(Negate(is.null), pieces)
  if (!length(pieces)) {
    return(data.frame())
  }
  out <- do.call(rbind, pieces)
  out[, c("gene", "group1", "group2", "p_value", "p_adjusted", "source"), drop = FALSE]
}

omix_extract_precomputed_deg_stats <- function(
    deg_results,
    genes,
    categories,
    deg_gene_column,
    pvalue_type) {
  omix_validate_table(deg_results, "deg_results")
  if (!deg_gene_column %in% names(deg_results)) {
    stop("ERROR: `deg_results` is missing the gene identifier column: ", deg_gene_column)
  }

  suffix <- if (identical(pvalue_type, "adjusted")) "_adjpval" else "_pval"
  statistic_columns <- grep(paste0(suffix, "$"), names(deg_results), value = TRUE)
  if (!length(statistic_columns)) {
    stop(
      "ERROR: `deg_results` has no columns ending in `", suffix,
      "`. Use pvalue_type = 'nominal' for *_pval columns or provide a compatible DEG table."
    )
  }

  deg_results[[deg_gene_column]] <- as.character(deg_results[[deg_gene_column]])
  deg_results <- deg_results[deg_results[[deg_gene_column]] %in% genes, , drop = FALSE]
  out <- list()
  index <- 1L
  for (column in statistic_columns) {
    comparison <- sub(paste0(suffix, "$"), "", column)
    pair <- strsplit(comparison, "-", fixed = TRUE)[[1L]]
    if (length(pair) != 2L || !all(pair %in% categories)) {
      next
    }
    raw_column <- paste0(comparison, "_pval")
    adjusted_column <- paste0(comparison, "_adjpval")
    for (row in seq_len(nrow(deg_results))) {
      p_selected <- suppressWarnings(as.numeric(deg_results[[column]][[row]]))
      if (!is.finite(p_selected)) {
        next
      }
      raw_p <- if (raw_column %in% names(deg_results)) {
        suppressWarnings(as.numeric(deg_results[[raw_column]][[row]]))
      } else {
        NA_real_
      }
      adjusted_p <- if (adjusted_column %in% names(deg_results)) {
        suppressWarnings(as.numeric(deg_results[[adjusted_column]][[row]]))
      } else {
        NA_real_
      }
      if (identical(pvalue_type, "nominal")) {
        raw_p <- p_selected
      } else {
        adjusted_p <- p_selected
      }
      out[[index]] <- data.frame(
        gene = deg_results[[deg_gene_column]][[row]],
        group1 = pair[[1L]],
        group2 = pair[[2L]],
        p_value = raw_p,
        p_adjusted = adjusted_p,
        source = "precomputed_deg",
        stringsAsFactors = FALSE
      )
      index <- index + 1L
    }
  }
  if (!length(out)) {
    return(data.frame())
  }
  do.call(rbind, out)
}

omix_format_pvalue <- function(value, label) {
  if (!is.finite(value)) {
    return(NA_character_)
  }
  paste0(label, "=", format.pval(value, digits = 2L, eps = 1e-3))
}

omix_make_gene_boxplot <- function(
    data_long,
    gene,
    statistics,
    pvalue_type,
    plot_type,
    plot_title_prefix,
    y_axis_label,
    colors) {
  one_gene <- data_long[data_long$gene == gene, , drop = FALSE]
  one_gene$category <- droplevels(one_gene$category)
  levels_present <- levels(one_gene$category)
  group_colors <- grDevices::hcl.colors(length(levels_present), palette = "Dark 3")
  names(group_colors) <- levels_present
  if (!is.null(colors) && length(colors)) {
    group_colors <- rep(colors, length.out = length(levels_present))
    names(group_colors) <- levels_present
  }

  geometry <- if (identical(plot_type, "violin")) {
    ggplot2::geom_violin(alpha = 0.65, trim = FALSE, color = "grey25")
  } else {
    ggplot2::geom_boxplot(alpha = 0.65, outlier.shape = NA, width = 0.62, color = "grey25")
  }
  plot <- ggplot2::ggplot(one_gene, ggplot2::aes(x = category, y = value, fill = category)) +
    geometry +
    ggplot2::geom_jitter(
      ggplot2::aes(color = category),
      width = 0.10,
      height = 0,
      size = 2.1,
      alpha = 0.85,
      show.legend = FALSE
    ) +
    ggplot2::scale_fill_manual(values = group_colors) +
    ggplot2::scale_color_manual(values = group_colors) +
    ggplot2::labs(
      title = paste0(plot_title_prefix, gene),
      x = NULL,
      y = y_axis_label
    ) +
    ggplot2::theme_classic(base_size = 12) +
    ggplot2::theme(
      legend.position = "none",
      plot.title = ggplot2::element_text(face = "italic", hjust = 0.5),
      plot.margin = grid::unit(c(6, 6, 18, 6), "pt")
    )

  one_gene_stats <- statistics[statistics$gene == gene, , drop = FALSE]
  value_column <- if (identical(pvalue_type, "adjusted")) "p_adjusted" else "p_value"
  if (nrow(one_gene_stats) && value_column %in% names(one_gene_stats)) {
    one_gene_stats$selected_p <- one_gene_stats[[value_column]]
    one_gene_stats <- one_gene_stats[is.finite(one_gene_stats$selected_p), , drop = FALSE]
    if (nrow(one_gene_stats)) {
      one_gene_stats$x1 <- match(one_gene_stats$group1, levels_present)
      one_gene_stats$x2 <- match(one_gene_stats$group2, levels_present)
      one_gene_stats <- one_gene_stats[
        is.finite(one_gene_stats$x1) & is.finite(one_gene_stats$x2),
        ,
        drop = FALSE
      ]
      one_gene_stats <- one_gene_stats[
        order(abs(one_gene_stats$x2 - one_gene_stats$x1), one_gene_stats$x1, one_gene_stats$x2),
        ,
        drop = FALSE
      ]
    }
    if (nrow(one_gene_stats)) {
      y_range <- range(one_gene$value, na.rm = TRUE)
      value_span <- diff(y_range)
      if (!is.finite(value_span) || value_span == 0) {
        value_span <- max(abs(y_range), 1)
      }
      whisker_tops <- vapply(levels_present, function(category) {
        values <- one_gene$value[one_gene$category == category]
        q3 <- stats::quantile(values, 0.75, na.rm = TRUE)
        iqr <- stats::IQR(values, na.rm = TRUE)
        min(q3 + 1.5 * iqr, max(values, na.rm = TRUE))
      }, numeric(1))
      base_y <- max(whisker_tops, na.rm = TRUE) + value_span * 0.10
      line_spacing <- value_span * 0.12
      label_gap <- value_span * 0.035
      p_label <- if (identical(pvalue_type, "adjusted")) "adj. p" else "p"
      for (index in seq_len(nrow(one_gene_stats))) {
        comparison <- one_gene_stats[index, , drop = FALSE]
        line_y <- base_y + (index - 1L) * line_spacing
        plot <- plot +
          ggplot2::annotate(
            "segment",
            x = comparison$x1,
            xend = comparison$x2,
            y = line_y,
            yend = line_y,
            linewidth = 0.65,
            color = "grey20"
          ) +
          ggplot2::annotate(
            "text",
            x = mean(c(comparison$x1, comparison$x2)),
            y = line_y + label_gap,
            label = omix_format_pvalue(comparison$selected_p, label = p_label),
            size = 3.2,
            vjust = 0,
            color = "grey20"
          )
      }
      plot <- plot +
        ggplot2::coord_cartesian(clip = "off") +
        ggplot2::theme(plot.margin = grid::unit(c(18, 6, 6, 6), "pt"))
    }
  }
  plot
}

#' Create gene-expression boxplots with model-consistent or within-plot statistics.
#'
#' @param expression_table A data frame with a gene identifier column and one
#'   numeric expression column per sample. It can contain normalized CPM,
#'   voom-scale expression, or batch-corrected expression values.
#' @param sample_metadata A data frame with sample IDs and a grouping column.
#' @param genes Character vector of gene identifiers to plot.
#' @param statistics_mode `"precomputed_deg"` uses supplied DEG statistics,
#'   `"within_plot"` computes pairwise tests from the plotted values, and
#'   `"none"` omits statistical annotations.
#' @param deg_results Optional DEG table. It may be the same object as
#'   `expression_table` when it contains both expression and `*_pval` /
#'   `*_adjpval` columns.
#' @return An invisible list containing `data`, `statistics`, `plots`, and
#'   output file paths. PNGs and CSVs are written when `output_dir` is supplied.
omix_gene_boxplots <- function(
    expression_table,
    sample_metadata,
    genes,
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
    minimum_samples_per_category = 2L,
    plot_type = c("box", "violin"),
    plot_title_prefix = "Expression: ",
    y_axis_label = "Expression",
    colors = NULL,
    output_dir = NULL,
    image_width = 6,
    image_height = 5,
    image_dpi = 300) {
  if (!requireNamespace("ggplot2", quietly = TRUE)) {
    stop("ERROR: Package `ggplot2` is required")
  }
  statistics_mode <- match.arg(statistics_mode)
  pvalue_type <- match.arg(pvalue_type)
  statistical_method <- match.arg(statistical_method)
  plot_type <- match.arg(plot_type)
  categories <- omix_parse_csv_values(categories)
  prepared <- omix_prepare_boxplot_data(
    expression_table = expression_table,
    sample_metadata = sample_metadata,
    genes = genes,
    gene_column = gene_column,
    sample_column = sample_column,
    category_column = category_column,
    categories = categories,
    minimum_samples_per_category = as.integer(minimum_samples_per_category)
  )

  statistics <- switch(
    statistics_mode,
    "precomputed_deg" = {
      if (is.null(deg_results)) {
        stop("ERROR: `deg_results` is required when statistics_mode = 'precomputed_deg'")
      }
      omix_extract_precomputed_deg_stats(
        deg_results = deg_results,
        genes = prepared$genes_found,
        categories = prepared$categories,
        deg_gene_column = deg_gene_column,
        pvalue_type = pvalue_type
      )
    },
    "within_plot" = omix_calculate_within_plot_stats(
      prepared$data,
      method = statistical_method,
      p_adjust_method = p_adjust_method
    ),
    "none" = data.frame(
      gene = character(), group1 = character(), group2 = character(),
      p_value = numeric(), p_adjusted = numeric(), source = character()
    )
  )
  if (!nrow(statistics)) {
    statistics <- data.frame(
      gene = character(), group1 = character(), group2 = character(),
      p_value = numeric(), p_adjusted = numeric(), source = character()
    )
  }

  plots <- lapply(prepared$genes_found, function(gene) {
    omix_make_gene_boxplot(
      data_long = prepared$data,
      gene = gene,
      statistics = statistics,
      pvalue_type = pvalue_type,
      plot_type = plot_type,
      plot_title_prefix = plot_title_prefix,
      y_axis_label = y_axis_label,
      colors = colors
    )
  })
  names(plots) <- prepared$genes_found

  output_files <- list()
  if (!is.null(output_dir) && nzchar(output_dir)) {
    dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
    plot_directory <- file.path(output_dir, "gene_boxplots")
    dir.create(plot_directory, recursive = TRUE, showWarnings = FALSE)
    for (gene in names(plots)) {
      path <- file.path(plot_directory, paste0(omix_safe_filename(gene), ".png"))
      ggplot2::ggsave(path, plot = plots[[gene]], width = image_width,
        height = image_height, units = "in", dpi = image_dpi)
    }
    statistics_file <- file.path(output_dir, "gene_boxplot_statistics.csv")
    data_file <- file.path(output_dir, "gene_boxplot_expression_long.csv")
    summary_file <- file.path(output_dir, "gene_boxplot_run_summary.csv")
    utils::write.csv(statistics, statistics_file, row.names = FALSE)
    utils::write.csv(prepared$data, data_file, row.names = FALSE)
    utils::write.csv(data.frame(
      statistics_mode = statistics_mode,
      pvalue_type = pvalue_type,
      genes_plotted = length(plots),
      samples_included = prepared$sample_count,
      categories = paste(prepared$categories, collapse = ","),
      stringsAsFactors = FALSE
    ), summary_file, row.names = FALSE)
    output_files <- list(
      plot_directory = plot_directory,
      statistics = statistics_file,
      expression_long = data_file,
      summary = summary_file
    )
  }

  invisible(list(
    data = prepared$data,
    statistics = statistics,
    plots = plots,
    output_files = output_files,
    categories = prepared$categories
  ))
}
