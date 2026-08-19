ARG BASE_IMAGE=rocker/r-ver:4.4.3@sha256:3dae5d2eeddf74f10e0a81fb6b7ae350295e288000304f438b844b2c1e00fe2c
FROM ${BASE_IMAGE}

LABEL org.opencontainers.image.title="OMIX r-base starter"
LABEL org.opencontainers.image.description="Base R runtime for OMIX modules"
LABEL org.opencontainers.image.source="https://github.com/NIDAP-Community/OMIX"

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        git \
        libcurl4-openssl-dev \
        libssl-dev \
        libxml2-dev \
    && rm -rf /var/lib/apt/lists/*

RUN R -q -e "install.packages(c('BiocManager', 'remotes', 'renv', 'jsonlite', 'yaml'), repos = 'https://cloud.r-project.org')"

WORKDIR /workspace
