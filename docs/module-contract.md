# Module Contract

Each OMIX module is an independently maintained analysis capability under
`modules/<module-name>/`. It is not automatically exported by the `Omix` R
package.

Every module must contain:

```text
modules/<module-name>/
|-- R/                     Module-owned R source
|-- tests/                 Direct module tests
|-- schemas/               Machine-readable input and output contracts
|-- module.yml             Module identity and execution metadata
|-- README.md              Usage and dependency documentation
`-- CHANGELOG.md           Module release history
```

Shared utilities belong in `core/` only after two or more modules need the same
stable behavior. A module should otherwise own its implementation and declare
its own dependencies and data policy in `module.yml`.
