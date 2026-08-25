# OMIX

OMIX is an R bioinformatics monorepo. It combines an installable shared R
package with independent analysis modules.

```text
OMIX/
|-- core/                              Shared R package: Omix
|-- bridges/                           Optional ecosystem-specific R packages
|   `-- mosuite/                       OmixMOSuite MOO-to-table bridge
|-- modules/                           Independent analysis modules
|   |-- OMIX-GSEA-Preranked-Legacy/
|   |-- OMIX-L2P-Single/
|   `-- OMIX-L2P-Multi/
|-- docs/                              Repository and module conventions
`-- tests/                             Repository-level contract checks
```

## Core package

`core/` is the installable `Omix` package. It currently provides reusable
color palette utilities, including `get_color_palette()`.

For analysis use, install it directly from GitHub:

```r
install.packages("remotes")
remotes::install_github("NIDAP-Community/Omix", subdir = "core")
library(Omix)
```

See [core/README.md](core/README.md) for the full utility guide and local
contributor setup.

## Optional bridge packages

`bridges/` contains separately installable packages that convert a supported
external data object into a portable Core contract. They are not dependencies
of `Omix` or ordinary table-based modules.

| Package | Ecosystem | Purpose |
| --- | --- | --- |
| [OmixMOSuite](bridges/mosuite) | MOSuite | Convert an MOO into `omix_standard_input` counts and metadata tables. |

See [bridges/README.md](bridges/README.md) for the extension contract and
installation guidance.

## Module catalog

Each directory under `modules/` is independent from the other modules and
from the `Omix` package API. It owns its own source, tests, schemas,
documentation, and release history.

Each module will be synchronized with its corresponding individual repository.
The synchronization tooling is under construction.

The **Module** link below is the canonical, platform-neutral implementation.
The **Code Ocean adapter** link is the repository deployed as a capsule; it
contains the Code Ocean-specific `code/`, metadata, and environment files.

| Module | Code Ocean adapter | Purpose | Status |
| --- | --- | --- | --- |
| [OMIX-GSEA-Preranked-Legacy](modules/OMIX-GSEA-Preranked-Legacy) | [OMIX-GSEA-Preranked-Legacy](https://github.com/NIDAP-Community/OMIX-GSEA-Preranked-Legacy) | Legacy preranked GSEA | Active |
| [OMIX-Volcano-Plot](modules/OMIX-Volcano-Plot) | [OMIX-Volcano-Plot](https://github.com/NIDAP-Community/OMIX-Volcano-Plot) | Differential-expression volcano plot | Active |
| [OMIX-L2P-Single](modules/OMIX-L2P-Single) | [OMIX-L2P-Single](https://github.com/NIDAP-Community/OMIX-L2P-Single) | Single-comparison L2P | Active |
| [OMIX-L2P-Multi](modules/OMIX-L2P-Multi) | [OMIX-L2P-Multi](https://github.com/NIDAP-Community/OMIX-L2P-Multi) | Multi-comparison L2P | Active |

Read the [developer guide](docs/developer-guide.md) and
[module contract](docs/module-contract.md) before adding or releasing module
implementation. The compact instructions for GitHub Copilot are in
[.github/copilot-instructions.md](.github/copilot-instructions.md).

## Starter environments

Shared runtime definitions live in [`starter-environments/`](starter-environments/).
They are built once for a scientific domain and then used by module-specific
container overlays. This keeps pathway modules independent of MOSuite while
allowing the same pinned OCI image to run in Code Ocean, Docker, and HPC.
See [docs/starter-environments.md](docs/starter-environments.md).

## Checks

Run the repository layout check from the repository root:

```bash
Rscript tests/test-monorepo-layout.R
```

Run the core package tests after installing its dependencies:

```r
testthat::test_local("core")
```
