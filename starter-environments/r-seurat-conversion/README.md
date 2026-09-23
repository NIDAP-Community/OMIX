# r-seurat-conversion

`r-seurat-conversion` is the one OMIX runtime profile allowed to install the
full Seurat package. Its responsibility is deliberately narrow: read current
or legacy serialized Seurat objects, including specialized classes such as
`SCTAssay`, and write portable matrices, aligned metadata, and a provenance
manifest for downstream OMIX modules.

It serves `OMIX-Seurat-Pseudobulk`. It is not a general single-cell analysis
environment and must not become a dependency of DEG, Limma, pathway, or
visualization modules.

## Conversion boundary

The runtime may read:

- raw `RNA/counts` for count-sum pseudobulk;
- gene-level SCWorkflow `Harmony/data` for donor-level corrected-expression
  means; and
- legacy or current Seurat `SCT/data` for donor-level SCTransform means.

It must emit the portable files and `Pseudobulk_Manifest.dcf` declared by the
module. Downstream modules read those tables; they do not open a Seurat object
or install Seurat.

The Harmony embedding (`reductions$harmony@cell.embeddings`) is not a
gene-expression matrix and is never a conversion target.

## Bootstrap status

This initial definition is `v0` and is not publishable. Its candidate
`renv.lock` is pinned to R 4.4.3 and the known working Seurat 5.3.0 stack. The
targeted Linux CI build generates and serializes a synthetic object with an
`SCTAssay`, then verifies the supported RNA, Harmony-assay, and SCT-assay
conversions. Only after that evidence is recorded on the intended source
commit may a maintainer change `VERSION` to `v1` and publish a
digest-qualified image record.
