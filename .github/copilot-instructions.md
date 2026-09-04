# OMIX Copilot Instructions

Follow the repository-wide [AGENTS.md](../AGENTS.md) before changing OMIX.
For detailed workflow, read [the AI contributor guide](../docs/ai-contributor-guide.md)
and the [module contract](../docs/module-contract.md).

## Copilot essentials

- Classify the request as canonical scientific behavior, an optional bridge,
  deployment translation, or a shared runtime before editing.
- Keep `modules/<name>/` platform-neutral with explicit input and output paths.
  Do not assume mounted input or output directories in a canonical module.
- Update the owning implementation, schema, tests, README, and changelog
  together when a public scientific interface changes.
- Preserve documented statistical defaults, legacy output contracts, and
  established plotting behavior unless the request explicitly changes them.
- Do not add generated outputs, debug data, package caches, or secrets to Git.
- Run `Rscript tests/test-monorepo-layout.R` after structural changes and
  report module-specific or external validation separately.
