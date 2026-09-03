ARG BASE_IMAGE=ghcr.io/nidap-community/omix-r-base:r4.4.3-v1
FROM ${BASE_IMAGE}

LABEL org.opencontainers.image.title="OMIX r-visualization starter"
LABEL org.opencontainers.image.description="Plotting and statistical visualization runtime for OMIX modules"
LABEL org.opencontainers.image.source="https://github.com/NIDAP-Community/OMIX"

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        cmake \
        libuv1-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /workspace

COPY renv.lock ./renv.lock

# Restore the lockfile from CRAN source archives in dependency order. The
# binary package endpoint can otherwise test a package before its locked
# dependency is available (for example, fontawesome before htmltools).
ENV RENV_CONFIG_PPM_ENABLED=FALSE \
    RENV_CONFIG_INSTALL_JOBS=1
RUN R -q -e "options(pkgType = 'source'); \
repos <- c(CRAN = 'https://cran.r-project.org'); \
options(repos = repos); \
renv::restore( \
  lockfile = 'renv.lock', \
  library = .libPaths()[1], \
  repos = repos, \
  prompt = FALSE \
)"
