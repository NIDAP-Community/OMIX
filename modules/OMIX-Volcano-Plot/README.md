# OMIX Volcano Plot

Create publication-ready volcano plots from differential-expression results.

**Runtime profile:** [`r-visualization`](../../README.md#run-a-module-on-biowulf-or-another-shared-r-system)
**Entry point:** `scripts/run_volcano_plot.R`

## What it does

The module displays each feature by effect size and statistical significance,
and writes the values used to construct the plot. It supports a conventional
single-comparison DEG table as well as wide tables containing multiple
comparison-specific columns.

## When to use it

Use a volcano plot after a fitted differential-expression analysis to inspect
the direction, magnitude, and significance of individual features. It is a
visual summary of the DEG model; it does not refit statistics from expression
values.

## Inputs

Provide one CSV, TSV, TXT, or RDS DEG table with:

- a feature identifier column;
- a significance column (`pval` or adjusted p-value); and
- a log2 fold-change column.

Feature detection prefers `GeneName`, then `Gene Symbols`, followed by common
generic identifier names. For a wide result table, use comparison-prefixed
columns such as `Treatment-Control_pval` and `Treatment-Control_logFC`, or
provide matching comma-separated column lists explicitly.

## Run locally or on HPC

After restoring the `r-visualization` runtime profile and setting `OMIX_ROOT`
to the OMIX checkout, run:

```bash
Rscript "$OMIX_ROOT/modules/OMIX-Volcano-Plot/scripts/run_volcano_plot.R" \
  --deg_table /path/to/DEG_Analysis.csv \
  --pvalue_type nominal \
  --p_value_threshold 0.05 \
  --log2_fold_change_threshold 1 \
  --output_dir results/volcano
```

## Outputs

| File | Contents |
| --- | --- |
| `volcano_plot.png` | Volcano plot; a suffix is added when more than one comparison is plotted. |
| `volcano_plot_data.csv` | Input table augmented with signed negative-log10 significance ranks used by the plot. |

## Method notes

- The default `--pvalue_type nominal` displays raw p-values. Set it to
  `adjusted` when the scientific question calls for multiple-testing-adjusted
  values.
- The default significance threshold is 0.05 and the default absolute log2
  fold-change threshold is 1.0.
- A volcano plot should be interpreted with the study design and the upstream
  statistical model in mind, including batch terms or repeated-measures
  blocking when present.

## Interface and deployment

See [`schemas/interface.yml`](schemas/interface.yml) for the complete
machine-readable input, parameter, and output contract.

**Deployment repository:**
[OMIX-Volcano-Plot](https://github.com/NIDAP-Community/OMIX-Volcano-Plot)
