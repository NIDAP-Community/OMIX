# Deployment adapter inventory

This is Beacon's evidence-based snapshot of deployment adapters registered in canonical `module.yml` files. It is an audit index, not release authorization. `Pending` and `Unknown` are intentional when durable evidence is absent.

- **Snapshot date:** 2026-09-30
- **Canonical OMIX commit:** [`d41b2e3b1e3a`](https://github.com/NIDAP-Community/OMIX/commit/d41b2e3b1e3a0971c4a8b0341678774675a5fbeb)
- **Tracked work item:** [issue #45](https://github.com/NIDAP-Community/OMIX/issues/45)
- **Machine-readable source:** [`deployment-adapter-inventory.json`](deployment-adapter-inventory.json)
- **Validation/render command:** `python3 scripts/check_deployment_adapter_inventory.py --write-summary`

## Current status

| Adapter | Canonical | Deployment | Recorded export | Current parity | Schema | App Panel | Runtime | Code Ocean | Syncweaver | Active work |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| [OMIX-DEG-Analysis](https://github.com/NIDAP-Community/OMIX-DEG-Analysis) | v0.4.0 / interface 2 | `main` @ `015b5c29` | verified | verified | verified | verified | partial | partial | pending | [PR #1](https://github.com/NIDAP-Community/OMIX-DEG-Analysis/pull/1), [PR #3](https://github.com/NIDAP-Community/OMIX-DEG-Analysis/pull/3) |
| [OMIX-GSEA-Filters-Legacy](https://github.com/NIDAP-Community/OMIX-GSEA-Filters-Legacy) | v1.0.0 / interface 1 | `master` @ `baab86f3` | verified | verified | verified | verified | partial | pending | pending | [PR #2](https://github.com/NIDAP-Community/OMIX-GSEA-Filters-Legacy/pull/2), [PR #3](https://github.com/NIDAP-Community/OMIX-GSEA-Filters-Legacy/pull/3) |
| [OMIX-GSEA-Preranked-Legacy](https://github.com/NIDAP-Community/OMIX-GSEA-Preranked-Legacy) | v5.2.0 / interface 1 | `master` @ `c29a0dc0` | verified | verified | verified | blocked | partial | pending | blocked | [PR #3](https://github.com/NIDAP-Community/OMIX-GSEA-Preranked-Legacy/pull/3), [PR #1](https://github.com/NIDAP-Community/OMIX-GSEA-Preranked-Legacy/pull/1) |
| [OMIX-GSEA-Visualization-Legacy](https://github.com/NIDAP-Community/OMIX-GSEA-Visualization-Legacy) | v4.0.0 / interface 1 | `master` @ `f8a10972` | verified | verified | verified | verified | partial | pending | pending | [PR #2](https://github.com/NIDAP-Community/OMIX-GSEA-Visualization-Legacy/pull/2) |
| [OMIX-Gene-Boxplots](https://github.com/NIDAP-Community/OMIX-Gene-Boxplots) | v1.0.0 / interface 1 | `main` @ `35ad6168` | verified | verified | verified | verified | partial | pending | pending | [PR #3](https://github.com/NIDAP-Community/OMIX-Gene-Boxplots/pull/3) |
| [OMIX-L2P-Multi](https://github.com/NIDAP-Community/OMIX-L2P-Multi) | v4.0.1 / interface 1 | `main` @ `0331e8ef` | verified | outdated | verified | outdated | partial | pending | blocked | [PR #2](https://github.com/NIDAP-Community/OMIX-L2P-Multi/pull/2) |
| [OMIX-L2P-Single](https://github.com/NIDAP-Community/OMIX-L2P-Single) | v3.1.0 / interface 1 | `main` @ `838ae385` | verified | verified | verified | partial | partial | pending | pending | [PR #2](https://github.com/NIDAP-Community/OMIX-L2P-Single/pull/2) |
| [OMIX-Volcano-Plot](https://github.com/NIDAP-Community/OMIX-Volcano-Plot) | v1.0.0 / interface 1 | `main` @ `2a30686f` | verified | verified | verified | verified | partial | pending | pending | [PR #2](https://github.com/NIDAP-Community/OMIX-Volcano-Plot/pull/2), [PR #3](https://github.com/NIDAP-Community/OMIX-Volcano-Plot/pull/3) |

## Priority findings

- **Adapters behind current canonical science:** OMIX-L2P-Multi.
- **Adapters with adapter-only or legacy files co-located in `code/functions/`:** OMIX-L2P-Multi.
- **Adapters without a Syncweaver lockfile on the default branch:** OMIX-DEG-Analysis, OMIX-GSEA-Filters-Legacy, OMIX-GSEA-Preranked-Legacy, OMIX-GSEA-Visualization-Legacy, OMIX-Gene-Boxplots, OMIX-L2P-Multi, OMIX-L2P-Single, OMIX-Volcano-Plot.
- **Canonical schema completeness:** verified for all 8 registered adapters.
- **App Panels needing remediation:** OMIX-GSEA-Preranked-Legacy (blocked), OMIX-L2P-Multi (outdated), OMIX-L2P-Single (partial).
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
