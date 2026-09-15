# Changelog

## Unreleased

- Add optional `--comparisons` for independent, ordered batched L2P Single
  runs from one wide DEG table. Each comparison receives its own output
  directory and comparison-annotated figure titles; the root run manifest
  records all generated outputs. Existing `--comparison` calls remain
  supported unchanged.
- **Breaking change:** the summary plot now displays up to 20 top pathways per
  regulated direction by default, rather than 12. Use
  `--number_of_pathways_to_plot` to reproduce another limit.
- **Breaking change:** default gene-list selection now uses nominal p-value <=
  0.05 and absolute fold change >= 1.2 instead of the top/bottom t-statistic
  ranks. Pass `--select_by_rank true` to restore the prior rank-based default.
- Prevent implicit graphics devices from writing `Rplots.pdf` during
  non-interactive command-line runs; plots are saved only through the explicit
  export path.
- Initialized the OMIX-L2P-Single module skeleton.
