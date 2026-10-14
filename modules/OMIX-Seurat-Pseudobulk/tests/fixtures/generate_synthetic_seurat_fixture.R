#!/usr/bin/env Rscript

# Build the small serialized object used by the public-CLI equivalence test.
#
# The fixture is generated at test time instead of committed as an RDS. This
# keeps binary, package-version-specific Seurat serialization out of Git while
# still exercising deserialization of a real SCTAssay produced by SCTransform.

required_packages <- c("Matrix", "Seurat", "SeuratObject", "sctransform")
missing_packages <- required_packages[
  !vapply(required_packages, requireNamespace, logical(1), quietly = TRUE)
]
if (length(missing_packages) > 0L) {
  stop(
    "Synthetic Seurat fixture generation requires: ",
    paste(missing_packages, collapse = ", "),
    ". Restore the r-seurat-conversion runtime; this equivalence fixture must not skip.",
    call. = FALSE
  )
}

arguments <- commandArgs(trailingOnly = TRUE)
if (length(arguments) != 1L || !nzchar(arguments[[1L]])) {
  stop("Usage: generate_synthetic_seurat_fixture.R OUTPUT.rds", call. = FALSE)
}
output_path <- arguments[[1L]]
dir.create(dirname(output_path), recursive = TRUE, showWarnings = FALSE)

# Four paired donors, two conditions, and three cells per donor-condition
# profile are enough to exercise donor-aware downstream models while keeping
# SCTransform fast. Cell ordering is deliberate because profile ordering is a
# public handoff property checked by the driver.
donors <- paste0("D", seq_len(4L))
groups <- c("A", "B")
profile_grid <- expand.grid(
  Group = groups,
  Donor = donors,
  KEEP.OUT.ATTRS = FALSE,
  stringsAsFactors = FALSE
)
profile_grid <- profile_grid[order(match(profile_grid$Donor, donors), match(profile_grid$Group, groups)), ]
metadata <- profile_grid[rep(seq_len(nrow(profile_grid)), each = 3L), , drop = FALSE]
metadata$CellType <- "Monocytes"
metadata$Batch <- ifelse(metadata$Donor %in% c("D1", "D2"), "Run1", "Run2")
metadata$Include <- "yes"
rownames(metadata) <- paste0("Cell", sprintf("%02d", seq_len(nrow(metadata))))

# A fixed seed plus an explicit effect creates reproducible integer RNA counts
# without depending on external data. The first 18 genes have a strong B-A
# effect, the next six have the opposite effect, and all genes retain cell-level
# variation for SCTransform fitting.
set.seed(92042L)
feature_ids <- paste0("Gene", sprintf("%03d", seq_len(120L)))
counts <- matrix(
  stats::rpois(length(feature_ids) * nrow(metadata), lambda = 9),
  nrow = length(feature_ids),
  dimnames = list(feature_ids, rownames(metadata))
)
counts[seq_len(18L), metadata$Group == "B"] <-
  counts[seq_len(18L), metadata$Group == "B", drop = FALSE] + 12L
counts[19:24, metadata$Group == "A"] <-
  counts[19:24, metadata$Group == "A", drop = FALSE] + 8L

object <- SeuratObject::CreateSeuratObject(
  counts = Matrix::Matrix(counts, sparse = TRUE),
  meta.data = metadata,
  assay = "RNA"
)

# SCWorkflow serializations use a legacy slot-based Assay named Harmony for
# corrected gene-level expression. This is intentionally distinct from a
# Harmony dimensional-reduction embedding.
harmony_expression <- log2(counts + 1)
harmony_expression[seq_len(18L), metadata$Group == "B"] <-
  harmony_expression[seq_len(18L), metadata$Group == "B", drop = FALSE] + 0.35
harmony_expression <- sweep(
  harmony_expression,
  MARGIN = 1L,
  STATS = (seq_along(feature_ids) %% 7L) / 100,
  FUN = "+"
)
harmony_assay <- SeuratObject::CreateAssayObject(
  counts = Matrix::Matrix(counts, sparse = TRUE)
)
methods::slot(harmony_assay, "data") <- Matrix::Matrix(
  harmony_expression,
  sparse = TRUE
)
object[["Harmony"]] <- harmony_assay

# Produce, and explicitly verify, a genuine SCTAssay. The seed is reset so the
# SCTransform result is independent of any preceding random-number use.
set.seed(92042L)
object <- Seurat::SCTransform(
  object = object,
  assay = "RNA",
  new.assay.name = "SCT",
  vst.flavor = "v1",
  variable.features.n = 60L,
  return.only.var.genes = FALSE,
  verbose = FALSE
)
if (!inherits(object[["SCT"]], "SCTAssay")) {
  stop("SCTransform did not produce the required SCTAssay fixture.", call. = FALSE)
}

saveRDS(object, output_path, version = 3)
message("Wrote deterministic synthetic Seurat fixture to ", normalizePath(output_path))
