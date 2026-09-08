# Contributor guide

This is the practical guide for people and coding agents changing canonical
OMIX code. Read the [module contract](module-contract.md) first; it defines
the architecture and wins if documents disagree.

## Start with the scope

OMIX is the canonical, platform-neutral home for reusable scientific
behavior. A module must accept explicit input and output paths so it can run
from local R, containers, HPC, and workflow wrappers.

| Change | Owner | Typical location |
| --- | --- | --- |
| Scientific method, reusable parameter, table contract, or portable CLI | Canonical module | `modules/<name>/` |
| External-object conversion | Optional bridge | `bridges/<ecosystem>/` |
| UI, mounted-input discovery, result location, or platform entry point | Deployment adapter | Separate adapter repository |
| Dependency shared by several modules | Shared runtime profile | `starter-environments/<profile>/` |

An adapter is not a second scientific source of truth. If an adapter reveals a
scientific or reusable-interface problem, fix and test the canonical module,
then export the validated implementation back to the adapter. For adapter
specific work, continue with the [deployment adapter guide](deployment-adapter-guide.md).

## Discover before editing

Work in the smallest relevant scope and preserve unrelated user changes.

```bash
git status --short --branch
git log -1 --oneline
sed -n '1,220p' modules/<module>/module.yml
sed -n '1,260p' modules/<module>/schemas/interface.yml
rg --files modules/<module>
```

Read the affected module's README, schema, tests, and changelog before
changing scientific code. For adapter work, also inspect its `AGENTS.md`,
`OMIX_MODULE_SOURCE.md`, Git state, and canonical-source link.

When the requested scope or evidence conflicts, inspect first and request
direction rather than making an architectural assumption.

## Change a canonical module

For a scientific or reusable-interface change:

1. Update the R implementation and its explicit-path script if the public CLI
   changes.
2. Update `schemas/interface.yml` for every public input, parameter, or output
   change.
3. Add a direct regression test, including a changed default or relevant
   failure path where practical.
4. Update the module README and `CHANGELOG.md` for user-visible behavior.
5. Apply the [versioning policy](versioning-and-releases.md): change the
   semantic module version for externally visible behavior, and increase
   `interface_version` only when an existing caller becomes invalid.
6. Run direct tests, a representative explicit-path CLI command, and the
   repository layout test.

Do not hard-code deployment paths in canonical code. Do not copy platform UI,
runtime setup, or generated results into a canonical module.

## Add a module

Start from the required structure in the module contract. Choose an existing
runtime profile unless a genuinely shared dependency family is needed. Create a
complete public schema, direct test, and small reproducible fixture before
building a deployment adapter. Add the module to the root catalog only after
the canonical implementation exists.

Keep reusable utilities in `core/` only after two or more modules need the
same stable behavior. Keep object extraction in an optional bridge, not Core,
unless it is a portable contract shared across ecosystems.

## Preserve scientific behavior

Treat these as scientific changes rather than cosmetic refactoring:

- statistical models, filtering, normalization, and default thresholds;
- feature/sample alignment and identifier rules;
- output columns or filenames consumed downstream; and
- established plot aesthetics, annotation positions, palette order, and
  layout.

Preserve a tested baseline before a modernization. Make a behavioral change in
an explicit reviewable step, document its effect, and use the appropriate
version increment.

## Write module READMEs for users

Each canonical module README is for a scientist running the analysis, not for
a repository maintainer. Lead with the scientific aim and the shortest useful
path to a run. Use this order where applicable:

1. **Title and one-sentence aim**
2. **What it does** and **When to use it**
3. **Quick start** — runtime profile, entry point, and a link to the complete
   command below
4. **Inputs** — file types, key columns, and alignment rules
5. **Run locally or on HPC** — one complete explicit-path command matching
   `module.yml`'s entry point
6. **Outputs** — stable output files and their intended downstream use
7. **Method notes** — only defaults or assumptions that affect interpretation
8. **Optional integrations, interface, deployment link, and references**

Use `module.yml` and `schemas/interface.yml` as the source of truth. Link to
the root README for environment setup instead of duplicating installation
instructions. A deployment link must remain supplementary: the canonical
README must be complete for local and HPC users.

## Data and runtime discipline

- Do not commit credentials, real study data, generated results, package
  caches, or large inventories. Use ignored small `data/debug/` fixtures only
  when useful for a test.
- Use the module's declared `runtime_profile`. The profile lockfile—not a
  repository-wide lock—is the dependency baseline for a module run.
- Declare a module-specific runtime overlay in `module.yml` only when needed,
  with an exact package version.
- A shared runtime changes only when its Dockerfile, lockfile, or runtime
  definition changes. Validate and publish only the affected profile.
- For a reproducible result, record the module commit, immutable runtime
  identity, effective run lockfile, explicit command, and input provenance.
  See the [runtime guide](runtime-guide.md).

## Validate and hand off

Always run the layout check after a structural change:

```bash
Rscript tests/test-monorepo-layout.R
```

Run module tests and a representative CLI command when scientific behavior or
the interface changes. A documentation-only change needs link/path and diff
checks. A local check is not evidence that an adapter ran on its platform.

Before review, report the scope and rationale, changed files, compatibility
decision, commands/tests run, remaining external validation, and the
provenance needed to reproduce a resulting analysis.

Use [Versioning and releases](versioning-and-releases.md) for any release.
An automated release agent must additionally follow the exact
[release automation contract](release-automation-contract.md); it cannot
infer a version bump, create missing evidence, or move an existing tag.
