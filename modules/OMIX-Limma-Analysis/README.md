# OMIX Limma Analysis

Fit limma linear or donor-blocked mixed-effect models to a declared continuous
feature-by-sample matrix.

## What it does

This module is the portable, command-line form of the established
[`Limma_Analysis_v41.R`](../../../../Templates/Limma_Analysis_v41.R) template.
It preserves the template's feature summarization, design and contrast
construction, covariate handling, optional `duplicateCorrelation()` donor
blocking, direct `lmFit()` model, and empirical-Bayes result calculations.

It replaces notebook-only plots and printed tables with explicit output files
and a run summary. The module function's default variance model, `ebayes`, is
intentionally template-equivalent. The command-line interface defaults to
`auto`: it uses the recommendation in a compatible pseudobulk manifest, or
falls back to `ebayes` when no manifest is supplied. `ebayes_trend` remains an
explicit option when a documented mean-dependent variance trend is appropriate
for the supplied continuous matrix.

## When to use it

Use this module for a matrix whose values are already continuous and on a
declared analysis scale, for example:

- donor-level means of corrected `SCT/data` expression;
- donor-level means of a declared gene-expression matrix such as
  `Harmony/data`;
- GSVA or ssGSEA enrichment scores; or
- another numeric feature score with aligned biological replicates.

Do not use it for raw RNA UMI counts. Raw count pseudobulk belongs in
`OMIX-DEG-Analysis`, which applies edgeR/TMM/voom before limma. Do not supply
untransformed relative cell fractions: proportions require a documented logit
or compositional transformation before a limma analysis.

For SCWorkflow-derived inputs, `SCT/data` and `Harmony/data` are expression
sources. `SCT/scale.data` is a Pearson-residual matrix and the `harmony`
reduction is a cell embedding; neither is a general gene-expression input.
`Harmony/data` is restricted to the selected variable features and explicitly
added genes, so record that feature universe with the analysis.

## Quick start

**Runtime profile:** [`r-statistics`](../../README.md#run-a-module-on-biowulf-or-another-shared-r-system)

Set `OMIX_ROOT` to the OMIX checkout and prepare a writable runtime project:

```bash
export OMIX_RUN=/path/to/omix-limma-runtime
Rscript "$OMIX_ROOT/scripts/restore-omix-runtime.R" \
  --module OMIX-Limma-Analysis \
  --project "$OMIX_RUN"
cd "$OMIX_RUN"
```

Run a two-group log2-expression analysis:

```bash
Rscript "$OMIX_ROOT/modules/OMIX-Limma-Analysis/scripts/run_limma_analysis.R" \
  --matrix /path/to/SCT_Mean_Log2_Expression.csv \
  --metadata /path/to/Pseudobulk_Sample_Metadata.csv \
  --gene_names_column GeneName \
  --sample_names_column Sample \
  --contrast_variable_columns Group \
  --contrasts B-A \
  --input_kind log2_expression \
  --pseudobulk_manifest /path/to/Pseudobulk_Manifest.dcf \
  --output_dir results/limma
```

Add `--donor_variable_column Donor` only if a donor contributes repeated
profiles to the fitted design, such as paired time points or conditions. Do
not add Donor both as a blocking variable and a fixed covariate.

## Inputs

| Input | Requirements |
| --- | --- |
| Matrix | CSV, TSV, TXT, or RDS feature-by-sample continuous matrix. The default feature-ID column is `GeneName`. |
| Metadata | CSV, TSV, TXT, or RDS table with a unique `Sample` column matching matrix column names. |
| Contrast columns | One or two metadata variables defining the groups to test. |
| Covariates | Optional fixed-effect columns, such as an unhandled technical variable. |
| Donor | Optional repeated-measure blocking column; only valid when at least one donor has multiple modeled profiles. |

When the matrix originates from OMIX Seurat Pseudobulk, supply its
`Pseudobulk_Manifest.dcf`. The CLI accepts only the declared continuous
Harmony or SCT paths, rejects a raw-count bundle with a redirect to DEG
Analysis, and uses `ebayes` for Harmony means or `ebayes_trend` for SCT means
when `--variance_model auto` is left unchanged. You may explicitly override
that recommendation, but the run summary records both values.

`input_kind` controls effect-size labels:

- `log2_expression` preserves the template's signed `FC` and `logFC` columns;
- `enrichment_score` and `continuous_score` write a contrast `effect` in the
  original score units.

## Outputs

| File | Contents |
| --- | --- |
| `Limma_Analysis.csv` | Differential-analysis results, optionally followed by the modeled sample matrix. |
| `Sample_Metadata.csv` | Metadata aligned to modeled sample columns. |
| `run_summary.txt` | Input paths, scale declaration, variance model, fitted design, and donor-correlation provenance. |

## Method notes

The default is the original direct limma workflow: `lmFit()` followed by
`contrasts.fit()` and `eBayes()`. It does not perform count filtering,
library-size normalization, TMM, or voom.

Use `ebayes_trend` only when the input contract and diagnostics support
mean-dependent variance modeling. For SCT donor means the compatible
pseudobulk manifest recommends it; the feature remains under
representative-data validation.
For Harmony-adjusted means, do not apply a second batch correction, and ensure
the upstream Harmony correction did not remove or confound the biological
effect of interest.

## Interface and deployment

See [`schemas/interface.yml`](schemas/interface.yml) for the complete public
contract. This module has no deployment adapter yet.
