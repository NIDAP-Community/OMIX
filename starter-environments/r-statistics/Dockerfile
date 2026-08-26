# `r4.4.3-v1` is an immutable OMIX release tag. CI overrides this argument with
# its local validation image; release records also retain the resolved digest.
ARG BASE_IMAGE=ghcr.io/nidap-community/omix-r-base:r4.4.3-v1
FROM ${BASE_IMAGE}

ARG BIOCONDUCTOR_VERSION=3.20

LABEL org.opencontainers.image.title="OMIX r-statistics starter"
LABEL org.opencontainers.image.description="Statistical analysis runtime for OMIX modules"
LABEL org.opencontainers.image.source="https://github.com/NIDAP-Community/OMIX"

# This lockfile was captured from a successful CI build of the bootstrap
# installer. Restore it into a dedicated runtime library so releases do not
# depend on a mutable package-manager endpoint.
WORKDIR /opt/omix/r-statistics
COPY renv.lock renv.lock
ENV RENV_CONFIG_PPM_ENABLED=FALSE \
    RENV_CONFIG_INSTALL_JOBS=1 \
    R_LIBS_USER=/opt/omix/r-statistics/library
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
  lockfile = '/opt/omix/r-statistics/renv.lock', \
  library = Sys.getenv('R_LIBS_USER'), \
  repos = repos, \
  prompt = FALSE \
)"

WORKDIR /workspace
