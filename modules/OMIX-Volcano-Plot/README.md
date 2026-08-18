# OMIX Volcano Plot

Platform-neutral volcano-plot generation for differential-expression tables.
The module accepts an explicit input path and output directory, so it can be
called from an HPC job, container, Galaxy wrapper, or a platform adapter.

## Run from the command line

```bash
Rscript scripts/run_volcano_plot.R \
  --deg_table /path/to/DEG_Analysis.csv \
  --output_dir results
```

The feature identifier, significance, and log2-fold-change columns are inferred
when their names follow common DEG conventions. Feature detection prefers
`GeneName`, then `Gene Symbols`, followed by common generic identifier names.
They can be set explicitly with
`--column_with_feature_id`, `--significance_column`, and
`--log2_fold_change_column`. For multiple comparisons, provide matching
comma-separated significance and fold-change column lists.

The reusable implementation is in `R/Volcano_Plot_Enhanced.R`; see
`schemas/interface.yml` for the machine-readable contract.
