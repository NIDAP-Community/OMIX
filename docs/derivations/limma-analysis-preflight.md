# `limma-analysis` Derivation Preflight

**Status:** source snapshot recorded; implementation may begin. This is not a release, published image, or OncoChat enablement claim.

**Recorded:** 2026-10-24

**Application repository:** `NIDAP-Community/limma-analysis`
**Canonical module:** `modules/OMIX-Limma-Analysis/`

`OMIX-Limma-Analysis` is an `active` canonical module, version `1.2.0` /
interface `3`, at OMIX commit `0ea6223129de6d98d69469027c19fa1887b59f6a`.
Its standalone image uses the pinned `r-statistics` base:
`ghcr.io/nidap-community/omix-r-statistics@sha256:1325722877fec5167d171aa766ddf7bbfd056e4999bf40fd8c1eabee495da667`.

| File | SHA-256 |
| --- | --- |
| `R/OMIX_Limma_Analysis.R` | `c7afa223d1d0cf4ba7a73ed06d8d1c60e191a137a4c01a71671fe585fec8c69a` |
| `scripts/run_limma_analysis.R` | `954587f5e3b30f18370f4340e5f63bf8e2833902a5de2cf2b0b68396502a22d6` |
| `schemas/interface.yml` | `bebaf35ecc35fb257f9eff098c3d45d1879dcd6cea992c07dc80106d12e7d5ee` |
| `module.yml` | `b0d994117f1b57dffe6ccf1ef68c6817d41d235e243c9c4818f5bde51cd59dd9` |

OncoChat stages a declared continuous matrix and aligned metadata under `/data`.
It must retain upstream artifact and input-data-type identity, particularly for
Harmony, SCT, GSVA, fractions, or other score matrices. Raw counts are rejected
by the canonical interface and belong to the DEG component.

The wrapper may organize results/provenance but cannot alter transformation,
variance-model, or input-type defaults. Required gates are source parity,
continuous-matrix smoke and representative-data checks, result-bundle/OCI
validation, declared downstream compatibility, digest-pinned OncoChat staging,
and a canonical tag or approved exception before release.
