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
| `active` | The canonical module is the supported stable implementation for routine portable use. | The current canonical behavior and interface have passed direct tests and independent review; runtime requirements and user documentation are current; no known canonical blocker remains; and the supported version is recorded in `module.yml` and the changelog. |

Canonical `active` status does not require a deployment adapter. Likewise, a
successful platform run cannot make an incomplete canonical module active.
Adapter parity, runtime provenance, platform validation, adapter tags, and
platform releases remain separate evidence classes.

## Status changes

The module owner proposes a status change in a reviewed pull request. The pull
request must state:

- the previous and proposed status;
- the module version and interface version;
- direct test and contract evidence;
- any independent scientific or interface review;
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

- OMIX GSVA advances from `development` to `active` because its current
  canonical version has direct locked-runtime validation, independent review,
  a namespaced module tag, and recorded platform validation. The platform
  evidence supports but does not define its canonical status.
- OMIX Limma Analysis advances from `development` to `review` because its
  interface-3 implementation, documentation, contract tests, exact-runtime
  test, and independent review are complete, while the newly synchronized
  deployment interface still requires platform validation before a broader
  release decision.
- Existing `review` modules remain under review where recent scientific or
  interface work still needs final adapter, runtime, or independent evidence.
- Existing `active` modules retain that status provisionally. Their labels
  describe canonical support, not current deployment parity; adapter evidence
  is audited separately in the deployment-adapter inventory.
