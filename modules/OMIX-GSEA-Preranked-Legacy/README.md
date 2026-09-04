# OMIX GSEA Preranked Legacy

Perform pre-ranked gene-set enrichment analysis from differential-expression
ranking statistics and a supplied gene-set database.

**Runtime profile:** [`r-pathway`](../../README.md#run-a-module-on-biowulf-or-another-shared-r-system)
**Entry point:** `scripts/run_gsea.R`

## What it does

GSEA tests whether genes from a pathway concentrate toward either end of a
ranked differential-expression list. The module uses `fgsea` to calculate
enrichment scores, normalized enrichment scores, p-values, FDR, and leading
edge genes for one or more contrasts.

## When to use it

Use pre-ranked GSEA when a well-specified DEG model produces a continuous
ranking statistic and you want to detect coordinated pathway changes without
first selecting a hard DEG cutoff. Use L2P when you instead want
over-representation analysis of a defined gene subset.

## Inputs

Provide two input files:

| Input | Requirements |
| --- | --- |
| DEG table | CSV, TSV, or RDS table with one gene-ID column and one or more ranking-score columns. |
| Pathways database | CSV, TSV, or RDS gene-set membership database, such as an MSigDB release. |

By default, the module looks for ranking columns that end in `_tstat`, for
example `Treatment-Control_tstat`. It auto-detects `GeneName`, then `Gene
Symbols` and other common identifier columns; specify `--gene_names_column`
when the input uses a different name.

## Run locally or on HPC

Set `OMIX_ROOT` to the OMIX checkout, then prepare a writable runtime project:

```bash
export OMIX_RUN=/path/to/omix-gsea-runtime
Rscript "$OMIX_ROOT/scripts/restore-omix-runtime.R" \
  --module OMIX-GSEA-Preranked-Legacy \
  --project "$OMIX_RUN"
cd "$OMIX_RUN"
```

Run:

```bash
Rscript "$OMIX_ROOT/modules/OMIX-GSEA-Preranked-Legacy/scripts/run_gsea.R" \
  --deg_table /path/to/DEG_Analysis.csv \
  --pathways_database /path/to/MSigDB.rds \
  --gene_scores_suffix _tstat \
  --species Mouse \
  --output_dir results/gsea
```

## Outputs

| File | Contents |
| --- | --- |
| `gsea_results.csv` | Pathway, contrast, enrichment statistics, FDR, pathway size, and leading-edge genes. |
| `gsea_pvalue_tables.png` | Visual summary of pathway p-values. |

## Method notes

- GSEA uses every ranked gene, rather than only genes passing a DEG threshold.
- Positive and negative normalized enrichment scores correspond to the two
  ends of the supplied ranking; interpret direction in the context of the
  contrast definition.
- The pathway database determines the available collections. Hallmark (`H`) is
  often a useful first collection for concise biological interpretation.
- Non-human inputs are mapped to human orthologs for pathway testing, then
  results are mapped back to the original identifiers where possible.
- Preserve the exact database release, ranking statistic, module commit, and
  runtime lockfile with downstream results.

## Interface and deployment

See [`schemas/interface.yml`](schemas/interface.yml) for the complete
machine-readable input, parameter, and output contract.

**Deployment repository:**
[OMIX-GSEA-Preranked-Legacy](https://github.com/NIDAP-Community/OMIX-GSEA-Preranked-Legacy)

## References

- Korotkevich G, et al. Fast gene set enrichment analysis. *bioRxiv*. 2021.
  [doi:10.1101/060012](https://doi.org/10.1101/060012)
- Subramanian A, et al. Gene set enrichment analysis: a knowledge-based
  approach for interpreting genome-wide expression profiles. *PNAS*. 2005.
  [doi:10.1073/pnas.0506580102](https://doi.org/10.1073/pnas.0506580102)
- Liberzon A, et al. The Molecular Signatures Database hallmark gene set
  collection. *Cell Systems*. 2015.
  [doi:10.1016/j.cels.2015.12.004](https://doi.org/10.1016/j.cels.2015.12.004)
