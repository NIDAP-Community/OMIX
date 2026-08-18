#' Volcano Plot - Enhanced [CCBR] [scRNA-seq] [Bulk]
#'
#' @description
#' Implementation of Bioconductor's Enhanced Volcano Plot (v1.6.0,
#' https://bioconductor.org/packages/release/bioc/html/EnhancedVolcano.html).
#' Template written by Matthew Angel and maintained by CCBR. Final Potomac
#' Compatible Version: v52. Final Sugarloaf V1 Version: v55. Latest Sugarloaf V2
#' Version: v67. View Documentation
#'
#' @details
#' Contact CCBR at \email{NCICCBRNIDAP@@mail.nih.gov} if you encounter problems.
#'
#' @param deg_table
#' A data frame. Dataset containing differential expression of genes (DEG)
#' analysis output columns. Usually, this includes columns for gene names,
#' (log) fold changes, (adjusted) p-values, and t-statistics. Other columns
#' may be present.
#' @param column_with_feature_id
#' Character. Column from the input DEG table containing Feature ID (such as
#' Gene Names, Isoform IDs, UniProt IDs, and so on). This is usually the first
#' column (named "Feature_ID" or "Gene"). Only Text type columns will be
#' allowed.
#' @param significance_column
#' Character vector. Choose an unadjusted or adjusted p-value column from the
#' input DEG table to use as the measure of significance in your Volcano plot.
#' If your DEG analysis contained more than one contrast comparison, you will
#' only be able to select one of these at a time. Make sure you select the
#' same contrast that was selected for the "Log2 Fold Change Column"
#' parameter.
#' @param log2_fold_change_column
#' Character vector. Choose a log2 fold change column from the input DEG
#' table. If your DEG analysis contained more than one contrast comparison,
#' you will only be able to select one of these at a time. Make sure you
#' select the same contrast that was selected for the "Significance Column"
#' parameter.
#' @param p_value_threshold Numeric. Default: \code{0.001}.
#' @param log2_fold_change_threshold Numeric. Default: \code{1.0}.
#' @param choose_feature_to_label_by
#' Character. One of ['p-value', 'fold-change']. This selection determines how
#' the feature (gene) list is sorted before choosing the top-N features as set
#' by the "Number of Features to Label" parameter. Choose either (absolute)
#' fold change, p-value, or t-statistic to label the top features by the
#' selected metric. This also determines which features are labeled in the
#' plot. This option is negated if only using custom labels. Default:
#' \code{p-value}.
#' @param number_of_features_to_label
#' Numeric. To minimize clutter on the volcano plot, it is inadvisable to
#' label every feature (gene). You can choose to label any number of features
#' or none. The value of this parameter (N) is used to label the top N
#' features only. See the "Choose Features To Label By" parameter for options
#' on how to sort the gene list before labeling the top N features. Will be
#' negated if the option to use only additional labels is selected. Default:
#' \code{30}.
#' @param label_only_my_feature_list
#' Logical. Select TRUE when you want to label ONLY a specific list of
#' features given in the "My Feature List" parameter. Default: \code{FALSE}.
#' @param use_custom_axis_label
#' Logical. Use text from "Custom significance label"? Default: \code{FALSE}.
#' @param my_feature_list
#' Character. Additional features (genes) to label. If the option to use only
#' custom labels is selected, these will be the only points labeled on the
#' plot. Otherwise, these will be plotted in addition to the other top
#' features. This should be a comma-separated or space-delimited list.
#' @param top_genes_labeled_only_if_passing_thresholds
#' Logical. If TRUE, only genes passing your p-value and logFC thresholds
#' (Basic Parameters) will be labeled on the final plot. If FALSE, genes that
#' do not pass thresholds may be labeled, also. Default is TRUE. Default:
#' \code{TRUE}.
#' @param label_size Numeric. Default: \code{4}.
#' @param custom_significance_label
#' Character. This replaces bulky names for the p-value column. Default:
#' \code{p-value}.
#' @param custom_log_fold_change_label
#' Character. This replaces bulky column names for the fold-change column.
#' Default: \code{log2FC}.
#' @param plot_title Character. Default: \code{Volcano Plots}.
#' @param y_limit
#' Numeric. Maximum value for y-axis. Defaults to -log10(min(pval)). Set to 0
#' for automatic scaling. Default: \code{0}.
#' @param use_auto_axis_capping
#' Logical. If \code{TRUE}, automatically cap X/Y limits using the quantile
#' set by \code{auto_axis_capping_quantile} when manual limits are not
#' provided. Default: \code{FALSE}.
#' @param auto_axis_capping_quantile
#' Numeric. Quantile used for automatic axis capping (between 0.5 and 1).
#' Default: \code{0.995}.
#' @param auto_axis_capping_min_y_limit
#' Numeric. Minimum allowed Y cap when automatic capping is enabled and
#' \code{y_limit = 0}. Default: \code{0}.
#' @param auto_axis_capping_symmetric_x
#' Logical. If \code{TRUE}, uses symmetric X limits from
#' \code{±quantile(abs(log2FC))}. If \code{FALSE}, uses asymmetric lower/upper
#' quantiles. Default: \code{TRUE}.
#' @param custom_x_axis_limits
#' Character. Leave empty for automatic scaling, put one number for
#' symmetrical scale (i.e, putting "5" would result in a range from "-5" to
#' "5"), or put two numbers separated by comma for "asymmetrical" scale (i.e,
#' putting "-2,4" would result in a range from "-2" to "4")
#' @param x_limit_padding
#' Numeric. Add additional units to x-limit Default: \code{0}.
#' @param y_limit_padding
#' Numeric. Adds additional units to y-limit. Default: \code{0}.
#' @param axis_label_size Numeric. Default: \code{24}.
#' @param point_size Numeric. Default: \code{2}.
#' @param image_width Numeric. Default: \code{3000}.
#' @param image_height Numeric. Default: \code{3000}.
#' @param resolution_dpi_ Numeric. Default: \code{300}.
#' @param output_file_path Character or \code{NULL}. Optional output path for
#' volcano figure(s). If multiple contrasts are provided, suffixes are added.
#' @param color_not_significant Character. Color for points that are not
#' significant (bottom-center quadrant). Default: \code{"gray"}.
#' @param color_fold_change_only Character. Color for points with fold change
#' only (left and right quadrants). Default: \code{"orange"}.
#' @param color_significant_only Character. Color for points with significance
#' only (top-center quadrant). Default: \code{"green4"}.
#' @param color_significant_and_fold_change Character. Color for points with
#' both significance and fold change (top-left and top-right quadrants).
#' Default: \code{"red3"}.
#'
#' @return A data frame of DEG results used to generate the volcano plot,
#' including fold change, p-value, significance category, and label columns.
#' Side effect: volcano plot is rendered.
#'
#' @importFrom dplyr .
#' @importFrom ggplot2 .
#' @importFrom stringr .
#' @importFrom ggrepel .
#' @export
volcano_plot_enhanced <- function(
  deg_table,
  pvalue_type = "nominal",
  column_with_feature_id,
  significance_column,
  log2_fold_change_column,
  p_value_threshold = 0.001,
  log2_fold_change_threshold = 1.0,
  choose_feature_to_label_by = "p-value",
  number_of_features_to_label = 30,
  label_only_my_feature_list = FALSE,
  use_custom_axis_label = FALSE,
  my_feature_list = NULL,
  top_genes_labeled_only_if_passing_thresholds = TRUE,
  label_size = 4,
  label_box_padding = 1,
  label_force = 1,
  label_max_overlaps = Inf,
  custom_significance_label = "p-value",
  custom_log_fold_change_label = "log2FC",
  plot_title = "Volcano Plots",
  plot_subtitle = "",
  y_limit = 0,
  use_auto_axis_capping = TRUE,
  auto_axis_capping_quantile = 0.9999,
  auto_axis_capping_min_y_limit = 0,
  auto_axis_capping_symmetric_x = TRUE,
  custom_x_axis_limits = NULL,
  x_limit_padding = 0,
  y_limit_padding = 0,
  plot_title_size = 16,
  axis_title_size = 14,
  axis_text_size = 12,
  point_size = 2,
  image_width = 3000,
  image_height = 3000,
  resolution_dpi_ = 300,
  output_file_path = NULL,
  color_not_significant = "gray",
  color_fold_change_only = "orange",
  color_significant_only = "green4",
  color_significant_and_fold_change = "red3"
) {
  if (is.character(deg_table) && length(deg_table) == 1) {
    if (!file.exists(deg_table)) {
      stop("ERROR: `deg_table` file does not exist: ", deg_table)
    }
    deg_table <- read.csv(
      deg_table,
      check.names = FALSE,
      stringsAsFactors = FALSE
    )
  }

  if (!is.data.frame(deg_table)) {
    stop("ERROR: `deg_table` must be a data frame or a valid file path.")
  }

  if (
    !is.numeric(auto_axis_capping_quantile) ||
      length(auto_axis_capping_quantile) != 1 ||
      is.na(auto_axis_capping_quantile) ||
      auto_axis_capping_quantile <= 0.5 ||
      auto_axis_capping_quantile >= 1
  ) {
    stop(
      paste0(
        "ERROR: `auto_axis_capping_quantile` must be a single numeric ",
        "value between 0.5 and 1."
      )
    )
  }

  infer_feature_column <- function(df) {
    preferred <- c("Gene", "Feature_ID", "FeatureID", "gene", "gene_id")
    hit <- preferred[preferred %in% colnames(df)][1]
    if (!is.na(hit)) {
      return(hit)
    }
    candidates <- colnames(df)[vapply(
      df,
      function(x) is.character(x) || is.factor(x),
      logical(1)
    )]
    if (length(candidates) == 0) {
      stop("ERROR: Could not infer `column_with_feature_id`.")
    }
    candidates[1]
  }

  infer_significance_columns <- function(df, prefer_adjusted = TRUE) {
    p_cols <- grep(
      "adjpval|pval|p_value|pvalue|fdr",
      colnames(df),
      ignore.case = TRUE,
      value = TRUE
    )
    p_cols <- p_cols[vapply(df[p_cols], is.numeric, logical(1))]
    
    # Split into adjusted and nominal
    adj_cols <- grep("adj", p_cols, ignore.case = TRUE, value = TRUE)
    nom_cols <- grep("^((?!adj).)*pval", p_cols, ignore.case = TRUE, value = TRUE, perl = TRUE)
    
    # Return based on preference
    if (prefer_adjusted && length(adj_cols) > 0) {
      return(adj_cols)
    } else if (!prefer_adjusted && length(nom_cols) > 0) {
      return(nom_cols)
    } else if (length(adj_cols) > 0) {
      return(adj_cols)
    } else if (length(nom_cols) > 0) {
      return(nom_cols)
    } else {
      return(p_cols)
    }
  }

  infer_logfc_columns <- function(df) {
    fc_cols <- grep(
      "logfc|log2fc|log2_fold_change",
      colnames(df),
      ignore.case = TRUE,
      value = TRUE
    )
    fc_cols[vapply(df[fc_cols], is.numeric, logical(1))]
  }

  if (
    is.null(column_with_feature_id) ||
      !nzchar(column_with_feature_id) ||
      !column_with_feature_id %in% colnames(deg_table)
  ) {
    column_with_feature_id <- infer_feature_column(deg_table)
    message(paste0("Using feature column: ", column_with_feature_id))
  }

  if (is.null(significance_column) || length(significance_column) == 0) {
    prefer_adjusted <- tolower(pvalue_type) == "adjusted"
    significance_column <- infer_significance_columns(deg_table, prefer_adjusted)
    if (length(significance_column) == 0) {
      stop("ERROR: Could not infer a significance column.")
    }
    message(paste0(
      "Using significance column(s): ",
      paste(significance_column, collapse = ", ")
    ))
  }

  if (
    is.null(log2_fold_change_column) || length(log2_fold_change_column) == 0
  ) {
    log2_fold_change_column <- infer_logfc_columns(deg_table)
    if (length(log2_fold_change_column) == 0) {
      stop("ERROR: Could not infer a log2 fold-change column.")
    }
    message(paste0(
      "Using log2 fold-change column(s): ",
      paste(log2_fold_change_column, collapse = ", ")
    ))
  }

  significance_column <- significance_column[
    significance_column %in% colnames(deg_table)
  ]
  log2_fold_change_column <- log2_fold_change_column[
    log2_fold_change_column %in% colnames(deg_table)
  ]

  if (
    length(significance_column) == 0 || length(log2_fold_change_column) == 0
  ) {
    stop(
      paste0(
        "ERROR: Selected significance/log2 fold-change columns are ",
        "not present in `deg_table`."
      )
    )
  }

  if (length(significance_column) != length(log2_fold_change_column)) {
    if (length(significance_column) == 1) {
      significance_column <- rep(
        significance_column,
        length(log2_fold_change_column)
      )
    } else if (length(log2_fold_change_column) == 1) {
      log2_fold_change_column <- rep(
        log2_fold_change_column,
        length(significance_column)
      )
    } else {
      stop(
        paste0(
          "ERROR: `significance_column` and `log2_fold_change_column` ",
          "must have matching lengths, or one must be length 1."
        )
      )
    }
  }

  parse_feature_list <- function(x) {
    if (is.null(x) || (length(x) == 1 && !nzchar(trimws(x)))) {
      return(character(0))
    }
    if (length(x) > 1) {
      return(unique(trimws(x[nzchar(trimws(x))])))
    }
    vals <- unlist(strsplit(gsub(",", " ", x), "\\s+"))
    unique(vals[nzchar(vals)])
  }

  custom_labels <- parse_feature_list(my_feature_list)
  rank_values <- list()

  get_x_limits <- function(
    values,
    x_padding,
    custom_limits,
    use_auto_capping,
    cap_quantile,
    symmetric_x
  ) {
    if (is.null(custom_limits) || !nzchar(trimws(custom_limits))) {
      if (use_auto_capping) {
        if (symmetric_x) {
          x_cap <- as.numeric(stats::quantile(
            abs(values),
            probs = cap_quantile,
            na.rm = TRUE
          ))
          return(c(-(x_cap + x_padding), x_cap + x_padding))
        }

        lower_q <- as.numeric(stats::quantile(
          values,
          probs = 1 - cap_quantile,
          na.rm = TRUE
        ))
        upper_q <- as.numeric(stats::quantile(
          values,
          probs = cap_quantile,
          na.rm = TRUE
        ))
        return(c(lower_q - x_padding, upper_q + x_padding))
      }

      return(c(
        floor(min(values, na.rm = TRUE)) - x_padding,
        ceiling(max(values, na.rm = TRUE)) + x_padding
      ))
    }

    if (!grepl(",", custom_limits)) {
      lim <- as.numeric(trimws(custom_limits))
      return(c(-1 * lim, lim))
    }

    split_values <- strsplit(custom_limits, ",")[[1]]
    c(as.numeric(trimws(split_values[1])), as.numeric(trimws(split_values[2])))
  }

  get_y_max <- function(
    values,
    user_y_limit,
    use_auto_capping,
    cap_quantile,
    min_y_limit
  ) {
    if (user_y_limit > 0) {
      return(user_y_limit)
    }

    if (use_auto_capping) {
      y_cap <- as.numeric(stats::quantile(
        values,
        probs = cap_quantile,
        na.rm = TRUE
      ))
      return(max(y_cap, min_y_limit))
    }

    max(values, na.rm = TRUE)
  }

  save_plot <- function(plot_obj, out_path, suffix, width_in, height_in, dpi) {
    if (is.null(out_path) || !nzchar(trimws(out_path))) {
      return(invisible(NULL))
    }

    dir_name <- dirname(out_path)
    if (!dir.exists(dir_name)) {
      dir.create(dir_name, recursive = TRUE)
    }

    ext <- tools::file_ext(out_path)
    stem <- tools::file_path_sans_ext(basename(out_path))
    if (!nzchar(ext)) {
      png_path <- file.path(dir_name, paste0(stem, "_", suffix, ".png"))
      pdf_path <- file.path(dir_name, paste0(stem, "_", suffix, ".pdf"))
      ggplot2::ggsave(
        png_path,
        plot_obj,
        width = width_in,
        height = height_in,
        dpi = dpi
      )
      ggplot2::ggsave(pdf_path, plot_obj, width = width_in, height = height_in)
      return(invisible(c(png_path, pdf_path)))
    }

    out_file <- out_path
    if (
      length(significance_column) > 1 || length(log2_fold_change_column) > 1
    ) {
      out_file <- file.path(dir_name, paste0(stem, "_", suffix, ".", ext))
    }
    ggplot2::ggsave(
      out_file,
      plot_obj,
      width = width_in,
      height = height_in,
      dpi = ifelse(tolower(ext) == "pdf", NA, dpi)
    )
    invisible(out_file)
  }

  for (index in seq_along(log2_fold_change_column)) {
    lfc_col <- log2_fold_change_column[index]
    sig_col <- significance_column[index]

    df <- deg_table %>%
      dplyr::select(all_of(c(column_with_feature_id, lfc_col, sig_col))) %>%
      dplyr::mutate(
        !!sym(lfc_col) := tidyr::replace_na(.data[[lfc_col]], 0),
        !!sym(sig_col) := tidyr::replace_na(.data[[sig_col]], 1)
      ) %>%
      as.data.frame()

    plot_sig_name <- sig_col
    plot_lfc_name <- lfc_col
    if (use_custom_axis_label) {
      if (nzchar(custom_significance_label)) {
        names(df)[names(df) == sig_col] <- custom_significance_label
        plot_sig_name <- custom_significance_label
      }
      if (nzchar(custom_log_fold_change_label)) {
        names(df)[names(df) == lfc_col] <- custom_log_fold_change_label
        plot_lfc_name <- custom_log_fold_change_label
      }
    }

    rank_values[[paste0("C_", gsub("_pval|p_val_", "", sig_col), "_rank")]] <-
      -log10(pmax(df[[plot_sig_name]], .Machine$double.eps)) *
      sign(df[[plot_lfc_name]])

    if (choose_feature_to_label_by == "fold-change") {
      df <- df %>% dplyr::arrange(desc(abs(.data[[plot_lfc_name]])))
    } else {
      df <- df %>% dplyr::arrange(.data[[plot_sig_name]])
    }

    if (top_genes_labeled_only_if_passing_thresholds) {
      df_sub <- df %>%
        dplyr::filter(
          .data[[plot_sig_name]] <= p_value_threshold,
          abs(.data[[plot_lfc_name]]) >= log2_fold_change_threshold
        )
    } else {
      df_sub <- df
    }

    top_labels <- head(
      as.character(df_sub[[column_with_feature_id]]),
      number_of_features_to_label
    )
    valid_custom_labels <- custom_labels[
      custom_labels %in% as.character(df[[column_with_feature_id]])
    ]

    if (label_only_my_feature_list) {
      labels_to_use <- valid_custom_labels
    } else {
      labels_to_use <- unique(c(top_labels, valid_custom_labels))
    }

    df <- df %>%
      dplyr::mutate(
        neg_log10_p = -log10(pmax(.data[[plot_sig_name]], .Machine$double.eps)),
        significance_group = dplyr::case_when(
          .data[[plot_sig_name]] <= p_value_threshold &
            abs(.data[[plot_lfc_name]]) >=
              log2_fold_change_threshold ~ "Significant and fold change",
          .data[[plot_sig_name]] <= p_value_threshold ~ "Significant only",
          abs(.data[[plot_lfc_name]]) >=
            log2_fold_change_threshold ~ "Fold change only",
          TRUE ~ "Not significant"
        ),
        plot_label = ifelse(
          .data[[column_with_feature_id]] %in% labels_to_use,
          as.character(.data[[column_with_feature_id]]),
          ""
        )
      ) %>%
      as.data.frame()

    max_y <- get_y_max(
      values = df$neg_log10_p,
      user_y_limit = y_limit,
      use_auto_capping = use_auto_axis_capping,
      cap_quantile = auto_axis_capping_quantile,
      min_y_limit = auto_axis_capping_min_y_limit
    )

    x_limits <- get_x_limits(
      df[[plot_lfc_name]],
      x_limit_padding,
      custom_x_axis_limits,
      use_auto_capping = use_auto_axis_capping,
      cap_quantile = auto_axis_capping_quantile,
      symmetric_x = auto_axis_capping_symmetric_x
    )

    # Build ggplot object
    plot_obj <- ggplot2::ggplot(df, ggplot2::aes(x = .data[[plot_lfc_name]], y = .data[["neg_log10_p"]])) +
      ggplot2::geom_point(
        ggplot2::aes(color = .data[["significance_group"]]),
        size = point_size,
        alpha = 0.85
      ) +
      ggrepel::geom_text_repel(
        ggplot2::aes(label = .data[["plot_label"]]),
        size = label_size,
        max.overlaps = label_max_overlaps,
        box.padding = label_box_padding,
        force = label_force,
        min.segment.length = 0
      ) +
      ggplot2::geom_vline(
        xintercept = c(-log2_fold_change_threshold, log2_fold_change_threshold),
        linetype = "dashed",
        color = "grey40"
      ) +
      ggplot2::geom_hline(
        yintercept = -log10(p_value_threshold),
        linetype = "dashed",
        color = "grey40"
      ) +
      ggplot2::scale_color_manual(
        values = c(
          "Not significant" = color_not_significant,
          "Fold change only" = color_fold_change_only,
          "Significant only" = color_significant_only,
          "Significant and fold change" = color_significant_and_fold_change
        )
      ) +
      ggplot2::coord_cartesian(
        xlim = x_limits,
        ylim = c(0, ceiling(max_y) + y_limit_padding)
      ) +
      ggplot2::labs(
        title = plot_title,
        subtitle = if (nzchar(plot_subtitle)) plot_subtitle else gsub("_", " ", sig_col),
        x = gsub("_", " ", plot_lfc_name),
        y = gsub("_", " ", plot_sig_name),
        color = NULL
      ) +
      ggplot2::theme_bw() +
      ggplot2::theme(
        plot.title = ggplot2::element_text(size = plot_title_size, face = "bold"),
        axis.title = ggplot2::element_text(size = axis_title_size),
        axis.text = ggplot2::element_text(size = axis_text_size),
        legend.text = ggplot2::element_text(size = 11),
        legend.position = "top"
      )

    width_in <- image_width / resolution_dpi_
    height_in <- image_height / resolution_dpi_
    suffix <- paste0("volcano_", gsub("[^A-Za-z0-9]+", "_", sig_col))
    save_plot(
      plot_obj,
      output_file_path,
      suffix,
      width_in,
      height_in,
      resolution_dpi_
    )
  }

  df.final <- dplyr::bind_cols(deg_table, as.data.frame(rank_values))
  df.final
}
