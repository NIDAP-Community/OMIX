# Standalone Application Repository Contract

This contract defines how to derive a portable, independently versioned
application repository from an OMIX module for use by OncoChat, command-line
users, and HPC/container runtimes. It is a companion to the
[module contract](module-contract.md),
[deployment adapter guide](deployment-adapter-guide.md),
[runtime guide](runtime-guide.md), and
[versioning and release policy](versioning-and-releases.md).

It does **not** turn the OMIX monorepo into a collection of copied projects.
OMIX remains the canonical owner of scientific methods, module interfaces,
schemas, and regression tests. The derived repository is a portable
application component that packages one approved module interface behind a
stable CLI and OCI runtime.

## Intended repository set

| Application repository | Canonical OMIX module | Primary application role | Initial data profile |
| --- | --- | --- | --- |
| `expression-heatmap` | `OMIX-Expression-Heatmap` | Render annotated expression heatmaps | Normalized continuous matrix plus sample metadata |
| `gsva-analysis` | `OMIX-GSVA` | Compute sample-level pathway scores | Normalized continuous matrix, sample metadata, approved gene-set catalog |
| `gene-boxplots` | `OMIX-Gene-Boxplots` | Plot selected genes across declared groups | Normalized continuous matrix plus sample metadata |
| `l2p-single-pathway-analysis` | `OMIX-L2P-Single` | Run one DEG-table pathway over-representation analysis | Validated DEG-table artifact |
| `differential-expression-analysis` | `OMIX-DEG-Analysis` | Generate differential-expression tables from declared groups | Raw-count matrix plus sample metadata |
| `limma-analysis` | `OMIX-Limma-Analysis` | Fit declared Limma models | Normalized continuous matrix plus sample metadata |
| `volcano-plot` | `OMIX-Volcano-Plot` | Visualize a declared DEG result | Validated DEG-table artifact |

`differential-expression-analysis` is deliberately distinct from the existing
`OMIX-DEG-Analysis` Code Ocean adapter repository. A Code Ocean adapter is not
the source, name, runtime, or release record for this portable application
component.

The table is a planning map, not a readiness claim. Each module must pass the
preflight gates below before a repository is created or advertised.

## Ownership and boundaries

| Concern | Canonical OMIX module | Standalone application repository | OncoChat |
| --- | --- | --- | --- |
| Scientific algorithms and defaults | Owns | Uses a pinned approved export; does not fork behavior | Does not own |
| Public scientific input/output schema | Owns | Implements and documents the selected schema version | Validates user requests against it |
| CLI and container interface | Defines portable scientific arguments | Provides one stable root CLI and container entrypoint | Translates approved request fields into CLI arguments |
| Database access, authorization, IAM, job lifecycle | Never | Never | Owns |
| Data materialization | Never | Reads only staged files under `/data` | Materializes approved database data into a job workspace |
| Result storage and presentation | Writes declared artifacts | Writes a complete run bundle to `/output` | Collects, retains, and presents artifacts |
| OCI build and release | Supplies reusable runtime-profile evidence | Owns application image, labels, CI, and release record | Pins and launches an image digest |

No repository may silently change a scientific default, normalize data in an
undocumented way, or introduce platform-specific behavior into the canonical
OMIX module. A discovered scientific or reusable-interface defect is fixed,
tested, and versioned in OMIX first.

## Input and workflow rule

OncoChat's only external study-data source for this family is an approved
tabular raw-count matrix and aligned sample metadata materialized from its
database. A user does not upload arbitrary local matrices or choose host paths.

Some modules require a normalized matrix or a DEG table rather than raw counts.
Those are **workflow artifacts**, not additional external data sources:

1. OncoChat materializes the approved raw counts and metadata into the job's
   read-only `/data` directory.
2. A declared, versioned preprocessing or analysis component produces a
   normalized matrix or DEG table with a documented schema.
3. A downstream component consumes only that validated artifact, its aligned
   metadata when required, and an approved parameter request.

For example, `volcano-plot` and `l2p-single-pathway-analysis` consume the
output of `differential-expression-analysis`; they must not recreate a DEG
calculation from a plotting request. Similarly, a module requiring continuous
expression must receive a named preprocessing artifact rather than silently
applying a normalization rule. Approved gene-set catalogs are image- or
repository-versioned assets selected by a bounded identifier, not arbitrary
user-supplied files.

Every cross-component artifact must have a schema identifier, producing source
commit, input checksums, parameter record, and a compatibility check at the
consumer boundary.

## Required repository shape

Each derived repository must contain, at minimum:

```text
<application-repository>/
|-- README.md
|-- LICENSE
|-- CHANGELOG.md
|-- OMIX_MODULE_SOURCE.md
|-- entrypoint.R                 # one stable, noninteractive root CLI
|-- src/                         # repository-owned CLI/orchestration utilities
|-- scripts/                     # local convenience wrappers only
|-- schemas/                     # request, input, output, and artifact schemas
|-- test_data/                   # small synthetic or redistributable fixtures
|-- tests/                       # interface, regression, and container checks
|-- container/
|   |-- Dockerfile
|   |-- README.md
|   |-- build_docker.sh
|   |-- run_docker.sh
|   |-- run_apptainer.sh
|   `-- smoke_test.sh
|-- docs/
|   |-- architecture.md
|   |-- container_contract.md
|   |-- oncochat_adapter_contract.md
|   |-- decision_log.md
|   |-- session_notes.md
|   `-- releases/
|-- renv.lock                    # or an equally explicit, reviewed R lockfile
`-- .github/workflows/container.yml
```

`README.md` is for a scientist or operator running the component. It must show
the published digest, local/container quick start, input table expectations,
bounded parameters, result tree, representative figures or tables when safe,
and troubleshooting. Detailed developer and application contracts belong in
`docs/`, not in a historical README narrative.

`OMIX_MODULE_SOURCE.md` is mandatory. It records the canonical module path,
module and interface versions, immutable OMIX commit, canonical tag when
available, exported scientific-file checksums, runtime profile, application
repository commit, and the image digest used for each validated release.

## Canonical source and parity requirements

Before copying or exporting code, record a source snapshot containing:

- canonical module name, `module.yml` version, and `interface_version`;
- full immutable OMIX commit and approved canonical tag, if one exists;
- selected module schema and CLI contract version;
- runtime profile and any module overlay requirements; and
- a file inventory with SHA-256 checksums for every exported scientific file.

Use the reviewed Syncweaver export path when available. Otherwise, make the
one-time import explicit, checksum it, and establish a follow-up synchronization
method before release. The standalone repository may add an entrypoint,
container, documentation, tests, result packaging, and application-specific
parameter translation. It may not hand-edit the exported scientific functions.

Parity evidence must show that the same fixture and explicit parameters give
equivalent scientific tables and declared figures in OMIX and in the standalone
repository. A matching exit code alone is insufficient.

## CLI and container contract

Every component is a Container-as-a-Function:

- one noninteractive root command, such as `Rscript entrypoint.R <workflow>`;
- explicit, schema-validated flags rather than arbitrary shell arguments;
- read-only `/data` for staged inputs and writable `/output` for one job's
  complete result bundle;
- no database credentials, cloud credentials, study data, or user-specific
  paths baked into the image;
- non-root default execution; and
- no runtime package installation or network dependency.

The container must be a repo-owned OCI image at
`ghcr.io/nidap-community/<application-repository>`. It may use an existing
OMIX runtime image as a **pinned base image** only after validating that the
runtime profile and overlay match the canonical source snapshot. Do not simply
retag an OMIX environment image: the derived image must also contain the
application entrypoint, pinned scientific export, documentation, and smoke
fixture needed for its own interface.

Build for `linux/amd64`, emit OCI source/revision/creation labels, and expose
the source revision to run-provenance code. Apple Silicon development may use
emulation but does not create an ARM64 production release unless separately
approved. Support an Apptainer/Singularity conversion path, but treat a target
HPC smoke test as required evidence rather than assuming OCI compatibility is
sufficient.

## Request validation and result bundle

The standalone CLI validates file schemas, declared identifiers, enum values,
numeric bounds, and output paths before analysis begins. OncoChat performs an
additional request-validation layer before staging data; it never forwards a
user-provided shell fragment or host path.

Each completed job writes a self-contained result bundle under `/output/<job>`
containing at least:

```text
RUN_METADATA.md
run_manifest.csv or run_manifest.json
logs/sessionInfo.txt
tables/                         # primary rectangular results and mappings
figures/                        # when the component produces figures
artifacts/                      # schema-identified handoff files, when applicable
```

`RUN_METADATA.md` records the standalone repository revision, canonical OMIX
source record, application interface/schema versions, image revision supplied
at build time, input artifact identities and checksums, declared parameters,
runtime package/lockfile identity, timestamps, and terminal status. The
OncoChat job record separately retains the resolved OCI digest because a
container cannot reliably discover the digest by which it was launched.

All user-visible outputs require an interpretation disclaimer appropriate to
the module. Outputs are exploratory research analyses, not clinical decision
support.

## Validation gates

Do not declare a component OncoChat-ready until all applicable gates have
passed against the exact source and image revisions being considered.

| Gate | Required evidence |
| --- | --- |
| 0. Module preflight | Canonical module status is `review` or `active`, interface/schema are defined, source snapshot is recorded, and intended input profile is compatible with the OncoChat workflow. A `development` module needs an explicit exception. |
| 1. Canonical parity | Export checksums match; representative fixtures and parameters produce equivalent scientific outputs between OMIX and the standalone repository. |
| 2. Local CLI | `--help`, malformed-input rejection, schema validation, and a complete synthetic fixture run succeed without undeclared global state. |
| 3. Container | A fresh `linux/amd64` build and canonical smoke test succeed; `/data` is read-only, `/output` is writable, and required provenance/artifacts exist. |
| 4. Representative study validation | An approved non-sensitive fixture or authorized study validation reproduces pre-specified reference outputs within agreed tolerances. |
| 5. OncoChat integration | The application validates requests, stages only approved database-derived artifacts, pins an image digest, rejects traversal/unsupported choices, collects the complete result bundle, and records job provenance. |
| 6. Workflow handoff | Any downstream component accepts the declared artifact schema and rejects incompatible or incomplete upstream artifacts. |
| 7. Release | Versions, changelog, source record, tests, immutable image digest, access policy, and explicit human publication approval are recorded. |

Successful local tests, a built image, or an existing OMIX/Code Ocean container
are evidence for only their respective gates. They do not establish OncoChat
integration, release status, or cross-component compatibility.

## Release and operations policy

CI builds and smoke-tests candidate images but does not publish them. Registry
publication, semantic version/tag selection, public/private visibility, image
retention, signing/attestation policy, and production enablement require
separate explicit decisions and approvals.

OncoChat must launch the resolved immutable digest, not `latest` or any mutable
tag. Record readable tags for discovery, but use the digest in jobs, deployment
configuration, acceptance evidence, and user-support triage. The registry
access policy must permit the OncoChat runtime identity to pull the package
without exposing the package more broadly than intended.

## Derivation workflow

1. **Assess:** identify the canonical module, source snapshot, readiness
   status, required runtime profile, input profile, and downstream artifact
   relationships.
2. **Create:** initialize the repository from this required shape; add the
   source record, root CLI, schemas, synthetic fixture, and minimal docs.
3. **Import/export:** bring in the verified scientific implementation and
   establish checksum-based parity protection.
4. **Package:** build the repository-owned linux/amd64 OCI image, container
   helpers, and CI smoke test.
5. **Validate:** complete gates 1 through 4 before claiming component
   readiness; retain exact commands and artifacts.
6. **Integrate:** define the OncoChat request translation, approved database
   staging, artifact collection, digest pinning, authorization, and workflow
   handoff checks.
7. **Release:** only after explicit authorization, publish the image, record
   its digest, and create tags/releases under the OMIX release policy.

## Prohibited shortcuts

- Do not copy a Code Ocean adapter and rename it as the standalone repository.
- Do not edit copied OMIX scientific code only in the standalone repository.
- Do not treat a pre-existing OMIX GHCR environment image as the finished
  application image without a repo-owned entrypoint and validation.
- Do not accept arbitrary uploads, local paths, unbounded free-text flags, or
  credentials from users.
- Do not silently alter normalization, filtering, gene-set selection, or
  statistical defaults between components.
- Do not publish `latest` as the deployment reference, infer image digests,
  or claim a platform release from a local/container test.
- Do not release a `development` module without an explicit exception and
  documented validation scope.

## Per-repository initialization record

Create this short record before implementation for every row in the intended
repository set:

```text
Application repository:
Canonical OMIX module:
Canonical module version / interface version:
OMIX source commit and canonical tag:
Module readiness status and preflight decision:
Scientific export method and checksum manifest:
Runtime profile / pinned base image digest / overlay:
External database-derived input profile:
Upstream workflow artifacts accepted:
Downstream artifacts produced:
OncoChat request fields and allowed values:
Synthetic fixture and representative-validation plan:
Image repository, tag policy, and target platform:
Release owner and explicit approval record:
Open exceptions or deferred gates:
```

Populate this record before creating a repository. It makes each derivation
reviewable without presuming that every OMIX module, existing adapter, or
published runtime has the same readiness level.

Current derivation records are stored under [docs/derivations/](derivations/).
