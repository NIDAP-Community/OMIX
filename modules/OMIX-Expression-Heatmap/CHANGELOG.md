# Changelog

## Unreleased

- Corrected the canonical lifecycle classification to `development`, matching
  the lifecycle policy while the required shared runtime remains unpinned and
  unvalidated.
- Added the draft platform-neutral OMIX Expression Heatmap module from the
  established ComplexHeatmap implementation.
- Defined one explicit continuous-expression contract for bulk and
  single-cell-derived pseudobulk matrices. Direct Seurat-object extraction is
  intentionally outside this module.
- Declared `ComplexHeatmap` as a required runtime overlay pending a pinned
  shared-runtime update and validation.
