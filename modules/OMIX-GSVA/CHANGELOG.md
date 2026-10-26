# Changelog

## Unreleased

- Added automatic OMIX handoff defaults: `gene_column = auto` prefers `Gene`
  and then `GeneName`, while `collections_to_include = auto` selects the
  Human or Mouse Hallmark collection for the selected pathway-database
  species. Explicit existing feature columns and explicit collection names
  remain unchanged. Validation errors now identify compatible feature-ID
  columns and available collections for the selected species. This is a
  scientific-default change; module version 1.0.0 preserves interface version
  2 because existing explicit CLI and table contracts remain valid.

- Documents and regression-tests the compatible OMIX Limma Analysis
  `Batch_Corrected_Expression.csv` plus `Sample_Metadata.csv` handoff. This
  preserves the existing GSVA input contract and does not change methods,
  defaults, or the public interface.

- Advanced the canonical module from development to review after lifecycle
  audit of its direct locked-runtime validation, independent review,
  documented interface, and current release evidence. Promotion to active now
  additionally requires a reviewed local-versus-Code Ocean output comparison.
  This status change does not alter scientific behavior, the public interface,
  or deployment-release state.

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
