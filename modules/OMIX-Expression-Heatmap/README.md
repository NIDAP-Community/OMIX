# OMIX Expression Heatmap

Render an annotated heatmap from a normalized continuous feature-by-sample
expression matrix and matching sample metadata.

## What it does

OMIX Expression Heatmap selects variable or specified features, optionally
row-standardizes their values, and renders a clustered `ComplexHeatmap` with
sample annotations. It also writes the exact matrix displayed in the heatmap.

Use it for normalized bulk expression, batch-corrected expression, or
single-cell-derived pseudobulk/mean-expression profiles. The input contract is
the same in each case: rows are features and columns are samples. Prepare a
Seurat object upstream with [OMIX Seurat Pseudobulk](../OMIX-Seurat-Pseudobulk/README.md);
this module does not read Seurat objects directly.

Do not use raw counts. Supply continuous values that are already appropriate
for visualization.

## Quick start

The module requires `ComplexHeatmap` 2.22.0 in the `r-visualization` runtime.
The `r4.4.3-v3` runtime definition supplies that pin, but remains a candidate
until targeted validation and a separate publication decision complete. From
an OMIX checkout with a compatible local runtime, run:

```bash
Rscript modules/OMIX-Expression-Heatmap/scripts/run_expression_heatmap.R \
  --expression_matrix=/path/to/expression_matrix.csv \
  --sample_metadata=/path/to/sample_metadata.csv \
  --gene_column=Gene \
  --sample_name_column=Sample \
  --group_columns=Group,Batch \
  --output_dir=/path/to/results/expression_heatmap
```

When `--samples_to_include` is blank, the module uses matching sample IDs in
metadata row order. `--gene_column auto` accepts `Gene`, `GeneName`, or the
first column.

## Inputs

| Input | Requirements |
| --- | --- |
| Expression matrix | CSV or tab-delimited table with a feature-ID column and numeric sample columns. Duplicate feature IDs are averaged, consistent with continuous normalized values. |
| Sample metadata | CSV or tab-delimited table with one row per sample and a sample-ID column matching the selected expression columns. |

Optional `--group_columns` create top annotations. Feature selection defaults
to the 500 highest-variance features. Set `--include_all_genes true` and
`--filter_top_genes_by_variance false` to display the complete matrix.

## Outputs

| File | Use |
| --- | --- |
| `expression_heatmap.png` | Annotated clustered heatmap. |
| `expression_heatmap_matrix.csv` | Exact displayed matrix after duplicate-feature averaging, selection, and optional row standardization. |
| `expression_heatmap_run_summary.txt` | Inputs, selected samples, annotations, and plotted feature count. |

## Method notes

- The default palette is `Bu Yl Rd`; color limits are data-driven unless
  `--autoscale_heatmap_color false` is selected.
- Row standardization is enabled by default, making each displayed feature
  easier to compare across samples. Disable it to show the original continuous
  scale.
- The current canonical module is in development pending validation of its
  pinned shared runtime. The interface and a small reproducible fixture are
  included so that runtime validation is explicit rather than implicit.

## Interface and deployment

The complete portable interface is defined in
[schemas/interface.yml](schemas/interface.yml). Deployment adapters will be
listed in [module.yml](module.yml) when they are available; none is registered
for this development module.
