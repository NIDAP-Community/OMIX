# `differential-expression-analysis` Derivation Preflight

**Status:** source snapshot recorded; implementation may begin. This is not a
release, published image, or OncoChat enablement claim.

**Recorded:** 2026-10-24

**Application repository:** `NIDAP-Community/differential-expression-analysis`
**Canonical module:** `modules/OMIX-DEG-Analysis/`

`OMIX-DEG-Analysis` is eligible for derivation: it is `review` status with a
versioned CLI/interface and tests. It is the workflow component that consumes
approved database-derived raw counts; downstream visualization/pathway tools
must consume its declared results rather than recalculate a model.

| Item | Value |
| --- | --- |
| OMIX commit | `0ea6223129de6d98d69469027c19fa1887b59f6a` |
| Version / interface | `0.4.3` / `2` |
| Runtime | `r-statistics` |
| Base image | `ghcr.io/nidap-community/omix-r-statistics@sha256:1325722877fec5167d171aa766ddf7bbfd056e4999bf40fd8c1eabee495da667` |
| Canonical tag | Pending |

| File | SHA-256 |
| --- | --- |
| `R/OMIX_DEG_Analysis.R` | `b7b27095689bb0cb0419ba1002ef74cbad9c456db476876b13be633863e2ec81` |
| `scripts/run_deg_analysis.R` | `898c2dd7436fc7dc79abc708fe28448937bdf5d9f3fefde0931c65c8e5835f44` |
| `schemas/interface.yml` | `7b0f6ac828f1158fb0039bae303160dbfc49b7a36ae0bc426670a73fbd66e74c` |
| `module.yml` | `ab1442b4c38316489e02e22221d88d146f836085868d197c58d7ba9133a9947b` |

OncoChat stages a feature-by-sample integer count matrix and sample metadata
under `/data`; the request must declare analysis mode, groups/contrasts, and
bounded optional covariates. It must retain query identity and source checksums
in job provenance. The image does not connect to PostgreSQL or accept arbitrary
host paths/flags.

The standalone wrapper must add provenance/result organization without changing
canonical model defaults. Required gates: source parity, a raw-count container
fixture, malformed-input rejection, declared representative-data validation,
workflow output compatibility, digest-pinned OncoChat staging, and a canonical
tag or approved exception before release.
