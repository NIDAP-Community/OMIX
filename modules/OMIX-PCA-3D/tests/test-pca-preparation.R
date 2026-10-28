#!/usr/bin/env Rscript

test_file <- sub("^--file=", "", commandArgs(FALSE)[grepl("^--file=", commandArgs(FALSE))])
module_dir <- normalizePath(file.path(dirname(test_file), ".."))
source(file.path(module_dir, "R", "OMIX_PCA_3D.R"))

feature_matrix <- utils::read.csv(
  file.path(module_dir, "tests", "fixtures", "feature_matrix.csv"),
  check.names = FALSE,
  stringsAsFactors = FALSE
)
sample_metadata <- utils::read.csv(
  file.path(module_dir, "tests", "fixtures", "sample_metadata.csv"),
  check.names = FALSE,
  stringsAsFactors = FALSE
)

prepared <- omix_pca_3d_prepare(
  feature_matrix = feature_matrix,
  sample_metadata = sample_metadata,
  feature_id_column = "Gene",
  sample_id_column = "Sample",
  sample_label_column = "DisplayLabel",
  group_column = "Group",
  samples_to_include = c("Sample_D", "Sample_B", "Sample_C", "Sample_A"),
  outlier_sample_ids = "Sample_B",
  point_color_names = c("indigo", "orange"),
  manual_label_renames = "Treatment C:treated sample C"
)

stopifnot(identical(prepared$selected_samples, c("Sample_D", "Sample_C", "Sample_A")))
stopifnot(identical(names(prepared$coordinates)[1:3], c("PC1", "PC2", "PC3")))
stopifnot(identical(prepared$coordinates$sample, c("Treatment D", "treated sample C", "Control A")))
stopifnot(identical(names(prepared$point_colors), c("Treatment", "Control")))
stopifnot(identical(unname(prepared$point_colors), c("#5954d6", "#FFA500")))
stopifnot(nrow(prepared$components) == 3L)
stopifnot(abs(sum(prepared$components$variance) - 100) < 1e-10)
stopifnot(identical(prepared$axis_titles, sub(" variance", "", prepared$components$variance_label[1:3])))

if (requireNamespace("edgeR", quietly = TRUE)) {
  cpm_prepared <- omix_pca_3d_prepare(
    feature_matrix = feature_matrix,
    sample_metadata = sample_metadata,
    feature_id_column = "Gene",
    sample_id_column = "Sample",
    sample_label_column = "DisplayLabel",
    group_column = "Group",
    use_cpm = TRUE
  )
  stopifnot(nrow(cpm_prepared$coordinates) == 4L)
  stopifnot(identical(
    unname(cpm_prepared$point_colors),
    c("#5954d6", "#e1562c")
  ))
} else {
  message("edgeR is unavailable; CPM-specific preparation check skipped.")
}

message("OMIX-PCA-3D preparation tests passed")
