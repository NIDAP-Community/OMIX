# OmixMOSuite

`OmixMOSuite` is an optional interoperability package that converts MOSuite
`multiOmicDataSet` (MOO) objects into the portable OMIX standard input. It is
platform-neutral and can be used in R, Docker, or HPC environments.

## Install

Install the supported MOSuite revision, Core, and this bridge from the same
OMIX revision:

```r
remotes::install_github("CCBR/MOSuite@5c80b4493d546d9298131e745cc7812f51a2a297")
remotes::install_github("NIDAP-Community/OMIX", subdir = "core")
remotes::install_github("NIDAP-Community/OMIX", subdir = "bridges/mosuite")
```

The bridge's `DESCRIPTION` records that MOSuite commit as its supported source.
Table-based OMIX modules do not need this package or MOSuite.

## Convert an MOO

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

Use `count_type = "raw"` for raw-count DEG workflows. The bridge records the
selected layer and MOSuite version but does not make a scientific choice about
which layer is appropriate for a downstream method.
