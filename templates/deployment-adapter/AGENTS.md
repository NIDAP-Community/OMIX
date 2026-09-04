# Deployment Adapter Agent Instructions

This repository is a deployment adapter for the canonical OMIX module recorded
in [OMIX_MODULE_SOURCE.md](OMIX_MODULE_SOURCE.md). Read that file, this
repository's README, and the canonical [OMIX module contract](https://github.com/NIDAP-Community/OMIX/blob/main/docs/module-contract.md)
before editing.

## Ownership

- The canonical module owns scientific functions, scientific defaults,
  portable CLI behavior, schemas, and tests.
- This repository owns deployment UI, attached-input discovery, result paths,
  runtime configuration, and the platform entry point.
- Do not permanently change exported scientific functions here. Backport any
  scientific or reusable-interface change to the canonical module, validate
  it, then export the released function back into `code/functions/`.

## Working rules

1. Inspect Git status, the app-panel definition, `OMIX_MODULE_SOURCE.md`, and
   the canonical schema before editing.
2. Keep UI parameter names and defaults aligned with the canonical contract.
   Document any required platform-only translation explicitly.
3. Discover attached data only when exactly one candidate matches; otherwise
   fail with the candidate paths and require explicit selection.
4. Preserve stable output names and paired artifacts needed by downstream
   workflows.
5. Use the named pinned runtime. Do not rebuild unrelated shared environments
   or use an unpinned `latest` image.
6. Do not commit input data, generated results, credentials, package caches,
   or package-inventory archives.
7. Validate an adapter change with a representative deployment run. Report
   separately what was tested locally, in the deployment environment, and not
   tested.

## Release discipline

- Keep the README and `OMIX_MODULE_SOURCE.md` current with the canonical
  module link and source reference.
- Before release, confirm Git is clean, inputs are unambiguous, the app panel
  matches the intended interface, the environment is pinned, and the workflow
  handoff works when applicable.
