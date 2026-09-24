# OmixMOSuite

`OmixMOSuite` is the lightweight, platform-neutral bridge from
[`MOObject::multiOmicDataSet`](https://github.com/CCBR/MOObject) objects to
portable OMIX count or continuous-expression inputs. Despite its historical
package name, the bridge imports **MOObject only** and does not install the full
MOSuite analysis package.

The supported object API is MOObject 0.5.0, pinned to release commit
`0c296b88c69e408d8f5e70c93af5878ec167db9a`. MOObject defines the S7 class and
its public properties, exports `extract_counts()` and the object readers, and
provides an explicit compatibility reader for supported legacy
`MOSuite::multiOmicDataSet` class labels. MOSuite 0.5.0 itself imports MOObject,
so new MOSuite objects use this same lightweight object boundary.

## Install

Install MOObject, OMIX Core, and this bridge from their supported revisions:

```r
remotes::install_github(
  "CCBR/MOObject@0c296b88c69e408d8f5e70c93af5878ec167db9a"
)
remotes::install_github("NIDAP-Community/OMIX", subdir = "core")
remotes::install_github("NIDAP-Community/OMIX", subdir = "bridges/mosuite")
```

Table-based OMIX modules do not need this bridge or MOObject after the portable
tables have been written.

## Convert a raw-count layer

```r
library(OmixMOSuite)

input <- omix_read_mosuite_rds(
  "moo.rds",
  count_type = "raw",
  annotation_columns = "GeneName"
)

input$counts
input$metadata
input$provenance
```

The default count handoff requires finite, non-negative, integer-like sample
values. That guard prevents a normalized layer from silently entering a
count-based DEG workflow. Filtered raw counts can be selected with
`count_type = "filt"` when the MOO records that layer.

## Convert a continuous-expression layer

Use the separate expression handoff for normalized, log-scale, or
batch-corrected gene-expression values:

```r
expression_input <- omix_read_mosuite_expression_rds(
  "moo.rds",
  count_type = "batch",
  expression_scale = "batch_corrected_log2",
  annotation_columns = "GeneName"
)

expression_input$expression
expression_input$metadata
expression_input$provenance
```

`expression_scale` is required provenance. The bridge does not normalize,
transform, or otherwise interpret a selected layer. A downstream Limma module
must choose its variance model based on the documented source and scale.

For a nested layer, also supply `sub_count_type`:

```r
expression_input <- omix_read_mosuite_expression_rds(
  "moo.rds",
  count_type = "norm",
  sub_count_type = "voom",
  expression_scale = "log2_cpm"
)
```

## Validation and compatibility

Both handoffs:

- require a valid `MOObject::multiOmicDataSet`;
- use the exported `MOObject::extract_counts()` generic;
- read documented S7 `sample_meta` and `annotation` properties with `S7::prop()`;
- require unique, non-empty feature IDs;
- require finite numeric values and exact sample alignment with metadata; and
- record bridge, MOObject, layer, subtype, and handoff provenance.

`omix_read_mosuite_rds()` and `omix_read_mosuite_expression_rds()` delegate
deserialization to `MOObject::read_multiOmicDataSet()`. MOObject 0.5.0 includes
a tested coercion path for compatible legacy MOSuite class labels. This bridge
does not inspect private slots or depend on MOSuite workflow functions.

The repository does not commit real workflow outputs. To verify a legacy
`MOSuite-filter-counts` artifact in an isolated runtime, install only MOObject,
OMIX Core, and this bridge, confirm that `MOSuite` is absent, and run:

```bash
Rscript bridges/mosuite/inst/validation/validate-real-mosuite-artifacts.R \
  /path/to/moo-filt.rds \
  /path/to/moo-with-batch-layer.rds
```

The validation reads and validates both legacy objects through MOObject,
checks the integer-like `filt` handoff, checks the separately declared
`batch_corrected_log2` handoff, verifies sample alignment and provenance, and
confirms that a continuous batch layer cannot silently enter the count path.
