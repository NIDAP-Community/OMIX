# OMIX GSEA Filters Legacy

Filter and subset GSEA result tables by statistical significance, enrichment
score, pathway size, collection, pathway, gene membership, and contrast.

**Code Ocean deployment adapter:** [OMIX-GSEA-Filters-Legacy](https://github.com/NIDAP-Community/OMIX-GSEA-Filters-Legacy)

## Input

Supply a CSV, TSV, or RDS GSEA-results table. The standard output from
OMIX-GSEA-Preranked-Legacy is supported. At a minimum, the table needs
`contrast`, `collection`, `pathway`, the selected p-value column (`padj` or
`pval`), the selected enrichment-score column (`NES` or `ES`), and the selected
size column (`size` or `size_leadingEdge`).

## Run from the command line

```bash
Rscript scripts/run_gsea_filters.R \
  --input /path/to/gsea_results.csv \
  --output_dir results \
  --p_value_threshold 0.05 \
  --enrichment_score_threshold 1.5
```

The portable CLI writes `filtered_gsea_results.csv` and
`filtered_gsea_results.rds` to `--output_dir`.

## Filter behavior

- **P-value:** adjusted p-value is the default; raw p-value is available for
  specialized analyses.
- **Enrichment score:** filter by absolute NES or ES, optionally retaining
  positive or negative enrichment only.
- **Size:** filter by pathway size or leading-edge size.
- **Selection:** retain top-ranked pathways, selected collections or pathways,
  pathways containing selected genes, or selected contrasts.

The Code Ocean adapter adds an interactive HTML table and a filtering-summary
image, but its App Panel and `/data`/`/results` behavior are deliberately not
part of this platform-neutral module.

See `schemas/interface.yml` for the machine-readable interface contract and
the [OMIX module contract](../../docs/module-contract.md) for adapter ownership.
