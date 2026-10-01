# OmixPathwayInputs

`OmixPathwayInputs` provides one base-R compatibility layer for
differential-expression tables consumed by OMIX pathway modules. It prevents
L2P Single, L2P Multi, and GSEA Preranked from maintaining divergent mappings
for the same upstream export.

The initial `0.1.0` contract recognizes Seurat `FindMarkers()` results:

- wide comparison-prefixed tables with nominal or adjusted p-values, signed
  log fold changes, and optional detection fractions; and
- native one-comparison tables using `p_val`, `p_val_adj`, `avg_log2FC` or
  legacy `avg_logFC`, and `pct.1`/`pct.2`.

Native unprefixed tables require one explicit biological comparison label.
The package never interprets detection fractions as pathway statistics and
never changes enrichment thresholds, duplicate-gene handling, or missing-value
handling. See the shared
[FindMarkers pathway input profile](../../docs/findmarkers-pathway-input.md)
for the complete contract.

Install from an OMIX checkout:

```bash
R CMD INSTALL packages/OmixPathwayInputs
```

Run direct tests:

```r
testthat::test_local("packages/OmixPathwayInputs")
```

This package must be included in `r-pathway` before modules using this profile
are released in a new runtime. Runtime publication is a separate Forge-owned
step and is not implied by a canonical module merge.
