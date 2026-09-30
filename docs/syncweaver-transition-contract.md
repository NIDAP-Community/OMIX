# Syncweaver transition contract

This document defines the reviewed evidence and safety boundary for moving a
deployment adapter from interim Harbor exports to Syncweaver maintenance. The
machine-readable wave-1 record is
[`syncweaver-transition-wave1.json`](syncweaver-transition-wave1.json),
validated against
[`syncweaver-transition-contract.schema.json`](schemas/syncweaver-transition-contract.schema.json).

The record is **preparation only**. It is not a Syncweaver API, generated
`.syncweaver-lock.json`, installation instruction, release request, or
authorization to write to an adapter or Code Ocean capsule. The Syncweaver
maintainer may consume the reviewed facts using the production interface they
provide, but that interface must preserve every stop condition below.

Tracked work: [OMIX issue #44](https://github.com/NIDAP-Community/OMIX/issues/44).

## Scientific ownership and write boundary

Scientific code flows in one direction:

```text
reviewed OMIX module R/ at an immutable commit
                         |
                         v
reviewed adapter code/functions/ at an immutable commit
```

The canonical commit, complete `R/` tree, path mapping, and SHA-256 values—not
file timestamps—identify the authoritative content. A synchronization proposal
may change only the explicitly mapped `code/functions/` destinations and the
documented generated metadata path `.syncweaver-lock.json`. Every unlisted
adapter path is protected. In particular, `.codeocean/`, the platform entry
point, mounted-input discovery, adapter tests, runtime files, documentation,
and `OMIX_MODULE_SOURCE.md` remain outside the scientific export.

`OMIX_MODULE_SOURCE.md` remains Harbor-owned release evidence. It must agree
with a proposed/generated lock before review completes, but synchronization
must not silently rewrite it. Code Ocean validation, an immutable runtime
digest, Beacon review, and explicit release approval remain separate gates.

## Wave-1 reviewed baselines

Only the following three merged, parity-reviewed adapters are in wave 1:

| Adapter | Canonical source | Version / interface | Adapter baseline | Mapping | Expected SHA-256 |
| --- | --- | --- | --- | --- | --- |
| OMIX-DEG-Analysis | `018ef0e10bf29c69166b38ee6d81d4d71d18aeca` | `0.4.0` / `2` | `3f8052a6c13d51bac9bef20b418183d801d62cac` | `modules/OMIX-DEG-Analysis/R/OMIX_DEG_Analysis.R` -> `code/functions/OMIX_DEG_Analysis.R` | `e0e64e4de04b91419c77d1d44ac607f62fa172bc1b99fd0936ebb3e6ae8eb13e` |
| OMIX-Volcano-Plot | `eee4433cd74d0ce9bd1daba1571ca6312cba7ea2` | `1.0.0` / `1` | `8a54215e741565a01b2afa36808ff8558e4c7af5` | `modules/OMIX-Volcano-Plot/R/Volcano_Plot_Enhanced.R` -> `code/functions/Volcano_Plot_Enhanced.R` | `75df94195458c63130edaab5a2ee0a90c88ca9aa859591c6810d3eec5948673b` |
| OMIX-GSEA-Filters-Legacy | `eee4433cd74d0ce9bd1daba1571ca6312cba7ea2` | `1.0.0` / `1` | `01aeefbee65362f4ed35182193c8feb640b5b4f0` | `modules/OMIX-GSEA-Filters-Legacy/R/filter_gsea_function.R` -> `code/functions/filter_gsea_function.R` | `981aa772884f41931b3a64b1a67ddca455ae7b56b746b5472bc27505bfc31c2e` |

At these baselines each `code/functions/` directory contains exactly one file,
the corresponding canonical `R/` tree is complete in the mapping, and source
and destination bytes are identical. Other adapters remain outside wave 1
until their own remediation and parity review are complete.

## Mandatory stop conditions

Synchronization must stop and preserve evidence when any of these conditions
is true:

1. Either checkout is dirty, including untracked files.
2. A checkout is not at the exact reviewed commit used by the proposal.
3. Canonical or adapter history has diverged from the reviewed baseline.
4. A managed adapter file differs from both the recorded adapter baseline and
   declared canonical source. This is a host-side scientific edit; report its
   byte diff rather than overwriting it.
5. The canonical `R/` tree or adapter `code/functions/` tree has an unlisted,
   missing, renamed, or symlinked file.
6. `OMIX_MODULE_SOURCE.md` disagrees with the canonical commit, module or
   interface version, mapping, or hashes.
7. A proposal touches any protected adapter path.
8. Any required canonical, mapping, contract, adapter, or fixture test fails.

Modification timestamps, upload times, and platform sync times never resolve
a conflict. The only allowed result of ambiguous authority is stop-and-review.

## Required pre-sync evidence

Before proposing an update, verify:

1. clean canonical and adapter worktrees;
2. exact source and adapter commits plus non-divergent history;
3. `module.yml` module and interface versions at the source commit;
4. the complete canonical `R/` and destination `code/functions/` file sets;
5. SHA-256 parity at the recorded baseline;
6. agreement with `OMIX_MODULE_SOURCE.md`;
7. the module tests listed in the wave-1 record; and
8. the adapter contract, input, CLI, and representative-fixture tests listed
   for that adapter.

The repository checker validates the immutable canonical evidence by default:

```bash
python3 scripts/check_syncweaver_transition_contract.py
```

It can also verify clean local adapter baselines without modifying them:

```bash
python3 scripts/check_syncweaver_transition_contract.py \
  --adapter-root OMIX-DEG-Analysis=/path/to/OMIX-DEG-Analysis \
  --adapter-root OMIX-Volcano-Plot=/path/to/OMIX-Volcano-Plot \
  --adapter-root OMIX-GSEA-Filters-Legacy=/path/to/OMIX-GSEA-Filters-Legacy \
  --require-all-adapters
```

## Required post-proposal evidence

Before a synchronization proposal may merge:

1. recompute source and destination SHA-256 values and prove byte parity;
2. prove the managed tree is complete and contains no extra scientific copy;
3. prove all protected paths are unchanged from the adapter baseline;
4. compare the generated lock with `OMIX_MODULE_SOURCE.md` and this mapping;
5. rerun the canonical and adapter tests recorded in the contract;
6. run the OMIX deployment-adapter contract checker against the proposed
   adapter commit; and
7. obtain Beacon's independent parity review.

A passing proposal is still not a platform validation or release. Code Ocean
must run the exact merged adapter candidate, Forge must record the immutable
runtime digest, and the project owner must explicitly approve any release,
tag, or publication.

## Maintainer handoff

The Syncweaver maintainer needs to supply or confirm these production
capabilities before onboarding:

- immutable canonical and adapter commit inputs;
- complete-tree, allowlisted path mapping;
- pre-write dirty/divergence/hash checks;
- host-scientific-edit detection with a reviewable diff;
- protected-path enforcement;
- deterministic SHA-256 evidence in the generated lock/proposal;
- pre/post test hooks with failure as a hard stop; and
- a review-only proposal workflow with no automatic merge, release, or reverse
  synchronization.

This contract deliberately does not name commands, endpoints, events, or
configuration fields for those capabilities. Those details belong to the
maintainer-supplied Syncweaver interface, not to OMIX policy.
