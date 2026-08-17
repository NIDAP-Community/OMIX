# omix-r-pathway

Shared runtime for pathway and gene-set modules, including GSEA, GSVA, and
L2P. It extends `omix-r-base` with a fixed Bioconductor release, `fgsea`,
`GSVA`, and the CCBR `l2p` packages pinned to a Git commit.

It deliberately does not include MSigDB or other research data. Supply those
assets at runtime under `/data`.

## Local and HPC paths

All consumers should mount their input and output folders at the same paths:

```text
host input directory  -> /data
host output directory -> /results
```

After publication, use the immutable image digest for a release. For example:

```bash
apptainer pull gsea-pathway.sif docker://ghcr.io/nidap-community/omix-r-pathway@sha256:<digest>
```
