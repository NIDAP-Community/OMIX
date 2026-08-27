#!/usr/bin/env Rscript

# Create a local, ignored pseudobulk fixture from the Kang et al. IFN-beta PBMC
# study. The result is intended for development and integration testing only.

arguments <- commandArgs(trailingOnly = TRUE)
output_directory <- if (length(arguments) >= 1L) {
  arguments[[1L]]
} else {
  file.path("data", "debug", "kang-pseudobulk")
}

required_packages <- c("muscData", "SummarizedExperiment", "Matrix")
missing_packages <- required_packages[!vapply(
  required_packages,
  requireNamespace,
  logical(1),
  quietly = TRUE
)]
if (length(missing_packages) > 0L) {
  stop(
    "Install required package(s): ",
    paste(missing_packages, collapse = ", "),
    ". For muscData, use BiocManager::install('muscData')."
  )
}

dir.create(output_directory, recursive = TRUE, showWarnings = FALSE)

single_cell_experiment <- muscData::Kang18_8vs8()
keep_cells <-
  single_cell_experiment$multiplets == "singlet" &
  !is.na(single_cell_experiment$cell) &
  single_cell_experiment$cell == "CD14+ Monocytes"
single_cell_experiment <- single_cell_experiment[, keep_cells]

cell_metadata <- as.data.frame(SummarizedExperiment::colData(single_cell_experiment))
raw_counts <- SummarizedExperiment::assay(single_cell_experiment, "counts")
sample_groups <- interaction(
  cell_metadata$ind,
  cell_metadata$stim,
  drop = TRUE,
  lex.order = TRUE
)
aggregation_design <- Matrix::sparseMatrix(
  i = seq_along(sample_groups),
  j = as.integer(sample_groups),
  x = 1,
  dims = c(length(sample_groups), nlevels(sample_groups)),
  dimnames = list(colnames(raw_counts), levels(sample_groups))
)
pseudobulk_counts <- raw_counts %*% aggregation_design
sample_name_parts <- strsplit(colnames(pseudobulk_counts), ".", fixed = TRUE)
pseudobulk_metadata <- data.frame(
  Sample = colnames(pseudobulk_counts),
  Donor = vapply(sample_name_parts, `[`, character(1), 1L),
  Group = vapply(sample_name_parts, `[`, character(1), 2L),
  Cells = as.integer(Matrix::colSums(aggregation_design)),
  stringsAsFactors = FALSE
)

utils::write.csv(
  data.frame(Gene = rownames(pseudobulk_counts), as.matrix(pseudobulk_counts), check.names = FALSE),
  file.path(output_directory, "kang_cd14_pseudobulk_counts.csv"),
  row.names = FALSE
)
utils::write.csv(
  pseudobulk_metadata,
  file.path(output_directory, "kang_cd14_pseudobulk_metadata.csv"),
  row.names = FALSE
)

message(
  "Created ", ncol(pseudobulk_counts), " donor-by-condition pseudobulk profiles ",
  "from ", ncol(raw_counts), " CD14+ monocyte singlets in ", output_directory
)
