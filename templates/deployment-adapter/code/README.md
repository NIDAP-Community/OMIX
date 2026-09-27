# Deployment code

- `main.R` is the Harbor-owned platform adapter. It resolves mounted or
  uploaded inputs, translates named parameters, selects deployment output
  paths, and calls the canonical scientific functions.
- `run` is the deployment launcher.
- `functions/` is populated from the canonical module's complete `R/`
  directory by Syncweaver. Do not edit or duplicate those functions here.

Keep scientific defaults and algorithms out of `main.R`. Record every
platform-only alias, preset, hidden field, and path translation in
`OMIX_MODULE_SOURCE.md` and test it against the canonical interface schema.
