# Changelog

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
