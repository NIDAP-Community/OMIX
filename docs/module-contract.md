# Module Contract

Each OMIX module is an independently maintained analysis capability under
`modules/<module-name>/`. It is not automatically exported by the `Omix` R
package.

Every module must contain:

```text
modules/<module-name>/
|-- R/                     Module-owned R source
|-- tests/                 Direct module tests
|-- schemas/               Machine-readable input and output contracts
|-- module.yml             Module identity and execution metadata
|-- README.md              Usage and dependency documentation
`-- CHANGELOG.md           Module release history
```

The monorepo is platform-neutral. Modules must not contain Code Ocean App
Panel metadata, Code Ocean environment Dockerfiles, or `/data` and `/results`
mount assumptions. Platform-specific repositories or build outputs own those
adapters. A module's `scripts/` entry point accepts explicit input and output
paths so that Code Ocean, Galaxy, containers, and HPC schedulers can invoke
the same scientific implementation.

## Code Ocean deployment adapters

An individual Code Ocean repository is a **deployment adapter**, not a
directory-for-directory mirror of its module in this monorepo. The two
repositories intentionally divide ownership as follows:

| Responsibility | Canonical OMIX module | Code Ocean repository |
| --- | --- | --- |
| Scientific R implementation | `R/` | Exported copy under `code/functions/` |
| Platform-neutral command-line interface | `scripts/` | Not copied directly |
| Input/output contract and tests | `schemas/`, `tests/` | References the released module contract |
| Code Ocean App Panel and metadata | Never | `.codeocean/`, `metadata/` |
| Code Ocean runtime adapter | Never | `code/main.R`, `code/run` |
| Code Ocean paths and workflow discovery | Never | `/data` discovery and `/results` handling in `code/main.R` |
| Capsule environment | Never | `environment/` |

`code/main.R` is therefore expected to differ from a module's `scripts/`
entry point. The former translates Code Ocean inputs, parameters, and output
locations into a call to the scientific implementation; the latter accepts
explicit, platform-neutral paths for local, Docker, Galaxy, and HPC use.

### Development and release flow

1. For a scientific or reusable-interface change, edit the canonical OMIX
   module first; update its tests, schema, and changelog as appropriate.
2. Run the module and repository checks, then export the released R
   implementation to the corresponding Code Ocean repository's
   `code/functions/` directory.
3. For a change discovered in Code Ocean, test it in the capsule first. If it
   changes scientific behavior or the reusable interface, backport it to the
   canonical module, validate it there, and then export the release back to
   the adapter.
4. Keep Code Ocean-only behavior—App Panel fields, `/data` discovery,
   `/results` handling, and the capsule environment—only in the individual
   repository.

Each Code Ocean repository contains `OMIX_MODULE_SOURCE.md`, which identifies
its canonical module and links developers to this contract.

### Adapter registry and bidirectional links

Each canonical module records its supported deployment adapters in the
`deployment_adapters` list in `module.yml`. Every entry names the platform and
links to the adapter repository. The module README must also link to each
supported adapter so people can find the deployable implementation.

In the other direction, every adapter README and `OMIX_MODULE_SOURCE.md` must
link to its canonical module and to this contract. When an adapter is added,
moved, renamed, or retired, update all four references—the module metadata,
module README, adapter README, and `OMIX_MODULE_SOURCE.md`—and verify the link
targets before release. This keeps the monorepo the scientific source of truth
without hiding the platform-specific deployment path.

Shared utilities belong in `core/` only after two or more modules need the same
stable behavior. A module should otherwise own its implementation and declare
its own dependencies and data policy in `module.yml`.

## Optional ecosystem bridges

External data-object integrations are neither scientific modules nor Core
dependencies. `core/` defines portable input contracts; an optional bridge
package under `bridges/<ecosystem>/` may depend on Core and an external package
to convert its objects into those contracts. A bridge must document its source
object assumptions, preserve conversion provenance, and test its supported
ecosystem version. It must not introduce Code Ocean runtime paths or UI into
the monorepo's portable code.
