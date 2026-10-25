# `gsva-analysis` Derivation Preflight

**Status:** local application candidate validated. This is not a repository
release, published OCI image, or OncoChat enablement claim.

**Recorded:** 2026-10-24

**Application repository:** `NIDAP-Community/gsva-analysis` (name verified
available on GitHub)
**Canonical module:** `modules/OMIX-GSVA/`

This record applies the [standalone application repository
contract](../standalone-application-repository-contract.md) before a separate
repository is initialized.

## Preflight decision

`OMIX-GSVA` is eligible to begin a standalone-repository derivation because it
has status `review`, a defined versioned interface, direct CLI tests, and a
released `r-pathway` runtime. The derived repository must be a portable
application component—not a copy or rename of the existing
`NIDAP-Community/OMIX-GSVA` Code Ocean adapter.

Implementation may use the exact source snapshot below. Publication and
OncoChat enablement remain blocked by the open gates in this document.

## Canonical source snapshot

| Item | Recorded value |
| --- | --- |
| Canonical OMIX commit | `0ea6223129de6d98d69469027c19fa1887b59f6a` |
| Canonical branch check | `origin/main` resolved to the same commit on 2026-10-24 |
| Module version | `0.3.0` |
| Interface version | `2` |
| Module status | `review` |
| Canonical release tag | Pending; no tag was established at the recorded snapshot |
| Runtime profile | `r-pathway` |
| Canonical CLI | `modules/OMIX-GSVA/scripts/run_gsva.R` |

### Export and interface checksums

| Canonical file | SHA-256 | Derivation role |
| --- | --- | --- |
| `R/GSVA.R` | `2ef7ab5d3726a89676ffb6e5e6b1bc42b41c4ef59093d3754252c8035b0fa7ad` | Scientific implementation; must remain byte-identical in the application export. |
| `scripts/run_gsva.R` | `5ed78b47ba2910d7b1b39102c4f2c2f003558e59e489265f473da7bdb09487ed` | Reference portable CLI and parameter semantics. |
| `schemas/interface.yml` | `186c7a70b6bd60321257d448bc9666badb91cebd77036af0ecaab5dc4d324c6a` | Source input/output interface. |
| `starter-environments/r-pathway/renv.lock` | `520ffdb1c855bb5259731bc0069f78e1d2f7cb8846b86c629d7f5449c277e4a4` | Shared runtime dependency record. |

The derived repository may add its root CLI, data-staging contract, result
bundle, container, tests, and documentation. It must not modify `GSVA.R` in
place. Any scientific or reusable-interface correction returns to OMIX first.

## Runtime baseline

The initial candidate base runtime is the published OMIX `r-pathway` release:

```text
ghcr.io/nidap-community/omix-r-pathway@sha256:25ad9f50df5a4d7f70a7e3debed13f8d5c9b07cbc46d57fdf5c3cf4f2e767ddc
```

Its recorded profile is `r4.4.3-bioconductor3.20-v2`, with R 4.4.3,
Bioconductor 3.20, GSVA 2.0.7, and L2P/L2Psupp 0.0-14. The standalone image
must be built from this digest or another explicitly approved replacement,
then add the pinned application source, root entrypoint, smoke fixture, and
OCI labels. It must publish under
`ghcr.io/nidap-community/gsva-analysis`, not by retagging the shared runtime.

## Local candidate validation

On 2026-10-24, the local `gsva-analysis` repository candidate at
`782580d96e75904bc8568445b7849f48150aa579` was built from the pinned
`r-pathway` digest as `linux/amd64`. Its local Docker image ID was
`sha256:7fca82007cb264c8c3e7059dc9a3a3330dd7af95ef7230ed9f79709100fd640c`.
Apple Silicon executed it through Docker emulation; this is local validation,
not native hosted-CI evidence.

The candidate passed a synthetic end-to-end smoke test and wrote this result
bundle under the writable output mount:

```text
RUN_METADATA.md
run_manifest.json
tables/gsva_results.csv
figures/gsva_heatmap.png
logs/gsva_run_summary.txt
logs/sessionInfo.txt
```

The copied `GSVA.R`, canonical CLI, interface schema, and `module.yml` still
match the four source checksums recorded above. Its `--help` path works, and a
deliberately nonexistent gene column is rejected before success metadata is
written. The wrapper supplies result organization and provenance only; it does
not change scientific defaults or modify the canonical GSVA export.

For the same synthetic fixture and parameter request, the exact canonical OMIX
CLI mounted from `modules/OMIX-GSVA` and the standalone wrapper were executed
in the same pinned runtime. `gsva_results.csv` and `gsva_run_summary.txt` were
byte-for-byte identical before the standalone wrapper organized them into its
result bundle.

This is **not** complete result-bundle or release evidence. The initial
synthetic membership file cannot establish the required live
`pathway_identifier_map.csv` or `gene_identifier_resolution.csv`; those wait
for the catalog-mapping gate and an approved representative study. The image
is local only, without a published application digest or remote repository.

## Initial OncoChat data contract

The external study-data source is the approved PostgreSQL dataset materialized
for one job. For the first GSVA integration:

| Staged artifact | Source and required form |
| --- | --- |
| `normalized_expression.tsv` | Pivot the supported parent `counts_tpm` relation with `ensemblgenes` and selected `samples` into a `Gene` column plus selected sample columns. The value scale is the stored TPM/normalized continuous value; raw integer counts are not accepted by canonical GSVA. |
| `sample_metadata.tsv` | One row per selected sample with `Sample` and only the approved metadata fields needed for selection, grouping, or display. Its order defines the default GSVA sample order. |
| `pathway_membership.tsv` | Build from supported `pw_genesets` and `pw_genes`, not the abandoned `public.pathways` relation. Translate the selected catalog into canonical `collection`, `gene_set_name`, `gene_symbol`, and `species` columns. |

No arbitrary user upload, local path, or database credential reaches the GSVA
container. OncoChat stages these artifacts under `/data` and launches the
application image with only bounded, schema-validated request fields.

The stage-in implementation must retain the SQL/query identity, approved
cohort selection, source-table identifiers, row counts, and checksums in the
job provenance. It must query `counts_tpm` rather than a partition child.

### Pathway catalog mapping gate

The deployed pathway schema identifies gene sets by `(category, accession)`
and stores display text in `pw_genesets.name`. Before choosing a user-visible
default collection, validate the live catalog values and define a stable unique
mapping to canonical `collection` and `gene_set_name`. Preserve a mapping
table in the result bundle so an output `Geneset` can be traced to its source
category, accession, and display name.

Do not assume that the canonical module's illustrative default string
`H: hallmark gene sets` is already a live database category. The initial
request surface may offer only catalog values confirmed by this gate.

## Initial request surface

The OncoChat adapter must translate validated fields to the canonical interface
without exposing file paths or arbitrary CLI flags:

- approved cohort/sample selection and optional approved metadata grouping;
- expression species and pathway-catalog species;
- one or more catalog collection identifiers;
- GSVA method: `gsva`, `ssgsea`, `zscore`, or `plage`;
- bounded minimum and maximum gene-set sizes;
- whether canonical L2P gene-symbol updating is enabled; and
- image dimensions within configured safe ranges.

The initial deployment defaults to a human `counts_tpm` expression artifact.
Mouse support remains available only after the selected catalog provides a
validated mouse/orthology-aware membership mapping. The existing canonical
module behavior—explicit species choices with automatic L2P update/ortholog
mapping—must remain unchanged.

## Required result bundle

In addition to the canonical outputs `gsva_results.csv`, `gsva_heatmap.png`,
and `gsva_run_summary.txt`, the standalone component must write:

```text
RUN_METADATA.md
run_manifest.json
logs/sessionInfo.txt
tables/pathway_identifier_map.csv
tables/gene_identifier_resolution.csv
```

The score table is the declared downstream handoff artifact for compatible
continuous-matrix consumers, initially including `limma-analysis` after its
own derivation and compatibility review.

## Open gates before release

1. Create a local `gsva-analysis` repository from the standalone contract and
   record this source snapshot in `OMIX_MODULE_SOURCE.md`.
2. Add automated checksum and fixture-parity tests against the canonical
   source commit. The local candidate now includes this workflow at application
   commit `166b2b0496545555451cae7082e2dda9c3c8d572`; the initial local
   byte-for-byte export verification and same-runtime synthetic parity
   comparison are complete, but hosted CI cannot run until a remote repository
   exists.
3. Implement and test the exact `counts_tpm`/sample/pathway-catalog staging
   transformation, including live collection-value inventory and source-key
   mapping. Do not infer the live catalog labels from schema names.
4. Build a repository-owned `linux/amd64` OCI image and pass native container
   smoke tests with `/data` read-only and `/output` writable.
5. Run an approved representative data validation and compare the declared
   scientific outputs with canonical GSVA under the same explicit inputs.
6. Complete OncoChat request validation, Fargate staging/output collection,
   image-digest pinning, authorization, and negative-path acceptance tests.
7. Establish or explicitly approve an exception to the canonical module tag
   requirement before publishing a standalone `gsva-analysis` release.

None of these gates may be inferred from the older Code Ocean adapter. Its
recorded source reference is historical and its checkout is behind the current
canonical OMIX branch.
