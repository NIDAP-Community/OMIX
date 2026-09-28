#!/usr/bin/env Rscript

test_args <- commandArgs(FALSE)
test_file <- sub("^--file=", "", test_args[grepl("^--file=", test_args)])
module_dir <- normalizePath(file.path(dirname(test_file), ".."))
cli_file <- file.path(module_dir, "scripts", "run_gsea.R")
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

path_controls <- c("deg_table", "pathways_database", "output_dir")
expected_schema_type <- function(name, cli_type) {
  if (identical(name, "collapse_redundancy")) return("boolean")
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
    "deg_table", "pathways_database", "species", "gene_scores_suffix",
    "contrasts", "pathways_species", "collections", "fdr_mode"
  ),
  advanced = c(
    "gene_names_column", "min_geneset_size", "max_geneset_size",
    "n_permutations", "random_seed", "collapse_redundancy", "sort_by",
    "image_width", "image_height", "image_resolution"
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

species_choices <- c(
  "Dog", "Drosophila", "Chimpanzee", "Human", "Macaque",
  "Mouse", "Rabbit", "Rat", "Zebrafish"
)
expected_allowed <- list(
  species = species_choices,
  pathways_species = species_choices,
  fdr_mode = c("over all collections", "within each collection"),
  sort_by = c("contrast", "collection", "pathway", "pval", "padj", "ES", "NES", "size", "nMoreExtreme")
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
  isTRUE(schema$inputs$pathways_database$required),
  identical(schema$parameters$contrasts$delimiter, ","),
  isTRUE(schema$parameters$contrasts$preserves_order),
  identical(schema$parameters$collections$delimiter, ",")
)

message("OMIX-GSEA-Preranked-Legacy interface contract checks passed")
