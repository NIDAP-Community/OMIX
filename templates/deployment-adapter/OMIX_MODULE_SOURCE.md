# Canonical OMIX Module Source

## Canonical module

- **Module:** [`<module name>`](<canonical module URL>)
- **Canonical path:** `modules/<module name>/`
- **Released source reference:** `<Git tag or commit>`
- **Interface schema:** [schemas/interface.yml](<canonical schema URL>)
- **Module contract:** [OMIX module contract](https://github.com/NIDAP-Community/OMIX/blob/main/docs/module-contract.md)

## Exported scientific files

| Canonical file | Adapter copy | Purpose |
| --- | --- | --- |
| `R/<function>.R` | `code/functions/<function>.R` | <scientific implementation> |

## Ownership

The canonical module owns scientific functions, portable CLI behavior, schemas,
tests, and user-facing scientific documentation. This adapter owns deployment
UI, input discovery, result paths, runtime setup, and the platform entry
point.

## Synchronization procedure

1. Make reusable scientific or interface changes in the canonical module.
2. Update its tests, schema, README, and changelog; validate the module.
3. Record the released Git reference above.
4. Export the listed scientific files without unreviewed behavior changes.
5. Validate the adapter with representative platform inputs and record the
   result in the adapter release notes or pull request.

If an adapter run reveals a scientific or reusable-interface issue, backport
the fix to the canonical module before re-exporting it here.
