# Canonical OMIX Module Source

## Canonical module

- **Module:** [`<module name>`](<canonical module URL>)
- **Canonical path:** `modules/<module name>/`
- **Canonical module version:** `<module.yml version>`
- **Canonical interface version:** `<module.yml interface_version>`
- **Canonical release tag:** `<module tag, or Pending — baseline tag not yet established>`
- **Canonical source reference:** `<40-character commit SHA or immutable tag>`
- **Interface schema:** [schemas/interface.yml](<canonical schema URL>)
- **Module contract:** [OMIX module contract](https://github.com/NIDAP-Community/OMIX/blob/main/docs/module-contract.md)

## Adapter release record

| Field | Recorded value |
| --- | --- |
| Adapter version | `<semantic version, or Pending — baseline tag not yet established>` |
| Adapter release tag | `<immutable adapter tag, or Pending>` |
| Platform release | `<platform release ID/link, or Pending validation>` |
| Runtime identity | `<immutable OCI tag@digest or lockfile reference, or Pending>` |

See the canonical [versioning and release policy](https://github.com/NIDAP-Community/OMIX/blob/main/docs/versioning-and-releases.md). A source commit, an adapter tag, a platform release, and a runtime image are separate records; do not substitute one for another.

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
3. Update the canonical module/interface versions and source reference above.
4. Export the listed scientific files without unreviewed behavior changes.
5. Validate the adapter with representative platform inputs and record the
   resulting adapter tag, platform release, and immutable runtime identity
   above when they are available.

If an adapter run reveals a scientific or reusable-interface issue, backport
the fix to the canonical module before re-exporting it here.
