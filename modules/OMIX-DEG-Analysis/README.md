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

### Local paired-pseudobulk fixture

For a reproducible local integration test, generate the Kang et al. IFN-beta
PBMC CD14+ monocyte fixture. It contains eight donors observed in both `ctrl`
and `stim` conditions, producing 16 donor-by-condition profiles. The data are
created under ignored `data/debug/` and are never part of a release.

```r
BiocManager::install("muscData")
```

```bash
Rscript modules/OMIX-DEG-Analysis/scripts/create_kang_pseudobulk_fixture.R
```

Run the resulting files with `--contrast_variable_columns Group`,
`--contrasts stim-ctrl`, and `--donor_variable_column Donor`.

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

## Optional Seurat pseudobulk input

For a Seurat object, use the optional
[OmixSeurat bridge](../../bridges/seurat/README.md) to select a cell type and
sum raw `RNA` `counts` by donor and condition. It returns the same portable
count-table-plus-metadata contract used above. The bridge depends on
`SeuratObject`, not the full Seurat package, and does not treat cells as
independent DEG replicates.

## Summary of normalization best practices

| Dataset type | Recommended workflow | Reason |
| --- | --- | --- |
| **Typical dataset** (standard knockouts, treatments, diverse human tissues) | **Normalization Method: `TMM`** (default) [1, 2] | Preserves the observed biological range while correcting RNA-composition bias. |
| **High technical noise** (for example, varying platforms or batch-heavy historical data) | **Normalization Method: `TMM + Quantile`** | Forces log-CPM distributions to align and can reduce severe, non-linear technical variation, at the risk of attenuating subtle or global biology. [2] |

`TMM + Scale` equalizes sample medians, while `TMM + Cyclic Loess` is a
slower, pairwise alternative that can be more robust when differential
expression is unbalanced. `Quantile` omits TMM and applies voom-scale quantile
normalization alone; use it only when that deliberate choice fits the study.

### Choosing a profile

- Start with **`TMM`** for a new bulk RNA-seq analysis.
- Try **`TMM + Scale`** when QC shows a modest, sample-wide median shift after
  TMM and there is good reason to regard it as technical.
- Use **`TMM + Quantile`** only when QC shows a severe technical mismatch of
  whole distributions. It is intentionally stronger and can obscure genuine
  global shifts.
- Use **`TMM + Cyclic Loess`** as a sensitivity analysis for nonlinear,
  sample-specific distribution differences, particularly with unbalanced
  differential expression.
- Use **`Quantile`**, **`TMMwsp`**, **`RLE`**, or **`Upper Quartile`** for a
  deliberate legacy/reproducibility comparison or a documented special case;
  they are not routine first choices.

Normalization does not replace modelling known technical batch variables.

### Normalization diagnostics

The portable CLI writes `normalization_boxplots.png`,
`normalization_densities.png`, and `voom_mean_variance.png` by default. The
first two compare filtered log-CPM values before normalization with the final
voom values used for modelling. The mean-variance plot shows the voom trend
used to estimate precision weights and is useful for checking low-count
filtering and model preparation. Disable these outputs with
`--write_normalization_diagnostics false`. When calling `omix_deg_analysis()`
directly, set `normalization_diagnostics = TRUE` and supply
`diagnostics_output_dir` to write the same files.

### References

1. Robinson MD, Oshlack A. A scaling normalization method for differential expression analysis of RNA-seq data. *Genome Biology*. 2010;11:R25. [doi:10.1186/gb-2010-11-3-r25](https://doi.org/10.1186/gb-2010-11-3-r25)
2. [limma documentation: `voom` and `normalizeBetweenArrays`](https://bioconductor.org/packages/devel/bioc/manuals/limma/man/limma.pdf)

## Design notes

- Use `--donor_variable_column` only for genuine repeated measurements from
  the same biological donor or participant.
- Every comparison group must contain at least two biological samples. For
  single-cell input, aggregate raw counts by donor and condition first; cells
  are not independent replicates.
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
