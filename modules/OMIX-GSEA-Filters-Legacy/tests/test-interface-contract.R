#!/usr/bin/env Rscript

test_args <- commandArgs(FALSE)
test_file <- sub("^--file=", "", test_args[grepl("^--file=", test_args)])
module_dir <- normalizePath(file.path(dirname(test_file), ".."))
cli_file <- file.path(module_dir, "scripts", "run_gsea_filters.R")
schema_file <- file.path(module_dir, "schemas", "interface.yml")

if (!requireNamespace("yaml", quietly = TRUE)) {
  stop("The OMIX runtime must provide the `yaml` package for contract tests.")
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

path_controls <- c("input", "output_dir")
expected_schema_type <- function(name, cli_type) {
  if (name %in% path_controls) return("path")
  switch(cli_type, character = "string", integer = "integer", double = "number")
}
normalize_default <- function(value, schema_type) {
  if (is.null(value)) return(NULL)
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
    "input", "p_value_filter", "p_value_threshold",
    "enrichment_score_filter", "enrichment_score_threshold",
    "enrichment_score_sign", "top_rank_filter", "contrast_filter",
    "contrasts"
  ),
  advanced = c(
    "size_filter", "size_cutoff", "collections_to_include",
    "pathways_to_include", "gene_filter_universe", "genes_to_include"
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

expected_allowed <- list(
  p_value_filter = c("adjusted p-value", "raw p-value"),
  enrichment_score_filter = c("NES (Normalized Enrichment Score)", "ES (Enrichment Score)"),
  enrichment_score_sign = c("+/-", "+", "-"),
  size_filter = c("Pathway size", "Leading Edge (LE) size"),
  gene_filter_universe = c("Leading Edge (LE)", "Pathway"),
  contrast_filter = c("none", "keep", "remove")
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
  isTRUE(schema$inputs$input$required),
  identical(schema$inputs$input$formats, c("csv", "tsv", "txt", "rds")),
  all(vapply(
    schema$parameters[c("collections_to_include", "pathways_to_include", "genes_to_include", "contrasts")],
    function(control) identical(control$delimiter, ","),
    logical(1)
  ))
)

message("OMIX-GSEA-Filters-Legacy interface contract checks passed")
