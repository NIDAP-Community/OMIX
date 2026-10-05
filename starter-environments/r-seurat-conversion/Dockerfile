# `r4.4.3-v2` is the proposed immutable OMIX release tag. CI overrides this
# argument with its local validation image; release records retain the resolved
# digest.
# This dedicated compatibility runtime uses full Seurat to convert serialized
# objects into portable tables for downstream OMIX modules.
ARG BASE_IMAGE=ghcr.io/nidap-community/omix-r-base@sha256:a762f2c8ae0657c9578e15d28672b3dcecb3de129edf7cbd7469c340c791547a
FROM ${BASE_IMAGE}

LABEL org.opencontainers.image.title="OMIX r-seurat-conversion starter"
LABEL org.opencontainers.image.description="Seurat compatibility and conversion runtime for OMIX portable handoffs"
LABEL org.opencontainers.image.source="https://github.com/NIDAP-Community/OMIX"

# Seurat imports packages that compile graphics, graph, and optimization
# extensions. These system headers are scoped to this compatibility image so
# downstream analytical runtimes can consume the portable conversion outputs.
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

# Full Seurat is restored here to read specialized legacy classes such as
# SCTAssay. Downstream DEG, Limma, pathway, and visualization modules consume
# the converted portable outputs. Restore from CRAN source archives: a dated
# snapshot that predates a locked version cannot resolve that package's source.
# The lock captures the registry dependency graph; Core and OmixSeurat remain
# source-controlled OMIX packages below.
RUN mkdir -p "$R_LIBS_USER" \
    && R -q -e "options(pkgType = 'source'); \
options(repos = c(CRAN = 'https://cran.r-project.org')); \
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
