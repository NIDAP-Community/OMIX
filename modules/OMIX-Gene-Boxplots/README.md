# OMIX Gene Boxplots

Create one publication-ready, sample-level expression boxplot per selected
gene, with model-consistent DEG annotations when available.

**Runtime profile:** [`r-visualization`](../../README.md#run-a-module-on-biowulf-or-another-shared-r-system)
**Entry point:** `scripts/run_gene_boxplots.R`

## What it does

The module plots selected genes from a sample-level expression table alongside
their individual observations. It can annotate each group comparison with the
p-values already calculated by an upstream DEG model, or it can run a clearly
labelled exploratory within-plot test.

Each requested comparison is drawn as a horizontal bar spanning its two
corresponding groups and labelled with the selected nominal or adjusted
p-value.

## When to use it

Use this module after an expression or differential-expression workflow when
you want to show the sample-level values behind selected genes. It accepts
voom-scale, normalized-CPM, or batch-corrected expression values; do not
supply raw counts unless a raw-count display is specifically intended.

Use `precomputed_deg` when a result such as `DEG_Analysis.csv` is available.
It retains the original design, batch terms, donor blocking, and contrast. Use
`within_plot` only for a simple exploratory comparison of the displayed
values; it is not a replacement for the original DEG model.

## Inputs

| Input | Requirements |
| --- | --- |
| Expression table | CSV, TSV, TXT, or RDS gene-by-sample expression table. The default gene-ID column is `GeneName`. |
| Metadata table | CSV, TSV, TXT, or RDS table. The default sample-ID column is `Sample`; group labels are read from `Group`. |
| DEG table | Required with `--statistics_mode precomputed_deg`. It may be the same file as the expression table when that export contains both expression and DEG statistics. |

Sample IDs in the metadata must exactly match the expression-table sample
column names. For precomputed annotations, the DEG table must contain
comparison columns such as `B-A_pval` and/or `B-A_adjpval`.

## Run locally or on HPC

After restoring the `r-visualization` runtime profile and setting `OMIX_ROOT`
to the OMIX checkout, use model-consistent DEG annotations as follows:

```bash
Rscript "$OMIX_ROOT/modules/OMIX-Gene-Boxplots/scripts/run_gene_boxplots.R" \
  --expression_table /path/to/DEG_Analysis.csv \
  --metadata_table /path/to/Sample_Metadata.csv \
  --deg_table /path/to/DEG_Analysis.csv \
  --genes Nfil3,Tox,Zbtb16,Id2,Tcf7,Gata3,Bcl11b \
  --statistics_mode precomputed_deg \
  --pvalue_type nominal \
  --output_dir results/gene-boxplots
```

For a simple exploratory test rather than a precomputed DEG annotation, use
an expression table, metadata table, `--statistics_mode within_plot`, and an
appropriate `--statistical_method` such as `anova`, `t-test`, or `kruskal`.

## Outputs

| File | Contents |
| --- | --- |
| `gene_boxplots/<gene>.png` | One preserved-style plot per requested gene. |
| `gene_boxplot_statistics.csv` | Pairwise values used for the annotations. |
| `gene_boxplot_expression_long.csv` | Exact sample-level values displayed in every plot. |
| `gene_boxplot_run_summary.csv` | Selected analysis settings and input scope. |

## Method notes

### Preserved implementation

[`R/Boxplot_with_Stats.R`](R/Boxplot_with_Stats.R) is the compatibility
reference. It contains the original public
`gene_boxplot_with_stats()` and `gene_boxplot_with_deg_results()` functions,
including category-order handling, duplicate-gene behavior, covariate-aware
tests, compact-letter annotations, beeswarm support, palette controls, and
layout controls. `omix_gene_boxplots()` is a thin wrapper that maps ordinary
input tables and standardized output paths to those functions; it does not
recalculate their logic.

The intentional OMIX default difference is that precomputed DEG annotations
use **nominal** p-values by default (`pvalue_to_plot = "raw"` in the preserved
function). Select `adjusted` when appropriate for the question.

### Plot appearance

The default visual style is the established CCBR template: groups are assigned
**Deep Red**, **Vivid Blue**, **Green**, **Purple**, and subsequent original
custom colors in display order; boxes are lightly filled; individual
observations are small filled circles; and a right-side legend is shown.
Comparison bars and italic p-value labels are black. Leave `colors` empty to
retain these defaults, or supply comma-separated original color names in group
order.

## Interface and deployment

See [`schemas/interface.yml`](schemas/interface.yml) for the complete
machine-readable input, parameter, and output contract.

**Deployment repository:**
[OMIX-Gene-Boxplots](https://github.com/NIDAP-Community/OMIX-Gene-Boxplots)
