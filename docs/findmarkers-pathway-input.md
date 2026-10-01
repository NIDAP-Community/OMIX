# Seurat FindMarkers input profile for pathway modules

This profile is the single canonical mapping used by OMIX L2P Single, L2P
Multi, and GSEA Preranked when a differential-expression table was derived
from Seurat `FindMarkers()`. It changes only input translation. Each module's
existing enrichment method, thresholds, pathway database, and plots remain
unchanged.

## Wide comparison-prefixed tables

A wide table may contain several comparison families. This commonly occurs
after several `FindMarkers()` results are joined by gene identifier:

```text
Gene
C_1_vs_2_pval
C_1_vs_2_logFC
C_1_vs_2_pct1
C_1_vs_2_pct2
C_1_vs_2_adjpval
C_3_vs_all_pval
C_3_vs_all_logFC
C_3_vs_all_pct1
C_3_vs_all_pct2
C_3_vs_all_adjpval
```

The compatibility layer recognizes nominal p-value suffixes `_pval` and
`_p_val`, adjusted-p-value suffixes `_adjpval` and `_p_val_adj`, and signed
log-fold-change suffixes `_logFC`, `_avg_log2FC`, and `_avg_logFC`.
Comparison order follows the first occurrence of each complete family in the
source table unless the caller supplies an explicit ordered comparison list.

Automatic FindMarkers recognition requires either a matched `pct1`/`pct2`
family or a Seurat-specific `avg_log2FC`/`avg_logFC` suffix. This prevents a
generic custom DEG table from silently changing its established column
resolution behavior.

## Native one-comparison tables

A native current Seurat table normally contains:

```text
p_val, avg_log2FC, pct.1, pct.2, p_val_adj
```

Legacy tables may use `avg_logFC`. Genes may be in a named column, retained R
row names, or the unnamed first column produced when row names are written to
CSV. Because these statistic names do not contain a biological comparison,
the caller must provide exactly one comparison label. OMIX never invents that
label from file position or metadata.

## Statistical mappings

- L2P threshold mode uses nominal p-value and signed log2 fold change by
  default. Its existing linear `fold_change_threshold` is converted to log2
  units by the L2P implementation because the mapped column name remains
  `_logFC`.
- Adjusted p-values remain available through the existing significance-column
  or suffix override. They are not silently substituted for nominal p-values.
- GSEA uses the signed log fold change as its ranking score when a recognized
  FindMarkers table is supplied and no ranking suffix was explicitly chosen.
- Detection fractions (`pct1`/`pct2` or `pct.1`/`pct.2`) are recorded as
  ignored metadata. They are never interpreted as significance, fold change,
  rank, or pathway size.

The normalization helper adds analysis aliases without deleting, sorting,
filtering, aggregating, or imputing input rows. Existing duplicate-gene and
missing-value behavior therefore remains owned by the downstream module.

## Ambiguity and overrides

An explicit gene-column override always takes precedence. Automatic mode
stops when it finds multiple plausible gene columns, both current and legacy
native fold-change columns, duplicate column names, incomplete FindMarkers
families, or requested comparisons that are absent. Existing exact column and
suffix controls remain available and override automatic module choices.

