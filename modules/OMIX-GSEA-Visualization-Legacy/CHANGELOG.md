# Changelog

## Unreleased

- **Breaking change:** default pathway figures now show up to 20 pathways
  rather than 10. This applies to both `--top_n_pathways` for legacy GSEA
  panels and `--pathway_bubble_top_n` for shared bubble plots.
- **Breaking change:** shared bubble plots now use adjusted p-value/FDR by
  default for pathway selection and significance shapes. The optional
  `--pathway_bubble_significance_statistic` accepts `padj` (default) or
  `pval`.
- Add shared `OmixPathwayPlots` combined, faceted cross-collection, and
  collection-specific bubble outputs, with a manifest and independent
  collection colour scales by default.
- Declared the required Bioconductor 3.20 `ComplexHeatmap` 2.22.0 runtime
  overlay so the portable leading-edge heatmap option can be provisioned with
  the shared runtime helper and recorded in the effective run lockfile.

## 2.0.0

- Changed the default GSEA visualization selection from one to ten pathways
  within each contrast × collection. The explicit `--top_n_pathways` option
  remains available for workflows that require the former one-pathway default.

## 1.0.0

- Promoted the established legacy GSEA visualization implementation into a
  platform-neutral OMIX module.
- Added an explicit-path CLI for MSigDB, filtered-GSEA, DEG-table, metadata,
  and output inputs.
- Registered the deployment adapter while retaining its platform-specific
  workflow discovery outside this module.
