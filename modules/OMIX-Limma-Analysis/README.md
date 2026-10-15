# OMIX Limma Analysis

Compare biological groups in an already normalized continuous
feature-by-sample matrix using limma linear models and empirical-Bayes variance
moderation.

## What it does

OMIX Limma Analysis aligns a continuous measurement matrix with sample
metadata, summarizes duplicate feature identifiers, constructs the requested
design and contrasts, optionally accounts for repeated donors, and reports
moderated statistics for every feature. Features may be genes, pathways, cell
types, proteins, metabolites, genomic regions, or another declared continuous
measurement.

The module does not normalize raw sequencing counts. Use a count-aware
workflow such as OMIX DEG Analysis when the input consists of raw RNA-seq or
ATAC-seq counts.

## When to use it

Suitable inputs include:

- normalized log2 microarray or bulk-expression measurements;
- donor-level means from declared SCT or Harmony-corrected expression;
- GSVA, ssGSEA, or other pathway-activity scores;
- transformed CIBERSORT relative fractions or CIBERSORT absolute scores;
- DNA-methylation M-values;
- normalized log-scale proteomic, phosphoproteomic, metabolomic, or cytokine
  measurements;
- delta-Ct qPCR measurements;
- log2 copy-number ratios;
- normalized continuous chromatin-accessibility or CRISPR-screen scores; and
- another well-defined continuous measurement with biological replication.

Do not use this module for raw counts, binary outcomes, survival outcomes,
ranked-gene lists, or individual cells treated as biological replicates.

## Quick start

**Runtime profile:** [`r-statistics`](../../README.md#run-a-module)

Set `OMIX_ROOT` to the OMIX checkout and prepare a writable runtime project:

```bash
export OMIX_RUN=/path/to/omix-limma-runtime
Rscript "$OMIX_ROOT/scripts/restore-omix-runtime.R" \
  --module OMIX-Limma-Analysis \
  --project "$OMIX_RUN"
cd "$OMIX_RUN"
```

Run a two-group analysis of normalized bulk expression:

```bash
Rscript "$OMIX_ROOT/modules/OMIX-Limma-Analysis/scripts/run_limma_analysis.R" \
  --matrix /path/to/normalized_expression.csv \
  --metadata /path/to/sample_metadata.csv \
  --gene_names_column GeneName \
  --sample_names_column Sample \
  --contrast_variable_columns Group \
  --contrasts B-A \
  --input_data_type normalized_bulk_expression \
  --variance_model auto \
  --output_dir results/limma
```

When an OMIX pseudobulk manifest accompanies the matrix, the input type and
recommended variance model can be resolved automatically:

```bash
Rscript "$OMIX_ROOT/modules/OMIX-Limma-Analysis/scripts/run_limma_analysis.R" \
  --matrix /path/to/SCT_Mean_Log2_Expression.csv \
  --metadata /path/to/Pseudobulk_Sample_Metadata.csv \
  --pseudobulk_manifest /path/to/Pseudobulk_Manifest.dcf \
  --contrast_variable_columns Group \
  --contrasts B-A \
  --donor_variable_column Donor \
  --input_data_type auto \
  --variance_model auto \
  --output_dir results/sct-limma
```

You may omit `--contrasts` only when the selected contrast variable produces
exactly two groups with at least two samples in each group. In that
unambiguous case, OMIX records the inferred comparison. Supply an explicit
contrast for every other design.

## Inputs

| Input | Requirements |
| --- | --- |
| Matrix | CSV, TSV, TXT, or RDS feature-by-sample numeric matrix. The default feature-ID column is `GeneName`. |
| Metadata | CSV, TSV, TXT, or RDS table with a unique `Sample` column matching matrix sample columns. |
| Contrast columns | One or two metadata variables defining the groups to compare. |
| Covariates | Optional fixed-effect columns, such as age, sex, or an unhandled technical variable. |
| Donor | Optional repeated-measure blocking column. Use it only when a donor contributes more than one modeled profile. |
| Manifest | Optional upstream declaration of matrix type, intended downstream analysis, and recommended variance model. |

Group labels may be ordinary text or numeric labels such as `0` and `1`.
Numeric labels are translated to safe internal design names, while result
columns preserve the requested contrast label such as `1-0`.

## Input data types and automatic variance models

`--input_data_type` tells the program what the matrix represents. This cannot
be inferred reliably from decimal values alone: SCT expression, Harmony
expression, GSVA scores, and normalized assay intensities can have overlapping
numeric ranges.

With `--variance_model auto`, OMIX uses the following defaults:

| `input_data_type` | Expected matrix | Automatic variance model |
| --- | --- | --- |
| `microarray_log2_expression` | Normalized log2 microarray intensities | `ebayes` |
| `normalized_bulk_expression` | VST, rlog, quantile-normalized, or otherwise variance-stabilized expression | `ebayes` |
| `log2_cpm_without_voom_weights` | Log2-CPM when raw counts and voom weights are unavailable | `ebayes_trend` |
| `sctransform_mean_expression` | Sample-level mean SCT expression | `ebayes_trend` |
| `harmony_corrected_mean_expression` | Sample-level mean Harmony-corrected expression | `ebayes` |
| `gsva_enrichment_scores` | Pathway-by-sample GSVA or related scores | `ebayes` |
| `cibersort_relative_fractions` | Cell-type fractions bounded by zero and one | `ebayes` after the selected fraction transformation |
| `cibersort_absolute_scores` | Non-compositional CIBERSORT absolute-mode scores | `ebayes` |
| `methylation_m_values` | DNA-methylation M-values | `ebayes` |
| `normalized_proteomics` | Normalized log-scale protein or phosphoprotein intensity | `ebayes` |
| `normalized_metabolomics` | Normalized, typically log-scale metabolite or lipid abundance | `ebayes` |
| `qpcr_delta_ct` | Delta-Ct measurements | `ebayes` |
| `copy_number_log2_ratios` | Feature-level log2 copy-number ratios | `ebayes` |
| `normalized_chromatin_accessibility` | Continuous normalized peak or region signal without voom weights | `ebayes_trend` |
| `normalized_crispr_scores` | Normalized gene-level screen scores | `ebayes` |
| `other_continuous` | Another declared continuous measurement | No automatic choice; select `ebayes` or `ebayes_trend` explicitly |

`auto` uses the upstream manifest when one is supplied. For compatibility with
older calls that predate `input_data_type`, an explicit `input_kind` of
`log2_expression` maps to `normalized_bulk_expression`, and
`enrichment_score` maps to `gsva_enrichment_scores`. New analyses should
declare the data type directly or supply a manifest.

### Choosing the variance model

- `ebayes` shrinks feature-wise residual variances toward one common prior
  variance. Use it when residual variability is approximately independent of
  average signal.
- `ebayes_trend` allows the prior variance to change smoothly with average
  signal. Use it when the residual standard deviation has a clear relationship
  with average feature signal.
- `auto` applies the documented default for a recognized input type. It never
  chooses a model according to which one produces smaller p-values.

Every run writes `Variance_Diagnostic.csv` and `variance_diagnostic.png`.
An approximately horizontal relationship supports ordinary `ebayes`; a clear
smooth increase or decrease supports considering `ebayes_trend`. The selected
model affects moderated standard errors, test statistics, and p-values, but it
does not change fitted group means or contrast coefficients.

`other_continuous` is the extension point for measurements not listed above.
It requires both a short `--measurement_scale` description and an explicit
variance model:

```bash
--input_data_type other_continuous \
--measurement_scale "log2 normalized cytokine concentration" \
--variance_model ebayes
```

## CIBERSORT inputs

Relative fractions and absolute-mode scores are distinct inputs.

For relative fractions, `--fraction_transform auto` uses `arcsin_sqrt`. This
transformation is defined at exact zero and one and does not invent an
effective cell-count denominator that a fraction-only CIBERSORT table does not
contain. The module verifies that values lie between zero and one and warns if
a sample does not sum to approximately one.

Available controls are:

- `auto`: use `arcsin_sqrt` for relative fractions and `none` otherwise;
- `arcsin_sqrt`: apply `asin(sqrt(fraction))`;
- `logit`: apply a logit after replacing exact boundary values with
  `--fraction_pseudocount` and `1 - fraction_pseudocount`; and
- `none`: expert override that retains raw fractions and emits a warning.

CIBERSORT absolute scores do not sum to one and must use
`cibersort_absolute_scores`; the relative-fraction transformation is not
applied. Ordinary limma does not propagate uncertainty from the upstream
deconvolution step, so interpret results as differences in estimated cell
composition rather than differential gene expression.

## Effects and measurement scales

`input_kind` controls result labels and normally resolves automatically:

- expression-like inputs report signed `FC` and `logFC` columns;
- GSVA inputs report an `effect` in enrichment-score units; and
- fractions, absolute scores, methylation, proteomics, metabolomics, qPCR,
  copy-number, accessibility, CRISPR, and other continuous inputs report an
  `effect` in the supplied or transformed measurement units.

For delta-Ct data, remember that a larger delta-Ct ordinarily represents lower
expression. Interpret the sign according to the supplied scale.

## Outputs

| File | Contents |
| --- | --- |
| `Limma_Analysis.csv` | Group summaries, contrast effects, moderated statistics, and optionally the modeled matrix. |
| `Sample_Metadata.csv` | Metadata aligned to the modeled sample columns. |
| `run_summary.txt` | Requested and resolved input type, scale, transformation, variance model, design, contrasts, and donor-correlation provenance. |
| `Variance_Diagnostic.csv` | Per-feature average signal and residual standard deviation before empirical-Bayes moderation. |
| `variance_diagnostic.png` | Residual standard deviation versus average signal with a lowess trend when sufficient features are present. |

## Method notes

The module fits `lmFit()`, applies the requested contrasts, and then runs
`eBayes()` with or without its intensity trend. It does not perform count
filtering, library-size normalization, TMM, or voom.

For Harmony-corrected expression, confirm that the upstream correction did not
remove or confound the biological effect of interest. For aggregated SCT or
Harmony data, the variance model does not correct unequal numbers of cells per
sample; aggregation precision and cell-number effects remain separate design
considerations.

## References

- [limma package and user guide](https://bioconductor.org/packages/release/bioc/html/limma.html)
- [GSVA package vignette](https://bioconductor.org/packages/release/bioc/vignettes/GSVA/inst/doc/GSVA.html)
- [speckle proportion-analysis manual](https://bioconductor.org/packages/release/bioc/manuals/speckle/man/speckle.pdf)
- [Propeller method for differential cell-type proportions](https://doi.org/10.1093/bioinformatics/btac582)

## Interface and deployment

See [`schemas/interface.yml`](schemas/interface.yml) for the complete public
contract. The optional
[OMIX Limma Analysis deployment adapter](https://github.com/NIDAP-Community/OMIX-Limma-Analysis)
provides platform input discovery, user-interface controls, result routing,
and runtime selection without changing the canonical scientific
implementation.
