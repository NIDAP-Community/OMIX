# Changelog

## Unreleased

- Adds optional declared technical-batch handling for continuous matrices.
  Batch columns are included in the Limma model, and the opt-in
  `Batch_Corrected_Expression.csv` handoff removes only those batch effects
  while protecting the biological group design. The DE statistics are
  unchanged by this downstream-output option.

- Advanced the canonical module from review to active after direct and
  contract tests, independent review, exact-runtime validation, and the
  reviewed local-versus-Code Ocean scientific-output comparison completed.
  The comparison covered the current interface-3 implementation and recorded
  numerical agreement within the declared tolerance; this lifecycle change
  does not alter scientific behavior or the public interface.
- Advanced the canonical module from development to review after the
  interface-3 implementation, documentation, direct tests, and exact-runtime
  validation completed. Deployment-platform validation remains separate and
  pending; this status change does not alter scientific behavior or the public
  interface.

## 1.0.0

- Advances the public interface to version 3: a standalone CLI run without a
  compatible manifest must now declare `input_data_type` (or use one of the
  limited explicit `input_kind` compatibility mappings) instead of silently
  treating an unknown matrix as normalized bulk expression.
- Adds a controlled `input_data_type` vocabulary for expression, pathway,
  CIBERSORT, methylation, proteomic, metabolomic, qPCR, copy-number,
  accessibility, CRISPR, and other continuous matrices.
- Makes `variance_model=auto` resolve deterministically from a compatible
  manifest or declared input type. Unknown `other_continuous` measurements
  require an explicit variance model and measurement-scale description.
- Adds declared CIBERSORT relative-fraction handling with automatic
  arcsine-square-root transformation, optional boundary-controlled logit, and
  a separate absolute-score type.
- Writes residual-variance diagnostic data and a plot, and records requested
  and resolved input, transformation, and variance decisions in run
  provenance.
- Rewrites the module README around supported scientific inputs, safe
  automatic defaults, interpretation, and complete local or HPC usage.

## 0.1.2

- Allows a blank contrast only when the selected model has exactly two groups
  with at least two samples each, then records the deterministic inferred
  comparison in run provenance.
- Rejects contrast expressions that do not contain both positive and negative
  modeled-group coefficients, preventing numeric text such as `1-0` from being
  interpreted as ordinary arithmetic when the actual groups are unrelated.
- Adds group replicate counts and requested-versus-resolved contrast details to
  the run summary and actionable ambiguity diagnostics.

## 0.1.1

- Accepts numeric modeled-group labels such as `0` and `1`, translating them
  to deterministic syntactic design names while preserving natural contrast
  and result labels such as `1-0`.
- Adds direct function and command-line regression coverage for the numeric
  grouping produced by Seurat Pseudobulk handoffs.

## 0.1.0

- Initial portable OMIX module based on the analytical core of
  `Templates/Limma_Analysis_v41.R`.
- Preserves the template's default direct `lmFit` / `eBayes` calculation,
  contrast construction, covariate handling, duplicate-feature summary, and
  optional `duplicateCorrelation` donor blocking.
- Replaces interactive notebook reporting with explicit command-line inputs,
  output files, and run provenance.
- Adds declared continuous score inputs and an explicit opt-in
  `ebayes_trend` variance model without changing the template-equivalent
  default.
