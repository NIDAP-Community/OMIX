#!/usr/bin/env Rscript

test_args <- commandArgs(FALSE)
test_file <- sub("^--file=", "", test_args[grepl("^--file=", test_args)])
module_dir <- normalizePath(file.path(dirname(test_file), ".."))
cli_file <- file.path(module_dir, "scripts", "run_l2p_multi.R")
schema_file <- file.path(module_dir, "schemas", "interface.yml")

if (!requireNamespace("yaml", quietly = TRUE)) {
  stop("The r-pathway runtime must provide the `yaml` package for contract tests.")
}

schema <- yaml::read_yaml(schema_file)
controls <- c(schema$inputs, schema$parameters)

find_make_options <- function(expressions) {
  options <- list()
  visit <- function(node) {
    if (!is.call(node)) return(invisible(NULL))
    if (identical(node[[1L]], as.name("make_option"))) {
      arguments <- as.list(node)[-1L]
      argument_names <- names(arguments)
      unnamed <- which(is.na(argument_names) | argument_names == "")
      flag <- eval(arguments[[unnamed[[1L]]]], envir = baseenv())
      name <- sub("^--", "", flag)
      type_index <- which(argument_names == "type")
      default_index <- which(argument_names == "default")
      options[[name]] <<- list(
        cli_type = eval(arguments[[type_index]], envir = baseenv()),
        has_default = length(default_index) == 1L,
        default_expression = if (length(default_index) == 1L) {
          list(arguments[[default_index]])
        } else {
          list()
        }
      )
      return(invisible(NULL))
    }
    lapply(as.list(node)[-1L], visit)
    invisible(NULL)
  }
  lapply(expressions, visit)
  options
}

cli_options <- find_make_options(parse(file = cli_file, keep.source = FALSE))
stopifnot(identical(sort(names(controls)), sort(names(cli_options))))
stopifnot(identical(names(schema$control_classifications), c("public", "advanced", "internal")))

boolean_controls <- c(
  "update_genes", "select_by_rank", "select_top_percentage_of_genes",
  "pathway_bubble_plots", "use_built_in_gene_universe",
  "use_fdr_for_significance", "use_panel_plot",
  "use_dynamic_pathway_font_size"
)
path_controls <- c("deg_table", "custom_pathways", "output_dir")

expected_schema_type <- function(name, cli_type) {
  if (name %in% boolean_controls) return("boolean")
  if (name %in% path_controls) return("path")
  switch(cli_type, character = "string", integer = "integer", double = "number")
}

normalize_default <- function(value, schema_type) {
  if (is.null(value)) return(NULL)
  if (schema_type == "boolean") {
    if (is.logical(value)) return(value)
    return(identical(tolower(as.character(value)), "true"))
  }
  if (schema_type %in% c("number", "integer")) return(as.numeric(value))
  as.character(value)
}

for (name in names(cli_options)) {
  cli <- cli_options[[name]]
  contract <- controls[[name]]
  stopifnot(identical(contract$type, expected_schema_type(name, cli$cli_type)))
  stopifnot(contract$classification %in% names(schema$control_classifications))

  schema_has_default <- "default" %in% names(contract)
  stopifnot(identical(schema_has_default, cli$has_default))
  if (cli$has_default) {
    cli_default <- eval(cli$default_expression[[1L]], envir = baseenv())
    stopifnot(identical(
      normalize_default(contract$default, contract$type),
      normalize_default(cli_default, contract$type)
    ))
  }
}

expected_classification <- list(
  public = c(
    "deg_table", "comparisons", "species", "collections_to_include",
    "select_by_rank", "significance_threshold", "fold_change_threshold",
    "number_of_significant_events", "pathway_bubble_plots",
    "pathway_bubble_top_n", "pathway_bubble_significance_statistic",
    "minimum_pathway_hit_count", "p_value_limit"
  ),
  advanced = c(
    "custom_pathways", "gene_names_column", "t_statistic_columns",
    "significance_columns", "fold_change_columns", "update_genes",
    "select_top_percentage_of_genes", "select_top_genes",
    "minimum_number_of_deg_genes", "collection_color_scale",
    "use_built_in_gene_universe", "pathway_size_limit",
    "use_fdr_for_significance", "custom_pathway_name_column",
    "custom_pathway_gene_column", "pathways_to_remove"
  ),
  internal = c(
    "output_dir", "top_pathways", "maximum_pathways_to_plot",
    "plot_bubble_size", "plot_bubble_color", "plot_bubble_max_color",
    "pathway_axis_label_max_length", "pathway_axis_label_font_size",
    "rename_groups", "vertical_line_placement", "use_panel_plot",
    "use_dynamic_pathway_font_size", "custom_pathway_order",
    "x_axis_title", "y_axis_title", "x_axis_title_font_size",
    "y_axis_title_font_size", "x_axis_tick_font_size",
    "x_axis_tick_labels", "y_axis_tick_labels", "plot_width",
    "plot_height", "column_spacing"
  )
)
for (classification in names(expected_classification)) {
  observed <- names(controls)[vapply(
    controls,
    function(control) identical(control$classification, classification),
    logical(1)
  )]
  stopifnot(identical(sort(observed), sort(expected_classification[[classification]])))
}

ordered_controls <- c(
  "comparisons", "t_statistic_columns", "significance_columns",
  "fold_change_columns", "rename_groups", "vertical_line_placement",
  "custom_pathway_order", "x_axis_tick_labels", "y_axis_tick_labels"
)
stopifnot(all(vapply(
  schema$parameters[ordered_controls],
  function(control) isTRUE(control$preserves_order),
  logical(1)
)))

expected_allowed <- list(
  species = c("Human", "Mouse", "Macaque", "Rat", "Zebrafish", "Rabbit", "Drosophila"),
  pathway_bubble_significance_statistic = c("padj", "pval"),
  collection_color_scale = c("independent", "shared"),
  plot_bubble_size = c("pval", "fdr", "number_hits"),
  plot_bubble_color = c(
    "enrichment_score", "net_enrichment_score",
    "percent_gene_hits_per_pathway"
  )
)
observed_allowed <- names(controls)[vapply(
  controls,
  function(control) "allowed" %in% names(control),
  logical(1)
)]
stopifnot(identical(sort(observed_allowed), sort(names(expected_allowed))))
for (name in names(expected_allowed)) {
  stopifnot(identical(controls[[name]]$allowed, expected_allowed[[name]]))
}

stopifnot(
  isTRUE(schema$inputs$deg_table$required),
  isTRUE(schema$parameters$comparisons$required),
  identical(schema$parameters$t_statistic_columns$aligned_with, "comparisons"),
  identical(schema$parameters$significance_columns$aligned_with, "comparisons"),
  identical(schema$parameters$fold_change_columns$aligned_with, "comparisons"),
  isTRUE(schema$parameters$top_pathways$deprecated),
  isTRUE(schema$parameters$maximum_pathways_to_plot$deprecated),
  identical(
    schema$parameters$collections_to_include$item_allowed,
    c(
      "GO", "REACTOME", "KEGG", "PANTH", "PID", "BIOCYC",
      "WikiPathways", "H", "C1", "C2", "C3", "C4", "C6", "C7", "C8"
    )
  )
)

message("OMIX-L2P-Multi interface contract checks passed")
