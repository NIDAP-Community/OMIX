# OMIX

OMIX is an R bioinformatics monorepo. It combines an installable shared R
package with independent analysis modules.

```text
OMIX/
|-- core/                              Shared R package: Omix
|-- bridges/                           Optional ecosystem-specific R packages
|   |-- mosuite/                       OmixMOSuite MOO-to-table bridge
|   `-- seurat/                        OmixSeurat pseudobulk bridge
|-- modules/                           Independent analysis modules
|   |-- OMIX-DEG-Analysis/
|   |-- OMIX-GSEA-Filters-Legacy/
|   |-- OMIX-GSEA-Preranked-Legacy/
|   |-- OMIX-GSEA-Visualization-Legacy/
|   |-- OMIX-Gene-Boxplots/
|   |-- OMIX-L2P-Single/
|   |-- OMIX-L2P-Multi/
|   `-- OMIX-Volcano-Plot/
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
| [OmixSeurat](bridges/seurat) | SeuratObject | Aggregate one selected cell type into donor-by-condition raw-count pseudobulk tables. |

See [bridges/README.md](bridges/README.md) for the extension contract and
installation guidance.

## Module catalog

Each directory under `modules/` is independent from the other modules and
from the `Omix` package API. It owns its own source, tests, schemas,
documentation, and release history.

The **Module** link below is the canonical, platform-neutral implementation.
The optional **Deployment repository** link is a separately maintained
interface and runtime layer; it is not required to run the module locally.

| Module | Deployment repository | Purpose | Status |
| --- | --- | --- | --- |
| [OMIX-DEG-Analysis](modules/OMIX-DEG-Analysis) | [OMIX-DEG-Analysis](https://github.com/NIDAP-Community/OMIX-DEG-Analysis) | Raw-count differential expression | Review |
| [OMIX-Gene-Boxplots](modules/OMIX-Gene-Boxplots) | [OMIX-Gene-Boxplots](https://github.com/NIDAP-Community/OMIX-Gene-Boxplots) | Gene-expression boxplots with optional model-consistent DEG annotations | Review |
| [OMIX-GSEA-Preranked-Legacy](modules/OMIX-GSEA-Preranked-Legacy) | [OMIX-GSEA-Preranked-Legacy](https://github.com/NIDAP-Community/OMIX-GSEA-Preranked-Legacy) | Legacy preranked GSEA | Active |
| [OMIX-GSEA-Filters-Legacy](modules/OMIX-GSEA-Filters-Legacy) | [OMIX-GSEA-Filters-Legacy](https://github.com/NIDAP-Community/OMIX-GSEA-Filters-Legacy) | Filter and subset GSEA result tables | Active |
| [OMIX-GSEA-Visualization-Legacy](modules/OMIX-GSEA-Visualization-Legacy) | [OMIX-GSEA-Visualization-Legacy](https://github.com/NIDAP-Community/OMIX-GSEA-Visualization-Legacy) | Legacy GSEA enrichment-score and leading-edge visualization | Review |
| [OMIX-Volcano-Plot](modules/OMIX-Volcano-Plot) | [OMIX-Volcano-Plot](https://github.com/NIDAP-Community/OMIX-Volcano-Plot) | Differential-expression volcano plot | Active |
| [OMIX-L2P-Single](modules/OMIX-L2P-Single) | [OMIX-L2P-Single](https://github.com/NIDAP-Community/OMIX-L2P-Single) | Single-comparison L2P | Active |
| [OMIX-L2P-Multi](modules/OMIX-L2P-Multi) | [OMIX-L2P-Multi](https://github.com/NIDAP-Community/OMIX-L2P-Multi) | Multi-comparison L2P | Active |

Read the [developer guide](docs/developer-guide.md) and
[module contract](docs/module-contract.md) before adding or releasing module
implementation. Use the [module README guide](docs/module-readme-guide.md)
when documenting a canonical module. The compact instructions for GitHub Copilot are in
[.github/copilot-instructions.md](.github/copilot-instructions.md).

Use [versioning and releases](docs/versioning-and-releases.md) to distinguish
module versions, public-interface versions, adapter tags, platform releases,
and runtime identities. A module or adapter is not formally released merely
because it has been merged to its default branch.

AI coding assistants should start with [AGENTS.md](AGENTS.md) and follow the
[AI contributor guide](docs/ai-contributor-guide.md).

Deployment adapters are documented in the
[deployment adapter guide](docs/deployment-adapter-guide.md), including
reusable README, source-record, and agent-instruction templates.

## Starter environments

Shared runtime definitions live in [`starter-environments/`](starter-environments/).
They are built once for a scientific domain and then used by module-specific
container overlays. This keeps pathway modules independent of MOSuite while
allowing the same pinned OCI image to run locally, in Docker, and on HPC.
See [docs/starter-environments.md](docs/starter-environments.md).

## Run a module on Biowulf or another shared R system

OMIX modules are ordinary R source files with command-line entry points. The
command-line interface is the recommended way to run a module on Biowulf, a
workstation, or a different workflow system. It loads the module's source
itself and accepts explicit input and output paths.

Each module selects a **runtime profile** in its `module.yml`. Use the matching
committed `renv.lock` below to create a user-local R project:

| Runtime profile | Modules | Lockfile |
| --- | --- | --- |
| `r-statistics` | OMIX-DEG-Analysis | `starter-environments/r-statistics/renv.lock` |
| `r-visualization` | OMIX-GSEA-Filters-Legacy, OMIX-Gene-Boxplots, OMIX-Volcano-Plot | `starter-environments/r-visualization/renv.lock` |
| `r-pathway` | OMIX-GSEA-Preranked-Legacy, OMIX-GSEA-Visualization-Legacy, OMIX-L2P-Single, OMIX-L2P-Multi | `starter-environments/r-pathway/renv.lock` |

The validated locks target R 4.4.3 and Bioconductor 3.20. On Biowulf, check
which R module is currently offered before loading the matching version:

```bash
module spider R
module load R/4.4.3
Rscript -e 'cat(R.version.string, "\\n")'
```

Create a separate, writable run project for each runtime profile. Keeping it
outside the Git checkout avoids modifying OMIX itself and avoids consuming
limited home-directory space with compiled R packages. Substitute a suitable
writable project location if `/data/${USER}` is not the location allocated to
you.

```bash
export OMIX_ROOT=/data/${USER}/projects/OMIX
export OMIX_RUN=/data/${USER}/projects/omix-r-statistics
export RENV_PATHS_ROOT="$OMIX_RUN/.renv"

git clone https://github.com/NIDAP-Community/OMIX.git "$OMIX_ROOT"
mkdir -p "$OMIX_RUN" "$RENV_PATHS_ROOT"

Rscript -e 'install.packages("renv", repos = "https://cran.r-project.org")'
Rscript "$OMIX_ROOT/scripts/restore-omix-runtime.R" \
  --module OMIX-DEG-Analysis \
  --project "$OMIX_RUN"
```

For another module, change the run-directory name and `--module` value. The
helper reads that module's `runtime_profile`, restores the matching committed
profile lock, installs any explicitly versioned module overlay, and writes the
complete effective lock to `$OMIX_RUN/renv.lock`. Keep that generated lock with
the result provenance; it records the exact environment used for that run.

`r-pathway` additionally installs `l2p` and `l2psupp` from the immutable
source commit recorded in its Dockerfile. Those packages are deliberately
outside the shared lock because they are not hosted by CRAN or Bioconductor;
the helper records them in the effective run lock after installation.

Run a module from that activated run project. For example, this invokes the
portable DEG interface while leaving all data paths under your control:

```bash
cd "$OMIX_RUN"
Rscript "$OMIX_ROOT/modules/OMIX-DEG-Analysis/scripts/run_deg_analysis.R" \
  --input_type table \
  --counts /path/to/raw_counts.csv \
  --metadata /path/to/sample_metadata.csv \
  --gene_names_column GeneName \
  --sample_names_column Sample \
  --contrast_variable_columns Group \
  --contrasts B-A \
  --output_dir /path/to/results/deg
```

For interactive or programmatic use, start `R` from `$OMIX_RUN`, load the
local `renv` project, then source only the module function you need:

```r
renv::load(".")
source(file.path(
  Sys.getenv("OMIX_ROOT"),
  "modules/OMIX-DEG-Analysis/R/OMIX_DEG_Analysis.R"
))
```

There is deliberately no repository-wide `renv.lock`: it would install
unrelated pathway and visualization dependencies for every analysis. The
profile locks above are the canonical shared runtime definitions; each run
project's generated lock records the selected profile plus module-specific
dependencies. For a fully containerized Docker, Apptainer, or Singularity run,
use the matching pinned OCI image as described in
[docs/starter-environments.md](docs/starter-environments.md).

## Checks

Run the repository layout check from the repository root:

```bash
Rscript tests/test-monorepo-layout.R
```

Run the core package tests after installing its dependencies:

```r
testthat::test_local("core")
```
