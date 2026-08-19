# OMIX Copilot Instructions

Read `docs/developer-guide.md` and `docs/module-contract.md` before changing
OMIX architecture or module code.

## Required boundaries

- `modules/<name>/` is platform-neutral. Never add `.codeocean/`, `metadata/`,
  `environment/`, or a Code Ocean `code/` runtime directory there.
- Put reusable scientific R functions in a module's `R/`; use `scripts/` for
  an explicit-path CLI. Do not assume `/data` or `/results` in a module.
- Keep Code Ocean-specific App Panel metadata, workflow discovery, `/data` and
  `/results` paths, `code/main.R`, `code/run`, and capsule setup in the
  separate adapter repository.
- Treat an adapter as a deployment layer, not a directory mirror. Export only
  the released scientific function files to `code/functions/`.
- Record each supported adapter in the canonical module's
  `deployment_adapters` metadata and README. Keep the adapter README and
  `OMIX_MODULE_SOURCE.md` linked back to that canonical module.
- Place shared, reusable container definitions in `starter-environments/`.
  Pin dependencies and preserve nonstandard package provenance.

## When editing

1. Identify whether the request is scientific/module behavior, a Code Ocean
   adapter behavior, or a shared-environment change.
2. Update the implementation, schema, tests, documentation, and changelog in
   the owning location.
3. Run `Rscript tests/test-monorepo-layout.R` after structural changes.
4. Do not add generated outputs, debug data, package inventories, or secrets
   to Git.

If a change begins in Code Ocean but affects scientific behavior or a reusable
interface, make the canonical module the final source of truth and then export
the release back to the adapter.
