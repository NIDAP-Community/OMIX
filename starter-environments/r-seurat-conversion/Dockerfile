# `r4.4.3-v1` is an immutable OMIX release tag. CI overrides this argument
# with its local validation image; release records retain the resolved digest.
# This is deliberately the only OMIX profile with full Seurat: its role is to
# convert serialized objects into portable tables.
ARG BASE_IMAGE=ghcr.io/nidap-community/omix-r-base:r4.4.3-v1
FROM ${BASE_IMAGE}

LABEL org.opencontainers.image.title="OMIX r-seurat-conversion starter"
LABEL org.opencontainers.image.description="Seurat compatibility and conversion runtime for OMIX portable handoffs"
LABEL org.opencontainers.image.source="https://github.com/NIDAP-Community/OMIX"

# Seurat imports packages that compile graphics, graph, and optimization
# extensions. These system headers belong only in this compatibility image,
# never in the lightweight analytical runtime tiers.
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        libfontconfig1-dev \
        libfreetype6-dev \
        libfribidi-dev \
        libglpk-dev \
        libgsl-dev \
        libharfbuzz-dev \
        libjpeg-dev \
        libpng-dev \
        libtiff5-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /opt/omix/r-seurat-conversion
COPY starter-environments/r-seurat-conversion/renv.lock renv.lock
ENV RENV_CONFIG_PPM_ENABLED=FALSE \
    RENV_CONFIG_INSTALL_JOBS=1 \
    R_LIBS_USER=/opt/omix/r-seurat-conversion/library

# Full Seurat is restored here only to read specialized legacy classes such as
# SCTAssay. It is not an analysis dependency for DEG, Limma, pathway, or
# visualization modules. The lock captures the registry dependency graph;
# Core and OmixSeurat remain source-controlled OMIX packages below.
RUN mkdir -p "$R_LIBS_USER" \
    && R -q -e "options(pkgType = 'source'); \
options(repos = c(CRAN = 'https://p3m.dev/cran/2025-04-10')); \
renv::restore( \
  lockfile = '/opt/omix/r-seurat-conversion/renv.lock', \
  library = Sys.getenv('R_LIBS_USER'), \
  repos = getOption('repos'), \
  prompt = FALSE \
)"

# The portable Core contract and bridge are installed from this exact OMIX
# source checkout. They are excluded from the dependency lock because their
# versions are represented by the OMIX commit used for the conversion.
COPY core /tmp/Omix
COPY bridges/seurat /tmp/OmixSeurat
RUN R CMD INSTALL --library="$R_LIBS_USER" /tmp/Omix \
    && R CMD INSTALL --library="$R_LIBS_USER" /tmp/OmixSeurat \
    && rm -rf /tmp/Omix /tmp/OmixSeurat

WORKDIR /workspace
