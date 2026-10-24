# Portable OMIX Application Template

Copy this directory into a new repository only after reading
`docs/portable-application-guide.md`. Replace every angle-bracket placeholder
before publishing. This template contains distribution and orchestration code;
canonical scientific code remains in OMIX.

Required additions in the new repository:

- `container/Dockerfile` based on the module's pinned OMIX GHCR runtime digest;
- `container/entrypoint.sh` that permits only `/data` inputs and `/output`
  artifacts;
- `src/` containing a byte-identical canonical export and a thin wrapper;
- `OMIX_MODULE_SOURCE.md` with the complete source map and SHA-256 values;
- a public fixture plus expected results and smoke test; and
- a README with Docker, Singularity/Apptainer, and HPC examples.
