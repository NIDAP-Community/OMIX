# Canonical-module validation

This is the reusable PR-validation contract for portable OMIX modules. It
turns a module's committed tests and fixture run into a reviewable artifact,
without putting deployment code, study data, or release actions in the
canonical repository.

It is intended to answer two different questions:

1. Does the portable module still meet its declared fixture-level contract in
   the immutable runtime assigned to it?
2. Does the pull request give an independent reviewer enough evidence to
   assess the scientific change before merge?

It does not establish Code Ocean adapter parity, publish a runtime, or grant
an `active` lifecycle state by itself.

## Add validation to a module

Opt in by adding `modules/<module>/tests/validation.json`, using
[`templates/canonical-module-validation/validation.json`](../templates/canonical-module-validation/validation.json)
as the starting point. The manifest must declare:

| Field | Purpose |
| --- | --- |
| `schema_version` | Currently `1`. |
| `module` / `runtime_profile` | Must exactly match the module directory and `module.yml`. |
| `test_commands` | Direct contract and regression tests, run from the repository root. |
| `fixture_command` | Portable CLI command using only committed public fixture data and writing to `/artifacts`. |
| `fixture_inputs` | Committed public fixture files; their SHA-256 checksums and byte sizes are retained in the plan and report. |
| `expected_artifacts` | Files and directories that the fixture must produce for review. |
| `known_result_evidence` | Committed expected-result test(s), plus any explicit-path local historical comparison. |

Do not put credentials, user paths, protected data, mounted-path discovery, or
shell fragments that depend on an adapter in this manifest. The generic runner
mounts the repository read-only at `/workspace` and a fresh artifact directory
at `/artifacts`.

Every scientific module should have a small public fixture with assertions for
known results. If a historical dataset is the scientific reference, add an
explicit-path local parity script; keep those source data and outputs outside
Git and record its command, input provenance, runtime identity, tolerance, and
result in the project session notes.

## Run the same validation locally

From the OMIX repository root, create a plan and a generated runner. The plan
resolves the immutable runtime digest from
`starter-environments/release-manifest.json`.

```bash
validation_dir="$(mktemp -d)"
python3 scripts/canonical_module_validation.py plan \
  --module OMIX-PCA-3D --output "$validation_dir/plan.json"
mkdir -p "$validation_dir/artifacts"
python3 scripts/canonical_module_validation.py write-runner \
  --plan "$validation_dir/plan.json" --output "$validation_dir/artifacts/run-validation.sh"
image="$(python3 scripts/canonical_module_validation.py plan \
  --module OMIX-PCA-3D --image-only)"
docker run --rm \
  --volume "$PWD:/workspace:ro" \
  --volume "$validation_dir/artifacts:/artifacts" \
  --workdir /workspace "$image" \
  bash /artifacts/run-validation.sh
python3 scripts/canonical_module_validation.py report \
  --plan "$validation_dir/plan.json" \
  --artifact-directory "$validation_dir/artifacts"
```

Inspect `validation-report.json`, the command's run summary, tables, HTML, and
companion assets before treating the fixture as accepted. Keep the temporary
directory if it is review evidence; otherwise remove only that exact directory.

## What runs on a pull request

The **Validate canonical module** workflow detects changed modules that have a
validation manifest. For each one it:

1. resolves the assigned immutable runtime digest;
2. runs the declared direct tests and fixture command in that image;
3. verifies every declared artifact exists;
4. records the checked-out OMIX commit, immutable runtime digest, fixture input
   checksums, and output file digests/directory file counts in
   `validation-report.json`;
5. adds that report to the GitHub check summary and uploads the complete
   artifact bundle.

To run it manually, open the repository's
[Actions page](https://github.com/NIDAP-Community/OMIX/actions/workflows/validate-canonical-module.yml),
select **Validate canonical module**, choose **Run workflow**, and enter the
canonical module name (or retain `all`).

For review, open the pull request's **Checks** tab, select the completed
**Validate canonical module** check, then download the `canonical-module-<name>`
artifact. Compare its `validation-report.json`, module run summary, result
tables, and visual output to the PR description and expected scientific
behavior.

## Boundary and review checklist

- Keep scientific methods, fixture inputs, and expected-result assertions in
  `modules/<name>/`; keep Code Ocean input discovery and UI translation in an
  adapter repository.
- A no-code documentation-only PR should not fabricate a scientific fixture
  run. Conversely, a scientific-method or interface change needs a domain
  reviewer and a regression result, as required by the
  [agent team operating model](agent-team-operating-model.md).
- The initial runner validates the module's base `runtime_profile`. A module
  with an effective dependency overlay must keep a base-compatible validation
  lane and document separate exact-effective-runtime evidence until the
  manifest supports locked overlays. Do not describe the base lane as overlay
  equivalence.
- The workflow never builds, tags, publishes, or releases an image. Runtime
  changes remain subject to the [runtime guide](runtime-guide.md) and their
  own evidence.
- The workflow is only one input to lifecycle decisions. `active` requires the
  independent-review and cross-environment evidence specified in the
  [canonical module lifecycle](module-lifecycle.md).

## Ownership

For team work, use a tracked GitHub issue and the role boundaries in the
[agent team operating model](agent-team-operating-model.md): Beacon maintains
the checklist and review evidence contract; Forge owns reusable CI and runtime
provenance; the module's scientific/domain reviewer verifies expected results;
and Atlas records the issue, scope, review, and merge decision. That ownership
is durable documentation, not a replacement for a named assignee on an issue.
