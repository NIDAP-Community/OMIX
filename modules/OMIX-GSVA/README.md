# OMIX GSVA

Calculate sample-level pathway enrichment scores from a normalized
gene-by-sample expression matrix. This module preserves the CCBR
`GSVA_v1.R` scientific function and exposes it through an explicit-path,
platform-neutral command line.

## What it does

OMIX GSVA selects one or more collections from a long gene-set membership
table, aligns those gene sets to the expression matrix, and calculates one
enrichment score per gene set and sample. It supports the template's `gsva`,
`ssgsea`, `zscore`, and `plage` methods and writes both the score table and the
template heatmap.

Use it when normalized, continuous expression is available and sample-level
pathway activity is the desired downstream representation. Do not supply raw
integer counts. The resulting score table can be analyzed as continuous
enrichment data with
[OMIX Limma Analysis](../OMIX-Limma-Analysis/README.md).

## Quick start

Restore the `r-pathway` runtime as described in the root README, then run the
complete command below with explicit paths. No deployment platform is required.

```bash
Rscript modules/OMIX-GSVA/scripts/run_gsva.R \
  --normalized_data /path/to/normalized_expression.tsv \
  --sample_metadata /path/to/sample_metadata.tsv \
  --pathways_database /path/to/pathway_membership.tsv \
  --gene_column Gene \
  --sample_name_column Sample \
  --collections_to_include 'H: hallmark gene sets' \
  --species Human \
  --database_species Human \
  --output_dir /path/to/results/gsva
```

When `--samples_to_include` is omitted, samples are selected by intersecting
the metadata sample IDs with expression column names, in metadata row order.

## Inputs

### Normalized expression

A delimited table with one unique gene-symbol column and numeric sample
columns. The default gene column is `Gene`. Values must be normalized,
continuous expression suitable for the chosen GSVA method—not raw counts.

### Sample metadata

A delimited table with one row per sample. Its sample-ID column (default
`Sample`) must match the selected expression columns. Metadata establishes the
default sample set and order; it is not used to fit a statistical model in this
module.

### Pathways database

A long membership table with these exact columns:

| Column | Meaning |
| --- | --- |
| `collection` | Collection label selected by `--collections_to_include`. |
| `gene_set_name` | Unique pathway or gene-set name. |
| `gene_symbol` | One member gene per row. |
| `species` | Species label selected by the database-species parameters. |

The module does not bundle MSigDB or any other gene-set database. Supply a
versioned data asset at runtime and retain its source, version, and license in
the analysis provenance.

All three inputs use `--input_delim`, which defaults to a tab. For CSV inputs,
supply `--input_delim ','`.

## Outputs

| File | Use |
| --- | --- |
| `gsva_v1_results.csv` | Gene-set-by-sample score table with `Geneset` first. Use this as continuous enrichment input for downstream modeling. |
| `gsva_v1_heatmap.png` | Template-compatible row-scaled heatmap of the score matrix. |
| `gsva_run_summary.txt` | Paths, selected samples and collections, method settings, and template provenance. |

## Method notes

- Scientific defaults are preserved from `GSVA_v1.R`: method `gsva`, minimum
  gene-set size 15, maximum size 1200, Human expression/database species,
  Hallmark collection, and gene-symbol updating enabled.
- `--update_genes true` uses `l2psupp` to update symbols before GSVA. Disable it
  only when the supplied identifiers and gene-set database have already been
  deliberately harmonized.
- If expression and database species differ, the template maps orthologs with
  `l2psupp::o2o` before scoring.
- Multiple requested collections are combined into one GSVA call. Gene-set
  names therefore need to be unique across the selected collections.
- The heatmap uses the original base-R `stats::heatmap` behavior, including
  row scaling and clustering.

## Runtime and reproducibility

The module uses the shared `r-pathway` runtime. Its lockfile pins R 4.4.3,
Bioconductor 3.20, and GSVA 2.0.7; `l2psupp` 0.0-14 is installed from the
immutable source reference documented by that runtime. Restore it into a
writable local/HPC run project with:

```bash
Rscript scripts/restore-omix-runtime.R \
  --module OMIX-GSVA --project /path/to/omix-runtime
```

For a reproducible result, record the OMIX commit, the effective runtime
lockfile or published image digest, the full command, and provenance for all
three input tables.

## Template provenance and compatibility

The implementation comes from `NIDAP/Templates/GSVA_v1.R` (template version
1; SHA-256
`0d536870e979daa3a949e2a86aa12d72f25b160d26eec1148c0db33fc24b0c5d`).
That source is byte-identical to the curated template-library copy and the
earlier OMIX_Test prototype at the time this module was created. Cleanup was
limited to removing package-only roxygen directives, correcting source
documentation to match the existing `update_genes = TRUE` default, and moving
platform selection into this explicit-path CLI. The statistical function,
method choices, defaults, gene-set construction, mapping, scoring, and heatmap
behavior remain intact.

The public interface is defined in [schemas/interface.yml](schemas/interface.yml).
No deployment adapter is registered yet.
