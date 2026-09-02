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

RUN R -q -e "renv::restore( \
  lockfile = 'renv.lock', \
  library = .libPaths()[1], \
  prompt = FALSE \
)"
