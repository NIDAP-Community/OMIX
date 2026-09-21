# Bootstrap definition for the lightweight Seurat-object runtime. CI must
# capture and commit its resolved lockfile before VERSION advances past v0.
ARG BASE_IMAGE=ghcr.io/nidap-community/omix-r-base:r4.4.3-v1
FROM ${BASE_IMAGE}

LABEL org.opencontainers.image.title="OMIX r-singlecell starter"
LABEL org.opencontainers.image.description="Lightweight SeuratObject and pseudobulk runtime for OMIX modules"
LABEL org.opencontainers.image.source="https://github.com/NIDAP-Community/OMIX"

# This profile intentionally installs SeuratObject, not the full Seurat
# workflow package. OmixSeurat needs only object access, sparse matrices, and
# metadata; analytical Seurat dependencies do not belong in this environment.
RUN R -q -e "packages <- c( \
  'SeuratObject', 'optparse', 'colorspace', 'ggsci', 'RColorBrewer' \
); \
install.packages(packages, repos = 'https://cloud.r-project.org'); \
missing <- packages[!vapply(packages, requireNamespace, logical(1), quietly = TRUE)]; \
if (length(missing)) stop('Required single-cell package(s) failed to install: ', paste(missing, collapse = ', '))"

# The Core contract and bridge are installed from this exact source checkout,
# after their registry dependencies are available. They are intentionally not
# lockfile entries because they are source-controlled OMIX packages.
COPY core /tmp/Omix
COPY bridges/seurat /tmp/OmixSeurat
RUN R CMD INSTALL /tmp/Omix \
    && R CMD INSTALL /tmp/OmixSeurat \
    && rm -rf /tmp/Omix /tmp/OmixSeurat

WORKDIR /workspace
