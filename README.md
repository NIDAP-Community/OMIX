# OMIX

OMIX is an R bioinformatics monorepo. It combines an installable shared R
package with independent analysis modules.

```text
OMIX/
|-- core/                              Shared R package: Omix
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

## Module catalog

Each directory under `modules/` is independent from the other modules and
from the `Omix` package API. It owns its own source, tests, schemas,
documentation, and release history.

Each module will be synchronized with its corresponding individual repository.
The synchronization tooling is under construction.

| Module | Purpose | Status |
| --- | --- | --- |
| [OMIX-GSEA-Preranked-Legacy](modules/OMIX-GSEA-Preranked-Legacy) | Legacy preranked GSEA | Planned |
| [OMIX-L2P-Single](modules/OMIX-L2P-Single) | Single-comparison L2P | Planned |
| [OMIX-L2P-Multi](modules/OMIX-L2P-Multi) | Multi-comparison L2P | Planned |

Each planned module currently contains only its skeleton contract. Read
[docs/module-contract.md](docs/module-contract.md) before adding implementation.

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
