# OMIX DEG Analysis

Portable bulk RNA-seq differential-expression analysis from raw counts and
sample metadata. It applies design-aware filtering, edgeR TMM normalization,
limma-voom modelling, and optional `duplicateCorrelation` blocking for genuine
repeated-measures designs.

## Run locally

Install the standard R dependencies once:

```r
install.packages("BiocManager")
BiocManager::install(c("edgeR", "limma"))
install.packages("optparse")
```

Run from the OMIX repository root with explicit paths:

```bash
Rscript modules/OMIX-DEG-Analysis/scripts/run_deg_analysis.R \
  --input_type table \
  --counts /path/to/raw_counts.csv \
  --metadata /path/to/sample_metadata.csv \
  --gene_names_column GeneName \
  --sample_names_column Sample \
  --contrast_variable_columns Group \
  --contrasts B-A \
  --batch_effect_columns Batch \
  --output_dir results/deg
```

The count table contains one feature-ID column followed by sample columns. The
metadata sample-ID values must match those sample columns exactly. The output
directory receives `DEG_Analysis.csv` and `DEG_Analysis_run_summary.txt`.

## Optional MOSuite MOO input

MOO input is an optional interoperability path, not a requirement for this
module. Install the pinned MOSuite version, OMIX Core, and `OmixMOSuite` as
described in [the bridge README](../../bridges/mosuite/README.md), then run:

```bash
Rscript modules/OMIX-DEG-Analysis/scripts/run_deg_analysis.R \
  --input_type moo \
  --moo /path/to/moo.rds \
  --contrast_variable_columns Group \
  --contrasts B-A \
  --batch_effect_columns Batch \
  --output_dir results/deg
```

The bridge extracts the MOO's **raw** count layer and embedded sample
metadata, validates their sample alignment, and passes the portable table
contract to the DEG function. Do not use a prefiltered MOO layer as input to
the count model; it applies its own design-aware filtering.

## Design notes

- Use `--donor_variable_column` only for genuine repeated measurements from
  the same biological donor or participant.
- Technical replicates within the same donor-by-group combination are rejected
  rather than selected silently.
- Batch adjustment is included in the fitted model. The optional expression
  block appended to the DEG table is for downstream visualization and does not
  replace the statistics.

The implementation is in `R/OMIX_DEG_Analysis.R`. See
[`schemas/interface.yml`](schemas/interface.yml) for the machine-readable
interface and [`tests/test-omix-deg-analysis.R`](tests/test-omix-deg-analysis.R)
for direct regression tests.

## Deployment adapter

The corresponding deployment repository is
[OMIX-DEG-Analysis](https://github.com/NIDAP-Community/OMIX-DEG-Analysis).
It may supply a user interface and runtime configuration, while this module
remains the canonical scientific implementation.
