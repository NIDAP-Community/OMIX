#!/usr/bin/env Rscript

script_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
if (length(script_arg) != 1L) {
  stop("Run this test with Rscript tests/test-interface-contract.R")
}

module_root <- normalizePath(
  file.path(dirname(sub("^--file=", "", script_arg)), "..")
)
schema_file <- file.path(module_root, "schemas", "interface.yml")
cli_file <- file.path(module_root, "scripts", "run_volcano_plot.R")
function_file <- file.path(module_root, "R", "Volcano_Plot_Enhanced.R")

stopifnot(
  requireNamespace("yaml", quietly = TRUE),
  requireNamespace("optparse", quietly = TRUE)
)

schema <- yaml::read_yaml(schema_file)
stopifnot(
  identical(schema$interface_version, 1L),
  identical(schema$entrypoint, "scripts/run_volcano_plot.R"),
  identical(names(schema$inputs), "deg_table"),
  identical(schema$inputs$deg_table$classification, "public"),
  identical(schema$inputs$deg_table$cli, "--deg_table"),
  identical(schema$inputs$deg_table$type, "path"),
  is.null(schema$inputs$deg_table$default),
  identical(schema$inputs$deg_table$required, TRUE)
)

# Evaluate only the option-list declaration so the test observes the actual
# optparse names, types, and defaults without executing the CLI.
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

schema_parameter_names <- names(schema$parameters)
stopifnot(
  identical(names(cli_options), c("deg_table", schema_parameter_names)),
  identical(cli_options$deg_table@long_flag, schema$inputs$deg_table$cli),
  identical(cli_options$deg_table@dest, names(schema$inputs)),
  identical(cli_options$deg_table@type, "character"),
  is.null(cli_options$deg_table@default),
  !"resolution_dpi_" %in% names(cli_options),
  "resolution_dpi" %in% schema_parameter_names
)

allowed_classifications <- c("public", "advanced")
parameter_classifications <- vapply(
  schema$parameters,
  function(parameter) parameter$classification,
  character(1)
)
stopifnot(all(parameter_classifications %in% allowed_classifications))

advanced_parameters <- c(
  "use_custom_axis_label",
  "custom_significance_label",
  "custom_log_fold_change_label",
  "y_limit",
  "use_auto_axis_capping",
  "auto_axis_capping_quantile",
  "auto_axis_capping_symmetric_x",
  "custom_x_axis_limits",
  "x_limit_padding",
  "y_limit_padding"
)
stopifnot(
  identical(names(parameter_classifications)[
    parameter_classifications == "advanced"
  ], advanced_parameters),
  all(parameter_classifications[
    setdiff(schema_parameter_names, advanced_parameters)
  ] == "public")
)

expected_cli_type <- c(
  string = "character",
  path = "character",
  number = "double",
  integer = "integer",
  boolean = "character"
)

defaults_equal <- function(schema_default, cli_default, schema_type) {
  if (is.null(schema_default) || is.null(cli_default)) {
    return(is.null(schema_default) && is.null(cli_default))
  }
  if (identical(schema_type, "boolean")) {
    return(identical(tolower(cli_default), tolower(as.character(schema_default))))
  }
  if (schema_type %in% c("number", "integer")) {
    return(isTRUE(all.equal(as.numeric(cli_default), as.numeric(schema_default))))
  }
  identical(cli_default, schema_default)
}

for (parameter_name in schema_parameter_names) {
  parameter <- schema$parameters[[parameter_name]]
  cli_option <- cli_options[[parameter_name]]
  stopifnot(
    parameter$type %in% names(expected_cli_type),
    identical(cli_option@type, unname(expected_cli_type[[parameter$type]])),
    defaults_equal(parameter$default, cli_option@default, parameter$type)
  )
}

stopifnot(
  identical(schema$parameters$pvalue_type$allowed, c("nominal", "adjusted")),
  identical(
    schema$parameters$choose_feature_to_label_by$allowed,
    c("p-value", "fold-change")
  ),
  is.infinite(schema$parameters$label_max_overlaps$default),
  identical(schema$parameters$resolution_dpi$default, 300L)
)

expected_internal_controls <- c(
  "resolution_dpi_",
  "auto_axis_capping_min_y_limit",
  "output_file_path"
)
stopifnot(
  identical(names(schema$internal_controls), expected_internal_controls),
  all(vapply(
    schema$internal_controls,
    function(control) identical(control$classification, "internal"),
    logical(1)
  )),
  identical(
    schema$internal_controls$resolution_dpi_$source_parameter,
    "resolution_dpi"
  ),
  identical(
    schema$internal_controls$output_file_path$derived_from,
    "output_dir"
  )
)

function_environment <- new.env(parent = globalenv())
sys.source(function_file, envir = function_environment)
function_defaults <- formals(function_environment$volcano_plot_enhanced)
stopifnot(
  identical(eval(function_defaults$resolution_dpi_), 300),
  identical(eval(function_defaults$auto_axis_capping_min_y_limit), 0),
  is.null(eval(function_defaults$output_file_path))
)

cli_text <- paste(readLines(cli_file, warn = FALSE), collapse = "\n")
stopifnot(grepl(
  "resolution_dpi_ = opt$resolution_dpi",
  cli_text,
  fixed = TRUE
))

message("OMIX-Volcano-Plot interface contract checks passed")
