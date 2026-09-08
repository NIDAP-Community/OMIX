# Release automation contract

This document governs an automated agent that proposes, prepares, or
finalizes an OMIX module or deployment-adapter release. It supplements the
[versioning and release policy](versioning-and-releases.md); where they differ,
the versioning policy wins.

It is platform-neutral. It applies equally to a local tool, CI workflow, or
orchestrated agent, and it does not require any particular deployment service.

## Non-negotiable principles

An automated workflow must preserve these invariants:

- The canonical module owns scientific behavior and public interfaces. An
  adapter owns platform translation only.
- A version number is an explicit release decision, never an inference from
  file paths or a diff.
- Evidence is tied to the immutable commit being tagged. A successful run of a
  different commit is not release evidence.
- A source commit, canonical tag, adapter tag, platform release, and runtime
  identity are separate facts and must be recorded separately.
- The workflow is idempotent. Repeating a completed request is a no-op only
  when every tag already points to the requested commit; otherwise it fails.
- The workflow never force-pushes, deletes or moves a tag, rewrites history,
  replaces a source record, or copies scientific changes from an adapter into
  canonical OMIX.

## Automation modes

| Mode | Permitted behavior | Prohibited behavior |
| --- | --- | --- |
| `plan` | Read the request and repository state; report the exact files, versions, tags, checks, and missing evidence. | Writing files, opening a pull request, tagging, publishing, or changing an environment. |
| `prepare` | Create a branch or pull request containing explicitly requested metadata, changelog, schema, and source-record updates; run declared checks; attach their results. | Merging, tagging, publishing an image, claiming platform validation, or changing scientific code beyond an approved request. |
| `finalize` | Create annotated canonical and/or adapter tags at the approved immutable commits; update a release record only when the required evidence and approval are present. | Retagging, force-updating, merging, inventing an ID/digest, publishing an unapproved release, or expanding scope beyond the request. |

Use `plan` by default. `prepare` and `finalize` require an explicit structured
request conforming to [the release-request schema](schemas/release-request.schema.json).

## Required structured request

Store a request as JSON based on
[templates/release-automation/release-request.json](../templates/release-automation/release-request.json).
It must include:

| Field | Required for | Rule |
| --- | --- | --- |
| `request_id` | All modes | Stable, unique identifier used for audit and idempotency. |
| `mode` | All modes | Exactly `plan`, `prepare`, or `finalize`. |
| `canonical` | All modes | Module name, current/proposed semantic version, current/proposed interface version, change class, rationale, and source commit. |
| `validations` | `prepare`, `finalize` | Command, result, evidence URI or artifact, and the exact commit tested. |
| `approval` | `finalize` | Human approval identity, timestamp, and approved source commit. |
| `adapters` | Adapter work | Repository, adapter version, adapter source commit, exported-file verification, and platform-validation record. |
| `runtime` | Finalized release | Immutable OCI tag plus digest, or a lockfile/overlay reference; a pending value needs a reason. |

`canonical.source_ref`, every validation `source_ref`, and the canonical tag
target must be the same full 40-character commit SHA. For an adapter,
`adapter.source_ref`, the adapter tag target, and the source-record commit
must likewise agree.

## Version decision is supplied, not guessed

The request author supplies `change_class`, `proposed_version`, and
`proposed_interface_version`. The agent validates that decision against the
[versioning policy](versioning-and-releases.md), but does not choose it.

| Requested change | Required check |
| --- | --- |
| `documentation` | Module and interface versions are unchanged; no module/adapter tag is created. |
| `patch` | Proposed version is the next patch version; interface version is unchanged. |
| `minor` | Proposed version is the next minor version; interface version is unchanged unless an explicit compatible contract versioning policy later requires it. |
| `major` | Proposed version is the next major version; confirm documented migration/compatibility handling. |
| `interface_break` | Proposed module version is major and proposed interface version increases. |
| `adapter_only` | Canonical versions are unchanged; adapter version decision and platform-validation plan are explicit. |
| `runtime_only` | No module version/tag unless the request separately establishes a user-visible module or adapter release. |

The workflow stops if the requested numbers violate this table, duplicate an
existing incompatible tag, or cannot be compared unambiguously with the
current module metadata.

## Validation and approval gates

Before a canonical tag, the workflow must verify:

1. The module source commit is reachable from the approved default branch and
   has a clean tree.
2. `module.yml`, schema, README, and changelog agree with the supplied
   versions and intended change.
3. The module’s direct tests, representative explicit-path command, and
   `Rscript tests/test-monorepo-layout.R` passed against the tag target.
4. The request contains immutable evidence locations or stored artifacts for
   those checks.
5. The release approval names that exact source commit.

Before an adapter tag, the workflow must additionally verify:

1. The required canonical tag exists and resolves to the documented canonical
   source commit.
2. Every exported scientific file has the documented checksum or byte-for-byte
   comparison against that canonical source.
3. `OMIX_MODULE_SOURCE.md` names the canonical versions, canonical tag,
   canonical source commit, proposed adapter version, and adapter tag.
4. Representative platform validation succeeded for the adapter source commit;
   its evidence identifies the run and date. A published platform release ID
   may remain pending only when its absence is explicitly recorded.
5. Runtime identity is recorded, or the request contains a specific pending
   reason. The agent must never fabricate an OCI digest or lockfile reference.
6. A human approval names the adapter source commit and requested tag.

## Allowed file changes in `prepare`

Unless a human-approved pull request explicitly includes a broader scope, the
agent may modify only:

- the affected module’s `module.yml`, `CHANGELOG.md`, README, schema, tests,
  and files listed by the request;
- the adapter’s `OMIX_MODULE_SOURCE.md`, README, app-panel metadata, and files
  explicitly listed by the request; and
- generated release notes or validation artifacts that the repository’s
  `.gitignore` and data policy permit.

The agent must present a file-by-file change summary before finalization. It
must stop if unrelated scientific files, real data, credentials, package
caches, generated results, or untracked user files would be staged.

## Tagging rules

- Canonical module tags use `module/<module-name>/vX.Y.Z`, for example
  `module/omix-deg-analysis/v0.1.3`.
- Adapter tags use `vX.Y.Z` within that adapter repository.
- Tags are annotated and point directly to the approved immutable commit.
- Existing tags are immutable. If a tag exists at a different commit, fail and
  require a new version; never delete, move, or force-push it.
- Creating a Git tag and publishing a hosted release are separate actions. A
  hosted release requires an additional explicit request.

## Required audit output

Every mode emits a durable summary containing the request ID, actor, UTC
timestamps, source commits, versions, exact commands, validation artifact
links, checksums, tags created or reused, pending facts, and all stop reasons.
No token, credential, raw data path, or private result is included in this
summary.

## Stop conditions

The workflow must stop for human review when any of the following applies:

- missing, conflicting, stale, or unverified validation evidence;
- a change to a scientific default, statistical method, or public contract
  without an explicit supplied version decision and rationale;
- an adapter scientific export that differs from its claimed canonical source;
- an ambiguous adapter, source file, input, output, environment, or runtime;
- an existing tag at a different commit, a non-fast-forward operation, or a
  request to rewrite/delete history;
- a missing approval, or approval for a different source commit;
- a requested image publication, platform publication, or hosted release not
  explicitly authorized; or
- an attempt to stage real data, generated outputs, credentials, or another
  contributor’s unrelated work.

When stopped, the agent reports the evidence it found, the exact unmet gate,
and the smallest human decision needed to continue. It does not retry by
loosening a rule.
