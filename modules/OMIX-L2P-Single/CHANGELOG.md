# Changelog

## Unreleased

- Add shared Seurat `FindMarkers()` input compatibility through
  `OmixPathwayInputs` 0.1.0. Wide families run in source order when comparison
  controls are blank; native unprefixed tables require one explicit label.
  Existing thresholds, explicit overrides, duplicate handling, and missing
  value behavior are unchanged. Module version becomes 3.3.0; interface 1
  remains compatible.
- Add advanced comparison-column suffix controls for ranking, significance,
  and fold change. They support deterministic automatic detection and ordered
  batches with nonstandard but consistent suffixes, while exact column
  overrides retain precedence for single-comparison runs.
- Fix blank comparison handling by automatically selecting exactly one
  complete comparison prefix from the DEG table. Inputs with several valid
  prefixes now stop with an actionable list rather than selecting one
  implicitly. Explicit single and ordered batched comparison controls are
  unchanged.
- Standardize machine-readable control metadata on the project-wide
  `classification` key without changing CLI behavior, defaults, outputs, or
  interface version.
- Complete the machine-readable CLI contract, classify every control as
  public, advanced, or internal, and add regression checks for names, types,
  defaults, choices, and ordered-list semantics. This documents existing
  behavior without changing scientific defaults or outputs.
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
