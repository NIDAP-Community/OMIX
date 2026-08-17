#' GSEA Preranked - Sugarloaf V2 [CCBR] [scRNA-seq] [Bulk]
#'
#' @description
#' Performs Gene Set Enrichment Analysis (GSEA). GSEA is a computational
#' technique that assesses if a predefined group of genes exhibits significant,
#' consistent differences between two biological states (e.g., phenotypes). This
#' template executes GSEA on a pre-ranked gene list, evaluating if a gene set is
#' substantially enriched at either end of the ranking. The calculation employs
#' the R Bioconductor fgsea library. By default, the template uses the Broad
#' Institute MSigDB v2023.2 database as the gene set source.
#' DUET Documentation
#'
#' @details
#' Contact CCBR at \email{NCICCBRNIDAP@@mail.nih.gov} if you encounter problems.
#'
#' @param DEG_Table
#' A data frame or file path. Dataset containing genes with their associated
#' scores for
#' ranking. For example, for the output of a differential gene expression
#' analysis (DEG Table), the score could be the log fold-change or
#' t-statistic. The required columns consist of the gene symbol column (any
#' column header) and the gene score columns (one column per each comparison
#' contrast). Gene score column names will be used to identify comparison
#' contrasts for which separate GSEA runs will be performed. The naming
#' assumes two parts of the gene score column names: the contrast name (e.g.,
#' A-B) and the gene score name (e.g., _tstat). This naming convention is used
#' in the CCBR template that produces a DEG Table (Voom Normalization & DEG
#' Analysis [Bulk] [CCBR]).
#' @param Pathways_Database
#' A data frame or file path. Dataset containing gene set membership
#' information, listing
#' genes in separate rows for each gene set. By default, the GSEA MSigDB
#' v2023.2 [CCBR] NIDAP dataset (MSigDB v2023.2 human and mouse collections)
#' is imported with the template. If a custom gene set database is used, the
#' following columns are required: collection, gene_set_name, gene_symbol,
#' species, and optionally pathways_database (the database name and version,
#' e.g., MSigDB_v2023)
#' @param Gene_Names_Column
#' Character. Gene name column in the gene score dataset
#' @param species
#' Character. One of ['Dog', 'Drosophila', 'Chimpanzee', 'Human', 'Macaque',
#' 'Mouse', 'Rabbit', 'Rat', 'Zebrafish']. Gene annotation species in the DEG
#' table.
#' @param Gene_Scores_Column_s_Suffix
#' Character. One of ['_tstat', '_logFC']. suffix in column names in columns
#' containing the score that will be used to rank the genes in descending
#' order for each identified contrast Default: \code{_tstat}.
#' @param Gene_Score_Alternative
#' Character vector. Optional. Use only if the gene scores column name you
#' wish to use does not have a suffix like one of those listed among the Gene
#' Scores Column(s) parameter choices.
#' @param Contrasts_Filter
#' Character. One of ['none', 'keep', 'remove']. if none all identified
#' contrasts will be run; if remove or keep, a subset of contrasts will be run
#' Default: \code{none}.
#' @param Contrasts
#' Character vector. if None entered all contrast will be used, otherwise
#' enter specific contrasts included in the gene score dataset to be kept or
#' removed
#' @param Pathways_Database_Species
#' Character. One of ['Human', 'Mouse']. Gene annotation species in the
#' Pathways Database dataset. Default: \code{Human}.
#' @param Collections_to_Include
#' Character. Collections from Pathways Dayabase to be included in the
#' analysis. The dropdown menu lists collections from the MSigDB Database
#' NIDAP Ontology Object. For a custom Pathways Database input dataset, type a
#' custom collection name and click "Create option" to use in this code
#' template. Default: \code{c("H: hallmark gene sets","CP:REACTOME: Reactome
#' gene sets")}.
#' @param Custom_Pathways_Database_
#' Logical. Set to TRUE for custom species in the Pathways Database. FALSE by
#' default. Default: \code{FALSE}.
#' @param Custom_Species
#' Character. One of ['Dog', 'Drosophila', 'Chimpanzee', 'Human', 'Macaque',
#' 'Mouse', 'Rabbit', 'Rat', 'Zebrafish']. Gene annotation species in the
#' custom Pathways Database. Default: \code{Mouse}.
#' @param Minimum_Gene_Set_Size
#' Numeric. Minimum size of gene sets to include Default: \code{15}.
#' @param Maximum_Gene_Set_Size
#' Numeric. Maximum gene set size to include Default: \code{500}.
#' @param FDR_Correction_Mode
#' Character. One of ['over all collections', 'within each collection'].
#' Default: \code{within each collection}.
#' @param Number_of_Permutations
#' Numeric. Number of permutations of the input preranked dataset. In general,
#' a higher number gives more accurate p-values but also increases runtime.
#' (Default: 5000) Default: \code{5000}.
#' @param Random_Seed
#' Numeric. A starting point in generating random numbers for the permutation
#' test Default: \code{246642}.
#' @param Collapse_Pathway_Redundancy
#' Logical. Uses fgsea's collapsePathways function to reduce redundancy in
#' pathway list Default: \code{FALSE}.
#' @param Sort_Output_By
#' Character. One of ['contrast', 'collection', 'pathway', 'pval', 'padj',
#' 'ES', 'NES', 'size', 'nMoreExtreme']. Sorting variables Default:
#' \code{c("pval")}.
#' @param Sort_Output_in_Decreasing_Order Logical. Default: \code{FALSE}.
#' @param Image_Width Numeric. image width in pixels Default: \code{2500}.
#' @param Image_Height Numeric. Image height in pixels Default: \code{2500}.
#' @param Image_Resolution Numeric. Image resolution (dpi) Default: \code{300}.
#' @param Display_Warnings
#' Numeric. Set to 0 if you want warnings to appear in the Logs output tab;
#' default is set to -1 which mutes the warnings Default: \code{-1}.
#'
#' @return A data frame of preranked GSEA results including NES, p-value,
#' adjusted p-value, and leading-edge genes for each gene set.
#'
#' @importFrom dplyr .
#' @importFrom fgsea .
#' @importFrom ggplot2 .
#' @importFrom tibble .
#' @importFrom data.table .
#' @importFrom patchwork .
#' @export
GSEA_Preranked <- function(
  DEG_Table,
  Pathways_Database,
  Gene_Names_Column,
  species = NULL,
  Gene_Scores_Column_s_Suffix = "_tstat",
  Gene_Score_Alternative = c(),
  Contrasts_Filter = "none",
  Contrasts = c(),
  Pathways_Database_Species = "Human",
  Collections_to_Include = c(
    "H: hallmark gene sets",
    "CP:REACTOME: Reactome gene sets"
  ),
  Custom_Pathways_Database_ = FALSE,
  Custom_Species = "Mouse",
  Minimum_Gene_Set_Size = 15,
  Maximum_Gene_Set_Size = 500,
  FDR_Correction_Mode = "within each collection",
  Number_of_Permutations = 5000,
  Random_Seed = 246642,
  Collapse_Pathway_Redundancy = FALSE,
  Sort_Output_By = c("pval"),
  Sort_Output_in_Decreasing_Order = FALSE,
  Image_Width = 2500,
  Image_Height = 2500,
  Image_Resolution = 300,
  Display_Warnings = -1
) {
  # This function calculates pre-ranked GSEA for multiple contrasts

  ## --------- ##
  ## Libraries ##
  ## --------- ##

  options(warn = Display_Warnings)
  read_input_table <- function(x, label) {
    if (is.data.frame(x)) {
      return(x)
    }

    if (is.character(x) && length(x) == 1 && file.exists(x)) {
      ext <- tolower(tools::file_ext(x))

      if (ext == "csv") {
        return(read.csv(x, stringsAsFactors = FALSE, check.names = FALSE))
      }

      if (ext %in% c("tsv", "txt")) {
        return(read.delim(x, stringsAsFactors = FALSE, check.names = FALSE))
      }

      if (ext == "rds") {
        return(as.data.frame(readRDS(x)))
      }

      if (ext %in% c("rda", "rdata")) {
        env <- new.env(parent = emptyenv())
        load(x, envir = env)
        obj_names <- ls(env)
        if (length(obj_names) == 0) {
          stop(sprintf("ERROR: %s file has no objects: %s", label, x))
        }
        candidate <- env[[obj_names[1]]]
        return(as.data.frame(candidate))
      }

      stop(sprintf(
        "ERROR: Unsupported file extension for %s: %s",
        label,
        x
      ))
    }

    stop(sprintf(
      "ERROR: %s must be a data frame or a readable file path",
      label
    ))
  }

  normalize_species_label <- function(x, label, default = NULL) {
    if (
      is.null(x) ||
        length(x) == 0 ||
        is.na(x[[1]]) ||
        !nzchar(trimws(as.character(x[[1]])))
    ) {
      if (!is.null(default)) {
        return(default)
      }
      stop(sprintf("ERROR: `%s` must be specified", label))
    }

    species_lookup <- c(
      dog = "Dog",
      drosophila = "Drosophila",
      chimpanzee = "Chimpanzee",
      human = "Human",
      macaque = "Macaque",
      mouse = "Mouse",
      rabbit = "Rabbit",
      rat = "Rat",
      zebrafish = "Zebrafish"
    )
    species_key <- tolower(trimws(as.character(x[[1]])))

    if (!species_key %in% names(species_lookup)) {
      stop(sprintf(
        "ERROR: `%s` must be one of: %s",
        label,
        paste(unname(species_lookup), collapse = ", ")
      ))
    }

    unname(species_lookup[[species_key]])
  }

  check_gene_species_case <- function(deg_table, gene_column, species) {
    if (!gene_column %in% colnames(deg_table)) {
      stop(sprintf(
        "ERROR: Gene_Names_Column `%s` was not found in DEG_Table",
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
          "DEG_Table, but `species` is set to Human. Gene symbols in `%s` ",
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
          "DEG_Table, but `species` is set to Mouse. Gene symbols in `%s` ",
          "look human-like because they are mostly all caps ",
          "(examples: %s). Rerun with `species = \"Human\"`."
        ),
        gene_column,
        examples
      ))
    }

    invisible(NULL)
  }
  ## -------------------------------- ##
  ## User-Defined Template Parameters ##
  ## -------------------------------- ##

  # Datasets
  deg_table <- read_input_table(DEG_Table, "DEG_Table")
  pathways_database <- read_input_table(
    Pathways_Database,
    "Pathways_Database"
  )
  species <- normalize_species_label(species, "species", default = "Human")

  # DEG Table Parameters
  gene_scores_column_s_suffix <- Gene_Scores_Column_s_Suffix
  gene_score_alternative <- Gene_Score_Alternative

  # Pathways Database Parameters
  collection_species <- if (Custom_Pathways_Database_) {
    Custom_Species
  } else {
    Pathways_Database_Species
  }
  collection_species <- normalize_species_label(
    collection_species,
    "Pathways_Database_Species"
  )

  # GSEA parameters
  number_of_processing_units <- 0

  # Output parameters
  sort_output_by <- Sort_Output_By

  ## --------------------------------- ##
  ## Parameter Misspecification Errors ##
  ## --------------------------------- ##

  # identify available species in pathways_database and stop if not not found
  # with collection_species; list in the log available ones
  if (!"species" %in% colnames(pathways_database)) {
    stop("ERROR: Pathways_Database must contain a `species` column")
  }
  if (!"collection" %in% colnames(pathways_database)) {
    stop("ERROR: Pathways_Database must contain a `collection` column")
  }

  available_species <- unique(pathways_database[["species"]])

  if (!collection_species %in% available_species) {
    stop(sprintf(
      paste0(
        "\nERROR:%s species not found in the Pathways Database\n",
        "available species: %s\n"
      ),
      collection_species,
      paste(available_species, collapse = ", ")
    ))
  }

  # stop if collections_to_include are not all found in pathways_database;
  # list in the log not found and available ones
  available_collections <- unique(
    pathways_database[pathways_database[["species"]] == collection_species,
      "collection",
      drop = TRUE
    ]
  )

  if (!any(Collections_to_Include %in% available_collections)) {
    stop(sprintf(
      paste0(
        "ERROR:\n\n%s Pathways Database does not have the selected ",
        "Collections to Include.\n\nNot found collections are:\n%s\n\n",
        "Available collections are:\n%s"
      ),
      collection_species,
      paste(Collections_to_Include, collapse = "\n"),
      paste(available_collections, collapse = "\n")
    ))
  } else if (!all(Collections_to_Include %in% available_collections)) {
    wrong_collections <- setdiff(Collections_to_Include, available_collections)
    stop(sprintf(
      paste0(
        "ERROR:\n\n%s Pathways Database does not have some of the selected ",
        "Collections to Include.\n\nNot found collections are:\n%s\n\n",
        "Available collections are:\n%s"
      ),
      collection_species,
      paste(wrong_collections, collapse = "\n"),
      paste(available_collections, collapse = "\n")
    ))
  }

  check_gene_species_case(deg_table, Gene_Names_Column, species)

  ## --------- ##
  ## Libraries ##
  ## --------- ##

  library(data.table)
  library(dplyr)
  library(fgsea)
  library(ggplot2)
  library(grid)
  library(gridExtra)
  library(gtable)
  library(l2psupp)
  library(patchwork)
  library(tibble)
  library(stats)

  ## --------- ##
  ## Functions ##
  ## --------- ##

  # 1# Begin run.gsea() function: will be applied to dplyr::group_by(contrast)
  run.gsea <-
    function(
      dx,
      mode,
      collections,
      db,
      minimum_size,
      maximum_size,
      number_perms,
      organism,
      Np,
      randomSeed
    ) {
      # compute gsea stats

      ranked <- dx$genescores
      names(ranked) <- dx$gene_id
      db$inPathway <- sapply(db$gene_symbol, function(x) {
        paste(sort(x[x %in% names(ranked)]), collapse = ",")
      })

      if (mode == "over all collections") {
        set.seed(randomSeed)
        gsea <-
          fgsea(
            pathways = collections,
            stats = ranked,
            minSize = minimum_size,
            maxSize = maximum_size,
            nperm = number_perms,
            nproc = Np
          )
        gsea$size_leadingEdge <- sapply(gsea$leadingEdge, length)
        gsea$fraction_leadingEdge <- gsea$size_leadingEdge / gsea$size
        gsea$leadingEdge <-
          sapply(gsea$leadingEdge, function(x) {
            paste(x, collapse = ",")
          })
        gsea <-
          dplyr::inner_join(
            gsea,
            select(db, pathways_database, collection, gene_set_name, inPathway),
            by = c("pathway" = "gene_set_name")
          ) %>%
          dplyr::select(pathways_database, collection, dplyr::everything())
      } else {
        included_collections <-
          stats::setNames(unique(db$collection), unique(db$collection))
        gsea <- lapply(included_collections, function(x) {
          set.seed(randomSeed)
          gsea_collection <- fgsea(
            pathways = collections[
              names(collections) %in%
                dplyr::filter(db, collection == x)$gene_set_name
            ],
            stats = ranked,
            minSize = minimum_size,
            maxSize = maximum_size,
            nperm = number_perms,
            nproc = Np
          )
          gsea_collection$size_leadingEdge <-
            sapply(gsea_collection$leadingEdge, length)
          gsea_collection$fraction_leadingEdge <-
            gsea_collection$size_leadingEdge / gsea_collection$size
          gsea_collection$leadingEdge <-
            sapply(gsea_collection$leadingEdge, function(x) {
              paste(x, collapse = ",")
            })
          return(
            dplyr::inner_join(
              gsea_collection,
              select(
                db,
                pathways_database,
                collection,
                gene_set_name,
                inPathway
              ) %>%
                filter(collection == x),
              by = c("pathway" = "gene_set_name")
            ) %>%
              dplyr::select(pathways_database, collection, dplyr::everything())
          )
        }) %>%
          dplyr::bind_rows()
      }
      gsea$species <- organism
      return(gsea)
    } # End run.gsea() function

  # 2# Begin edit fgsea::collapsePathways() that is add nproc argument and
  # set.seed() for fgsea runs
  collapsePathways <-
    function(
      fgseaRes,
      pathways,
      stats,
      pval.threshold = 0.05,
      nperm = 10 / pval.threshold,
      Nproc,
      gseaParam = 1,
      rSeed
    ) {
      universe <- names(stats)
      pathways <- pathways[fgseaRes$pathway]
      pathways <- lapply(pathways, intersect, universe)
      parentPathways <-
        stats::setNames(rep(NA, length(pathways)), names(pathways))
      for (i in seq_along(pathways)) {
        p <- names(pathways)[i]
        if (!is.na(parentPathways[p])) {
          next
        }
        pathwaysToCheck <- setdiff(
          names(which(is.na(parentPathways))),
          p
        )
        if (length(pathwaysToCheck) == 0) {
          break
        }
        minPval <- stats::setNames(
          rep(1, length(pathwaysToCheck)),
          pathwaysToCheck
        )
        u1 <- setdiff(universe, pathways[[p]])

        set.seed(rSeed)
        fgseaRes1 <- fgsea(
          pathways = pathways[pathwaysToCheck],
          stats = stats[u1],
          nperm = nperm,
          maxSize = length(u1) -
            1,
          nproc = Nproc,
          gseaParam = gseaParam
        )
        minPval[fgseaRes1$pathway] <- pmin(
          minPval[fgseaRes1$pathway],
          fgseaRes1$pval
        )
        u2 <- pathways[[p]]

        set.seed(rSeed)
        fgseaRes2 <- fgsea(
          pathways = pathways[pathwaysToCheck],
          stats = stats[u2],
          nperm = nperm,
          maxSize = length(u2) -
            1,
          nproc = Nproc,
          gseaParam = gseaParam
        )
        minPval[fgseaRes2$pathway] <- pmin(
          minPval[fgseaRes2$pathway],
          fgseaRes2$pval
        )
        parentPathways[names(which(minPval > pval.threshold))] <- p
      }
      return(list(
        mainPathways = names(which(is.na(parentPathways))),
        parentPathways = parentPathways
      ))
    } # End collapsePathways() edit

  # 3# Begin collapse.gsea() function (from Matt Angel's code)
  collapse.gsea <- function(grp, dx, collections, Np, randomSeed) {
    # filter ranked variable
    temp <- dx %>% filter(contrast %in% grp$contrast)
    ranked <- temp$genescores
    names(ranked) <- temp$gene_id

    # collapse function
    run.collapse <-
      function(cp.input, pvalue, collections, ranked, Nprocs, rS) {
        collapsedPathways <-
          collapsePathways(
            as.data.table(cp.input),
            collections,
            ranked,
            pval.threshold = pvalue,
            Nproc = Nprocs,
            rSeed = rS
          ) # requires the data.table library
        return(data.frame(pathway = collapsedPathways$mainPathways))
      }
    filter_gsea <- grp %>%
      dplyr::filter(pval < 0.05) %>%
      dplyr::arrange(pval) %>%
      dplyr::group_by(collection)
    collapsedResults <- dplyr::group_modify(
      filter_gsea,
      ~ run.collapse(
        .,
        pvalue = 0.05,
        collections = collections,
        ranked = ranked,
        Nprocs = Np,
        rS = randomSeed
      )
    ) %>%
      dplyr::ungroup()
    out <-
      grp %>%
      dplyr::inner_join(
        collapsedResults,
        by = c("pathway" = "pathway", "collection" = "collection")
      )

    return(out)
  } # End collapse.gsea() function

  # 4# Begin table.pvalue() pvalue cutoffs table
  table.pvalue <- function(gsea) {
    cuts <- c(-Inf, 1e-04, 0.001, 0.005, 0.01, 0.025, 0.05, 0.1, 1)
    cutsLab <- paste("<", cuts[-1], sep = "")
    p <- cumsum(table(
      cut(
        gsea$pval,
        breaks = cuts,
        labels = cutsLab,
        include.lowest = FALSE,
        right = TRUE
      )
    ))
    q <- cumsum(table(
      cut(
        gsea$padj,
        breaks = cuts,
        labels = cutsLab,
        include.lowest = FALSE,
        right = TRUE
      )
    ))
    tab <- data.frame(cutsLab, p, q)
    colnames(tab) <- c("alpha", "p-value", "*adjusted\np-value")
    rownames(tab) <- NULL
    return(tab)
  } # End table.pvalue() function

  # 5# Begin plot.table() pvalue cutoffs table
  plot.table <- function(dtab, score) {
    contrast_name <- unique(dtab$contrast)
    if (length(contrast_name) == 0) {
      contrast_name <- "NA"
    }
    title <-
      textGrob(paste0(contrast_name, score), gp = gpar(fontsize = 10))
    tab <- dtab %>%
      dplyr::select(-contrast)
    if (nrow(tab) == 0 || ncol(tab) == 0) {
      return(wrap_elements(title))
    }
    tab <- as.data.frame(tab, stringsAsFactors = FALSE)
    table <-
      tableGrob(
        tab,
        theme = ttheme_default(
          core = list(fg_params = list(cex = 0.9)),
          colhead = list(fg_params = list(cex = 0.9, parse = FALSE)),
          rowhead = list(fg_params = list(cex = 0.6))
        )
      )
    table <-
      gtable_add_rows(
        table,
        heights = grobHeight(title) + unit(2, "line"),
        pos = 0
      )
    table <-
      gtable_add_grob(
        table,
        list(title),
        t = c(1),
        l = c(1),
        r = ncol(table)
      )
    wrap_elements(table)
  } # End plot.table() function

  # 6# Begin species.genes() returning back gene symbols after running GSEA
  # with orthologs
  species.genes <- function(dx = gsea, map = exist_ortholog) {
    map <- data.frame(map)
    leadingEdge_orthologs <- dx$leadingEdge
    inPathway_orthologs <- dx$inPathway
    ltmp <- as.list(dx$leadingEdge)
    ltmp <- lapply(ltmp, function(x) {
      orthogenes <- unlist(strsplit(x, ","))
      genes <- map[, Gene_Names_Column][match(orthogenes, map$Ortholog)]
      paste(genes, collapse = ",")
    })
    leadingEdge <- do.call(rbind, ltmp)
    ltmp <- as.list(dx$inPathway)
    ltmp <- lapply(ltmp, function(x) {
      orthogenes <- unlist(strsplit(x, ","))
      map <- data.frame(map)
      genes <- map[, Gene_Names_Column][match(orthogenes, map$Ortholog)]
      paste(genes, collapse = ",")
    })
    inPathway <- do.call(rbind, ltmp)
    out <- data.frame(
      leadingEdge,
      inPathway,
      leadingEdge_orthologs,
      inPathway_orthologs
    )
    return(out)
  } # End species.genes() function

  # 7# Begin get.var() converting variable name (function arg) to string
  get.var <- function(var) {
    deparse(substitute(var))
  }

  ## --------------- ##
  ## Main Code Block ##
  ## --------------- ##

  ## INPUT HANDLING AND FILTERING ====

  ## pathway collection
  pathways_database <- as.data.frame(pathways_database)
  pathways_database <- pathways_database %>%
    dplyr::filter(species == collection_species) %>%
    dplyr::filter(collection %in% Collections_to_Include)
  db_unique <- pathways_database %>%
    dplyr::select(gene_set_name) %>%
    dplyr::distinct()
  db_selected <- pathways_database %>%
    dplyr::select(collection, gene_set_name) %>%
    dplyr::distinct()
  db_isDuplicated <- nrow(db_selected) > nrow(db_unique)

  if (db_isDuplicated) {
    within_collection <- db_selected %>%
      dplyr::group_by(collection) %>%
      dplyr::filter(duplicated(gene_set_name)) %>%
      dplyr::ungroup() %>%
      nrow()

    if (within_collection == 0) {
      stop(paste0(
        "ERROR: duplicated gene set names found in the 'Gene set database' ",
        "due to overlapping collections selected by the ",
        "'Collections to include' parameter"
      ))
    } else if (within_collection > 0) {
      between_collection <-
        Reduce(
          "intersect",
          split(db_selected$gene_set_name, db_selected$collection)
        ) %>%
        length()

      if (between_collection == 0) {
        stop(paste0(
          "ERROR: duplicated gene set names found in the 'Gene set database' ",
          "due to not unique gene set names within a collection"
        ))
      } else if (between_collection > 0) {
        paste0(
          "ERROR: duplicated gene set names found in the 'Gene set database' ",
          "due to overlapping collections selected by the ",
          "'Collections to include' parameter and not unique gene set names ",
          "within a collection"
        )
      }
    }
  }

  if (!"pathways_database" %in% colnames(pathways_database)) {
    pathways_database <- pathways_database %>%
      dplyr::mutate(pathways_database = get.var(Pathways_Database))
  }
  pathways_database <-
    pathways_database %>%
    dplyr::group_by(pathways_database, collection, gene_set_name) %>%
    dplyr::summarize(
      gene_symbol = as.list(strsplit(
        paste0(
          unique(gene_symbol),
          collapse = " "
        ),
        " "
      ))
    ) %>%
    dplyr::ungroup()
  geneset_list <- pathways_database$gene_symbol
  names(geneset_list) <- pathways_database$gene_set_name

  ## ranking

  if (!is.null(gene_score_alternative)) {
    if (gsub("", "", gene_score_alternative) == "") {
      stop(paste0(
        "'ERROR: Gene score alternative' parameter is empty - remove the ",
        "entry or specify it correctly'"
      ))
    }
    gene_scores_column_s_suffix <- gene_score_alternative
  }
  rank_columns <- colnames(deg_table)[grepl(
    paste0("\\Q", gene_scores_column_s_suffix, "\\E$"),
    colnames(deg_table)
  )]
  rank_contrasts <- unlist(strsplit(rank_columns, gene_scores_column_s_suffix))
  contrasts_is_empty <-
    length(Contrasts) == 0 || all(trimws(as.character(Contrasts)) == "")

  if (Contrasts_Filter == "remove") {
    if (!is.null(Contrasts)) {
      if (contrasts_is_empty) {
        stop(paste0(
          "'ERROR: Contrasts' parameter is empty - remove the entry or ",
          "specify it correctly'"
        ))
      }

      all_contrasts <- rank_contrasts
      index <- match(Contrasts, rank_contrasts)
      rank_columns <- rank_columns[-index]
      rank_contrasts <- rank_contrasts[-index]
      removed <- setdiff(all_contrasts, rank_contrasts)
      if (length(removed) < 1) {
        cat(
          sprintf(
            paste0(
              "WARNING:contrast(s) to remove (%s) not found; filter not ",
              "applied\nIdentified contrast(s) used: %s\n"
            ),
            paste(Contrasts, collapse = ", "),
            paste(rank_contrasts, collapse = ", ")
          )
        )
      } else {
        cat(sprintf(
          "Removed contrast(s): %s\n",
          paste(removed, collapse = ", ")
        ))
        cat(sprintf(
          "Kept contrast(s): %s\n",
          paste(rank_contrasts, collapse = ", ")
        ))
      }
    } else if (is.null(Contrasts)) {
      cat(
        sprintf(
          paste0(
            "WARNING:contrast(s) to remove (%s) not found; filter not ",
            "applied\nIdentified contrast(s) used: %s\n"
          ),
          paste(Contrasts, collapse = ", "),
          paste(rank_contrasts, collapse = ", ")
        )
      )
    }
  } else if (Contrasts_Filter == "keep") {
    if (!is.null(Contrasts)) {
      if (contrasts_is_empty) {
        stop(paste0(
          "'ERROR: Contrasts' parameter is empty - remove the entry or ",
          "specify it correctly'"
        ))
      }

      all_contrasts <- rank_contrasts
      index <- match(Contrasts, rank_contrasts)
      rank_columns <- rank_columns[index]
      rank_contrasts <- rank_contrasts[index]
      removed <- setdiff(all_contrasts, rank_contrasts)
      if (length(rank_contrasts) < 1) {
        cat(
          sprintf(
            paste0(
              "WARNING:contrast(s) to keep (%s) not found; filter not ",
              "applied\nIdentified contrast(s) used: %s\n"
            ),
            paste(Contrasts, collapse = ", "),
            paste(rank_contrasts, collapse = ", ")
          )
        )
      } else {
        cat(sprintf(
          "Removed contrast(s): %s\n",
          paste(removed, collapse = ", ")
        ))
        cat(sprintf(
          "Kept contrast(s): %s\n",
          paste(rank_contrasts, collapse = ", ")
        ))
      }
    } else if (is.null(Contrasts)) {
      cat(
        sprintf(
          paste0(
            "WARNING:contrast(s) to keep (%s) not found; filter not ",
            "applied\nIdentified contrast(s) used: %s\n"
          ),
          paste(Contrasts, collapse = ", "),
          paste(rank_contrasts, collapse = ", ")
        )
      )
    }
  } else if (Contrasts_Filter == "none") {
    if (!is.null(Contrasts)) {
      cat(
        sprintf(
          paste0(
            "WARNING:contrast filter not specified correctly; filter not ",
            "applied\nIdentified contrast(s) used: %s\n"
          ),
          paste(rank_contrasts, collapse = ", ")
        )
      )
    } else {
      cat(sprintf(
        'Filter contrast ("none"); Identified contrast(s) used: %s\n',
        paste(rank_contrasts, collapse = ", ")
      ))
    }
  }

  # deg table
  need_ortholog <- ifelse(species == collection_species, FALSE, TRUE)
  if (need_ortholog) {
    list_orthologs <- lapply(
      deg_table[, Gene_Names_Column],
      o2o,
      species,
      collection_species
    )
    names(list_orthologs) <- deg_table[, Gene_Names_Column]
    gene_to_many <- list_orthologs[sapply(list_orthologs, length) > 1]
    no_ortho <- sum(sapply(list_orthologs, length) == 0)
    gene_to_unique <- sum(sapply(list_orthologs, length) == 1)
    if (no_ortho > 0) {
      cat(sprintf(
        "\n%g of %s genes have no %s ortholog\n",
        no_ortho,
        species,
        collection_species
      ))
    }
    if (length(gene_to_many) > 0) {
      cat(sprintf(
        paste0(
          "%g of %s genes have more than one %s ortholog; one ortholog ",
          "was selected by random for each\n"
        ),
        length(gene_to_many),
        species,
        collection_species
      ))
    }
    cat(sprintf(
      "%g of %s genes were mapped uniquely to a %s ortholog\n",
      gene_to_unique,
      species,
      collection_species
    ))
    ortholog <- lapply(list_orthologs, function(x) {
      x[1]
    })
    ortholog <- stats::setNames(
      data.frame(do.call(rbind, ortholog)),
      "Ortholog"
    ) %>%
      rownames_to_column("Gene")
    deg_species <- dplyr::inner_join(
      deg_table,
      ortholog,
      by = stats::setNames("Gene", Gene_Names_Column)
    )
    exist_ortholog <- ortholog %>%
      dplyr::filter(!is.na(Ortholog)) %>%
      group_by(Ortholog)
    ortho_to_many <- sum(count(exist_ortholog)$n > 1)
    if (length(ortho_to_many) > 0) {
      cat(sprintf(
        paste0(
          "%g of %s orthologs mapped to more than one %s gene; one gene ",
          "was selected by random for each\n"
        ),
        ortho_to_many,
        collection_species,
        species
      ))
    }
    exist_ortholog <- exist_ortholog %>%
      filter(row_number() == 1) %>%
      ungroup()
    cat(sprintf(
      paste0(
        "%g genes were mapped between %s and %s and will be used in the ",
        "GSEA analysis\n\n"
      ),
      nrow(exist_ortholog),
      species,
      collection_species
    ))
    deg_table <- dplyr::inner_join(
      deg_table,
      exist_ortholog,
      by = stats::setNames("Gene", Gene_Names_Column)
    ) %>%
      dplyr::select("Ortholog", everything(), -Gene_Names_Column)
    colnames(deg_table)[colnames(deg_table) == "Ortholog"] <-
      Gene_Names_Column
  }

  deg_table <-
    deg_table %>%
    dplyr::select(Gene_Names_Column, rank_columns) %>%
    tidyr::pivot_longer(
      !Gene_Names_Column,
      names_to = "contrast",
      values_to = "genescores",
      values_drop_na = TRUE
    ) %>%
    dplyr::rename("gene_id" = Gene_Names_Column) %>%
    dplyr::mutate(contrast = sub(gene_scores_column_s_suffix, "", contrast))
  duplicates <-
    dplyr::group_by(deg_table, contrast, gene_id) %>%
    dplyr::filter(dplyr::n() > 1)
  if (nrow(duplicates) > 0) {
    genescore_grouped <-
      deg_table %>%
      dplyr::group_by(contrast, gene_id) %>%
      dplyr::summarize(genescores = mean(genescores, na.rm = TRUE))
    cat(
      sprintf(
        paste0(
          "WARNING: duplicated gene names found of %g gene(s), duplicated ",
          "values of gene scores were averaged per gene"
        ),
        length(unique(duplicates$gene_id))
      )
    )
  } else {
    genescore_grouped <- dplyr::group_by(deg_table, contrast)
  }

  # ANALYSIS ====

  ## GSEA
  gsea <-
    dplyr::group_modify(
      genescore_grouped,
      ~ run.gsea(
        .,
        db = pathways_database,
        collections = geneset_list,
        minimum_size = Minimum_Gene_Set_Size,
        maximum_size = Maximum_Gene_Set_Size,
        number_perms = Number_of_Permutations,
        mode = FDR_Correction_Mode,
        organism = species,
        Np = number_of_processing_units,
        randomSeed = Random_Seed
      )
    )
  # OUTPUT ====

  ## visualization
  
  # Define output graphics file path
  graphicsFile <- file.path("/results", "gsea_pvalue_tables.png")

  png(
    filename = graphicsFile,
    width = Image_Width,
    height = Image_Height,
    units = "px",
    pointsize = 4,
    bg = "white",
    res = Image_Resolution,
    type = "cairo"
  )
  plot_device <- grDevices::dev.cur()
  on.exit(
    {
      open_devices <- grDevices::dev.list()
      if (!is.null(open_devices) && plot_device %in% open_devices) {
        grDevices::dev.off(which = plot_device)
      }
    },
    add = TRUE
  )

  tab <-
    dplyr::group_modify(gsea, ~ table.pvalue(.x)) %>% dplyr::ungroup()
  ltab <-
    split(tab, tab$contrast) %>%
    lapply(function(x) {
      plot.table(x, score = gene_scores_column_s_suffix)
    }) %>%
    wrap_plots()
  print(
    ltab +
      plot_annotation(
        title = "Cumulative number of significant calls (GSEA)",
        subtitle = sprintf(
          "*p value adjusted %s by the method of Benjamini and Hochberg (1995)",
          FDR_Correction_Mode
        ),
        tag_levels = "A",
        theme = theme(
          plot.title = element_text(
            size = 20,
            face = "bold",
            hjust = 0.5,
            margin = margin(t = 0)
          ),
          plot.subtitle = element_text(
            size = 11,
            face = "italic",
            hjust = 0.5,
            margin = margin(t = 10, b = 20)
          )
        )
      )
  )
  ## logs
  cat("\nThe number of tested gene sets per each collection and contrast\n")
  N <- dplyr::count(gsea, collection)
  print(N, n = nrow(N))
  cat(
    sprintf(
      paste0(
        "\nCumulative number of significant calls\n",
        "p-value adjusted for the false discovery rate %s by the method ",
        "of Benjamini and Hochberg (1995)\n"
      ),
      FDR_Correction_Mode
    )
  )
  tab %>% print(n = nrow(tab))

  ## collapse redundant?

  if (Collapse_Pathway_Redundancy == TRUE) {
    gsea_grouped <-
      gsea %>%
      dplyr::mutate(group_contrast = contrast) %>%
      dplyr::group_by(group_contrast)
    gsea <-
      dplyr::group_modify(
        gsea_grouped,
        ~ collapse.gsea(
          .,
          dx = deg_table,
          collections = geneset_list,
          Np = number_of_processing_units,
          randomSeed = Random_Seed
        )
      ) %>%
      dplyr::ungroup() %>%
      dplyr::select(-group_contrast) %>%
      dplyr::group_by(contrast)
    cat(
      "\nThe number of non-redundant gene sets per each collection and ",
      "contrast\n"
    )
    N <- dplyr::count(gsea, collection)
    print(N, n = nrow(N))
  }

  ## return dataset
  if (need_ortholog) {
    gsea$leadingEdge_orthologs <- species.genes()$leadingEdge_orthologs
    gsea$leadingEdge <- species.genes()$leadingEdge
    gsea$inPathway_orthologs <- species.genes()$inPathway_orthologs
    gsea$inPathway <- species.genes()$inPathway
  }

  # Convert sort_output_by to symbols and apply arrange
  if (Sort_Output_in_Decreasing_Order) {
    sort_exprs <- lapply(sort_output_by, function(x) {
      rlang::expr(desc(!!rlang::sym(x)))
    })
  } else {
    sort_exprs <- lapply(sort_output_by, function(x) {
      rlang::sym(x)
    })
  }

  gsea <-
    gsea %>%
    dplyr::arrange(!!!sort_exprs) %>%
    tibble::add_column(
      geneScore = gene_scores_column_s_suffix,
      .after = "contrast"
    ) %>%
    tibble::add_column(
      fdr_correction_mode = FDR_Correction_Mode,
      .after = "geneScore"
    )

  return(gsea)
}


