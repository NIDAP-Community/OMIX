# r-visualization

Shared plotting and statistical-visualization runtime for OMIX modules.

Current consumers include:

- OMIX Gene Boxplots
- OMIX Volcano Plot
- OMIX GSEA Filters Legacy

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

`r4.4.3-v1` remains the original adopted image record. `r4.4.3-v2` is the
first image built and validated from this repository's locked visualization
definition. Every later dependency update must produce a new CI-verified
lockfile and a new image version. Capsules and other consumers must pin an
immutable published image tag or digest, never `latest`.
