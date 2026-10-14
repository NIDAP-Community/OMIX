#!/usr/bin/env Rscript

# End-to-end deterministic equivalence test for the portable public CLIs.
#
# This is intentionally stricter than the lightweight module unit tests:
# missing scientific dependencies are an error, not a skip. It generates a
# real SCTAssay at run time, executes all three Seurat Pseudobulk modes through
# scripts/run_seurat_pseudobulk.R, and then executes the routed canonical DEG
# or Limma CLI. Committed text baselines make the outputs machine-comparable
# without storing a binary Seurat object.

script_argument <- grep("^--file=", commandArgs(FALSE), value = TRUE)
if (length(script_argument) != 1L) {
  stop("Run this test with Rscript tests/test-public-cli-equivalence.R", call. = FALSE)
}
module_root <- normalizePath(
  file.path(dirname(sub("^--file=", "", script_argument)), "..")
)
repo_root <- normalizePath(file.path(module_root, "..", ".."))
fixture_root <- file.path(module_root, "tests", "fixtures")
expected_root <- file.path(fixture_root, "expected")

test_arguments <- commandArgs(trailingOnly = TRUE)
record_expected <- FALSE
record_root <- NULL
execution_phase <- "all"
shared_working_dir <- NULL
if (length(test_arguments) > 0L) {
  if (length(test_arguments) == 2L && identical(test_arguments[[1L]], "--record-expected")) {
    record_root <- test_arguments[[2L]]
    if (!nzchar(record_root) || file.exists(record_root)) {
      stop("--record-expected must name a new, non-existing directory.", call. = FALSE)
    }
    dir.create(record_root, recursive = TRUE, showWarnings = FALSE)
    record_expected <- TRUE
  } else if (
    length(test_arguments) == 4L &&
      identical(test_arguments[[1L]], "--phase") &&
      identical(test_arguments[[3L]], "--working-dir")
  ) {
    execution_phase <- test_arguments[[2L]]
    shared_working_dir <- test_arguments[[4L]]
    if (!execution_phase %in% c("conversion", "downstream")) {
      stop("--phase must be conversion or downstream.", call. = FALSE)
    }
    if (!nzchar(shared_working_dir)) {
      stop("--working-dir must name a persistent handoff directory.", call. = FALSE)
    }
  } else {
    stop(
      paste(
        "Usage: test-public-cli-equivalence.R",
        "[--record-expected NEW_DIRECTORY]",
        "[--phase conversion|downstream --working-dir DIRECTORY]"
      ),
      call. = FALSE
    )
  }
}

conversion_packages <- c(
  "Matrix", "Seurat", "SeuratObject", "sctransform", "OmixSeurat", "optparse"
)
downstream_packages <- c("optparse", "edgeR", "limma")
required_packages <- switch(
  execution_phase,
  conversion = conversion_packages,
  downstream = downstream_packages,
  all = unique(c(conversion_packages, downstream_packages))
)
missing_packages <- required_packages[
  !vapply(required_packages, requireNamespace, logical(1), quietly = TRUE)
]
if (length(missing_packages) > 0L) {
  stop(
    "Public-CLI equivalence requires all scientific dependencies: ",
    paste(missing_packages, collapse = ", "),
    ". Restore the declared OMIX runtimes; this dedicated test must not skip.",
    call. = FALSE
  )
}

required_baselines <- c(
  "equivalence-contract.dcf",
  "baseline-provenance.dcf",
  "Pseudobulk_Sample_Metadata.csv",
  "Pseudobulk_Counts.csv",
  "Harmony_Mean_Expression.csv",
  "SCT_Mean_Log2_Expression.csv",
  "Raw_Pseudobulk_Manifest.dcf",
  "Harmony_Pseudobulk_Manifest.dcf",
  "SCT_Pseudobulk_Manifest.dcf",
  "Raw_DEG_Analysis.csv",
  "Harmony_Limma_Analysis.csv",
  "SCT_Limma_Analysis.csv"
)
missing_baselines <- required_baselines[
  !file.exists(file.path(expected_root, required_baselines))
]
if (!record_expected && length(missing_baselines) > 0L) {
  stop(
    "Equivalence baseline is incomplete: ",
    paste(missing_baselines, collapse = ", "),
    call. = FALSE
  )
}

run_cli <- function(script, arguments, label) {
  output <- suppressWarnings(system2(
    file.path(R.home("bin"), "Rscript"),
    c(script, arguments),
    stdout = TRUE,
    stderr = TRUE
  ))
  status <- attr(output, "status")
  if (!is.null(status)) {
    stop(
      label, " failed with status ", status, ":\n",
      paste(output, collapse = "\n"),
      call. = FALSE
    )
  }
  invisible(output)
}

read_csv <- function(path) {
  utils::read.csv(
    path,
    check.names = FALSE,
    stringsAsFactors = FALSE,
    na.strings = ""
  )
}

# Compare schema, ordering, categorical values, missingness, and numeric values
# independently. This yields useful failures and prevents NA or row reordering
# from being hidden by a single all.equal call.
compare_table <- function(actual_path, expected_path, tolerance, label) {
  actual <- read_csv(actual_path)
  expected <- read_csv(expected_path)
  if (!identical(names(actual), names(expected))) {
    stop(label, " column names/order differ from the committed baseline.", call. = FALSE)
  }
  if (!identical(dim(actual), dim(expected))) {
    stop(label, " dimensions differ from the committed baseline.", call. = FALSE)
  }
  for (column in names(expected)) {
    actual_missing <- is.na(actual[[column]])
    expected_missing <- is.na(expected[[column]])
    if (!identical(actual_missing, expected_missing)) {
      stop(label, " missingness differs in column ", column, ".", call. = FALSE)
    }
    keep <- !expected_missing
    if (is.numeric(expected[[column]])) {
      if (!is.numeric(actual[[column]])) {
        stop(label, " column ", column, " is no longer numeric.", call. = FALSE)
      }
      difference <- abs(actual[[column]][keep] - expected[[column]][keep])
      maximum_difference <- if (length(difference)) max(difference) else 0
      if (!is.finite(maximum_difference) || maximum_difference > tolerance) {
        stop(
          label, " numeric difference in ", column, " is ",
          format(maximum_difference, scientific = TRUE),
          "; tolerance is ", format(tolerance, scientific = TRUE), ".",
          call. = FALSE
        )
      }
    } else if (!identical(actual[[column]][keep], expected[[column]][keep])) {
      stop(label, " categorical/identifier values differ in column ", column, ".", call. = FALSE)
    }
  }
  invisible(actual)
}

compare_manifest <- function(actual_path, expected_path, label) {
  actual <- base::read.dcf(actual_path)
  expected <- base::read.dcf(expected_path)
  if (!identical(colnames(actual), colnames(expected)) ||
      !identical(unname(actual), unname(expected))) {
    stop(label, " manifest differs from the committed baseline.", call. = FALSE)
  }
  invisible(actual)
}

assert_summary_value <- function(path, expected_line) {
  summary_lines <- readLines(path, warn = FALSE)
  if (!expected_line %in% summary_lines) {
    stop("Missing expected run-summary line: ", expected_line, call. = FALSE)
  }
}

if (is.null(shared_working_dir)) {
  working_dir <- tempfile("omix-pseudobulk-public-cli-equivalence-")
  dir.create(working_dir, recursive = TRUE)
  on.exit(unlink(working_dir, recursive = TRUE, force = TRUE), add = TRUE)
} else {
  dir.create(shared_working_dir, recursive = TRUE, showWarnings = FALSE)
  working_dir <- normalizePath(shared_working_dir)
}

fixture_path <- file.path(working_dir, "synthetic-seurat.rds")
if (execution_phase %in% c("all", "conversion")) {
  existing_outputs <- file.path(
    working_dir,
    c("raw-pseudobulk", "harmony-pseudobulk", "sct-pseudobulk")
  )
  if (any(file.exists(existing_outputs))) {
    stop(
      "Conversion phase requires a working directory without prior pseudobulk outputs.",
      call. = FALSE
    )
  }
  run_cli(
    file.path(fixture_root, "generate_synthetic_seurat_fixture.R"),
    fixture_path,
    "Synthetic fixture generation"
  )
  fixture <- readRDS(fixture_path)
  if (!inherits(fixture[["SCT"]], "SCTAssay")) {
    stop("Serialized fixture does not contain a real SCTAssay.", call. = FALSE)
  }
}

expected_features <- paste0("Gene", sprintf("%03d", seq_len(120L)))
expected_samples <- as.vector(rbind(
  paste0("D", seq_len(4L), "__A"),
  paste0("D", seq_len(4L), "__B")
))
expected_donors <- rep(paste0("D", seq_len(4L)), each = 2L)
expected_groups <- rep(c("A", "B"), 4L)
expected_batches <- rep(c("Run1", "Run1", "Run2", "Run2"), each = 2L)

pseudobulk_cli <- file.path(module_root, "scripts", "run_seurat_pseudobulk.R")
deg_cli <- file.path(repo_root, "modules", "OMIX-DEG-Analysis", "scripts", "run_deg_analysis.R")
limma_cli <- file.path(repo_root, "modules", "OMIX-Limma-Analysis", "scripts", "run_limma_analysis.R")
contract <- base::read.dcf(file.path(expected_root, "equivalence-contract.dcf"))
if (record_expected) {
  invisible(file.copy(
    file.path(expected_root, "equivalence-contract.dcf"),
    file.path(record_root, "equivalence-contract.dcf")
  ))
  package_version <- function(package) as.character(utils::packageVersion(package))
  base::write.dcf(data.frame(
    format_version = "1",
    fixture_seed = "92042",
    fixture_features = "120",
    fixture_profiles = "8",
    cells_per_profile = "3",
    r_version = paste(R.version$major, R.version$minor, sep = "."),
    Seurat = package_version("Seurat"),
    SeuratObject = package_version("SeuratObject"),
    sctransform = package_version("sctransform"),
    Omix = package_version("Omix"),
    OmixSeurat = package_version("OmixSeurat"),
    edgeR = package_version("edgeR"),
    limma = package_version("limma"),
    optparse = package_version("optparse"),
    note = paste(
      "Candidate text baseline; record published-container equivalence",
      "as a separate execution record."
    ),
    check.names = FALSE,
    stringsAsFactors = FALSE
  ), file.path(record_root, "baseline-provenance.dcf"))
}

mode_prefix <- c(
  sum_counts = "Raw",
  mean_harmony_corrected_expression = "Harmony",
  mean_sctransform_expression = "SCT"
)
mode_output <- list()
downstream_output <- list()

for (index in seq_len(nrow(contract))) {
  mode <- unname(contract[index, "mode"])
  prefix <- unname(mode_prefix[[mode]])
  output_dir <- file.path(working_dir, paste0(tolower(prefix), "-pseudobulk"))
  metadata_path <- file.path(output_dir, "Pseudobulk_Sample_Metadata.csv")
  matrix_file <- unname(contract[index, "matrix_file"])
  matrix_path <- file.path(output_dir, matrix_file)
  manifest_path <- file.path(output_dir, "Pseudobulk_Manifest.dcf")
  downstream_dir <- file.path(working_dir, paste0(tolower(prefix), "-downstream"))

  if (execution_phase %in% c("all", "conversion")) {
    arguments <- c(
      "--seurat_rds", fixture_path,
      "--donor_column", "Donor",
      "--group_column", "Group",
      "--cell_type_column", "CellType",
      "--cell_type", "Monocytes",
      "--metadata_columns", "Batch",
      "--cell_filter_column", "Include",
      "--cell_filter_values", "yes",
      "--aggregation_method", mode,
      "--min_cells", "3",
      "--output_dir", output_dir
    )
    run_cli(pseudobulk_cli, arguments, paste(prefix, "Pseudobulk CLI"))
    mode_output[[mode]] <- output_dir

    metadata <- if (record_expected) {
      read_csv(metadata_path)
    } else {
      compare_table(
        metadata_path,
        file.path(expected_root, "Pseudobulk_Sample_Metadata.csv"),
        tolerance = 0,
        label = paste(prefix, "sample metadata")
      )
    }
    if (record_expected && index == 1L) {
      invisible(file.copy(
        metadata_path,
        file.path(record_root, "Pseudobulk_Sample_Metadata.csv")
      ))
    }
    stopifnot(
      identical(as.character(metadata$Sample), expected_samples),
      identical(as.character(metadata$Donor), expected_donors),
      identical(as.character(metadata$Group), expected_groups),
      identical(as.character(metadata$Batch), expected_batches),
      identical(as.character(metadata$CellType), rep("Monocytes", 8L)),
      identical(as.integer(metadata$Cells), rep(3L, 8L)),
      !anyNA(metadata)
    )

    matrix <- if (record_expected) {
      read_csv(matrix_path)
    } else {
      compare_table(
        matrix_path,
        file.path(expected_root, unname(contract[index, "expected_matrix"])),
        tolerance = as.numeric(contract[index, "matrix_tolerance"]),
        label = paste(prefix, "donor-level matrix")
      )
    }
    if (record_expected) {
      invisible(file.copy(
        matrix_path,
        file.path(record_root, unname(contract[index, "expected_matrix"]))
      ))
    }
    stopifnot(
      identical(as.character(matrix[["GeneName"]]), expected_features),
      identical(names(matrix)[-1L], expected_samples),
      !anyNA(matrix)
    )

    expected_manifest_name <- paste0(prefix, "_Pseudobulk_Manifest.dcf")
    manifest <- if (record_expected) {
      base::read.dcf(manifest_path)
    } else {
      compare_manifest(
        manifest_path,
        file.path(expected_root, expected_manifest_name),
        paste(prefix, "Pseudobulk")
      )
    }
    if (record_expected) {
      invisible(file.copy(
        manifest_path,
        file.path(record_root, expected_manifest_name)
      ))
    }
    stopifnot(
      identical(unname(manifest[1L, "matrix_type"]), unname(contract[index, "matrix_type"])),
      identical(
        unname(manifest[1L, "expected_downstream_module"]),
        unname(contract[index, "downstream_module"])
      ),
      identical(
        unname(manifest[1L, "recommended_variance_model"]),
        unname(contract[index, "variance_model"])
      )
    )
  }

  if (execution_phase %in% c("all", "downstream")) {
    missing_handoff <- c(metadata_path, matrix_path, manifest_path)[
      !file.exists(c(metadata_path, matrix_path, manifest_path))
    ]
    if (length(missing_handoff) > 0L) {
      stop(
        "Downstream phase is missing conversion handoff file(s): ",
        paste(missing_handoff, collapse = ", "),
        call. = FALSE
      )
    }
    if (identical(mode, "sum_counts")) {
      run_cli(
        deg_cli,
        c(
          "--input_type", "table",
          "--analysis_mode", "raw_counts",
          "--counts", file.path(output_dir, matrix_file),
          "--metadata", metadata_path,
          "--pseudobulk_manifest", file.path(output_dir, "Pseudobulk_Manifest.dcf"),
          "--contrasts", "B-A",
          "--donor_variable_column", "Donor",
          "--batch_effect_columns", "Batch",
          "--write_normalization_diagnostics", "false",
          "--output_dir", downstream_dir
        ),
        "Raw-count DEG CLI"
      )
      assert_summary_value(file.path(downstream_dir, "run_summary.txt"), "analysis mode: raw_counts")
      assert_summary_value(file.path(downstream_dir, "run_summary.txt"), "model type: repeated_measures")
    } else {
      run_cli(
        limma_cli,
        c(
          "--matrix", file.path(output_dir, matrix_file),
          "--metadata", metadata_path,
          "--pseudobulk_manifest", file.path(output_dir, "Pseudobulk_Manifest.dcf"),
          "--contrasts", "B-A",
          "--donor_variable_column", "Donor",
          "--output_dir", downstream_dir
        ),
        paste(prefix, "Limma CLI")
      )
      assert_summary_value(
        file.path(downstream_dir, "run_summary.txt"),
        paste("variance model:", unname(contract[index, "variance_model"]))
      )
    }
    downstream_output[[mode]] <- downstream_dir

    downstream_path <- file.path(
      downstream_dir,
      unname(contract[index, "downstream_file"])
    )
    downstream <- if (record_expected) {
      read_csv(downstream_path)
    } else {
      compare_table(
        downstream_path,
        file.path(expected_root, unname(contract[index, "expected_downstream"])),
        tolerance = as.numeric(contract[index, "downstream_tolerance"]),
        label = paste(prefix, "downstream analysis")
      )
    }
    if (record_expected) {
      invisible(file.copy(
        downstream_path,
        file.path(record_root, unname(contract[index, "expected_downstream"]))
      ))
    }
    gene_column <- if ("GeneName" %in% names(downstream)) "GeneName" else "Gene"
    stopifnot(
      identical(as.character(downstream[[gene_column]]), expected_features),
      identical(tail(names(downstream), length(expected_samples)), expected_samples)
    )
  }
}

if (record_expected) {
  message("Recorded candidate equivalence baseline in ", normalizePath(record_root))
} else {
  message(
    "OMIX Seurat Pseudobulk public-CLI equivalence ", execution_phase,
    " phase passed for raw counts, legacy Harmony/data, and real SCTAssay routes"
  )
}
