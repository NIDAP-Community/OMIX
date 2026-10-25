ARG BASE_IMAGE=ghcr.io/nidap-community/omix-r-base:r4.4.3-v1
FROM ${BASE_IMAGE}

ARG BIOCONDUCTOR_VERSION=3.20

LABEL org.opencontainers.image.title="OMIX r-visualization starter"
LABEL org.opencontainers.image.description="Plotting and statistical visualization runtime for OMIX modules"
LABEL org.opencontainers.image.source="https://github.com/NIDAP-Community/OMIX"

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        cmake \
        libpng-dev \
        libuv1-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /workspace

COPY renv.lock ./renv.lock

# Restore the lockfile from CRAN and Bioconductor source archives in dependency
# order. The binary package endpoint can otherwise test a package before its
# locked dependency is available (for example, fontawesome before htmltools).
# Keep the Bioconductor release explicit: ComplexHeatmap is published there,
# not on CRAN, and must remain aligned to this R 4.4 profile.
ENV RENV_CONFIG_PPM_ENABLED=FALSE \
    RENV_CONFIG_INSTALL_JOBS=1
RUN R -q -e "options(pkgType = 'source'); \
repos <- c( \
  CRAN = 'https://cran.r-project.org', \
  BioCsoft = 'https://bioconductor.org/packages/${BIOCONDUCTOR_VERSION}/bioc', \
  BioCann = 'https://bioconductor.org/packages/${BIOCONDUCTOR_VERSION}/data/annotation', \
  BioCexp = 'https://bioconductor.org/packages/${BIOCONDUCTOR_VERSION}/data/experiment', \
  BioCworkflows = 'https://bioconductor.org/packages/${BIOCONDUCTOR_VERSION}/workflows', \
  BioCbooks = 'https://bioconductor.org/packages/${BIOCONDUCTOR_VERSION}/books' \
); \
options(repos = repos); \
renv::restore( \
  lockfile = 'renv.lock', \
  library = .libPaths()[1], \
  repos = repos, \
  prompt = FALSE \
)"
