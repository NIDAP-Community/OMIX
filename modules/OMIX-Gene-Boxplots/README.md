# OMIX Gene Boxplots

Create one publication-ready gene-expression boxplot per requested gene. The
module is platform-neutral: it reads ordinary expression and metadata tables
from paths you provide and writes ordinary PNG and CSV files. Its scientific
and visual implementation is the preserved CCBR `Boxplot_with_Stats.R` code,
not a simplified replacement.

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

## Preserved implementation and OMIX boundary

[`R/Boxplot_with_Stats.R`](R/Boxplot_with_Stats.R) contains the original
implementation, including its public `gene_boxplot_with_stats()` and
`gene_boxplot_with_deg_results()` functions, category-order handling,
duplicate-gene behavior, covariate-aware tests, compact-letter annotations,
beeswarm option, palette controls, and layout controls. It is the compatibility
reference and should not be refactored without regression tests against it.

`omix_gene_boxplots()` is deliberately a thin wrapper. It maps ordinary input
tables and standardized output paths to the preserved functions; it does not
recalculate their logic. Its only intentional OMIX default difference is that
**nominal** p-values are selected by default for precomputed DEG annotations
(`pvalue_to_plot = "raw"` in the preserved function). Choose `adjusted` when
you want the original DEG-wrapper default instead.

## Plot appearance

The default visual style is the established CCBR template: groups are assigned
**Deep Red**, **Vivid Blue**, **Green**, **Purple**, and subsequent original
custom colors in display order; boxes are lightly filled; individual
observations are small filled circles; and a right-side legend is shown.
Comparison bars and italic p-value labels are black. Leave `colors` empty to
retain these defaults, or provide comma-separated original color names in group
order. The preserved functions expose the complete original appearance API.

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

The first two artifacts use the same original plotting and statistics code;
the long table and run summary are additive OMIX workflow records.

See `schemas/interface.yml` for the machine-readable interface contract.
