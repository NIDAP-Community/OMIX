script_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
if (length(script_arg) != 1L) {
  stop("Run this test with Rscript tests/test-omix-deg-analysis.R")
}
module_root <- normalizePath(file.path(dirname(sub("^--file=", "", script_arg)), ".."))
source(file.path(module_root, "R", "OMIX_DEG_Analysis.R"))

make_unpaired_fixture <- function() {
  set.seed(42)
  sample_ids <- c("A1", "A2", "A3", "B1", "B2", "B3")
  counts <- matrix(stats::rpois(400L * length(sample_ids), lambda = 80), ncol = length(sample_ids))
  counts[seq_len(60L), sample_ids %in% c("B1", "B2", "B3")] <-
    counts[seq_len(60L), sample_ids %in% c("B1", "B2", "B3")] + 80
  colnames(counts) <- sample_ids
  list(
    dataset = data.frame(Gene = paste0("Gene", seq_len(nrow(counts))), counts, check.names = FALSE),
    metadata = data.frame(
      Sample = sample_ids,
      Condition = rep(c("A", "B"), each = 3L),
      Batch = c("Run1", "Run2", "Run1", "Run2", "Run1", "Run2"),
      stringsAsFactors = FALSE
    )
  )
}

fixture <- make_unpaired_fixture()
stopifnot(identical(
  names(formals(.omix_deg_normalization_profile)),
  "value"
))
profile_error <- tryCatch(
  .omix_deg_normalization_profile("not-a-profile"),
  error = conditionMessage
)
stopifnot(
  identical(
    profile_error,
    "normalization_method must be one of: TMM, Quantile, TMM + Quantile, TMM + Scale, TMM + Cyclic Loess, TMMwsp, RLE, Upper Quartile."
  )
)
unpaired <- omix_deg_analysis(
  Dataset = fixture$dataset,
  Metadata_Table = fixture$metadata,
  sample_names_column = "Sample",
  samples_to_include = fixture$metadata$Sample,
  gene_names_column = "Gene",
  contrast_variable_columns = "Condition",
  contrasts = "B-A",
  batch_effect_columns = "Batch",
  normalization_method = "TMM + Quantile"
)

stopifnot(all(c("Gene", "B-A_logFC", "B-A_pval", "B-A_adjpval") %in% colnames(unpaired)))
stopifnot(identical(tail(colnames(unpaired), 6L), fixture$metadata$Sample))
stopifnot(identical(attr(unpaired, "omix_deg_run")$model_type, "linear"))
stopifnot(identical(attr(unpaired, "omix_deg_run")$expression_output, "batch_adjusted_voom"))
stopifnot(identical(attr(unpaired, "omix_deg_run")$normalization_method, "TMM + Quantile"))
stopifnot(identical(attr(unpaired, "omix_deg_run")$voom_scale_normalization, "quantile"))

diagnostic_directory <- tempfile("omix-deg-normalization-diagnostics-")
diagnostic_run <- omix_deg_analysis(
  Dataset = fixture$dataset,
  Metadata_Table = fixture$metadata,
  sample_names_column = "Sample",
  samples_to_include = fixture$metadata$Sample,
  gene_names_column = "Gene",
  contrast_variable_columns = "Condition",
  contrasts = "B-A",
  normalization_diagnostics = TRUE,
  diagnostics_output_dir = diagnostic_directory
)
diagnostic_files <- attr(diagnostic_run, "omix_deg_run")$normalization_diagnostic_files
stopifnot(identical(basename(diagnostic_files), c(
  "normalization_boxplots.png",
  "normalization_densities.png",
  "voom_mean_variance.png"
)))
stopifnot(all(file.exists(diagnostic_files)))
unlink(diagnostic_directory, recursive = TRUE)

paired_metadata <- data.frame(
  Sample = c("D1_A", "D1_B", "D2_A", "D2_B", "D3_A", "D3_B"),
  Condition = rep(c("A", "B"), 3L),
  Donor = rep(paste0("D", 1:3), each = 2L),
  stringsAsFactors = FALSE
)
paired_counts <- fixture$dataset[, c("Gene", fixture$metadata$Sample), drop = FALSE]
colnames(paired_counts)[-1L] <- paired_metadata$Sample
paired <- omix_deg_analysis(
  Dataset = paired_counts,
  Metadata_Table = paired_metadata,
  sample_names_column = "Sample",
  samples_to_include = paired_metadata$Sample,
  gene_names_column = "Gene",
  contrast_variable_columns = "Condition",
  contrasts = "B-A",
  donor_variable_column = "Donor"
)
stopifnot(identical(attr(paired, "omix_deg_run")$model_type, "repeated_measures"))
stopifnot(identical(attr(paired, "omix_deg_run")$expression_output, "batch_adjusted_voom"))

duplicate_metadata <- rbind(paired_metadata, transform(paired_metadata[1L, , drop = FALSE], Sample = "D1_A_repeat"))
duplicate_counts <- cbind(paired_counts, D1_A_repeat = paired_counts[["D1_A"]])
duplicate_error <- tryCatch(
  omix_deg_analysis(
    Dataset = duplicate_counts,
    Metadata_Table = duplicate_metadata,
    sample_names_column = "Sample",
    samples_to_include = duplicate_metadata$Sample,
    gene_names_column = "Gene",
    contrast_variable_columns = "Condition",
    contrasts = "B-A",
    donor_variable_column = "Donor"
  ),
  error = conditionMessage
)
stopifnot(is.character(duplicate_error), grepl("Technical replicates detected", duplicate_error, fixed = TRUE))

under_replicated_metadata <- fixture$metadata[fixture$metadata$Sample %in% c("A1", "B1", "B2"), , drop = FALSE]
under_replicated_error <- tryCatch(
  omix_deg_analysis(
    Dataset = fixture$dataset[, c("Gene", under_replicated_metadata$Sample), drop = FALSE],
    Metadata_Table = under_replicated_metadata,
    sample_names_column = "Sample",
    samples_to_include = under_replicated_metadata$Sample,
    gene_names_column = "Gene",
    contrast_variable_columns = "Condition",
    contrasts = "B-A"
  ),
  error = conditionMessage
)
stopifnot(
  is.character(under_replicated_error),
  grepl("Each comparison group must contain at least two biological samples", under_replicated_error, fixed = TRUE)
)

message("OMIX DEG raw-count model tests passed")
