#!/usr/bin/env Rscript

test_args <- commandArgs(FALSE)
test_file <- sub("^--file=", "", test_args[grepl("^--file=", test_args)])
module_dir <- normalizePath(file.path(dirname(test_file), ".."))
cli_file <- file.path(module_dir, "scripts", "run_gsea_visualization.R")
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
        default_expression = if (length(default_index) == 1L) list(arguments[[default_index]]) else list()
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
stopifnot(identical(names(schema$exposure_levels), c("public", "advanced", "internal")))

boolean_controls <- c(
  "top_n_by_sign", "pathway_bubble_plots", "show_es_rank_bar",
  "show_rnk_peak_line", "show_rnk_le_highlight", "show_es_le_highlight",
  "show_le_heatmap_gene_names", "show_le_heatmap_sample_names",
  "show_le_heatmap_rank_labels"
)
path_controls <- c(
  "msigdb_database", "gsea_filter_results", "deg_table",
  "sample_metadata", "output_dir"
)
expected_schema_type <- function(name, cli_type) {
  if (name %in% boolean_controls) return("boolean")
  if (name %in% path_controls) return("path")
  switch(cli_type, character = "string", integer = "integer", double = "number", logical = "boolean")
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
  stopifnot(contract$exposure %in% names(schema$exposure_levels))
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

expected_exposure <- list(
  public = c(
    "msigdb_database", "gsea_filter_results", "deg_table",
    "sample_metadata", "contrast_filter", "contrasts", "top_n_pathways",
    "pathway_bubble_plots", "pathway_bubble_top_n",
    "pathway_bubble_significance_statistic", "plots_to_include",
    "heatmap_transform"
  ),
  advanced = c(
    "top_n_by_sign", "collection_color_scale", "max_plots_in_pdf",
    "running_score_line_color", "add_max_deviation_line", "rank_area_color",
    "show_es_rank_bar", "show_rnk_peak_line", "show_rnk_le_highlight",
    "show_es_le_highlight", "max_le_genes_heatmap", "heatmap_gene_order",
    "heatmap_sample_order", "heatmap_gene_clustering_distance",
    "heatmap_gene_clustering_method", "heatmap_sample_clustering_distance",
    "heatmap_sample_clustering_method", "show_le_heatmap_gene_names",
    "show_le_heatmap_sample_names", "show_le_heatmap_rank_labels",
    "heatmap_gene_names_column", "heatmap_sample_names_column",
    "heatmap_group_column", "pdf_width", "pdf_height"
  ),
  internal = "output_dir"
)
for (exposure in names(expected_exposure)) {
  observed <- names(controls)[vapply(
    controls,
    function(control) identical(control$exposure, exposure),
    logical(1)
  )]
  stopifnot(identical(sort(observed), sort(expected_exposure[[exposure]])))
}

distance_choices <- c(
  "euclidean", "maximum", "manhattan", "canberra", "binary",
  "minkowski", "pearson", "spearman", "kendall"
)
method_choices <- c(
  "ward.D", "ward.D2", "single", "complete", "average",
  "mcquitty", "median", "centroid"
)
expected_allowed <- list(
  contrast_filter = c("none", "keep", "remove"),
  pathway_bubble_significance_statistic = c("padj", "pval"),
  collection_color_scale = c("independent", "shared"),
  plots_to_include = c("ES", "ES+RNK", "ES+LE", "ES+RNK+LE", "LE"),
  running_score_line_color = c("ES sign", "green"),
  add_max_deviation_line = c("coordinate", "horizontal", "both", "none"),
  rank_area_color = c("grey", "red/blue by Gene score"),
  heatmap_transform = c("z-score", "center by row mean", "center by row median", "none"),
  heatmap_gene_order = c("rank", "cluster", "input"),
  heatmap_sample_order = c("group", "cluster", "input"),
  heatmap_gene_clustering_distance = distance_choices,
  heatmap_gene_clustering_method = method_choices,
  heatmap_sample_clustering_distance = distance_choices,
  heatmap_sample_clustering_method = method_choices
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
  all(vapply(schema$inputs, function(input) isTRUE(input$required), logical(1))),
  identical(schema$parameters$contrasts$delimiter, ",")
)

message("OMIX-GSEA-Visualization-Legacy interface contract checks passed")
