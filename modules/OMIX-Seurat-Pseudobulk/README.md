# OMIX Seurat Pseudobulk

Create donor-level profiles from one selected cell type in an RDS-serialized
Seurat object. The module can sum raw counts for a count-based DEG model,
average a declared Harmony-corrected expression layer, or average Seurat
SCTransform expression for direct limma. Its portable result bundle routes
raw counts only to [OMIX DEG Analysis](../OMIX-DEG-Analysis/README.md) and
continuous-expression means only to
[OMIX Limma Analysis](../OMIX-Limma-Analysis/README.md).

## When to use it

Use this module when the biological replicates are donors, patients, animals,
or samples—not individual cells. It selects one exact cell type, optionally
applies an explicit cell-level filter, and makes one donor-by-group profile.

| Aggregation method | Source matrix | Output | Compatible downstream analysis |
| --- | --- | --- | --- |
| `sum_counts` | Raw integer-like `counts` layer | `Pseudobulk_Counts.csv` | `raw_counts`: edgeR TMM plus limma-voom, with batch modelling when needed. |
| `mean_harmony_corrected_expression` | SCWorkflow gene-level `Harmony/data` log2-scale expression | `Harmony_Mean_Expression.csv` | OMIX Limma Analysis, direct `ebayes`: no TMM, voom, or second batch correction. |
| `mean_sctransform_expression` | Seurat SCTransform `SCT/data` log1p corrected expression | `SCT_Mean_Log2_Expression.csv` | OMIX Limma Analysis, direct `ebayes_trend` on log2-scale donor means, with no TMM or voom. |

It reads objects through the OmixSeurat bridge. The dedicated
`r-seurat-conversion` runtime includes full Seurat only at this conversion
boundary, so that it can read specialized legacy classes such as `SCTAssay`.
Every downstream OMIX module receives portable tables and does not install or
require Seurat.

## Inputs

- A Seurat `.rds` object with the source assay and layer required by the chosen aggregation method.
- Cell metadata containing a donor column, an experimental-group column, and a cell-type column.
- One exact cell-type value to aggregate.
- Optional invariant sample-level metadata columns, such as `Batch`, to retain for DEG modelling.

Every selected donor-by-group profile must have at least 20 cells by default.
The module stops on an under-populated profile unless `--on_insufficient_cells drop` is explicitly selected.

## Quick start

Restore the `r-seurat-conversion` profile as described in the root README, then
run:

```bash
Rscript modules/OMIX-Seurat-Pseudobulk/scripts/run_seurat_pseudobulk.R \
  --seurat_rds /path/to/object.rds \
  --donor_column donor \
  --group_column condition \
  --cell_type_column cell_type \
  --cell_type 'CD14+ Monocytes' \
  --metadata_columns Batch \
  --aggregation_method sum_counts \
  --assay RNA \
  --layer counts \
  --output_dir /path/to/results/pseudobulk
```

## Runtime profile

This module uses `r-seurat-conversion`: the dedicated full-Seurat compatibility
profile that converts objects to portable OMIX tables. Restore it into a
writable run project before a local or HPC run:

```bash
Rscript scripts/restore-omix-runtime.R \
  --module OMIX-Seurat-Pseudobulk --project /path/to/omix-runtime
```

For a reproducible scientific result, pin the published
`r-seurat-conversion` image digest recorded in
`starter-environments/release-manifest.json`.

For a paired study, retain `Donor` in the output metadata and pass it to the
compatible downstream module as `--donor_variable_column Donor`.

For SCWorkflow-corrected expression, use its `Harmony/data` assay. The
`harmony` reduction holds embedding coordinates and is not a valid replacement
for a gene-expression layer.

```bash
Rscript modules/OMIX-Seurat-Pseudobulk/scripts/run_seurat_pseudobulk.R \
  --seurat_rds /path/to/object.rds \
  --donor_column donor \
  --group_column condition \
  --cell_type_column cell_type \
  --cell_type 'CD14+ Monocytes' \
  --metadata_columns Batch \
  --aggregation_method mean_harmony_corrected_expression \
  --assay Harmony \
  --layer data \
  --output_dir /path/to/results/harmony-means
```

For SCTransform-derived expression, leave the assay and layer on their
method-specific defaults. This reads `SCT/data`, averages the selected cells
per donor and group, and converts the donor means from log1p to log2 scale so
that the downstream DEG table has interpretable fold changes.

```bash
Rscript modules/OMIX-Seurat-Pseudobulk/scripts/run_seurat_pseudobulk.R \
  --seurat_rds /path/to/object.rds \
  --donor_column donor \
  --group_column condition \
  --cell_type_column cell_type \
  --cell_type 'CD14+ Monocytes' \
  --metadata_columns Batch \
  --aggregation_method mean_sctransform_expression \
  --output_dir /path/to/results/sct-means
```

### Development-only smoke test without the published runtime

To exercise legacy `SCTAssay` conversion locally without restoring the runtime,
use a clean writable R library, install `Seurat`, `optparse`, and the Core
dependencies, then install `core/` and `bridges/seurat/` from the *same OMIX
commit*. Do not treat that ad hoc development environment as a reproducible
scientific runtime; the committed lock and published image digest remain the
supported execution record.

## Outputs

| File | Use |
| --- | --- |
| `Pseudobulk_Counts.csv` | Written by `sum_counts`: raw integer-like counts with `GeneName` followed by one pseudobulk profile per column. |
| `Harmony_Mean_Expression.csv` | Written by `mean_harmony_corrected_expression`: donor-level means from the declared corrected expression layer. |
| `SCT_Mean_Log2_Expression.csv` | Written by `mean_sctransform_expression`: donor-level log2 means of SCTransform depth-corrected expression. |
| `Pseudobulk_Sample_Metadata.csv` | Aligned `Sample`, `Donor`, `Group`, `CellType`, `Cells`, and requested covariates such as `Batch`. Use as the compatible downstream metadata input. |
| `Pseudobulk_Manifest.dcf` | Matrix type, source layer, aggregation method, upstream correction, expected downstream module/mode, input kind, and recommended variance model. Pass it to OMIX Limma Analysis for a continuous-expression handoff. |
| `Pseudobulk_Run_Summary.txt` | Aggregation parameters, profile counts, selected-cell total, and bridge provenance. |

The module does not normalize, batch-correct, or fit a statistical model. The
manifest directs raw counts to DEG Analysis and continuous expression to Limma
Analysis.

## Data and method notes

- `sum_counts` defaults to `--layer counts`. Do not aggregate normalized,
  log-transformed, or batch-corrected cell-level values for count-based DEG.
- `mean_harmony_corrected_expression` averages `Harmony/data`, which is the
  gene-level corrected assay written by SCWorkflow. It does not run Harmony
  itself or validate the scientific adequacy of the upstream correction; record
  that upstream method and inspect batch/group diagnostics before
  interpretation. The corrected assay contains selected variable features plus
  explicitly retained genes, not necessarily the full transcriptome.
- `mean_sctransform_expression` uses only the `data` layer from the declared
  SCTransform assay (default `SCT`). SCTransform corrects sequencing-depth
  effects, but it does not itself establish that a technical batch has been
  handled. Record any upstream regression and model remaining batch as a DEG
  covariate when it is estimable.
- One invocation produces one cell-type-specific pseudobulk dataset. Run it
  separately for each cell type that requires its own biological comparison.
- `--metadata_columns` values must be non-missing and identical across all
  cells in each donor-by-group profile; this prevents ambiguous `Batch` or
  covariate assignments.
- The cell filter is deliberately explicit. For example, supply a singlet/QC
  metadata column only when that selection is part of the documented analysis.

## Integration

The module uses the optional [OmixSeurat bridge](../../bridges/seurat/README.md)
and the portable [omix_standard_input](../../core/README.md) contract. No Code
Ocean adapter exists yet; add one only after the portable CLI has been run
successfully with a representative object.
