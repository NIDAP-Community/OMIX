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

The `r4.4.3-v2` candidate retains that registry dependency lock and installs
OmixSeurat 0.3.1 from the same OMIX source commit used to build the image. Its
targeted Linux CI build generates and serializes a synthetic object with a
legacy slot-based `Harmony/data` assay and an `SCTAssay`, then verifies the
supported RNA, Harmony-assay, and SCT-assay conversions. The v1 image remains
immutable and must not be retagged or overwritten.

The image inherits the verified r-base v1 parent by its immutable OCI digest,
not by a mutable readable tag. CI replaces that parent only when it is
simultaneously validating a changed local r-base candidate.

After publishing, record the immutable GHCR digest in
`starter-environments/release-manifest.json` and use that digest-qualified
reference for reproducible scientific runs.
