# Changelog

## 0.4.0 - 2026-09-18

- Added sct_mean_expression for log2-scale donor means derived from Seurat
  SCT/data. It fits limma directly and rejects TMM, voom, count filtering, and
  downstream batch-effect removal.
- SCTransform corrects technical depth but does not imply that technical batch
  has been handled. An unhandled batch can be modelled through
  covariate_columns; it is not silently removed from the returned expression.

## 0.3.0 - 2026-09-17

- Added the explicit `harmony_mean_expression` analysis mode for declared
  Harmony-corrected donor-level mean expression. It fits limma directly and
  rejects TMM, voom, count filtering, and a second technical-batch adjustment.
- Added optional `Pseudobulk_Manifest.dcf` validation so an upstream donor-level
  matrix can only enter its compatible DEG path.
- Preserved the existing `raw_counts` edgeR TMM plus limma-voom behavior as the
  default path. This is a backward-compatible scientific capability expansion;
  interface version remains 2.

## 0.2.0 - 2026-09-16

- Standardized the first `DEG_Analysis.csv` column as `GeneName` regardless of
  the caller's input feature-column label. This is an interface-version 2
  change for downstream tools.

## 0.1.5 - 2026-09-02

- Reordered the normalization guidance and public interface to recommend TMM,
  then Quantile, then TMM + Quantile, before the remaining specialist
  profiles.

## 0.1.4 - 2026-09-02

- Export `Sample_Metadata.csv` beside `DEG_Analysis.csv`, restricted and
  ordered to the sample-expression columns present in the DEG result. The two
  files form one portable downstream data bundle.

## 0.1.3 - 2026-08-27

- Restored the saved voom mean-variance trend diagnostic alongside the
  normalization boxplot and density diagnostics.

## 0.1.2 - 2026-08-26

- Reject under-replicated comparison groups before fitting limma-voom, with a
  clear message that cells are not biological DEG replicates.
- Added a reproducible, ignored Kang IFN-beta PBMC pseudobulk fixture generator
  for local paired-design integration checks.
- Documented the optional `OmixSeurat` bridge for SeuratObject-based raw-count
  pseudobulk conversion.

## 0.1.1 - 2026-08-25

- Added combined edgeR-plus-voom normalization profiles, including TMM,
  TMM + Scale, TMM + Quantile, and TMM + Cyclic Loess.
- Added opt-in normalization diagnostics to the scientific function and
  default diagnostic PNG outputs to the CLI and deployment adapter.

## 0.1.0 - 2026-08-25

- Added the initial portable raw-count DEG module.
- Added explicit table and optional MOSuite MOO command-line inputs.
- Added design-aware filtering, TMM normalization, limma-voom modelling, and
  repeated-measures support from the reviewed DEG implementation.
