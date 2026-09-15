# OMIX L2P Multi

Compare L2P over-representation results across multiple differential-expression
contrasts from one wide DEG table.

## What it does

L2P Multi performs one over-representation analysis per requested comparison,
then combines the results into a comparison-aware table and summary plot. It
is designed for a wide DEG export that contains corresponding statistics for
several contrasts.

## When to use it

Use this module when the same experiment has several comparisons and you need
to identify pathways that are shared, specific, or directionally different
across them. Use [OMIX-L2P-Single](../OMIX-L2P-Single) for one comparison.

## Quick start

**Runtime profile:** [`r-pathway`](../../README.md#run-a-module-on-biowulf-or-another-shared-r-system)

**Command:** `scripts/run_l2p_multi.R`

Choose a wide DEG table and comparison list, then use the copyable command in
[Run locally or on HPC](#run-locally-or-on-hpc).

## Inputs

Provide one CSV, TSV, TXT, or RDS wide DEG table. For each requested comparison,
the table needs a gene-ID column and comparison-specific ranking,
significance, and fold-change columns. Common column names include:

```text
GeneName, B-A_tstat, B-A_pval, B-A_adjpval, B-A_FC,
          C-A_tstat, C-A_pval, C-A_adjpval, C-A_FC
```

The module uses the comma-separated `--comparisons` value to resolve these
columns. Use explicit column-list arguments if a legacy or custom export does
not follow the conventional comparison-prefix pattern.

## Run locally or on HPC

Set `OMIX_ROOT` to the OMIX checkout, then prepare a writable runtime project:

```bash
export OMIX_RUN=/path/to/omix-l2p-multi-runtime
Rscript "$OMIX_ROOT/scripts/restore-omix-runtime.R" \
  --module OMIX-L2P-Multi \
  --project "$OMIX_RUN"
cd "$OMIX_RUN"
```

Invoke the portable CLI:

```bash
Rscript "$OMIX_ROOT/modules/OMIX-L2P-Multi/scripts/run_l2p_multi.R" \
  --deg_table /path/to/DEG_Analysis.csv \
  --comparisons B-A,C-A,B-C \
  --species Mouse \
  --collections_to_include H \
  --output_dir results/l2p-multi
```

## Outputs

| File | Contents |
| --- | --- |
| `l2p_multi_results.csv` | All pathways significant in at least `--number_of_significant_events` comparisons, with their available comparison-level enrichment values. |
| `l2p_multi_results_provenance.csv` | Resolved input columns and analysis provenance for every comparison. |
| `L2P-Multi-Pathway-Bubble_combined_pathways.png` | Shared combined-pathway bubble plot showing the top selected pathways regardless of source collection. |
| `L2P-Multi-Pathway-Bubble_across_collections.png` | Shared faceted bubble plot showing the top selected pathways across source collections, with one panel per collection. |
| `L2P-Multi-Pathway-Bubble_<collection>.png` | One shared-style bubble plot for each selected pathway collection. |
| `L2P-Multi-Pathway-Bubble_manifest.csv` | Bubble-plot selections, colour limits, output dimensions, and file names. |

## Method notes

- `--comparisons` is required; list comparison names exactly as they occur in
  the DEG column prefixes and in the desired analysis and shared bubble-plot
  order. For example, `B-A,C-A,C-B` requires matching `C-B_*` columns; it does
  not invert an available `B-C_*` result.
- By default, each comparison's up- and downregulated gene lists use nominal
  p-value <= 0.05 and absolute fold change >= 1.2. This uses the inferred
  `<comparison>_pval` and `<comparison>_FC` columns when they are available.
  To use the legacy top/bottom t-statistic ranking method instead, pass
  `--select_by_rank true`; its rank-specific options then apply.
- `--collections_to_include` defaults to `H` (MSigDB Hallmark), which is a
  useful compact starting collection for multi-comparison interpretation.
- Export selection and figure selection are deliberately separate. A pathway
  is retained in `l2p_multi_results.csv` when it meets the chosen p-value (or
  FDR) and hit-count criteria in at least one comparison by default.
- `--top_pathways` is retained only for backwards-compatible invocations and
  no longer filters the exported CSV.
- Shared bubble plots are written by default. `--pathway_bubble_top_n`
  defaults to 20; set it to `0` to show all eligible pathways. The combined
  plot selects its top paths across all collections, while each collection plot
  selects its own top paths. Collection plots use their own score colour range
  by default so a high-amplitude source cannot wash out another source; set
  `--collection_color_scale shared` for direct colour comparison across plots.
  They omit redundant collection prefixes from axis labels, while the combined
  plot retains the prefixes to distinguish source collections.
  `--pathway_bubble_significance_statistic` defaults to `padj`, so FDR
  determines both the displayed top pathways and circle-versus-X significance
  encoding; set it to `pval` for nominal p-values instead.
- `--maximum_pathways_to_plot` defaults to 20 for direct low-level R calls.
  It and the other legacy bubble-rendering options do not affect the default
  CLI outputs; use `--pathway_bubble_top_n` for the shared plots.
- Results are only as comparable as the input DEG models. Use tables generated
  from a consistent count, normalization, and statistical-model workflow.

## Interface and deployment

See [`schemas/interface.yml`](schemas/interface.yml) for the complete
machine-readable input, parameter, and output contract.

**Deployment repository:**
[OMIX-L2P-Multi](https://github.com/NIDAP-Community/OMIX-L2P-Multi)
