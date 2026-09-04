# Module README Guide

Each directory under `modules/` is the canonical, portable implementation of
one analysis. Its README is written for a scientist running the module from a
local R session, a command line, a container, or an HPC system.

## Standard structure

Use the following order. Sections that do not apply may be omitted, but do not
change the meaning of the shared headings.

1. **Title and summary** — the module name and one sentence stating the
   scientific task.
2. **Runtime profile** — the value from `module.yml`, linked to the root
   README's shared-R/HPC setup instructions.
3. **What it does** and, when useful, **When to use it** — concise scientific
   purpose and appropriate use cases.
4. **Inputs** — required file types, required columns, and any important
   sample- or feature-alignment rules.
5. **Run locally or on HPC** — one complete CLI example using explicit paths.
   The example must invoke the `entrypoint` recorded in `module.yml`.
6. **Outputs** — named output files or directories and their intended use.
7. **Method notes** — defaults, modeling assumptions, normalization,
   statistical interpretation, or preserved legacy behavior that materially
   affects scientific results.
8. **Optional integrations or reproducible fixtures** — only where they are
   part of the module's public use.
9. **Interface and deployment** — link to `schemas/interface.yml` and, when
   present, the separately maintained deployment repository.
10. **References** — primary methods, algorithms, or databases when they are
    needed to interpret the analysis.

## Writing rules

- Treat `module.yml` and `schemas/interface.yml` as the source of truth for
  runtime profile, entry point, declared inputs, parameters, and outputs.
- Use explicit, platform-neutral file paths such as `/path/to/input.csv` and
  `results/`. Do not describe an interactive platform UI, mounts, or default
  platform directories in a canonical module README.
- Explain the expected biological or statistical use before enumerating every
  parameter. Link to the interface schema for the complete machine-readable
  contract.
- Keep package-installation instructions centralized in the root README. A
  module README should identify its runtime profile and link to those setup
  instructions rather than maintain a second dependency list.
- Preserve documented legacy behavior and scientific defaults. Documentation
  cleanup must not imply a different calculation, plot appearance, or input
  contract.

## Review checklist

- The module title, `runtime_profile`, entry point, and output names agree with
  `module.yml` and `schemas/interface.yml`.
- The CLI example can be copied after the selected runtime profile is restored.
- Input and output tables identify their key ID columns and alignment rules.
- Any deployment repository appears only as a link; the canonical README
  remains useful without that deployment.
