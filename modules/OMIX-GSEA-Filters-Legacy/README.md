# OMIX GSEA Filters Legacy

Filter and subset GSEA result tables for focused review or downstream pathway
visualization.

**Runtime profile:** [`r-visualization`](../../README.md#run-a-module-on-biowulf-or-another-shared-r-system)
**Entry point:** `scripts/run_gsea_filters.R`

## What it does

The module filters a GSEA results table by significance, enrichment score,
pathway or leading-edge size, collection, pathway name, gene membership, and
contrast. It retains the selected GSEA annotations and membership columns in a
portable CSV and RDS export.

## When to use it

Use this module after [OMIX-GSEA-Preranked-Legacy](../OMIX-GSEA-Preranked-Legacy)
when you want a transparent, reproducible subset of pathways for interpretation
or enrichment-curve and leading-edge visualization.

## Inputs

Provide one CSV, TSV, or RDS GSEA-results table. The standard GSEA output is
supported. At minimum, the table needs:

- `contrast`, `collection`, and `pathway` columns;
- the selected p-value column (`padj` or `pval`);
- the selected enrichment-score column (`NES` or `ES`); and
- the selected size column (`size` or `size_leadingEdge`).

Preserve pathway-membership and leading-edge columns when the filtered output
will be passed to a downstream GSEA visualization module.

## Run locally or on HPC

After restoring the `r-visualization` runtime profile and setting `OMIX_ROOT`
to the OMIX checkout, run:

```bash
Rscript "$OMIX_ROOT/modules/OMIX-GSEA-Filters-Legacy/scripts/run_gsea_filters.R" \
  --input /path/to/gsea_results.csv \
  --p_value_filter 'adjusted p-value' \
  --p_value_threshold 0.05 \
  --enrichment_score_filter 'NES (Normalized Enrichment Score)' \
  --enrichment_score_threshold 1.5 \
  --output_dir results/gsea-filters
```

## Outputs

| File | Contents |
| --- | --- |
| `filtered_gsea_results.csv` | Filtered GSEA table for review and downstream workflows. |
| `filtered_gsea_results.rds` | The same filtered table in RDS format. |

## Method notes

- Adjusted p-value is the default significance criterion; raw p-value is
  available for specialized analyses.
- The score filter can use NES or ES and can retain positive, negative, or
  both directions of enrichment.
- Filters are composable: a pathway must satisfy every active criterion.
- Use explicit collection, pathway, gene, or contrast lists to create a
  documented biological subset rather than manually editing a results table.

## Interface and deployment

See [`schemas/interface.yml`](schemas/interface.yml) for the complete
machine-readable input, parameter, and output contract.

**Deployment repository:**
[OMIX-GSEA-Filters-Legacy](https://github.com/NIDAP-Community/OMIX-GSEA-Filters-Legacy)
