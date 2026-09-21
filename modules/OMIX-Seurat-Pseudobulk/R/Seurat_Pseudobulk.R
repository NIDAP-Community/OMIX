#' Write a DEG-ready donor-level table bundle from a Seurat RDS
#'
#' @description
#' Uses the optional OmixSeurat bridge to select one cell type and create one
#' donor-by-group profile per biological replicate. `sum_counts` extracts raw
#' counts and writes a count bundle for edgeR TMM plus limma-voom. The separate
#' continuous-expression paths either extract a declared Harmony-corrected
#' gene-expression layer or use Seurat's `SCT/data` layer. Both calculate donor
#' means and write direct-limma bundles. The result manifest prevents the three
#' matrix types from being interchanged downstream.
#'
#' Cells are never used as independent differential-expression replicates.
#' Each output column represents one donor-by-group profile.
#'
#' @param seurat_rds Path to a serialized Seurat object.
#' @param donor_column Cell-metadata column identifying biological donors.
#' @param group_column Cell-metadata column identifying the experimental group.
#' @param cell_type_column Cell-metadata column identifying cell types.
#' @param cell_type One exact cell-type value to aggregate.
#' @param metadata_columns Optional cell-metadata columns to retain in output
#'   sample metadata, such as Batch or Sex. Each value must be invariant and
#'   non-missing within every donor-by-group profile.
#' @param cell_filter_column Optional cell-metadata column used for an explicit
#'   pre-aggregation filter.
#' @param cell_filter_values Values retained from cell_filter_column.
#' @param aggregation_method `"sum_counts"` (default),
#'   `"mean_harmony_corrected_expression"`, or
#'   `"mean_sctransform_expression"`.
#' @param assay Seurat assay containing the declared source layer. `"auto"`
#'   (default) resolves to `"RNA"` for raw counts, `"Harmony"` for the
#'   gene-level Harmony expression assay written by SCWorkflow, and `"SCT"`
#'   for SCTransform expression.
#' @param layer Assay layer containing raw counts for `sum_counts`, or a
#'   documented Harmony-corrected gene-expression matrix for
#'   `mean_harmony_corrected_expression`, or the `data` layer of the
#'   declared SCTransform assay for `mean_sctransform_expression`.
#' @param feature_id_column Output feature-ID column. Default: "GeneName".
#' @param min_cells Minimum selected cells in each donor-by-group profile.
#' @param on_insufficient_cells Whether profiles below min_cells cause an error
#'   (default) or are intentionally dropped.
#' @param output_dir Explicit directory for the pseudobulk table bundle.
#'
#' @return A list of output paths and the validated omix_standard_input.
omix_seurat_pseudobulk <- function(
  seurat_rds,
  donor_column,
  group_column,
  cell_type_column,
  cell_type,
  metadata_columns = NULL,
  cell_filter_column = NULL,
  cell_filter_values = NULL,
  aggregation_method = c(
    "sum_counts",
    "mean_harmony_corrected_expression",
    "mean_sctransform_expression"
  ),
  assay = "auto",
  layer = NULL,
  feature_id_column = "GeneName",
  min_cells = 20L,
  on_insufficient_cells = c("error", "drop"),
  output_dir = "results"
) {
  # Normalize the user-supplied paths first so every later error reports the
  # same explicit file/directory the caller asked the module to use.
  seurat_rds <- .omix_seurat_pseudobulk_path(seurat_rds, "seurat_rds", must_exist = TRUE)
  output_dir <- .omix_seurat_pseudobulk_path(output_dir, "output_dir", must_exist = FALSE)
  aggregation_method <- match.arg(aggregation_method)

  # Each aggregation method has one biologically appropriate default source:
  # raw RNA counts for count-based pseudobulk, the SCWorkflow Harmony assay
  # for corrected expression, or the SCT assay for SCTransform expression.
  # A caller may override these defaults only by naming an assay explicitly.
  if (is.null(assay) || identical(assay, "auto")) {
    assay <- switch(
      aggregation_method,
      sum_counts = "RNA",
      mean_harmony_corrected_expression = "Harmony",
      mean_sctransform_expression = "SCT"
    )
  }
  if (is.null(layer) || identical(layer, "auto")) {
    layer <- if (identical(aggregation_method, "sum_counts")) "counts" else "data"
  }

  # SCT/data is log1p corrected expression. Restricting this path to that
  # layer prevents accidental use of SCT Pearson residuals (scale.data) as a
  # general gene-expression matrix.
  if (identical(aggregation_method, "mean_sctransform_expression") && !identical(layer, "data")) {
    stop(
      "mean_sctransform_expression requires the SCTransform assay's data layer. ",
      "Use layer = 'data'.",
      call. = FALSE
    )
  }
  # Validate all identifiers before opening the RDS. This avoids ambiguous
  # bridge errors when a required metadata column or cell-type label is blank.
  required_values <- list(
    donor_column = donor_column,
    group_column = group_column,
    cell_type_column = cell_type_column,
    cell_type = cell_type,
    assay = assay,
    layer = layer,
    feature_id_column = feature_id_column
  )
  for (name in names(required_values)) {
    .omix_seurat_pseudobulk_scalar(required_values[[name]], name)
  }
  metadata_columns <- .omix_seurat_pseudobulk_column_names(metadata_columns, "metadata_columns")
  if (xor(is.null(cell_filter_column), is.null(cell_filter_values))) {
    stop(
      "Supply both cell_filter_column and cell_filter_values, or neither.",
      call. = FALSE
    )
  }
  if (!is.null(cell_filter_column)) {
    .omix_seurat_pseudobulk_scalar(cell_filter_column, "cell_filter_column")
    cell_filter_values <- .omix_seurat_pseudobulk_values(cell_filter_values, "cell_filter_values")
  }
  if (!is.numeric(min_cells) || length(min_cells) != 1L || is.na(min_cells) ||
      min_cells < 1L || min_cells != as.integer(min_cells)) {
    stop("min_cells must be one positive integer.", call. = FALSE)
  }
  on_insufficient_cells <- match.arg(on_insufficient_cells)
  if (!requireNamespace("OmixSeurat", quietly = TRUE)) {
    stop(
      "OmixSeurat is required to read a Seurat object. Restore the r-seurat-conversion runtime ",
      "or install OMIX Core and bridges/seurat from the same OMIX commit.",
      call. = FALSE
    )
  }

  # The lightweight OmixSeurat bridge owns Seurat-object extraction. This
  # module supplies the biological grouping choices and receives a portable
  # feature-by-profile table plus aligned pseudobulk metadata in return.
  input_arguments <- list(
    path = seurat_rds,
    donor_column = donor_column,
    group_column = group_column,
    cell_type_column = cell_type_column,
    cell_type = cell_type,
    sample_metadata_columns = metadata_columns,
    cell_filter_column = cell_filter_column,
    cell_filter_values = cell_filter_values,
    assay = assay,
    layer = layer,
    feature_id_column = feature_id_column,
    min_cells = as.integer(min_cells),
    on_insufficient_cells = on_insufficient_cells
  )
  # Raw counts and continuous expression use different bridge entry points so
  # the two data scales cannot silently share a downstream statistical model.
  input <- if (identical(aggregation_method, "sum_counts")) {
    do.call(OmixSeurat::omix_read_seurat_rds, input_arguments)
  } else {
    do.call(OmixSeurat::omix_read_seurat_expression_rds, input_arguments)
  }
  # The bridge returns SCT/data means on the original log1p scale. Convert the
  # mean itself to log2 (rather than transforming cell values before averaging)
  # so direct limma reports interpretable log2 fold changes downstream.
  if (identical(aggregation_method, "mean_sctransform_expression")) {
    input <- .omix_seurat_sctransform_log2_input(input)
  }

  .omix_write_seurat_pseudobulk_bundle(
    input = input,
    output_dir = output_dir,
    seurat_rds = seurat_rds,
    aggregation_method = aggregation_method
  )
}

.omix_seurat_sctransform_log2_input <- function(input) {
  if (!is.list(input) || is.null(input$expression) || is.null(input$sample_columns) ||
      is.null(input$provenance)) {
    stop("SCTransform aggregation requires a complete continuous-expression input.", call. = FALSE)
  }
  expression <- as.data.frame(input$expression, check.names = FALSE, stringsAsFactors = FALSE)
  sample_columns <- as.character(input$sample_columns)
  if (!all(sample_columns %in% names(expression))) {
    stop("SCTransform expression input is missing donor-level sample columns.", call. = FALSE)
  }
  # SCT/data is natural-log (log1p) corrected expression. Dividing by log(2)
  # changes only the log base; it does not add a second normalization step.
  expression[, sample_columns] <- as.data.frame(
    as.matrix(expression[, sample_columns, drop = FALSE]) / log(2),
    check.names = FALSE,
    stringsAsFactors = FALSE
  )
  input$expression <- expression
  input$provenance$sctransform_input_scale <- "log1p_corrected_umi"
  input$provenance$aggregation_output_scale <- "log2_corrected_umi"
  input$provenance$upstream_batch_correction <- "not_declared"
  input
}

.omix_write_seurat_pseudobulk_bundle <- function(
  input,
  output_dir,
  seurat_rds,
  aggregation_method = c(
    "sum_counts",
    "mean_harmony_corrected_expression",
    "mean_sctransform_expression"
  )
) {
  aggregation_method <- match.arg(aggregation_method)

  # The bridge deliberately labels raw and continuous inputs differently. Pick
  # the expected element here, so a count matrix cannot be written as a
  # continuous-expression handoff (or the reverse).
  matrix_name <- if (identical(aggregation_method, "sum_counts")) "counts" else "expression"
  if (!is.list(input) || is.null(input[[matrix_name]]) || is.null(input$metadata) ||
      is.null(input$feature_id_column) || is.null(input$sample_id_column) ||
      is.null(input$sample_columns) || is.null(input$provenance)) {
    stop("input must be a complete donor-level matrix-and-metadata input.", call. = FALSE)
  }
  # Convert bridge objects to ordinary data frames before writing portable CSV
  # files. check.names = FALSE preserves biological sample IDs exactly.
  matrix_data <- as.data.frame(input[[matrix_name]], check.names = FALSE, stringsAsFactors = FALSE)
  metadata <- as.data.frame(input$metadata, check.names = FALSE, stringsAsFactors = FALSE)
  if (!identical(input$feature_id_column, "GeneName")) {
    stop(
      "The pseudobulk downstream handoff requires feature_id_column = 'GeneName'.",
      call. = FALSE
    )
  }
  if (!identical(input$sample_id_column, "Sample")) {
    stop(
      "The pseudobulk downstream handoff requires sample_id_column = 'Sample'.",
      call. = FALSE
    )
  }
  if (!all(c("GeneName", input$sample_columns) %in% names(matrix_data))) {
    stop("Donor-level matrix is missing GeneName or sample columns.", call. = FALSE)
  }
  if (!all(c("Sample", "Group", "Donor", "CellType", "Cells") %in% names(metadata))) {
    stop("Pseudobulk metadata is missing required OMIX columns.", call. = FALSE)
  }
  if (!identical(as.character(metadata$Sample), as.character(input$sample_columns))) {
    stop("Pseudobulk metadata is not aligned with pseudobulk count columns.", call. = FALSE)
  }
  if (length(unique(as.character(metadata$Group))) < 2L) {
    stop(
      "Pseudobulk output contains fewer than two Group values; DEG requires a comparison.",
      call. = FALSE
    )
  }

  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

  # These switches are the central handoff contract. The selected aggregation
  # method determines both what the matrix means and which downstream module
  # may analyze it. This is intentionally metadata, not a model fit.
  matrix_type <- switch(
    aggregation_method,
    sum_counts = "raw_integer_counts",
    mean_harmony_corrected_expression = "harmony_corrected_mean_expression",
    mean_sctransform_expression = "sctransform_mean_log2_expression"
  )
  expected_downstream_module <- switch(
    aggregation_method,
    sum_counts = "OMIX-DEG-Analysis",
    mean_harmony_corrected_expression = "OMIX-Limma-Analysis",
    mean_sctransform_expression = "OMIX-Limma-Analysis"
  )
  expected_downstream_mode <- switch(
    aggregation_method,
    sum_counts = "raw_counts",
    mean_harmony_corrected_expression = "continuous_expression",
    mean_sctransform_expression = "continuous_expression"
  )
  downstream_input_kind <- switch(
    aggregation_method,
    sum_counts = "raw_integer_counts",
    mean_harmony_corrected_expression = "log2_expression",
    mean_sctransform_expression = "log2_expression"
  )
  recommended_variance_model <- switch(
    aggregation_method,
    sum_counts = "voom_precision_weights",
    mean_harmony_corrected_expression = "ebayes",
    mean_sctransform_expression = "ebayes_trend"
  )
  matrix_filename <- switch(
    aggregation_method,
    sum_counts = "Pseudobulk_Counts.csv",
    mean_harmony_corrected_expression = "Harmony_Mean_Expression.csv",
    mean_sctransform_expression = "SCT_Mean_Log2_Expression.csv"
  )
  upstream_batch_correction <- switch(
    aggregation_method,
    sum_counts = "none",
    mean_harmony_corrected_expression = "Harmony",
    mean_sctransform_expression = "SCTransform_depth_correction_only"
  )
  # All three output files share an explicit directory, making the bundle easy
  # to move as a unit between local R, HPC, and later workflow adapters.
  matrix_path <- file.path(output_dir, matrix_filename)
  metadata_path <- file.path(output_dir, "Pseudobulk_Sample_Metadata.csv")
  manifest_path <- file.path(output_dir, "Pseudobulk_Manifest.dcf")
  summary_path <- file.path(output_dir, "Pseudobulk_Run_Summary.txt")
  utils::write.csv(matrix_data, matrix_path, row.names = FALSE, quote = TRUE)
  utils::write.csv(metadata, metadata_path, row.names = FALSE, quote = TRUE)

  # Bridge provenance is optional, so use an empty string rather than failing
  # when a source object did not record a particular detail.
  provenance_value <- function(name, default = "") {
    value <- input$provenance[[name]]
    if (is.null(value) || length(value) == 0L) return(default)
    paste(as.character(value), collapse = ",")
  }
  # The DCF manifest prevents a downstream caller from mistaking continuous
  # donor means for raw counts. It also records the expected module and the
  # variance-model recommendation without performing any normalization here.
  manifest <- data.frame(
    format_version = "1",
    matrix_type = matrix_type,
    aggregation_method = aggregation_method,
    expected_downstream_module = expected_downstream_module,
    expected_downstream_mode = expected_downstream_mode,
    downstream_input_kind = downstream_input_kind,
    recommended_variance_model = recommended_variance_model,
    feature_id_column = input$feature_id_column,
    sample_id_column = input$sample_id_column,
    source_assay = provenance_value("assay"),
    source_layer = provenance_value("layer"),
    upstream_batch_correction = upstream_batch_correction,
    cell_type = unique(as.character(metadata$CellType)),
    feature_count = as.character(nrow(matrix_data)),
    stringsAsFactors = FALSE
  )
  base::write.dcf(manifest, file = manifest_path)

  # The human-readable summary duplicates the essential routing and provenance
  # information so it can be inspected without parsing the DCF manifest.
  group_counts <- table(as.character(metadata$Group))
  summary_lines <- c(
    "OMIX Seurat donor-level aggregation run summary",
    paste("Seurat RDS:", normalizePath(seurat_rds, mustWork = FALSE)),
    paste("Aggregation method:", aggregation_method),
    paste("Matrix type:", matrix_type),
    paste("Expected downstream module:", expected_downstream_module),
    paste("Expected downstream mode:", expected_downstream_mode),
    paste("Downstream input kind:", downstream_input_kind),
    paste("Recommended variance model:", recommended_variance_model),
    paste("Output matrix:", basename(matrix_path)),
    paste("Output metadata:", basename(metadata_path)),
    paste("Output manifest:", basename(manifest_path)),
    paste("Features:", nrow(matrix_data)),
    paste("Pseudobulk profiles:", length(input$sample_columns)),
    paste("Cell type:", unique(as.character(metadata$CellType))),
    paste("Total selected cells:", sum(as.integer(metadata$Cells))),
    "Profiles per group:",
    paste(names(group_counts), as.integer(group_counts), sep = "=", collapse = "; "),
    "Provenance:"
  )
  provenance <- input$provenance
  provenance_lines <- vapply(names(provenance), function(name) {
    value <- provenance[[name]]
    if (is.null(value)) {
      value <- "<none>"
    } else if (length(value) > 1L) {
      value <- paste(as.character(value), collapse = ",")
    } else {
      value <- as.character(value)
    }
    paste0(name, ": ", value)
  }, character(1))
  writeLines(c(summary_lines, provenance_lines), summary_path)

  list(
    matrix_path = matrix_path,
    counts_path = if (identical(aggregation_method, "sum_counts")) matrix_path else NULL,
    expression_path = if (!identical(aggregation_method, "sum_counts")) matrix_path else NULL,
    metadata_path = metadata_path,
    manifest_path = manifest_path,
    run_summary_path = summary_path,
    input = input
  )
}

.omix_seurat_pseudobulk_path <- function(value, name, must_exist) {
  .omix_seurat_pseudobulk_scalar(value, name)
  if (must_exist && !file.exists(value)) {
    stop(name, " was not found: ", value, call. = FALSE)
  }
  value
}

.omix_seurat_pseudobulk_scalar <- function(value, name) {
  if (!is.character(value) || length(value) != 1L || is.na(value) || !nzchar(value)) {
    stop(name, " must be one non-empty character value.", call. = FALSE)
  }
  invisible(value)
}

.omix_seurat_pseudobulk_values <- function(value, name) {
  values <- unique(as.character(value))
  if (length(values) == 0L || anyNA(values) || any(!nzchar(values))) {
    stop(name, " must contain one or more non-empty values.", call. = FALSE)
  }
  values
}

.omix_seurat_pseudobulk_column_names <- function(value, name) {
  if (is.null(value) || length(value) == 0L) {
    return(NULL)
  }
  values <- .omix_seurat_pseudobulk_values(value, name)
  reserved <- c("Sample", "Donor", "Group", "CellType", "Cells")
  if (any(values %in% reserved)) {
    stop(
      name, " must not repeat standard pseudobulk column(s): ",
      paste(intersect(values, reserved), collapse = ", "),
      call. = FALSE
    )
  }
  values
}
