ARG BASE_IMAGE=ghcr.io/nidap-community/omix-r-pathway:latest
FROM ${BASE_IMAGE}

LABEL org.opencontainers.image.title="OMIX GSEA Preranked Legacy"
LABEL org.opencontainers.image.description="Portable runtime for the OMIX GSEA preranked module"

WORKDIR /code
COPY code/ /code/
RUN chmod +x /code/run

ENTRYPOINT ["/code/run"]
