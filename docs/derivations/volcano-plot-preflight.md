# `volcano-plot` Derivation Preflight

**Status:** source snapshot recorded; implementation may begin. This is not a release, published image, or OncoChat enablement claim.

**Recorded:** 2026-10-24

**Application repository:** `NIDAP-Community/volcano-plot`
**Canonical module:** `modules/OMIX-Volcano-Plot/`

`OMIX-Volcano-Plot` is a `review`-status visualization module, version `1.0.0` /
interface `1`, at OMIX commit `0ea6223129de6d98d69469027c19fa1887b59f6a`.
It consumes a validated upstream DEG table and must not recreate differential
expression from a matrix. Candidate base image:
`ghcr.io/nidap-community/omix-r-visualization@sha256:1d9f453b49412aa05e9d3420cd4b1b4ea0beac4923cb40572af38b0ae2a46830`.

| File | SHA-256 |
| --- | --- |
| `R/Volcano_Plot_Enhanced.R` | `75df94195458c63130edaab5a2ee0a90c88ca9aa859591c6810d3eec5948673b` |
| `scripts/run_volcano_plot.R` | `82e9d77b9c2050df05bd3cb543a7ea759cd26a63d8c31f0286e19c48c33b66ba` |
| `schemas/interface.yml` | `fdabea7a708438d7b22042566ca08953b737115dba24b26a57f63edfdffbc4d4` |
| `module.yml` | `00c10160c48103031df8db1f5dabb67205a4c50ef11cd3793eb6ba645f143315` |

OncoChat stages a schema-identified DEG artifact plus its upstream run identity
under `/data`; bounded display/threshold parameters map directly to the
canonical interface. The application returns PNG figure(s), augmented plotting
data, and provenance. Required gates are source parity, container smoke,
representative artifact validation, result-bundle/OCI validation, digest-pinned
staging, and a canonical tag or approved exception before release.
