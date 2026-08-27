# OmixSeurat

`OmixSeurat` is an optional, platform-neutral bridge from Seurat objects to
the raw-count and metadata tables consumed by OMIX modules. It imports
`SeuratObject`, not the full `Seurat` package.

The bridge does not treat individual cells as independent replicates. It
selects one cell type and sums raw counts per donor and condition, returning an
`omix_standard_input` with one pseudobulk profile per donor-by-group pair.

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
  cell_filter_column = "qc_status",
  cell_filter_values = "pass",
  assay = "RNA",
  layer = "counts"
)

input$counts
input$metadata
```

The output metadata contains `Sample`, `Donor`, `Group`, `CellType`, and
`Cells`. Use `Group` as the DEG contrast variable and `Donor` for a paired or
repeated-measures analysis.

`min_cells` defaults to 20 for each donor-by-group profile. The default action
is to stop rather than silently exclude under-populated profiles; set
`on_insufficient_cells = "drop"` only after reviewing the affected donors.

Optional `cell_filter_column` and `cell_filter_values` make a cell-level QC
decision explicit before aggregation. For example, use
`cell_filter_column = "multiplets", cell_filter_values = "singlet"` for the
Kang PBMC fixture. The bridge makes no filtering choice when these arguments
are omitted.

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
