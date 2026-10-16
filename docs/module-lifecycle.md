# Canonical module lifecycle

The `status` field in each `modules/<name>/module.yml` describes the readiness
of the canonical, platform-neutral module. It does not describe a deployment
adapter, shared runtime image, Code Ocean capsule, Git tag, or platform
release. Those records are tracked and validated separately.

## Allowed statuses

| Status | Meaning | Minimum evidence |
| --- | --- | --- |
| `development` | The canonical implementation or public contract is still being designed, is incomplete, or has a known canonical blocker. It is not recommended for routine scientific use. | The module layout may exist, but one or more required implementation, schema, documentation, runtime, or direct-test elements remain incomplete. Missing evidence and known blockers must be stated in the module changelog or a linked issue. |
| `review` | The canonical module is functionally complete and usable for evaluation, but new scientific behavior, an interface change, reproducibility evidence, or independent review is still pending. | Required module files exist; direct module and contract tests pass in a compatible environment; the README documents the current behavior; and remaining review or validation work is explicit. |
| `active` | The canonical module is the supported stable implementation for routine portable use. | The current canonical behavior and interface have passed direct tests, independent review, and the cross-environment reproducibility gate below; runtime requirements and user documentation are current; no known canonical blocker remains; and the supported version is recorded in `module.yml` and the changelog. |

Canonical `active` status does not require a deployment adapter. Likewise, a
successful platform run cannot make an incomplete canonical module active.
Adapter parity, runtime provenance, platform validation, adapter tags, and
platform releases remain separate evidence classes, even though an existing
supported adapter triggers the cross-environment requirement below.

## Cross-environment reproducibility gate

Before a module moves to `active`, run one representative fixture through the
canonical module in its supported local or pinned-container runtime. Compare
the resulting scientific outputs with the same fixture executed through every
deployment adapter presented as supported.

When a Code Ocean adapter is registered, a local-versus-Code Ocean output
comparison is mandatory. A successful capsule status by itself is not enough.
The reviewed evidence must record:

- the canonical and adapter commits;
- the local and platform runtime identities;
- the fixture and effective parameters;
- the local and platform run identifiers;
- the files and scientific fields compared;
- whether comparison is exact or tolerance-based, including each tolerance;
  and
- the comparison result and any understood, accepted differences.

Use exact comparison for deterministic identifiers, ordering, dimensions, and
serialized values where the format permits it. Use declared numeric
tolerances for floating-point results and explicit structural or visual checks
for figures. An adapter with missing, stale, or failed cross-environment
evidence blocks promotion to `active`; it does not by itself prove that the
canonical scientific implementation is defective.

## Status changes

The module owner proposes a status change in a reviewed pull request. The pull
request must state:

- the previous and proposed status;
- the module version and interface version;
- direct test and contract evidence;
- any independent scientific or interface review;
- the cross-environment comparison record required for `active` promotion;
- known blockers or limitations; and
- deployment or runtime evidence only as separate supporting context.

Advancing a module requires all evidence for the target status. Regressing a
module is appropriate when a canonical scientific defect, unsupported runtime,
or contract failure is discovered. A deployment-only failure does not by
itself regress a canonical module unless it exposes a canonical defect.

Do not infer status from a version number, timestamp, commit order, Git tag,
adapter status, or completed job alone. A generated artifact or platform run
must be inspected before it is used as evidence.

## Catalog synchronization

The main README module catalog is a user-facing rendering of canonical module
metadata:

- the module name and canonical link come from the module directory;
- the deployment repository comes from `deployment_adapters`;
- the purpose is the module `description`; and
- the displayed status is the title-cased `status` value.

Run `python3 tests/test_module_catalog.py` after changing a module manifest or
the README catalog. CI runs the same check and rejects metadata/catalog drift.

## Current audit decisions

The initial audit for [issue #99](https://github.com/NIDAP-Community/OMIX/issues/99)
uses conservative classifications:

- OMIX GSVA advances from `development` to `review`. Its current canonical
  version has direct locked-runtime validation, independent review, a
  namespaced module tag, and recorded platform runs, but a reviewed
  local-versus-Code Ocean scientific-output comparison is not yet recorded.
- OMIX Limma Analysis advances from `development` to `review` because its
  interface-3 implementation, documentation, contract tests, exact-runtime
  test, and independent review are complete, while the newly synchronized
  deployment interface still requires platform validation before a broader
  release decision.
- Existing `review` modules remain under review where recent scientific or
  interface work still needs final adapter, runtime, or independent evidence.
- Modules previously labeled `active` move to `review` until their registered
  adapters have current local-versus-platform output comparisons. This is a
  lifecycle-evidence correction, not a claim that their scientific behavior
  is defective.

A subsequent reviewed evidence refresh for
[issue #101](https://github.com/NIDAP-Community/OMIX/issues/101) records the
current OMIX Limma Analysis interface-3 canonical and adapter commits, pinned
runtime identity, representative platform runs, Standard Capsule release, and
the local-versus-Code Ocean scientific-output comparison. With those gates
complete and no known canonical blocker remaining, OMIX Limma Analysis now
advances from `review` to `active`. This status change does not alter its
scientific behavior, public interface, adapter version, runtime, or platform
release.
