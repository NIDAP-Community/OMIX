ARG BASE_IMAGE=ghcr.io/nidap-community/omix-r-base:latest
FROM ${BASE_IMAGE}

ARG BIOCONDUCTOR_VERSION=3.20
ARG L2P_REF=ab389bc978441f1893414da7a07e803bea971205

LABEL org.opencontainers.image.title="OMIX r-pathway starter"
LABEL org.opencontainers.image.description="Pathway and gene-set analysis runtime for OMIX modules"

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
ENV R_LIBS_USER=/opt/omix/r-pathway/library
RUN mkdir -p "$R_LIBS_USER" \
    && R -q -e "options(pkgType = 'source'); renv::restore( \
  lockfile = '/opt/omix/r-pathway/renv.lock', \
  library = Sys.getenv('R_LIBS_USER'), \
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
