# omix-r-statistics

Bootstrap shared runtime for OMIX statistical-analysis modules. It extends the
pinned `omix-r-base` R 4.4.3 image and uses Bioconductor 3.20.

## Scope

The initial statistical foundation is deliberately small:

- `limma` and `edgeR` for linear-model and voom-based bulk differential
  expression;
- `DESeq2` for count-model differential expression where a module selects that
  method;
- `sva` for surrogate-variable and ComBat batch-adjustment workflows; and
- `optparse` for Code Ocean-compatible command-line adapters.

Pathway packages (`fgsea`, `GSVA`, `l2p`), plotting/reporting packages, module
code, and research data do not belong here. They remain in specialized images
or module-level adapters.

## Bootstrap-release gate

`VERSION` is intentionally `v0`. It must not be published or registered as a
Code Ocean Starter Environment. The first CI build uploads an exact package
inventory and an `renv.lock` artifact. Review and commit that lockfile, replace
the bootstrap installer with `renv::restore()`, then set `VERSION` to a new
publishable `v1` tag. This makes the first released image reproducible without
using a mutable package-manager endpoint.

After publication, record the immutable GHCR digest with each capsule release.
