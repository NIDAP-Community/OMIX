#!/usr/bin/env Rscript

test_args <- commandArgs(FALSE)
test_file <- sub("^--file=", "", test_args[grepl("^--file=", test_args)])
module_dir <- normalizePath(file.path(dirname(test_file), ".."))
cli_file <- file.path(module_dir, "scripts", "run_l2p_single.R")
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
  "select_by_rank", "select_top_percentage_of_genes",
  "use_built_in_gene_universe", "use_fdr_p_values",
  "plot_top_pathways_up", "plot_top_pathways_down"
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
    "deg_table", "comparison", "comparisons", "species",
    "collections_to_include", "select_by_rank", "significance_threshold",
    "fold_change_threshold", "number_of_pathways_to_plot"
  ),
  advanced = c(
    "custom_pathways", "gene_names_column", "t_statistic_column",
    "significance_column", "fold_change_column",
    "select_top_percentage_of_genes", "select_top_genes",
    "minimum_number_of_deg_genes", "minimum_pathway_hit_count",
    "p_value_threshold_for_output", "use_built_in_gene_universe",
    "use_fdr_p_values", "custom_pathway_name_column",
    "custom_pathway_gene_column", "pathway_axis_label_max_length",
    "pathway_axis_label_font_size", "x_axis_title_font_size",
    "y_axis_title_font_size", "x_axis_tick_font_size",
    "plot_top_pathways_up", "pathways_to_use_up",
    "plot_top_pathways_down", "pathways_to_use_down",
    "sort_bubble_plot_by", "plot_bubble_size", "plot_bubble_color",
    "bubble_colors", "color_for_bar", "export_plot_width",
    "export_plot_height"
  ),
  internal = "output_dir"
)
for (classification in names(expected_classification)) {
  observed <- names(controls)[vapply(
    controls,
    function(control) identical(control$classification, classification),
    logical(1)
  )]
  stopifnot(identical(sort(observed), sort(expected_classification[[classification]])))
}

expected_allowed <- list(
  species = c("Human", "Mouse", "Macaque", "Rat", "Zebrafish", "Rabbit", "Drosophila"),
  sort_bubble_plot_by = c(
    "percent gene hits per pathway", "Fisher's Exact pval",
    "fdr corrected pval", "enrichment score", "number of hits"
  ),
  plot_bubble_size = c(
    "number of hits", "percent gene hits per pathway", "enrichment score",
    "Fisher's Exact pval", "fdr corrected pval"
  ),
  plot_bubble_color = c(
    "Fisher's Exact pval", "fdr corrected pval",
    "percent gene hits per pathway", "number of hits", "enrichment score"
  ),
  bubble_colors = c("blues", "reds", "blue to red"),
  color_for_bar = c(
    "Blue", "Green", "Orange", "Grey", "Red", "Purple",
    "GreentoBlue", "OrangetoRed", "YellowOrangeRed"
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
  identical(schema$parameters$comparison$mutually_exclusive_with, "comparisons"),
  identical(schema$parameters$comparisons$mutually_exclusive_with, "comparison"),
  isTRUE(schema$parameters$comparisons$preserves_order),
  isTRUE(schema$parameters$pathways_to_use_up$preserves_order),
  isTRUE(schema$parameters$pathways_to_use_down$preserves_order),
  identical(
    schema$parameters$collections_to_include$item_allowed,
    c(
      "GO", "REACTOME", "KEGG", "PANTH", "PID", "BIOCYC",
      "WikiPathways", "H", "C1", "C2", "C3", "C4", "C6", "C7", "C8"
    )
  )
)

message("OMIX-L2P-Single interface contract checks passed")
