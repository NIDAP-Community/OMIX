#!/usr/bin/env Rscript

test_file <- sub("^--file=", "", commandArgs(FALSE)[grepl("^--file=", commandArgs(FALSE))])
module_dir <- normalizePath(file.path(dirname(test_file), ".."))
result_dir <- tempfile("omix-pca-3d-")
on.exit(unlink(result_dir, recursive = TRUE), add = TRUE)

command <- c(
  file.path(module_dir, "scripts", "run_pca_3d.R"),
  paste0("--feature_matrix=", file.path(module_dir, "tests", "fixtures", "feature_matrix.csv")),
  paste0("--sample_metadata=", file.path(module_dir, "tests", "fixtures", "sample_metadata.csv")),
  "--feature_id_column=Gene",
  "--sample_label_column=DisplayLabel",
  "--group_column=Group",
  "--samples_to_include=Sample_D,Sample_B,Sample_C,Sample_A",
  "--outlier_sample_ids=Sample_B",
  "--point_colors=indigo,orange",
  paste0("--manual_label_renames=", shQuote("Treatment C:treated sample C")),
  paste0("--output_dir=", result_dir)
)
status <- system2("Rscript", command)
stopifnot(identical(status, 0L))

expected <- c(
  "pca_3d.html",
  "pca_3d_components.csv",
  "pca_3d_coordinates.csv",
  "pca_3d_run_summary.txt"
)
stopifnot(all(file.exists(file.path(result_dir, expected))))
stopifnot(dir.exists(file.path(result_dir, "pca_3d_files")))
coordinates <- utils::read.csv(file.path(result_dir, "pca_3d_coordinates.csv"), check.names = FALSE)
stopifnot(identical(names(coordinates)[1:3], c("PC1", "PC2", "PC3")))
stopifnot(identical(coordinates$sample, c("Treatment D", "treated sample C", "Control A")))
components <- utils::read.csv(file.path(result_dir, "pca_3d_components.csv"), check.names = FALSE)
stopifnot(identical(names(components), c("id", "eigenvalue", "variance", "cumvariance", "variance_label", "cumvariance_label")))
stopifnot(abs(sum(components$variance) - 100) < 1e-10)
summary_lines <- readLines(file.path(result_dir, "pca_3d_run_summary.txt"))
stopifnot(all(c(
  "module=omix-pca-3d",
  "selected_samples=Sample_D,Sample_C,Sample_A",
  "use_cpm=false",
  "self_contained_html=false",
  "features_after_template_filters=6"
) %in% summary_lines))
message("OMIX-PCA-3D CLI fixture test passed")
