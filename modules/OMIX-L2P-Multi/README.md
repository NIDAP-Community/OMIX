# OMIX L2P Multi

Platform-neutral L2P over-representation analysis for comparing multiple DEG
contrasts. The module accepts explicit input and output paths so it can be
called from an HPC job, container, Galaxy wrapper, or a platform adapter.

**Code Ocean deployment adapter:** [OMIX-L2P-Multi](https://github.com/NIDAP-Community/OMIX-L2P-Multi)

## Run from the command line

```bash
Rscript scripts/run_l2p_multi.R \
  --deg_table /path/to/DEG_Analysis.csv \
  --comparisons TreatmentA-Control,TreatmentB-Control \
  --output_dir results
```

For conventional wide DEG tables, the module derives columns such as
`TreatmentA-Control_tstat`, `TreatmentA-Control_pval`, and
`TreatmentA-Control_FC`. Supply explicit comma-separated column lists when
your table uses different names.

The reusable implementation is in `R/analysis_functions.R`; see
`schemas/interface.yml` for the machine-readable contract.
