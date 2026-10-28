# Changelog

## Unreleased

- Added a committed exact-result PCA regression for the public fixture and an
  explicit-path local historical-Plotly parity check. These are validation
  evidence only; PCA filtering, scaling, coordinates, and plot behavior are
  unchanged.
- Classified the canonical module as `review` after its direct CLI fixture,
  preprocessing checks, and repository checks passed in the published
  `r-visualization` v3 image. Independent review remains required before any
  later lifecycle decision.
- Added the canonical OMIX PCA 3D module at version 0.1.0, interface 1.
- Preserved the CCBR 3D PCA template's optional edgeR CPM, zero-mean and
  zero-variance feature filters, scaled PCA, fixed-seed palette extension,
  Plotly visualization, and components/coordinates outputs.
- Replaced Code Ocean-specific `new.output()` handling with explicit input and
  output paths. No deployment adapter is registered.
- Added a small synthetic fixture and direct layout/preprocessing checks.
- Declared the exact Bioconductor edgeR 4.4.2 module overlay for the existing
  `r-visualization` runtime profile. This is an interface declaration only;
  no shared runtime was rebuilt or published.
- Corrected the portable HTML-output default after an exact published
  `r-visualization` v3 run established that its image does not contain Pandoc.
  The default now writes `pca_3d.html` with `pca_3d_files/`; an explicit
  `self_contained_html` control retains the historical single-file form for
  Pandoc-equipped environments. This does not alter PCA or plot semantics.

## Imported-template provenance

- Baseline examined: CCBR PCA 3D template revision 43, SHA-256
  `a6e4145ef01a829ab399939ae5c69a74fbfc881bde71c6118da12c6ca5c5b1d0`.
- Companion App Panel revision 43, SHA-256
  `4d067c8651d805d6e7f55b77dd6a5d7c5dce2a60809ecbc273642aa13ce2ac7f`,
  was released after Example Code Workbook testing. It establishes the
  preserved defaults: CPM disabled, point size 8, title `PCA 3D`, and the
  ordered 12-color palette.
- Revision 43 differs from revision 42 only in the order of function
  arguments. The earlier revision 42 removed the prior invisible coordinate
  return; the portable module instead writes that same coordinate table as a
  documented output file.
