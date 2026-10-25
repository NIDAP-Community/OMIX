# Changelog

## Unreleased

- Added L2P-informed automatic sample-axis font sizing, with a recorded
  resolved size and a compatible positive numeric override. The policy reacts
  to cohort size and label length while preserving metadata-driven labels.
- Exposed the template's existing portable sample-column ordering modes in the
  CLI and schema: clustering, annotation-group arrangement, feature-expression
  ordering, and optional clustered-dendrogram rotation. Added explicit mode
  and ordering-vector validation.
- Corrected long-feature handling so exported matrix identifiers remain exact;
  word wrapping is now strictly a plot-label layout transformation.
- Recorded that the published `r-visualization` v3 runtime supplies the
  required `ComplexHeatmap` 2.22.0 pin; the module remains in development
  pending its independent lifecycle evidence.
- Added automatic, row-count-aware feature-label visibility and font sizing:
  labels are shown for focused heatmaps of up to 50 rows and hidden for denser
  displays unless the caller explicitly overrides the choice. This preserves
  readable GSVA and pathway-gene plots without crowding broad gene heatmaps.
- Added display-only underscore-to-space conversion and font-aware wrapping
  for long row labels. The exact feature identifiers in
  `expression_heatmap_matrix.csv` remain unchanged.
- Added `auto` support for `display_gene_names` and `gene_name_font_size`, plus
  the compatible `row_label_max_length` layout control. Existing explicit
  `true`/`false` and positive numeric font-size values remain supported.
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
- Pinned the required overlay to Bioconductor `ComplexHeatmap` 2.22.0; the
  `r-visualization` v3 runtime candidate still requires validation and a
  separate publication decision.
