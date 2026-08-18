#' L2P Analysis for Multiple Comparisons [CCBR] [scRNA-seq] [Bulk]
#'
#' @description
#' Runs pathway over-representation analysis using L2P (List to pathway,
#' https://github.com/ccbr/l2p) comparing significant pathways from several
#' differentially expressed gene (DEG) lists. Final Potomac Compatible Version:
#' v70. Final Sugarloaf V1: v84. View Documentation
#'
#' @details
#' Contact CCBR at \email{NCICCBRNIDAP@@mail.nih.gov} if you encounter problems.
#'
#' @param deg_table
#' A data frame. Dataset containing differential expression of genes. Should
#' contain a column with gene name, (log) fold change and p-value /
#' t-statistic.
#' @param gene_names_column Character. Column containing gene names. If omitted
#' and the table has a common gene column name such as \code{Gene}, it is
#' inferred.
#' @param comparisons
#' Character vector. Optional comparison IDs such as \code{c("B-A", "C-A")}.
#' When supplied, missing column selections are derived as
#' \code{<comparison>_tstat}, \code{<comparison>_pval}, and
#' \code{<comparison>_FC}. Explicit column parameters override derived columns.
#' @param t_statistic_columns
#' Character vector. Select t-statistic columns on which rank order up and
#' downregulated genes to run pathway enrichment. Bubble Plot will display in
#' the same order of the input columns.
#' @param significance_columns
#' Character vector. If "Select By Rank" (above) is FALSE, then choose columns
#' containing p-values or adjusted p-values upon which to filter your gene
#' list. You must then also set a "Significance Threshold" (below).
#' @param fold_change_columns
#' Character vector. If select by rank is FALSE, choose fold change or log
#' fold change column on which to filter genelist. If selecting log fold
#' change, fold change threshold (below) is still applied as fold change, i.e.
#' if selecting a 2 fold-change threshold, this will be equivalent to 1 log
#' fold-change.
#' @param species
#' Character. One of ['Human', 'Mouse', 'Macaque', 'Rat', 'Zebrafish',
#' 'Rabbit', 'Drosophila']. If other organism than human is selected, gene
#' names are converted to human before running l2p. Default: \code{Human}.
#' @param update_genes
#' Logical. If TRUE (default), the input gene symbols are updated for the L2P
#' run and a column with the original gene names is added to the output.
#' Otherwise, the input gene symbols are used as is. Default: \code{TRUE}.
#' @param collections_to_include
#' Character. Geneset Sources to Use: GO: http://geneontology.org REACTOME:
#' https://reactome.org/ KEGG: https://www.kegg.jp/ PANTH:
#' http://www.pantherdb.org/ PID: Pathway interaction database BIOCYC:
#' https://biocyc.org/ WikiPathways: https://www.wikipathways.org H: MSigDB
#' Hallmark gene sets C1: MSigDB positional gene sets C2: MSigDB curated gene
#' sets C3: MSigDB motif gene sets C4: MSigDB computational gene sets C6:
#' MSigDB oncogenic gene sets C7: MSigDB immunologic gene sets C8: MSigDB
#' cell type signature gene sets Default: \code{c("H")}.
#' @param custom_pathways
#' Optional custom pathway database. May be a list in the format expected by
#' \code{l2p(custompathways = ...)} or a long-format data frame with pathway
#' names and gene symbols.
#' @param custom_pathway_name_column
#' Character. Column containing pathway names when \code{custom_pathways} is a
#' data frame. Default: \code{gene_set_name}.
#' @param custom_pathway_gene_column
#' Character. Column containing gene symbols when \code{custom_pathways} is a
#' data frame. Default: \code{gene_symbol}.
#' @param select_by_rank
#' Logical. If TRUE, your genes will be ranked by the column you select in the
#' "Column Used to Rank Genes" parameter under the "Genelist selected by
#' t-statistic rank" section. If FALSE, you need to set other parameters in
#' "Genelist selected by fold-change and pval" section of the template to set
#' thresholds on significance and fold change columns instead. This latter
#' (FALSE) parameterization may be appropriate if you have heterogeneous data
#' like Single Cell RNA-Seq data or highly variable data (e.g. few significant
#' genes). Set to TRUE by default. Default: \code{TRUE}.
#' @param top_pathways
#' Numeric. Select number (n) of top pathways for comparing across groups. If
#' a pathway is found to be among the top n significant in at least x
#' contrasts (x being the number of significant events, below), it will be
#' considered for comparison across all groups. Default: \code{10}.
#' @param number_of_significant_events
#' Numeric. Filter to pathways that have at least n number of instances in
#' significant enrichment Default: \code{1}.
#' @param select_top_percentage_of_genes
#' Logical. If "Select By Rank" (above) is TRUE, select top percentage of up
#' and downregulated genes ranked by t-statistic. If TRUE, set at 10%. If
#' FALSE, uses selected number of genes (set below). Default: \code{TRUE}.
#' @param select_top_genes
#' Numeric. If "Select By Rank" (above) is TRUE, and Select Top Percentage of
#' Genes is FALSE, select number of top ranked genes by t-statistic. Set to
#' 500 by default Default: \code{500}.
#' @param significance_threshold
#' Numeric. If "Select By Rank" (above) is FALSE, then set p-value or adjusted
#' p-value threshold on which to set genelist. Set to 0.05 by default.
#' Default: \code{0.05}.
#' @param fold_change_threshold
#' Numeric. If "Select By Rank" (above) is FALSE, then set fold change or log
#' fold change threshold on which to select genelist. If you have a bulk
#' RNA-seq dataset or single cell RNA-Seq with few DEG genes, we recommend
#' setting this to 1.2 initially. Threshold is for fold-change rather than
#' log fold-change. Default: \code{1.2}.
#' @param minimum_number_of_deg_genes
#' Numeric. Desired minimum number of selected genes per up/down list before a
#' warning is printed. Default: \code{100}.
#' @param plot_bubble_size
#' Character. One of ['pval', 'fdr', 'number_hits']. For the size of the
#' bubble in the plot, use either -log10(pval), -log10(fdr pval) number of
#' significant hits in the pathway Default: \code{pval}.
#' @param plot_bubble_color
#' Character. One of ['enrichment_score', 'net_enrichment_score',
#' 'percent_gene_hits_per_pathway']. For the bubble color, choose to plot
#' enrichment score (ES) or net enrichment score (ie. ES for upregulated genes
#' - ES for downregulated genes). Net enrichment score takes into account
#' some level of enrichment in both up and downregulated genes in a pathway.
#' Percent hits is positive for upregulated pathways and negative for
#' downregulated pathways Default: \code{enrichment_score}.
#' @param plot_bubble_max_color
#' Numeric. By default, the maximum color saturation is set to the maximum
#' absolute value of the variable used to color the bubbles. The allowed
#' values are between 0 and 1, but the recommended values, alternative to 1,
#' are usually 0.99 or 0.95 for a more robust display than the maximum.
#' Default: \code{1}.
#' @param pathway_axis_label_max_length
#' Numeric. Set pathway axis label maximum length as shown in Y-axis, set to
#' 45 by default. Default: \code{45}.
#' @param pathway_axis_label_font_size
#' Numeric. Sets font size of pathways on Y-axis label. Set to 5 by default.
#' Default: \code{5}.
#' @param use_built_in_gene_universe
#' Logical. If TRUE, use all genes in the gene universe, if FALSE, use all
#' genes in gene matrix as gene universe. Default is FALSE Default:
#' \code{FALSE}.
#' @param minimum_pathway_hit_count
#' Numeric. Minimum pathway hit count to consider as significant. Fisher's
#' Exact Test can often result in small sized pathway hits being significant
#' but because gene membership is low, biological relevance of the pathway is
#' difficult to interpret. Default is set to 5. Default: \code{5}.
#' @param pathway_size_limit
#' Numeric. Top pathway size limit (less than n) to remove large sized
#' pathways which tend to be too general to be biologically meaningful.
#' Default: \code{500}.
#' @param p_value_limit
#' Numeric. P-value limit (less than x) to restrict to significant pathways to
#' compare across groups. This filter is in addition to the "Top Pathways"
#' filter applied above to restrict to the top n number of pathways to compare
#' across groups. Default: \code{0.05}.
#' @param use_fdr_for_significance
#' Logical. If TRUE, use False Discovery Rate corrected p-value instead of
#' Fisher's Exact Test p-value to the threshold (set above) to limit
#' significant pathways to compare across groups. Helpful when there are a
#' large number of pathways. Default is FALSE. Default: \code{FALSE}.
#' @param maximum_pathways_to_plot
#' Numeric. Maximum number of unique pathway rows to show in the bubble plot.
#' Pathways are ranked by their most significant p-value or FDR across all
#' comparisons before this limit is applied. Default: \code{15}.
#' @param pathways_to_remove
#' Character vector. Add pathways to specifically remove from plot. Needs to
#' be entered exactly as appears - copy from the preview output (ctrl-c) and
#' paste (ctrl-v) into the box.
#' @param rename_groups
#' Character vector. Names to use for x-axis: enter in the order of
#' appearance. If blank, will take the original group names.
#' @param vertical_line_placement
#' Character vector. X-coordinates to add vertical line(s) to separate groups.
#' For example, entering 1 will add a dashed line between group 1 and group 2.
#' @param use_panel_plot
#' Logical. If set to TRUE, the plot will be divided into panels by
#' collections. This is not recommended when testing a large number of
#' collections simultaneously. Default: \code{FALSE}.
#' @param use_dynamic_pathway_font_size
#' Logical. If TRUE (default), pathway axis label font size will be determined
#' based on the number of pathways; if FALSE, parameter value from 'Pathway
#' Axis Label Font Size' will be used. Default: \code{TRUE}.
#' @param custom_pathway_order
#' Character vector. Optional manual order for pathway labels in the bubble
#' plot (using displayed labels after uppercasing and replacing underscores
#' with spaces).
#' @param x_axis_title
#' Character. Optional x-axis title for the bubble plot. Set to \code{NULL}
#' or an empty string to omit. Default: \code{NULL}.
#' @param y_axis_title
#' Character. Optional y-axis title for the bubble plot. Set to \code{NULL}
#' or an empty string to omit. Default: \code{NULL}.
#' @param x_axis_title_font_size
#' Numeric. Font size for the x-axis title. Default: \code{14}.
#' @param y_axis_title_font_size
#' Numeric. Font size for the y-axis title. Default: \code{14}.
#' @param x_axis_tick_font_size
#' Numeric. Font size for the x-axis tick labels. Default: \code{14}.
#' @param x_axis_tick_labels
#' Character vector. Optional replacement labels for x-axis ticks, provided
#' in the same order as the plotted groups. If omitted, original group names
#' or \code{rename_groups} values are used. Default: \code{NULL}.
#' @param y_axis_tick_labels
#' Character vector. Optional replacement labels for y-axis pathway ticks.
#' Provide either one label per displayed pathway row, or a named character
#' vector where names match raw pathway names or displayed pathway labels.
#' Default: \code{NULL}.
#' @param export_plot_file
#' Character. Optional output file path for saving the plot with
#' \code{ggplot2::ggsave}. Defaults to
#' \code{file.path(getwd(), "l2p_multi_v93_plot.png")}. Set to
#' \code{NULL} to disable plot export.
#' @param export_plot_width
#' Numeric. Plot width (in inches) used when saving with
#' \code{ggplot2::ggsave}. Default: \code{14}.
#' @param export_plot_height
#' Numeric. Plot height (in inches) used when saving with
#' \code{ggplot2::ggsave}. Default: \code{16}.
#' @param column_spacing
#' Numeric multiplier controlling horizontal spacing between contrast columns
#' in the bubble plot. Use larger values for wider spacing. Default:
#' \code{0.5}.
#' @param export_results_file
#' Character. Optional output file path for saving the returned results as CSV.
#' A companion provenance CSV is written with \code{_provenance} appended to
#' the basename. Defaults to
#' \code{file.path(getwd(), "l2p_multi_v93_results.csv")}. Set to
#' \code{NULL} to disable results and provenance export.
#'
#' @return A data frame of L2P pathway enrichment results across all
#' contrasts, including pathway name, category, direction, hit counts,
#' enrichment score, p-value, FDR, and gene lists.
#'
#' @importFrom dplyr .
#' @importFrom tidyr .
#' @importFrom ggplot2 .
#' @importFrom stringr .
#' @importFrom magrittr .
#' @importFrom l2p .
#' @export
l2p_multi <- function(
  deg_table,
  gene_names_column = NULL,
  t_statistic_columns = NULL,
  significance_columns = NULL,
  fold_change_columns = NULL,
  comparisons = NULL,
  species = "Human",
  update_genes = TRUE,
  collections_to_include = c("H"),
  custom_pathways = NULL,
  custom_pathway_name_column = "gene_set_name",
  custom_pathway_gene_column = "gene_symbol",
  select_by_rank = TRUE,
  top_pathways = 10,
  number_of_significant_events = 1,
  select_top_percentage_of_genes = TRUE,
  select_top_genes = 500,
  significance_threshold = 0.05,
  fold_change_threshold = 1.2,
  minimum_number_of_deg_genes = 100,
  plot_bubble_size = "pval",
  plot_bubble_color = "enrichment_score",
  plot_bubble_max_color = 1,
  pathway_axis_label_max_length = 45,
  pathway_axis_label_font_size = 5,
  use_built_in_gene_universe = FALSE,
  minimum_pathway_hit_count = 5,
  pathway_size_limit = 500,
  p_value_limit = 0.05,
  use_fdr_for_significance = FALSE,
  maximum_pathways_to_plot = 15,
  pathways_to_remove = NULL,
  rename_groups = NULL,
  vertical_line_placement = c(),
  use_panel_plot = FALSE,
  use_dynamic_pathway_font_size = TRUE,
  custom_pathway_order = NULL,
  x_axis_title = NULL,
  y_axis_title = NULL,
  x_axis_title_font_size = 14,
  y_axis_title_font_size = 14,
  x_axis_tick_font_size = 14,
  x_axis_tick_labels = NULL,
  y_axis_tick_labels = NULL,
  export_plot_file = file.path(getwd(), "l2p_multi_v93_plot.png"),
  export_plot_width = 14,
  export_plot_height = 16,
  column_spacing = 0.5,
  export_results_file = file.path(getwd(), "l2p_multi_v93_results.csv")
) {
  check_gene_species_case <- function(deg_table, gene_column, species) {
    if (!gene_column %in% colnames(deg_table)) {
      stop(sprintf(
        "ERROR: `gene_names_column` (%s) must exist in `deg_table`.",
        gene_column
      ))
    }

    genes <- unique(trimws(as.character(deg_table[[gene_column]])))
    genes <- genes[!is.na(genes) & nzchar(genes)]
    genes <- genes[grepl("[A-Za-z]", genes)]

    if (length(genes) < 10) {
      return(invisible(NULL))
    }

    letters_only <- gsub("[^A-Za-z]", "", genes)
    enough_letters <- nchar(letters_only) >= 2
    genes <- genes[enough_letters]
    letters_only <- letters_only[enough_letters]

    if (length(genes) < 10) {
      return(invisible(NULL))
    }

    human_like <- letters_only == toupper(letters_only)
    mouse_like <- grepl("^[A-Z][a-z]", genes) |
      grepl("^mt-", genes) |
      grepl("[A-Za-z][0-9-]*[a-z]", genes)

    mouse_fraction <- mean(mouse_like)
    human_fraction <- mean(human_like)
    min_count <- min(20, ceiling(length(genes) * 0.5))

    if (
      species == "human" &&
        sum(mouse_like) >= min_count &&
        mouse_fraction >= 0.50 &&
        mouse_fraction > human_fraction
    ) {
      examples <- paste(utils::head(genes[mouse_like], 8), collapse = ", ")
      stop(sprintf(
        paste0(
          "ERROR: Mouse appears to be the correct species for this ",
          "deg_table, but `species` is set to Human. Gene symbols in `%s` ",
          "look mouse-like because they contain lowercase letters ",
          "(examples: %s). Rerun with `species = \"Mouse\"`."
        ),
        gene_column,
        examples
      ))
    }

    if (
      species == "mouse" &&
        sum(human_like) >= min_count &&
        human_fraction >= 0.80
    ) {
      examples <- paste(utils::head(genes[human_like], 8), collapse = ", ")
      stop(sprintf(
        paste0(
          "ERROR: Human appears to be the correct species for this ",
          "deg_table, but `species` is set to Mouse. Gene symbols in `%s` ",
          "look human-like because they are mostly all caps ",
          "(examples: %s). Rerun with `species = \"Human\"`."
        ),
        gene_column,
        examples
      ))
    }

    invisible(NULL)
  }

  optional_vector <- function(x, arg_name) {
    if (is.null(x)) {
      return(NULL)
    }

    if (
      !is.character(x) ||
        length(x) == 0 ||
        any(is.na(x)) ||
        any(!nzchar(trimws(x)))
    ) {
      stop(sprintf(
        "ERROR: `%s` must be a non-empty character vector.",
        arg_name
      ))
    }

    trimws(x)
  }

  is_log_fold_change_column <- function(x) {
    grepl("logFC|log2FC|avg_log2FC", x)
  }

  optional_axis_title <- function(x, arg_name) {
    if (is.null(x) || length(x) == 0 || is.na(x[[1]])) {
      return(NULL)
    }

    x <- trimws(as.character(x[[1]]))
    if (!nzchar(x)) {
      return(NULL)
    }

    x
  }

  optional_axis_tick_labels <- function(x, arg_name) {
    if (is.null(x)) {
      return(NULL)
    }

    if (
      !is.character(x) ||
        length(x) == 0 ||
        any(is.na(x)) ||
        any(!nzchar(trimws(x)))
    ) {
      stop(sprintf(
        "ERROR: `%s` must be a non-empty character vector.",
        arg_name
      ))
    }

    label_names <- names(x)
    x <- trimws(x)
    if (!is.null(label_names) && any(nzchar(label_names))) {
      if (any(is.na(label_names) | !nzchar(label_names))) {
        stop(sprintf(
          paste0(
            "ERROR: `%s` must either be fully named or fully unnamed."
          ),
          arg_name
        ))
      }
      names(x) <- trimws(label_names)
    }

    x
  }

  numeric_font_size <- function(x, arg_name) {
    x <- as.numeric(x)[1]
    if (!is.finite(x) || x <= 0) {
      stop(sprintf(
        "ERROR: `%s` must be a positive numeric font size.",
        arg_name
      ))
    }

    x
  }

  numeric_positive_integer <- function(x, arg_name) {
    x <- as.numeric(x)[1]
    if (!is.finite(x) || x <= 0) {
      stop(sprintf(
        "ERROR: `%s` must be a positive number.",
        arg_name
      ))
    }

    floor(x)
  }

  dynamic_wrap_length <- function(max_length, font_size) {
    reference_font_size <- 8
    adjusted_length <- floor(max_length * reference_font_size / font_size)

    min(max_length, max(15, adjusted_length))
  }

  resolve_gene_names_column <- function(deg_table, gene_column) {
    provided <- ""
    if (
      !is.null(gene_column) &&
        length(gene_column) > 0 &&
        !is.na(gene_column[[1]])
    ) {
      provided <- trimws(as.character(gene_column[[1]]))
    }

    if (nzchar(provided) && provided %in% colnames(deg_table)) {
      return(provided)
    }

    if (nzchar(provided)) {
      trimmed_match <- colnames(deg_table)[trimws(colnames(deg_table)) == provided]
      if (length(trimmed_match) == 1) {
        return(trimmed_match)
      }

      case_match <- colnames(deg_table)[tolower(colnames(deg_table)) == tolower(provided)]
      if (length(case_match) == 1) {
        warning(sprintf(
          "Using gene column `%s`, matched case-insensitively from `%s`.",
          case_match,
          provided
        ))
        return(case_match)
      }
    }

    if (!nzchar(provided)) {
      common_gene_columns <- c(
        "GeneName",
        "Gene Symbols",
        "Gene",
        "gene",
        "GeneSymbol",
        "gene_symbol",
        "Gene_Symbol",
        "symbol",
        "Symbol",
        "gene_name",
        "Gene_Name",
        "gene_names",
        "Gene_Names",
        "gene_id",
        "GeneID",
        "Gene_ID"
      )
      inferred <- common_gene_columns[common_gene_columns %in% colnames(deg_table)]
      if (length(inferred) > 0) {
        warning(sprintf(
          "`gene_names_column` was not provided. Using inferred gene column `%s`.",
          inferred[[1]]
        ))
        return(inferred[[1]])
      }
    }

    available_columns <- paste(utils::head(colnames(deg_table), 30), collapse = ", ")
    if (ncol(deg_table) > 30) {
      available_columns <- paste0(available_columns, ", ...")
    }
    provided_label <- if (nzchar(provided)) provided else "NULL/empty"

    stop(sprintf(
      paste0(
        "ERROR: `gene_names_column` must be provided and exist in `deg_table`. ",
        "Received: %s. Available columns include: %s"
      ),
      provided_label,
      available_columns
    ))
  }

  ## -------------------------------- ##
  ## User-Defined Template Parameters ##
  ## -------------------------------- ##

  # Basic Parameters:
  species <- tolower(trimws(species))
  valid_species <- c(
    "human",
    "mouse",
    "macaque",
    "rat",
    "zebrafish",
    "rabbit",
    "drosophila"
  )
  if (!species %in% valid_species) {
    stop(
      paste0(
        "ERROR: `species` must be one of: Human, Mouse, Macaque, ",
        "Rat, Zebrafish, Rabbit, Drosophila"
      )
    )
  }

  column_spacing <- as.numeric(column_spacing)[1]
  if (!is.finite(column_spacing) || column_spacing <= 0) {
    column_spacing <- 0.5
  }

  plot_bubble_max_color <- as.numeric(plot_bubble_max_color)[1]
  if (
    !is.finite(plot_bubble_max_color) ||
      plot_bubble_max_color < 0 ||
      plot_bubble_max_color > 1
  ) {
    stop(
      "ERROR: `plot_bubble_max_color` must be a numeric value between 0 and 1."
    )
  }

  minimum_number_of_deg_genes <- as.numeric(minimum_number_of_deg_genes)[1]
  if (
    !is.finite(minimum_number_of_deg_genes) ||
      minimum_number_of_deg_genes < 0
  ) {
    stop(
      "ERROR: `minimum_number_of_deg_genes` must be a non-negative number."
    )
  }

  if (is.null(maximum_pathways_to_plot)) {
    maximum_pathways_to_plot <- Inf
  } else {
    maximum_pathways_to_plot <- as.numeric(maximum_pathways_to_plot)[1]
    if (
      !is.finite(maximum_pathways_to_plot) ||
        maximum_pathways_to_plot <= 0
    ) {
      stop(
        "ERROR: `maximum_pathways_to_plot` must be a positive number."
      )
    }
    maximum_pathways_to_plot <- floor(maximum_pathways_to_plot)
  }

  x_axis_title <- optional_axis_title(x_axis_title, "x_axis_title")
  y_axis_title <- optional_axis_title(y_axis_title, "y_axis_title")
  x_axis_title_font_size <- numeric_font_size(
    x_axis_title_font_size,
    "x_axis_title_font_size"
  )
  y_axis_title_font_size <- numeric_font_size(
    y_axis_title_font_size,
    "y_axis_title_font_size"
  )
  pathway_axis_label_max_length <- numeric_positive_integer(
    pathway_axis_label_max_length,
    "pathway_axis_label_max_length"
  )
  pathway_axis_label_font_size <- numeric_font_size(
    pathway_axis_label_font_size,
    "pathway_axis_label_font_size"
  )
  x_axis_tick_font_size <- numeric_font_size(
    x_axis_tick_font_size,
    "x_axis_tick_font_size"
  )
  x_axis_tick_labels <- optional_axis_tick_labels(
    x_axis_tick_labels,
    "x_axis_tick_labels"
  )
  y_axis_tick_labels <- optional_axis_tick_labels(
    y_axis_tick_labels,
    "y_axis_tick_labels"
  )

  ## --------------- ##
  ## Error Messages ##
  ## -------------- ##

  gene_names_column <- resolve_gene_names_column(deg_table, gene_names_column)
  check_gene_species_case(deg_table, gene_names_column, species)

  comparisons <- optional_vector(comparisons, "comparisons")
  t_statistic_columns <- optional_vector(
    t_statistic_columns,
    "t_statistic_columns"
  )
  significance_columns <- optional_vector(
    significance_columns,
    "significance_columns"
  )
  fold_change_columns <- optional_vector(
    fold_change_columns,
    "fold_change_columns"
  )

  if (!is.null(comparisons)) {
    if (
      !is.null(t_statistic_columns) &&
        length(t_statistic_columns) != length(comparisons)
    ) {
      stop(
        "ERROR: `t_statistic_columns` must have the same length as `comparisons`."
      )
    }
    if (
      !is.null(significance_columns) &&
        length(significance_columns) != length(comparisons)
    ) {
      stop(
        "ERROR: `significance_columns` must have the same length as `comparisons`."
      )
    }
    if (
      !is.null(fold_change_columns) &&
        length(fold_change_columns) != length(comparisons)
    ) {
      stop(
        "ERROR: `fold_change_columns` must have the same length as `comparisons`."
      )
    }

    if (is.null(t_statistic_columns)) {
      t_statistic_columns <- paste0(comparisons, "_tstat")
    }
    if (is.null(significance_columns)) {
      significance_columns <- paste0(comparisons, "_pval")
    }
    if (is.null(fold_change_columns)) {
      fold_change_columns <- paste0(comparisons, "_FC")
    }
  }

  if (select_by_rank) {
    if (is.null(t_statistic_columns) || length(t_statistic_columns) == 0) {
      stop(
        paste0(
          "ERROR: Provide `comparisons` or `t_statistic_columns` when ",
          "`select_by_rank` is TRUE."
        )
      )
    }
    if (!all(t_statistic_columns %in% colnames(deg_table))) {
      missing_cols <- setdiff(t_statistic_columns, colnames(deg_table))
      stop(sprintf(
        "ERROR: Missing t-statistic columns in `deg_table`: %s",
        paste(missing_cols, collapse = ", ")
      ))
    }

    groups_for_reporting <- gsub("_tstat", "", t_statistic_columns)
    if (is.null(fold_change_columns)) {
      fold_change_columns <- paste0(groups_for_reporting, "_FC")
    }
    if (is.null(significance_columns)) {
      significance_columns <- paste0(groups_for_reporting, "_pval")
    }

    missing_companion_columns <- setdiff(
      c(fold_change_columns, significance_columns),
      colnames(deg_table)
    )
    if (length(missing_companion_columns) > 0) {
      warning(sprintf(
        paste0(
          "Rank-based selection will continue, but companion column(s) ",
          "for least-selected-gene reporting are missing: %s"
        ),
        paste(missing_companion_columns, collapse = ", ")
      ))
    }
  } else {
    if (is.null(fold_change_columns) || is.null(significance_columns)) {
      stop(
        paste0(
          "ERROR: Provide `comparisons` or both `fold_change_columns` ",
          "and `significance_columns` when `select_by_rank` is FALSE."
        )
      )
    }
    if (!all(fold_change_columns %in% colnames(deg_table))) {
      missing_cols <- setdiff(fold_change_columns, colnames(deg_table))
      stop(sprintf(
        "ERROR: Missing fold-change columns in `deg_table`: %s",
        paste(missing_cols, collapse = ", ")
      ))
    }
    if (!all(significance_columns %in% colnames(deg_table))) {
      missing_cols <- setdiff(significance_columns, colnames(deg_table))
      stop(sprintf(
        "ERROR: Missing significance columns in `deg_table`: %s",
        paste(missing_cols, collapse = ", ")
      ))
    }
    if (length(fold_change_columns) != length(significance_columns)) {
      stop(
        paste0(
          "ERROR: `fold_change_columns` and `significance_columns` ",
          "must have equal length."
        )
      )
    }

    FCgroups <- gsub(
      "_FC|_logFC|_log2FC|avg_logFC_|avg_log2FC_",
      "",
      fold_change_columns
    )
    pvalgroups <- gsub(
      "_pval|_adjpval|p_val_|p_val_adj_",
      "",
      significance_columns
    )
    if (!identical(FCgroups, pvalgroups)) {
      stop(
        paste0(
          "ERROR: Make sure fold change and pval columns are in ",
          "the same group order"
        )
      )
    }

    fc_is_log <- is_log_fold_change_column(fold_change_columns)
    fc_is_linear <- grepl("_FC", fold_change_columns)
    if (!all(fc_is_log | fc_is_linear)) {
      stop(
        paste0(
          "ERROR: Make sure fold change columns are consistently ",
          "either log fold change or fold change"
        )
      )
    }

    if (!(all(fc_is_log) || all(fc_is_linear))) {
      stop(
        paste0(
          "ERROR: Make sure fold change columns are consistently ",
          "either log fold change or fold change"
        )
      )
    }

    sig_is_adj <- grepl("_adjpval|p_val_adj_", significance_columns)
    sig_is_p <- grepl("_pval|p_val_", significance_columns) & !sig_is_adj
    if (!all(sig_is_p | sig_is_adj)) {
      stop(
        paste0(
          "ERROR: Make sure significance columns are consistently ",
          "either pval or adjpval"
        )
      )
    }

    if (!(all(sig_is_p) || all(sig_is_adj))) {
      stop(
        paste0(
          "ERROR: Make sure significance columns are consistently ",
          "either pval or adjpval"
        )
      )
    }
  }

  custom_pathways_list <- NULL
  if (!is.null(custom_pathways)) {
    if (is.data.frame(custom_pathways)) {
      required_custom_cols <- c(
        custom_pathway_name_column,
        custom_pathway_gene_column
      )
      if (!all(required_custom_cols %in% colnames(custom_pathways))) {
        missing_cols <- setdiff(required_custom_cols, colnames(custom_pathways))
        stop(sprintf(
          "ERROR: Missing columns in `custom_pathways`: %s",
          paste(missing_cols, collapse = ", ")
        ))
      }

      keep_custom_pathways <- !is.na(custom_pathways[[custom_pathway_name_column]]) &
        !is.na(custom_pathways[[custom_pathway_gene_column]])
      custom_pathways <- custom_pathways[keep_custom_pathways, , drop = FALSE]
      split_pathways <- split(
        as.character(custom_pathways[[custom_pathway_gene_column]]),
        as.character(custom_pathways[[custom_pathway_name_column]])
      )
      custom_pathways_list <- Map(
        function(pathway_name, genes) {
          c(pathway_name, pathway_name, unique(genes))
        },
        names(split_pathways),
        split_pathways
      )
    } else if (is.list(custom_pathways)) {
      custom_pathways_list <- custom_pathways
    } else {
      stop(
        paste0(
          "ERROR: `custom_pathways` must be either a data frame or a list ",
          "formatted for `l2p(custompathways = ...)`."
        )
      )
    }
  }

  ## --------- ##
  ## Libraries ##
  ## --------- ##
  library(l2p)
  library(l2psupp)
  library(dplyr)
  library(tidyr)
  library(magrittr)
  library(ggplot2)
  library(stringr)
  library(RCurl)
  library(plyr)

  ## --------- ##
  ## Functions ##
  ## --------- ##

  collapse_for_provenance <- function(x) {
    if (is.null(x) || length(x) == 0) {
      return("")
    }

    paste(as.character(x), collapse = ";")
  }

  provenance_file_from_results <- function(results_file) {
    ext <- tools::file_ext(results_file)
    if (!nzchar(ext)) {
      ext <- "csv"
    }
    paste0(tools::file_path_sans_ext(results_file), "_provenance.", ext)
  }

  write_provenance_csv <- function(provenance, results_file) {
    if (is.null(results_file) || !nzchar(results_file)) {
      return(invisible(NULL))
    }

    provenance_file <- provenance_file_from_results(results_file)
    provenance_tbl <- data.frame(
      field = names(provenance),
      value = vapply(provenance, collapse_for_provenance, character(1)),
      stringsAsFactors = FALSE
    )
    utils::write.csv(provenance_tbl, provenance_file, row.names = FALSE)
    provenance_file
  }

  analysis_provenance <- list(
    analysis_template_name = "L2P_Multi_v93",
    analysis_template_version = "v93",
    analysis_run_timestamp = format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"),
    analysis_r_version = R.version.string,
    analysis_l2p_version = as.character(utils::packageVersion("l2p")),
    analysis_l2psupp_version = as.character(utils::packageVersion("l2psupp")),
    analysis_species = species,
    analysis_gene_column = collapse_for_provenance(gene_names_column),
    analysis_comparisons = collapse_for_provenance(comparisons),
    analysis_rank_columns = collapse_for_provenance(t_statistic_columns),
    analysis_significance_columns = collapse_for_provenance(significance_columns),
    analysis_fold_change_columns = collapse_for_provenance(fold_change_columns),
    analysis_collections_to_include = collapse_for_provenance(
      collections_to_include
    ),
    analysis_custom_pathways_used = !is.null(custom_pathways_list),
    analysis_custom_pathway_count = if (is.null(custom_pathways_list)) {
      0L
    } else {
      length(custom_pathways_list)
    },
    analysis_select_by_rank = select_by_rank,
    analysis_select_top_percentage_of_genes = select_top_percentage_of_genes,
    analysis_select_top_genes = select_top_genes,
    analysis_significance_threshold = significance_threshold,
    analysis_fold_change_threshold = fold_change_threshold,
    analysis_update_genes = update_genes,
    analysis_use_built_in_gene_universe = use_built_in_gene_universe,
    analysis_minimum_number_of_deg_genes = minimum_number_of_deg_genes,
    analysis_minimum_pathway_hit_count = minimum_pathway_hit_count,
    analysis_pathway_size_limit = pathway_size_limit,
    analysis_p_value_limit = p_value_limit,
    analysis_use_fdr_for_significance = use_fdr_for_significance,
    analysis_top_pathways = top_pathways,
    analysis_number_of_significant_events = number_of_significant_events,
    analysis_maximum_pathways_to_plot = maximum_pathways_to_plot,
    analysis_x_axis_title_font_size = x_axis_title_font_size,
    analysis_y_axis_title_font_size = y_axis_title_font_size,
    analysis_x_axis_tick_font_size = x_axis_tick_font_size,
    analysis_export_plot_file = collapse_for_provenance(export_plot_file),
    analysis_export_results_file = collapse_for_provenance(export_results_file)
  )

  dynamicFontsize <-
    function(
      n.genes,
      n.breakes = c(0, 20, 55, Inf),
      decrease.rates = c(0.1, 0.2, 0.3),
      min.fontsize = 6,
      max.fontsize = 20
    ) {
      decrease <-
        cut(n.genes, breaks = n.breakes, labels = decrease.rates, right = FALSE)
      decrease <- as.numeric(as.character(decrease))
      fontsize <- max.fontsize / (n.genes^decrease)
      round(max(min(fontsize, max.fontsize), min.fontsize))
    }

  updategenenames <- function(genes, species, preserve_names = TRUE) {
    genes <- unique(as.character(genes))
    genes <- genes[!is.na(genes) & nzchar(genes)]

    if (species == "human") {
      new_genes <- updategenes(genes, trust = 1)
      if (preserve_names) {
        names(new_genes) <- genes
      }
    } else if (preserve_names) {
      new_genes <- sapply(genes, function(x) o2o(x, species, "human")[1])
      new_genes <- new_genes[!is.na(new_genes) & nzchar(new_genes)]
    } else {
      new_genes <- o2o(genes, species, "human")
      new_genes <- unique(as.character(new_genes))
      new_genes <- new_genes[!is.na(new_genes) & nzchar(new_genes)]
    }

    return(new_genes)
  }

  restore_original_genes <- function(l2pout, genes_column, gene_name_map) {
    reverse_gene_map <- setNames(names(gene_name_map), unname(gene_name_map))
    pathway_genes <- strsplit(l2pout[[genes_column]], " ", fixed = TRUE)
    vapply(pathway_genes, function(genes) {
      original_genes <- reverse_gene_map[genes]
      missing_original <- is.na(original_genes)
      original_genes[missing_original] <- genes[missing_original]
      paste(unname(original_genes), collapse = " ")
    }, character(1))
  }

  align_custom_pathways_to_gene_map <- function(pathway_list, gene_name_map) {
    lapply(pathway_list, function(pathway_entry) {
      pathway_entry <- as.character(pathway_entry)
      if (length(pathway_entry) <= 2) {
        return(pathway_entry)
      }

      pathway_genes <- pathway_entry[-c(1, 2)]
      mapped_genes <- gene_name_map[pathway_genes]
      mapped_genes <- ifelse(
        is.na(mapped_genes) | !nzchar(mapped_genes),
        pathway_genes,
        mapped_genes
      )
      mapped_genes <- unique(as.character(mapped_genes))
      mapped_genes <- mapped_genes[!is.na(mapped_genes) & nzchar(mapped_genes)]

      c(pathway_entry[1:2], mapped_genes)
    })
  }

  run_l2p <- function(
    genes_to_include,
    update,
    gene_name_map,
    gene_universe_local
  ) {
    genes_to_include <- as.vector(unique(unlist(genes_to_include)))

    # Update gene names
    if (update) {
      genes_to_include <- gene_name_map[genes_to_include]
      genes_to_include <- as.character(genes_to_include)
      genes_to_include <- genes_to_include[
        !is.na(genes_to_include) & nzchar(genes_to_include)
      ]
    }
    if (!is.null(custom_pathways_list)) {
      if (use_built_in_gene_universe == TRUE) {
        x <- l2p(
          genes_to_include,
          categories = collections_to_include,
          custompathways = custom_pathways_list
        )
        print("Using custom pathways with built-in gene universe.")
      } else {
        x <- l2p(
          genes_to_include,
          categories = collections_to_include,
          custompathways = custom_pathways_list,
          universe = gene_universe_local
        )
      }
    } else if (use_built_in_gene_universe == TRUE) {
      x <- l2p(genes_to_include, categories = collections_to_include)
      print("Using built-in gene universe.")
    } else {
      x <- l2p(
        genes_to_include,
        categories = collections_to_include,
        universe = gene_universe_local
      )
    }

    genes_column <- intersect(
      c("allgenesinpw", "genesinpathway", "genes_in_pathway", "genes", "hits"),
      colnames(x)
    )[1]
    if (is.na(genes_column) || is.null(genes_column)) {
      stop(
        paste0(
          "ERROR: L2P output does not contain a recognizable ",
          "genes-in-pathway column."
        )
      )
    }

    x$orig_genes <- restore_original_genes(x, genes_column, gene_name_map)

    if (genes_column != "allgenesinpw") {
      x$allgenesinpw <- x[[genes_column]]
    }
    return(x)
  }

  select_top_paths <- function(l2p_tbl) {
    filtered <- l2p_tbl %>%
      dplyr::filter(number_hits > minimum_pathway_hit_count)

    if (use_fdr_for_significance) {
      filtered <- filtered %>%
        dplyr::filter(fdr < p_value_limit) %>%
        dplyr::arrange(fdr, pval)
    } else {
      filtered <- filtered %>%
        dplyr::filter(pval < p_value_limit) %>%
        dplyr::arrange(pval, fdr)
    }

    filtered %>%
      head(top_pathways) %>%
      dplyr::select(pathway_name)
  }

  rank_pathways_for_plot <- function(pathall_tbl) {
    significance_column <- if (use_fdr_for_significance) {
      "fdr"
    } else {
      "pval"
    }

    pathway_names <- unique(pathall_tbl$pathway_name)
    pathway_rank <- lapply(pathway_names, function(pathway_name) {
      pathway_rows <- pathall_tbl[pathall_tbl$pathway_name == pathway_name, ]
      significance_values <- pathway_rows[[significance_column]]
      significance_values <- significance_values[
        !is.na(significance_values) & significance_values > 0
      ]
      p_values <- pathway_rows$pval
      p_values <- p_values[!is.na(p_values) & p_values > 0]
      fdr_values <- pathway_rows$fdr
      fdr_values <- fdr_values[!is.na(fdr_values) & fdr_values > 0]

      data.frame(
        pathway_name = pathway_name,
        best_significance = if (length(significance_values)) {
          min(significance_values)
        } else {
          Inf
        },
        best_pval = if (length(p_values)) min(p_values) else Inf,
        best_fdr = if (length(fdr_values)) min(fdr_values) else Inf,
        max_abs_enrichment = max(
          abs(pathway_rows$enrichment_score),
          na.rm = TRUE
        ),
        stringsAsFactors = FALSE
      )
    })

    pathway_rank <- dplyr::bind_rows(pathway_rank)
    pathway_rank$max_abs_enrichment[
      !is.finite(pathway_rank$max_abs_enrichment)
    ] <- 0

    pathway_rank %>%
      dplyr::arrange(
        best_significance,
        best_pval,
        best_fdr,
        dplyr::desc(max_abs_enrichment),
        pathway_name
      ) %>%
      dplyr::pull(pathway_name)
  }

  ## --------------- ##
  ## Main Code Block ##
  ## --------------- ##

  genelists <- list()
  lists <- list()

  if (select_by_rank == TRUE) {
    compnum <- length(t_statistic_columns)
    groups <- gsub("_tstat", "", t_statistic_columns)
    for (i in 1:compnum) {
      deg_table %>%
        dplyr::select(
          .data[[gene_names_column]],
          .data[[t_statistic_columns[i]]]
        ) -> genesmat
      if (select_top_percentage_of_genes == TRUE) {
        numselect <- ceiling(0.1 * dim(deg_table)[1])
      } else {
        numselect <- select_top_genes
      }
      genesmat %>%
        dplyr::filter(!is.na(.data[[t_statistic_columns[i]]])) %>%
        dplyr::arrange(desc(.data[[t_statistic_columns[i]]])) -> genesmat
      genesmat %>%
        head(numselect) %>%
        pull(.data[[gene_names_column]]) -> lists[[1]]
      genesmat %>%
        dplyr::filter(!is.na(.data[[t_statistic_columns[i]]])) %>%
        dplyr::arrange(.data[[t_statistic_columns[i]]]) -> genesmat
      genesmat %>%
        head(numselect) %>%
        pull(.data[[gene_names_column]]) -> lists[[2]]
      genelists[[i]] <- list(lists[[1]], lists[[2]])
    }
  } else {
    compnum <- length(fold_change_columns)
    if (sum(is_log_fold_change_column(fold_change_columns)) == compnum) {
      groups <- gsub(
        "_logFC|_log2FC|avg_logFC_|avg_log2FC_",
        "",
        fold_change_columns
      )
      for (i in 1:compnum) {
        deg_table %>%
          dplyr::select(
            .data[[gene_names_column]],
            .data[[fold_change_columns[i]]],
            .data[[significance_columns[i]]]
          ) -> genesmat
        logFC_threshold <- log2(fold_change_threshold) # Upregulated genes
        genesmat %>%
          dplyr::arrange(.data[[significance_columns[i]]]) %>%
          dplyr::filter(
            .data[[significance_columns[i]]] <= significance_threshold &
              .data[[fold_change_columns[i]]] >= logFC_threshold
          ) %>%
          pull(.data[[gene_names_column]]) -> lists[[1]]
        logFC_threshold <- -1 * log2(fold_change_threshold)
        # Downregulated genes
        genesmat %>%
          dplyr::arrange(.data[[significance_columns[i]]]) %>%
          dplyr::filter(
            .data[[significance_columns[i]]] <= significance_threshold &
              .data[[fold_change_columns[i]]] <= logFC_threshold
          ) %>%
          pull(.data[[gene_names_column]]) -> lists[[2]]
        genelists[[i]] <- list(lists[[1]], lists[[2]])
      }
    } else {
      groups <- gsub("_FC", "", fold_change_columns)
      for (i in 1:compnum) {
        deg_table %>%
          dplyr::select(
            .data[[gene_names_column]],
            .data[[fold_change_columns[i]]],
            .data[[significance_columns[i]]]
          ) -> genesmat
        genesmat %>%
          dplyr::arrange(.data[[significance_columns[i]]]) %>%
          dplyr::filter(
            .data[[significance_columns[i]]] <= significance_threshold &
              .data[[fold_change_columns[i]]] >= fold_change_threshold
          ) %>%
          pull(.data[[gene_names_column]]) -> lists[[1]]
        genesmat %>%
          dplyr::arrange(.data[[significance_columns[i]]]) %>%
          dplyr::filter(
            .data[[significance_columns[i]]] <= significance_threshold &
              .data[[fold_change_columns[i]]] <= -1 * fold_change_threshold
          ) %>%
          pull(.data[[gene_names_column]]) -> lists[[2]]
        genelists[[i]] <- list(lists[[1]], lists[[2]])
      }
    }
  }

  names(genelists) <- groups

  # Error messaging for low number of genes in genelist:
  genelengths <- lapply(genelists, function(x) lapply(x, length))
  genelistnums <- unlist(lapply(genelengths, function(x) {
    lapply(x, function(x) x[1])
  }))
  names(genelistnums) <- gsub("1$", "_upregulated", names(genelistnums))
  names(genelistnums) <- gsub("2$", "_downregulated", names(genelistnums))
  lowgenenums <- names(genelistnums)[
    genelistnums < minimum_number_of_deg_genes
  ]
  if (sum(genelistnums < minimum_number_of_deg_genes) > 0) {
    warning(sprintf(
      paste0(
        "The size of these genelists are below a desired size ",
        "threshold of %g: Try loosening the criteria for p-values ",
        "up to 0.15 and/or fold change to 1.2"
      ),
      minimum_number_of_deg_genes
    ))
    print(lowgenenums)
  }

  reg.table <- list()
  for (i in 1:length(genelists)) {
    genesize <- lapply(genelists[[i]], function(x) length(x))
    lastgene <- lapply(genelists[[i]], function(x) tail(x, 1))
    FCcol <- fold_change_columns[i]
    pvalcol <- significance_columns[i]
    reporting_columns <- unique(c(gene_names_column, FCcol, pvalcol))
    reporting_columns <- reporting_columns[
      !is.na(reporting_columns) &
        reporting_columns %in% colnames(deg_table)
    ]

    deg_table %>%
      dplyr::select(dplyr::all_of(reporting_columns)) %>%
      mutate(Group = names(genelists)[i]) %>%
      mutate(Direction = "Upregulated") %>%
      mutate(Listsize = genesize[[1]]) %>%
      dplyr::filter(.data[[gene_names_column]] == lastgene[1]) -> upreggene
    deg_table %>%
      dplyr::select(dplyr::all_of(reporting_columns)) %>%
      mutate(Group = names(genelists)[i]) %>%
      mutate(Direction = "Downregulated") %>%
      mutate(Listsize = genesize[[2]]) %>%
      dplyr::filter(.data[[gene_names_column]] == lastgene[2]) -> downreggene
    reg.table[[i]] <- rbind(upreggene, downreggene)
    colnames(reg.table[[i]]) <- c(
      "Last_Gene_in_list",
      "FC",
      "pval or adjpval",
      "Group",
      "Direction",
      "Listsize"
    )
  }

  combined_table <- bind_rows(reg.table)
  cat("Check for significance of selected genelists:\n\n")
  print(combined_table)
  gene_universe_orig <- unique(as.character(deg_table[[gene_names_column]]))
  gene_universe_orig <- gene_universe_orig[
    !is.na(gene_universe_orig) & nzchar(gene_universe_orig)
  ]
  selected_gene_universe <- unique(as.character(unlist(
    genelists,
    use.names = FALSE
  )))
  selected_gene_universe <- selected_gene_universe[
    !is.na(selected_gene_universe) & nzchar(selected_gene_universe)
  ]

  # Set up gene universe and new gene name lookup table:
  if (update_genes == TRUE) {
    if (species == "human") {
      new_gene_names <- updategenenames(
        selected_gene_universe,
        species,
        preserve_names = TRUE
      )
      gene_universe <- if (use_built_in_gene_universe == TRUE) {
        NULL
      } else {
        updategenenames(gene_universe_orig, species, preserve_names = FALSE)
      }
    } else if (use_built_in_gene_universe == TRUE) {
      new_gene_names <- updategenenames(
        selected_gene_universe,
        species,
        preserve_names = TRUE
      )
      gene_universe <- NULL
    } else {
      new_gene_names <- updategenenames(
        gene_universe_orig,
        species,
        preserve_names = TRUE
      )
      gene_universe <- as.character(new_gene_names)
      gene_universe <- gene_universe[
        !is.na(gene_universe) & nzchar(gene_universe)
      ]
    }
  } else {
    gene_universe <- if (use_built_in_gene_universe == TRUE) {
      NULL
    } else {
      gene_universe_orig
    }
    new_gene_names <- setNames(selected_gene_universe, selected_gene_universe)
  }

  if (!is.null(custom_pathways_list) && update_genes == TRUE) {
    custom_pathways_list <- align_custom_pathways_to_gene_map(
      custom_pathways_list,
      new_gene_names
    )
  }

  l2presults <- list()
  for (i in 1:length(genelists)) {
    l2presults[[i]] <- lapply(genelists[[i]], function(x) {
      run_l2p(
        x,
        update = update_genes,
        gene_name_map = new_gene_names,
        gene_universe_local = gene_universe
      )
    })
  }

  # Print out genes in genelist that are updated:
  updated_genes_idx <- sapply(
    seq_along(new_gene_names),
    function(i) names(new_gene_names)[i] != new_gene_names[[i]]
  )
  updated_genes <- new_gene_names[updated_genes_idx]
  updated_genes_num <- sum(updated_genes_idx)
  print(paste("Number of updated genes:", updated_genes_num))
  cat("Original:Updated\n")
  updated_gene_pairs <- vapply(seq_along(updated_genes), function(i) {
    paste0(names(updated_genes)[i], ":", updated_genes[i])
  }, character(1))
  print(utils::head(updated_gene_pairs, 10L))
  if (length(updated_gene_pairs) > 10L) {
    cat(sprintf("... (%d more updated genes)\n", length(updated_gene_pairs) - 10L))
  }

  # Error messaging for zero significant pathway results:
  names(l2presults) <- groups
  l2plength <- lapply(l2presults, function(x) lapply(x, dim))
  l2poutpaths <- unlist(lapply(l2plength, function(x) {
    lapply(x, function(x) x[1])
  }))
  names(l2poutpaths) <- gsub("1$", "_upregulated", names(l2poutpaths))
  names(l2poutpaths) <- gsub("2$", "_downregulated", names(l2poutpaths))
  nopaths <- names(l2poutpaths)[l2poutpaths == 0]

  if (sum(l2poutpaths == 0) > 0) {
    stop(sprintf(
      paste0(
        "ERROR: At least one of the l2p results shows no ",
        "significant pathways, probably because of too few genes ",
        "in genelist: %s"
      ),
      nopaths
    ))
  }

  colname <- unlist(names(genelists))
  pathlist <- list()

  for (i in 1:length(l2presults)) {
    paths <- lapply(l2presults[[i]], select_top_paths)
    pathlist[[i]] <- unlist(lapply(paths, function(x) {
      unlist(x, use.names = FALSE)
    }))
  }

  path.all <- data.frame(pathwayname = unlist(pathlist))

  path.all %>%
    group_by(pathwayname) %>%
    tally() %>%
    arrange(dplyr::desc(n)) %>%
    dplyr::filter(n >= number_of_significant_events) %>%
    dplyr::pull(pathwayname) -> path.select

  if (length(path.select) == 0) {
    stop(
      paste0(
        "ERROR: No pathways passed selection thresholds. Try ",
        "relaxing pathway filters (p/FDR, top pathways, hit count, ",
        "or significant event count)."
      )
    )
  }

  build_pathall <- function(pathway_names) {
    pathmerge <- list()
    for (i in 1:length(l2presults)) {
      pathselect <- lapply(l2presults[[i]], function(x) {
        dplyr::filter(x, pathway_name %in% pathway_names) %>%
          mutate(total = number_hits + number_misses) %>%
          dplyr::distinct(pathway_name, .keep_all = TRUE) %>%
          dplyr::filter(total < pathway_size_limit) %>%
          dplyr::select(
            pathway_name,
            pathway_id,
            category,
            enrichment_score,
            number_hits,
            total,
            percent_gene_hits_per_pathway,
            pval,
            fdr,
            allgenesinpw,
            orig_genes
          )
      })

      pathselect.merge <- merge(
        pathselect[[1]],
        pathselect[[2]],
        by = "pathway_name",
        all = TRUE
      ) %>%
        dplyr::mutate_if(is.numeric, tidyr::replace_na, 0) %>%
        dplyr::mutate(
          net_enrichment_score = enrichment_score.x - enrichment_score.y
        ) %>%
        dplyr::mutate(net_number_hits = number_hits.x - number_hits.y) %>%
        dplyr::mutate(
          enrichment_score = case_when(
            net_enrichment_score > 0 ~ enrichment_score.x,
            net_enrichment_score < 0 ~ -1 * enrichment_score.y,
            TRUE ~ 0
          )
        ) %>%
        dplyr::mutate(
          categ = case_when(
            net_enrichment_score > 0 ~ category.x,
            net_enrichment_score < 0 ~ category.y,
            TRUE ~ "NA"
          )
        ) %>%
        dplyr::mutate(
          number_hits = case_when(
            net_enrichment_score > 0 ~ number_hits.x,
            net_enrichment_score < 0 ~ number_hits.y,
            TRUE ~ as.integer(0)
          )
        ) %>%
        dplyr::mutate(
          percent_gene_hits_per_pathway = case_when(
            net_enrichment_score > 0 ~ percent_gene_hits_per_pathway.x,
            net_enrichment_score < 0 ~ -1 * percent_gene_hits_per_pathway.y,
            TRUE ~ 0
          )
        ) %>%
        dplyr::mutate(
          pval = case_when(
            net_enrichment_score > 0 ~ pval.x,
            net_enrichment_score < 0 ~ pval.y,
            TRUE ~ 0
          )
        ) %>%
        dplyr::mutate(
          fdr = case_when(
            net_enrichment_score > 0 ~ fdr.x,
            net_enrichment_score < 0 ~ fdr.y,
            TRUE ~ 0
          )
        ) %>%
        dplyr::mutate(
          genes = case_when(
            net_enrichment_score > 0 ~ allgenesinpw.x,
            net_enrichment_score < 0 ~ allgenesinpw.y
          )
        ) %>%
        dplyr::mutate(
          orig_genes = case_when(
            net_enrichment_score > 0 ~ orig_genes.x,
            net_enrichment_score < 0 ~ orig_genes.y
          )
        ) %>%
        dplyr::mutate(
          pathway_id = case_when(
            net_enrichment_score > 0 ~ pathway_id.x,
            net_enrichment_score < 0 ~ pathway_id.y
          )
        ) %>%
        dplyr::mutate(group = colname[i])
      pathmerge[[i]] <- pathselect.merge
    }

    bind_rows(pathmerge) %>%
      select(
        pathway_name,
        pathway_id,
        categ,
        number_hits,
        percent_gene_hits_per_pathway,
        enrichment_score,
        pval,
        fdr,
        net_number_hits,
        net_enrichment_score,
        genes,
        orig_genes,
        group
      ) %>%
      arrange(pval)
  }

  pathall <- build_pathall(path.select)

  if (select_by_rank == TRUE) {
    grouplevel <- gsub("_tstat", "", t_statistic_columns)
  } else {
    grouplevel <- gsub(
      "_FC|_logFC|_log2FC|avg_logFC_|avg_log2FC_",
      "",
      fold_change_columns
    )
  }
  pathall$group <- factor(pathall$group, levels = grouplevel)
  pathall %>% dplyr::filter(!pathway_name %in% pathways_to_remove) -> pathall

  pathall_output <- pathall
  pathall_plot <- pathall_output

  ranked_pathways_for_plot <- rank_pathways_for_plot(pathall_plot)
  if (
    is.finite(maximum_pathways_to_plot) &&
      length(ranked_pathways_for_plot) > maximum_pathways_to_plot
  ) {
    pathways_to_keep <- utils::head(
      ranked_pathways_for_plot,
      maximum_pathways_to_plot
    )
    pathall_plot <- pathall_plot %>%
      dplyr::filter(.data[["pathway_name"]] %in% pathways_to_keep)
    cat(sprintf(
      paste0(
        "\nBubble plot limited to the %d most significant pathway rows ",
        "by %s.\n"
      ),
      maximum_pathways_to_plot,
      if (use_fdr_for_significance) "FDR" else "p-value"
    ))
  }

  if (length(rename_groups) > 0) {
    names(rename_groups) <- grouplevel
    pathall_output$group <- rename_groups[pathall_output$group]
    pathall_output$group <- factor(pathall_output$group, levels = rename_groups)
    pathall_plot$group <- rename_groups[pathall_plot$group]
    pathall_plot$group <- factor(pathall_plot$group, levels = rename_groups)
  }

  pathall2 <- pathall_plot

  if (use_dynamic_pathway_font_size) {
    npathways <- length(unique(pathall2$pathway_name))
    fsize <- dynamicFontsize(npathways)
    cat(sprintf("\nPathway Axis Label Font Size set to %g\n\n", fsize))
    pathway_axis_label_font_size <- fsize
  }

  effective_pathway_axis_label_max_length <- dynamic_wrap_length(
    pathway_axis_label_max_length,
    pathway_axis_label_font_size
  )
  if (effective_pathway_axis_label_max_length != pathway_axis_label_max_length) {
    cat(sprintf(
      paste0(
        "\nPathway Axis Label Max Length set to %d after font-size ",
        "adjustment\n\n"
      ),
      effective_pathway_axis_label_max_length
    ))
  }

  pathall2$pathway_name2 <- str_to_upper(pathall2$pathway_name)
  pathall2$pathway_name2 <- gsub("_", " ", pathall2$pathway_name2)
  pathall2 %>%
    dplyr::mutate(
      pathway_name2 = stringr::str_wrap(
        pathway_name2,
        effective_pathway_axis_label_max_length
      )
    ) -> pathall2

  if (!is.null(custom_pathway_order) && length(custom_pathway_order) > 0) {
    custom_pathway_order <- unique(custom_pathway_order)
    pathall2 <- pathall2 %>%
      dplyr::filter(pathway_name2 %in% custom_pathway_order)
    if (nrow(pathall2) == 0) {
      stop(
        paste0(
          "ERROR: No pathways remain after applying ",
          "`custom_pathway_order`. Check names and casing."
        )
      )
    }
    pathall2$pathway_name2 <- factor(
      pathall2$pathway_name2,
      levels = custom_pathway_order
    )
  }

  pathway_axis_breaks <- unique(as.character(pathall2$pathway_name2))
  pathway_axis_tick_label_map <- stats::setNames(
    pathway_axis_breaks,
    pathway_axis_breaks
  )
  if (!is.null(y_axis_tick_labels)) {
    y_label_names <- names(y_axis_tick_labels)
    y_axis_tick_labels <- stringr::str_wrap(
      y_axis_tick_labels,
      effective_pathway_axis_label_max_length
    )
    if (!is.null(y_label_names)) {
      names(y_axis_tick_labels) <- y_label_names
    }

    if (!is.null(y_label_names) && any(nzchar(y_label_names))) {
      pathway_label_lookup <- unique(data.frame(
        pathway_name = as.character(pathall2$pathway_name),
        pathway_name2 = as.character(pathall2$pathway_name2),
        unwrapped_pathway_name2 = stringr::str_to_upper(gsub(
          "_",
          " ",
          as.character(pathall2$pathway_name)
        )),
        stringsAsFactors = FALSE
      ))

      for (label_name in y_label_names) {
        matching_labels <- pathway_label_lookup$pathway_name2[
          pathway_label_lookup$pathway_name == label_name |
            pathway_label_lookup$pathway_name2 == label_name |
            pathway_label_lookup$unwrapped_pathway_name2 == label_name
        ]

        if (length(matching_labels) == 0) {
          stop(sprintf(
            paste0(
              "ERROR: `y_axis_tick_labels` name `%s` did not match a raw ",
              "pathway name or displayed pathway label."
            ),
            label_name
          ))
        }

        pathway_axis_tick_label_map[unique(matching_labels)] <-
          y_axis_tick_labels[[label_name]]
      }
    } else {
      if (length(y_axis_tick_labels) != length(pathway_axis_breaks)) {
        stop(sprintf(
          paste0(
            "ERROR: Unnamed `y_axis_tick_labels` must have one label per ",
            "displayed pathway row (%d labels expected)."
          ),
          length(pathway_axis_breaks)
        ))
      }
      pathway_axis_tick_label_map[pathway_axis_breaks] <-
        unname(y_axis_tick_labels)
    }
  }
  pathway_axis_tick_label_lookup <- function(values) {
    values <- as.character(values)
    labels <- pathway_axis_tick_label_map[values]
    missing_labels <- is.na(labels)
    labels[missing_labels] <- values[missing_labels]
    unname(labels)
  }

  ## addon
  significant_label <- if (use_fdr_for_significance) {
    sprintf("fdr<%g", p_value_limit)
  } else {
    sprintf("pval<%g", p_value_limit)
  }
  nonsignificant_label <- if (use_fdr_for_significance) {
    sprintf("fdr>%g", p_value_limit)
  } else {
    sprintf("pval>%g", p_value_limit)
  }

  if (use_fdr_for_significance) {
    pathall2 <- pathall2 %>%
      mutate(
        Significance = ifelse(
          fdr > p_value_limit,
          nonsignificant_label,
          significant_label
        )
      )
  } else {
    pathall2 <- pathall2 %>%
      mutate(
        Significance = ifelse(
          pval > p_value_limit,
          nonsignificant_label,
          significant_label
        )
      )
  }
  significance_levels <- c(significant_label, nonsignificant_label)
  pathall2$Significance <- factor(
    pathall2$Significance,
    levels = significance_levels
  )
  significance_shapes <- stats::setNames(c(19, 4), significance_levels)

  maxabscore <- as.numeric(
    quantile(
      abs(pathall2[[plot_bubble_color]]),
      probs = plot_bubble_max_color,
      na.rm = TRUE
    )
  )
  if (!is.finite(maxabscore) || maxabscore <= 0) {
    maxabscore <- 1
  }
  maxscore <- maxabscore
  minscore <- -1 * maxabscore

  col1 <- sym(plot_bubble_size)
  col2 <- sym(plot_bubble_color)

  group_levels <- levels(pathall2$group)
  effective_column_spacing <- column_spacing

  x_positions <- seq_along(group_levels)
  x_positions <- (x_positions - 1) * effective_column_spacing + 1
  position_lookup <- setNames(x_positions, group_levels)
  pathall2$group_x <- position_lookup[as.character(pathall2$group)]
  group_axis_labels <- group_levels
  if (!is.null(x_axis_tick_labels)) {
    if (length(x_axis_tick_labels) != length(group_levels)) {
      stop(sprintf(
        paste0(
          "ERROR: `x_axis_tick_labels` must have one label per plotted ",
          "group (%d labels expected)."
        ),
        length(group_levels)
      ))
    }
    group_axis_labels <- unname(x_axis_tick_labels)
  }
  legend_key_data <- data.frame(
    group_x = rep(x_positions[[1]], length(significance_levels)),
    pathway_name2 = rep(
      as.character(pathall2$pathway_name2[[1]]),
      length(significance_levels)
    ),
    Significance = factor(significance_levels, levels = significance_levels)
  )

  x_span <- if (length(x_positions) > 1) diff(range(x_positions)) else 1
  side_x_pad <- max(0.50, 0.18 * x_span)

  ## addson ggplot2
  if (plot_bubble_size %in% c("pval", "fdr")) {
    g <- ggplot(
      pathall2,
      aes(
        x = group_x,
        y = reorder(pathway_name2, enrichment_score),
        size = -log10(!!col1),
        colour = !!col2
      )
    ) +
      geom_point(aes(shape = Significance)) +
      geom_point(
        data = legend_key_data,
        aes(x = group_x, y = pathway_name2, shape = Significance),
        inherit.aes = FALSE,
        size = 3,
        colour = "black",
        alpha = 0,
        show.legend = TRUE
      ) +
      scale_shape_manual(
        values = significance_shapes,
        limits = significance_levels,
        breaks = significance_levels,
        drop = FALSE
      ) +
      guides(
        shape = guide_legend(
          override.aes = list(size = 3, colour = "black", alpha = 1)
        )
      ) +
      theme_bw() +
      theme(
        panel.grid.major = element_blank(),
        panel.grid.minor = element_blank()
      ) +
      ylab(y_axis_title) +
      xlab(x_axis_title) +
      scale_colour_gradient2(
        limits = c(minscore, maxscore),
        midpoint = 0,
        low = "darkblue",
        mid = "grey",
        high = "tomato",
        oob = scales::squish
      ) +
      scale_size(range = c(0, 10)) +
      scale_x_continuous(
        breaks = x_positions,
        labels = group_axis_labels,
        expand = expansion(add = c(side_x_pad, side_x_pad))
      ) +
      scale_y_discrete(
        labels = pathway_axis_tick_label_lookup,
        expand = c(0.05, 0.05)
      ) +
      theme(
        axis.text.x = element_text(
          angle = 90,
          hjust = 1,
          colour = "black",
          size = x_axis_tick_font_size
        ),
        axis.title.x = element_text(
          size = x_axis_title_font_size,
          margin = margin(t = 8)
        ),
        axis.title.y = element_text(
          size = y_axis_title_font_size,
          margin = margin(r = 8)
        ),
        axis.text.y = element_text(
          colour = "black",
          size = pathway_axis_label_font_size,
          margin = margin(r = 10)
        ),
        plot.margin = margin(t = 8, r = 12, b = 8, l = 12)
      )
  } else {
    g <- ggplot(
      pathall2,
      aes(
        x = group_x,
        y = reorder(pathway_name2, enrichment_score),
        size = !!col1,
        colour = !!col2
      )
    ) +
      geom_point(aes(shape = Significance)) +
      geom_point(
        data = legend_key_data,
        aes(x = group_x, y = pathway_name2, shape = Significance),
        inherit.aes = FALSE,
        size = 3,
        colour = "black",
        alpha = 0,
        show.legend = TRUE
      ) +
      scale_shape_manual(
        values = significance_shapes,
        limits = significance_levels,
        breaks = significance_levels,
        drop = FALSE
      ) +
      guides(
        shape = guide_legend(
          override.aes = list(size = 3, colour = "black", alpha = 1)
        )
      ) +
      theme_bw() +
      theme(
        panel.grid.major = element_blank(),
        panel.grid.minor = element_blank()
      ) +
      ylab(y_axis_title) +
      xlab(x_axis_title) +
      scale_colour_gradient2(
        limits = c(minscore, maxscore),
        midpoint = 0,
        low = "darkblue",
        mid = "grey",
        high = "tomato",
        oob = scales::squish
      ) +
      scale_size(range = c(0, 10)) +
      scale_x_continuous(
        breaks = x_positions,
        labels = group_axis_labels,
        expand = expansion(add = c(side_x_pad, side_x_pad))
      ) +
      scale_y_discrete(
        labels = pathway_axis_tick_label_lookup,
        expand = c(0.05, 0.05)
      ) +
      theme(
        axis.text.x = element_text(
          angle = 90,
          hjust = 1,
          colour = "black",
          size = x_axis_tick_font_size
        ),
        axis.title.x = element_text(
          size = x_axis_title_font_size,
          margin = margin(t = 8)
        ),
        axis.title.y = element_text(
          size = y_axis_title_font_size,
          margin = margin(r = 8)
        ),
        axis.text.y = element_text(
          colour = "black",
          size = pathway_axis_label_font_size,
          margin = margin(r = 10)
        ),
        plot.margin = margin(t = 8, r = 12, b = 8, l = 12)
      )
  }

  if (!is.null(vertical_line_placement)) {
    vertical_line_placement <- as.numeric(vertical_line_placement)
    g <- g +
      geom_vline(
        xintercept = 1 +
          (vertical_line_placement - 0.5) * effective_column_spacing,
        linetype = "dashed"
      )
  }
  if (use_panel_plot) {
    g <- g + facet_wrap(~categ, nrow = 1)
  }

  if (interactive()) {
    print(g)
  }

  if (!is.null(export_plot_file) && nzchar(export_plot_file)) {
    ggplot2::ggsave(
      filename = export_plot_file,
      plot = g,
      width = export_plot_width,
      height = export_plot_height,
      dpi = 600
    )
  }

  if (!update_genes) {
    pathall_output <- pathall_output %>%
      dplyr::select(-orig_genes)
  }

  if (!is.null(export_results_file) && nzchar(export_results_file)) {
    utils::write.csv(pathall_output, export_results_file, row.names = FALSE)
    final_analysis_provenance <- c(
      analysis_provenance,
      list(
        analysis_input_gene_count = length(gene_universe_orig),
        analysis_selected_gene_count = length(selected_gene_universe),
        analysis_selected_gene_counts_by_list = paste(
          names(genelistnums),
          genelistnums,
          sep = "=",
          collapse = ";"
        ),
        analysis_gene_universe_count = if (is.null(gene_universe)) {
          "built-in"
        } else {
          length(gene_universe)
        },
        analysis_result_row_count = nrow(pathall_output)
      )
    )
    provenance_file <- write_provenance_csv(
      final_analysis_provenance,
      export_results_file
    )
    cat(sprintf("\nSaved provenance to %s\n", provenance_file))
  }

  return(pathall_output)
}
