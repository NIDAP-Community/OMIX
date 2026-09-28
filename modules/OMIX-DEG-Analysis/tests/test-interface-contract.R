script_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
if (length(script_arg) != 1L) {
  stop("Run this test with Rscript tests/test-interface-contract.R")
}

if (!requireNamespace("yaml", quietly = TRUE)) {
  stop("The interface-contract test requires the yaml package.")
}

module_root <- normalizePath(file.path(dirname(sub("^--file=", "", script_arg)), ".."))
schema_path <- file.path(module_root, "schemas", "interface.yml")
entrypoint_path <- file.path(module_root, "scripts", "run_deg_analysis.R")
schema <- yaml::read_yaml(schema_path)

# Collect every schema node that explicitly maps to a command-line control.
collect_controls <- function(node) {
  if (!is.list(node)) return(list())
  if (!is.null(node$cli)) return(setNames(list(node), sub("^--", "", node$cli)))
  Reduce(c, unname(lapply(node, collect_controls)), init = list())
}

schema_controls <- c(
  collect_controls(schema$inputs),
  collect_controls(schema$parameters)
)

# Read literal optparse declarations so the test detects a new CLI control that
# was not added to the canonical contract, or a default changed in only one
# location. The module intentionally uses string defaults for every CLI option.
entrypoint_lines <- readLines(entrypoint_path, warn = FALSE)
option_lines <- grep("make_option\\(\"--", entrypoint_lines, value = TRUE)
cli_names <- sub('.*make_option\\(\"--([^\"]+)\".*', "\\1", option_lines)
cli_defaults <- sub('.*default = \"([^\"]*)\".*', "\\1", option_lines)
names(cli_defaults) <- cli_names

stopifnot(
  identical(schema$interface_version, 2L),
  identical(schema$entrypoint, "scripts/run_deg_analysis.R"),
  !anyDuplicated(names(schema_controls)),
  identical(sort(names(schema_controls)), sort(cli_names))
)

expected_classification <- c(
  input_type = "public",
  counts = "public",
  metadata = "public",
  moo = "public",
  pseudobulk_manifest = "advanced",
  analysis_mode = "public",
  gene_names_column = "public",
  sample_names_column = "public",
  samples_to_include = "advanced",
  contrast_variable_columns = "public",
  contrasts = "public",
  covariate_columns = "advanced",
  batch_effect_columns = "advanced",
  donor_variable_column = "advanced",
  filter_low_expression = "advanced",
  return_batch_corrected_values = "advanced",
  remove_donor_effect_for_downstream = "advanced",
  normalization_method = "advanced",
  write_normalization_diagnostics = "advanced",
  summarization_method = "advanced",
  output_dir = "internal"
)

observed_classification <- vapply(
  schema_controls[names(expected_classification)],
  `[[`,
  character(1),
  "classification"
)
stopifnot(identical(observed_classification, expected_classification))

schema_defaults <- vapply(schema_controls, function(control) {
  if (is.null(control$default)) stop("Missing schema default for ", control$cli)
  as.character(control$default)
}, character(1))
stopifnot(identical(unname(schema_defaults[names(cli_defaults)]), unname(cli_defaults)))

expected_choices <- list(
  input_type = c("table", "moo"),
  analysis_mode = c("raw_counts", "harmony_mean_expression", "sct_mean_expression"),
  filter_low_expression = c("auto", "true", "false"),
  return_batch_corrected_values = c("auto", "true", "false"),
  remove_donor_effect_for_downstream = c("auto", "true", "false"),
  normalization_method = c(
    "auto", "None", "TMM", "Quantile", "TMM + Quantile", "TMM + Scale",
    "TMM + Cyclic Loess", "TMMwsp", "RLE", "Upper Quartile"
  ),
  write_normalization_diagnostics = c("auto", "true", "false"),
  summarization_method = c("auto", "sum", "mean", "max")
)
for (control_name in names(expected_choices)) {
  stopifnot(identical(
    as.character(schema_controls[[control_name]]$allowed),
    expected_choices[[control_name]]
  ))
}

user_settable <- schema_controls[vapply(
  schema_controls,
  function(control) control$classification %in% c("public", "advanced"),
  logical(1)
)]
stopifnot(
  length(user_settable) == 20L,
  all(vapply(user_settable, function(control) nzchar(control$type), logical(1))),
  all(vapply(user_settable, function(control) {
    !is.null(control$description) && nzchar(control$description)
  }, logical(1)))
)

message("OMIX DEG CLI/schema classification and default contract tests passed")
