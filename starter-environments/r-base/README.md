# omix-r-base

Common R runtime for OMIX environments. It intentionally contains no
module-specific analysis packages or data.

The initial base uses R 4.4.3 pinned to an OCI digest. Pin the published image
digest in downstream release manifests rather than relying on a mutable image
tag.
