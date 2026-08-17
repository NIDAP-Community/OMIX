# OMIX GSEA Preranked Legacy - App Panel User Guide

Gene Set Enrichment Analysis (GSEA) for pre-ranked gene lists using the fgsea package.

## Quick Start

1. **Try with demo data**: Leave 'DEG Table File' blank to automatically use the attached Mouse RNA-seq demo dataset
2. **Or upload your own**: Use the 'DEG Table File' parameter to upload your DEG results (RDS/CSV/TSV)
3. Configure the 'Gene Score Suffix' to match your ranking columns (default: `_tstat`)
4. Select pathway 'Collections' to test (default: Hallmark + REACTOME)
5. Run the analysis

## Basic Settings (Required)

Configure these essential parameters in the **⭐ Basic Settings** category:

### 1. DEG Table File
**Input your differential expression data:**
- **Upload your own file**: Click to upload RDS, CSV, or TSV format
- **Use demo data**: Leave blank to automatically use the attached demo dataset (Mouse RNA-seq example)

**Required columns in your file:**
- Gene identifier column (e.g., `Gene`, `symbol`)
- Ranking score column(s) with suffix pattern `{comparison}{suffix}`
  
**Example for comparisons with `_tstat` suffix:**
```
Gene        B-A_tstat   C-A_tstat   
Serpina3f   5.23        3.12       
Abl1        -3.45       -2.89       
...
```

### 2. Gene Names Column
**Which column contains gene identifiers** (default: Gene)
- Must match the column name exactly in your DEG table
- Common examples: `Gene`, `gene_name`, `symbol`, `gene_id`

### 3. Species
**Select your input organism** (default: Mouse)
- Options: Human, Mouse, Rat, Dog, Rabbit, Zebrafish, Drosophila, Chimpanzee, Macaque
- Non-human genes are automatically converted to human orthologs for pathway matching

### 4. Gene Score Suffix
**Pattern to identify ranking columns** (default: `_tstat`)
- Select `_tstat` if your ranking columns are named like `ComparisonA_tstat`, `ComparisonB_tstat`
- Select `_logFC` if using log fold-change rankings
- The tool will analyze all columns ending with this suffix as separate contrasts

### 5. Pathways Species
**Species in the pathways database** (default: Human)
- **Recommended**: Keep as `Human` for most analyses
- Use Human collections (H/C prefix) regardless of your input species
- Input genes are automatically mapped to human orthologs
- Only select `Mouse` if specifically using M-prefix collections

### 6. Collections
**Which MSigDB pathways to test** (default: Hallmark + REACTOME)

Copy and paste one or more comma-separated collection names:

**Quick options:**
- `H: hallmark gene sets` - Start here! Well-defined biological states (50 gene sets)
- `H: hallmark gene sets,C2:CP:REACTOME: Reactome gene sets` - Hallmark + REACTOME (default)
- `H: hallmark gene sets,C5:GO:BP: GO biological process` - Hallmark + GO Biological Process

See the main README for the complete collection list.

## Available MSigDB Collections

### Human Collections (Pathways Species = Human) - **RECOMMENDED**

Use these for **all species** - your input genes will be automatically mapped to human orthologs:

#### Core Collections (Most Popular)

- `H: hallmark gene sets` - Well-defined biological states and processes (50 focused gene sets)
- `C2:CP:REACTOME: Reactome gene sets` - Reactome pathways
- `C2:CP:KEGG_LEGACY: KEGG Legacy gene sets` - KEGG pathways
- `C5:GO:BP: GO biological process` - Gene Ontology Biological Process

#### Additional Human Collections

**Pathway & Network Collections:**
- `C2:CGP: chemical and genetic pertubations`
- `C2:CP:BIOCARTA: BioCarta gene sets`
- `C2:CP:WIKIPATHWAYS: WikiPathways gene sets`

**Regulatory Target Collections:**
- `C3:TFT:GTRD: GTRD transcription factor targets`
- `C3:MIR:MIRDB: miRDB microRNA targets`

**Gene Ontology Collections:**
- `C5:GO:CC: GO cellular component`
- `C5:GO:MF: GO molecular function`

**Specialized Collections:**
- `C1: positional gene sets`
- `C6: oncogenic signature gene sets`
- `C7: immunologic signature gene sets`
- `C8: cell type signature gene sets`

### Mouse Collections (Pathways Species = Mouse) - **SPECIALIZED USE**

Use M-prefix collections **only** when you specifically need mouse-specific pathways:

- `MH: orthology-mapped hallmark gene sets`
- `M2:CP:REACTOME: Reactome gene sets`
- `M5:GO:BP: GO biological process`
- Other M-prefix collections: `M1`, `M2:CGP`, `M2:CP:BIOCARTA`, `M2:CP:WIKIPATHWAYS`, `M3:GTRD`, `M3:MIRDB`, `M5:GO:CC`, `M5:GO:MF`, `M5:MPT`, `M8`

### Usage Examples

**Default (Hallmark + REACTOME):**
```
H: hallmark gene sets,C2:CP:REACTOME: Reactome gene sets
```

**Comprehensive pathway analysis:**
```
H: hallmark gene sets,C2:CP:REACTOME: Reactome gene sets,C2:CP:KEGG_LEGACY: KEGG Legacy gene sets,C2:CP:BIOCARTA: BioCarta gene sets
```

**Cancer research:**
```
H: hallmark gene sets,C6: oncogenic signature gene sets,C2:CP:REACTOME: Reactome gene sets
```

**Immunology research:**
```
H: hallmark gene sets,C7: immunologic signature gene sets,C2:CP:REACTOME: Reactome gene sets
```

## Optional: Advanced Configuration

### Gene Set Filters

- **Min Geneset Size** (default: 15): Exclude gene sets with fewer genes
- **Max Geneset Size** (default: 500): Exclude gene sets with more genes

### Statistical Settings

- **Number of Permutations** (default: 5000): More permutations = more accurate p-values (range: 1000-10000)
- **Random Seed** (default: 246642): Ensures reproducible results
- **FDR Correction Mode** (default: within each collection): 
  - `within each collection` - Correct within each MSigDB collection separately
  - `over all collections` - Correct across all pathways (more stringent)
- **Collapse Redundancy** (default: false): Reduce redundant pathways using fgsea's collapsing

### Output Options

- **Sort By** (default: pval): Order results by p-value, adjusted p-value, NES, ES, or pathway name
- **Image Width/Height** (default: 2500 pixels): Plot dimensions
- **Image Resolution** (default: 300 dpi): 300 for publication, 150 for web

## Understanding Your Results

### Output Files

1. **gsea_results.csv**: Complete enrichment results table with:
   - Pathway name and collection
   - NES (Normalized Enrichment Score): positive = enriched in upregulated genes, negative = downregulated
   - P-value and adjusted p-value (FDR)
   - Gene set size and overlap with your data
   - Leading edge genes

2. **Plots** (if generated):
   - Enrichment plots showing pathway distribution
   - Summary tables of significant pathways

### Key Metrics

- **NES (Normalized Enrichment Score)**: Effect size; |NES| > 1.5 indicates strong enrichment
- **P-value**: Statistical significance
- **FDR**: False Discovery Rate; FDR < 0.05 is typically significant
- **Leading Edge Genes**: Core genes driving the enrichment signal

## Multi-Contrast Analysis

GSEA automatically analyzes all ranking columns matching your Gene Score Suffix.

**Example:**
If your DEG table has `TreatmentA_tstat`, `TreatmentB_tstat`, and `TreatmentC_tstat`, and you set Gene Score Suffix = `_tstat`, the tool will run GSEA for all three treatments and combine results into a single table.

## Tips for Best Results

1. **Start with Hallmark**: Use `H: hallmark gene sets` for the most interpretable results
2. **Match your ranking metric**: Use `_tstat` for t-statistics, `_logFC` for fold-changes
3. **Keep Pathways Species as Human**: Use Human collections with automatic ortholog mapping
4. **Filter gene set sizes**: Defaults (15-500) work well for most analyses
5. **Check leading edge genes**: These genes reveal the biological mechanism
6. **Try the demo data first**: Familiarize yourself with the tool before analyzing your data

## Support

For questions or issues:
- **NIDAP Team**: NCICCBRNIDAP@mail.nih.gov
- **CCBR**: CCR Collaborative Bioinformatics Resource

---

**OMIX Collection** | **Bioinformatics** | **Pathway Analysis** | **R** | **GSEA**
