# `l2p-single-pathway-analysis` Derivation Preflight

**Status:** local candidate validated. This is not a repository release,
published OCI image, or OncoChat enablement claim.

**Recorded:** 2026-10-24

**Application repository:** `NIDAP-Community/l2p-single-pathway-analysis`
**Canonical module:** `modules/OMIX-L2P-Single/`

## Preflight decision

`OMIX-L2P-Single` is eligible for a standalone application derivation. It is a
`review`-status pathway module with a versioned portable CLI and interface.
The resulting component consumes a validated upstream DEG artifact; it does
not calculate differential expression and must not accept raw counts directly.
The existing Code Ocean adapter remains a distinct deployment adapter.

## Canonical source snapshot

| Item | Value |
| --- | --- |
| OMIX base source commit | `0ea6223129de6d98d69469027c19fa1887b59f6a` |
| Local canonical CLI repair | `0b2fe11` |
| Module version / interface | `3.3.0` / `1` |
| Status | `review` |
| Canonical tag | Pending |
| Runtime profile | `r-pathway` |
| Required runtime package | `OmixPathwayInputs` 0.1.0 |
| CLI | `scripts/run_l2p_single.R` |

| Canonical file | SHA-256 |
| --- | --- |
| `R/L2P_Analysis.R` | `f24c57751dcbda394cdf222bdf46892b6f463f98fb678d07234e921fa0c02054` |
| `scripts/run_l2p_single.R` | `0d96fa74049692401665265e6bee6b69fa2826a65461929cef544949eb62e701` |
| `schemas/interface.yml` | `1b9575f6573be628f8b1860c3961601541fd4c3818cd94193a59d1631de7342d` |
| `module.yml` | `72bc226804dbd1dae9c1774c5991ca9696ce2cca663a417b6924e1163244b6d9` |

The standalone repository may add only wrapper/container/provenance/CI code;
the copied canonical R and CLI files remain byte-identical.

## Runtime and OncoChat contract

The candidate base is
`ghcr.io/nidap-community/omix-r-pathway@sha256:25ad9f50df5a4d7f70a7e3debed13f8d5c9b07cbc46d57fdf5c3cf4f2e767ddc`.
The validated candidate layers `OmixPathwayInputs` 0.1.0 and lockfile-pinned
`bitops` 1.0-9 plus `RCurl` 1.98-1.19 over that image, with SHA-256 checks for
the two vendored CRAN archives.

OncoChat stages a validated DEG table at `/data/deg_results.tsv`, optionally a
validated custom-pathway file, and launches a pinned application image by
digest. The request maps only bounded schema fields. For a database-backed
study, the DEG artifact must retain the source normalization/model/comparison
identity; the container never receives database credentials or raw counts.

## Required bundle and open gates

The wrapper must collect the canonical result CSV, provenance CSV, plots, and
canonical run manifest under `tables/`, `figures/`, and `logs/`, plus
`RUN_METADATA.md`, `run_manifest.json`, and `logs/sessionInfo.txt`.

Before release: create the local candidate; validate runtime/package presence;
add source checksum and fixture-parity tests; pass a `linux/amd64` container
smoke test; validate a representative declared DEG artifact; complete OncoChat
staging/authorization/negative-path tests; and obtain a canonical tag or an
approved exception. No Code Ocean evidence substitutes for those gates.

## Canonical interface repair and candidate validation

The candidate image successfully installs `OmixPathwayInputs` 0.1.0 from the
pinned source package. However, on 2026-10-24 the canonical CLI was invoked
with a readable tabular `--custom_pathways` file and failed in
`build_custom_pathways_list()`: the CLI validates the supplied path but passes
the path string to a function that requires a data frame or L2P pathway list.
This prevents the documented file-based custom-pathway route from running.

This was repaired in the local canonical OMIX commit `0b2fe11` by reading the
declared RDS/CSV/TSV file before the canonical analysis call. The standalone
candidate copies the repaired CLI byte-for-byte. Its `linux/amd64` container
smoke fixture now exercises a tabular custom-pathway input, produces the
standardized result bundle, and passes direct canonical-output parity for the
scientific result table. The only excluded parity field is the documented
run-timestamp row in the canonical provenance CSV.

Docker's R download cannot validate the CRAN TLS chain in this environment, so
the candidate vendors the exact lockfile versions of `bitops` and `RCurl` with
checked SHA-256 values. This is a reproducible local overlay, not a change to
the shared runtime. Publication, representative-data validation, OncoChat
authorization/negative-path tests, and a canonical release tag or approved
exception remain required release gates.
