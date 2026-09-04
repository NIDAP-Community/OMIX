# Versioning and releases

This policy separates the versioned identities involved in an OMIX release.
It applies to canonical OMIX modules, deployment adapters, and shared runtime
images. It does not make Code Ocean or any other platform a requirement for
running OMIX locally, in containers, or on HPC.

## What is versioned

| Record | Owner | Location | Meaning |
| --- | --- | --- | --- |
| Module version | Canonical OMIX module | `modules/<name>/module.yml` | Semantic version of the portable scientific capability. |
| Interface version | Canonical OMIX module | `modules/<name>/module.yml` | Integer version of the public table, parameter, output, and CLI contract. |
| Module release tag | Canonical OMIX repository | Git tag | Immutable, validated canonical module release. Use a namespaced tag such as `module/omix-deg-analysis/v0.1.3`. |
| Adapter version/tag | Deployment repository | Git tag and `OMIX_MODULE_SOURCE.md` | Immutable deployment-adapter release; separate from the canonical module tag. |
| Platform release | Deployment platform | Adapter release record | The validated published platform release, if one exists. |
| Runtime identity | Shared runtime or adapter | OCI tag plus digest, or lockfile reference | Exact environment used for a validated run. |

These records are related but not interchangeable. A commit is not a release
tag; an adapter tag is not evidence of a platform run; and an OCI tag without
its resolved digest is not an immutable environment identity.

## Current baseline

Existing `module.yml` semantic versions are the current canonical baseline.
This repository does not retroactively label earlier commits as formal release
tags. The first namespaced module tags and adapter tags should be created only
when each corresponding module or adapter has completed its documented
validation. Until then, release-record fields must say **Pending** rather than
implying validation that did not occur.

## Module semantic versions

Use [semantic versioning](https://semver.org/) for `module.yml`:

- **Patch** (`X.Y.Z+1`): compatible bug fix that preserves the documented
  scientific method, defaults, and public contract.
- **Minor** (`X.Y+1.0`): backward-compatible feature, optional parameter, or
  additional output that does not require existing callers to change.
- **Major** (`X+1.0.0`): breaking input/output/CLI change, removed behavior,
  or deliberate change to a scientific method or default that can alter
  results.

Update `CHANGELOG.md` in the same pull request whenever behavior visible to a
module user changes. A documentation-only correction normally needs neither a
module version increment nor a tag.

## Interface versions

`interface_version` is a positive integer, initially `1`. Increase it when a
caller must change how it supplies inputs, parameters, or consumes outputs:

- removing or renaming a required column, parameter, file, or CLI option;
- changing a column's meaning, units, or data type;
- altering a required output table or file contract; or
- changing compatibility behavior in a way that makes an earlier caller
  invalid.

Do not increase it for internal refactoring, a compatible optional field, or a
scientific implementation change that leaves the public contract unchanged.
Interface and module versions may therefore change together, or independently.

## Canonical-to-adapter promotion

1. Classify the change as canonical scientific behavior, a public interface,
   deployment translation, or shared runtime.
2. For canonical work, update implementation, schema, tests, README,
   changelog, `version`, and `interface_version` as required. Run the module
   and repository checks.
3. Merge the canonical change. After its required validation, create its
   namespaced canonical module Git tag.
4. Export only the listed scientific files to the deployment adapter. Preserve
   platform UI, data discovery, output layout, and runtime setup there.
5. Update the adapter's `OMIX_MODULE_SOURCE.md` with the canonical module
   version, interface version, release tag (or pending state), and exact
   immutable source reference.
6. Run the deployment validation. Only then create an adapter tag and record
   the platform release identifier and runtime identity.

No automated process copies changes from an adapter back into canonical OMIX.
Adapter-discovered scientific or reusable-interface fixes must be deliberately
backported, reviewed, tested, and re-exported. Future automation may detect
drift and open a review item, but must not automatically overwrite either
source of record.

## Runtime records

For a shared container, record both a readable OCI tag and its resolved image
digest after the image is published. For an R/renv or HPC execution, record
the runtime profile and lockfile commit; record a module overlay separately.
Do not use `latest` as a release runtime. A Git source change alone does not
require rebuilding an unrelated runtime image.

## Release checklist

Before creating a tag or publishing a release:

1. Confirm the module version and interface version reflect the change.
2. Update the changelog, schema, README, and regression tests as needed.
3. Run the relevant module tests, representative explicit-path command, and
   `Rscript tests/test-monorepo-layout.R`.
4. Confirm adapter source records name the exact canonical version/ref and
   exported scientific files.
5. For an adapter, complete representative platform validation before adding
   the adapter tag or platform release ID.
6. Record a pinned runtime tag plus digest, or an explicit lockfile reference.
7. Keep all unavailable facts explicitly pending; never manufacture a release
   number, release ID, test status, or digest.
