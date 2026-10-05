# Changelog

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
