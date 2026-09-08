# Runtime guide

OMIX runtime profiles are shared OCI environments for modules in the same
scientific domain. They contain dependencies, not analysis code or research
data. Module code remains under `modules/<name>/`; module-specific additions
are declared in that module's `module.yml` overlay.

```text
r-base -> r-statistics    -> bulk statistical modules
       -> r-visualization -> plotting and filtering modules
       -> r-pathway       -> GSEA and L2P modules
```

## Choose and reproduce a runtime

Read a module's `runtime_profile` in `module.yml`, then use the corresponding
immutable image reference in
[`starter-environments/release-manifest.json`](../starter-environments/release-manifest.json).
A readable image tag is not an execution identity; record the full
`image@sha256:...` reference with each result.

For each analysis, retain:

| Item | Record |
| --- | --- |
| Scientific source | OMIX commit, module name, semantic version, and interface version |
| Runtime | Profile, immutable OCI reference, platform architecture, and lockfile SHA-256 |
| Module additions | Exact declared overlay package/version, when present |
| Invocation | Explicit CLI command and all parameters |
| Inputs and outputs | Immutable asset/version identifier or SHA-256 checksums |

The shared helper creates an effective `$OMIX_RUN/renv.lock` after restoring a
profile and module overlay. Preserve that generated lock beside the results.

## Run on a workstation or HPC

For an R installation on a workstation or shared HPC system, create one
writable runtime project per profile. The root README has the complete
[local/HPC setup and DEG example](../README.md#run-a-module-on-biowulf-or-another-shared-r-system).

For containers, mount the OMIX checkout read-only, a writable runtime project,
explicit input data, and results. This uses the immutable statistics image for
the DEG module; replace the final CLI with the selected module's documented
example.

```bash
export OMIX_ROOT=/path/to/OMIX
export OMIX_MODULE=OMIX-DEG-Analysis
export OMIX_RUN=$PWD/omix-runtime
export OMIX_IMAGE='ghcr.io/nidap-community/omix-r-statistics@sha256:1325722877fec5167d171aa766ddf7bbfd056e4999bf40fd8c1eabee495da667'
mkdir -p "$OMIX_RUN" "$PWD/input" "$PWD/results"

docker run --rm \
  -v "$OMIX_ROOT:/omix:ro" -v "$OMIX_RUN:/runtime" -w /runtime \
  "$OMIX_IMAGE" Rscript /omix/scripts/restore-omix-runtime.R \
    --module "$OMIX_MODULE" --project /runtime

docker run --rm \
  -v "$OMIX_ROOT:/omix:ro" -v "$OMIX_RUN:/runtime" \
  -v "$PWD/input:/data:ro" -v "$PWD/results:/results" -w /runtime \
  "$OMIX_IMAGE" Rscript /omix/modules/OMIX-DEG-Analysis/scripts/run_deg_analysis.R \
    --input_type table --counts /data/raw_counts.csv \
    --metadata /data/sample_metadata.csv --contrast_variable_columns Group \
    --contrasts B-A --output_dir /results
```

On HPC, pull that same image digest with Apptainer or Singularity, bind the
same four locations, and invoke the same two `Rscript` commands. For example:

```bash
apptainer pull omix-r-statistics.sif "docker://${OMIX_IMAGE}"
apptainer exec \
  --bind "$OMIX_ROOT:/omix:ro,$OMIX_RUN:/runtime,$PWD/input:/data:ro,$PWD/results:/results" \
  --pwd /runtime omix-r-statistics.sif \
  Rscript /omix/scripts/restore-omix-runtime.R \
    --module "$OMIX_MODULE" --project /runtime
```

## Change and publish a runtime

1. Pin the parent OCI digest and all non-registry source references; record
   source checksums for downloaded tarballs.
2. Update the profile lockfile from a successful validation build and bump its
   `VERSION`.
3. Run targeted CI validation and explicitly publish only the changed profile.
4. Resolve the published digest and append a new record to
   `release-manifest.json`; never modify an earlier release record.
5. Run a representative module using that exact digest before claiming a
   validated release.

The **Starter Environments** workflow supports a registry-only adoption of a
validated historical image when a package must be reassociated with this
repository. That operation must use an explicit version tag; it never creates
or replaces `latest`.

The manual **Verify Published Starter Environments** workflow checks a
published digest against its recorded lockfile and required packages. Use it
after recording a release and before relying on a historical image record.

Deployment adapters can use a separate internal runtime registry. Their
source record must independently retain the adapter commit, immutable runtime
identity or environment-release ID, and platform-validation evidence.
