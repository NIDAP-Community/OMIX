#!/usr/bin/env Rscript

# Compare portable PCA output to a supplied historical Plotly object.  This is
# deliberately an opt-in local test: neither the historical inputs nor the
# object are committed to OMIX or uploaded by the PR workflow.

arguments <- commandArgs(trailingOnly = TRUE)
options <- list()
for (argument in arguments) {
  if (!startsWith(argument, "--") || !grepl("=", argument, fixed = TRUE)) {
    stop("Arguments must use --name=value form; received: ", argument, call. = FALSE)
  }
  pieces <- strsplit(substring(argument, 3L), "=", fixed = TRUE)[[1L]]
  options[[pieces[[1L]]]] <- paste(pieces[-1L], collapse = "=")
}

required <- c(
  "feature_matrix", "sample_metadata", "historical_plot", "feature_id_column",
  "sample_id_column", "sample_label_column", "group_column"
)
missing <- required[vapply(required, function(name) {
  is.null(options[[name]]) || !nzchar(options[[name]])
}, logical(1))]
if (length(missing)) {
  stop("Missing required argument(s): ", paste(paste0("--", missing), collapse = ", "), call. = FALSE)
}

script_file <- sub("^--file=", "", commandArgs(FALSE)[grepl("^--file=", commandArgs(FALSE))])
module_dir <- normalizePath(file.path(dirname(script_file), ".."))
source(file.path(module_dir, "R", "OMIX_PCA_3D.R"))

read_delimited <- function(path) {
  extension <- tolower(tools::file_ext(path))
  if (extension == "csv") {
    utils::read.csv(path, check.names = FALSE, stringsAsFactors = FALSE)
  } else if (extension %in% c("tsv", "txt")) {
    utils::read.delim(path, check.names = FALSE, stringsAsFactors = FALSE)
  } else {
    stop("Only CSV, TSV, or TXT input tables are supported: ", path, call. = FALSE)
  }
}

split_csv <- function(value) {
  if (is.null(value) || !nzchar(value)) character() else trimws(strsplit(value, ",", fixed = TRUE)[[1L]])
}

flatten_plotly <- function(figure) {
  built <- plotly::plotly_build(figure)
  traces <- lapply(built$x$data, function(trace) {
    data.frame(
      PC1 = as.numeric(trace$x),
      PC2 = as.numeric(trace$y),
      PC3 = as.numeric(trace$z),
      group = rep(as.character(trace$name), length(trace$x)),
      sample = as.character(trace$text),
      point_size = rep(as.numeric(trace$marker$size), length(trace$x)),
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, traces)
}

feature_matrix <- read_delimited(options$feature_matrix)
sample_metadata <- read_delimited(options$sample_metadata)
historical_figure <- readRDS(options$historical_plot)
samples_to_include <- split_csv(options$samples_to_include)
if (!length(samples_to_include)) {
  samples_to_include <- intersect(as.character(sample_metadata[[options$sample_id_column]]), names(feature_matrix))
}
outlier_sample_ids <- split_csv(options$outlier_sample_ids)
point_color_names <- split_csv(options$point_colors)
if (!length(point_color_names)) point_color_names <- c("indigo", "carrot", "lipstick", "turquoise", "lavender", "jade", "coral", "azure", "green", "rum", "orange", "olive")
use_cpm <- !is.null(options$use_cpm) && identical(tolower(options$use_cpm), "true")
tolerance <- if (is.null(options$tolerance)) 1e-10 else as.numeric(options$tolerance)
point_size <- if (is.null(options$point_size)) 8 else as.numeric(options$point_size)
if (!is.finite(tolerance) || tolerance < 0) stop("--tolerance must be a non-negative number.", call. = FALSE)
if (!is.finite(point_size) || point_size <= 0) stop("--point_size must be positive.", call. = FALSE)

prepared <- omix_pca_3d_prepare(
  feature_matrix = feature_matrix,
  sample_metadata = sample_metadata,
  feature_id_column = options$feature_id_column,
  sample_id_column = options$sample_id_column,
  sample_label_column = options$sample_label_column,
  group_column = options$group_column,
  samples_to_include = samples_to_include,
  outlier_sample_ids = outlier_sample_ids,
  use_cpm = use_cpm,
  point_color_names = point_color_names,
  manual_label_renames = split_csv(options$manual_label_renames)
)

historical <- flatten_plotly(historical_figure)
current_figure <- omix_pca_3d_render(
  prepared = prepared,
  plot_title = "Known-result parity check",
  point_size = point_size,
  label_font_size = 24
)
current <- flatten_plotly(current_figure)

# The group and hover label together identify an observed plotting point while
# preserving intentional display-label changes made by the historical template.
key <- c("group", "sample")
if (anyDuplicated(paste(historical$group, historical$sample, sep = "\r")) ||
    anyDuplicated(paste(current$group, current$sample, sep = "\r"))) {
  stop("Historical and current Plotly points must each have unique group/sample keys.", call. = FALSE)
}
joined <- merge(
  current[, c(key, "PC1", "PC2", "PC3", "point_size")],
  historical[, c(key, "PC1", "PC2", "PC3", "point_size")],
  by = key,
  suffixes = c("_current", "_historical"),
  all = TRUE,
  sort = FALSE
)
if (nrow(joined) != nrow(current) || nrow(joined) != nrow(historical) ||
    anyNA(joined$PC1_current) || anyNA(joined$PC1_historical)) {
  stop("Current and historical plots do not contain the same group/sample points.", call. = FALSE)
}

coordinate_columns <- c("PC1", "PC2", "PC3")
max_delta <- max(abs(unlist(lapply(coordinate_columns, function(component) {
  joined[[paste0(component, "_current")]] - joined[[paste0(component, "_historical")]]
}))))
if (max_delta > tolerance) {
  stop(
    "PCA historical parity failed: maximum absolute coordinate difference ",
    format(max_delta, digits = 17), " exceeds tolerance ", format(tolerance, digits = 17), ".",
    call. = FALSE
  )
}
if (!isTRUE(all.equal(joined$point_size_current, joined$point_size_historical, tolerance = tolerance))) {
  stop("PCA historical parity failed: Plotly point sizes differ.", call. = FALSE)
}

message(
  "PCA historical parity passed: ", nrow(joined), " matched samples, ",
  3L * nrow(joined), " coordinates, max absolute difference ",
  format(max_delta, digits = 17), "."
)
