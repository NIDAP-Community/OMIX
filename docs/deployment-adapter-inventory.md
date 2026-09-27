# Deployment adapter inventory

This is Beacon's evidence-based snapshot of deployment adapters registered in canonical `module.yml` files. It is an audit index, not release authorization. `Pending` and `Unknown` are intentional when durable evidence is absent.

- **Snapshot date:** 2026-09-27
- **Canonical OMIX commit:** [`13e3e45f360e`](https://github.com/NIDAP-Community/OMIX/commit/13e3e45f360ea58b05972cb983403a54e6411b02)
- **Tracked work item:** [OMIX issue #26](https://github.com/NIDAP-Community/OMIX/issues/26)
- **Machine-readable source:** [`deployment-adapter-inventory.json`](deployment-adapter-inventory.json)
- **Validation/render command:** `python3 scripts/check_deployment_adapter_inventory.py --write-summary`

## Current status

| Adapter | Canonical | Deployment | Recorded export | Current parity | Schema | App Panel | Runtime | Code Ocean | Syncweaver | Active work |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| [OMIX-DEG-Analysis](https://github.com/NIDAP-Community/OMIX-DEG-Analysis) | v0.4.0 / interface 2 | `main` @ `bc3b105e` | verified | outdated | pending | outdated | partial | partial | blocked | [PR #1](https://github.com/NIDAP-Community/OMIX-DEG-Analysis/pull/1) |
| [OMIX-GSEA-Filters-Legacy](https://github.com/NIDAP-Community/OMIX-GSEA-Filters-Legacy) | v1.0.0 / interface 1 | `master` @ `ed4f77ff` | verified | verified | pending | blocked | partial | pending | pending | None recorded |
| [OMIX-GSEA-Preranked-Legacy](https://github.com/NIDAP-Community/OMIX-GSEA-Preranked-Legacy) | v5.2.0 / interface 1 | `master` @ `c29a0dc0` | verified | verified | pending | pending | partial | pending | blocked | [PR #1](https://github.com/NIDAP-Community/OMIX-GSEA-Preranked-Legacy/pull/1) |
| [OMIX-GSEA-Visualization-Legacy](https://github.com/NIDAP-Community/OMIX-GSEA-Visualization-Legacy) | v4.0.0 / interface 1 | `master` @ `4aa52dba` | verified | verified | pending | pending | partial | pending | pending | None recorded |
| [OMIX-Gene-Boxplots](https://github.com/NIDAP-Community/OMIX-Gene-Boxplots) | v1.0.0 / interface 1 | `main` @ `9a8eb2e8` | verified | verified | pending | pending | partial | pending | blocked | None recorded |
| [OMIX-L2P-Multi](https://github.com/NIDAP-Community/OMIX-L2P-Multi) | v4.0.0 / interface 1 | `main` @ `0331e8ef` | verified | verified | pending | outdated | partial | pending | blocked | [PR #2](https://github.com/NIDAP-Community/OMIX-L2P-Multi/pull/2) |
| [OMIX-L2P-Single](https://github.com/NIDAP-Community/OMIX-L2P-Single) | v3.1.0 / interface 1 | `main` @ `c3618f22` | verified | verified | pending | pending | partial | pending | blocked | [PR #2](https://github.com/NIDAP-Community/OMIX-L2P-Single/pull/2) |
| [OMIX-Volcano-Plot](https://github.com/NIDAP-Community/OMIX-Volcano-Plot) | v1.0.0 / interface 1 | `main` @ `064b36f9` | verified | outdated | pending | blocked | partial | pending | blocked | None recorded |

## Priority findings

- **Adapters behind current canonical science:** OMIX-DEG-Analysis, OMIX-Volcano-Plot.
- **Adapters with adapter-only or legacy files co-located in `code/functions/`:** OMIX-DEG-Analysis, OMIX-Gene-Boxplots, OMIX-L2P-Multi, OMIX-L2P-Single, OMIX-Volcano-Plot.
- **Adapters without a Syncweaver lockfile on the default branch:** OMIX-DEG-Analysis, OMIX-GSEA-Filters-Legacy, OMIX-GSEA-Preranked-Legacy, OMIX-GSEA-Visualization-Legacy, OMIX-Gene-Boxplots, OMIX-L2P-Multi, OMIX-L2P-Single, OMIX-Volcano-Plot.
- **Schema completeness and App Panel coverage:** pending a parameter-level contract audit for every adapter; file presence alone is not counted as completeness.
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
