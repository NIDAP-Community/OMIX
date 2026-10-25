# `gene-boxplots` Derivation Preflight

**Status:** source snapshot recorded; implementation may begin. This is not a
repository release, published OCI image, or OncoChat enablement claim.

**Recorded:** 2026-10-24

**Application repository:** `NIDAP-Community/gene-boxplots` (name checked and
not found on GitHub)
**Canonical module:** `modules/OMIX-Gene-Boxplots/`

## Preflight decision

`OMIX-Gene-Boxplots` is eligible for a standalone-application derivation. It
is a `review`-status visualization module with a versioned interface, portable
CLI, preserved compatibility tests, and a published `r-visualization` runtime
digest. The application is a separate component for local/HPC/container use
and future OncoChat orchestration; it is not a rename or replacement for the
existing `NIDAP-Community/OMIX-Gene-Boxplots` Code Ocean adapter.

The standalone export may use the exact source snapshot below. Publication and
OncoChat enablement remain blocked by the open gates in this record.

## Canonical source snapshot

| Item | Recorded value |
| --- | --- |
| Canonical OMIX commit | `0ea6223129de6d98d69469027c19fa1887b59f6a` |
| Canonical branch check | `origin/main` resolved to the same commit on 2026-10-24 |
| Module version | `1.0.0` |
| Interface version | `1` |
| Module status | `review` |
| Canonical release tag | Pending; no tag was established at the recorded snapshot |
| Runtime profile | `r-visualization` |
| Canonical CLI | `modules/OMIX-Gene-Boxplots/scripts/run_gene_boxplots.R` |

### Export and interface checksums

| Canonical file | SHA-256 | Derivation role |
| --- | --- | --- |
| `R/Boxplot_with_Stats.R` | `dd4ce18058849c8560b8f137b2d8ab9b1712c88fbbd256be3ecd505469620715` | Preserved CCBR scientific plotting implementation. |
| `R/OMIX_Gene_Boxplots.R` | `9a5b8405b11347e63a7e2433356a55ec4c03f46fcbe09b1ef3bd5a3f142e6801` | Canonical workflow wrapper and output semantics. |
| `scripts/run_gene_boxplots.R` | `72d219759d0b46a5da993fe1d969bc05f625fd930c2f2783de8853514c43ae70` | Portable CLI and parameter semantics. |
| `schemas/interface.yml` | `57f2aee00ad5cdbccbfdb6c78ef6c89d392d0f60506d2d5eacca61c9d3f28033` | Canonical interface. |
| `starter-environments/r-visualization/renv.lock` | `ad17b0bec64cad3f97dfcc9e352f183fe99dcf77555b6bab6494ec277aa81b32` | Shared runtime dependency record. |

The derived repository may add only application glue: a root CLI, result
bundle/provenance wrapper, container, smoke fixture, documentation, and CI.
It must not edit copied scientific R code. Any scientific or reusable
interface correction returns to OMIX first.

## Runtime baseline

The candidate base runtime is the published OMIX visualization image:

```text
ghcr.io/nidap-community/omix-r-visualization@sha256:1d9f453b49412aa05e9d3420cd4b1b4ea0beac4923cb40572af38b0ae2a46830
```

Its profile is `r4.4.3-v2`; its pinned lockfile is recorded above. The
standalone image must be built from this digest, add its own entrypoint and
fixtures, emit OCI labels, and eventually publish under
`ghcr.io/nidap-community/gene-boxplots`. It must not retag the shared runtime
or reuse the Code Ocean adapter image as a standalone release.

## Initial OncoChat data and workflow contract

OncoChat's external study-data source remains the approved database-derived
raw-count matrix with aligned metadata. Gene Boxplots consumes only declared
workflow artifacts derived from that source:

| Staged artifact | Required form |
| --- | --- |
| `expression.tsv` | A validated normalized continuous gene-by-sample matrix produced by a declared upstream normalization component. It is not raw integer counts. |
| `sample_metadata.tsv` | One row per displayed sample with `Sample`, the requested grouping column, and only approved display/filter fields. |
| `deg_results.tsv` | Required only for `statistics_mode=precomputed_deg`; it must be the declared output of a compatible differential-expression workflow for the exact cohort, groups, model, and feature identifier convention. |

The adapter stages only these approved files under `/data`; it does not pass
database credentials, arbitrary local paths, raw shell flags, or arbitrary
uploads to the image. It must verify sample alignment, requested genes,
category values, and identifier convention before launch.

### Statistical-mode rule

The canonical default is `statistics_mode=precomputed_deg`, so omitting
`deg_results.tsv` is an error rather than a reason to invent statistics. The
initial OncoChat request must either:

1. provide a compatible upstream DEG artifact and keep `precomputed_deg`; or
2. explicitly select canonical `within_plot` or `none`, with its exploratory
interpretation made clear.

No adapter may silently substitute one mode for another, change the canonical
nominal-p-value default, or change the `duplicate_aggregation=mean` default
for normalized log-space expression.

## Required result bundle

The application wrapper must organize canonical results and provenance under
the declared output directory, at minimum:

```text
RUN_METADATA.md
run_manifest.json
logs/sessionInfo.txt
tables/gene_boxplot_statistics.csv
tables/gene_boxplot_expression_long.csv
tables/gene_boxplot_run_summary.csv
figures/gene_boxplots/<gene>.png
```

`RUN_METADATA.md` must identify the standalone revision, canonical source
record, runtime and image revision, input-artifact identities/checksums,
declared parameters, timestamp, terminal status, and the exploratory
non-clinical interpretation. The originating DEG run identity must be retained
when `precomputed_deg` is used.

## Open gates before release

1. Create the local `gene-boxplots` repository and record this source snapshot
   in `OMIX_MODULE_SOURCE.md`.
2. Export the scientific files byte-for-byte and add checksum plus fixture
   parity tests against the canonical source commit.
3. Build a repository-owned `linux/amd64` OCI image; pass a synthetic smoke
   test with `/data` read-only, `/output` writable, and the full result bundle.
4. Validate both a `precomputed_deg` run using a declared compatible DEG
   artifact and an explicitly selected non-DEG mode using approved
   representative data.
5. Complete OncoChat request validation, artifact-staging/output-collection,
   digest pinning, authorization, and negative-path acceptance tests.
6. Establish or explicitly approve an exception to the canonical module tag
   requirement before publishing a standalone release.

Existing Code Ocean adapter evidence is informative for its own deployment
contract but cannot substitute for the standalone container, result-bundle,
or OncoChat integration gates.
