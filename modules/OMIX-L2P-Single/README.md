# OMIX L2P Single

Run L2P over-representation analysis independently for one or more requested
comparisons in a differential-expression (DEG) table.

## What it does

L2P tests whether selected pathway collections are over-represented among the
genes meeting the module's DEG criteria for one biological comparison. A
single CLI run can optionally batch several comparisons from a wide DEG table;
each remains an independent L2P analysis with its own tabular results,
provenance record, and summary plots.

## When to use it

Use L2P when you have one contrast of interest and want an interpretable
over-representation analysis of its differentially expressed genes. For a
ranked, all-gene pathway analysis, use
[OMIX-GSEA-Preranked-Legacy](../OMIX-GSEA-Preranked-Legacy) instead.

## Quick start

**Runtime profile:** [`r-pathway`](../../README.md#run-a-module-on-biowulf-or-another-shared-r-system)

**Command:** `scripts/run_l2p_single.R`

Choose one comparison, or an ordered batch of comparisons, from a compatible
DEG table, then use the copyable command in [Run locally or on HPC](#run-locally-or-on-hpc).

## Inputs

Provide one CSV, TSV, TXT, or RDS DEG table. It may contain one comparison or
be a wide table with comparison-prefixed columns. By default, the module uses
the supplied comparison name to infer a gene-ID column and matching
comparison-specific ranking, significance, and fold-change columns.

For a conventional wide DEG table, use names such as:

```text
GeneName, Treatment-Control_tstat, Treatment-Control_pval,
Treatment-Control_adjpval, Treatment-Control_FC
```

The automatic detection can be overridden with explicit gene, ranking,
significance, and fold-change column arguments when the input uses another
naming convention.

## Run locally or on HPC

Set `OMIX_ROOT` to the OMIX checkout, then prepare a writable runtime project:

```bash
export OMIX_RUN=/path/to/omix-l2p-single-runtime
Rscript "$OMIX_ROOT/scripts/restore-omix-runtime.R" \
  --module OMIX-L2P-Single \
  --project "$OMIX_RUN"
cd "$OMIX_RUN"
```

Run the entry point with explicit paths:

```bash
Rscript "$OMIX_ROOT/modules/OMIX-L2P-Single/scripts/run_l2p_single.R" \
  --deg_table /path/to/DEG_Analysis.csv \
  --comparison Treatment-Control \
  --species Mouse \
  --collections_to_include H \
  --output_dir results/l2p-single
```

To run independent analyses for several wide-table contrasts in one command,
use `--comparisons` in the desired order. Each comparison gets a subdirectory
and figures titled, for example, `B-A — Upregulated Pathways`:

```bash
Rscript "$OMIX_ROOT/modules/OMIX-L2P-Single/scripts/run_l2p_single.R" \
  --deg_table /path/to/DEG_Analysis.csv \
  --comparisons B-A,C-A,C-B \
  --species Mouse \
  --collections_to_include H \
  --output_dir results/l2p-single-batch
```

Use either `--comparison` or `--comparisons`, not both. Batched runs infer
comparison-prefixed columns automatically; do not provide fixed
`--t_statistic_column`, `--significance_column`, or `--fold_change_column`
overrides for a batch.

## Outputs

| File | Contents |
| --- | --- |
| `l2p_results.csv` | Pathway-level over-representation results for the selected comparison. |
| `l2p_results_provenance.csv` | Resolved input-column choices and analysis provenance. |
| `l2p_plots.png` | Summary plot of the L2P results. |
| `l2p_single_run_manifest.csv` | One row per requested comparison, with its output location, files, completion status, and result-row count. |

With `--comparisons`, each comparison has its own subdirectory containing the
same result, provenance, and plot files listed above.

## Method notes

- Supply exactly one of `--comparison` or `--comparisons`. Both identify the
  comparison-prefixed columns to use; `--comparisons` preserves the requested
  run order but does not pool enrichment statistics across comparisons.
- By default, L2P selects up- and downregulated gene lists using nominal
  p-value <= 0.05 and absolute fold change >= 1.2. This uses the inferred
  `<comparison>_pval` and `<comparison>_FC` columns when they are available.
  To use the legacy top/bottom t-statistic ranking method instead, pass
  `--select_by_rank true`; its rank-specific options then apply.
- `--collections_to_include` defaults to `GO,REACTOME,KEGG`; set it to `H` to
  restrict the analysis to MSigDB Hallmark pathways.
- The summary plot displays up to 20 top pathways per regulated direction by
  default. Use `--number_of_pathways_to_plot` to choose another per-direction
  limit.
- The pathway database and annotation behavior are supplied by the locked
  `r-pathway` runtime. Record the runtime lockfile, module commit, and input
  table provenance with any scientific result.

## Interface and deployment

See [`schemas/interface.yml`](schemas/interface.yml) for the complete
machine-readable input, parameter, and output contract.

**Deployment repository:**
[OMIX-L2P-Single](https://github.com/NIDAP-Community/OMIX-L2P-Single)
