# Deployment Adapter Guide

A deployment adapter makes one canonical OMIX module usable in a particular
execution environment. It may own an interactive UI, input discovery, output
layout, and runtime translation. It does not own a second version of the
scientific method.

Read the [module contract](module-contract.md), [developer guide](developer-guide.md),
[AI contributor guide](ai-contributor-guide.md), and
[versioning and release policy](versioning-and-releases.md) before creating or
changing an adapter.

## When an adapter is warranted

Create an adapter only when the canonical module needs a platform-specific UI,
managed data or workflow handoff, platform runtime configuration, or an
environment-specific entry point. A portable CLI module that is used directly
from local R, a container, or HPC does not need an adapter.

The canonical module must already exist and have a documented public contract:

- explicit-path CLI under `scripts/`;
- `module.yml` with module and interface versions, a runtime profile, and an
  adapter registry;
- `schemas/interface.yml`;
- direct tests, README, and changelog; and
- a reviewed scientific implementation under `R/`.

## Ownership boundary

| Responsibility | Canonical module | Deployment adapter |
| --- | --- | --- |
| Scientific functions and scientific defaults | Owns | Released export only |
| Portable CLI and machine-readable contract | Owns | References |
| UI, data attachment, workflow input discovery, and result location | Never | Owns |
| Platform entry point and environment overlay | Never | Owns |
| Shared scientific runtime definition | Owns | References a pinned release |
| Platform validation | Receives evidence | Performs |

If an adapter test reveals a scientific, statistical, input-contract, or
portable-interface issue, backport it to the canonical module, test it there,
and export the released function back to the adapter.

## Required adapter files

Every adapter repository should contain the following files at its root:

| File | Purpose |
| --- | --- |
| `README.md` | User-facing deployment instructions and clear link to the canonical module. |
| `OMIX_MODULE_SOURCE.md` | Canonical versions/source reference, exported scientific files, synchronization rules, and adapter release record. |
| `AGENTS.md` | Repository-local instructions for coding agents, including the adapter boundary and validation procedure. |
| `.github/copilot-instructions.md` | Brief Copilot entry point that links to `AGENTS.md`. |

Copy the templates under [`templates/deployment-adapter/`](../templates/deployment-adapter/)
when starting a new adapter. Replace every angle-bracket placeholder before
release.

## Standard adapter README

Use this order in every user-facing adapter README:

1. **Title and summary** — identify the analysis and deployment purpose.
2. **Canonical OMIX module** — link to the module, interface schema, module
   contract, and the version/source reference recorded in `OMIX_MODULE_SOURCE.md`.
3. **What this deployment adds** — UI, input discovery, workflow handoff, or
   runtime behavior unique to the deployment.
4. **Inputs** — data assets, uploads, expected files, column requirements,
   and unambiguous selection rules.
5. **Run the analysis** — concise user steps and important parameter defaults.
6. **Outputs and workflow handoff** — output names, locations, and which
   artifacts are intended for downstream tools.
7. **Environment and reproducibility** — named runtime, pinned image or
   lockfile identity, source reference, and input provenance expectations.
8. **Troubleshooting and limitations** — common input, environment, or
   workflow errors. Do not hide ambiguity or unsupported input types.
9. **For developers** — point to `AGENTS.md` and `OMIX_MODULE_SOURCE.md`.
10. **References and support** — method citations and a support route when
    appropriate.

Keep the README usable by a scientist who has not read the monorepo. Do not
copy the canonical module's full portable CLI guide; link to it and document
only the behavior introduced by the deployment.

## Scientific exports and synchronization

- Export only validated scientific functions from the canonical module into the
  adapter's `code/functions/` directory.
- Record the canonical module and interface versions, immutable Git reference,
  exported files, and any intentional adapter-only differences in
  `OMIX_MODULE_SOURCE.md`.
- Do not edit an exported scientific function in the adapter as a permanent
  fix. Make the change in the canonical module, validate it, and re-export.
- The adapter entry point may translate UI parameters, resolve attached inputs,
  and select deployment output directories. It must not silently change a
  scientific default or implement a second analysis algorithm.

## Inputs, outputs, and workflows

- The app-panel parameter names and defaults must agree with the canonical
  schema unless the adapter explicitly translates a platform-only field.
- Discover attached input recursively only when the selection is unambiguous;
  fail with candidate paths when more than one suitable file is found.
- Prefer a single well-defined input bundle over unrelated independent files
  when a workflow produces a naturally paired set of artifacts.
- Write stable, documented output names. Preserve every artifact required by a
  downstream adapter, including paired data and metadata tables.
- Test upstream-result attachment and downstream-result handoff using a real
  representative run before release.

## Environment and release requirements

- Use the module's declared shared runtime profile whenever one is available.
  Pin the selected image by version and resolved digest; never use `latest`.
- Put platform-only package additions in the adapter environment. Promote a
  dependency to a shared runtime only after more than one module needs it.
- Rebuild only the affected runtime family when its definition changes.
- Before release, verify the adapter's Git state, canonical source reference,
  app-panel/schema agreement, environment identity, input provenance, and a
  successful platform run.
- Create an adapter tag only after platform validation. Record that tag, the
  platform release identifier, and the runtime tag plus resolved digest in
  `OMIX_MODULE_SOURCE.md`. State **Pending** for unavailable facts; do not
  invent release evidence.

## Audit checklist

For an existing adapter, verify:

- a current `README.md`, `OMIX_MODULE_SOURCE.md`, and `AGENTS.md` exist;
- the canonical module lists the adapter in `module.yml` and its README;
- the adapter links back to the canonical module and module contract;
- exported scientific files are intentionally synchronized with the canonical
  release;
- the runtime and input/output behavior are documented and tested; and
- no credentials, generated results, package caches, or large inventories are
  committed.
