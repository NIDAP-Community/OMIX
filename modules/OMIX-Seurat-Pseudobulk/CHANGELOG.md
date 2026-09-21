# Changelog

## 0.4.0 - 2026-09-21

- Moved the module to the dedicated `r-seurat-conversion` runtime profile.
  That profile isolates full-Seurat compatibility required for legacy
  `SCTAssay` objects from all downstream analytical runtimes.
- Retained the portable table-and-manifest handoff: Seurat is used only for
  input conversion and is never added to DEG, Limma, pathway, or visualization
  environments.

## 0.3.0 - 2026-09-18

- Added mean_sctransform_expression, which averages the Seurat SCT/data layer
  separately per cell type x donor and converts the log1p donor means to log2
  scale for direct limma.
- Expanded the manifest into an explicit downstream handoff contract:
  `sum_counts` routes only to OMIX DEG Analysis raw-count/voom, while Harmony
  and SCTransform means route only to OMIX Limma Analysis continuous-expression
  analysis with their respective variance-model recommendations.
- Changed the automatic Harmony source to the gene-level `Harmony/data` assay
  written by SCWorkflow. This remains distinct from the Harmony embedding.

## 0.2.0 - 2026-09-17

- Added `mean_harmony_corrected_expression`, which averages a declared
  gene-level corrected expression layer per cell type × donor for direct limma.
- Preserved `sum_counts` as the default raw-count pseudobulk method for
  edgeR/limma-voom.
- Added `Pseudobulk_Manifest.dcf` to declare matrix semantics, source layer,
  upstream correction, and the only compatible OMIX DEG analysis mode.

## 0.1.0 - 2026-09-16

- Added a portable explicit-path workflow that writes raw donor-by-group
  pseudobulk count and metadata tables from one selected Seurat cell type.
- Standardized the DEG handoff on GeneName, Sample, and Group, while retaining
  Donor, CellType, cell counts, and optional invariant covariates.
