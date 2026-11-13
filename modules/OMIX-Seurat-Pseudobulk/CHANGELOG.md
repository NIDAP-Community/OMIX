# Changelog

## Unreleased

- Made `output_dir` mandatory for both one-category and collection runs, and
  reject non-empty output directories before writing artifacts. This prevents
  an implicit working-directory-relative `results/` folder and mixed outputs
  from separate runs.
- Breaking interface-2 rename: `cell_category_column`, `cell_category`,
  `cell_category_mode`, and `cell_category_selection` replace the former
  cell-type inputs. The collection catalog, manifest fields, nested directory,
  and metadata field now use `CellCategory` and `cell_categories` consistently.
  Categories can be cell types, clusters, regions, or state labels.
- Fixed collection-mode `on_insufficient_cells = drop` so that a cell category
  with fewer than two groups after sparse profile removal is recorded and
  omitted rather than aborting other valid cell-category bundles. The collection
  manifest and run summary now distinguish requested, written, and omitted
  cell categories; strict `error` behavior is unchanged.
- Added an opt-in cell-category collection capability. Selected mode reads an
  ordered exact-label table and all mode enumerates non-missing labels after
  any explicit cell filter. Each label produces an ordinary nested pseudobulk
  bundle plus a profile-level eligibility/provenance catalog.
- Collection mode keeps donor-by-group profiles as biological replicates,
  applies the existing minimum-cell policy independently per cell category, and
  rejects unknown labels, duplicate/empty selections, and labels with fewer
  than two retained groups. It does not pool cells or fit Limma models.
- Registered the accepted Code Ocean deployment-adapter repository without
  changing the portable scientific implementation or interface version.
- Added a deterministic, text-baselined public-CLI equivalence fixture covering
  raw RNA counts, legacy gene-level `Harmony/data`, a real `SCTAssay`, and the
  required canonical DEG or Limma downstream route. Scientific defaults and
  the public interface are unchanged.

## 0.4.2

- Restored compatible extraction of standard expression matrices from legacy
  slot-based Seurat `Assay` objects, including a declared `Harmony/data`
  assay, when the installed SeuratObject layer accessor does not recognize the
  assay name. The public interface and aggregation behavior are unchanged.

## 0.4.1

- Constrained `feature_id_column` to the only implemented and downstream-safe
  value, `GeneName`, in the schema and CLI validation.
- Clarified that this is a fixed handoff contract rather than a configurable
  scientific parameter. The interface version remains 1 because the
  implementation already rejected every other value.

## 0.4.0 - 2026-09-21

- Moved the module to the dedicated `r-seurat-conversion` runtime profile.
  That profile isolates full-Seurat compatibility required for legacy
  `SCTAssay` objects from all downstream analytical runtimes.
- Retained the portable table-and-manifest handoff: Seurat is used only for
  input conversion and is never added to DEG, Limma, pathway, or visualization
  environments.

## 0.3.0 - 2026-09-18

- Added mean_sctransform_expression, which averages the Seurat SCT/data layer
  separately per cell category x donor and converts the log1p donor means to log2
  scale for direct limma.
- Expanded the manifest into an explicit downstream handoff contract:
  `sum_counts` routes only to OMIX DEG Analysis raw-count/voom, while Harmony
  and SCTransform means route only to OMIX Limma Analysis continuous-expression
  analysis with their respective variance-model recommendations.
- Changed the automatic Harmony source to the gene-level `Harmony/data` assay
  written by SCWorkflow. This remains distinct from the Harmony embedding.

## 0.2.0 - 2026-09-17

- Added `mean_harmony_corrected_expression`, which averages a declared
  gene-level corrected expression layer per cell category × donor for direct limma.
- Preserved `sum_counts` as the default raw-count pseudobulk method for
  edgeR/limma-voom.
- Added `Pseudobulk_Manifest.dcf` to declare matrix semantics, source layer,
  upstream correction, and the only compatible OMIX DEG analysis mode.

## 0.1.0 - 2026-09-16

- Added a portable explicit-path workflow that writes raw donor-by-group
  pseudobulk count and metadata tables from one selected Seurat cell category.
- Standardized the DEG handoff on GeneName, Sample, and Group, while retaining
  Donor, CellCategory, cell counts, and optional invariant covariates.
