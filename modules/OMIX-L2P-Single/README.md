# OMIX L2P Single

Run a single-comparison L2P over-representation analysis from a
differential-expression (DEG) table.

**Runtime profile:** [`r-pathway`](../../README.md#run-a-module-on-biowulf-or-another-shared-r-system)
**Entry point:** `scripts/run_l2p_single.R`

## What it does

L2P tests whether selected pathway collections are over-represented among the
genes meeting the module's DEG criteria for one biological comparison. It
returns tabular pathway results, a provenance record of the resolved input
columns, and a summary plot.

## When to use it

Use L2P when you have one contrast of interest and want an interpretable
over-representation analysis of its differentially expressed genes. For a
ranked, all-gene pathway analysis, use
[OMIX-GSEA-Preranked-Legacy](../OMIX-GSEA-Preranked-Legacy) instead.

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

After restoring the `r-pathway` runtime profile and setting `OMIX_ROOT` to the
OMIX checkout, run the entry point with explicit paths:

```bash
Rscript "$OMIX_ROOT/modules/OMIX-L2P-Single/scripts/run_l2p_single.R" \
  --deg_table /path/to/DEG_Analysis.csv \
  --comparison Treatment-Control \
  --species Mouse \
  --collections_to_include H \
  --output_dir results/l2p-single
```

## Outputs

| File | Contents |
| --- | --- |
| `l2p_results.csv` | Pathway-level over-representation results for the selected comparison. |
| `l2p_results_provenance.csv` | Resolved input-column choices and analysis provenance. |
| `l2p_plots.png` | Summary plot of the L2P results. |

## Method notes

- `--comparison` is required and identifies the biological direction and the
  comparison-prefixed columns to use.
- `--collections_to_include` defaults to `GO,REACTOME,KEGG`; set it to `H` to
  restrict the analysis to MSigDB Hallmark pathways.
- The pathway database and annotation behavior are supplied by the locked
  `r-pathway` runtime. Record the runtime lockfile, module commit, and input
  table provenance with any scientific result.

## Interface and deployment

See [`schemas/interface.yml`](schemas/interface.yml) for the complete
machine-readable input, parameter, and output contract.

**Deployment repository:**
[OMIX-L2P-Single](https://github.com/NIDAP-Community/OMIX-L2P-Single)
