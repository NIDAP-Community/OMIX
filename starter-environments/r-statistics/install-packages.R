args <- commandArgs(trailingOnly = TRUE)
bioconductor_version <- if (length(args) == 1L) args[[1L]] else "3.20"

cran_repository <- "https://cran.r-project.org"
bioc_repositories <- c(
  CRAN = cran_repository,
  BioCsoft = sprintf("https://bioconductor.org/packages/%s/bioc", bioconductor_version),
  BioCann = sprintf("https://bioconductor.org/packages/%s/data/annotation", bioconductor_version),
  BioCexp = sprintf("https://bioconductor.org/packages/%s/data/experiment", bioconductor_version),
  BioCworkflows = sprintf("https://bioconductor.org/packages/%s/workflows", bioconductor_version),
  BioCbooks = sprintf("https://bioconductor.org/packages/%s/books", bioconductor_version)
)
options(repos = bioc_repositories)

# CRAN package used by OMIX capsule command-line adapters. Pin it explicitly;
# the full transitive dependency set is captured by CI before release.
remotes::install_version(
  package = "optparse",
  version = "1.8.2",
  repos = cran_repository,
  upgrade = "never"
)

# Bioconductor 3.20 is tied to R 4.4. Keep this shared runtime limited to the
# limma-voom statistical foundation. DESeq2, sva, and other method-specific
# stacks belong in a future specialised image; otherwise they impose a large
# genome-annotation dependency chain on every statistics module.
BiocManager::install(
  c("limma", "edgeR"),
  version = bioconductor_version,
  ask = FALSE,
  update = FALSE
)

required_packages <- c("optparse", "limma", "edgeR")
missing <- required_packages[!vapply(required_packages, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing) > 0L) {
  stop("Required packages failed to install: ", paste(missing, collapse = ", "))
}
message(
  "Installed OMIX statistical packages: ",
  paste(
    sprintf(
      "%s %s",
      required_packages,
      vapply(required_packages, function(package) as.character(packageVersion(package)), character(1))
    ),
    collapse = "; "
  )
)
