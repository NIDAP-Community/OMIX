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

The coordinator owns the work queue and integration sequence. The coordinator:

- defines each task's objective, scope, exclusions, acceptance criteria, and
  dependencies;
- assigns one owner and prevents overlapping file ownership;
- ensures reusable scientific behavior is changed in the canonical module
  before a deployment adapter is updated;
- reviews validation evidence, compatibility decisions, and documentation;
- decides merge order and requests rebases when an earlier dependency merges;
- owns repository-wide integration files and release coordination; and
- does not infer, tag, publish, or finalize an unapproved release.

The coordinator may make small integration edits, but should not silently
rewrite a worker's scientific implementation during review.

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

### Forge — runtime and reproducibility agent

This agent owns `starter-environments/`, runtime lockfiles, container tests,
package inventories, and immutable image provenance. It packages approved
scientific code but does not change statistical behavior. Publication follows
the [runtime guide](runtime-guide.md), [versioning guide](versioning-and-releases.md),
and, when automated, the
[release automation contract](release-automation-contract.md).

### Harbor — deployment-adapter agent

This agent translates a merged canonical module into a separate deployment
repository. It owns platform entry points, mounted-input discovery, UI files,
adapter documentation, and `OMIX_MODULE_SOURCE.md`. It must follow the
[deployment adapter guide](deployment-adapter-guide.md) and must not introduce
independent scientific behavior.

### Beacon — quality and documentation reviewer

This role checks module-contract compliance, tests, schemas, examples, user
documentation, generated-file exclusions, and provenance. It reports gaps; it
does not perform an unrequested broad refactor. The role may rotate between
contributors, but should be independent of the task author for higher-risk
scientific or release changes.

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

This is a planning queue, not release authorization. The coordinator should
move each item into a tracked issue before assigning it and update this section
as priorities change.

| Priority | Work item | Agent name | Suggested owner | Dependency or completion evidence |
| --- | --- | --- | --- | --- |
| 1 | Promote and publish `r-seurat-conversion` as the first validated non-bootstrap release | **Forge** | Runtime agent | Green committed-lockfile and raw-count, Harmony-layer, and SCT-layer conversion tests; approved version; immutable digest and manifest record |
| 2 | Validate Seurat pseudobulk outputs through the raw-count DEG and continuous-expression Limma paths | **Helix** | Single-cell/DEG agent | Representative end-to-end fixtures, matching sample metadata, manifests, and stable output schemas |
| 3 | Build the GSVA canonical module from the existing template with mild cleanup | **Compass** | Pathway agent | Template provenance, explicit-path CLI, schema, focused tests, README, and changelog |
| 4 | Determine how Gene Boxplots combines repeated gene identifiers | **Canvas** | Visualization agent | Trace current behavior, document whether values are summed or averaged, and add a fixture-based regression test before changing behavior |
| 5 | Assess a lightweight `MOObject` bridge | **Helix** | Bridge agent | Confirm the released object API and required generics without introducing full MOSuite as a dependency |
| 6 | Specify a one-way pathway-database export for local, HPC, Code Ocean, and on-prem use | **Compass** | Pathway/data agent | Versioned geneset and membership schema, provenance, organism and identifier fields, and immutable export artifact |
| 7 | Synchronize deployment adapters after canonical module changes settle | **Harbor** | Deployment-adapter agent | Merged canonical commits, passing module tests, updated source records, and platform validation plan |

## Coordinator checklist

Before assigning work:

- confirm the task belongs in a module, bridge, package, runtime, or adapter;
- record dependencies and assign non-overlapping ownership;
- specify the scientific baseline and required fixtures; and
- identify whether another active branch touches the same interface.

Before merging:

- review the diff and the agent's handoff;
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
