# Changelog

## Unreleased

- Declared the required Bioconductor 3.20 `ComplexHeatmap` 2.22.0 runtime
  overlay so the portable leading-edge heatmap option can be provisioned with
  the shared runtime helper and recorded in the effective run lockfile.

## 1.0.0

- Promoted the established legacy GSEA visualization implementation into a
  platform-neutral OMIX module.
- Added an explicit-path CLI for MSigDB, filtered-GSEA, DEG-table, metadata,
  and output inputs.
- Registered the deployment adapter while retaining its platform-specific
  workflow discovery outside this module.
