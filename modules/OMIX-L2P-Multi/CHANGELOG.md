# Changelog

## Unreleased

- **Breaking change:** pathway figures now use a default top-pathway limit of
  20 rather than 10 for shared plots and 15 for direct low-level legacy plots.
  Use `--pathway_bubble_top_n` or `--maximum_pathways_to_plot` to override
  the relevant limit.
- **Breaking change:** shared bubble plots now use adjusted p-value/FDR by
  default for pathway selection and significance shapes. The optional
  `--pathway_bubble_significance_statistic` accepts `padj` (default) or
  `pval`.

- Preserve the explicit `--comparisons` order in shared pathway-bubble
  selection and display, including intentionally empty comparison columns.

- Retire the duplicate `l2p_multi_plot.png` from the portable CLI. The shared
  `OmixPathwayPlots` outputs are now the module's pathway figures; the
  low-level explicit legacy export remains available for compatibility.
- **Breaking change:** default gene-list selection now uses nominal p-value <=
  0.05 and absolute fold change >= 1.2 instead of the top/bottom t-statistic
  ranks. Pass `--select_by_rank true` to restore the prior rank-based default.
- Add shared `OmixPathwayPlots` combined, faceted cross-collection, and
  collection-specific bubble outputs, with a manifest and independent
  collection colour scales by default.
- Export every pathway that meets the selected significance and hit-count
  criteria in at least the configured number of distinct comparisons; plotting
  now applies its own top-X cap without truncating the downstream CSV.
- Prevent implicit graphics devices from writing `Rplots.pdf` during
  non-interactive command-line runs; plots are saved only through the explicit
  export path.
- Limit ortholog-mapping log output to a ten-gene preview.
- Initialized the OMIX-L2P-Multi module skeleton.
