# OMIX PCA 3D

Render an interactive three-dimensional principal-component analysis (PCA)
plot from an explicit feature-by-sample matrix and aligned sample metadata.

## What it does

OMIX PCA 3D follows the established CCBR 3D PCA method: it optionally applies
edgeR counts per million (CPM) to raw counts, removes features with an exactly
zero mean and then zero variance, scales each remaining feature, and runs
`prcomp()`. The resulting interactive Plotly plot colors samples by a metadata
group and displays a chosen sample-label column on hover.

Use it for exploratory visualization of raw bulk counts (with `--use_cpm
true`) or for an already normalized continuous feature-by-sample matrix (with
the default `--use_cpm false`). It does not read Seurat objects directly;
export a matrix and aligned metadata upstream, for example with
[OMIX Seurat Pseudobulk](../OMIX-Seurat-Pseudobulk/README.md).

## Quick start

The module uses the `r-visualization` profile plus its pinned edgeR 4.4.2
overlay. From an OMIX checkout with a compatible prepared runtime, run:

```bash
Rscript modules/OMIX-PCA-3D/scripts/run_pca_3d.R \
  --feature_matrix=/path/to/feature_matrix.csv \
  --sample_metadata=/path/to/sample_metadata.csv \
  --feature_id_column=Gene \
  --sample_id_column=Sample \
  --sample_label_column=Sample \
  --group_column=Group \
  --output_dir=/path/to/results/pca_3d
```

The [runtime guide](../../docs/runtime-guide.md) explains how to create the
module-specific effective `renv.lock` before a reproducible local, container,
or HPC run.

## Validation

The committed small fixture has exact expected PCA coordinates and variance;
it runs with the module preparation tests. The generic PR-validation contract
and local container command are documented in
[Canonical-module validation](../../docs/canonical-module-validation.md).

For a stronger local known-result check, use
`tests/test-pca-historical-parity.R` with explicit paths to a non-committed
feature matrix, matching metadata, and historical Plotly RDS object. It checks
sample/group identities, all three coordinates, and point sizes within an
explicit tolerance. Do not commit private inputs or its derived outputs; record
the input provenance, runtime digest, command, and numerical result in the
session notes instead.

## Inputs

| Input | Requirements |
| --- | --- |
| Feature matrix | CSV or tab-delimited feature-by-sample table. The selected sample columns must be numeric and have no missing values. The feature-ID column defaults to `Gene`, `GeneName`, or the first column. |
| Sample metadata | CSV or tab-delimited table with one row per selected sample. `--sample_id_column` must match the matrix sample names, and label/group columns must be present and non-missing. |

Use `--samples_to_include=sample_1,sample_2` to choose and order samples, or
leave it blank to use matching metadata IDs in metadata-row order. Remove a
selected sample before analysis with `--outlier_sample_ids`. PCA requires at
least three selected samples and at least three remaining variable features.

For raw counts, set `--use_cpm true`; the module rejects negative values in
that mode. For normalized, transformed, batch-corrected, pseudobulk, or
mean-expression inputs, leave CPM disabled.

## Appearance controls

`--point_colors` accepts one or more comma-separated names from `indigo`,
`carrot`, `lipstick`, `turquoise`, `lavender`, `jade`, `coral`, `azure`,
`green`, `rum`, `orange`, and `olive`. If the grouping column has more levels
than selected named colors, the template's fixed-seed color generator supplies
the rest deterministically.

`--manual_label_renames` accepts comma-separated `old_label:new_label` pairs.
It changes hover labels only; matrix sample IDs and output-coordinate ordering
remain unchanged. `--point_size` and `--plot_title` control the interactive
display. The released template's label-font setting is a fixed value of 24.

## Outputs

| File | Use |
| --- | --- |
| `pca_3d.html` | Interactive Plotly three-dimensional scatter plot. |
| `pca_3d_files/` | Companion assets for `pca_3d.html`; retain it with the HTML file unless `--self_contained_html true` was used in an environment with Pandoc. |
| `pca_3d_components.csv` | Eigenvalues plus explained and cumulative variance for every principal component. |
| `pca_3d_coordinates.csv` | PCA coordinates with the selected group and display label for each sample. |
| `pca_3d_run_summary.txt` | Input paths, resolved sample selection, PCA controls, colors, and feature count after template filters. |

## Method notes and current status

The zero-mean filter intentionally preserves the imported template behavior.
For centered continuous matrices, choose an input representation whose
feature means are not intentionally zeroed before running this module, or
review whether this template-derived method is appropriate for that analysis.

The default `--self_contained_html false` is a runtime compatibility setting:
it writes the standard Plotly HTML plus `pca_3d_files/`, which works in the
published `r-visualization` v3 image without Pandoc. Set it to `true` only in
an environment that has Pandoc and when a single self-contained HTML file is
required.

This canonical module is in `review`. Its platform-neutral interface and
fixture pass direct checks in the published `r-visualization` v3 image; the
remaining gate is independent review. No deployment adapter is registered.

## Interface and provenance

The complete public contract is in [schemas/interface.yml](schemas/interface.yml).
The implementation preserves the CCBR 3D PCA template's scientific sequence
while replacing Code Ocean-specific output handling with explicit paths. The
imported template revision and checksum are recorded in the changelog rather
than embedded in the portable interface.
