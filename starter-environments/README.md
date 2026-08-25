# OMIX Starter Environments

Starter environments are reusable OCI container base layers for OMIX modules.
They contain runtime dependencies shared by a scientific domain, not
module-specific code or user data.

```text
r-base -> r-pathway -> OMIX-GSEA-Preranked-Legacy
       -> r-statistics -> OMIX-DEG-Analysis
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
| `r-statistics` | Bulk statistical-analysis libraries | DEG and future statistical modules |

Images are built by the `Starter Environments` GitHub workflow. Normal pushes
and pull requests only build and validate images. Publishing to GHCR is a
manual workflow-dispatch action, so an image is never released implicitly by a
code change.

## Release rule

Each starter environment has a `VERSION` file. A manual publication uses that
version tag and the Git commit tag; it does not publish a mutable `latest` tag.
After publication, CI records the resolved digest in the workflow summary.
Use that digest in a reproducible module or Code Ocean release record.

Before the first publication from OMIX, ensure that the corresponding GHCR
package is associated with the `NIDAP-Community/OMIX` repository or grants its
GitHub Actions workflow write access. A package previously associated with
another repository, such as `OMIX_Test`, does not automatically accept writes
from OMIX.

No research or reference data belongs in a starter image. Attach or mount
versioned data assets at runtime under `/data` instead.
