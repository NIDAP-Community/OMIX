# OMIX L2P Multi

Compare L2P over-representation results across multiple differential-expression
contrasts from one wide DEG table.

**Runtime profile:** [`r-pathway`](../../README.md#run-a-module-on-biowulf-or-another-shared-r-system)
**Entry point:** `scripts/run_l2p_multi.R`

## What it does

L2P Multi performs one over-representation analysis per requested comparison,
then combines the results into a comparison-aware table and summary plot. It
is designed for a wide DEG export that contains corresponding statistics for
several contrasts.

## When to use it

Use this module when the same experiment has several comparisons and you need
to identify pathways that are shared, specific, or directionally different
across them. Use [OMIX-L2P-Single](../OMIX-L2P-Single) for one comparison.

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
| `l2p_multi_results.csv` | Combined pathway-level results, retaining comparison identity. |
| `l2p_multi_results_provenance.csv` | Resolved input columns and analysis provenance for every comparison. |
| `l2p_multi_plot.png` | Comparison-aware summary plot. |

## Method notes

- `--comparisons` is required; list comparison names exactly as they occur in
  the DEG column prefixes.
- `--collections_to_include` defaults to `H` (MSigDB Hallmark), which is a
  useful compact starting collection for multi-comparison interpretation.
- Results are only as comparable as the input DEG models. Use tables generated
  from a consistent count, normalization, and statistical-model workflow.

## Interface and deployment

See [`schemas/interface.yml`](schemas/interface.yml) for the complete
machine-readable input, parameter, and output contract.

**Deployment repository:**
[OMIX-L2P-Multi](https://github.com/NIDAP-Community/OMIX-L2P-Multi)
