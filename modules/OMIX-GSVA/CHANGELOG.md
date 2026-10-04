# Changelog

## 0.3.0

- Added deterministic per-input delimiter detection and optional overrides for
  normalized expression, sample metadata, and pathway membership tables so
  CSV and TSV inputs can be used together in one run.
- Retained `input_delim` as the backward-compatible fallback when an
  input-specific delimiter is not supplied.

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
