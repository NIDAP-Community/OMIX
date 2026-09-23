#' GSVA - Sugarloaf V2 [CCBR] [scRNA-seq] [Bulk] [Beta]
#'
#' @description
#' A template that performs Gene Set Variation Analysis or GSVA. *This template
#' is a Beta version and is undergoing active development. If you encounter
#' problems, please contact CCBR* NCICCBRNIDAP@@mail.nih.gov. By default, the
#' template uses the Broad Institute MSigDB v2023.2 database as the gene set
#' source.
#'
#' @details
#' Contact CCBR at \email{NCICCBRNIDAP@@mail.nih.gov} if you encounter problems.
#'
#' @param normalized_data A data frame.
#' @param sample_metadata_table A data frame. Sample metadata table.
#' @param pathways_database
#' A data frame. Dataset containing gene set membership information, listing
#' genes in separate rows for each gene set. By default, the GSEA MSigDB
#' v2023.2 [CCBR] NIDAP dataset (MSigDB v2023.2 human and mouse collections)
#' is imported with the template. If a custom gene set database is used, the
#' following columns are required: collection, gene_set_name, gene_symbol,
#' species, and optionally pathways_database (the database name and version,
#' e.g., MSigDB_v2023)
#' @param gene_column Character. Gene name column in the normalized data.
#' @param sample_name_column Character. Column containing sample name.
#' @param samples_to_include Character vector.
#' @param species
#' Character. One of \code{Dog}, \code{Drosophila}, \code{Chimpanzee},
#' \code{Human}, \code{Macaque}, \code{Mouse}, \code{Rabbit}, \code{Rat},
#' \code{Zebrafish}. Gene annotation species in the Normalized Data. Default:
#' \code{Human}.
#' @param database_species
#' Character. One of \code{Human}, \code{Mouse}. Gene annotation species in
#' the Pathways Database dataset. Default: \code{Human}.
#' @param collections_to_include
#' Character. Collections from the pathways database to include in the
#' analysis. Default: \code{c("H: hallmark gene sets")}.
#' @param custom_pathways_database
#' Logical. Set to TRUE for custom species in the Pathways Database. FALSE by
#' default. Default: \code{FALSE}.
#' @param custom_species
#' Character. One of \code{Dog}, \code{Drosophila}, \code{Chimpanzee},
#' \code{Human}, \code{Macaque}, \code{Mouse}, \code{Rabbit}, \code{Rat},
#' \code{Zebrafish}. Gene annotation species in the custom Pathways Database.
#' Default: \code{Mouse}.
#' @param method
#' Character. One of \code{gsva}, \code{ssgsea}, \code{zscore}, \code{plage}.
#' Default: \code{gsva}.
#' @param minimum_geneset_size Numeric. Minimum size geneset.
#' @param maximum_geneset_size
#' Numeric. maximum size of geneset to test Default: \code{1200}.
#' @param update_genes
#' Logical. If TRUE, update gene symbols in both the counts matrix and the
#' gene sets using \code{l2psupp::updategenes} (Human) or
#' \code{l2psupp::o2o} (other species) before running GSVA. Default:
#' \code{TRUE}.
#' @param display_warnings
#' Numeric. Set to 0 if you want warnings to appear in the Logs output tab;
#' default is set to -1 which mutes the warnings Default: \code{-1}.
#' @param normalized_data_file Optional file path for normalized_data.
#' @param sample_metadata_file Optional file path for sample_metadata_table.
#' @param pathways_database_file Optional file path for pathways_database.
#' @param input_delim Delimiter used when reading input files. Default: "\t".
#' @param export_results_file Optional CSV path for GSVA table output.
#' @param export_plot_file Optional PNG path for GSVA heatmap output.
#' @param export_plot_width Plot width in inches for PNG output.
#' @param export_plot_height Plot height in inches for PNG output.
#'
#' @return
#' A data frame of GSVA enrichment scores (gene sets x samples) with a
#' leading Geneset column.
#'
run_gsva <- function(
  normalized_data = NULL,
  sample_metadata_table = NULL,
  pathways_database = NULL,
  gene_column,
  sample_name_column,
  samples_to_include,
  species = "Human",
  database_species = "Human",
  collections_to_include = c("H: hallmark gene sets"),
  custom_pathways_database = FALSE,
  custom_species = "Mouse",
  method = "gsva",
  minimum_geneset_size = 15,
  maximum_geneset_size = 1200,
  update_genes = TRUE,
  display_warnings = -1,
  normalized_data_file = NULL,
  sample_metadata_file = NULL,
  pathways_database_file = NULL,
  input_delim = "\t",
  export_results_file = file.path(getwd(), "gsva_v1_results.csv"),
  export_plot_file = file.path(getwd(), "gsva_v1_heatmap.png"),
  export_plot_width = 12,
  export_plot_height = 10
) {
  old_warn <- getOption("warn")
  on.exit(options(warn = old_warn), add = TRUE)
  options(warn = display_warnings)

  ## --------- ##
  ## Libraries ##
  ## --------- ##
  library(dplyr)
  library(GSVA)
  library(l2psupp)
  library(stringr)
  library(tibble)
  ## -------------------------------- ##
  ## User-Defined Template Parameters ##
  ## -------------------------------- ##

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

  normalized_data <- read_input_table(
    normalized_data,
    normalized_data_file,
    input_delim
  )
  sample_metadata_table <- read_input_table(
    sample_metadata_table,
    sample_metadata_file,
    input_delim
  )
  pathways_database <- read_input_table(
    pathways_database,
    pathways_database_file,
    input_delim
  )

  if (is.null(normalized_data)) {
    stop("ERROR: `normalized_data` is required.")
  }
  if (is.null(sample_metadata_table)) {
    stop("ERROR: `sample_metadata_table` is required.")
  }
  if (is.null(pathways_database)) {
    stop("ERROR: `pathways_database` is required.")
  }

  required_norm_cols <- c(gene_column, samples_to_include)
  missing_norm_cols <- setdiff(required_norm_cols, colnames(normalized_data))
  if (length(missing_norm_cols) > 0) {
    stop(sprintf(
      "ERROR: Missing columns in normalized_data: %s",
      paste(missing_norm_cols, collapse = ", ")
    ))
  }

  required_meta_cols <- c(sample_name_column)
  missing_meta_cols <- setdiff(
    required_meta_cols,
    colnames(sample_metadata_table)
  )
  if (length(missing_meta_cols) > 0) {
    stop(sprintf(
      "ERROR: Missing columns in sample_metadata_table: %s",
      paste(missing_meta_cols, collapse = ", ")
    ))
  }

  required_path_cols <- c(
    "collection",
    "gene_set_name",
    "gene_symbol",
    "species"
  )
  if (!all(required_path_cols %in% colnames(pathways_database))) {
    missing_path_cols <- setdiff(
      required_path_cols,
      colnames(pathways_database)
    )
    stop(sprintf(
      "ERROR: Missing columns in pathways_database: %s",
      paste(missing_path_cols, collapse = ", ")
    ))
  }

  ## --------------------------------- ##
  ## Parameter Misspecification Errors ##
  ## --------------------------------- ##

  if (custom_pathways_database) {
    collection_species <- custom_species
  } else {
    collection_species <- database_species
  }

  available_species <- pathways_database %>%
    dplyr::distinct(species) %>%
    dplyr::pull(species)

  if (!collection_species %in% available_species) {
    stop(sprintf(
      paste0(
        "\nERROR: %s species not found in the Pathways Database\n",
        "available species: %s\n"
      ),
      collection_species,
      paste(available_species, collapse = ", ")
    ))
  }

  # Stop if selected collections are not all found in pathways_database.
  available_collections <- pathways_database %>%
    dplyr::filter(species == collection_species) %>%
    dplyr::distinct(collection) %>%
    dplyr::pull(collection)

  if (!any(collections_to_include %in% available_collections)) {
    stop(sprintf(
      paste0(
        "ERROR:\n\n%s Pathways Database does not have the selected ",
        "Collections to Include.\n\nNot found collections are:\n%s\n\n",
        "Available collections are:\n%s"
      ),
      collection_species,
      paste(collections_to_include, collapse = "\n"),
      paste(available_collections, collapse = "\n")
    ))
  } else if (!all(collections_to_include %in% available_collections)) {
    wrong_collections <- setdiff(collections_to_include, available_collections)
    stop(sprintf(
      paste0(
        "ERROR:\n\n%s Pathways Database does not have some selected ",
        "Collections to Include.\n\nNot found collections are:\n%s\n\n",
        "Available collections are:\n%s"
      ),
      collection_species,
      paste(wrong_collections, collapse = "\n"),
      paste(available_collections, collapse = "\n")
    ))
  }

  #####################
  ##     Functions   ##
  #####################

  updategenenames <- function(genes, species) {
    species <- tolower(species)
    if (species == "human") {
      new_genes <- sapply(genes, function(x) l2psupp::updategenes(x, trust = 1))
    } else {
      new_genes <- sapply(
        genes,
        function(x) l2psupp::o2o(x, species, "human")[1]
      )
    }
    new_genes
  }

  #####################
  ## Main Code Block ##
  #####################

  ## Pathways database selection
  pathways_database <- pathways_database %>%
    dplyr::filter(species == collection_species) %>%
    dplyr::filter(collection %in% collections_to_include)

  pathways_database <-
    pathways_database %>%
    dplyr::group_by(collection, gene_set_name) %>%
    dplyr::summarize(
      gene_symbol = as.list(strsplit(
        paste0(
          unique(gene_symbol),
          collapse = " "
        ),
        " "
      )),
      .groups = "drop"
    )
  geneset_list <- pathways_database$gene_symbol
  names(geneset_list) <- pathways_database$gene_set_name

  ## Select samples to run and initiate es.mat (data.frame)
  samples_to_include <- samples_to_include[!samples_to_include %in% gene_column]
  es.mat <-
    normalized_data %>% dplyr::select(gene_column, samples_to_include)

  ## Map orthologs if necessary and formates.mat as matrix for GSVA run.
  need_ortholog <- ifelse(species == collection_species, FALSE, TRUE)
  if (need_ortholog) {
    list_orthologs <-
      lapply(es.mat[, gene_column], o2o, species, collection_species)
    names(list_orthologs) <- es.mat[, gene_column]
    gene_to_many <- list_orthologs[sapply(list_orthologs, length) > 1]
    no_ortho <- sum(sapply(list_orthologs, length) == 0)
    gene_to_unique <- sum(sapply(list_orthologs, length) == 1)
    if (no_ortho > 0) {
      cat(
        sprintf(
          "\n%g of %s genes have no %s ortholog\n",
          no_ortho,
          species,
          collection_species
        )
      )
    }
    if (length(gene_to_many) > 0) {
      cat(
        sprintf(
          paste0(
            "%g of %s genes have more than one %s ortholog; ",
            "one ortholog was selected by random for each\n"
          ),
          length(gene_to_many),
          species,
          collection_species
        )
      )
    }
    cat(
      sprintf(
        "%g of %s genes were mapped uniquely to a %s ortholog\n",
        gene_to_unique,
        species,
        collection_species
      )
    )
    ortholog <- lapply(list_orthologs, function(x) {
      x[1]
    })
    ortholog <-
      stats::setNames(data.frame(do.call(rbind, ortholog)), "Ortholog") %>%
      rownames_to_column("Gene")
    exist_ortholog <-
      ortholog %>%
      dplyr::filter(!is.na(Ortholog)) %>%
      group_by(Ortholog)
    ortho_to_many <- sum(dplyr::count(exist_ortholog)$n > 1)
    if (length(ortho_to_many) > 0) {
      cat(
        sprintf(
          paste0(
            "%g of %s orthologs mapped to more than one %s gene; ",
            "one gene was selected by random for each\n"
          ),
          ortho_to_many,
          collection_species,
          species
        )
      )
    }
    exist_ortholog <-
      exist_ortholog %>%
      filter(row_number() == 1) %>%
      ungroup()
    cat(
      sprintf(
        paste0(
          "%g genes were mapped between %s and %s and ",
          "will be used in the GSVA analysis\n\n"
        ),
        nrow(exist_ortholog),
        species,
        collection_species
      )
    )
    es.mat <-
      dplyr::inner_join(
        es.mat,
        exist_ortholog,
        by = stats::setNames(gene_column, "Gene")
      ) %>%
      dplyr::select("Ortholog", everything(), -gene_column)
    es.mat <-
      es.mat %>%
      column_to_rownames("Ortholog") %>%
      as.matrix()
  } else {
    es.mat <-
      es.mat %>%
      column_to_rownames(gene_column) %>%
      as.matrix()
  }

  ## Optionally update gene names using l2psupp.
  if (update_genes) {
    ## Update counts matrix gene symbols.
    counts_map <- updategenenames(rownames(es.mat), collection_species)
    valid <- !is.na(counts_map)
    rownames(es.mat)[valid] <- counts_map[valid]
    es.mat <- es.mat[!duplicated(rownames(es.mat)), , drop = FALSE]

    ## Update geneset gene symbols independently (includes genes absent from
    ## counts that would be missed if only the counts map were used).
    all_geneset_genes <- unique(unlist(geneset_list))
    geneset_map <- updategenenames(all_geneset_genes, collection_species)
    geneset_list <- lapply(geneset_list, function(genes) {
      mapped <- geneset_map[genes]
      genes[!is.na(mapped)] <- mapped[!is.na(mapped)]
      genes
    })
  }

  ## Match sample names with metadata.
  sample_metadata_table <- sample_metadata_table[
    match(colnames(es.mat), sample_metadata_table[[sample_name_column]]),
  ]

  ## Count pathways filtered out based on the minimum and maximum geneset size.
  geneset_list_mapped <-
    lapply(geneset_list, function(x) {
      x[x %in% rownames(es.mat)]
    })
  ## Print number of genesets smaller than minimum:
  l <- sapply(geneset_list_mapped, length) < minimum_geneset_size
  if (any(l)) {
    smallsets <- names(geneset_list_mapped[l])
    cat(sprintf(
      "Genesets smaller than minimum size, not run: %g gene set(s)\n\n",
      length(smallsets)
    ))
  }

  ## Print number of genesets larger than maximum:
  m <- sapply(geneset_list_mapped, length) > maximum_geneset_size
  if (any(m)) {
    bigsets <- names(geneset_list_mapped[m])
    cat(sprintf(
      "Genesets larger than maximum size, not run: %g gene set(s)\n\n",
      length(bigsets)
    ))
  }

  ## Run GSVA and format results.
  method <- tolower(method)
  valid_methods <- c("gsva", "ssgsea", "zscore", "plage")
  if (!method %in% valid_methods) {
    stop(sprintf(
      "ERROR: `method` must be one of: %s",
      paste(valid_methods, collapse = ", ")
    ))
  }

  if (exists("gsvaParam", where = asNamespace("GSVA"), mode = "function")) {
    param_fn <- switch(
      method,
      gsva = GSVA::gsvaParam,
      ssgsea = GSVA::ssgseaParam,
      zscore = GSVA::zscoreParam,
      plage = GSVA::plageParam
    )
    gsva_param <- param_fn(
      exprData = es.mat,
      geneSets = geneset_list,
      minSize = minimum_geneset_size,
      maxSize = maximum_geneset_size
    )
    df.gsva <- GSVA::gsva(gsva_param, verbose = FALSE)
  } else {
    df.gsva <- GSVA::gsva(
      es.mat,
      geneset_list,
      method = method,
      min.sz = minimum_geneset_size,
      max.sz = maximum_geneset_size
    )
  }
  gsva.df <- as.data.frame(df.gsva) %>% rownames_to_column("Geneset")

  if (!is.null(export_results_file) && nzchar(export_results_file)) {
    utils::write.csv(gsva.df, export_results_file, row.names = FALSE)
  }

  if (!is.null(export_plot_file) && nzchar(export_plot_file)) {
    grDevices::png(
      filename = export_plot_file,
      width = export_plot_width,
      height = export_plot_height,
      units = "in",
      res = 300
    )
    stats::heatmap(
      as.matrix(df.gsva),
      scale = "row",
      cexRow = 0.6,
      cexCol = 0.8
    )
    grDevices::dev.off()
  }

  gsva.df
}

#################################################
## Global imports and functions included below ##
#################################################

# Functions defined here will be available to call in
# the code for any table.
