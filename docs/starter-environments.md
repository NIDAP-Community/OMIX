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

Each environment's `renv.lock`, when present, records the fully resolved
package set captured from its validated image. The base image, R version,
Bioconductor release where applicable, lockfile, and non-CRAN package commits
must remain pinned for a reproducible rebuild.

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

For either target, first identify the module's `runtime_profile` in
`modules/<module>/module.yml`, then use the matching published image. The
version tags below are release identifiers; replace a tag with the resolved
`@sha256:<digest>` from the publication summary for a recorded analysis.

| Runtime profile | Published image tag |
| --- | --- |
| `r-statistics` | `ghcr.io/nidap-community/omix-r-statistics:r4.4.3-bioconductor3.20-v1` |
| `r-visualization` | `ghcr.io/nidap-community/omix-r-visualization:r4.4.3-v2` |
| `r-pathway` | `ghcr.io/nidap-community/omix-r-pathway:r4.4.3-bioconductor3.20-v1` |

### Docker

Bind-mount the OMIX checkout read-only, explicit input and output folders, and
a writable runtime folder. Provision the run folder once for the selected
module, then run its portable CLI from that folder so `renv` activates the
effective lockfile.

```bash
export OMIX_ROOT=/path/to/OMIX
export OMIX_MODULE=OMIX-DEG-Analysis
export OMIX_IMAGE=ghcr.io/nidap-community/omix-r-statistics:r4.4.3-bioconductor3.20-v1
export OMIX_RUN=$PWD/omix-runtime
mkdir -p "$OMIX_RUN" "$PWD/input" "$PWD/results"

docker run --rm \
  -v "$OMIX_ROOT:/omix:ro" \
  -v "$OMIX_RUN:/runtime" \
  -w /runtime \
  "$OMIX_IMAGE" \
  Rscript /omix/scripts/restore-omix-runtime.R \
    --module "$OMIX_MODULE" \
    --project /runtime

docker run --rm \
  -v "$OMIX_ROOT:/omix:ro" \
  -v "$OMIX_RUN:/runtime" \
  -v "$PWD/input:/data:ro" \
  -v "$PWD/results:/results" \
  -w /runtime \
  "$OMIX_IMAGE" \
  Rscript "/omix/modules/$OMIX_MODULE/scripts/run_deg_analysis.R" \
    --input_type table \
    --counts /data/raw_counts.csv \
    --metadata /data/sample_metadata.csv \
    --contrast_variable_columns Group \
    --contrasts B-A \
    --output_dir /results
```

Replace the final command and its explicit arguments with the selected
module's CLI example. For `OMIX-GSEA-Visualization-Legacy`, use the `r-pathway`
image; the preparation command installs its pinned `ComplexHeatmap` overlay
into the mounted runtime project before the analysis command runs.

### Apptainer or Singularity on HPC

Pull the same image digest, bind the same four directories, and use the two
commands above with `apptainer exec` (or `singularity exec`) in place of
`docker run`. For example:

```bash
apptainer pull omix-r-statistics.sif \
  docker://ghcr.io/nidap-community/omix-r-statistics@sha256:<digest>

apptainer exec \
  --bind "$OMIX_ROOT:/omix:ro,$OMIX_RUN:/runtime,$PWD/input:/data:ro,$PWD/results:/results" \
  --pwd /runtime \
  omix-r-statistics.sif \
  Rscript /omix/scripts/restore-omix-runtime.R \
    --module OMIX-DEG-Analysis \
    --project /runtime
```

The second `apptainer exec` command invokes the chosen module's CLI exactly as
in the Docker example.
