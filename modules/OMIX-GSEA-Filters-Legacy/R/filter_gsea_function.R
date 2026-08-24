#' GSEA Filters - Sugarloaf V2 [CCBR] [scRNA-seq] [Bulk]
#'
#' @description
#' Filters the input GSEA table based on multiple criteria. The filtering
#' criteria include GSEA statistics, pathway annotation, and comparison
#' contrasts. Displays the filtered results in an interactive volcano-bubble
#' chart.
#' DUET Documentation
#'
#' @details
#' Contact CCBR at \email{NCICCBRNIDAP@@mail.nih.gov} if you encounter problems.
#'
#' @param GSEA_Table A data frame. The output dataset from a GSEA analysis
#' @param Columns_to_Sort_Output_By
#' Character vector. Sorting variables for arranging the output table
#' @param Sort_Output_in_Decreasing_Order Logical. Default: \code{FALSE}.
#' @param P_Value_Filter
#' Character. One of ['adjusted p-value', 'p-value']. Select p-value type to
#' use for filtering Default: \code{adjusted p-value}.
#' @param P_value_Threshold
#' Numeric. Type in the p-value cutoff for filtering Default: \code{0.05}.
#' @param Enrichment_Score_Filter
#' Character. One of ['NES (Normalized Enrichment Score)', 'ES (Enrichment
#' Score)']. Select the enrichment score type to use for filtering Default:
#' \code{NES (Normalized Enrichment Score)}.
#' @param Enrichment_Score_Threshold
#' Numeric. Type in the enrichment score cutoff for filtering (absolute value)
#' Default: \code{0}.
#' @param Enrichment_Score_Sign
#' Character. One of ['+/-', '+', '-']. Select the enrichment score direction
#' to use for filtering Default: \code{+/-}.
#' @param Size_Filter
#' Character. One of ['Pathway size', 'Leading Edge (LE) size']. Select
#' pathway or leading edge to use for filtering by its size Default:
#' \code{Pathway size}.
#' @param Size_Cutoff
#' Numeric. Type in the minimum size of a pathway or leading edge to use for
#' filtering Default: \code{0}.
#' @param Top_Rank_Filter
#' Character. P-value rank; if ALL (case insensitive), maximum number of
#' pathways included; otherwise top-ranked enriched pathways per each
#' collection and comparison contrast included Default: \code{all}.
#' @param Collections_to_Include
#' Character. Select a collection name from the dropdown list or type in a
#' custom collection if not listed (create new option). Multiple selections
#' allowed.
#' @param Pathways_to_Include
#' Character. Select a pathway name from the dropdown list or type in a custom
#' collection if not listed (create new option). Multiple selections allowed.
#' @param Gene_Filter_Universe
#' Character. One of ['Leading Edge (LE)', 'Pathway']. Select a pathway or
#' leading edge for searching gene members when filtering pathways Default:
#' \code{Leading Edge (LE)}.
#' @param Genes_to_Include
#' Character. Select a gene symbol from the dropdown list or type in a gene
#' symbol if not listed (create new option). Multiple selections allowed.
#' @param Contrast_Filter
#' Character. One of ['none', 'keep', 'remove']. if none all identified
#' contrasts will be included; if remove or keep, a subset of contrasts will
#' be used for filtering Default: \code{none}.
#' @param Contrasts
#' Character vector. Default: \code{c("if None entered all contrast will be
#' used"," otherwise enter specific contrasts included in the GSEA table to be
#' kept or removed for filtering")}.
#' @param Bubble_Color_Variable
#' Character. One of ['collection', 'pathway size']. Select collection or
#' pathway size to use in for coloring points in the output figure Default:
#' \code{collection}.
#' @param Bubble_Color_Opacity
#' Numeric. The transparency of point coloring. Enter a value between 0 and 1
#' (from transparent to opaque) Default: \code{0.95}.
#' @param Bubble_Maximal_Size
#' Numeric. Enter the maximum size for point scaling Default: \code{2}.
#' @param X_Axis_Minimum
#' Character vector. Use only to change default value defined by the data
#' @param X_Axis_Maximum
#' Character vector. Use only to change default value defined by the data
#' @param Y_Axis_Minimum
#' Character vector. Use only to change default value defined by the data
#' @param Y_Axis_Maximum
#' Character vector. Use only to change default value defined by the data
#' @param Display_Warnings
#' Numeric. Set to 0 if you want warnings to appear in the Logs output tab;
#' default is set to -1 which mutes the warnings. Default: \code{-1}.
#'
#' @return A filtered GSEA results data frame retaining only gene sets that
#' pass the user-defined significance and NES thresholds.
#'
#' @importFrom dplyr .
#' @importFrom ggplot2 .
#' @importFrom plotly .
#' @importFrom RColorBrewer .
#' @export
GSEA_Filters <- function(
    gsea_table,
    columns_to_sort_output_by,
    sort_output_in_decreasing_order = FALSE,
    p_value_filter = "adjusted p-value",
    p_value_threshold = 0.05,
    enrichment_score_filter = "NES (Normalized Enrichment Score)",
    enrichment_score_threshold = 0,
    enrichment_score_sign = "+/-",
    size_filter = "Pathway size",
    size_cutoff = 0,
    top_rank_filter = "all",
    collections_to_include = c(),
    pathways_to_include = c(),
    gene_filter_universe = "Leading Edge (LE)",
    genes_to_include = c(),
    contrast_filter = "none",
    contrasts = c(
        "if None entered all contrast will be used",
        paste0(
            " otherwise enter specific contrasts included in the GSEA ",
            "table to be kept or removed for filtering"
        )
    ),
    display_warnings = -1
) {
    ## This function filters GSEA Table

    ## --------- ##
    ## Libraries ##
    ## --------- ##

    options(warn = display_warnings)
    library(dplyr)
    library(ggplot2)
    library(tidyr)
    library(plotly)
    library(RColorBrewer)
    ## -------------------------------- ##
    ## User-Defined Template Parameters ##
    ## -------------------------------- ##

    # Visualization parameters

    ## --------------- ##
    ## Error Messages ##
    ## -------------- ##

    # stop if not available collections are selected with
    # "Collections to Include"
    if (!is.null(collections_to_include)) {
        available_collections <- unique(gsea_table[, "collection"])
        found_collections <- collections_to_include[
            collections_to_include %in% available_collections
        ]
        missing_collections <- collections_to_include[
            !collections_to_include %in% available_collections
        ]
        if (!any(collections_to_include %in% gsea_table[, "collection"])) {
            stop(sprintf(
                paste0(
                    "ERROR:\n\n",
                    "Requested 'Collections to Include' are not found in the input GSEA Table.\n\n",
                    "Not found collections:\n%s\n\n",
                    "Available collections:\n%s"
                ),
                paste(missing_collections, collapse = "\n"),
                paste(available_collections, collapse = "\n")
            ))
        } else if (
            !all(collections_to_include %in% gsea_table[, "collection"])
        ) {
            stop(sprintf(
                paste0(
                    "ERROR:\n\nSome of the requested 'Collections to ",
                    "Include' are not found in the input  GSEA Table.\n",
                    "Check if the collections were selected to run with ",
                    "the GSEA Preranked [CCBR] or if the collections full ",
                    "names (case sensitive) were typed correctly ",
                    "(relevant only to adding a custom pathway name to the ",
                    "dropdown list with the 'Create option' ",
                    "functionality). \n\nNot found collections are:\n%s\n\n",
                    "Found collections are:\n%s\n\n",
                    "Available collections are:\n%s"
                ),
                paste(missing_collections, collapse = "\n"),
                paste(found_collections, collapse = "\n"),
                paste(available_collections, collapse = "\n")
            ))
        }
    }
    if (!is.null(pathways_to_include)) {
        available_pathways <- gsea_table[, "pathway"]
        found_pathways <- pathways_to_include[
            pathways_to_include %in% available_pathways
        ]
        missing_pathways <- pathways_to_include[
            !pathways_to_include %in% available_pathways
        ]
        if (!any(pathways_to_include %in% gsea_table[, "pathway"])) {
            stop(sprintf(
                paste0(
                    "ERROR:\n\n",
                    "Requested 'Pathways to Include' are not found in the input GSEA Table.\n\n",
                    "Not found pathways:\n%s\n\n"
                ),
                paste(missing_pathways, collapse = "\n")
            ))
        } else if (!all(pathways_to_include %in% gsea_table[, "pathway"])) {
            stop(sprintf(
                paste0(
                    "ERROR:\n\n",
                    "Some of the requested 'Pathways to Include' are not found in the input GSEA Table.\n\n",
                    "Not found pathways:\n%s\n\n",
                    "Found pathways:\n%s\n\n"
                ),
                paste(missing_pathways, collapse = "\n"),
                paste(found_pathways, collapse = "\n")
            ))
        }
    }

    ## --------- ##
    ## Functions ##
    ## --------- #

    filter.message <-
        function(filter, warn = FALSE, condition, output) {
            n <- length(unique(output$pathway))
            if (!warn) {
                if (n == 0) {
                    cat(
                        sprintf(
                            paste0(
                                "ERROR: Filter by %s (%s) returned %g ",
                                "unique pathway(s)\n"
                            ),
                            filter,
                            condition,
                            n
                        )
                    )
                    stop("Filter condition error\n")
                } else {
                    cat(
                        sprintf(
                            paste0(
                                "OK: Filter by %s (%s) returned %g unique ",
                                "pathway(s)\n"
                            ),
                            filter,
                            condition,
                            n
                        )
                    )
                }
            } else {
                cat(
                    sprintf(
                        paste0(
                            "WARNING: Filter by %s (%s) not specified ",
                            "correctly; this filter is not applied\n"
                        ),
                        filter,
                        condition
                    )
                )
            }
        }

    ## --------------- ##
    ## Main Code Block ##
    ## --------------- ##

    # translate filters to column names
    filterInput_byScore <- switch(
        enrichment_score_filter,
        "NES (Normalized Enrichment Score)" = "NES",
        "ES (Enrichment Score)" = "ES"
    )
    filterInput_byPvalue <- switch(
        p_value_filter,
        "raw p-value" = "pval",
        "p-value" = "pval",  # legacy support
        "adjusted p-value" = "padj",
        "nominal p-value" = "pval",  # alternative naming
        stop(sprintf("Unknown p_value_filter: '%s'. Expected 'raw p-value', 'adjusted p-value', or 'nominal p-value'", p_value_filter))
    )

    if (!is.null(genes_to_include)) {
        if (gene_filter_universe == "Leading Edge (LE)") {
            available_genes <- unique(trimws(unlist(strsplit(
                gsea_table$leadingEdge,
                split = ","
            ))))
        } else {
            available_genes <- unique(trimws(unlist(strsplit(
                gsea_table$inPathway,
                split = ","
            ))))
        }
        found_genes <- genes_to_include[genes_to_include %in% available_genes]
        missing_genes <- genes_to_include[
            !genes_to_include %in% available_genes
        ]
        if (!any(genes_to_include %in% available_genes)) {
            stop(sprintf(
                paste0(
                    "ERROR:\n\n",
                    "Requested 'Genes to Include' are not found in the input GSEA Table.\n\n",
                    "Not found genes:\n%s\n\n"
                ),
                paste(missing_genes, collapse = "\n")
            ))
        } else if (!all(genes_to_include %in% available_genes)) {
            stop(sprintf(
                paste0(
                    "ERROR:\n\n",
                    "Some of the requested 'Genes to Include' are not found in the input GSEA Table.\n\n",
                    "Not found genes:\n%s\n\n",
                    "Found genes:\n%s\n\n"
                ),
                paste(missing_genes, collapse = "\n"),
                paste(found_genes, collapse = "\n")
            ))
        }
    }

    ## apply filters
    cat("\n\nFiltering steps\n\n")

    gsea_filtered <- gsea_table %>%
        dplyr::filter(get(filterInput_byPvalue) <= p_value_threshold)
    filter.message(
        filter = p_value_filter,
        condition = p_value_threshold,
        output = gsea_filtered
    )

    if (enrichment_score_sign == "+") {
        gsea_filtered <- gsea_filtered %>%
            dplyr::filter(
                get(filterInput_byScore) >= enrichment_score_threshold
            )
        filter.message(
            filter = "value of GSEA score",
            condition = sprintf(
                "%s > %g",
                filterInput_byScore,
                enrichment_score_threshold
            ),
            output = gsea_filtered
        )
    } else if (enrichment_score_sign == "-") {
        gsea_filtered <- gsea_filtered %>%
            dplyr::filter(
                get(filterInput_byScore) <= -enrichment_score_threshold
            )
        filter.message(
            filter = "value of GSEA score",
            condition = sprintf(
                "%s < %s%g",
                filterInput_byScore,
                ifelse(enrichment_score_threshold == 0, "", "-"),
                enrichment_score_threshold
            ),
            output = gsea_filtered
        )
    } else {
        gsea_filtered <-
            gsea_filtered %>%
            dplyr::filter(
                abs(get(filterInput_byScore)) >= enrichment_score_threshold
            )
        filter.message(
            filter = "value of GSEA score",
            condition = sprintf(
                "|%s| > %g",
                filterInput_byScore,
                enrichment_score_threshold
            ),
            output = gsea_filtered
        )
    }

    if (size_cutoff > 0) {
        if (size_filter == "Pathway size") {
            gsea_filtered <-
                gsea_filtered %>% dplyr::filter(size >= size_cutoff)
            filter.message(
                filter = size_filter,
                condition = sprintf(">%g", size_cutoff),
                output = gsea_filtered
            )
        } else {
            gsea_filtered <-
                gsea_filtered %>% dplyr::filter(size_leadingEdge >= size_cutoff)
            filter.message(
                filter = size_filter,
                condition = size_cutoff,
                output = gsea_filtered
            )
        }
    } else {
        filter.message(
            filter = size_filter,
            condition = paste0(">", size_cutoff),
            output = gsea_filtered
        )
    }

    if (!is.null(collections_to_include)) {
        gsea_filtered <-
            gsea_filtered %>%
            dplyr::filter(collection %in% collections_to_include)
        filter.message(
            filter = "Collection filter ON",
            condition = "Collections to include",
            output = gsea_filtered
        )
        cat(sprintf(
            "    Found collections: %s\n",
            paste(
                unique(gsea_filtered$collection),
                collapse = ", "
            )
        ))
    }

    if (!is.null(pathways_to_include)) {
        gsea_filtered <-
            gsea_filtered %>% dplyr::filter(pathway %in% pathways_to_include)
        filter.message(
            filter = "Pathway filter ON",
            condition = "Pathways to include",
            output = gsea_filtered
        )
        cat(sprintf(
            "    Found pathways: %s\n",
            paste(
                unique(gsea_filtered$pathway),
                collapse = ", "
            )
        ))
    }

    if (!is.null(genes_to_include)) {
        if (gene_filter_universe == "Leading Edge (LE)") {
            index_pathway <- lapply(genes_to_include, function(x) {
                grep(paste0("\\b\\Q", x, "\\E\\b"), gsea_filtered$leadingEdge)
            })
            found <- sapply(index_pathway, function(x) {
                length(x) > 0
            })
            index_pathway <- Reduce(union, index_pathway)
            gsea_filtered <- gsea_filtered %>% dplyr::slice(index_pathway)

            filter.message(
                filter = "Gene filter ON",
                condition = "Leading Edge",
                output = gsea_filtered
            )
            cat(sprintf(
                "    Found genes: %s\n",
                paste(genes_to_include[which(found)], collapse = ", ")
            ))
            if (sum(!found) > 0) {
                cat(sprintf(
                    "    Missing genes: %s\n",
                    paste(genes_to_include[which(!found)], collapse = ", ")
                ))
            }
        } else if (gene_filter_universe == "Pathway") {
            if (!"inPathway" %in% colnames(gsea_filtered)) {
                stop(
                    paste0(
                        "'inPathway' column not present in the input GSEA ",
                        "Table;\n\nchange change 'Gene Filter Universe' to ",
                        " 'Leading Edge (LE)'\nor run the latest 'GSEA ",
                        "Preranked [CCBR]' template to provide 'inPathway' ",
                        "column with the input GSEA Table"
                    )
                )
            } else {
                index_pathway <- lapply(genes_to_include, function(x) {
                    grep(paste0("\\b\\Q", x, "\\E\\b"), gsea_filtered$inPathway)
                })
                found <- sapply(index_pathway, function(x) {
                    length(x) > 0
                })
                index_pathway <- Reduce(union, index_pathway)
                gsea_filtered <- gsea_filtered %>% dplyr::slice(index_pathway)

                filter.message(
                    filter = "Gene filter ON",
                    condition = "in Pathway",
                    output = gsea_filtered
                )
                cat(sprintf(
                    "    Found genes: %s\n",
                    paste(genes_to_include[which(found)], collapse = ", ")
                ))
                if (sum(!found) > 0) {
                    cat(sprintf(
                        "    Missing genes: %s\n",
                        paste(genes_to_include[which(!found)], collapse = ", ")
                    ))
                }
            }
        }
    }

    if (contrast_filter == "remove") {
        if (!is.null(contrasts)) {
            all_contrasts <- unique(gsea_filtered$contrast)
            gsea_filtered <-
                gsea_filtered %>% dplyr::filter(!contrast %in% contrasts)
            removed <- setdiff(all_contrasts, unique(gsea_filtered$contrast))
            if (length(removed) < 1) {
                filter.message(
                    warn = TRUE,
                    filter = "Contrast filter",
                    condition = sprintf(
                        "remove %s missing",
                        paste(contrasts, collapse = ", ")
                    ),
                    output = gsea_filtered
                )
            } else {
                filter.message(
                    filter = "Contrast filter",
                    condition = contrast_filter,
                    output = gsea_filtered
                )
                cat(sprintf(
                    "    Removed contrast(s): %s\n",
                    paste(removed, collapse = ", ")
                ))
                cat(sprintf(
                    "    Keep contrast(s): %s\n",
                    paste(
                        unique(gsea_filtered$contrast),
                        collapse = ", "
                    )
                ))
            }
        } else if (is.null(contrasts)) {
            filter.message(
                warn = TRUE,
                filter = "Contrast filter",
                condition = class(contrasts),
                output = gsea_filtered
            )
        }
    } else if (contrast_filter == "keep") {
        if (!is.null(contrasts)) {
            all_contrasts <- unique(gsea_filtered$contrast)
            gsea_filtered <-
                gsea_filtered %>% dplyr::filter(contrast %in% contrasts)
            kept <- intersect(all_contrasts, unique(gsea_filtered$contrast))
            removed <- setdiff(all_contrasts, unique(gsea_filtered$contrast))
            if (length(kept) < 1) {
                filter.message(
                    warn = TRUE,
                    filter = "Contrast filter",
                    condition = sprintf(
                        "keep %s missing",
                        paste(contrasts, collapse = ", ")
                    ),
                    output = gsea_filtered
                )
            } else {
                filter.message(
                    filter = "Contrast filter",
                    condition = contrast_filter,
                    output = gsea_filtered
                )
                cat(sprintf(
                    "    Removed contrast(s): %s\n",
                    paste(removed, collapse = ", ")
                ))
                cat(sprintf(
                    "    Kept contrast(s): %s\n",
                    paste(
                        unique(gsea_filtered$contrast),
                        collapse = ", "
                    )
                ))
            }
        } else if (is.null(contrasts)) {
            filter.message(
                warn = TRUE,
                filter = "Contrast filter",
                condition = class(contrasts),
                output = gsea_filtered
            )
        }
    } else if (contrast_filter == "none") {
        if (!is.null(contrasts)) {
            filter.message(
                warn = TRUE,
                filter = "Contrast filter",
                condition = sprintf(
                    "none; %s",
                    paste(contrasts, collapse = ", ")
                ),
                output = gsea_filtered
            )
        }
    }

    top_rank_filter <- tolower(top_rank_filter)

    if (top_rank_filter == "all") {
        filterInput_keep <- paste("Inf (ALL)")
        top_rank_filter <- Inf
    } else {
        top_rank_filter <- as.numeric(top_rank_filter)

        if (is.na(top_rank_filter)) {
            stop(
                paste0(
                    "ERROR in Top rank filter; enter ALL (case ",
                    "insensitive) or a numeric rank.\n"
                )
            )
        } else if (top_rank_filter <= 0) {
            top_rank_filter <- 1
            cat(
                paste0(
                    "WARNING: 'Top rank filter' cannot be 0 or less; its ",
                    "value was changed to 1.\n"
                )
            )
        }
        filterInput_keep <- top_rank_filter
    }

    gsea_filtered <-
        gsea_filtered %>%
        dplyr::group_by(contrast, collection) %>%
        dplyr::mutate(p_rank = rank(pval, ties.method = "min")) %>%
        dplyr::filter(p_rank <= top_rank_filter) %>%
        dplyr::select(-p_rank)
    filter.message(
        filter = "Top significant filter",
        condition = sprintf(
            "up to p-value rank of %s per contrast and collection",
            filterInput_keep
        ),
        output = gsea_filtered
    )

    # OUTPUT ====

    ## sort output
    # Modern dplyr: use arrange with pick() and conditional desc()
    if (sort_output_in_decreasing_order) {
        gsea_filtered <- gsea_filtered %>%
            dplyr::arrange(dplyr::desc(dplyr::pick(dplyr::all_of(columns_to_sort_output_by))))
    } else {
        gsea_filtered <- gsea_filtered %>%
            dplyr::arrange(dplyr::pick(dplyr::all_of(columns_to_sort_output_by)))
    }

    ## do plot and return dataset

    if (nrow(gsea_filtered) == 0) {
        stop("ERROR: filtering returned 0 pathways")
    } else {
        cat("\n\nFiltered pathways\n")
        tab <- table(gsea_filtered$collection, gsea_filtered$contrast) %>%
            addmargins(
                margin = c(1, 2)
            )
        print(tab)

        cat("\n\nGSEA statistics (filtered pathways)\n\n")
        print(tibble(gsea_filtered))

        return(gsea_filtered)
    }
}

## ---------------------------- ##
## Global Imports and Functions ##
## ---------------------------- ##

## Functions defined here will be available to call in
## the code for any table.

## --------------- ##
## End of Template ##
## --------------- ##
