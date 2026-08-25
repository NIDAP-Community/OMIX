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

`r-pathway/renv.lock` records the fully resolved CRAN and Bioconductor package
set captured from its validated image. The base image, R version,
Bioconductor release, lockfile, and non-CRAN package commits must remain
pinned for a reproducible rebuild.

## Publishing a shared image

1. Make the intended Dockerfile and lockfile changes, then bump that
   environment's `VERSION` file. If the base image changes, update the
   versioned `BASE_IMAGE` reference in each dependent environment.
2. Merge the validated change to `main`, confirm the GHCR package is associated
   with `NIDAP-Community/OMIX` (or grants OMIX Actions access), then manually
   dispatch **Starter Environments** with **Publish** enabled.
3. Record the version-tagged image digest from the workflow summary alongside
   the consuming module commit and input-data provenance. Use that exact image
   digest for local containers and HPC releases.

The workflow publishes an explicit version tag and the source commit tag. It
does not publish or overwrite `latest`.

### Adopting an existing image

When a validated image already exists in GHCR under a legacy repository
association, first reconnect that package to `NIDAP-Community/OMIX` and grant
OMIX Actions write access. Then manually dispatch **Starter Environments**
with **Adopt existing** enabled and the existing source tag (normally
`latest`). This registry-only job copies the existing manifest to the version
tags recorded in `VERSION`; it does not run a Docker build or reinstall any
packages.

## Execution targets

- **Docker:** bind-mount explicit input and output directories.
- **HPC:** pull the same image digest with Apptainer/Singularity and bind the
  required input and output directories.
