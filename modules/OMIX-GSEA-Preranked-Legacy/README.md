# OMIX GSEA

Gene Set Enrichment Analysis (GSEA) for pre-ranked gene lists using the fgsea package. Part of the OMIX analysis suite.

## Overview

**Version**: v5.0 | **Part of the OMIX analysis suite**

Gene Set Enrichment Analysis (GSEA) determines whether predefined gene sets show statistically significant, concordant differences between two biological states. This tool uses **pre-ranked gene lists** from differential expression analysis to evaluate pathway enrichment using the fast fgsea algorithm.

### What is GSEA?

Unlike over-representation analysis (ORA) which tests if specific genes are enriched in a pathway, GSEA evaluates whether genes in a pathway are **concentrated at the top or bottom of a ranked gene list**. This approach:

- Uses **all genes** in your data, not just significant ones
- Considers **gene rankings** (t-statistics, fold changes), preserving biological signal
- Identifies **subtle but coordinated changes** in pathway activity
- Is **more sensitive** to pathway-level effects than ORA

### Key Features

- **Pre-ranked GSEA**: Uses your gene rankings (t-statistics, log fold-change) directly
- **Comprehensive MSigDB coverage**: Access to Hallmark, GO, REACTOME, KEGG, and more
- **Cross-species support**: Automatic ortholog mapping for non-human organisms
- **Multiple contrasts**: Analyze multiple comparisons in a single run
- **Fast permutation testing**: Efficient multi-level split Monte-Carlo scheme
- **Leading edge genes**: Identifies core genes driving enrichment signals
- **Publication-ready outputs**: Enrichment statistics, FDR correction, and plots

## How It Works

1. **Input**: Ranked gene list from differential expression (e.g., sorted by t-statistic)
2. **Enrichment Calculation**: For each pathway, calculates an enrichment score (ES) that reflects whether pathway genes are concentrated at the top (upregulated) or bottom (downregulated) of the ranking
3. **Statistical Testing**: Permutation testing determines if ES is significantly different from random
4. **FDR Correction**: Benjamini-Hochberg correction controls for multiple testing
5. **Output**: Normalized enrichment scores (NES), p-values, FDR, and leading edge genes

## When to Use GSEA vs. ORA

**Use GSEA when:**
- You want to detect subtle, coordinated pathway changes
- You have well-powered experiments with reliable gene rankings
- You want to use information from all genes, not just significant ones
- You're analyzing bulk RNA-seq with good statistical power

**Use ORA (L2P tools) when:**
- You have a clear set of differentially expressed genes
- You want simpler, more interpretable results
- You're working with heterogeneous data (e.g., single-cell)
- You want to compare enrichment across multiple conditions side-by-side

## Input Requirements

### DEG Table (Data Asset or Upload)

Differential expression results with:
- **Gene identifiers** (e.g., HGNC symbols)
- **Ranking scores**: t-statistics or log fold-changes for each comparison
- **Format**: RDS, CSV, or TSV

**Column naming pattern:** `{comparison}_{suffix}`  
Example: `TreatmentA_tstat`, `TreatmentB_tstat`, `Control_tstat`

**Demo dataset included**: Mouse RNA-seq data runs automatically if no file is uploaded.

## Supported Species

Human, Mouse, Rat, Dog, Rabbit, Zebrafish, Drosophila, Chimpanzee, Macaque

Non-human genes are automatically converted to human orthologs before pathway analysis, then results are mapped back to original gene IDs.

## Pathway Collections

Access to **MSigDB collections** including:

- **Hallmark** (H): Core biological states and processes (50 gene sets)
- **Curated pathways** (C2): REACTOME, KEGG, BioCarta, WikiPathways
- **Regulatory targets** (C3): Transcription factors, microRNAs
- **Gene Ontology** (C5): Biological process, cellular component, molecular function
- **Oncogenic** (C6): Cancer gene signatures
- **Immunologic** (C7): Immune cell states and perturbations
- **Cell type** (C8): Cell type marker genes

**Recommendation**: Start with Hallmark for the most interpretable results.

## Output Files

### 1. gsea_results.csv

Complete enrichment results table:
- Pathway name and collection
- **NES** (Normalized Enrichment Score): Positive = enriched in upregulated genes, negative = downregulated
- **P-value** and **FDR**: Statistical significance
- Gene set size and overlap
- **Leading edge genes**: Core genes driving enrichment

### 2. Plots (if generated)

- Enrichment plots showing pathway distribution across gene rankings
- Summary tables of significant pathways

## Key Result Metrics

- **NES (Normalized Enrichment Score)**: Effect size; |NES| > 1.5 typically indicates strong enrichment
- **P-value**: Raw statistical significance from permutation test
- **FDR (False Discovery Rate)**: Multiple testing-corrected p-value; < 0.05 is typically significant
- **Leading Edge Genes**: Subset of pathway genes contributing most to enrichment

## Algorithm Details

Uses the **fgsea** R Bioconductor package:
- **Fast pre-ranked GSEA**: Adaptive multi-level split Monte-Carlo permutation scheme
- **Permutation testing**: Estimates significance while preserving gene-gene correlations
- **FDR correction**: Benjamini-Hochberg procedure controls false discovery rate
- **Normalized scoring**: Accounts for pathway size differences

## Method Comparison

| Feature | GSEA (this tool) | ORA (L2P tools) |
|---------|------------------|-----------------|
| Input | Ranked gene list | Gene subset (DEGs) |
| Uses all genes | ✓ | ✗ |
| Statistical power | Higher for subtle effects | Higher for strong effects |
| Interpretation | Enrichment score + direction | Hit count + odds ratio |
| Multi-contrast viz | Table | Bubble plot |

## References

- **fgsea**: Korotkevich G et al. (2021). Fast gene set enrichment analysis. *bioRxiv*. doi:10.1101/060012
- **Original GSEA**: Subramanian A et al. (2005). Gene set enrichment analysis: A knowledge-based approach for interpreting genome-wide expression profiles. *PNAS*. doi:10.1073/pnas.0506580102
- **MSigDB**: Liberzon A et al. (2015). The Molecular Signatures Database (MSigDB) hallmark gene set collection. *Cell Systems*. doi:10.1016/j.celsys.2015.12.004

## Support

For questions or issues:
- **NIDAP Team**: NCICCBRNIDAP@mail.nih.gov
- **CCBR**: CCR Collaborative Bioinformatics Resource

For detailed step-by-step instructions on using the App Panel, see `/code/README.md`.

---

**OMIX Collection** | **Bioinformatics** | **Pathway Analysis** | **R** | **GSEA**
