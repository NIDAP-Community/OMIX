# OMIX Bridge Packages

Bridge packages translate a supported external data-object ecosystem into an
OMIX portable contract. They are optional extensions, not scientific modules
and not dependencies of `core/`.

Each bridge is a separate R package under `bridges/<ecosystem>/`. It may depend
on both `Omix` and the external ecosystem package, and must return a documented
portable structure rather than exposing ecosystem-specific objects to an OMIX
module.

| Bridge | External ecosystem | Output |
| --- | --- | --- |
| `mosuite` / `OmixMOSuite` | MOSuite MOO | `omix_standard_input` |

Future bridges—for example, a Seurat pseudobulk bridge—belong here only after
their conversion and scientific policy have been explicitly specified and
tested.
