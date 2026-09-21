# OmixSeurat

`OmixSeurat` is an optional, platform-neutral bridge from Seurat objects to
donor-level raw-count or continuous-expression tables consumed by OMIX
modules. It imports `SeuratObject`, not the full `Seurat` package.

The bridge does not treat individual cells as independent replicates. It
selects one cell type and makes one profile per donor-by-group pair. For raw
counts it returns an `omix_standard_input`; for a declared corrected expression
layer it returns an `omix_expression_input` with donor means.

## Install

Install OMIX Core and the bridge from the same OMIX revision:

```r
remotes::install_github("NIDAP-Community/OMIX", subdir = "core")
remotes::install_github("NIDAP-Community/OMIX", subdir = "bridges/seurat")
```

## Convert a Seurat object

```r
library(OmixSeurat)

input <- omix_seurat_to_input(
  seurat_object = object,
  donor_column = "donor",
  group_column = "condition",
  cell_type_column = "cell_type",
  cell_type = "CD14+ Monocytes",
  sample_metadata_columns = c("Batch", "Sex"),
  cell_filter_column = "qc_status",
  cell_filter_values = "pass",
  assay = "RNA",
  layer = "counts"
)

input$counts
input$metadata
```

The count table uses `GeneName` as its feature-ID column. Output metadata
contains `Sample`, `Donor`, `Group`, `CellType`, `Cells`, and any requested
invariant sample-level covariates such as `Batch`. Use `Group` as the DEG
contrast variable, retain `Batch` when applicable, and use `Donor` for a
paired or repeated-measures analysis.

`min_cells` defaults to 20 for each donor-by-group profile. The default action
is to stop rather than silently exclude under-populated profiles; set
`on_insufficient_cells = "drop"` only after reviewing the affected donors.

Optional `cell_filter_column` and `cell_filter_values` make a cell-level QC
decision explicit before aggregation. For example, use
`cell_filter_column = "multiplets", cell_filter_values = "singlet"` for the
Kang PBMC fixture. The bridge makes no filtering choice when these arguments
are omitted.

Use `sample_metadata_columns` to retain cell-metadata fields needed by a
downstream model, such as `Batch`, `Sex`, or treatment metadata. Every
requested value must be identical and non-missing among cells in a
donor-by-group profile; the bridge stops rather than assigning an ambiguous
covariate value.

## Convert a declared corrected expression layer

Use this path only when the source is a documented gene-level corrected
expression matrix. A Harmony embedding/reduction is not gene expression and
cannot be used for gene-level limma.

```r
means <- omix_seurat_to_expression_input(
  seurat_object = object,
  donor_column = "donor",
  group_column = "condition",
  cell_type_column = "cell_type",
  cell_type = "CD14+ Monocytes",
  sample_metadata_columns = "Batch",
  assay = "RNA",
  layer = "harmony_corrected"
)

means$expression
means$metadata
```

The function only calculates the arithmetic mean. It does not run Harmony,
normalize values, or remove batches. The caller must record and validate the
source layer before passing the result to OMIX DEG Analysis in
`harmony_mean_expression` mode. Do not add `Batch` again in that downstream
mode; retain it only as provenance/QC metadata.

## Read an RDS

```r
input <- omix_read_seurat_rds(
  "object.rds",
  donor_column = "donor",
  group_column = "condition",
  cell_type_column = "cell_type",
  cell_type = "CD14+ Monocytes"
)
```

`readRDS()` still needs `SeuratObject` available because it defines the object
classes. The bridge explicitly requests the raw `RNA` `counts` layer, avoiding
the active assay and avoiding a dependency on the full Seurat package for
supported objects.

For corrected expression, use `omix_read_seurat_expression_rds()` with the
same donor, group, cell-type, assay, and layer arguments.
