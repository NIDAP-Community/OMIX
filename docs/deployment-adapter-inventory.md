# Deployment adapter inventory

This is Beacon's evidence-based snapshot of deployment adapters registered in canonical `module.yml` files. It is an audit index, not release authorization. `Pending` and `Unknown` are intentional when durable evidence is absent.

- **Snapshot date:** 2026-10-04
- **Canonical OMIX commit:** [`3700650c00f0`](https://github.com/NIDAP-Community/OMIX/commit/3700650c00f0567b8c56a337fce26ddba10db5dc)
- **Tracked work item:** [issue #45](https://github.com/NIDAP-Community/OMIX/issues/45)
- **Machine-readable source:** [`deployment-adapter-inventory.json`](deployment-adapter-inventory.json)
- **Validation/render command:** `python3 scripts/check_deployment_adapter_inventory.py --write-summary`

## Current status

| Adapter | Canonical | Deployment | Recorded export | Current parity | Schema | App Panel | Runtime | Code Ocean | Syncweaver | Active work |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| [OMIX-DEG-Analysis](https://github.com/NIDAP-Community/OMIX-DEG-Analysis) | v0.4.0 / interface 2 | `main` @ `015b5c29` | verified | verified | verified | verified | partial | partial | pending | [PR #1](https://github.com/NIDAP-Community/OMIX-DEG-Analysis/pull/1), [PR #3](https://github.com/NIDAP-Community/OMIX-DEG-Analysis/pull/3) |
| [OMIX-GSEA-Filters-Legacy](https://github.com/NIDAP-Community/OMIX-GSEA-Filters-Legacy) | v1.0.0 / interface 1 | `master` @ `5df1e9db` | verified | verified | verified | verified | partial | partial | pending | [PR #2](https://github.com/NIDAP-Community/OMIX-GSEA-Filters-Legacy/pull/2), [PR #3](https://github.com/NIDAP-Community/OMIX-GSEA-Filters-Legacy/pull/3), [PR #4](https://github.com/NIDAP-Community/OMIX-GSEA-Filters-Legacy/pull/4), [PR #5](https://github.com/NIDAP-Community/OMIX-GSEA-Filters-Legacy/pull/5), [PR #6](https://github.com/NIDAP-Community/OMIX-GSEA-Filters-Legacy/pull/6) |
| [OMIX-GSEA-Preranked-Legacy](https://github.com/NIDAP-Community/OMIX-GSEA-Preranked-Legacy) | v5.3.0 / interface 1 | `master` @ `c29a0dc0` | verified | verified | verified | blocked | partial | pending | blocked | [PR #3](https://github.com/NIDAP-Community/OMIX-GSEA-Preranked-Legacy/pull/3), [PR #1](https://github.com/NIDAP-Community/OMIX-GSEA-Preranked-Legacy/pull/1) |
| [OMIX-GSEA-Visualization-Legacy](https://github.com/NIDAP-Community/OMIX-GSEA-Visualization-Legacy) | v4.0.0 / interface 1 | `master` @ `f8a10972` | verified | verified | verified | verified | partial | pending | pending | [PR #2](https://github.com/NIDAP-Community/OMIX-GSEA-Visualization-Legacy/pull/2) |
| [OMIX-GSVA](https://github.com/NIDAP-Community/OMIX-GSVA) | v0.3.0 / interface 2 | `master` @ `15086514` | verified | verified | verified | verified | partial | pending | pending | [PR #1](https://github.com/NIDAP-Community/OMIX-GSVA/pull/1), [PR #2](https://github.com/NIDAP-Community/OMIX-GSVA/pull/2) |
| [OMIX-Gene-Boxplots](https://github.com/NIDAP-Community/OMIX-Gene-Boxplots) | v1.0.0 / interface 1 | `main` @ `35ad6168` | verified | verified | verified | verified | partial | pending | pending | [PR #3](https://github.com/NIDAP-Community/OMIX-Gene-Boxplots/pull/3) |
| [OMIX-L2P-Multi](https://github.com/NIDAP-Community/OMIX-L2P-Multi) | v4.2.0 / interface 1 | `main` @ `a28113cb` | verified | verified | verified | partial | partial | partial | blocked | [PR #5](https://github.com/NIDAP-Community/OMIX-L2P-Multi/pull/5), [PR #7](https://github.com/NIDAP-Community/OMIX-L2P-Multi/pull/7), [PR #8](https://github.com/NIDAP-Community/OMIX-L2P-Multi/pull/8) |
| [OMIX-L2P-Single](https://github.com/NIDAP-Community/OMIX-L2P-Single) | v3.3.0 / interface 1 | `main` @ `ba32e3a9` | verified | verified | verified | partial | partial | partial | pending | [PR #5](https://github.com/NIDAP-Community/OMIX-L2P-Single/pull/5), [PR #7](https://github.com/NIDAP-Community/OMIX-L2P-Single/pull/7) |
| [OMIX-Limma-Analysis](https://github.com/NIDAP-Community/OMIX-Limma-Analysis) | v0.1.0 / interface 1 | `main` @ `bd584807` | verified | verified | verified | verified | partial | partial | pending | [PR #1](https://github.com/NIDAP-Community/OMIX-Limma-Analysis/pull/1) |
| [OMIX-Seurat-Pseudobulk](https://github.com/NIDAP-Community/OMIX-Seurat-Pseudobulk) | v0.4.1 / interface 1 | `main` @ `56341538` | verified | verified | verified | verified | partial | pending | pending | [PR #1](https://github.com/NIDAP-Community/OMIX-Seurat-Pseudobulk/pull/1) |
| [OMIX-Volcano-Plot](https://github.com/NIDAP-Community/OMIX-Volcano-Plot) | v1.0.0 / interface 1 | `main` @ `44be95b6` | verified | verified | verified | verified | partial | partial | pending | [PR #2](https://github.com/NIDAP-Community/OMIX-Volcano-Plot/pull/2), [PR #3](https://github.com/NIDAP-Community/OMIX-Volcano-Plot/pull/3), [PR #5](https://github.com/NIDAP-Community/OMIX-Volcano-Plot/pull/5), [PR #6](https://github.com/NIDAP-Community/OMIX-Volcano-Plot/pull/6) |

## Priority findings

- **Adapters behind current canonical science:** None.
- **Adapters with adapter-only or legacy files co-located in `code/functions/`:** OMIX-L2P-Multi.
- **Adapters without a Syncweaver lockfile on the default branch:** OMIX-DEG-Analysis, OMIX-GSEA-Filters-Legacy, OMIX-GSEA-Preranked-Legacy, OMIX-GSEA-Visualization-Legacy, OMIX-GSVA, OMIX-Gene-Boxplots, OMIX-L2P-Multi, OMIX-L2P-Single, OMIX-Limma-Analysis, OMIX-Seurat-Pseudobulk, OMIX-Volcano-Plot.
- **Canonical schema completeness:** verified for all 11 registered adapters.
- **App Panels needing remediation:** OMIX-GSEA-Preranked-Legacy (blocked), OMIX-L2P-Multi (partial), OMIX-L2P-Single (partial).
- **Runtime provenance:** no adapter source record in this snapshot supplies both a pinned runtime tag and immutable digest.

## Reading the statuses

- `verified`: direct evidence supports the claim at the recorded commits.
- `outdated`: the adapter matches its recorded source but not the canonical snapshot.
- `partial`: some evidence exists, but a required identifier or validation is missing.
- `pending`: the required audit or evidence has not been completed.
- `unknown`: the snapshot found no durable evidence either way.
- `blocked`: a known structural conflict must be resolved before proceeding.

## Update protocol

Beacon updates the JSON after a reviewed adapter or canonical change, runs the validator, regenerates this page, and links the corresponding issue, PR, CI run, Code Ocean run, runtime tag, or digest. Harbor supplies deployment facts; domain owners supply scientific-interface evidence; Forge supplies runtime provenance. Atlas coordinates review and merge order.

Do not replace a `Pending` or `Unknown` value with an inference. Add an immutable or reviewable evidence URL first.
