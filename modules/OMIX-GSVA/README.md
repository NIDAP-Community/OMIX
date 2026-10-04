# OMIX GSVA

Calculate sample-level pathway enrichment scores from a normalized
gene-by-sample expression matrix.

## What it does

OMIX GSVA selects one or more collections from a long gene-set membership
table, aligns those gene sets to the expression matrix, and calculates one
enrichment score per gene set and sample. It supports the `gsva`, `ssgsea`,
`zscore`, and `plage` methods and writes both a score table and an overview
heatmap.

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
  --normalized_data /path/to/normalized_expression.csv \
  --sample_metadata /path/to/sample_metadata.csv \
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

Delimiters are detected independently for each input: `.csv` selects a comma,
`.tsv`/`.tab` selects a tab, and other extensions are detected from an
unambiguous header. Override detection with `--normalized_data_delim`,
`--sample_metadata_delim`, or `--pathways_database_delim`. The legacy
`--input_delim` remains available as a shared fallback. Use `','` for CSV and
`'\t'` for TSV/TXT inputs. Ambiguous files stop with the affected input named.

## Outputs

| File | Use |
| --- | --- |
| `gsva_results.csv` | Gene-set-by-sample score table with `Geneset` first. Use this as continuous enrichment input for downstream modeling. |
| `gsva_heatmap.png` | Row-scaled heatmap of the score matrix. |
| `gsva_run_summary.txt` | Paths, selected samples and collections, method settings, and OMIX module identity. |

## Method notes

- Defaults are method `gsva`, minimum gene-set size 15, maximum size 1200,
  Human expression/database species, Hallmark collection, and gene-symbol
  updating enabled.
- `--update_genes true` uses `l2psupp` to update symbols before GSVA. Disable it
  only when the supplied identifiers and gene-set database have already been
  deliberately harmonized.
- If expression and database species differ, the module maps orthologs with
  `l2psupp::o2o` before scoring.
- Multiple requested collections are combined into one GSVA call. Gene-set
  names therefore need to be unique across the selected collections.
- The heatmap uses base R `stats::heatmap`, including row scaling and
  clustering.

## Runtime profile and reproducibility

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

## Interface and deployment

The complete portable interface is defined in
[schemas/interface.yml](schemas/interface.yml). For a Code Ocean deployment,
use the [OMIX GSVA adapter](https://github.com/NIDAP-Community/OMIX-GSVA).
The adapter supplies platform-specific input discovery and UI configuration;
this module remains the source of truth for reusable scientific behavior.
