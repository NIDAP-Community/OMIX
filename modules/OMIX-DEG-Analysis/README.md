# OMIX DEG Analysis

Run design-aware differential-expression analysis from raw counts, declared
Harmony-corrected donor-level means, or SCTransform donor-level means and
sample metadata.

## What it does

The module has three intentionally separate analysis modes. All return the
same downstream-compatible DEG table, but they do not transform the same kind
of input in the same way.

| Mode | Input | Model | Batch handling |
| --- | --- | --- | --- |
| `raw_counts` | Raw integer-like bulk or summed pseudobulk counts | Design-aware filtering, edgeR library-size normalization, limma-voom | Include known technical batch terms in the model. |
| `harmony_mean_expression` | A documented, log2-scale, Harmony-corrected gene-expression matrix averaged per cell type × donor | Direct limma, with optional donor blocking | Do not add `Batch`, TMM, voom, or another normalization. Harmony is the declared upstream correction. |
| `sct_mean_expression` | Log2-scale cell-type × donor means written from Seurat `SCT/data` by OMIX Seurat Pseudobulk | Direct limma, with optional donor blocking | SCTransform addresses sequencing depth, not necessarily technical batch. Model any remaining batch through `covariate_columns`; do not use count normalization or downstream batch-effect removal. |

## When to use it

Use `raw_counts` for bulk RNA-seq counts or summed donor-level pseudobulk
counts. Use `harmony_mean_expression` only for the established workflow in
which a gene-level Harmony-corrected expression matrix is already available,
then averaged within each selected cell type and donor. It expects biological
replicates, not individual cells. Use `sct_mean_expression` only with the
log2 donor means emitted by OMIX Seurat Pseudobulk from `SCT/data`, not with
raw `SCT/counts` or variable-gene-only `SCT/scale.data`. For repeated
samples from the same donor or participant, set the donor column; do not use
technical batch as a donor surrogate.

## Quick start

**Runtime profile:** [`r-statistics`](../../README.md#run-a-module-on-biowulf-or-another-shared-r-system)

**Command:** `scripts/run_deg_analysis.R`

After checking the count and metadata requirements below, use the copyable
explicit-path command in [Run locally or on HPC](#run-locally-or-on-hpc).

## Inputs

The standard table input consists of two CSV, TSV, TXT, or RDS files:

| Input | Requirements |
| --- | --- |
| Matrix | In `raw_counts`, an integer-like feature-by-sample count table. In `harmony_mean_expression`, a finite, log2-scale Harmony-corrected mean-expression matrix. In `sct_mean_expression`, the `SCT_Mean_Log2_Expression.csv` file emitted by OMIX Seurat Pseudobulk. The default feature-ID column is `GeneName`; remaining columns are sample IDs. |
| Sample metadata | One row per sample with a unique sample-ID column. The default ID column is `Sample`; `Group` and, when applicable, `Batch` are common analysis columns. |

Metadata sample IDs must exactly match the matrix sample columns. Supply
the biological group column, contrast, optional fixed covariates, optional
technical batch column, and—only for genuine repeated measures—optional donor
column.

## Run locally or on HPC

Set `OMIX_ROOT` to the OMIX checkout, then prepare a writable runtime project
with the shared helper:

```bash
export OMIX_RUN=/path/to/omix-deg-runtime
Rscript "$OMIX_ROOT/scripts/restore-omix-runtime.R" \
  --module OMIX-DEG-Analysis \
  --project "$OMIX_RUN"
cd "$OMIX_RUN"
```

Run the portable CLI with explicit paths:

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

For an upstream Harmony-mean bundle, pass its three files explicitly. The
manifest is optional for ordinary user tables but is recommended because it
prevents a matrix-type mismatch:

```bash
Rscript "$OMIX_ROOT/modules/OMIX-DEG-Analysis/scripts/run_deg_analysis.R" \
  --input_type table \
  --analysis_mode harmony_mean_expression \
  --counts /path/to/Harmony_Mean_Expression.csv \
  --metadata /path/to/Pseudobulk_Sample_Metadata.csv \
  --pseudobulk_manifest /path/to/Pseudobulk_Manifest.dcf \
  --gene_names_column GeneName \
  --sample_names_column Sample \
  --contrast_variable_columns Group \
  --contrasts B-A \
  --donor_variable_column Donor \
  --output_dir results/deg
```

For an SCTransform donor-mean bundle, pass the matrix and matching manifest
written by OMIX Seurat Pseudobulk. Add an unhandled technical batch as a
covariate only when it is not confounded with Group:

```bash
Rscript "$OMIX_ROOT/modules/OMIX-DEG-Analysis/scripts/run_deg_analysis.R" \
  --input_type table \
  --analysis_mode sct_mean_expression \
  --counts /path/to/SCT_Mean_Log2_Expression.csv \
  --metadata /path/to/Pseudobulk_Sample_Metadata.csv \
  --pseudobulk_manifest /path/to/Pseudobulk_Manifest.dcf \
  --gene_names_column GeneName \
  --sample_names_column Sample \
  --contrast_variable_columns Group \
  --contrasts B-A \
  --donor_variable_column Donor \
  --covariate_columns Batch \
  --output_dir results/deg
```

## Outputs

| File | Contents |
| --- | --- |
| `DEG_Analysis.csv` | Differential-expression results whose first column is always `GeneName`, plus sample-level expression. Raw-count mode writes normalized/batch-adjusted voom log-CPM where requested; continuous-expression modes return their supplied donor means unchanged. |
| `Sample_Metadata.csv` | Metadata for exactly the samples represented in the DEG expression block, in matching order. |
| `run_summary.txt` | Input, filtering, model, contrast, and normalization provenance. |
| `normalization_boxplots.png` | Raw-count mode only: before-and-after filtered log-CPM distribution summary. |
| `normalization_densities.png` | Raw-count mode only: before-and-after filtered log-CPM density summary. |
| `voom_mean_variance.png` | Raw-count mode only: final voom mean-variance trend used to estimate precision weights. |

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

### Harmony-corrected mean expression

- A standard Harmony reduction/embedding is **not** a gene-expression matrix.
  This mode requires a documented gene-by-cell corrected expression layer.
- Average that layer separately for each selected cell type and donor before
  fitting limma. It is a cell-intrinsic state summary, not a cell-abundance
  analysis.
- This mode rejects a `Batch` term and raw-count options so that upstream
  correction is not applied twice. It can still use `duplicateCorrelation` to
  account for repeated measurements from the same donor.
- The output `*_logFC` is the limma coefficient on the declared corrected
  expression scale. Interpret `*_FC` as a fold change only when that input is
  log2-scale.

### SCTransform mean expression

- Use OMIX Seurat Pseudobulk with `mean_sctransform_expression`. It reads
  Seurat's `SCT/data` layer, averages the selected cell type separately per
  donor and group, then converts those log1p donor means to log2 scale.
- This mode is direct limma: it rejects TMM, voom, edgeR filtering, and
  downstream batch-effect removal. Do not use raw `SCT/counts` here; they
  are depth-corrected values, not observed raw counts.
- SCTransform corrects sequencing depth. If an unhandled technical batch
  remains and is not confounded with Group, model it through
  `--covariate_columns Batch`. If it was already explicitly regressed
  upstream, leave it out rather than correcting it twice.

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

### Seurat donor-level aggregation

Use [OMIX Seurat Pseudobulk](../OMIX-Seurat-Pseudobulk/README.md) to select a
cell type and write summed raw `RNA` counts, Harmony-corrected donor means,
or log2 SCTransform donor means. It also writes `Pseudobulk_Manifest.dcf`,
which identifies the only valid DEG `analysis_mode`. The bridge depends on
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
