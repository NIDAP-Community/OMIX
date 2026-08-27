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
| `seurat` / `OmixSeurat` | Seurat object via SeuratObject | donor-by-condition pseudobulk `omix_standard_input` |

Bridges may define an explicit conversion policy when it is documented and
tested. `OmixSeurat`, for example, aggregates raw counts for one selected cell
type by donor and condition; it does not expose individual cells as DEG
replicates.
