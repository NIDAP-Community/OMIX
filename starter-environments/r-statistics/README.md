# omix-r-statistics

Bootstrap shared runtime for OMIX statistical-analysis modules. It extends the
pinned `omix-r-base` R 4.4.3 image and uses Bioconductor 3.20.

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

## Bootstrap-release gate

`VERSION` is intentionally `v0`. It must not be published or registered for
production use. The first CI build uploads an exact package
inventory and an `renv.lock` artifact. Review and commit that lockfile, replace
the bootstrap installer with `renv::restore()`, then set `VERSION` to a new
publishable `v1` tag. This makes the first released image reproducible without
using a mutable package-manager endpoint.

After publication, record the immutable GHCR digest with each module release.
