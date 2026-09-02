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

This OMIX-owned bootstrap definition uses the immutable base image
`omix-r-base:r4.4.3-v1`. It verifies that every declared package is actually
loadable, including `plotly`; the completed legacy image exposed a missing
`plotly` installation despite declaring it.

The initial `r4.4.3-v0` version is validation-only and cannot be published.
Its CI artifact will provide the fully resolved `renv.lock`. Commit that lock,
replace the bootstrap installation step with `renv::restore()`, and change the
version to `r4.4.3-v1` before the first OMIX-owned release.
