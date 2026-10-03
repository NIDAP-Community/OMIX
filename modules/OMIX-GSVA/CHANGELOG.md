# Changelog

## 0.2.0

- Replaced legacy internal template names and revision suffixes with stable
  public OMIX names in the source, documentation, run summary, and outputs.
- Renamed the stable outputs to `gsva_results.csv` and `gsva_heatmap.png`;
  increased the interface version because callers consuming the earlier names
  must update.
- Registered and linked the OMIX GSVA Code Ocean deployment adapter.
- Removed editor boilerplate without changing GSVA methods, parameters,
  scientific defaults, score-table structure, or heatmap behavior.
- Corrected the schema metadata to record interface version 2 consistently
  with `module.yml` and added regression coverage for future version changes.

## 0.1.0

- Added the canonical, platform-neutral OMIX GSVA module.
- Preserved the established GSVA methods, scientific defaults, identifier
  updating, ortholog mapping, score-table structure, and heatmap behavior.
- Added explicit input/output paths, a machine-readable interface, provenance
  summary, and synthetic representative CLI coverage.
