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

Its `module.yml` must declare both a semantic module `version` (for the
scientific capability) and a positive integer `interface_version` (for its
public table, parameter, and CLI contract). The two versions change for
different reasons; follow [Versioning and releases](versioning-and-releases.md)
instead of treating them as interchangeable.

### R source modules are not R packages

The files under `modules/<name>/R/` are ordinary R source files. A module is
run by sourcing those files from its explicit-path CLI; it does not have a
package `DESCRIPTION` or `NAMESPACE`. Consequently, package-oriented roxygen
directives such as `@export`, `@import`, and `@importFrom` have no runtime
effect in a module and must not be used there. In particular, do not use a
placeholder such as `@importFrom dplyr .` to document a dependency.

Roxygen `@param`, `@return`, and narrative comments may be retained as
source-level documentation, but they do not generate installed help for a
module. Declare a module's runtime profile in `module.yml`, document
user-facing dependencies in its README, and use explicit package namespaces
or explicit dependency checks in code where practical.

By contrast, `packages/<name>/` is a standard R package with its own
`DESCRIPTION` and `NAMESPACE`. Only there are roxygen package directives
appropriate: `@export` defines public package functions, and `@importFrom`
must name the actual symbols imported.

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
   module first; update its tests, schema, changelog, and version metadata as
   appropriate.
2. Run the module and repository checks, then export the released R
   implementation to the corresponding deployment repository when needed.
3. For a change discovered in an adapter, test it there first. If it
   changes scientific behavior or the reusable interface, backport it to the
   canonical module, validate it there, and then export the release back to
   the adapter.
4. Keep UI fields, mounted-path discovery, output handling, and runtime setup
   only in the deployment repository.

Each deployment repository should contain `OMIX_MODULE_SOURCE.md`, identifying
its canonical module and linking developers to this contract. It also records
the canonical version/ref exported into the adapter, its own release tag,
platform-release validation, and pinned runtime identity when those are known.

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
stable behavior **and** the utility fits Core's intentionally lightweight
dependency policy. A module should otherwise own its implementation and
declare its own dependencies and data policy in `module.yml`.

## Optional shared R packages

Use `packages/<package-name>/` for a stable, portable R package needed by two
or more modules when it does not belong in lightweight Core. This is the home
for a shared renderer, formatter, or method helper with dependencies that are
appropriate for a runtime profile but not for every table-based OMIX use.

An optional shared package must have a standard R-package layout:

```text
packages/<package-name>/
|-- DESCRIPTION
|-- NAMESPACE
|-- R/
|-- tests/
`-- README.md
```

Its README must state the supported contracts, installation command, stable
defaults, and the module(s) it serves. It must not contain platform UI,
mounted-path discovery, a deployment runtime, or generated results. A module
continues to own its scientific selection and interpretation rules; a shared
package should only own behavior that is genuinely common and has direct
regression coverage.

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

The current legacy `moo/moo-filt.rds` output is serialized with a
`MOSuite::multiOmicDataSet` class label. MOObject 0.5.0 provides an explicit
compatibility reader that reconstructs supported legacy objects as current
`MOObject::multiOmicDataSet` objects. The OMIX bridge validates representative
legacy filtered-count and continuous-expression artifacts in a runtime that
does not contain the full MOSuite package. Portable count and metadata tables
remain the preferred cross-tool handoff when no object-aware consumer is
needed.

A producing workflow should use `MOObject::write_multiOmicDataSet()` for new
artifacts when it adopts MOObject directly. Preserve the established filtered
integer-like `filt` layer, aligned metadata, annotation, and provenance. The
OMIX bridge imports only MOObject and Core, pins the supported object API, and
keeps raw-count and declared continuous-expression handoffs separate.
