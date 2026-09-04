# OMIX DEG Analysis

Run design-aware bulk RNA-seq differential-expression analysis from raw counts
and sample metadata.

**Runtime profile:** [`r-statistics`](../../README.md#run-a-module-on-biowulf-or-another-shared-r-system)
**Entry point:** `scripts/run_deg_analysis.R`

## What it does

The module applies design-aware low-expression filtering, library-size
normalization, limma-voom modelling, and optional `duplicateCorrelation`
blocking for genuine repeated-measures designs. Known technical batch terms
are included in the fitted model. It returns DEG statistics plus sample-level
expression values suitable for downstream visualization.

## When to use it

Use this module for bulk RNA-seq counts, or for donor-level pseudobulk counts
derived from single-cell data. It expects biological replicates, not individual
cells. For repeated samples from the same donor or participant, set the donor
column; do not use technical batch as a donor surrogate.

## Inputs

The standard table input consists of two CSV, TSV, TXT, or RDS files:

| Input | Requirements |
| --- | --- |
| Raw counts | Integer-like feature-by-sample count table. The default feature-ID column is `GeneName`; remaining columns are sample IDs. |
| Sample metadata | One row per sample with a unique sample-ID column. The default ID column is `Sample`; `Group` and, when applicable, `Batch` are common analysis columns. |

Metadata sample IDs must exactly match the count-table sample columns. Supply
the biological group column, contrast, optional fixed covariates, optional
technical batch column, and—only for genuine repeated measures—optional donor
column.

## Run locally or on HPC

After restoring the `r-statistics` runtime profile and setting `OMIX_ROOT` to
the OMIX checkout, run the portable CLI with explicit paths:

```bash
Rscript "$OMIX_ROOT/modules/OMIX-DEG-Analysis/scripts/run_deg_analysis.R" \
  --input_type table \
  --counts /path/to/raw_counts.csv \
  --metadata /path/to/sample_metadata.csv \
  --gene_names_column GeneName \
  --sample_names_column Sample \
  --contrast_variable_columns Group \
  --contrasts B-A \
  --batch_effect_columns Batch \
  --normalization_method TMM \
  --output_dir results/deg
```

## Outputs

| File | Contents |
| --- | --- |
| `DEG_Analysis.csv` | Differential-expression results plus the model-ready sample-level expression block. When a batch term is fitted, those expression values are batch-adjusted voom-scale log-CPM values. |
| `Sample_Metadata.csv` | Metadata for exactly the samples represented in the DEG expression block, in matching order. |
| `run_summary.txt` | Input, filtering, model, contrast, and normalization provenance. |
| `normalization_boxplots.png` | Before-and-after filtered log-CPM distribution summary. |
| `normalization_densities.png` | Before-and-after filtered log-CPM density summary. |
| `voom_mean_variance.png` | Final voom mean-variance trend used to estimate precision weights. |

Keep `DEG_Analysis.csv` and `Sample_Metadata.csv` together when passing an
analysis to a downstream module. `DEG_Analysis.csv` is the canonical
downstream DEG table.

## Method notes

### Experimental design

- Every comparison group needs at least two biological samples.
- The donor column is only for repeated measurements from the same biological
  participant. Technical replicates within a donor-by-group combination are
  rejected rather than selected silently.
- Batch adjustment is fitted with the statistical model. The appended
  expression block supports downstream visualization; it does not replace the
  model statistics.

### Normalization

| Dataset type | Recommended normalization | Rationale |
| --- | --- | --- |
| Typical bulk RNA-seq dataset | `TMM` (default) | Corrects composition bias while retaining the observed biological range. |
| High technical noise or strongly mismatched distributions | `Quantile` | Force-aligns voom-scale distributions, which can reduce severe technical variation but can attenuate subtle or global biology. |
| Sensitivity analysis after evaluating Quantile | `TMM + Quantile` | Applies library-size normalization before voom-scale quantile normalization. |

`TMM + Scale` equalizes sample medians and is appropriate only when a modest
sample-wide median shift is credibly technical. `TMM + Cyclic Loess` is a
slower pairwise alternative for nonlinear, sample-specific distribution
differences, particularly with unbalanced differential expression. `TMMwsp`,
`RLE`, and `Upper Quartile` are deliberate legacy or special-case comparisons,
not routine first choices.

Normalization does not replace modelling known technical batch variables. The
diagnostic plots above are written by default; disable them with
`--write_normalization_diagnostics false`.

## Optional object integrations

### MOSuite MOO

Set `--input_type moo` and supply `--moo /path/to/moo.rds` to use the optional
[OmixMOSuite bridge](../../bridges/mosuite/README.md). The bridge extracts the
MOO raw-count layer and embedded sample metadata, validates their alignment,
and passes the same portable table contract to this module. Do not use a
prefiltered MOO layer as the count-model input; the module performs its own
design-aware filtering.

### Seurat pseudobulk

Use the optional [OmixSeurat bridge](../../bridges/seurat/README.md) to select
a cell type and sum raw `RNA` `counts` by donor and condition. It returns the
same count-table-plus-metadata contract used above and depends on
`SeuratObject`, not the full Seurat package.

### Reproducible paired-pseudobulk fixture

For a local integration test, generate the Kang et al. IFN-beta PBMC CD14+
monocyte fixture. It creates 16 donor-by-condition profiles for eight donors
under ignored `data/debug/`:

```bash
Rscript modules/OMIX-DEG-Analysis/scripts/create_kang_pseudobulk_fixture.R
```

Run the resulting table with `--contrast_variable_columns Group`,
`--contrasts stim-ctrl`, and `--donor_variable_column Donor`.

## Interface and deployment

See [`schemas/interface.yml`](schemas/interface.yml) for the complete
machine-readable input, parameter, and output contract.

**Deployment repository:**
[OMIX-DEG-Analysis](https://github.com/NIDAP-Community/OMIX-DEG-Analysis)

## References

1. Robinson MD, Oshlack A. A scaling normalization method for differential
   expression analysis of RNA-seq data. *Genome Biology*. 2010;11:R25.
   [doi:10.1186/gb-2010-11-3-r25](https://doi.org/10.1186/gb-2010-11-3-r25)
2. [limma documentation: `voom` and `normalizeBetweenArrays`](https://bioconductor.org/packages/devel/bioc/manuals/limma/man/limma.pdf)
