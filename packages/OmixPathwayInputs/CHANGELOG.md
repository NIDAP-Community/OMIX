# Changelog

## 0.1.0

- Add the shared Seurat `FindMarkers()` wide and native DEG-table input
  profile used by OMIX L2P Single, L2P Multi, and GSEA Preranked.
- Preserve source comparison order, explicit reordering, input rows,
  duplicate genes, and missing values while ignoring detection fractions for
  pathway testing.
- Prefer the longest supported suffix when legacy names overlap (for example,
  `_avg_logFC` over `_logFC`).
- Document that native FindMarkers comparison labels describe `ident.1`
  relative to `ident.2`; signed fold changes are never inverted.
