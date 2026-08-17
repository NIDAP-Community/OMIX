# Starter Environments

OMIX starter environments are shared, cached OCI base images. They provide a
stable runtime family without coupling unrelated modules to one another.

```text
r-base -> r-pathway -> pathway modules
       -> r-visualization -> visualization modules
       -> r-singlecell -> single-cell modules
```

`r-pathway` is the shared dependency layer for GSEA, GSVA, and L2P modules.
MOSuite has a separate runtime family and should exchange data with pathway
modules through documented schemas rather than shared package installations.

Module-specific code remains in `modules/<module>/`; module-specific runtime
additions belong beside that module. Only dependencies used by more than one
pathway module belong in `starter-environments/r-pathway/`.

## Reproducibility

The Dockerfile defines a build recipe, but a release is identified by its OCI
image digest plus the module Git commit and input-data provenance. CI builds
starter environments for validation; publication to GHCR is explicitly
requested through the manual workflow-dispatch input.

Before the first production release, capture the fully resolved R package set
from the built image into a reviewed lockfile. The base image, R version,
Bioconductor release, and non-CRAN package commits must remain pinned.

## Platform adapters

- **Code Ocean:** an administrator registers the published image as a Starter
  Environment. The capsule retains only module-specific setup.
- **Docker:** bind-mount inputs at `/data` and outputs at `/results`.
- **HPC:** pull the same image digest with Apptainer/Singularity and bind the
  same two paths.
