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

The monorepo is platform-neutral. Modules must not contain platform-specific
UI metadata, environment Dockerfiles, or mounted-path assumptions.
Platform-specific repositories or build outputs own those adapters. A module's
`scripts/` entry point accepts explicit input and output paths so that local R,
Galaxy, containers, and HPC schedulers can invoke the same scientific
implementation.

## Deployment adapters

An external deployment repository is a **deployment adapter**, not a
directory-for-directory mirror of its module in this monorepo. The two
repositories intentionally divide ownership as follows:

| Responsibility | Canonical OMIX module | Deployment repository |
| --- | --- | --- |
| Scientific R implementation | `R/` | Exported copy under `code/functions/` |
| Platform-neutral command-line interface | `scripts/` | Not copied directly |
| Input/output contract and tests | `schemas/`, `tests/` | References the released module contract |
| Platform UI and metadata | Never | Platform-owned configuration |
| Platform runtime adapter | Never | Platform-owned entry point |
| Mounted paths and workflow discovery | Never | Platform-owned I/O translation |
| Runtime configuration | Never | Platform-owned environment files |

An adapter entry point is therefore expected to differ from a module's
`scripts/` entry point. The adapter translates platform inputs, parameters,
and output locations into a call to the scientific implementation; the module
script accepts explicit, platform-neutral paths for local R, Docker, Galaxy,
and HPC use.

### Development and release flow

1. For a scientific or reusable-interface change, edit the canonical OMIX
   module first; update its tests, schema, and changelog as appropriate.
2. Run the module and repository checks, then export the released R
   implementation to the corresponding deployment repository when needed.
3. For a change discovered in an adapter, test it there first. If it
   changes scientific behavior or the reusable interface, backport it to the
   canonical module, validate it there, and then export the release back to
   the adapter.
4. Keep UI fields, mounted-path discovery, output handling, and runtime setup
   only in the deployment repository.

Each deployment repository should contain `OMIX_MODULE_SOURCE.md`, identifying
its canonical module and linking developers to this contract.

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
ecosystem version. It must not introduce platform runtime paths or UI into the
monorepo's portable code.

### MOO object boundary

Use a lightweight object package for ordinary MOO reading and extraction. Do
not add the full MOSuite workflow package to a shared OMIX runtime or a
downstream adapter merely to read a MOO.

The current legacy `moo/moo-filt.rds` output is serialized as
`MOSuite::multiOmicDataSet`, so it remains a MOSuite compatibility artifact.
It cannot be read by a runtime that has only MOObject. Until the producing
workflow writes a validated `MOObject::multiOmicDataSet`, use the portable
table handoff instead.

When an MOObject handoff is introduced, preserve the legacy MOO and write a
parallel, explicitly named MOO containing the filtered integer-like `filt`
counts, aligned metadata, annotation, and portable provenance. The OMIX bridge
must then import only MOObject and Core, pin and validate the object interface,
and complete an end-to-end module test in that minimal runtime.
