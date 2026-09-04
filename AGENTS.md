# OMIX Agent Instructions

These instructions apply to any AI coding assistant or automated contributor
working in this repository. They are a concise entry point, not a replacement
for the repository's detailed contracts.

## Read before changing code

1. [Developer guide](docs/developer-guide.md) — practical workflow and
   ownership boundaries.
2. [Module contract](docs/module-contract.md) — required module structure and
   the canonical-module versus deployment-adapter boundary.
3. [AI contributor guide](docs/ai-contributor-guide.md) — discovery,
   implementation, validation, and handoff procedure.
4. [Module README guide](docs/module-readme-guide.md) — required user-facing
   documentation structure.
5. [Deployment adapter guide](docs/deployment-adapter-guide.md) — required
   ownership, documentation, and release rules when an adapter is needed.

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

1. Inspect the affected module's `module.yml`, `schemas/interface.yml`, tests,
   README, and current Git state before editing.
2. Classify the request before changing files: canonical scientific behavior,
   bridge behavior, deployment translation, or shared runtime.
3. Preserve scientific defaults, input/output contracts, and documented legacy
   behavior. Do not refactor plotting aesthetics or statistical behavior merely
   for code style.
4. Do not commit generated outputs, debug data, credentials, package caches,
   or other large derived artifacts.
5. Run the affected tests and `Rscript tests/test-monorepo-layout.R` after a
   structural change. Report any validation that could not be run.
6. Make narrowly scoped changes and summarize files changed, validation run,
   and remaining external validation needed.

## Release discipline

- A deployment-only change remains in its deployment repository unless it
  changes scientific behavior or a reusable interface.
- Every deployment repository needs its own `AGENTS.md`, README, and
  `OMIX_MODULE_SOURCE.md`; the root instructions in this repository are not
  inherited by a separate checkout.
- Backport a reusable or scientific fix to the canonical module before
  treating it as released.
- Do not rebuild or publish a shared runtime unless its Dockerfile, lockfile,
  or runtime definition changed and the targeted validation has passed.
- Record module commit, lockfile/runtime identity, and input-data provenance
  for a reproducible scientific result.
