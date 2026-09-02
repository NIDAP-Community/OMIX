# OMIX Gene Boxplots

Create one publication-ready gene-expression boxplot per requested gene. The
module is platform-neutral: it reads ordinary expression and metadata tables
from paths you provide and writes ordinary PNG and CSV files.

**Deployment repository:** [OMIX-Gene-Boxplots](https://github.com/NIDAP-Community/OMIX-Gene-Boxplots)

## When to use it

Use this module after an expression or differential-expression workflow when
you want to show the sample-level values behind selected genes. It accepts
voom-scale, normalized-CPM, or batch-corrected expression values; do not supply
raw counts unless a raw-count display is specifically intended.

The default `precomputed_deg` mode annotates the boxplot using the p-values
already calculated by the DEG model. This is the preferred mode for a result
such as `DEG_Analysis.csv`, because it preserves the original design, batch
terms, donor blocking, and contrast. `within_plot` is available for simple
exploratory comparisons, but it deliberately performs a new independent test
on the plotted values and is not a substitute for the original DEG model.

Each displayed comparison is drawn as a horizontal bar spanning its two
corresponding groups, labelled with the selected nominal or adjusted p-value.

## Required tables

`expression_table` must contain a gene identifier column (default `GeneName`)
and one numeric expression column per sample.

`metadata_table` must contain the sample ID column (default `Sample`) and a
grouping column (default `Group`). Sample IDs must exactly match expression
column names.

For `precomputed_deg`, provide `deg_table`, containing columns named like
`B-A_pval` and/or `B-A_adjpval`. The DEG table may be the same as the
expression table when one exported table contains both expression values and
DEG statistics.

## Run from the command line

```bash
Rscript scripts/run_gene_boxplots.R \
  --expression_table /path/to/DEG_Analysis.csv \
  --metadata_table /path/to/Sample_Metadata.csv \
  --deg_table /path/to/DEG_Analysis.csv \
  --genes Nfil3,Tox,Zbtb16,Id2,Tcf7,Gata3,Bcl11b \
  --statistics_mode precomputed_deg \
  --pvalue_type nominal \
  --output_dir results/gene-boxplots
```

For a simple exploratory test rather than a precomputed DEG annotation:

```bash
Rscript scripts/run_gene_boxplots.R \
  --expression_table normalized_expression.csv \
  --metadata_table Sample_Metadata.csv \
  --genes GeneA,GeneB \
  --statistics_mode within_plot \
  --statistical_method anova \
  --output_dir results/within-plot
```

## Outputs

- `gene_boxplots/<gene>.png` — one plot per gene.
- `gene_boxplot_statistics.csv` — pairwise values used for annotations.
- `gene_boxplot_expression_long.csv` — exact sample-level values displayed.
- `gene_boxplot_run_summary.csv` — the selected analysis settings and data
  scope.

See `schemas/interface.yml` for the machine-readable interface contract.
