# Runtime reproducibility

This document defines the minimum record required to reproduce an OMIX run on
a workstation, an HPC system, or another container-capable service. It is
platform-neutral: the portable module and its explicit input/output paths are
the scientific source of truth.

## Two related promises

There are two different levels of reproducibility:

1. **Execution reproducibility** means a prior result can be re-run with the
   exact published OCI image, module commit, effective R lockfile, inputs, and
   command. This is the requirement for an analysis record.
2. **Build reproducibility** means a fresh image build resolves the same R,
   system, and non-registry dependencies. The Dockerfile, lockfile, pinned
   parent image, package source references, and source checksums support that
   goal for a new runtime release.

An image tag alone is not an immutable execution identity. Use the
digest-qualified reference in
[`starter-environments/release-manifest.json`](../starter-environments/release-manifest.json).

## Record for every analysis

Store the following with each result directory or electronic notebook:

| Item | Required record |
| --- | --- |
| Scientific source | OMIX Git commit, module name, module version, and interface version |
| Runtime | Runtime profile, full immutable OCI reference (`image@sha256:...`), platform architecture, and lockfile SHA-256 |
| Module additions | Declared module runtime overlay and its exact package version, if applicable |
| Invocation | Exact portable CLI command and all parameters |
| Inputs | Immutable asset/version identifier where available, plus SHA-256 of each input file or an equivalent provenance manifest |
| Outputs | SHA-256 of primary tables and figures, creation time in UTC, and tool/session information |

The `scripts/restore-omix-runtime.R` helper creates the effective lockfile in
the writable runtime project. Preserve that `$OMIX_RUN/renv.lock` with the
result: it includes the selected shared profile and any module-specific
overlay.

## Run an existing published image

Use the release manifest as the source of immutable image references. For
example, a DEG run uses the `r-statistics` reference rather than a tag alone:

```bash
export OMIX_IMAGE='ghcr.io/nidap-community/omix-r-statistics@sha256:1325722877fec5167d171aa766ddf7bbfd056e4999bf40fd8c1eabee495da667'
```

Then follow the explicit-path setup and invocation in
[Starter environments](starter-environments.md). The same digest can be
pulled by Docker or converted to an Apptainer/Singularity image for HPC use.

## Releasing a changed runtime

A change to a runtime definition is not an update to an already-published
image. For a new runtime release:

1. Pin the parent OCI digest and every non-registry source; record checksums
   for downloaded tarballs.
2. Update the profile lockfile from a successful validation build and bump the
   profile `VERSION`.
3. Run targeted CI validation and publish only through the explicit manual
   release workflow.
4. Resolve the resulting OCI digest and add a new record to the release
   manifest. Never alter a prior record.
5. Validate a representative portable module run using that exact digest
   before claiming a module or adapter release.

Deployment adapters may use a separate internal runtime registry. Their
source record must independently capture the adapter commit, its immutable
runtime identity or environment release identifier, and platform validation.
Do not substitute a similarly named public image digest for that evidence.

## Current release status

The manifest is authoritative for the execution identities of currently
published shared images. It deliberately marks historical image-release facts
that were not recorded at publication as pending rather than reconstructing
them by guesswork. The public `r-statistics` image package set was verified
against its committed lockfile on 2026-09-08. The visualization and pathway
package-set checks remain required before treating their current locks as
independently re-verified evidence.
