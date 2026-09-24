# Pathway data export contract

This contract defines a one-way, immutable export from an authoritative pathway
catalog into a portable artifact for local workstations, HPC, Code Ocean, and
on-premises deployments. The source database remains authoritative. Consumers
must not write changes back through this format.

The contract is intended to represent the existing `pw_genesets` and
`pw_genes` concepts without exporting the rest of a genomics database. It also
allows separately licensed resources and user-defined gene sets to be composed
at runtime without treating any one deployment as a second source of truth.

## Non-goals and licensing boundary

- This specification does not authorize redistribution of any source data.
- **Do not commit, publish, attach to a public release, or place in a public
  container any MSigDB membership data.** MSigDB is a separately licensed
  source. A deployment may use a separately provisioned MSigDB artifact only
  when its users and distribution channel are authorized by the applicable
  license.
- An `unknown`, `restricted`, or `prohibited` redistribution status fails
  closed for a public export. Metadata may identify an omitted source, but its
  gene sets and memberships must not be included.
- The format does not prescribe how the authoritative catalog is curated, how
  identifiers are mapped, or how pathway statistics are calculated.

## Versioning

The manifest's `schema_version` versions this contract. It uses semantic
versioning:

- patch: clarification or an optional backward-compatible field;
- minor: a backward-compatible new field or table; and
- major: removal, rename, type change, or a changed uniqueness/foreign-key
  rule.

`export_version` versions the catalog snapshot and is independent of
`schema_version`. An `(export_id, export_version)` pair is immutable. Rebuilding
the same source selection produces a new export version unless the bytes are
identical. Published files and tags must never be overwritten.

Each consumer records the artifact SHA-256, not merely a mutable filename or
download URL.

## Artifact layout

An unpacked artifact has this layout:

```text
omix-pathways-<export-id>-<export-version>/
|-- manifest.json
|-- genesets.tsv
|-- memberships.tsv
|-- NOTICE.md
`-- CHECKSUMS.sha256
```

The distributable archive is named
`omix-pathways-<export-id>-<export-version>-<digest12>.tar.gz`, where
`digest12` is the first 12 hexadecimal characters of the archive SHA-256. A
sidecar `<archive>.sha256` contains the complete archive checksum.

`manifest.json` follows
[`pathway-export-manifest.schema.json`](schemas/pathway-export-manifest.schema.json).
Its `files` entries contain the SHA-256 and data-row count for each payload
file. `CHECKSUMS.sha256` covers `manifest.json`, both tables, and `NOTICE.md`;
it does not list itself. `NOTICE.md` summarizes source attribution and
license restrictions without replacing the source licenses.

Files are UTF-8 with Unix newlines. TSV headers and field order are fixed for
schema major version 1. Fields must not contain literal tabs or newlines.
Missing optional text is an empty field, never the strings `NA` or `NULL`.

## `genesets.tsv`

One row describes one gene set in one source release and organism. Required
columns, in order, are:

| Column | Type | Contract |
| --- | --- | --- |
| `geneset_id` | string | Globally unique, stable, namespaced key such as `reactome:R-HSA-199420`; primary key. |
| `source_id` | string | Foreign key to `manifest.json` `sources[].source_id`. |
| `geneset_type` | string | Catalog classification such as `standard` or `custom`; values come from the exporter's controlled registry. |
| `source_accession` | string | Upstream accession; empty only when the source supplies none. |
| `collection_id` | string | Stable machine selector for the source collection. |
| `collection_name` | string | Human-readable collection label; this is the legacy `collection` value. |
| `name` | string | Human-readable gene-set name; this is the legacy `gene_set_name` value. |
| `description` | string | Source description or an empty field. |
| `source_record_url` | URI or empty | Direct provenance link for the upstream record. |
| `organism_tax_id` | positive integer | NCBI Taxonomy identifier, for example `9606`. |
| `organism_name` | string | Scientific name, for example `Homo sapiens`. |
| `member_namespace` | string | Namespace of all members, for example `HGNC_SYMBOL`, `MGI_SYMBOL`, or `NCBI_GENE_ID`. |

The tuple `(source_id, source_accession, organism_tax_id)` must be unique when
`source_accession` is present. Names are display labels and are not keys.
Different collections may legitimately contain the same `name`.

### Mapping the current IODC tables

The existing IODC tables can remain normalized at rest. The exporter joins
`pw_genesets` to `pw_genes` by their shared `category,accession` key and maps:

| IODC source | Export field |
| --- | --- |
| `pw_genesets.category` | `collection_id`; a controlled registry supplies `collection_name` |
| `pw_genesets.accession` | `source_accession` and the source-specific portion of `geneset_id` |
| `pw_genesets.name` | `name` |
| `pw_genesets.description` | `description` |
| `pw_genesets.url` | `source_record_url` |
| `pw_genesets.type` | `geneset_type` |
| `pw_genes.gene` | `member_id` |

Source release, retrieval time, license, redistribution status, organism, and
identifier namespace are required export metadata even if the current tables
do not contain them. They must come from an explicit source registry or export
request; the exporter must not infer them from gene spelling or filenames.

## `memberships.tsv`

One row represents one gene-set membership. Required columns, in order, are:

| Column | Type | Contract |
| --- | --- | --- |
| `geneset_id` | string | Foreign key to `genesets.tsv`. |
| `member_id` | string | Gene identifier exactly in the parent set's `member_namespace`. |

The tuple `(geneset_id, member_id)` is the primary key. Duplicate memberships
are invalid. Every gene set must have at least one membership. The export must
not silently translate namespaces; an identifier mapping is a separately
versioned transformation with its own provenance.

## Manifest provenance and licensing

The manifest records:

- the schema, export identity, creation time, content profile, and generator;
- the authoritative system and immutable source snapshot;
- every included or intentionally omitted source release;
- source retrieval time, origin URL, license name/URL, redistribution status,
  and notes;
- table paths, row counts, media types, and SHA-256 checksums; and
- the organism tax IDs and identifier namespaces present in the artifact.

`content_profile` is one of:

- `open`: contains only sources explicitly cleared for redistribution;
- `restricted-site`: produced for a controlled site under applicable source
  terms and never published as an OMIX release; or
- `custom`: contains user-owned gene sets with provenance supplied by that
  user.

For an open artifact, every included source must have `redistribution` equal
to `allowed`. An MSigDB source should normally appear as `included: false`,
`redistribution: restricted`, with a note that authorized users must obtain it
through the approved channel. A controlled export is still subject to the
actual license; naming it `restricted-site` does not grant rights.

## Exporter requirements

An exporter performs these steps in one direction only:

1. Read a transactionally consistent, read-only snapshot of the authoritative
   catalog.
2. Resolve the requested source releases and content profile.
3. Apply a fail-closed license policy before writing any membership rows.
4. Validate primary keys, foreign keys, non-empty memberships, taxonomy IDs,
   and namespace homogeneity.
5. Sort `genesets.tsv` by `geneset_id` and `memberships.tsv` by
   `geneset_id,member_id`; output must be deterministic.
6. Write payloads to a new versioned directory, calculate checksums, validate
   the manifest, and make the completed artifact read-only.
7. Publish only the archive and checksum approved for the target channel.

The exporter must never accept credentials in the manifest or artifact. A
database URL, token, or cloud secret stays in the exporting environment.

## Composition of multiple artifacts

Tools may combine an open artifact, an authorized separately delivered MSigDB
artifact, and a custom artifact at runtime. Composition is valid only when:

- schema major versions match;
- every artifact passes checksum and structural validation;
- `geneset_id` values are unique across artifacts, or byte-identical records
  from the same source release are explicitly deduplicated;
- source metadata with the same `source_id` agree;
- the requested organism and member namespace are compatible with the input
  expression or gene list, or an explicit versioned mapping is applied; and
- the analysis records every contributing artifact SHA-256.

Collisions or ambiguous display names are errors, not last-write-wins merges.

## Consumer contract for L2P, GSEA, and GSVA

Consumers verify the manifest, payload checksums, schema major version,
requested source/collection, organism, and namespace before analysis. They
must record `export_id`, `export_version`, payload checksums, selected source
releases, collections, organism, namespace, and any identifier-mapping
provenance in the run summary.

For the current GSEA and GSVA module interfaces, a loader derives a long table
without changing the artifact:

| Derived column | Source |
| --- | --- |
| `pathways_database` | `source_id` plus the manifest source version |
| `collection` | `collection_name` |
| `gene_set_id` | `geneset_id` |
| `gene_set_name` | `name` |
| `gene_symbol` | `member_id`, only when the namespace is a declared gene-symbol namespace |
| `species` | deterministic OMIX label derived from `organism_tax_id` |

The extra `gene_set_id` column should be retained even when a legacy function
ignores it. A legacy analysis that requires unique `gene_set_name` values must
fail with a clear collision message rather than rewrite names. New interfaces
should select and join by `gene_set_id`.

For L2P custom pathways, a loader derives the package's named-list input from
the same filtered rows and retains a sidecar mapping from list name to
`geneset_id`, display name, source, and collection. L2P's package-bundled
collections are not evidence that the export artifact was used; run
provenance must distinguish bundled and exported sources.

All three consumers apply analysis-specific size filters *after* artifact
validation and record those thresholds separately. An export contains source
memberships, not analysis-filtered memberships.

## Deployment delivery

- **Local/HPC:** place the unpacked versioned directory in read-only shared
  storage or a content-addressed cache and pass its explicit path.
- **Code Ocean:** attach an immutable Data Asset approved for the deployment.
  The capsule adapter discovers or receives its explicit path; the canonical
  module remains path-driven. A restricted MSigDB asset is managed separately
  and is not part of the public capsule repository or image.
- **On-premises:** mirror approved archives and checksums in an internal
  artifact store. Preserve the original bytes and verify at ingestion and use.
- **Containers:** images may contain the loader and schema, but not changing
  pathway data. Embedding a specific open artifact requires its immutable
  digest and license notice; embedding restricted content is prohibited unless
  separately authorized.

The synthetic example under
[`docs/examples/pathway-data-export/v1`](examples/pathway-data-export/v1)
demonstrates the structure without using real pathway or MSigDB content.

## Decisions required before implementation

This contract is implementable, but it does not select operational policy for:

1. the immutable snapshot identifier and transaction mechanism exposed by the
   authoritative IODC database;
2. the reviewed source registry values for versions, taxonomy, namespaces,
   collection display labels, and redistribution status;
3. the authorized delivery and access-control process for a separately
   obtained MSigDB artifact;
4. the internal artifact store, retention policy, and approval authority for
   open versus restricted-site exports; and
5. whether the shared validator/long-table loader is implemented as a small
   OMIX package or repeated temporarily in individual pathway modules.

Until those decisions are approved, this repository should contain only the
schema, synthetic fixture, tests, and consumer design—not a real database dump
or an automated publication workflow.
