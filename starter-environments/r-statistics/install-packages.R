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

# Bioconductor 3.20 is tied to R 4.4. These are the shared statistical
# foundations; module-specific scientific packages stay with their module.
BiocManager::install(
  c("limma", "edgeR", "DESeq2", "sva"),
  version = bioconductor_version,
  ask = FALSE,
  update = FALSE
)

required_packages <- c("optparse", "limma", "edgeR", "DESeq2", "sva")
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
