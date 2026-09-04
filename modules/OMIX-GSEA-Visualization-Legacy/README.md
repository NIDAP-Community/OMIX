# OMIX GSEA Visualization Legacy

Generate the established GSEA enrichment-score (ES), ranked-gene (RNK), and
leading-edge (LE) heatmap panels from explicit, compatible pathway-analysis
inputs.

**Runtime profile:** [`r-pathway`](../../README.md#run-a-module-on-biowulf-or-another-shared-r-system)
**Entry point:** `scripts/run_gsea_visualization.R`

## What it does

The module preserves the legacy GSEA visualization implementation while making
its inputs platform-neutral. It validates pathway membership against ranking
statistics, creates multi-page PDF figures, and writes the running enrichment
score values used in each plot.

## When to use it

Use it after [OMIX-GSEA-Filters-Legacy](../OMIX-GSEA-Filters-Legacy) when you
need publication-oriented enrichment curves and leading-edge expression
heatmaps for pathways selected from an upstream GSEA result.

## Inputs

Provide these four explicit inputs:

- **MSigDB database** — CSV or RDS database from the same release as upstream
  GSEA. It restores pathway membership only when that membership is absent in
  the filtered result.
- **Filtered GSEA results** — CSV or RDS from GSEA Filters. It requires
  `contrast`, `collection`, and `pathway`; retain `ES`, `NES`, pathway, and
  leading-edge membership columns whenever available.
- **DEG table** — CSV or RDS with a feature-ID column, wide ranking columns
  such as `B-A_tstat`, and numeric sample-expression columns. The DEG Analysis
  portable output supplies normalized expression when no batch variable was
  modeled and batch-corrected voom-scale log-CPM when batch adjustment was
  modeled.
- **Sample metadata** — CSV or RDS with sample IDs matching the DEG-expression
  columns and a grouping column. Defaults are `Sample` and `Group`.

All four inputs must come from the same biological analysis. The module stops
when reconstructed ES direction conflicts with the filtered GSEA result rather
than plotting an incompatible combination.

## Run locally or on HPC

Prepare a writable runtime project with the repository helper. It restores
`r-pathway`, installs the pinned `ComplexHeatmap` 2.22.0 Bioconductor overlay,
and writes the complete effective lockfile to `$OMIX_RUN/renv.lock`.

```bash
export OMIX_RUN=/path/to/omix-gsea-visualization-runtime
Rscript "$OMIX_ROOT/scripts/restore-omix-runtime.R" \
  --module OMIX-GSEA-Visualization-Legacy \
  --project "$OMIX_RUN"
cd "$OMIX_RUN"
```

Then run:

```bash
Rscript "$OMIX_ROOT/modules/OMIX-GSEA-Visualization-Legacy/scripts/run_gsea_visualization.R" \
  --msigdb_database /path/to/MSigDB.rds \
  --gsea_filter_results /path/to/filtered_gsea_results.csv \
  --deg_table /path/to/DEG_Analysis.csv \
  --sample_metadata /path/to/Sample_Metadata.csv \
  --plots_to_include ES+RNK+LE \
  --output_dir results/gsea-visualization
```

Use `--contrast_filter keep --contrasts B-A` to focus a comparison, or set
`--top_n_pathways 0` to plot every filtered pathway. The complete portable
contract is in [`schemas/interface.yml`](schemas/interface.yml).

## Outputs

| File | Contents |
| --- | --- |
| `GSEA-Vis-Enrichment-Plots.pdf` | Multi-page ES, RNK, and/or LE heatmap figures. |
| `GSEA-Vis-RunningES.csv` | Per-gene ranks and running enrichment scores used in the rendered panels. |

## Method notes

- The core plotting function is preserved from the legacy implementation;
  promotion changes only input handling and the portable command-line
  interface.
- LE heatmaps use the sample-level expression values in the DEG table and
  metadata-controlled ordering. No fresh differential-expression model is fit.
- The module first uses pathway membership carried by the filtered GSEA table,
  retaining that analysis provenance. It consults MSigDB only when membership
  must be restored.
- `top_n_pathways` is applied within contrast × collection. Set
  `top_n_by_sign` to select positive and negative ES pathways independently.

## Interface and deployment

See [`schemas/interface.yml`](schemas/interface.yml) for the machine-readable
input, parameter, and output contract.

**Deployment repository:**
[OMIX-GSEA-Visualization-Legacy](https://github.com/NIDAP-Community/OMIX-GSEA-Visualization-Legacy)
