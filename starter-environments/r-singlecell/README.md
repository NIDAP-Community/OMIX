# r-singlecell

`r-singlecell` is the shared runtime for modules that read a serialized
Seurat object and create pseudobulk inputs. It deliberately installs
`SeuratObject`, not the full `Seurat` workflow package.

Its intended scope is narrow:

- `SeuratObject` and its sparse-matrix dependencies to read an object and its
  raw assay layer;
- `optparse` for portable command-line entry points; and
- OMIX Core plus the separately versioned `OmixSeurat` bridge from the same
  source checkout.

It does not include Seurat analysis workflows, Harmony, single-cell
normalization/integration methods, or research data.

## Bootstrap status

This initial definition is marked `v0`. It is not publishable. The Starter
Environments CI must first build it on Linux, capture the resolved
`renv.lock`, and run the `OmixSeurat` package and Seurat-to-pseudobulk smoke
tests. Only then may a maintainer replace the bootstrap installer with the
committed lock restore, change `VERSION` to `v1`, and publish a digest-qualified
image record.

Until that validation is complete, `OMIX-Seurat-Pseudobulk` remains a review
module. Its portable source and explicit-path CLI are already testable with a
project-local installation of the exact same Core and bridge revisions.
