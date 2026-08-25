# Bootstrap image: CI captures the full dependency lockfile before the first
# publishable release is created. Do not publish VERSION v0 to GHCR.
ARG BASE_IMAGE=ghcr.io/nidap-community/omix-r-base:r4.4.3-v1
FROM ${BASE_IMAGE}

ARG BIOCONDUCTOR_VERSION=3.20

LABEL org.opencontainers.image.title="OMIX r-statistics starter"
LABEL org.opencontainers.image.description="Statistical analysis runtime for OMIX modules"
LABEL org.opencontainers.image.source="https://github.com/NIDAP-Community/OMIX"

COPY install-packages.R /opt/omix/r-statistics/install-packages.R
RUN Rscript /opt/omix/r-statistics/install-packages.R "$BIOCONDUCTOR_VERSION"

WORKDIR /workspace
