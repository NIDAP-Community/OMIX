# hash:sha256:135336cd2c28570812ddd6cc33e31c075e1674c8c886c8a6717c1692bac673dd
ARG REGISTRY_HOST
FROM $REGISTRY_HOST/codeocean/mosuite:v0.3.2

ARG DEBIAN_FRONTEND=noninteractive
ARG GIT_ASKPASS
COPY git-ask-pass /

ARG RCACHE_OPTIONS
RUN echo $RCACHE_OPTIONS >> $(Rscript -e 'cat(R.home())')/etc/Rprofile.site
RUN Rscript -e 'remotes::install_version("getopt", "1.21.1")' \
    && Rscript -e 'remotes::install_version("optparse", "1.8.2")'

COPY postInstall /
RUN --mount=type=secret,id=secrets . /run/secrets/secrets \
    && /postInstall
