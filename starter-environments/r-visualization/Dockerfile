# The bootstrap definition is deliberately tagged `v0` and must not be
# published. CI captures its fully resolved lockfile; the first release will
# restore that lockfile and use a `v1` version tag.
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

RUN R -q -e "packages <- c( \
  'dplyr', 'tidyr', 'ggplot2', 'ggrepel', 'ggbeeswarm', 'broom', \
  'multcomp', 'multcompView', 'RColorBrewer', 'stringr', 'optparse', \
  'patchwork', 'pheatmap', 'plotly' \
); \
install.packages(packages, repos = 'https://cloud.r-project.org'); \
missing <- packages[!vapply(packages, requireNamespace, logical(1), quietly = TRUE)]; \
if (length(missing)) stop('Required visualization package(s) failed to install: ', paste(missing, collapse = ', '))"

WORKDIR /workspace
