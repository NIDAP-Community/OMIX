# OMIX Starter Environments

Starter environments are reusable OCI container base layers for OMIX modules.
They contain runtime dependencies shared by a scientific domain, not
module-specific code or user data.

```text
r-base -> r-pathway -> OMIX-GSEA-Preranked-Legacy
```

The image family is intended for three execution targets:

- Code Ocean, after an administrator registers the published image as a
  Starter Environment;
- local Docker development; and
- HPC execution through Apptainer/Singularity.

## Environments

| Environment | Purpose | Consumer modules |
| --- | --- | --- |
| `r-base` | Pinned R and common build/runtime libraries | all R environments |
| `r-pathway` | Pathway and gene-set analysis libraries | GSEA, GSVA, L2P |

Images are built by the `Starter Environments` GitHub workflow. Normal pushes
and pull requests only build and validate images. Publishing to GHCR is a
manual workflow-dispatch action, so an image is never released implicitly by a
code change.

## Release rule

Use the image digest recorded after a successful build for reproducible module
releases. Do not use the mutable `latest` tag in a released module manifest.

No research or reference data belongs in a starter image. Attach or mount
versioned data assets at runtime under `/data` instead.
