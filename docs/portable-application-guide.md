# Portable Application Guide

A portable application distribution makes one canonical OMIX module easy to
run as an OCI container or command-line tool in environments such as HPC and
OncoChat. It is a thin distribution layer, not a second scientific
implementation and not a Code Ocean adapter.

The canonical module remains responsible for its scientific functions,
explicit-path CLI, schemas, tests, defaults, and runtime-profile selection.
The portable repository packages that released contract with a pinned OMIX
shared runtime, a stable `/data` to `/output` invocation, fixtures, and
user-facing documentation.

## When to create a portable application

Create one when a module needs a self-contained container and a concise CLI
contract for direct HPC use or for a workflow orchestrator such as OncoChat.
Do not create one merely to duplicate a Code Ocean App Panel. A Code Ocean
adapter and a portable application may coexist when they translate the same
canonical module for different environments.

Before bootstrap, confirm the module has reviewed `R/`, `scripts/`,
`schemas/interface.yml`, `module.yml`, direct tests, README, and changelog.
Choose the module's declared shared runtime profile; do not silently rebuild a
different scientific environment.

## Ownership boundary

| Responsibility | Canonical OMIX module | Portable application repository |
| --- | --- | --- |
| Scientific functions, defaults, schemas, and tests | Owns | References a pinned release only |
| Explicit-path scientific CLI | Owns | Invokes or wraps without changing semantics |
| Shared runtime profile | Owns | Pins an immutable OCI image digest |
| `/data` and `/output` container translation | Never | Owns |
| Request-file validation and safe parameter allowlist | Never | Owns |
| PostgreSQL access and authorization | Never | OncoChat owns outside the image |
| HPC command examples and OCI/Singularity guidance | References | Owns |

If application testing identifies a scientific or reusable-interface defect,
fix and validate it in the canonical module before updating the distribution.

## Standard invocation contract

Every portable application uses the same mount boundary:

```text
/data     read-only input directory supplied by a person, HPC job, or OncoChat
/output   writable directory for all generated artifacts
```

The application accepts only paths beneath `/data` and writes only beneath
`/output`. A `request.json` may provide a structured, allowlisted expression
of canonical parameters. It must never contain database credentials, mounted
host paths, shell fragments, or arbitrary executable commands.

Each run writes at least:

```text
/output/run_manifest.json   resolved parameters, source commit, image digest, input checksums
/output/results/            machine-readable primary results
/output/plots/              declared visual artifacts, when applicable
/output/qc/                 declared diagnostics, when applicable
/output/logs/               command and stderr/stdout capture
/output/sessionInfo.txt     R and package provenance
```

## Repository scaffold

Start from `templates/portable-application/`. Do not copy a Code Ocean
adapter directory or its `.codeocean/` files. The scaffold is intentionally
similar to the public multi-gene-correlation and survival applications:

```text
<application>/
├── .github/workflows/       # native smoke test and non-publishing multi-arch build
├── container/               # Dockerfile, entrypoint, build/run/smoke helpers
├── docs/                    # integration and contract notes
├── src/                     # pinned canonical export and thin CLI wrapper
├── test_data/               # small public, redistributable fixture only
├── tests/                   # contract and expected-artifact checks
├── AGENTS.md
├── CHANGELOG.md
├── OMIX_MODULE_SOURCE.md    # commit, module/interface version, file hashes, runtime digest
├── README.md
└── .gitignore
```

## Bootstrap sequence

1. Select a capability-based repository name, such as
   `differential-expression-analysis`, not the name of an existing Code Ocean
   adapter.
2. Record the canonical module, module version, interface version, immutable
   commit, complete exported-file map, and SHA-256 values in
   `OMIX_MODULE_SOURCE.md`.
3. Pin the appropriate published `ghcr.io/nidap-community/omix-r-*` image by
   digest. A mutable tag is not a release identity.
4. Copy the complete released scientific export without editing it. Keep the
   distribution wrapper separate from that export.
5. Implement a thin entrypoint that validates the request and maps `/data`
   and `/output` to the canonical explicit-path CLI.
6. Add a small fixture, expected primary results, and artifact assertions.
7. Run local CLI and container smoke tests, then native and ARM64 CI builds.
   CI build evidence is not image publication.
8. Give OncoChat the image digest, request schema, input staging rules, and
   artifact manifest. OncoChat owns PostgreSQL queries, cohort authorization,
   and result presentation.
9. Publish or tag only after a separate version decision and validation.

## Reuse across modules

The scaffold is generic. Module-specific information belongs in the source
record and request schema: selected runtime profile, permitted input tables,
canonical parameters, expected outputs, and fixture. This permits the same
workflow for heatmaps, GSVA, gene boxplots, differential expression, limma,
volcano plots, and L2P without making their scientific methods converge.
