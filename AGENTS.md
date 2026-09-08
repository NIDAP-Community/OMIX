# OMIX Agent Instructions

These instructions apply to any AI coding assistant or automated contributor.
They are a routing page and hard-rule summary, not a second contributor guide.

## Read before changing code

1. [Module contract](docs/module-contract.md) — required architecture and the
   canonical-module versus deployment-adapter boundary.
2. [Contributor guide](docs/contributor-guide.md) — discovery, implementation,
   README writing, validation, and handoff.
3. Add the [deployment adapter guide](docs/deployment-adapter-guide.md) only
   for adapter work, the [runtime guide](docs/runtime-guide.md) only for
   environment or reproducibility work, and
   [versioning and releases](docs/versioning-and-releases.md) only for release
   work.
4. An automated release additionally requires the
   [release automation contract](docs/release-automation-contract.md).

If these documents appear to conflict, preserve the module contract and report
the ambiguity rather than silently choosing a new architecture.

## Required boundaries

- `modules/<name>/` is portable scientific code. It must use explicit input
  and output paths and must not contain deployment UI, mounted-path discovery,
  environment setup, or generated results.
- Put reusable scientific functions in `R/` and the portable CLI in `scripts/`.
  Keep the matching schema, tests, README, and changelog current.
- Keep deployment translation in its separate repository. The canonical module
  remains the source of truth for scientific behavior and reusable interfaces.
- Use `bridges/<ecosystem>/` only for stable, portable external-object
  conversion. Do not add ecosystem-specific extraction to Core by default.
- Add a dependency shared by multiple modules to the appropriate
  `starter-environments/` runtime profile; keep one-module dependencies local
  to that module or its deployment overlay.

## Working rules

1. Inspect the affected module's `module.yml`, schema, tests, README, and Git
   state before editing; preserve unrelated changes.
2. Classify the request as canonical behavior, bridge behavior, deployment
   translation, or shared runtime before changing files.
3. Preserve scientific defaults, input/output contracts, legacy behavior, and
   established plot aesthetics. Do not refactor them merely for code style.
4. Do not commit generated outputs, debug data, credentials, package caches,
   or other large derived artifacts.
5. Run the affected tests and `Rscript tests/test-monorepo-layout.R` after a
   structural change. Report every validation not run.
6. Make narrowly scoped changes and summarize changed files, validation, and
   remaining external work.

## Release discipline

- A deployment-only change remains in its deployment repository unless it
  changes scientific behavior or a reusable interface.
- Every deployment repository needs its own `AGENTS.md`, README, and
  `OMIX_MODULE_SOURCE.md`; the root instructions in this repository are not
  inherited by a separate checkout.
- Backport a reusable or scientific fix to the canonical module before
  treating it as released.
- Keep `module.yml`'s semantic `version` and integer `interface_version`
  current. Update the changelog for every externally visible change; use the
  versioning guide to decide whether the change is patch, minor, or major.
- Do not create a Git tag, platform release record, or immutable runtime claim
  until its corresponding validation has completed. Record pending fields
  honestly in an adapter's `OMIX_MODULE_SOURCE.md`.
- An automated release workflow must follow the release automation contract.
  It may not infer a scientific version bump, alter a Git tag, or finalize a
  release without the required structured request, evidence, and approval.
- Do not rebuild or publish a shared runtime unless its Dockerfile, lockfile,
  or runtime definition changed and the targeted validation has passed.
- Record module commit, lockfile/runtime identity, and input-data provenance
  for a reproducible scientific result.
