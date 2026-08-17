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

RUN R -q -e "BiocManager::install(version = '${BIOCONDUCTOR_VERSION}', ask = FALSE, update = FALSE); \
  install.packages(c('data.table', 'dplyr', 'ggplot2', 'optparse', 'plyr', 'scales', 'stringr', 'tidyr'), repos = 'https://cloud.r-project.org'); \
  BiocManager::install(c('fgsea', 'GSVA'), ask = FALSE, update = FALSE)"

RUN curl --fail --location --retry 3 \
      --output /tmp/l2p_0.0-14.tar.gz \
      https://raw.githubusercontent.com/CCBR/l2p/${L2P_REF}/l2p_0.0-14.tar.gz \
    && curl --fail --location --retry 3 \
      --output /tmp/l2psupp_0.0-14.tar.gz \
      https://raw.githubusercontent.com/CCBR/l2p/${L2P_REF}/l2psupp_0.0-14.tar.gz \
    && R -q -e "install.packages(c('/tmp/l2p_0.0-14.tar.gz', '/tmp/l2psupp_0.0-14.tar.gz'), repos = NULL)" \
    && rm /tmp/l2p_0.0-14.tar.gz /tmp/l2psupp_0.0-14.tar.gz

WORKDIR /workspace
