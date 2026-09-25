# Agent team operating model

Use this guide when several people or coding agents are contributing to OMIX at
the same time. It supplements the [module contract](module-contract.md) and
[contributor guide](contributor-guide.md); those documents remain authoritative
for architecture and implementation requirements.

## Objective

The team should make independent, reviewable changes without creating a second
source of scientific truth or causing agents to overwrite each other's work.
Every task has one owner, one bounded file scope, explicit validation, and a
pull request reviewed by the coordinator.

The coordinator operates by exception rather than supervising every command.
Task owners produce the implementation, validation, status updates, and
handoff evidence for their scope. Atlas coordinates dependencies, conflicts,
review readiness, merge order, and release decisions without becoming the
default scientific reviewer, tester, documentation author, or runtime engineer.

## Team roles

Use these stable names when assigning work or asking a role-specific question.
The name identifies the responsibility, not a permanently running process, so
the underlying worker can be restarted without changing how the team refers to
the role.

| Name | Role | Primary scope |
| --- | --- | --- |
| **Atlas** | Coordinator and integrator | Backlog, ownership, reviews, merge order, and release coordination |
| **Helix** | Single-cell and differential expression | Seurat, pseudobulk, DEG, Limma, and related bridges |
| **Compass** | Pathway analysis | GSVA, GSEA, L2P, pathway databases, and pathway plots |
| **Canvas** | Visualization and reporting | Gene Boxplots, Volcano Plot, and shared visual behavior |
| **Forge** | Runtime and reproducibility | Containers, `renv`, CI, GHCR, inventories, and immutable provenance |
| **Harbor** | Deployment adapters | Code Ocean and other platform-specific integration |
| **Beacon** | Quality and documentation | Independent testing, contracts, documentation, and provenance review |

### Atlas — coordinator and integrator

The coordinator owns priorities, task boundaries, and the integration
sequence. The coordinator:

- defines each task's objective, scope, exclusions, acceptance criteria, and
  dependencies;
- assigns one owner and prevents overlapping file ownership;
- requires the task owner to maintain its issue or pull-request status and
  provide the validation evidence for its scope;
- ensures reusable scientific behavior is changed in the canonical module
  before a deployment adapter is updated;
- verifies that the required domain, runtime, deployment, and parity reviews
  occurred instead of repeating each specialist's work;
- decides merge order and requests rebases when an earlier dependency merges;
- owns repository-wide integration files and release coordination; and
- does not infer, tag, publish, or finalize an unapproved release.

The coordinator may make small integration edits, but should not silently
rewrite a worker's scientific implementation during review. Atlas retains
accountability for the state of the queue, but delegates scientific review to
the relevant domain owner, runtime evidence to Forge, platform translation to
Harbor, and independent parity review to Beacon. Atlas intervenes when work is
blocked, scopes overlap, evidence is missing, a required check fails, or a
cross-project decision is needed.

### Helix, Compass, and Canvas — scientific module agents

Divide scientific work by stable domain boundary rather than by individual
files:

| Agent | Domain | Typical scope |
| --- | --- | --- |
| **Helix** | Single-cell and differential expression | `OMIX-Seurat-Pseudobulk`, `OMIX-Limma-Analysis`, `OMIX-DEG-Analysis`, and `bridges/seurat` |
| **Compass** | Pathway analysis | L2P, GSEA, GSVA, shared pathway-data interfaces, and `OMIXPathwayPlots` |
| **Canvas** | Visualization and reporting | Gene Boxplots, Volcano Plot, and shared visualization behavior |

An agent changing scientific behavior must own the implementation, schema,
tests, README, changelog, and representative command for that bounded change.
Keep Helix assignments narrow even though its scientific pipeline is broad.

For pathway figures, Compass owns enrichment semantics, pathway selection,
score and significance mappings, and pathway-data preparation. Canvas owns
general visual grammar, themes, dimensions, wrapping, accessibility, and
exported-figure behavior. Give every cross-domain plotting task one primary
owner and name the other domain as reviewer when both concerns are affected.

### Forge — runtime and reproducibility agent

This agent owns `starter-environments/`, runtime lockfiles, container tests,
package inventories, and immutable image provenance. It packages approved
scientific code but does not change statistical behavior. Publication follows
the [runtime guide](runtime-guide.md), [versioning guide](versioning-and-releases.md),
and, when automated, the
[release automation contract](release-automation-contract.md).
Forge supplies machine-readable runtime evidence to the task and release
records; Atlas should not manually reconstruct package or digest provenance.

### Harbor — deployment-adapter agent

This agent translates a merged canonical module into a separate deployment
repository. It owns platform entry points, mounted-input discovery, UI files,
adapter documentation, and `OMIX_MODULE_SOURCE.md`. It must follow the
[deployment adapter guide](deployment-adapter-guide.md) and must not introduce
independent scientific behavior.

Several Harbor task instances may work in parallel when they use separate
adapter repositories and worktrees. Atlas still assigns one owner per adapter
and orders any shared canonical or runtime dependencies.

### Beacon — quality and documentation reviewer

This role checks module-contract compliance, tests, schemas, examples, user
documentation, generated-file exclusions, and provenance. Before an adapter
release, Beacon independently audits cross-repository parity and blocks release
when unexplained drift remains. The audit compares the adapter with its
recorded canonical commit and file hashes, separately reports lag from the
current canonical module, and checks CLI, schema, and app-panel parameter
names, types, choices, and defaults; scientific documentation claims; fixture
output equivalence; and the runtime tag plus immutable digest. Intentional
platform-only differences must be recorded in `OMIX_MODULE_SOURCE.md`.

Beacon reports drift but does not silently remediate it. Scientific owners fix
canonical defects, Harbor re-exports approved code and fixes platform
translation, Forge fixes runtime parity and provenance, and Atlas controls the
order. Scientific implementation flows only from canonical OMIX modules to
deployment repositories. The role may rotate between contributors, but should
be independent of the task author for higher-risk scientific or release
changes.

Beacon must not be the sole approver of documentation, QA tooling, or
governance that Beacon authored. A different domain owner or Atlas reviews
those changes. Domain owners author scientific documentation; Beacon checks
that it is accurate, complete, and consistent with the implementation.

## Repository and branch rules

1. Give every agent a separate Git worktree or clone. Never run two writing
   agents in the same working directory.
2. Start each task branch from the current `origin/main`.
3. Use one branch and pull request per bounded outcome, for example:

   ```text
   feature/seurat-handoff-validation
   feature/gsva-module
   investigation/gene-boxplot-aggregation
   release/r-seurat-conversion-v1
   ```

4. Assign directory ownership before editing. Shared root files, GitHub
   workflows, documentation indexes, and release manifests belong to the
   coordinator or an explicitly assigned integration agent.
5. Preserve unrelated local changes. Do not use destructive Git operations to
   make another agent's work disappear.
6. Rebase or merge the latest `origin/main` only when the coordinator requests
   it or before final review. Resolve conflicts in the task's owned scope and
   escalate cross-scope conflicts.
7. Do not commit study data, generated results, credentials, package caches, or
   large local fixtures.
8. Link a tracked work item before implementation begins. The issue is the
   transactional status record; this document is the durable summary of the
   queue and operating rules.

## Work-item lifecycle

Use these states consistently. Do not collapse a merge, platform run, and
release into one notion of completion.

| State | Meaning |
| --- | --- |
| **Backlog** | Desired work exists but has no active owner. |
| **Assigned** | Scope, owner, dependencies, and acceptance evidence are recorded. |
| **In progress** | The owner is working in an isolated branch or worktree. |
| **PR ready** | The implementation and declared validation are ready for review. |
| **Merged** | The reviewed source change is on the repository's default branch. |
| **Platform validated** | The exact merged adapter/runtime candidate passed its required external-platform run. |
| **Released** | The approved immutable tag, digest, or platform release identifier is recorded. |
| **Blocked** | Progress requires a named decision, dependency, authority, or external-state change. |

Every status update must link to durable evidence such as an issue, branch,
commit, pull request, CI run, platform run, tag, digest, or release record.

## Change classes and required review

Classify the task before assigning it so review depth matches risk.

| Change class | Primary owner | Required independent review or approval |
| --- | --- | --- |
| Documentation only | Authoring role | A different role verifies technical claims and links. |
| Adapter only | Harbor | Scientific owner confirms behavior; Beacon audits parity before release. |
| Runtime only | Forge | At least one consuming module owner validates compatibility; Beacon checks provenance. |
| Scientific patch | Helix, Compass, or Canvas | Independent domain review plus direct regression evidence. |
| Scientific default change | Scientific owner | Beacon review and explicit project-owner approval before merge or release. |
| Interface break | Scientific owner | Downstream-consumer review, version decision, Beacon review, and explicit project-owner approval. |
| Release or publication | Atlas coordinates | Required specialist gates plus explicit project-owner authorization. |

No role approves its own high-risk work alone. Atlas confirms that required
reviews exist but does not substitute coordinator judgment for scientific or
runtime evidence.

## Task assignment contract

The coordinator should give each agent a task containing:

```text
Objective:
The exact outcome required.

Owned scope:
Directories and files the agent may change.

Out of scope:
Files, modules, adapters, or behaviors that must remain unchanged.

Scientific constraints:
Defaults, legacy behavior, interfaces, and aesthetics to preserve.

Dependencies:
Branches, pull requests, runtime profiles, or upstream decisions required.

Change class:
Documentation, adapter-only, runtime-only, scientific patch, scientific
default change, interface break, or release/publication.

Required validation:
Specific tests and representative data scenarios.

Deliverable:
Feature branch, commits, pull request, and handoff report.

Release authority:
Whether the task is preparation only. Publication is never implied.
```

If the task cannot be completed within that boundary, the agent stops and asks
the coordinator to change the scope rather than expanding it independently.

## Required worker handoff

Every pull request handoff should state:

```text
Outcome:
What now works.

Files changed:
Exact paths and why they changed.

Scientific behavior:
What changed and what was intentionally preserved.

Validation:
Commands run and their results.

Not validated:
Anything that could not be tested.

Compatibility and versioning:
Interface effect, proposed version effect, and downstream consumers.

Risks or follow-up:
Open decisions and external validation.

Commit and pull request:
Immutable commit SHA and pull-request URL.
```

A green check is evidence only for the checks it actually ran. It is not by
itself proof of deployment-platform validation or release approval.

## Coordinator monitoring and local integration

The coordinator actively monitors assigned work instead of waiting for a
contributor to request status. During an active work wave, the coordinator:

1. consumes task-owner and automated status reports and focuses on blocked,
   failed, conflicting, or review-ready work;
2. alerts the project owner when a pull request is ready for review, including
   its validation evidence and unresolved limitations;
3. does not merge, publish, or release merely because checks are green; and
4. keeps independent work moving when another adapter or external platform is
   deferred or blocked.

Prefer a small number of active writing streams with non-overlapping scope.
Starting more agents is not progress when Atlas, Harbor, Beacon, or the project
owner cannot review their outputs promptly.

After the project owner merges pull requests, the coordinator verifies their
live merged state, fast-forwards the clean local `main` checkout with
`git merge --ff-only origin/main`, runs proportionate post-merge checks, and
refreshes the queue from the merged repository state. The coordinator must not
overwrite local work or assume that an IDE workspace switch changed Git state.

## Integration and release order

When work is related, the coordinator normally merges it in this order:

1. shared interfaces and bridges;
2. canonical scientific modules;
3. shared packages and plotting utilities;
4. runtime definitions and lockfiles;
5. cross-project documentation;
6. deployment adapters; and
7. explicitly approved version promotion and publication.

This order avoids repeatedly synchronizing adapters while canonical behavior
is still changing. Independent modules may merge in parallel when their file
ownership and interfaces do not overlap.

## Current next-work queue

This is a durable summary, not the transactional task system or release
authorization. Each assigned row must link to a tracked issue; the issue and
pull request carry live status and evidence. Atlas refreshes this summary when
work is assigned, blocked, merged, platform validated, or released. A running
agent session and local worktree path are temporary; issues, branches, pull
requests, commits, and validation records are authoritative. Use `Unassigned`,
`Pending`, or `Not started` instead of inferring missing state, and never treat
a merge as Code Ocean validation.

| Priority | Work item | Status | Branch/worktree | Agent name | Suggested owner | Dependency or completion evidence |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | Synchronize the DEG Analysis adapter with canonical interface 2, including `analysis_mode` and pseudobulk-manifest discovery | Draft PR open | `feature/interface2-adapter`; `OMIX-worktrees/Harbor-deg-interface2` | **Harbor** | Deployment-adapter agent with Helix review | [DEG adapter PR #1](https://github.com/NIDAP-Community/OMIX-DEG-Analysis/pull/1) exports canonical `0.4.0`/interface 2 and adds interface/input tests; Code Ocean validation is pending |
| 2 | Reconcile L2P Single and Multi app-panel names and defaults with their canonical CLIs, and determine why the deployed Code Ocean panels appear incomplete | Draft PRs open | `feature/reconcile-l2p-single-panel` / `OMIX-worktrees/Harbor-l2p-single-panel`; `feature/reconcile-l2p-multi-panel` / `OMIX-worktrees/Harbor-l2p-multi-panel` | **Harbor** | Deployment-adapter agent | [Single PR #2](https://github.com/NIDAP-Community/OMIX-L2P-Single/pull/2) and [Multi PR #2](https://github.com/NIDAP-Community/OMIX-L2P-Multi/pull/2) add panel-contract checks and document intentional demo presets; Code Ocean validation is pending |
| 3 | Add the canonical Gene Boxplots `duplicate_aggregation` control to the adapter as an advanced parameter | Merged; platform validation pending | `feature/gene-boxplots-duplicate-aggregation`; `OMIX-worktrees/Canvas-gene-boxplots-adapter` | **Canvas** | Visualization agent with Harbor review | [Gene Boxplots PR #1](https://github.com/NIDAP-Community/OMIX-Gene-Boxplots/pull/1) merged with `mean`, `sum`, and `keep`, default `mean`, canonical `1.0.0` source parity, and fixture tests; Code Ocean validation is not recorded |
| 4 | Complete canonical public schemas for L2P, GSEA, Gene Boxplots, and Volcano Plot before relying on automated adapter comparison | Backlog | Unassigned | Unassigned | Compass and Canvas, with Beacon review | Beacon's first audit found that several schemas omit public CLI controls; each scientific owner must classify controls as public, advanced, or internal and add contract tests |
| 5 | Repair deployment parameter bindings in GSEA Filters and Volcano Plot | Backlog | Unassigned | Unassigned | Harbor, with Compass/Canvas review | GSEA Filters requires a named-parameter capsule run; Volcano Plot requires canonical `resolution_dpi` support and an explicit compatibility decision for `resolution_dpi_` |
| 6 | Reconcile deployment runtime profiles and record immutable digests | Backlog | Unassigned | Unassigned | Forge | Pathway adapters must be assessed against verified `r-pathway` v2; GSEA Filters and Volcano must use or explicitly justify their canonical runtime profiles; every source record needs a tag and digest |
| 7 | Remove or explicitly archive the undocumented second GSEA Visualization implementation and document the GSEA Preranked Mouse preset | Backlog | Unassigned | Unassigned | Harbor, with Compass review | Verify that `code/GSEA_Visualization_Local_v1.R` is unused; record every intentional deployment-only hidden input or demo preset in `OMIX_MODULE_SOURCE.md` and test it |
| 8 | Add an automated adapter-contract check for canonical CLI/schema, adapter CLI, panel parameter names, and defaults | Blocked on canonical schema completion | Unassigned | Unassigned | Beacon, with Harbor remediation | CI must report source-hash drift, missing controls, stale aliases, default drift, and missing runtime provenance while allowing documented platform-managed or intentionally hidden parameters |
| 9 | Synchronize remaining deployment adapters after canonical and runtime decisions settle | Pending | Unassigned | Unassigned | Harbor | Requires merged canonical commits, passing module tests, explicit source records, adapter versions, Beacon parity review, and a platform-validation plan |
| Deferred | Resolve the `OMIX-GSEA-Preranked-Legacy` Code Ocean/GitHub sync conflict without losing the intentional hidden-MSigDB panel behavior | Deferred by project owner | Pending Code Ocean capsule work | **Harbor** | Deployment-adapter agent | Resume only when requested; preserve the capsule backup branches and attached `/data/msigdb` asset while keeping MSigDB hidden from the app panel; require a clean capsule run and tracked-tree review before sync |

Recently completed work should be removed from this queue after its completion
evidence is recorded in the relevant pull request, release manifest, and
changelog. Current examples include the canonical Gene Boxplots
duplicate-aggregation fix, Seurat handoff tests, the canonical GSVA module,
`r-seurat-conversion` publication and immutable verification, the lightweight
`MOObject` bridge and real-artifact validation, the validated `r-pathway` v2
release record, locked GSVA runtime validation, and the portable pathway-data
export contract.

## Coordinator checklist

Before assigning work:

- confirm the task belongs in a module, bridge, package, runtime, or adapter;
- create or link the tracked issue and classify the change risk;
- record dependencies and assign non-overlapping ownership;
- specify the scientific baseline and required fixtures; and
- identify whether another active branch touches the same interface.

Before merging:

- review the diff and the agent's handoff;
- confirm the required independent domain, runtime, platform, or parity reviews;
- confirm required tests and representative runs passed;
- verify schemas, README, changelog, and version decisions are consistent;
- run `Rscript tests/test-monorepo-layout.R` for structural changes; and
- record any deployment or release work that remains external.

Before publishing:

- require explicit release scope, version, immutable source commit, validation
  evidence, and approval;
- publish only the affected runtime or adapter;
- record the immutable digest or platform release identifier; and
- never move or overwrite an existing release tag or manifest record.
