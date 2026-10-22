# r-seurat-conversion

`r-seurat-conversion` is the dedicated OMIX compatibility and conversion
runtime for current or legacy serialized Seurat objects, including specialized
classes such as `SCTAssay`. It writes portable matrices, aligned metadata, and
a provenance manifest for downstream OMIX modules.

It serves `OMIX-Seurat-Pseudobulk` as a purpose-built object-conversion
environment. Downstream DEG, Limma, pathway, and visualization modules consume
the portable outputs rather than the serialized Seurat object.

## Conversion boundary

The runtime may read:

- raw `RNA/counts` for count-sum pseudobulk;
- gene-level SCWorkflow `Harmony/data` for donor-level corrected-expression
  means; and
- legacy or current Seurat `SCT/data` for donor-level SCTransform means.

It emits the portable files and `Pseudobulk_Manifest.dcf` declared by the
module. Downstream modules read those tables rather than opening the Seurat
object directly.

The Harmony embedding (`reductions$harmony@cell.embeddings`) is not a
gene-expression matrix and is excluded from the supported conversion inputs.

## Release contract

The initial published version was `r4.4.3-v1`. Its committed `renv.lock` is
pinned to R 4.4.3 and the known working Seurat 5.3.0 stack.

The published `r4.4.3-v2` image remains immutable and records OmixSeurat
0.3.1 in the release manifest. The current source profile retains the same
registry dependency lock, then installs OmixSeurat from the checked-out OMIX
bridge source. Its non-published candidate validation therefore installs
OmixSeurat 0.4.0 and verifies both the legacy RNA, Harmony-assay, and
SCT-assay conversions and a selected/all-cell-type Pseudobulk collection
fixture. A source candidate is not a revision of the published v2 image.
The shared serialized-conversion fixture receives its expected OmixSeurat
version explicitly: candidate CI supplies the source-built bridge version,
while published-image verification reads the version recorded for that image
in the release manifest.

This candidate-validation change does not alter `VERSION`, publish an image,
or amend `release-manifest.json`. A separately authorized release task must
choose a new runtime version, publish it, resolve its immutable digest, and
append a new release-manifest record before this source profile can be used as
a released runtime.

The image inherits the verified r-base v1 parent by its immutable OCI digest,
not by a mutable readable tag. CI replaces that parent only when it is
simultaneously validating a changed local r-base candidate.

After publishing, record the immutable GHCR digest in
`starter-environments/release-manifest.json` and use that digest-qualified
reference for reproducible scientific runs.
