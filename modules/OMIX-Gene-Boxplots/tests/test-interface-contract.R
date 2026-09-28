#!/usr/bin/env Rscript

script_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
if (length(script_arg) != 1L) {
  stop("Run this test with Rscript tests/test-interface-contract.R")
}

module_root <- normalizePath(
  file.path(dirname(sub("^--file=", "", script_arg)), "..")
)
schema_file <- file.path(module_root, "schemas", "interface.yml")
cli_file <- file.path(module_root, "scripts", "run_gene_boxplots.R")
function_file <- file.path(module_root, "R", "OMIX_Gene_Boxplots.R")

stopifnot(
  requireNamespace("yaml", quietly = TRUE),
  requireNamespace("optparse", quietly = TRUE)
)

schema <- yaml::read_yaml(schema_file)
stopifnot(
  identical(schema$interface_version, 1L),
  identical(schema$entrypoint, "scripts/run_gene_boxplots.R")
)

# Evaluate only the option-list declaration so the test observes the actual
# optparse order, names, types, and defaults without executing the CLI.
cli_expressions <- parse(cli_file)
is_option_list_assignment <- vapply(
  cli_expressions,
  function(expression) {
    is.call(expression) &&
      identical(expression[[1L]], as.name("<-")) &&
      identical(expression[[2L]], as.name("option_list"))
  },
  logical(1)
)
stopifnot(sum(is_option_list_assignment) == 1L)

option_environment <- list2env(
  list(make_option = optparse::make_option),
  parent = baseenv()
)
cli_options <- eval(
  cli_expressions[[which(is_option_list_assignment)]][[3L]],
  envir = option_environment
)
cli_options <- setNames(
  cli_options,
  vapply(cli_options, function(option) option@dest, character(1))
)

input_names <- names(schema$inputs)
parameter_names <- names(schema$parameters)
stopifnot(
  identical(input_names, c("expression_table", "metadata_table", "deg_table")),
  identical(names(cli_options), c(input_names, parameter_names))
)

expected_cli_type <- c(
  string = "character",
  path = "character",
  number = "double",
  integer = "integer"
)

defaults_equal <- function(schema_default, cli_default, schema_type) {
  if (is.null(schema_default) || is.null(cli_default)) {
    return(is.null(schema_default) && is.null(cli_default))
  }
  if (schema_type %in% c("number", "integer")) {
    return(isTRUE(all.equal(as.numeric(cli_default), as.numeric(schema_default))))
  }
  identical(cli_default, schema_default)
}

for (input_name in input_names) {
  input <- schema$inputs[[input_name]]
  cli_option <- cli_options[[input_name]]
  stopifnot(
    identical(input$classification, "public"),
    identical(input$cli, paste0("--", input_name)),
    identical(input$type, "path"),
    identical(cli_option@long_flag, input$cli),
    identical(cli_option@dest, input_name),
    identical(cli_option@type, unname(expected_cli_type[[input$type]])),
    defaults_equal(input$default, cli_option@default, input$type)
  )
}
stopifnot(
  identical(schema$inputs$expression_table$required, TRUE),
  identical(schema$inputs$metadata_table$required, TRUE),
  identical(
    schema$inputs$deg_table$required_when,
    "statistics_mode == precomputed_deg"
  )
)

allowed_classifications <- c("public", "advanced")
parameter_classifications <- vapply(
  schema$parameters,
  function(parameter) parameter$classification,
  character(1)
)
stopifnot(all(parameter_classifications %in% allowed_classifications))

advanced_parameters <- c(
  "p_adjust_method",
  "duplicate_aggregation",
  "image_width",
  "image_height",
  "image_dpi"
)
stopifnot(
  identical(names(parameter_classifications)[
    parameter_classifications == "advanced"
  ], advanced_parameters),
  all(parameter_classifications[
    setdiff(parameter_names, advanced_parameters)
  ] == "public")
)

for (parameter_name in parameter_names) {
  parameter <- schema$parameters[[parameter_name]]
  cli_option <- cli_options[[parameter_name]]
  stopifnot(
    parameter$type %in% names(expected_cli_type),
    identical(cli_option@type, unname(expected_cli_type[[parameter$type]])),
    defaults_equal(parameter$default, cli_option@default, parameter$type)
  )
}

expected_allowed <- list(
  statistics_mode = c("precomputed_deg", "within_plot", "none"),
  pvalue_type = c("nominal", "adjusted"),
  statistical_method = c("anova", "t-test", "kruskal"),
  p_adjust_method = c(
    "BH", "none", "bonferroni", "holm", "fdr", "hochberg", "hommel", "BY"
  ),
  duplicate_aggregation = c("mean", "sum", "keep"),
  plot_type = c("box", "violin")
)
for (parameter_name in names(expected_allowed)) {
  stopifnot(identical(
    schema$parameters[[parameter_name]]$allowed,
    expected_allowed[[parameter_name]]
  ))
}

function_environment <- new.env(parent = globalenv())
source(function_file, local = function_environment)
function_defaults <- formals(function_environment$omix_gene_boxplots)
color_function <- get(
  "boxplot_get_colorlist",
  envir = function_environment,
  mode = "function",
  inherits = TRUE
)
stopifnot(
  identical(
    eval(function_defaults$duplicate_aggregation),
    c("mean", "sum", "keep")
  ),
  identical(
    schema$parameters$colors$item_allowed,
    names(color_function())
  )
)

expected_internal_controls <- c("deg_gene_column", "sum_duplicates")
stopifnot(
  identical(names(schema$internal_controls), expected_internal_controls),
  all(vapply(
    schema$internal_controls,
    function(control) identical(control$classification, "internal"),
    logical(1)
  )),
  identical(
    schema$internal_controls$deg_gene_column$derived_from,
    "gene_column"
  ),
  identical(
    schema$internal_controls$sum_duplicates$replaced_by,
    "duplicate_aggregation"
  )
)

fixture_files <- c(
  "duplicate-expression.csv",
  "duplicate-metadata.csv",
  "duplicate-expected-mean-long.csv",
  "duplicate-expected-summed-long.csv"
)
stopifnot(all(file.exists(file.path(module_root, "tests", "fixtures", fixture_files))))

message("OMIX-Gene-Boxplots interface contract checks passed")
