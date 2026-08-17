# Portable GSEA container

This is the module-specific overlay on `omix-r-pathway`. It is intended for
local Docker and HPC use. Build from the module root once a published
`omix-r-pathway` image is available:

```bash
docker build -f container/Dockerfile -t omix-gsea-preranked:dev .
```

Run with Code Ocean-compatible paths:

```bash
docker run --rm \
  -v /path/to/input:/data:ro \
  -v /path/to/results:/results \
  omix-gsea-preranked:dev \
  --deg_table /data/DEG_Analysis.csv \
  --pathways_database /data/pathways.rds
```

For a release, replace mutable tags with immutable image digests.
