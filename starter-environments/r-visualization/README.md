# r-visualization

Shared plotting and statistical-visualization runtime for OMIX modules.

Current consumers include:

- OMIX Gene Boxplots
- OMIX Volcano Plot
- OMIX GSEA Filters Legacy

The in-development OMIX Expression Heatmap module requires the pending
`r4.4.3-v3` runtime, which adds the pinned Bioconductor `ComplexHeatmap`
2.22.0 dependency closure. It is not supported by the published `r4.4.3-v2`
image.

The image contains the plotting stack (`ggplot2`, `dplyr`, `tidyr`, `plotly`,
`patchwork`, `pheatmap`) and the preserved CCBR gene-boxplot dependencies
(`ggbeeswarm`, `broom`, `multcomp`, `multcompView`, and `RColorBrewer`).

## Release contract

This OMIX-owned runtime uses the immutable base image
`omix-r-base:r4.4.3-v1` and the CI-captured `renv.lock` to restore its R
dependencies reproducibly. It verifies that every declared package is actually
loadable, including `plotly`; the completed legacy image exposed a missing
`plotly` installation despite declaring it. It installs `cmake` and
`libuv1-dev` locally because `plotly`'s `htmlwidgets` dependency chain needs
the `fs` package, which requires a usable `libuv` build path.

The lockfile is restored from CRAN and the pinned Bioconductor 3.20 source
repositories with one install job at a time. This avoids binary repository
restore-order failures in which a package is tested before its locked
dependency has been installed.

`r4.4.3-v1` remains the original adopted image record. `r4.4.3-v2` is the
first image built and validated from this repository's locked visualization
definition. `r4.4.3-v3` is a candidate definition until its targeted CI and a
separate publication decision complete. Every later dependency update must
produce a new CI-verified lockfile and a new image version. Capsules and other
consumers must pin an immutable published image tag or digest, never `latest`.
