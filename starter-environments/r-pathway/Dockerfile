# `r4.4.3-v1` is an immutable OMIX release tag. CI overrides this argument with
# its local validation image; release records also retain the resolved digest.
ARG BASE_IMAGE=ghcr.io/nidap-community/omix-r-base:r4.4.3-v1
FROM ${BASE_IMAGE}

ARG BIOCONDUCTOR_VERSION=3.20
ARG L2P_REF=ab389bc978441f1893414da7a07e803bea971205

LABEL org.opencontainers.image.title="OMIX r-pathway starter"
LABEL org.opencontainers.image.description="Pathway and gene-set analysis runtime for OMIX modules"
LABEL org.opencontainers.image.source="https://github.com/NIDAP-Community/OMIX"

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        libmagick++-dev \
        libpng-dev \
        zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

# This lockfile was captured from the validated CI build. Restore the exact
# CRAN and Bioconductor package set into a dedicated runtime library. Source
# restoration preserves dependency order; the binary restore path can test a
# package before its binary dependency is available.
WORKDIR /opt/omix/r-pathway
COPY renv.lock renv.lock
# Do not transform the dated CRAN source snapshot into a PPM binary endpoint.
# Source packages are installed sequentially so each package's dependencies are
# loadable during renv's post-install verification.
ENV RENV_CONFIG_PPM_ENABLED=FALSE \
    RENV_CONFIG_INSTALL_JOBS=1 \
    R_LIBS_USER=/opt/omix/r-pathway/library
RUN mkdir -p "$R_LIBS_USER" \
    && R -q -e "options(pkgType = 'source'); \
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
  lockfile = '/opt/omix/r-pathway/renv.lock', \
  library = Sys.getenv('R_LIBS_USER'), \
  repos = repos, \
  prompt = FALSE \
)"

# l2p and l2psupp are not hosted in a package repository. Their immutable
# CCBR/l2p commit is the source record for these two packages.
RUN curl --fail --location --retry 3 \
      --output /tmp/l2p_0.0-14.tar.gz \
      https://raw.githubusercontent.com/CCBR/l2p/${L2P_REF}/l2p_0.0-14.tar.gz \
    && curl --fail --location --retry 3 \
      --output /tmp/l2psupp_0.0-14.tar.gz \
      https://raw.githubusercontent.com/CCBR/l2p/${L2P_REF}/l2psupp_0.0-14.tar.gz \
    && R -q -e "install.packages(c('/tmp/l2p_0.0-14.tar.gz', '/tmp/l2psupp_0.0-14.tar.gz'), repos = NULL)" \
    && rm /tmp/l2p_0.0-14.tar.gz /tmp/l2psupp_0.0-14.tar.gz

WORKDIR /workspace
