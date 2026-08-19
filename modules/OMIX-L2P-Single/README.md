# OMIX L2P Single

Platform-neutral L2P over-representation analysis for one DEG comparison. The
module accepts explicit input and output paths so it can be called from an HPC
job, container, Galaxy wrapper, or a platform adapter.

**Code Ocean deployment adapter:** [OMIX-L2P-Single](https://github.com/NIDAP-Community/OMIX-L2P-Single)

## Run from the command line

```bash
Rscript scripts/run_l2p_single.R \
  --deg_table /path/to/DEG_Analysis.csv \
  --comparison Treatment-Control \
  --output_dir results
```

The module can infer common gene, ranking-statistic, significance, and fold
change column names from the comparison. Override them with
`--gene_names_column`, `--t_statistic_column`, `--significance_column`, and
`--fold_change_column` when necessary.

The reusable implementation is in `R/L2P_Analysis.R`; see
`schemas/interface.yml` for the machine-readable contract.
