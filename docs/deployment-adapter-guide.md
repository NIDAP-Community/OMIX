# Deployment Adapter Guide

A deployment adapter makes one canonical OMIX module usable in a particular
execution environment. It may own an interactive UI, input discovery, output
layout, and runtime translation. It does not own a second version of the
scientific method.

Read the [module contract](module-contract.md),
[contributor guide](contributor-guide.md), and
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
| Scientific functions and scientific defaults | Owns | Syncweaver-managed released export only |
| Portable CLI and machine-readable contract | Owns | References |
| UI, data attachment, workflow input discovery, and result location | Never | Owns |
| Platform entry point and environment overlay | Never | Owns |
| Shared scientific runtime definition | Owns | References a pinned release |
| Platform validation | Receives evidence | Performs |

If an adapter test reveals a scientific, statistical, input-contract, or
portable-interface issue, backport it to the canonical module, test it there,
and let Syncweaver propose the released function update for the adapter.

## Required adapter files

Every adapter repository should contain the following files at its root:

| File | Purpose |
| --- | --- |
| `README.md` | User-facing deployment instructions and clear link to the canonical module. |
| `OMIX_MODULE_SOURCE.md` | Canonical versions/source reference, exported scientific files, synchronization rules, and adapter release record. |
| `AGENTS.md` | Repository-local instructions for coding agents, including the adapter boundary and validation procedure. |
| `.github/copilot-instructions.md` | Brief Copilot entry point that links to `AGENTS.md`. |
| `.syncweaver-lock.json` | Machine-readable mapping from canonical `R/` to the pinned `code/functions/` export; generate it with Syncweaver rather than editing it by hand. |
| `CHANGELOG.md` | Adapter-only changes, including UI, I/O translation, runtime selection, and platform releases. |
| `.gitignore` | Excludes attached data, generated results, scratch files, credentials, and local caches. |
| `code/main.R` | Thin platform entry point that resolves inputs and calls the managed scientific functions. |
| `code/run` | Executable deployment launcher. |

Copy the templates under [`templates/deployment-adapter/`](../templates/deployment-adapter/)
when starting a new adapter. Replace every angle-bracket placeholder before
release.

## Standard repository layout

Use the following layout for a Code Ocean deployment adapter. The
[OMIX GSEA Preranked Legacy adapter](https://github.com/NIDAP-Community/OMIX-GSEA-Preranked-Legacy)
is the reference for the platform components, but it is not a directory-for-
directory template: older repositories may contain historical module
directories, debug results, or package inventories that new adapters must not
copy.

```text
<adapter repository>/
├── .codeocean/
│   ├── app-panel.json          # Harbor: UI and named-parameter bindings
│   ├── datasets.json           # Harbor: attached-data declarations
│   ├── environment.json        # Harbor/Forge: pinned runtime selection
│   └── resources.json          # Harbor: deployment resource request
├── .github/
│   └── copilot-instructions.md
├── code/
│   ├── main.R                  # Harbor: platform input/output translation
│   ├── run                     # Harbor: deployment launcher
│   ├── README.md               # Optional App Panel user guide
│   └── functions/              # Syncweaver: canonical module R/ export
├── environment/                # Code Ocean environment export, when used
├── container/                  # Optional portable deployment overlay
├── metadata/                   # Optional platform/catalog metadata
├── tests/                      # Adapter contract and representative-run tests
├── .gitignore
├── .syncweaver-lock.json       # Canonical source mapping and pinned commit
├── AGENTS.md
├── CHANGELOG.md
├── OMIX_MODULE_SOURCE.md
└── README.md
```

Ownership is path-specific:

- Harbor owns `.codeocean/`, `code/main.R`, `code/run`, deployment-only
  documentation, mounted-input discovery, output placement, and adapter tests.
- Syncweaver owns the files under `code/functions/` after the initial source
  mapping is established. It imports them from the canonical module's `R/`
  directory at an immutable commit or module release tag.
- Forge owns shared-runtime definitions and immutable image provenance. An
  adapter may select or overlay a runtime, but it must not silently rebuild a
  different scientific environment.
- Beacon independently verifies source parity, interface translation, fixture
  equivalence, and runtime provenance before release.

Do not create empty `R/` or `schemas/` directories in a deployment repository;
those belong to the canonical module. Do not copy generated `results/`, data,
debug output, credentials, package caches, or package-inventory archives. A
deployment-local `module.yml` is not required: canonical module metadata lives
in OMIX, while adapter provenance lives in `OMIX_MODULE_SOURCE.md` and the
Syncweaver lockfile.

## Harbor: create a new deployment adapter

Harbor owns the initial repository bootstrap. Use this sequence:

1. Confirm that the canonical module has reviewed `R/` code, an explicit-path
   CLI, `module.yml`, `schemas/interface.yml`, tests, README, and changelog.
2. Create the deployment repository using the canonical module's display name
   and established adapter naming convention.
3. Copy `templates/deployment-adapter/` into the repository and replace every
   placeholder. Add a `.gitignore` that excludes at least `/data/`, `/results/`,
   and `/scratch/`.
4. Create `.codeocean/`, `code/`, `tests/`, and only the conditional runtime or
   metadata directories the deployment actually needs.
5. Implement `code/main.R` as a thin adapter: resolve platform inputs,
   translate named parameters, choose deployment output paths, and call the
   canonical functions. Put no independent scientific algorithm or default in
   this file.
6. Implement `code/run` as the deployment launcher and keep it free of
   scientific decisions.
7. Map the canonical module's complete `R/` directory into `code/functions/`,
   pinned to an immutable canonical commit or release tag. Until Syncweaver is
   ready for OMIX, Harbor performs this export using the controlled interim
   procedure below. Once available, Syncweaver assumes maintenance of the same
   path without changing its scientific contents.
8. Record the mapping, canonical version, interface version, source reference,
   and exported files in `OMIX_MODULE_SOURCE.md`. Do not claim an adapter tag,
   platform release, or runtime digest until it has been validated.
9. Build the App Panel from the canonical schema. Expose every user-settable
   canonical parameter with matching type, choices, and scientific default.
   Record every platform-only alias, intentionally hidden platform-managed
   input, preset, attached dataset, and path translation.
10. Add tests for parameter translation, unambiguous input discovery, stable
    outputs, and a representative fixture. Confirm that the adapter sources
    the Syncweaver-managed files rather than a second scientific copy.
11. Ask Beacon to perform the independent parity audit, then run the adapter in
    Code Ocean. Record the validated capsule release and immutable runtime
    digest before creating an adapter release tag.

### Interim Harbor synchronization

Until Syncweaver provides the required OMIX synchronization safeguards, Harbor
may perform the initial and subsequent scientific exports manually. This is a
temporary controlled operation, not permission to maintain adapter-specific
science. For every export Harbor must:

1. start from a merged, tested canonical commit or immutable module tag;
2. copy the complete canonical module `R/` contents into `code/functions/`,
   removing scientific files that no longer exist upstream;
3. make no edits, renames, formatting changes, or behavioral substitutions in
   the exported files;
4. record the canonical module version, interface version, exact commit, file
   mapping, and SHA-256 for every exported file in `OMIX_MODULE_SOURCE.md`;
5. place the export in a reviewable adapter pull request that leaves
   `.codeocean/`, `code/main.R`, runtime files, and other adapter-owned paths
   intact;
6. run the adapter contract and representative fixture tests; and
7. obtain Beacon's independent byte-parity and interface review before merge.

If the existing `code/functions/` contents differ from their claimed canonical
source, Harbor must stop, preserve the diff, and report the drift. Timestamps do
not determine which version is current. When Syncweaver is ready, onboard the
same mapping and pinned source without creating a second scientific-code path.

Use the [Syncweaver transition contract](syncweaver-transition-contract.md)
for the reviewed mapping, protected-path, stop-condition, and pre/post-test
evidence required before onboarding. The transition record is policy and
evidence, not a hand-authored Syncweaver lockfile or an invented automation API.

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

- Map the canonical module's complete validated `R/` directory into the
  adapter's `code/functions/` directory. After bootstrap this path is managed
  by Syncweaver, not Harbor.
- Record the canonical module and interface versions, immutable Git reference,
  exported files, and any intentional adapter-only differences in
  `OMIX_MODULE_SOURCE.md`.
- Do not edit a Syncweaver-managed scientific function in the adapter. Make the
  change in the canonical module, validate it, and let Syncweaver propose the
  updated export. Host-side drift must be reported rather than overwritten
  silently.
- The adapter entry point may translate UI parameters, resolve attached inputs,
  and select deployment output directories. It must not silently change a
  scientific default or implement a second analysis algorithm.

Scientific implementation has one direction of travel: canonical OMIX module
to deployment adapter. A platform test may reveal a canonical defect, but the
scientific owner must fix and validate it in OMIX before Syncweaver updates the
adapter. Do not resolve drift by making an adapter-only scientific edit.

Before release, Beacon independently compares the adapter with both its
recorded canonical commit and the current canonical module. The parity audit
checks exported-file hashes; module and interface versions; CLI, schema, and
app-panel parameter names, types, choices, and defaults; scientific
documentation; fixture output equivalence; and runtime tag plus immutable
digest. Record every intentional platform-only input, alias, preset, hidden
control, or output-path translation in `OMIX_MODULE_SOURCE.md`. Beacon reports
and blocks unexplained drift; scientific owners, Harbor, and Forge remediate
their respective canonical, platform, and runtime scopes under Atlas's merge
order.

## Inputs, outputs, and workflows

- The app-panel parameter names and defaults must agree with the canonical
  schema unless the adapter explicitly translates a platform-only field.
- Every user-settable canonical parameter must be represented in the App Panel,
  including advanced controls. A platform-managed input may remain hidden only
  when the adapter supplies it reproducibly and the exception is recorded in
  `OMIX_MODULE_SOURCE.md`; absence caused by an incomplete panel is not an
  intentional exception.
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
- An automated workflow must use the canonical
  [release automation contract](release-automation-contract.md). It may
  prepare a reviewable adapter release but may finalize a tag only with the
  recorded platform-validation evidence and approval.

## Audit checklist

Start with Beacon's current
[deployment adapter inventory](deployment-adapter-inventory.md). Its JSON
source is the durable, machine-readable status record; update and validate it
when an audit changes a parity, interface, runtime, or platform claim.

For an existing adapter, verify:

- a current `README.md`, `OMIX_MODULE_SOURCE.md`, and `AGENTS.md` exist;
- the canonical module lists the adapter in `module.yml` and its README;
- the adapter links back to the canonical module and module contract;
- exported scientific files match the recorded canonical commit and hashes,
  and any lag from the current canonical module is reported explicitly;
- CLI, schema, adapter CLI, and app-panel parameter names, types, choices, and
  defaults agree, except for documented platform-only translations;
- scientific documentation claims and fixture outputs agree across canonical
  and deployment execution;
- the runtime tag and immutable digest match the validated runtime record;
- the runtime and input/output behavior are documented and tested; and
- no credentials, generated results, package caches, or large inventories are
  committed.
