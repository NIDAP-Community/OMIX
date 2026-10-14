# OMIX Seurat Pseudobulk tests

The ordinary module checks cover portable bundle construction, validation, and
the downstream handoff helpers. `test-public-cli-equivalence.R` is the stricter
end-to-end equivalence driver. It:

- generates a small RNA object, legacy slot-based `Harmony/data` assay, and a
  real `SCTAssay` at run time;
- invokes the public Seurat Pseudobulk CLI in all three aggregation modes;
- routes raw counts through the public OMIX DEG Analysis CLI and both
  continuous matrices through the public OMIX Limma Analysis CLI;
- compares identifiers, columns, row and sample order, categorical metadata,
  missingness, manifests, variance routing, and numeric values with committed
  text baselines; and
- fails when any required scientific dependency is unavailable. It never
  reports a missing-runtime skip as successful equivalence.

Run it from the repository root in a test environment containing the declared
Seurat-conversion, DEG, and Limma dependency sets:

```bash
Rscript modules/OMIX-Seurat-Pseudobulk/tests/test-public-cli-equivalence.R
```

The exact-runtime CI workflow runs the same driver in two phases with a shared
writable handoff directory. The `conversion` phase executes fixture generation
and all three Pseudobulk modes in the immutable published
`r-seurat-conversion` image. The `downstream` phase then executes the routed
DEG and Limma CLIs in the immutable published `r-statistics` image:

```bash
Rscript modules/OMIX-Seurat-Pseudobulk/tests/test-public-cli-equivalence.R \
  --phase conversion --working-dir /path/to/handoff
Rscript modules/OMIX-Seurat-Pseudobulk/tests/test-public-cli-equivalence.R \
  --phase downstream --working-dir /path/to/handoff
```

Use a new handoff directory for the conversion phase. The workflow reads both
digest-qualified image references and lockfile checksums from
`starter-environments/release-manifest.json`, verifies each published package
set, records output checksums, and uploads the text outputs as a reviewable CI
artifact. It never builds, publishes, retags, or releases a runtime.

The numeric tolerances are machine-readable in
`fixtures/expected/equivalence-contract.dcf`. Raw pseudobulk counts must be
exact. Harmony means use `1e-12`, SCT means use `1e-8`, and downstream model
tables use `1e-10` or `1e-7` according to their expected cross-host numerical
stability. Schema, identifiers, ordering, categorical fields, and missingness
always require exact equality.

To propose a refreshed baseline, write to a new directory and review its diff
instead of overwriting the committed evidence in place:

```bash
Rscript modules/OMIX-Seurat-Pseudobulk/tests/test-public-cli-equivalence.R \
  --record-expected /tmp/pseudobulk-equivalence-candidate
```

The generated Seurat RDS remains temporary and must not be committed.
