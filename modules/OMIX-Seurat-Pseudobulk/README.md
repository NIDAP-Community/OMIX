# OMIX Seurat Pseudobulk

Create donor-level profiles from one selected cell category in an RDS-serialized
Seurat object. A category can be a cell category, cluster, subcluster, tissue or
spatial region, or a declared cell-state label. The module can sum raw counts for a count-based DEG model,
average a declared Harmony-corrected expression layer, or average Seurat
SCTransform expression for direct limma. Its portable result bundle routes
raw counts only to [OMIX DEG Analysis](../OMIX-DEG-Analysis/README.md) and
continuous-expression means only to
[OMIX Limma Analysis](../OMIX-Limma-Analysis/README.md).

## When to use it

Use this module when the biological replicates are donors, patients, animals,
or samples—not individual cells. It selects one exact cell category, optionally
applies an explicit cell-level filter, and makes one donor-by-group profile.

| Aggregation method | Source matrix | Output | Compatible downstream analysis |
| --- | --- | --- | --- |
| `sum_counts` | Raw integer-like `counts` layer | `Pseudobulk_Counts.csv` | `raw_counts`: edgeR TMM plus limma-voom, with batch modelling when needed. |
| `mean_harmony_corrected_expression` | SCWorkflow gene-level `Harmony/data` log2-scale expression | `Harmony_Mean_Expression.csv` | OMIX Limma Analysis, direct `ebayes`: no TMM, voom, or second batch correction. |
| `mean_sctransform_expression` | Seurat SCTransform `SCT/data` log1p corrected expression | `SCT_Mean_Log2_Expression.csv` | OMIX Limma Analysis, direct `ebayes_trend` on log2-scale donor means, with no TMM or voom. |

It reads objects through the OmixSeurat bridge. The dedicated
`r-seurat-conversion` runtime includes full Seurat only at this conversion
boundary, so that it can read specialized legacy classes such as `SCTAssay`.
It also supports the standard matrix slots of legacy `Assay` objects when a
declared assay such as `Harmony` is present in the serialized object but is not
recognized by the installed SeuratObject layer accessor.
Every downstream OMIX module receives portable tables and does not install or
require Seurat.

## Inputs

- A Seurat `.rds` object with the source assay and layer required by the chosen aggregation method.
- Cell metadata containing a donor column, an experimental-group column, and a category column.
- One exact category value to aggregate in one mode, or an ordered set of category labels in collection mode.
- Optional invariant sample-level metadata columns, such as `Batch`, to retain for DEG modelling.

Use `--cell_category_column` and `--cell_category` for the category input.
The category is any non-missing metadata label used to form separate
pseudobulk outputs: for example, a cell type, `seurat_clusters`, a
subcluster, a spatial region, or a cell-state label. It must be represented in
at least two experimental groups after filtering to form a downstream
comparison.

`--cell_filter_column` and `--cell_filter_values` mean something different:
they are an optional, shared pre-aggregation inclusion filter. They retain only
cells whose filter column has one of the supplied exact values before category
discovery and aggregation. For example, use a singlet/QC flag to exclude cells
from every category, or a compartment value to analyze only tumor cells. The
filter does not create separate outputs.

The output feature identifier is fixed to `GeneName`. This is part of the
portable handoff contract with OMIX DEG Analysis and OMIX Limma Analysis; it
is not a freely configurable column name.

Every selected donor-by-group profile must have at least 20 cells by default.
The module stops on an under-populated profile unless `--on_insufficient_cells drop` is explicitly selected. In a selected/all collection, `drop` also omits a category that no longer retains two experimental groups after sparse profiles are removed, and records that omission in the collection artifacts.

`--output_dir` is required. It must name a new or empty directory: the module
rejects an existing non-empty directory so results from separate runs cannot be
mixed.

## Quick start

Restore the `r-seurat-conversion` profile as described in the root README, then
run:

```bash
Rscript modules/OMIX-Seurat-Pseudobulk/scripts/run_seurat_pseudobulk.R \
  --seurat_rds /path/to/object.rds \
  --donor_column donor \
  --group_column condition \
  --cell_category_column cell_category \
  --cell_category 'CD14+ Monocytes' \
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
  --cell_category_column cell_category \
  --cell_category 'CD14+ Monocytes' \
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
  --cell_category_column cell_category \
  --cell_category 'CD14+ Monocytes' \
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
| `Pseudobulk_Sample_Metadata.csv` | Aligned `Sample`, `Donor`, `Group`, `CellCategory`, `Cells`, and requested covariates such as `Batch`. Use as the compatible downstream metadata input. |
| `Pseudobulk_Manifest.dcf` | Matrix type, source layer, aggregation method, upstream correction, expected downstream module/mode, input kind, and recommended variance model. Pass it to OMIX Limma Analysis for a continuous-expression handoff. |
| `Pseudobulk_Run_Summary.txt` | Aggregation parameters, profile counts, selected-cell total, and bridge provenance. |

The module does not normalize, batch-correct, or fit a statistical model. The
manifest directs raw counts to DEG Analysis and continuous expression to Limma
Analysis.

## Multiple cell categories

The default one mode preserves the established one-label command and root-level
output bundle. It is the right choice for one category.

For a planned collection, use selected mode with an ordered CSV, TSV, or TXT
table containing exactly one header column named CellCategory. Values are exact,
case-sensitive labels. The module rejects duplicate, empty, and labels absent
after the optional cell filter.

    CellCategory
    CD14+ Monocytes
    CD4 T cells

    Rscript modules/OMIX-Seurat-Pseudobulk/scripts/run_seurat_pseudobulk.R \
      --seurat_rds /path/to/object.rds \
      --donor_column donor \
      --group_column sex \
      --cell_category_column seurat_clusters \
      --cell_category_mode selected \
      --cell_category_selection /path/to/cell_categories.csv \
      --aggregation_method mean_sctransform_expression \
      --min_cells 20 \
      --output_dir /path/to/results/cell-category-pseudobulk

Use all mode to enumerate every non-missing category label remaining after the
same explicit cell filter. Labels are sorted deterministically. Both collection
modes create one ordinary pseudobulk bundle beneath `cell_categories/<stable-id>/`
for every category that retains at least two groups, plus:

| File | Contents |
| --- | --- |
| Cell_Category_Profile_Catalog.csv | Original exact category label, stable directory ID, donor, group, observed cells, minimum-cell eligibility/exclusion, nested paths, aggregation settings, and source provenance. |
| Pseudobulk_Collection_Manifest.dcf | Collection-level mode and routing/provenance record. Do not pass this file to Limma; pass each nested ordinary Pseudobulk_Manifest.dcf. |
| Pseudobulk_Collection_Run_Summary.txt | Human-readable selection and aggregation record. |

The module applies min_cells independently to every cell category × donor × group
profile. With `on_insufficient_cells = error`, it stops before writing the
collection and identifies each affected profile. With `drop`, the catalog
records excluded profiles and omits a category that no longer retains two
groups. The collection fails only when no selected category remains testable.

Collection mode does not pool cells across categories, fit a joint model, or
test a category-by-group interaction. Run the compatible Limma analysis on
each nested continuous-expression bundle. A separate canonical downstream
collection step must validate a common tested-gene universe before a multi-
comparison pathway module consumes the results.

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
- One-mode invocation produces one category-specific pseudobulk dataset.
  Selected/all collection modes produce separate equivalent datasets rather
  than pooling cells or treating cells as biological replicates.
- `--metadata_columns` values must be non-missing and identical across all
  cells in each donor-by-group profile; this prevents ambiguous `Batch` or
  covariate assignments.
- The cell filter is deliberately explicit. For example, supply a singlet/QC
  metadata column only when that selection is part of the documented analysis.

## Integration

The module uses the optional [OmixSeurat bridge](../../bridges/seurat/README.md)
and the portable [omix_standard_input](../../core/README.md) contract. A
[Code Ocean deployment adapter](https://github.com/NIDAP-Community/OMIX-Seurat-Pseudobulk)
is maintained separately; its platform-validation and release status are
recorded in that repository rather than inferred from this portable module.
