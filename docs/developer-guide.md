# OMIX Developer Guide

This guide is the practical companion to the [module contract](module-contract.md).
Read both before adding a module, changing an existing module, or preparing a
release.

## One scientific source, platform-specific adapters

The OMIX monorepo is the canonical, platform-neutral home for reusable
scientific behavior. A module must run with explicit input and output paths so
the same implementation can be called from local R, Docker, HPC, or Galaxy.

Individual deployment repositories are adapters. They make canonical behavior
usable on a particular platform, but they are not a second source of
scientific truth and are not directory-for-directory copies of modules.

| Owns | Canonical OMIX module | Deployment adapter repository |
| --- | --- | --- |
| Scientific R functions | `R/` | Exported copy in `code/functions/` |
| Portable CLI | `scripts/` | No |
| Schemas and direct tests | `schemas/`, `tests/` | Link to the canonical contract |
| UI, metadata, runtime paths | No | Platform-owned configuration and entry point |
| Runtime setup | No | Platform-owned environment files |
| Shared reusable image definitions | `starter-environments/` | References a published image |

Do not add platform UI, metadata, environment, or runtime directories to a
module under `modules/`.

## Starting a change

1. Classify it before editing.
   - A scientific algorithm, reusable parameter, schema, or portable I/O
     change starts in the canonical module.
   - A platform UI label, mounted-input discovery rule, platform output
     behavior, or platform-only setup belongs in the adapter.
   - A dependency needed by multiple modules belongs in a shared starter
     environment, not in an unrelated module.
2. For canonical changes, update the implementation, schema, tests, README,
   and changelog as applicable.
3. When an adapter is added, moved, renamed, or retired, update the module's
   `deployment_adapters` metadata and README link, plus the adapter README and
   `OMIX_MODULE_SOURCE.md` link back to the canonical module.
4. Run module checks and the repository layout check.
5. Export only the released scientific function files to the adapter's
   scientific-function directory. Keep the adapter entry point as a small
   platform translation layer.
6. Test the adapter on its target platform when its workflow or runtime is affected.
   Backport any scientific fix discovered there to the canonical module before
   releasing it again.

## Optional ecosystem bridges

`core/` owns portable contracts such as counts-plus-metadata validation. It
does not import external data-object ecosystems. Optional bridge packages live
under `bridges/<ecosystem>/`; each is an independent R package that depends on
Core and its ecosystem, then converts the object to the portable contract.

Use a bridge when several modules benefit from a stable, documented conversion.
Do not put object extraction, platform paths, or a scientific policy such as
single-cell pseudobulk aggregation into Core without an explicit contract and
tests. A bridge is platform-neutral; its platform installation and UI remain
the responsibility of the separate deployment adapter.

## Inputs, outputs, and test data

- Portable module scripts accept explicit paths. They must not assume mounted
  input or output locations.
- The adapter may discover platform inputs and write platform outputs;
  document those rules in the adapter.
- Keep real data, generated results, credentials, and large package inventory
  artifacts out of Git. Use an ignored `data/debug/` fixture only for local
  reproducibility checks.
- A useful local adapter test recreates the target platform's input and output
  layout with disposable fixture and result directories.

## Environments and reproducibility

- Shared domain environments live in `starter-environments/` and are published
  as versioned OCI images. Use the version tag plus the resolved image digest
  from the publication workflow for every tested release; never use `latest`
  for a capsule, Docker, or HPC release.
- Declare a portable module-specific runtime overlay, when needed, in the
  module's `module.yml` with an explicit package version. The shared
  `restore-omix-runtime.R` helper applies it after restoring the selected
  profile lock. Platform-only setup remains in the adapter.
- Pin package versions in the environment lockfile. Record package provenance
  for packages installed from tarballs or other nonstandard sources.
- Rebuild and publish an image only after its lockfile and Dockerfile changes
  have passed CI. A Git sync alone does not update a capsule's already-built
  environment.

## Versioning and release records

Use [Versioning and releases](versioning-and-releases.md) as the authoritative
policy. In brief, each module carries two independent identities:

- `version` is a semantic version for the module's scientific behavior and
  portable capability.
- `interface_version` is a positive integer for the public input, parameter,
  output, and CLI contract.

Use a patch increment for a compatible bug fix, a minor increment for a
backward-compatible feature, and a major increment for a breaking contract or
a deliberate scientific-method/default change that can alter results. Increase
`interface_version` only when the public contract changes. Update the
changelog whenever a user-visible behavior changes.

An adapter release is separate from a module release. Its
`OMIX_MODULE_SOURCE.md` must state the canonical module version and exact
source ref that were exported, plus its own tag, platform validation, and
immutable runtime identity when available. Do not fill in unavailable values
with guesses: use a clearly marked pending state until validation is complete.

## Review and release checklist

Before requesting review or a release:

1. Run `Rscript tests/test-monorepo-layout.R` from the OMIX repository root.
2. Run the changed module's own tests and a representative command-line run.
3. Confirm that the canonical function and exported adapter function are
   intentionally identical when the scientific implementation is shared.
4. Confirm bidirectional adapter references: `module.yml` and the module README
   point to every supported adapter; the adapter README and
   `OMIX_MODULE_SOURCE.md` point to the canonical module.
5. Confirm that no generated outputs, debug data, tokens, or platform files
   were staged in the monorepo.
6. Update user documentation and the module changelog for externally visible
   behavior changes. Confirm the module and interface versions were updated
   according to the versioning policy.
7. For a platform release, synchronize the adapter, select the intended
   environment, run a platform validation, and then record the adapter tag,
   platform release identifier, and immutable runtime identity before
   publishing a release.

## How to use this guide

- **Contributors:** start here, then read the detailed
  [module contract](module-contract.md).
- **Reviewers:** use the review checklist to identify ownership drift.
- **AI coding assistants:** start with [`AGENTS.md`](../AGENTS.md), then read
  the [AI contributor guide](ai-contributor-guide.md). GitHub Copilot also
  reads the concise `.github/copilot-instructions.md` entry point.
- **Deployment-adapter authors:** follow the
  [deployment adapter guide](deployment-adapter-guide.md) and begin from its
  README, source-record, and agent-instruction templates.
