# OMIX Developer Guide

This guide is the practical companion to the [module contract](module-contract.md).
Read both before adding a module, changing an existing module, or preparing a
Code Ocean capsule release.

## One scientific source, platform-specific adapters

The OMIX monorepo is the canonical, platform-neutral home for reusable
scientific behavior. A module must run with explicit input and output paths so
the same implementation can be called from Docker, HPC, Galaxy, or a Code
Ocean capsule.

Individual capsule repositories are deployment adapters. They make the
canonical behavior usable in Code Ocean, but they are not a second source of
scientific truth and are not directory-for-directory copies of modules.

| Owns | Canonical OMIX module | Code Ocean adapter repository |
| --- | --- | --- |
| Scientific R functions | `R/` | Exported copy in `code/functions/` |
| Portable CLI | `scripts/` | No |
| Schemas and direct tests | `schemas/`, `tests/` | Link to the canonical contract |
| App Panel, capsule metadata, runtime paths | No | `.codeocean/`, `metadata/`, `code/main.R`, `code/run` |
| Capsule setup | No | `environment/` |
| Shared reusable image definitions | `starter-environments/` | References a published image |

Do not add `.codeocean/`, `metadata/`, `environment/`, or a Code Ocean
`code/` runtime directory to a module under `modules/`.

## Starting a change

1. Classify it before editing.
   - A scientific algorithm, reusable parameter, schema, or portable I/O
     change starts in the canonical module.
   - An App Panel label, capsule input discovery rule, `/data` or `/results`
     behavior, or capsule-only setup belongs in the adapter.
   - A dependency needed by multiple modules belongs in a shared starter
     environment, not in an unrelated module.
2. For canonical changes, update the implementation, schema, tests, README,
   and changelog as applicable.
3. Run module checks and the repository layout check.
4. Export only the released scientific function files to the adapter's
   `code/functions/` directory. Keep the adapter's `code/main.R` as its small
   Code Ocean translation layer.
5. Test the adapter in Code Ocean when its workflow or runtime is affected.
   Backport any scientific fix discovered there to the canonical module before
   releasing it again.

## Inputs, outputs, and test data

- Portable module scripts accept explicit paths. They must not assume Code
  Ocean mounts such as `/data` or `/results`.
- The adapter may discover workflow inputs below `/data` and write to
  `/results`; document those rules in the adapter.
- Keep real data, generated results, credentials, and large package inventory
  artifacts out of Git. Use an ignored `data/debug/` fixture only for local
  reproducibility checks.
- A useful local adapter test recreates the downstream Code Ocean mount shape:
  mount a fixture at `/data`, mount a disposable output directory at
  `/results`, and run the adapter's `code/run`.

## Environments and reproducibility

- Shared domain environments live in `starter-environments/` and are published
  as versioned OCI images. Prefer an immutable commit tag for a tested release;
  reserve `latest` for convenience.
- Module-specific overlays or Code Ocean-only setup remain in the adapter.
- Pin package versions in the environment lockfile. Record package provenance
  for packages installed from tarballs or other nonstandard sources.
- Rebuild and publish an image only after its lockfile and Dockerfile changes
  have passed CI. A Git sync alone does not update a capsule's already-built
  environment.

## Review and release checklist

Before requesting review or a release:

1. Run `Rscript tests/test-monorepo-layout.R` from the OMIX repository root.
2. Run the changed module's own tests and a representative command-line run.
3. Confirm that the canonical function and exported adapter function are
   intentionally identical when the scientific implementation is shared.
4. Confirm that no generated outputs, debug data, tokens, or platform files
   were staged in the monorepo.
5. Update user documentation and the module changelog for externally visible
   behavior changes.
6. For a Code Ocean release, sync the adapter, rebuild/select the intended
   environment, and run a capsule validation before publishing a release.

## How to use this guide

- **Contributors:** start here, then read the detailed
  [module contract](module-contract.md).
- **Reviewers:** use the review checklist to identify ownership drift.
- **AI coding assistants:** follow `.github/copilot-instructions.md`; it is a
  concise, enforceable version of this guide.
