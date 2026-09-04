# <Analysis name> — Deployment Adapter

Run the <analysis purpose> through <deployment environment> while preserving
the canonical OMIX scientific implementation.

## Canonical OMIX module

| Item | Location |
| --- | --- |
| Canonical module | [<module name>](<canonical module URL>) |
| Interface contract | [schemas/interface.yml](<canonical schema URL>) |
| Development contract | [OMIX module contract](https://github.com/NIDAP-Community/OMIX/blob/main/docs/module-contract.md) |
| Version and source record | See [OMIX_MODULE_SOURCE.md](OMIX_MODULE_SOURCE.md) |

The canonical module owns scientific functions, portable CLI behavior, tests,
and the reusable input/output contract. This repository owns the deployment
translation only.

## What this deployment adds

- <interactive UI or parameter mapping>
- <attached-data or workflow-input discovery>
- <deployment-specific output and result behavior>
- <runtime or workstation behavior, if applicable>

## Inputs

Describe each supported input asset or upload here. For every input, state:

- expected file or bundle contents;
- required column names or object type;
- how the adapter selects it; and
- what to do when there is more than one candidate.

## Run the analysis

1. <Attach or upload the required input.>
2. <Set the key parameters and defaults.>
3. <Run the analysis.>

Explain the choices that materially affect the scientific result. Link to the
canonical module README for the complete portable interface.

## Outputs and workflow handoff

| Output | Purpose | Downstream use |
| --- | --- | --- |
| `<output-file>` | <description> | <next compatible module or none> |

State which output files must remain together, such as a results table and its
aligned sample metadata.

## Environment and reproducibility

- **Runtime profile:** `<runtime profile>`
- **Pinned environment:** `<image version and digest, or lockfile reference>`
- **Canonical source and adapter release record:** [OMIX_MODULE_SOURCE.md](OMIX_MODULE_SOURCE.md)

Record the input-data identity and selected parameters with any released
scientific result.

## Troubleshooting and limitations

Document expected user-facing errors, unsupported formats, and ambiguous-input
behavior. Prefer a clear error message over silently choosing a file or
changing a default.

## For developers

Read [AGENTS.md](AGENTS.md) and [OMIX_MODULE_SOURCE.md](OMIX_MODULE_SOURCE.md)
before editing. Reusable scientific changes belong in the canonical OMIX
module and are exported here only after validation.

## References and support

- <method and database citations>
- <support route>
