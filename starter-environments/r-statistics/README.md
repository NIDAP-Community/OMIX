# omix-r-statistics

Shared runtime for OMIX statistical-analysis modules. It extends the pinned
`omix-r-base` R 4.4.3 image and uses Bioconductor 3.20.

## Scope

The initial statistical foundation is deliberately small:

- `limma` and `edgeR` for linear-model and voom-based bulk differential
  expression;
- `optparse` for command-line adapters.

DESeq2, `sva`, pathway packages (`fgsea`, `GSVA`, `l2p`), plotting/reporting
packages, module code, and research data do not belong here. Method-specific
stacks remain in specialised images or module-level adapters, preventing one
module's large dependency graph from becoming a prerequisite for every
statistical workflow.

## Locked dependencies

`renv.lock` records the complete CRAN and Bioconductor package set captured
from the validated CI image: R 4.4.3 and Bioconductor 3.20. The Dockerfile
uses `renv::restore()` to install those exact package versions into its
dedicated runtime library from source archives. It uses the CRAN source archive
and matching Bioconductor 3.20 repositories explicitly, rather than a mutable
package-manager endpoint.

After publication, record the immutable GHCR digest with each module release.
