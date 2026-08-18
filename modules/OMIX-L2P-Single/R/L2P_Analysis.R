#' L2P Analysis for Single Comparisons [CCBR] [scRNA-seq] [Bulk]
#'
#' @description
#' Over-representation Analysis. Given a genelist, finds over-represented
#' pathways with Fisher's exact test, using the l2p package. Requires as input a
#' dataset with differential expression of genes (DEG). Final Potomac Compatible
#' Version: v97. Final Sugarloaf V1: v125. View Documentation
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
#' @param comparison
#' Character. Optional comparison ID such as \code{B-A}. When supplied, missing
#' column selections are derived as \code{B-A_tstat}, \code{B-A_pval}, and
#' \code{B-A_FC}. Explicit column parameters override derived columns.
#' @param t_statistic_column
#' Character. If "Select By Rank" (above) is TRUE, set a single column used to
#' select the genes of interest. This is usually the column containing
#' t-statistic, or another signed ranking statistic. This is the singular
#' version of the L2P Multi \code{t_statistic_columns} parameter.
#' @param significance_column
#' Character. If "Select By Rank" is FALSE, then choose a single column
#' containing p-values or adjusted p-values other significance metrics upon
#' which to filter your gene list. You must then also set a "Significance
#' Threshold" (below).
#' @param fold_change_column
#' Character. If "Select By Rank" is FALSE, then set a single fold change or log
#' fold change threshold on which to select genelist. You can select a column
#' that has either "logFC" or "FC" units as part of the column header.
#' @param species
#' Character. One of \code{Human}, \code{Mouse}, \code{Macaque}, \code{Rat},
#' \code{Zebrafish}, \code{Rabbit}, \code{Drosophila}. If other organism than
#' human is selected, gene names are converted to human before running l2p.
#' Default: \code{Human}.
#' @param collections_to_include
#' Character. Pathway or Geneset Sources to Use: GO: http://geneontology.org
#' REACTOME: https://reactome.org/ KEGG: https://www.kegg.jp/ PANTH:
#' http://www.pantherdb.org/ PID: Pathway interaction database BIOCYC:
#' https://biocyc.org/ WikiPathways: https://www.wikipathways.org H: MSigDB
#' Hallmark signature gene sets C1: MSigDB positional gene sets C2: MSigDB
#' curated gene sets C3: MSigDB motif gene sets C4: MSigDB computational gene
#' sets C6: MSigDB oncogenic gene sets C7: MSigDB immunologic gene sets C8:
#' MSigDB cell type signature gene sets Default:
#' \code{c("GO","REACTOME","KEGG")}.
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
#' @param select_top_percentage_of_genes
#' Logical. If "Select By Rank" (above) is TRUE, select top percentage of up
#' and downregulated genes ranked by t-statistic. If TRUE, set at 10%. If
#' FALSE, uses selected number of genes (set below). Default: \code{TRUE}.
#' @param select_top_genes
#' Numeric. If "Select By Rank" is TRUE, and Select Top Percentage of Genes is
#' FALSE, select number of top ranked genes by t-statistic. Set to 500 by
#' default. Default: \code{500}.
#' @param significance_threshold
#' Numeric. Set p-value or adjusted p-value threshold on which to set
#' genelist. Set to 0.05 by default. If genelist has fewer than 100 genes,
#' try raising this value to 0.10 Default: \code{0.05}.
#' @param fold_change_threshold
#' Numeric. Set fold change threshold on which to select genelist. If you have
#' a bulk RNA-seq dataset or single cell RNA-Seq with few DEG genes, we
#' recommend setting this to 1.2 initially. Threshold is in linear units,
#' even if logFC column is selected. Default: \code{1.2}.
#' @param minimum_number_of_deg_genes
#' Numeric. Minimum number of DEG genes to use for enrichment analysis.
#' Default is 50. Ideally should be ~10% of all genes Default: \code{50}.
#' @param number_of_pathways_to_plot
#' Numeric. Number of top pathways (by smallest pval) to display in bubble
#' plot Default: \code{12}.
#' @param pathway_axis_label_max_length
#' Numeric. Set pathway axis label maximum length as shown in Y-axis, set to
#' 50 by default. The effective wrap length is shortened automatically when
#' \code{pathway_axis_label_font_size} is increased. Default: \code{50}.
#' @param plot_top_pathways_up
#' Logical. If TRUE, automatically selects top pathways for the Bubble Plot.
#' If FALSE, user selects pathways (below) to display in plot Default:
#' \code{TRUE}.
#' @param pathways_to_use_up
#' Character vector. Selected Pathways to show in Bubble Plot instead of top
#' pathways
#' @param plot_top_pathways_down
#' Logical. If TRUE, automatically selects top pathways for the Bubble Plot.
#' If FALSE, user selects pathways (below) to display in plot Default:
#' \code{TRUE}.
#' @param pathways_to_use_down
#' Character vector. Selected Pathways to show in Bubble Plot instead of top
#' pathways
#' @param sort_bubble_plot_by
#' Character. One of \code{percent gene hits per pathway}, \code{Fisher's
#' Exact pval}, \code{fdr corrected pval}, \code{enrichment score},
#' \code{number of hits}. Sets the x-axis variable and hence, sort order of
#' pathways in bubble plot. Default ordering is percent hits. Default:
#' \code{percent gene hits per pathway}.
#' @param plot_bubble_size
#' Character. One of \code{number of hits}, \code{percent gene hits per
#' pathway}, \code{enrichment score}, \code{Fisher's Exact pval}, \code{fdr
#' corrected pval}. Select parameter that sets bubble plot size. Default is
#' "number of hits" which is the number of genes found significant in each
#' pathway. Default: \code{number of hits}.
#' @param plot_bubble_color
#' Character. One of \code{Fisher's Exact pval}, \code{fdr corrected pval},
#' \code{percent gene hits per pathway}, \code{number of hits},
#' \code{enrichment score}. Select parameter that sets bubble plot color.
#' Fisher's Exact pval is the default. Default: \code{Fisher's Exact pval}.
#' @param bubble_colors
#' Character. One of \code{blues}, \code{reds}, \code{blue to red}. Choose
#' color gradient. blues (light to dark blue), reds (light to dark red), blue
#' to red Default: \code{blues}.
#' @param pathway_axis_label_font_size
#' Numeric. Pathway labels font size. Also used to scale pathway label
#' wrapping. Default: \code{15}.
#' @param x_axis_title_font_size
#' Numeric. Font size for plot x-axis titles. Default: \code{20}.
#' @param y_axis_title_font_size
#' Numeric. Font size for plot y-axis titles. Default: \code{20}.
#' @param x_axis_tick_font_size
#' Numeric. Font size for plot x-axis tick labels. Default: \code{15}.
#' @param use_fdr_p_values
#' Logical. If FALSE, use Fisher's Exact p-values. If TRUE, use FDR values.
#' Default is FALSE. Default: \code{FALSE}.
#' @param color_for_bar
#' Character. One of \code{Blue}, \code{Green}, \code{Orange}, \code{Grey},
#' \code{Red}, \code{Purple}, \code{GreentoBlue}, \code{OrangetoRed},
#' \code{YellowOrangeRed}. Select color for Bar Plot Default:
#' \code{GreentoBlue}.
#' @param use_built_in_gene_universe
#' Logical. If FALSE, uses all genes in the differential expression analysis
#' as the gene universe. By default, uses l2p's built-in gene universe.
#' Default: \code{FALSE}.
#' @param minimum_pathway_hit_count
#' Numeric. Minimum pathway hit count to consider as significant. Fisher's
#' Exact Test can often result in small sized pathway hits being significant
#' but because gene membership is low, biological relevance of the pathway is
#' difficult to interpret. Default is set to 5. Default: \code{5}.
#' @param p_value_threshold_for_output
#' Numeric. Filter output file to only include significant pathways. Set to
#' pval < 0.05 by default. If all pathways are desired, set to 0. Default:
#' \code{0.05}.
#' @param export_plot_file
#' Character. Optional output file path prefix for saving generated plots with
#' \code{ggplot2::ggsave}. For each run, separate files are written for
#' up/downregulated bar and bubble plots by appending suffixes to this path.
#' Defaults to \code{file.path(getwd(), "l2p_single_v148_plot.png")}. Set to
#' \code{NULL} to disable plot export.
#' @param export_plot_width
#' Numeric. Plot width (in inches) used when saving with
#' \code{ggplot2::ggsave}. Default: \code{12}.
#' @param export_plot_height
#' Numeric. Plot height (in inches) used when saving with
#' \code{ggplot2::ggsave}. Default: \code{12}.
#' @param export_results_file
#' Character. Optional output file path for saving the returned results as CSV.
#' A companion provenance CSV is written with \code{_provenance} appended to
#' the basename. Defaults to
#' \code{file.path(getwd(), "l2p_single_v148_results.csv")}. Set to
#' \code{NULL} to disable results and provenance export.
#'
#' @return A data frame of L2P pathway enrichment results for up- and
#' downregulated gene sets, including pathway name, category, direction,
#' hit counts, enrichment score, p-value, FDR, and gene lists. When results are
#' exported, run provenance is written to a companion \code{_provenance.csv}
#' file.
#'
#' @importFrom dplyr .
#' @importFrom ggplot2 .
#' @importFrom stringr .
#' @importFrom magrittr .
#' @importFrom l2p .
#' @importFrom grid .
#' @export
l2p_single <- function(
  deg_table,
  gene_names_column = NULL,
  t_statistic_column = NULL,
  significance_column = NULL,
  fold_change_column = NULL,
  comparison = NULL,
  species = "Human",
  collections_to_include = c("GO", "REACTOME", "KEGG"),
  custom_pathways = NULL,
  custom_pathway_name_column = "gene_set_name",
  custom_pathway_gene_column = "gene_symbol",
  select_by_rank = TRUE,
  select_top_percentage_of_genes = TRUE,
  select_top_genes = 500,
  significance_threshold = 0.05,
  fold_change_threshold = 1.2,
  minimum_number_of_deg_genes = 50,
  number_of_pathways_to_plot = 12,
  pathway_axis_label_max_length = 50,
  plot_top_pathways_up = TRUE,
  pathways_to_use_up = NULL,
  plot_top_pathways_down = TRUE,
  pathways_to_use_down = c(),
  sort_bubble_plot_by = "percent gene hits per pathway",
  plot_bubble_size = "number of hits",
  plot_bubble_color = "Fisher's Exact pval",
  bubble_colors = "blues",
  pathway_axis_label_font_size = 15,
  x_axis_title_font_size = 20,
  y_axis_title_font_size = 20,
  x_axis_tick_font_size = 15,
  use_fdr_p_values = FALSE,
  color_for_bar = "GreentoBlue",
  use_built_in_gene_universe = FALSE,
  minimum_pathway_hit_count = 5,
  p_value_threshold_for_output = 0.05,
  export_plot_file = file.path(getwd(), "l2p_single_v148_plot.png"),
  export_plot_width = 12,
  export_plot_height = 12,
  export_results_file = file.path(getwd(), "l2p_single_v148_results.csv")
) {
  normalize_species_label <- function(x) {
    species_lookup <- c(
      drosophila = "Drosophila",
      human = "Human",
      macaque = "Macaque",
      mouse = "Mouse",
      rabbit = "Rabbit",
      rat = "Rat",
      zebrafish = "Zebrafish"
    )
    species_key <- tolower(trimws(as.character(x[[1]])))

    if (
      is.null(x) ||
        length(x) == 0 ||
        is.na(x[[1]]) ||
        !nzchar(species_key) ||
        !species_key %in% names(species_lookup)
    ) {
      stop(sprintf(
        "ERROR: `species` must be one of: %s",
        paste(unname(species_lookup), collapse = ", ")
      ))
    }

    unname(species_lookup[[species_key]])
  }

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
      species == "Human" &&
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
      species == "Mouse" &&
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

  optional_scalar <- function(x) {
    is.null(x) ||
      (is.character(x) &&
        length(x) == 1L &&
        !is.na(x) &&
        nzchar(trimws(x)))
  }

  require_scalar <- function(x, arg_name) {
    if (
      !is.character(x) ||
        length(x) != 1L ||
        is.na(x) ||
        !nzchar(trimws(x))
    ) {
      stop(sprintf(
        "ERROR: `%s` must be a single non-empty column name.",
        arg_name
      ))
    }

    trimws(x)
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

  is_log_fold_change_column <- function(x) {
    grepl("logFC|log2FC|avg_log2FC", x)
  }

  build_custom_pathways_list <- function(
    custom_pathways,
    custom_pathway_name_column,
    custom_pathway_gene_column
  ) {
    if (is.null(custom_pathways)) {
      return(NULL)
    }

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

      return(Map(
        function(pathway_name, genes) {
          c(pathway_name, pathway_name, unique(genes))
        },
        names(split_pathways),
        split_pathways
      ))
    }

    if (is.list(custom_pathways)) {
      return(custom_pathways)
    }

    stop(
      paste0(
        "ERROR: `custom_pathways` must be either a data frame or a list ",
        "formatted for `l2p(custompathways = ...)`."
      )
    )
  }

  ## -------------------------------- ##
  ## User-Defined Template Parameters ##
  ## -------------------------------- ##

  # Input validation and setup:
  species <- normalize_species_label(species)
  pathway_axis_label_max_length <- numeric_positive_integer(
    pathway_axis_label_max_length,
    "pathway_axis_label_max_length"
  )
  pathway_axis_label_font_size <- numeric_font_size(
    pathway_axis_label_font_size,
    "pathway_axis_label_font_size"
  )
  x_axis_title_font_size <- numeric_font_size(
    x_axis_title_font_size,
    "x_axis_title_font_size"
  )
  y_axis_title_font_size <- numeric_font_size(
    y_axis_title_font_size,
    "y_axis_title_font_size"
  )
  x_axis_tick_font_size <- numeric_font_size(
    x_axis_tick_font_size,
    "x_axis_tick_font_size"
  )
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

  gene_names_column <- resolve_gene_names_column(deg_table, gene_names_column)
  check_gene_species_case(deg_table, gene_names_column, species)

  if (!optional_scalar(comparison)) {
    stop("ERROR: `comparison` must be a single non-empty value such as `B-A`.")
  }
  if (!optional_scalar(t_statistic_column)) {
    stop("ERROR: `t_statistic_column` must be a single column name.")
  }
  if (!optional_scalar(significance_column)) {
    stop("ERROR: `significance_column` must be a single column name.")
  }
  if (!optional_scalar(fold_change_column)) {
    stop("ERROR: `fold_change_column` must be a single column name.")
  }

  if (!is.null(comparison)) {
    comparison <- trimws(comparison)
    if (is.null(t_statistic_column)) {
      t_statistic_column <- paste0(comparison, "_tstat")
    }
    if (is.null(significance_column)) {
      significance_column <- paste0(comparison, "_pval")
    }
    if (is.null(fold_change_column)) {
      fold_change_column <- paste0(comparison, "_FC")
    }
  }

  if (select_by_rank) {
    t_statistic_column <- require_scalar(
      t_statistic_column,
      "t_statistic_column"
    )
    if (!t_statistic_column %in% colnames(deg_table)) {
      stop(sprintf(
        "ERROR: Missing rank column in `deg_table`: %s",
        t_statistic_column
      ))
    }

    companion_columns <- c(fold_change_column, significance_column)
    missing_companion_columns <- setdiff(companion_columns, colnames(deg_table))
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
    significance_column <- require_scalar(
      significance_column,
      "significance_column"
    )
    fold_change_column <- require_scalar(
      fold_change_column,
      "fold_change_column"
    )

    required_threshold_columns <- c(significance_column, fold_change_column)
    missing_threshold_columns <- setdiff(
      required_threshold_columns,
      colnames(deg_table)
    )
    if (length(missing_threshold_columns) > 0) {
      stop(sprintf(
        "ERROR: Missing threshold selection column(s) in `deg_table`: %s",
        paste(missing_threshold_columns, collapse = ", ")
      ))
    }
  }

  plot_bubble <- TRUE

  ## --------------- ##
  ## Error Messages ##
  ## -------------- ##

  if (
    (plot_top_pathways_up == FALSE & length(pathways_to_use_up) == 0) |
      plot_top_pathways_down == FALSE & length(pathways_to_use_down) == 0
  ) {
    stop(
      paste0(
        "ERROR: Enter at least one pathway in 'Pathways to use' ",
        "when 'Plot top pathways' is set to FALSE"
      )
    )
  }
  if (
    (plot_top_pathways_up == TRUE & length(pathways_to_use_up) > 0) |
      (plot_top_pathways_down == TRUE & length(pathways_to_use_down) > 0)
  ) {
    stop(
      paste0(
        "ERROR: Remove pathways from 'Pathways to use', ",
        "When 'Plot top pathways' is set to TRUE"
      )
    )
  }

  if (select_by_rank == FALSE) {
    sigcol <- gsub("_pval|p_val_|_adjpval|p_val_adj_", "", significance_column)
    fccol <- gsub(
      "_FC|_logFC|_log2FC|avg_logFC_|avg_log2FC_",
      "",
      fold_change_column
    )
    if (sigcol != fccol) {
      stop(
        paste0(
          "ERROR: when 'select by rank' is FALSE, under Genelist ",
          "selected by fold-change and pval thresholds, make sure to ",
          "select significance and fold change columns from the ",
          "same group comparison"
        )
      )
    }
  }

  custom_pathways_list <- build_custom_pathways_list(
    custom_pathways,
    custom_pathway_name_column,
    custom_pathway_gene_column
  )

  ## --------- ##
  ## Libraries ##
  ## --------- ##
  .l2p_timer <- Sys.time()
  .l2p_step <- function(msg) {
    elapsed <- as.numeric(difftime(Sys.time(), .l2p_timer, units = "secs"))
    cat(sprintf("\n[L2P %6.1fs] %s\n", elapsed, msg))
    flush.console()
  }

  .l2p_step("Loading R libraries")
  library(l2p)
  library(l2psupp)
  library(dplyr)
  library(magrittr)
  library(ggplot2)
  library(stringr)
  library(RCurl)
  library(grid)
  .l2p_step("Loaded all libraries")

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
    analysis_template_name = "L2P_OMIX_Single_CO",
    analysis_template_version = "v148",
    analysis_run_timestamp = format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"),
    analysis_r_version = R.version.string,
    analysis_l2p_version = as.character(utils::packageVersion("l2p")),
    analysis_l2psupp_version = as.character(utils::packageVersion("l2psupp")),
    analysis_species = species,
    analysis_gene_column = collapse_for_provenance(gene_names_column),
    analysis_rank_column = collapse_for_provenance(t_statistic_column),
    analysis_significance_column = collapse_for_provenance(significance_column),
    analysis_fold_change_column = collapse_for_provenance(fold_change_column),
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
    analysis_use_built_in_gene_universe = use_built_in_gene_universe,
    analysis_minimum_pathway_hit_count = minimum_pathway_hit_count,
    analysis_p_value_threshold_for_output = p_value_threshold_for_output,
    analysis_use_fdr_p_values = use_fdr_p_values,
    analysis_x_axis_title_font_size = x_axis_title_font_size,
    analysis_y_axis_title_font_size = y_axis_title_font_size,
    analysis_x_axis_tick_font_size = x_axis_tick_font_size,
    analysis_export_plot_file = collapse_for_provenance(export_plot_file),
    analysis_export_results_file = collapse_for_provenance(export_results_file)
  )

  cat(sprintf(
    paste0(
      "\nL2P Single Analysis\n",
      "R version: %s\n",
      "l2p: %s\n",
      "l2psupp: %s\n"
    ),
    analysis_provenance$analysis_r_version,
    analysis_provenance$analysis_l2p_version,
    analysis_provenance$analysis_l2psupp_version
  ))

  ## --------- ##
  ## Functions ##
  ## --------- ##

  # Function to return original genes with specified gene names.
  return_original_genes <- function(l2pout, gene_name_map) {
    l2pgenes <- as.list(l2pout$allgenesinpw)
    l2pgenes <- lapply(l2pgenes, function(x) {
      unlist(strsplit(x, " ", fixed = TRUE))
    })
    reverse_gene_map <- setNames(names(gene_name_map), unname(gene_name_map))
    l2pout$orig_genes <- vapply(l2pgenes, function(a) {
      original_genes <- reverse_gene_map[a]
      missing_original <- is.na(original_genes)
      original_genes[missing_original] <- a[missing_original]
      paste(unname(original_genes), collapse = " ")
    }, character(1))
    l2pout <- l2pout %>% arrange(pval)
    return(l2pout)
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

  # Function to plot bar graphs for GO results
  plotbar <- function(goResults, color_for_bar, use_fdr_p_values, plotitle) {
    colpal <- list(
      "Blue" = "Blues",
      "Green" = "Greens",
      "Grey" = "Greys",
      "Red" = "Reds",
      "Purple" = "Purples",
      "Orange" = "Oranges",
      "GreentoBlue" = "GnBu",
      "OrangetoRed" = "OrRd",
      "YellowOrangeRed" = "YlOrRd"
    )
    pal <- colpal[[color_for_bar]]
    if (use_fdr_p_values == TRUE) {
      df1 <- goResults %>%
        mutate(fdr = -log(fdr)) %>%
        arrange(desc(fdr))
      gplot <- ggplot(df1, aes(x = reorder(pathwayname2, fdr), y = fdr)) +
        geom_bar(aes(fill = fdr), stat = "identity") +
        scale_fill_distiller(
          name = expression(paste(
            "-lo",
            g[10],
            "(FDR adj ",
            italic("p"),
            "value)"
          )),
          palette = pal,
          direction = 1
        ) +
        theme_classic() +
        ggtitle(plotitle) +
        labs(
          y = expression(paste(
            "-lo",
            g[10],
            "(FDR adjusted ",
            italic("p"),
            " value)"
          )),
          x = "Pathways"
        ) +
        theme(
          aspect.ratio = 1,
          plot.title = element_text(
            hjust = 0.5,
            vjust = 10,
            size = 20,
            face = "bold"
          ),
          plot.margin = margin(t = 30, r = 10, b = 10, l = 10, unit = "pt"),
          axis.title.y = element_text(
            size = y_axis_title_font_size,
            margin = margin(r = 80)
          ),
          axis.title.x = element_text(
            size = x_axis_title_font_size,
            margin = margin(t = 20)
          ),
          axis.text.y = element_text(colour = "black"),
          axis.text.x = element_text(
            colour = "black",
            size = x_axis_tick_font_size
          ),
          legend.key.size = unit(1, "cm"),
          legend.title = element_text(size = 15, margin = margin(l = 20)),
          legend.text = element_text(size = 15)
        ) +
        coord_flip()
    } else {
      df1 <- goResults %>%
        mutate(pval = -log(pval)) %>%
        arrange(desc(pval))
      gplot <- ggplot(df1, aes(x = reorder(pathwayname2, pval), y = pval)) +
        geom_bar(aes(fill = pval), stat = "identity") +
        scale_fill_distiller(
          name = expression(paste("-lo", g[10], italic("(p"), "-value)")),
          palette = pal,
          direction = 1,
          limits = c(min(df1$pval) - 1, max(df1$pval))
        ) +
        theme_classic() +
        ggtitle(plotitle) +
        labs(
          y = expression(paste("-lo", g[10], italic("(p"), "-value)")),
          x = "Pathways"
        ) +
        theme(
          aspect.ratio = 1,
          plot.title = element_text(
            hjust = 0.5,
            vjust = 10,
            size = 20,
            face = "bold"
          ),
          plot.margin = margin(t = 30, r = 10, b = 10, l = 10, unit = "pt"),
          axis.title.y = element_text(
            size = y_axis_title_font_size,
            margin = margin(r = 80)
          ),
          axis.title.x = element_text(
            size = x_axis_title_font_size,
            margin = margin(t = 20)
          ),
          axis.text.y = element_text(colour = "black"),
          axis.text.x = element_text(
            colour = "black",
            size = x_axis_tick_font_size
          ),
          legend.key.size = unit(1, "cm"),
          legend.title = element_text(size = 15, margin = margin(l = 20)),
          legend.text = element_text(size = 15)
        ) +
        coord_flip()
    }
    if (interactive()) {
      print(gplot)
    }
    return(gplot)
  }

  # Function to plot bubble charts for GO results
  plotbubble <- function(
    goResults,
    plot_bubble_color,
    plot_bubble_size,
    sort_bubble_plot_by,
    plotitle
  ) {
    leglab <- plot_bubble_color
    leglab2 <- plot_bubble_size
    x_label <- sort_bubble_plot_by

    plot_bubble_list <- list(
      "Fisher's Exact pval" = "pval",
      "fdr corrected pval" = "fdr",
      "number of hits" = "number_hits",
      "percent gene hits per pathway" = "percent_gene_hits_per_pathway",
      "enrichment score" = "enrichment_score"
    )
    plot_bubble_size <- plot_bubble_list[[plot_bubble_size]]
    plot_bubble_color <- plot_bubble_list[[plot_bubble_color]]
    sort_bubble_plot_by <- plot_bubble_list[[sort_bubble_plot_by]]

    if (plot_bubble_color %in% c("pval", "fdr")) {
      goResults$color <- -log10(goResults[[plot_bubble_color]])
      leglab <- paste0("-log10(", plot_bubble_color, ")")
    } else {
      goResults$color <- goResults[[plot_bubble_color]]
    }

    if (plot_bubble_size %in% c("pval", "fdr")) {
      goResults$size <- -log10(goResults[[plot_bubble_size]])
      leglab2 <- paste0("-log10(", plot_bubble_size, ")")
    } else {
      goResults$size <- goResults[[plot_bubble_size]]
    }

    if (sort_bubble_plot_by %in% c("pval", "fdr")) {
      goResults$sort <- -log10(goResults[[sort_bubble_plot_by]])
      x_label <- paste0("-log10(", sort_bubble_plot_by, ")")
    } else {
      goResults$sort <- goResults[[sort_bubble_plot_by]]
    }

    goResults$color <- as.numeric(goResults$color)
    minp <- floor(min(goResults$color))
    maxp <- ceiling(max(goResults$color))
    sizemax <- ceiling(max(goResults$size) / 10) * 10

    goResults <- goResults %>% dplyr::mutate(percorder = order(goResults$sort))
    goResults$pathwayname2 <- factor(
      goResults$pathwayname2,
      levels = goResults$pathwayname2[goResults$percorder]
    )
    xmin <- min(goResults$sort) - 0.1 * min(goResults$sort)
    xmax <- max(goResults$sort) + 0.1 * min(goResults$sort)

    bubblecols <- list(
      "blues" = c("#56B1F7", "#132B43"),
      "reds" = c("#fddbc7", "#b2182b"),
      "blue to red" = c("dark blue", "red")
    )

    gplot <- goResults %>%
      ggplot(aes(x = sort, y = pathwayname2, col = color, size = size)) +
      geom_point() +
      theme_classic() +
      ggtitle(plotitle) +
      labs(col = leglab, size = leglab2, y = "Pathway", x = x_label) +
      theme(
        aspect.ratio = 1,
        plot.title = element_text(
          hjust = 0.5,
          vjust = 10,
          size = 20,
          face = "bold"
        ),
        plot.margin = margin(t = 30, r = 10, b = 10, l = 10, unit = "pt"),
        text = element_text(size = pathway_axis_label_font_size),
        legend.position = "right",
        legend.key.height = unit(1, "cm"),
        axis.title.y = element_text(
          size = y_axis_title_font_size,
          margin = margin(r = 80)
        ),
        axis.title.x = element_text(
          size = x_axis_title_font_size,
          margin = margin(t = 20)
        ),
        axis.text.y = element_text(colour = "black"),
        axis.text.x = element_text(
          colour = "black",
          size = x_axis_tick_font_size
        ),
        legend.key.size = unit(1, "cm"),
        legend.title = element_text(
          size = 15,
          margin = margin(b = 10, l = 20)
        ),
        legend.text = element_text(size = 15)
      ) +
      xlim(xmin, xmax) +
      scale_colour_gradient(
        low = bubblecols[[bubble_colors]][1],
        high = bubblecols[[bubble_colors]][2]
      ) +
      expand_limits(
        colour = seq(minp, maxp, by = 1),
        size = seq(0, sizemax, by = 10)
      ) +
      guides(
        colour = guide_colourbar(
          order = 1,
          title.position = "top",
          title.hjust = 0.5
        ),
        size = guide_legend(
          order = 2,
          title.position = "top"
        )
      )
    if (interactive()) {
      print(gplot)
    }
    return(gplot)
  }

  draw_error_message <- function(message, color, width = 120) {
    # Split the message by newlines
    segments <- str_split(message, "\n")[[1]]
    # Wrap each segment
    wrapped_segments <- lapply(segments, str_wrap, width = width)
    # Combine the wrapped segments with newlines
    wrapped_message <- paste(unlist(wrapped_segments), collapse = "\n")

    if (interactive()) {
      grid.newpage()
      grid.rect(gp = gpar(fill = color, col = NA))
      grid.text(
        wrapped_message,
        x = 0.5,
        y = 0.5,
        gp = gpar(fontface = "italic", cex = 3, col = "black"),
        just = "center"
      )
    } else {
      message(wrapped_message)
    }
  }

  ## --------------- ##
  ## Main Code Block ##
  ## --------------- ##

  if (select_by_rank == TRUE) {
    genesmat <- deg_table %>%
      dplyr::select(
        .data[[gene_names_column]],
        .data[[t_statistic_column]]
      )
    genesmat <- genesmat %>%
      dplyr::arrange(desc(.data[[t_statistic_column]]))
    genesmat <- genesmat %>%
      dplyr::filter(!is.na(.data[[t_statistic_column]]))
    if (select_top_percentage_of_genes == TRUE) {
      numselect <- ceiling(0.1 * dim(deg_table)[1])
    } else {
      numselect <- select_top_genes
    }
  } else {
    numselect <- NULL
    genesmat <- deg_table %>%
      dplyr::select(
        .data[[gene_names_column]],
        .data[[fold_change_column]],
        .data[[significance_column]]
      )
  }

  genes_to_include <- list()
  x <- list()
  lastgene <- list()
  plotitle <- list("Upregulated Pathways", "Downregulated Pathways")

  # Select Upregulated genes
  if (!is.null(numselect)) {
    genes_to_include[[1]] <- head(genesmat[[gene_names_column]], numselect)
    lastgene[[1]] <- tail(genes_to_include[[1]], 1)
  } else {
    if (is_log_fold_change_column(fold_change_column)) {
      logFC_threshold <- log2(fold_change_threshold)
      genes_to_include[[1]] <- deg_table %>%
        dplyr::arrange(.data[[significance_column]]) %>%
        dplyr::filter(
          .data[[significance_column]] <= significance_threshold &
            .data[[fold_change_column]] >= logFC_threshold
        ) %>%
        pull(gene_names_column)
      n <- length(genes_to_include[[1]])
      cat(sprintf("Number of DEG genes using set cut-offs: %s \n", n))
      if (n < minimum_number_of_deg_genes) {
        message <- sprintf(
          "DEG gene count, %d is not enough to find enriched %s. Try to loosen criteria to reach %d or reset minimum number of DEG genes. Ideally, do not go under 50 genes.",
          n,
          plotitle[[1]],
          minimum_number_of_deg_genes
        )
        draw_error_message(message, color = "lightcoral")
        # stop(paste("ERROR: DEG gene count:",n,"is not enough to find enriched pathways. Try to loosen criteria to reach",minimum_number_of_deg_genes))
      } else {
        lastgene[[1]] <- tail(genes_to_include[[1]], 1)
      }
    } else {
      genes_to_include[[1]] <- deg_table %>%
        dplyr::arrange(.data[[significance_column]]) %>%
        dplyr::filter(
          .data[[significance_column]] <= significance_threshold &
            .data[[fold_change_column]] >= fold_change_threshold
        ) %>%
        pull(gene_names_column)
      n <- length(genes_to_include[[1]])
      # cat(sprintf("Number of DEG genes: %s \n",n))
      if (n < minimum_number_of_deg_genes) {
        message <- sprintf(
          "DEG gene count, %d is not enough to find enriched %s. Try to loosen criteria to reach %d or reset minimum number of DEG genes. Ideally, do not go under 50 genes.",
          n,
          plotitle[[1]],
          minimum_number_of_deg_genes
        )
        draw_error_message(message, color = "lightcoral")
        # stop(paste("ERROR: DEG gene count:",n,"is not enough to find enriched pathways. Try to loosen criteria to reach",minimum_number_of_deg_genes))
      } else {
        lastgene[[1]] <- tail(genes_to_include[[1]], 1)
      }
    }
  }

  # Select Downregulated Genes
  if (!is.null(numselect)) {
    genes_to_include[[2]] <- rev(tail(genesmat[[gene_names_column]], numselect))
    lastgene[[2]] <- tail(genes_to_include[[2]], 1)
  } else {
    if (is_log_fold_change_column(fold_change_column)) {
      logFC_threshold <- -1 * log2(fold_change_threshold)
      genes_to_include[[2]] <- deg_table %>%
        dplyr::arrange(.data[[significance_column]]) %>%
        dplyr::filter(
          .data[[significance_column]] <= significance_threshold &
            .data[[fold_change_column]] <= logFC_threshold
        ) %>%
        pull(gene_names_column)
      n <- length(genes_to_include[[2]])
      cat(sprintf("Number of DEG genes: %s \n", n))
      if (n < minimum_number_of_deg_genes) {
        message <- sprintf(
          "DEG gene count, %d is not enough to find enriched %s. Try to loosen criteria to reach %d or reset minimum number of DEG genes. Ideally, do not go under 50 genes.",
          n,
          plotitle[[2]],
          minimum_number_of_deg_genes
        )
        draw_error_message(message, color = "lightcoral")
        # stop(paste("ERROR: DEG gene count:",n,"is not enough to find enriched pathways. Try to loosen criteria to reach",minimum_number_of_deg_genes))
      } else {
        lastgene[[2]] <- tail(genes_to_include[[2]], 1)
      }
    } else {
      genes_to_include[[2]] <- deg_table %>%
        dplyr::arrange(.data[[significance_column]]) %>%
        dplyr::filter(
          .data[[significance_column]] <= significance_threshold &
            .data[[fold_change_column]] <= -1 * fold_change_threshold
        ) %>%
        pull(gene_names_column)
      n <- length(genes_to_include[[2]])
      # cat(sprintf("Number of DEG genes: %s \n",n))
      if (n < minimum_number_of_deg_genes) {
        message <- sprintf(
          "DEG gene count, %d is not enough to find enriched %s. Try to loosen criteria to reach %d or reset minimum number of DEG genes. Ideally, do not go under 50 genes.",
          n,
          plotitle[[2]],
          minimum_number_of_deg_genes
        )
        draw_error_message(message, color = "lightcoral")
        # stop(paste("ERROR: DEG gene count:",n,"is not enough to find enriched pathways. Try to loosen criteria to reach",minimum_number_of_deg_genes))
      } else {
        lastgene[[2]] <- tail(genes_to_include[[2]], 1)
      }
    }
  }

  cat(
    "\n\nOnly pathways that are over-represented are tested by One-Sided Fisher's Exact Test.\nPathways that show under-representation are excluded and not returned"
  )

  .l2p_step("Gene selection completed")

  # ========== OPTIMIZATION: Pre-compute gene maps once ==========
  # Extract raw gene universe once (all genes from DEG table).
  raw_gene_universe <- unique(as.character(genesmat[[gene_names_column]]))
  raw_gene_universe <- raw_gene_universe[
    !is.na(raw_gene_universe) & nzchar(raw_gene_universe)
  ]
  raw_selected_genes <- unique(as.character(unlist(
    genes_to_include,
    use.names = FALSE
  )))
  raw_selected_genes <- raw_selected_genes[
    !is.na(raw_selected_genes) & nzchar(raw_selected_genes)
  ]
  cat(sprintf("\n\nGene universe size: %d genes\n", length(raw_gene_universe)))

  .l2p_step("Processing selected genes (updating names/mapping orthologs)")

  if (species == "Human") {
    selected_gene_map <- updategenes(raw_selected_genes, trust = 1)
    names(selected_gene_map) <- raw_selected_genes
    cat(sprintf(
      "Updated %d selected gene symbols\n",
      length(selected_gene_map)
    ))
  } else {
    selected_gene_map <- sapply(raw_selected_genes, function(x) {
      o2o(x, species, "human")[1]
    })
    no_orth_count <- sum(is.na(selected_gene_map))
    selected_gene_map <- selected_gene_map[!is.na(selected_gene_map)]

    cat(sprintf(
      "Selected gene ortholog mapping: %d with homologs, %d without\n",
      length(selected_gene_map),
      no_orth_count
    ))
  }

  if (use_built_in_gene_universe == TRUE) {
    processed_gene_universe <- NULL
    original_gene_map <- selected_gene_map
    .l2p_step("Skipping custom gene universe processing")
  } else if (species == "Human") {
    original_gene_map <- updategenes(raw_gene_universe, trust = 1)
    names(original_gene_map) <- raw_gene_universe
    processed_gene_universe <- as.character(original_gene_map)
    .l2p_step("Gene universe processing completed")
  } else {
    original_gene_map <- sapply(raw_gene_universe, function(x) {
      o2o(x, species, "human")[1]
    })
    original_gene_map <- original_gene_map[
      !is.na(original_gene_map) & nzchar(original_gene_map)
    ]
    processed_gene_universe <- unique(as.character(original_gene_map))
    processed_gene_universe <- processed_gene_universe[
      !is.na(processed_gene_universe) & nzchar(processed_gene_universe)
    ]
    .l2p_step("Gene universe processing completed")
  }

  if (!is.null(custom_pathways_list)) {
    custom_pathway_genes <- unique(unlist(lapply(
      custom_pathways_list,
      function(pathway_entry) {
        pathway_entry <- as.character(pathway_entry)
        if (length(pathway_entry) <= 2) {
          return(character(0))
        }
        pathway_entry[-c(1, 2)]
      }
    )))
    custom_pathway_genes <- custom_pathway_genes[
      !is.na(custom_pathway_genes) & nzchar(custom_pathway_genes)
    ]

    if (length(custom_pathway_genes) > 0) {
      if (species == "Human") {
        custom_pathway_gene_map <- updategenes(custom_pathway_genes, trust = 1)
        names(custom_pathway_gene_map) <- custom_pathway_genes
      } else {
        custom_pathway_gene_map <- sapply(custom_pathway_genes, function(x) {
          o2o(x, species, "human")[1]
        })
        custom_pathway_gene_map <- custom_pathway_gene_map[
          !is.na(custom_pathway_gene_map)
        ]
      }
      custom_pathways_list <- align_custom_pathways_to_gene_map(
        custom_pathways_list,
        custom_pathway_gene_map
      )
    }
    .l2p_step("Custom pathway database processing completed")
  }

  # ========== END OPTIMIZATION ==========

  # Running L2P
  for (i in 1:length(genes_to_include)) {
    cat("\n\n")
    cat(sprintf("Analysis of %s :", plotitle[[i]]))
    cat("\n\n")
    .l2p_step(sprintf("Starting %s analysis", plotitle[[i]]))

    # Get the list of original gene names for this analysis direction
    original_genes <- as.vector(unique(unlist(genes_to_include[[i]])))

    # OPTIMIZATION: Subset from already-processed gene universe instead of re-processing
    if (species == "Human") {
      # Find the updated names for our selected genes
      genes_to_include[[i]] <- selected_gene_map[original_genes]
      missing_gene_count <- sum(is.na(genes_to_include[[i]]))
      genes_to_include[[i]] <- genes_to_include[[i]][
        !is.na(genes_to_include[[i]])
      ]

      # Report updates
      updated_count <- sum(
        names(genes_to_include[[i]]) != genes_to_include[[i]]
      )
      cat(sprintf(
        "\nGene names updated from cache. Number of updated genes: %d\n",
        updated_count
      ))
      if (missing_gene_count > 0) {
        cat(sprintf(
          "Selected genes missing from update cache: %d\n",
          missing_gene_count
        ))
      }

      if (updated_count > 0) {
        cat("\nOriginal:Updated\n")
        updated_idx <- names(genes_to_include[[i]]) != genes_to_include[[i]]
        for (j in which(updated_idx)) {
          cat(sprintf(
            "%s:%s\n",
            names(genes_to_include[[i]])[j],
            genes_to_include[[i]][j]
          ))
        }
      }

      # Save lastgene BEFORE converting to character (which strips names)
      lastgene[[i]] <- names(tail(genes_to_include[[i]], 1))
      new_gene_names <- genes_to_include[[i]]
      genes_to_include[[i]] <- as.character(genes_to_include[[i]])
    } else {
      # Find the homologs for our selected genes
      genes_to_include[[i]] <- selected_gene_map[original_genes]
      genes_to_include[[i]] <- genes_to_include[[i]][
        !is.na(genes_to_include[[i]])
      ]

      # Report homologs
      no_orth_count <- sum(!(original_genes %in% names(genes_to_include[[i]])))
      has_orth_count <- length(genes_to_include[[i]])

      cat(sprintf(
        "\n\nNumber of genes in genelist without homologue: %d (%.1f%%)\n",
        no_orth_count,
        100 * no_orth_count / length(original_genes)
      ))
      cat(sprintf(
        "Number of genes in genelist with homologue: %d (%.1f%%)\n",
        has_orth_count,
        100 * has_orth_count / length(original_genes)
      ))

      if (has_orth_count > 0) {
        cat("\nGene:Homolog\n")
        for (j in 1:min(10, length(genes_to_include[[i]]))) {
          cat(sprintf(
            "%s:%s\n",
            names(genes_to_include[[i]])[j],
            genes_to_include[[i]][j]
          ))
        }
        if (length(genes_to_include[[i]]) > 10) {
          cat(sprintf("... (%d more)\n", length(genes_to_include[[i]]) - 10))
        }
      }

      # Save lastgene BEFORE converting to character (which strips names)
      lastgene[[i]] <- names(tail(genes_to_include[[i]], 1))
      new_gene_names <- genes_to_include[[i]]
      genes_to_include[[i]] <- as.character(genes_to_include[[i]])
    }

    # Use cached processed gene universe
    gene_universe <- processed_gene_universe

    # Check overall size of genelist and p-values of lowest significant gene
    sizegenelist <- length(genes_to_include[[i]])

    cat("\n\nNumber of genes selected for pathway analysis: ", sizegenelist)
    if (use_built_in_gene_universe == TRUE) {
      cat("\nUsing built-in L2P gene universe.\n")
    } else {
      sizeuniv <- length(gene_universe)
      cat("\nSize of gene universe: ", sizeuniv)
      pctuniv <- (sizegenelist / sizeuniv) * 100
      pctuniv <- formatC(pctuniv, digits = 2, format = "f")
      cat(paste0(
        "\nFinal genelist as percent of gene universe (ideally < 20 %) : ",
        pctuniv,
        "%\n"
      ))
    }

    if (select_by_rank == FALSE) {
      lastgenedat <- deg_table %>%
        dplyr::filter(.data[[gene_names_column]] == lastgene[[i]]) %>%
        select(
          .data[[gene_names_column]],
          fold_change_column,
          significance_column
        )
    } else {
      reporting_columns <- unique(c(
        gene_names_column,
        t_statistic_column,
        fold_change_column,
        significance_column
      ))
      reporting_columns <- reporting_columns[
        !is.na(reporting_columns) &
          reporting_columns %in% colnames(deg_table)
      ]
      lastgenedat <- deg_table %>%
        dplyr::filter(.data[[gene_names_column]] == lastgene[[i]]) %>%
        dplyr::select(dplyr::all_of(reporting_columns))
    }

    cat(
      "\n\nCheck p-value for least significant gene in genelist (ideally p <= 0.15) :\n\n"
    )
    print(lastgenedat)

    .l2p_step(sprintf("Running Fisher's exact test for %s", plotitle[[i]]))

    if (use_built_in_gene_universe == TRUE) {
      if (!is.null(custom_pathways_list)) {
        x[[i]] <- l2p(
          genes_to_include[[i]],
          categories = collections_to_include,
          custompathways = custom_pathways_list
        )
        cat("\n\nUsing custom pathways with built-in gene universe.\n")
      } else {
        x[[i]] <- l2p(
          genes_to_include[[i]],
          categories = collections_to_include
        )
        cat("\n\nUsing built-in gene universe.\n")
      }
      cat(paste0("Total number of pathways tested: ", nrow(x[[i]])))
    } else {
      if (!is.null(custom_pathways_list)) {
        x[[i]] <- l2p(
          genes_to_include[[i]],
          categories = collections_to_include,
          custompathways = custom_pathways_list,
          universe = gene_universe
        )
      } else {
        x[[i]] <- l2p(
          genes_to_include[[i]],
          categories = collections_to_include,
          universe = gene_universe
        )
      }
      cat(
        "\n\nUsing all genes included in the differential expression analysis as gene universe.\n\n"
      )
      cat(paste0("Total number of pathways tested: ", nrow(x[[i]])))
    }

    .l2p_step(sprintf("Completed enrichment for %s", plotitle[[i]]))

    genes_column <- intersect(
      c("allgenesinpw", "genesinpathway", "genes_in_pathway", "genes", "hits"),
      colnames(x[[i]])
    )[1]
    if (is.na(genes_column) || is.null(genes_column)) {
      stop(
        "ERROR: L2P output does not contain a recognizable genes-in-pathway column."
      )
    }
    if (genes_column != "allgenesinpw") {
      x[[i]]$allgenesinpw <- x[[i]][[genes_column]]
    }

    .l2p_step(sprintf("Post-processing results for %s", plotitle[[i]]))

    l2p_result <- x[[i]] %>%
      select(
        pathway_name,
        category,
        number_hits,
        percent_gene_hits_per_pathway,
        enrichment_score,
        pval,
        fdr,
        allgenesinpw
      ) %>%
      mutate(percent_gene_hits_per_pathway = percent_gene_hits_per_pathway) %>%
      dplyr::arrange(pval)

    if (nrow(l2p_result) > 0) {
      l2p_result <- as.data.frame(return_original_genes(
        l2p_result,
        original_gene_map
      ))

      l2p_result$enrichment_score <- as.numeric(formatC(
        l2p_result$enrichment_score,
        digits = 3,
        format = "f"
      ))
      l2p_result$percent_gene_hits_per_pathway <- as.numeric(formatC(
        l2p_result$percent_gene_hits_per_pathway,
        digits = 3,
        format = "f"
      ))
      l2p_result$direction <- plotitle[[i]]

      x[[i]] <- l2p_result %>%
        dplyr::filter(number_hits >= minimum_pathway_hit_count) %>%
        dplyr::filter(pval < p_value_threshold_for_output)

      if (nrow(x[[i]]) > 0) {
        x[[i]] <- head(x[[i]], 500)
      } else {
        message <- sprintf(
          "No results for %s \n Try loosening the criteria (e.g. pvals up to < 0.15, FC > 1) to get more genes",
          plotitle[[i]]
        )
        draw_error_message(message, color = "lightcoral")
        x[[i]] <- NULL
      }

      .l2p_step(sprintf("Finished processing %s", plotitle[[i]]))
    } else {
      message <- sprintf(
        "No results for %s \n Try loosening the criteria (e.g. pvals up to < 0.15, FC > 1) to get more genes",
        plotitle[[i]]
      )
      draw_error_message(message, color = "lightcoral")
      x[[i]] <- NULL
    }
  }

  .l2p_step("Starting visualization")

  # Plotting the results
  if (any(!vapply(x, is.null, logical(1)))) {
    plot_outputs <- list()
    for (i in 1:length(x)) {
      if (is.null(x[[i]])) {
        next
      }
      goResults <- x[[i]] %>%
        dplyr::mutate(
          pathwayname2 = stringr::str_replace_all(pathway_name, "_", " ")
        )
      goResults$pathwayname2 <- str_to_upper(goResults$pathwayname2)
      goResults$pathwayname2 <- trimws(goResults$pathwayname2)
      goResults <- goResults %>%
        dplyr::mutate(
          pathwayname2 = stringr::str_wrap(
            pathwayname2,
            effective_pathway_axis_label_max_length
          )
        )
      goResults <- distinct(goResults, pathwayname2, .keep_all = TRUE)

      if (i == 1) {
        if (plot_top_pathways_up == TRUE) {
          goResults <- goResults %>%
            top_n(number_of_pathways_to_plot, wt = -log(pval))
        } else {
          goResults <- goResults %>%
            dplyr::filter(.data[["pathway_name"]] %in% pathways_to_use_up)
          if (dim(goResults)[1] < length(pathways_to_use_up)) {
            cat(
              "\nSome selected pathways are not showing in plot, check for spelling errors:\n\n"
            )
            cat(pathways_to_use_up[
              !pathways_to_use_up %in% goResults[["pathway_name"]]
            ])
          }
        }
      } else {
        if (plot_top_pathways_down == TRUE) {
          goResults <- goResults %>%
            top_n(number_of_pathways_to_plot, wt = -log(pval))
        } else {
          goResults <- goResults %>%
            dplyr::filter(.data[["pathway_name"]] %in% pathways_to_use_down)
          if (dim(goResults)[1] < length(pathways_to_use_down)) {
            cat(
              "\nSome selected pathways are not showing in plot, check for spelling errors:\n\n"
            )
            cat(pathways_to_use_down[
              !pathways_to_use_down %in% goResults[["pathway_name"]]
            ])
          }
        }
      }
      if (nrow(goResults) < number_of_pathways_to_plot) {
        numpath <- nrow(goResults)
        message <- sprintf(
          "Only %d significant %s. Try to loosen criteria to get more genes and enriched pathways",
          numpath,
          plotitle[[i]]
        )
        draw_error_message(message, color = "lightcoral")
      }
      bar_plot <- plotbar(
        goResults,
        color_for_bar,
        use_fdr_p_values,
        plotitle[[i]]
      )
      bubble_plot <- plotbubble(
        goResults,
        plot_bubble_color,
        plot_bubble_size,
        sort_bubble_plot_by,
        plotitle[[i]]
      )

      direction_suffix <- tolower(gsub("\\s+", "_", plotitle[[i]]))
      plot_outputs[[paste0(direction_suffix, "_bar")]] <- bar_plot
      plot_outputs[[paste0(direction_suffix, "_bubble")]] <- bubble_plot
    }

    if (!is.null(export_plot_file) && nzchar(export_plot_file)) {
      ext <- tools::file_ext(export_plot_file)
      if (!nzchar(ext)) {
        ext <- "png"
      }
      base_path <- tools::file_path_sans_ext(export_plot_file)
      for (nm in names(plot_outputs)) {
        out_plot <- paste0(base_path, "_", nm, ".", ext)
        ggplot2::ggsave(
          filename = out_plot,
          plot = plot_outputs[[nm]],
          width = export_plot_width,
          height = export_plot_height,
          dpi = 600
        )
      }
    }

    # Combine and format pathway results for return
    combined_paths <- do.call(rbind, x)
    combined_paths <- combined_paths %>% arrange(pval)
    combined_paths$pval <- sprintf("%.2e", combined_paths$pval)
    combined_paths$fdr <- sprintf("%.2e", combined_paths$fdr)
    combined_paths <- combined_paths %>%
      select(
        pathway_name,
        category,
        direction,
        number_hits,
        percent_gene_hits_per_pathway,
        enrichment_score,
        pval,
        fdr,
        allgenesinpw,
        orig_genes
      )

    .l2p_step("Completed visualization")

    if (!is.null(export_results_file) && nzchar(export_results_file)) {
      utils::write.csv(combined_paths, export_results_file, row.names = FALSE)
      .l2p_step("Saved results to CSV")

      final_analysis_provenance <- c(
        analysis_provenance,
        list(
          analysis_input_gene_count = length(raw_gene_universe),
          analysis_selected_up_gene_count = length(genes_to_include[[1]]),
          analysis_selected_down_gene_count = length(genes_to_include[[2]]),
          analysis_gene_universe_count = if (is.null(processed_gene_universe)) {
            "built-in"
          } else {
            length(processed_gene_universe)
          },
          analysis_result_row_count = nrow(combined_paths)
        )
      )
      provenance_file <- write_provenance_csv(
        final_analysis_provenance,
        export_results_file
      )
      .l2p_step(sprintf("Saved provenance to %s", provenance_file))
    }

    return(combined_paths)
  } else {
    message <- sprintf(
      "No pathway results. Try to loosen criteria to get more up and downregulated genes"
    )
    draw_error_message(message, color = "lightcoral")
    return(NULL)
  }
}
