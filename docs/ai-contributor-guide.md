# AI Contributor Guide

This guide gives an AI coding assistant a repeatable workflow for contributing
to OMIX. It complements the [developer guide](developer-guide.md) and the
[module contract](module-contract.md); it does not override them.

## Purpose and authority

OMIX is the canonical home for reusable, platform-neutral scientific behavior.
A deployment repository may translate a module for a particular environment,
but it is not a competing scientific source of truth.

Use this precedence order when planning a change:

1. The current user request and any explicit project decision.
2. The [module contract](module-contract.md).
3. The [developer guide](developer-guide.md).
4. The affected module's `module.yml`, schema, tests, changelog, and README.
5. This guide and the [module README guide](module-readme-guide.md).

When evidence conflicts or the requested scope is unclear, inspect first and
ask for direction rather than making an architectural assumption.

## Start every task with discovery

Before editing, inspect the repository and the smallest relevant scope:

```bash
git status --short --branch
git log -1 --oneline
sed -n '1,220p' modules/<module>/module.yml
sed -n '1,260p' modules/<module>/schemas/interface.yml
rg --files modules/<module>
```

Read the module README and its direct tests before modifying scientific code.
When a deployment repository is also involved, inspect its Git state and its
link back to the canonical module. Preserve unrelated user changes in a dirty
worktree.

## Classify the change

| Change type | Owner | Typical files |
| --- | --- | --- |
| Scientific algorithm, default, reusable parameter, table contract, or portable CLI | Canonical module | `R/`, `scripts/`, `schemas/`, `tests/`, `README.md`, `CHANGELOG.md`, `module.yml` as needed |
| External-object extraction or conversion | Optional bridge | `bridges/<ecosystem>/` package code, tests, and documentation |
| Deployment UI, mounted-input discovery, output location, runtime entry point, or environment overlay | Deployment repository | Adapter files only |
| Dependency used by more than one module in a scientific domain | Shared runtime | `starter-environments/<profile>/` and its lockfile/Dockerfile |

If an adapter-discovered issue changes scientific behavior or a reusable
interface, fix and validate the canonical module, then export the released
scientific implementation back to the adapter.

For adapter-specific creation, documentation, and validation requirements, use
the [deployment adapter guide](deployment-adapter-guide.md). Every separate
adapter checkout must carry its own `AGENTS.md`; it does not inherit this
repository's instructions.

## Modify a canonical module

For a scientific or reusable-interface change:

1. Update the implementation under `R/` and the explicit-path entry point
   under `scripts/` when its interface changes.
2. Update `schemas/interface.yml` for every public input, parameter, and
   output change.
3. Add or update a direct regression test. Test a new default and a relevant
   failure path when practical.
4. Update the module README using the
   [README guide](module-readme-guide.md), and add a changelog entry for
   externally visible behavior.
5. Apply the [versioning policy](versioning-and-releases.md): update the
   semantic module version for an externally visible behavior change and the
   interface version when the public contract changes. Then update
   `module.yml` for any identity, runtime-profile, data-policy, or adapter
   registry change.

Do not hard-code deployment paths such as mounted input or output directories
in canonical code. A module must work from explicit paths in local R, Docker,
HPC, and workflow wrappers.

## Add a module

Begin with the required module contract layout:

```text
modules/<module-name>/
|-- R/
|-- scripts/
|-- schemas/
|-- tests/
|-- module.yml
|-- README.md
`-- CHANGELOG.md
```

Choose one existing runtime profile unless a new shared dependency family is
truly justified. Create a complete public interface and a small reproducible
fixture before building a deployment adapter. Add the module to the root
catalog only after the canonical directory and contract exist.

## Preserve scientific and legacy behavior

Treat changes to these items as scientific changes, not mechanical cleanup:

- statistical models, filtering, normalization, and default thresholds;
- feature and sample alignment rules;
- output column names and filenames consumed downstream; and
- established plotting aesthetics, annotations, palette order, or layout.

When modernization is needed, preserve a tested baseline first. Make the
behavioral change in a separate, reviewable step and describe the effect in
the README and changelog.

## Manage data and dependencies safely

- Never commit credentials, real study data, generated results, package caches,
  or large package inventories.
- Keep small reproducible fixtures under ignored `data/debug/` only when they
  are useful for local tests.
- Select the module's `runtime_profile` from `module.yml`. The committed
  runtime lockfile is the reproducibility record; do not create a repository-
  wide lockfile that pulls unrelated dependencies into every module.
- Change and publish a shared runtime only when its definition changes. Target
  the affected profile rather than rebuilding unrelated runtime families.
- Do not create a module or adapter release tag merely because a branch merged.
  A tag represents the versioned, validated state described in
  [Versioning and releases](versioning-and-releases.md).

## Validate proportionally

At minimum, run the repository layout test after structural changes:

```bash
Rscript tests/test-monorepo-layout.R
```

Also run the changed module's direct tests and a representative CLI invocation
with disposable data when code or interface behavior changes. For a
documentation-only change, run Markdown/diff checks and verify paths and links.
For a deployment change, report the platform validation separately; a local
test is not evidence that a deployment workflow ran.

## Document and hand off

Before requesting review, provide:

- what changed and the scientific or interface rationale;
- the files changed and any intentional compatibility decision;
- commands/tests run and their result;
- external validation still required; and
- runtime, module-commit, and input-data provenance needed to reproduce a
  scientific result.

Use the [module README guide](module-readme-guide.md) for user-facing module
documentation. Keep deployment repositories linked under **Deployment
repository** in the canonical module README, while keeping the main scientific
instructions portable.
