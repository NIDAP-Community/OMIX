# Adapter validation

Add automated checks for:

- App Panel parameter names, types, choices, and defaults against the
  canonical interface schema;
- adapter CLI translation into canonical function arguments;
- unambiguous attached-input and workflow-result discovery;
- stable result names and downstream workflow bundles;
- byte-for-byte parity of `code/functions/` with the canonical commit recorded
  in `.syncweaver-lock.json` and `OMIX_MODULE_SOURCE.md`; and
- representative fixture equivalence between canonical and deployment runs.

Record the Code Ocean validation separately; a local test is not evidence that
the platform capsule or published runtime succeeded.
