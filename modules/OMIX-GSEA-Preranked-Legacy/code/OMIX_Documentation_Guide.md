# OMIX Pathway Analysis Suite - Documentation Updates

**Date:** January 8, 2026  
**Contact:** NIDAP Team

---

## Overview

The OMIX pathway analysis suite now includes enhanced documentation to help users navigate and utilize the tools more effectively. This guide explains the new documentation structure implemented across all three OMIX capsules.

---

## OMIX Suite Capsules

### 🔬 **OMIX L2P Single**
Over-representation analysis for single differential expression contrasts
- **Location:** `/capsule/9713710`
- **Purpose:** Fisher's exact test for pathway enrichment in gene lists
- **Use case:** Single comparison (e.g., Treatment vs Control)

### 🔬 **OMIX L2P Multi**
Over-representation analysis for multiple differential expression contrasts
- **Location:** `/capsule/8161572`
- **Purpose:** Compare pathway enrichment across multiple contrasts
- **Use case:** Multi-group comparisons (e.g., Treatment A, B, C vs Control)

### 🔬 **OMIX GSEA**
Gene Set Enrichment Analysis using fgsea
- **Location:** `/capsule/8775048`
- **Purpose:** Pre-ranked GSEA with MSigDB collections
- **Use case:** Ranked gene list enrichment analysis

---

## New Documentation Structure

### 📋 **CHANGELOG.md**

**What it does:** Tracks all changes, improvements, and bug fixes with dates.

**Why it matters:** 
- Quickly see what's new without digging through git history
- Understand version differences
- Troubleshoot issues tied to specific updates
- Track evolution of analysis methods

**Location:** Root of each capsule (same level as README.md)

**Format:**
```
## [Date] - Version Description
### Added
- New features

### Changed
- Modifications to existing features

### Fixed
- Bug fixes
```

---

### 📖 **Two-README Structure**

We now have **two README files** serving different audiences:

#### **`/README.md`** - *Conceptual Overview*

**For:** Browsing users deciding whether to use the capsule

**Contains:**
- What the tool does (high-level purpose)
- Scientific methods and algorithms
- When to use this tool vs alternatives
- Comparison between related methods (e.g., L2P vs GSEA)
- Key publications and references

**Visible:** On capsule landing page when users first arrive

**Example sections:**
- Overview
- Methods & Algorithms
- When to Use This Tool
- Scientific Background
- Citations

---

#### **`/code/README.md`** - *Step-by-Step Tutorial*

**For:** Active users in the IDE running analyses

**Contains:**
- Detailed App Panel parameter guide
- Step-by-step walkthrough with examples
- Input data requirements and formats
- Column naming conventions
- Troubleshooting tips
- Parameter selection guidance
- Output interpretation

**Visible:** Most prominent when working inside the IDE

**Example sections:**
- Quick Start Guide
- Parameter Reference
- Input Data Format
- Example Workflow
- Troubleshooting
- Advanced Usage

---

## Benefits of New Structure

### ✅ **Clearer Navigation**
Users get the right information for their current task—conceptual overview when browsing, practical guide when analyzing.

### ✅ **Less Overwhelming**
Information is separated by purpose rather than dumped into one large document.

### ✅ **Better Onboarding**
Landing page focuses on "Should I use this?" while IDE focuses on "How do I use this?"

### ✅ **Version Tracking**
CHANGELOG documents the evolution of each tool, making it easier to track improvements and understand behavior changes.

### ✅ **Reduced Support Burden**
Users can self-serve more effectively with targeted, context-appropriate documentation.

---

## Usage Example

**Scenario:** A researcher wants to perform pathway analysis on RNA-seq results.

1. **Browse Phase** (Capsule Landing Page)
   - Reads `/README.md` to understand the difference between L2P and GSEA
   - Learns about Fisher's exact test vs pre-ranked enrichment
   - Decides GSEA is appropriate for their ranked gene list
   - Checks CHANGELOG to see recent updates

2. **Analysis Phase** (IDE)
   - Opens OMIX GSEA capsule
   - Reads `/code/README.md` for parameter guidance
   - Follows step-by-step tutorial to configure Gene Score Suffix
   - Refers to troubleshooting section when column names don't match

3. **Future Reference**
   - Checks CHANGELOG before re-running analysis to see if methods changed
   - Reviews `/code/README.md` for parameter adjustments on new datasets

---

## Recent Major Updates (2026-01-07 to 2026-01-08)

### All Three Capsules
- ✅ Added CHANGELOG.md for version tracking
- ✅ Implemented two-README structure (conceptual + tutorial)
- ✅ Standardized support contact to "NIDAP Team"
- ✅ Added visual branding footers to all documentation
- ✅ Enhanced demo dataset documentation and visibility
- ✅ Improved metadata tags for discoverability (added "MSigDB", "gene-sets")
- ✅ Fixed named parameters support in App Panel for proper CLI argument handling
- ✅ Updated default organism from "Human" to "Mouse" to match demo datasets

### L2P Single & Multi
- ✅ Simplified capsule names (removed "Pathway Analysis")
- ✅ Exposed Demo DEG Table in App Panel
- ✅ Reorganized L2P Multi App Panel (10 categories → 6 standardized categories)
- ✅ Aligned app panel instructions with two-README structure

### OMIX GSEA
- ✅ Complete documentation overhaul targeting App Panel users
- ✅ Enhanced MSigDB collection guidance with research area examples
- ✅ Created conceptual `/README.md` from scratch
- ✅ Transformed `/code/README.md` from CLI-focused to App Panel tutorial

---

## Best Practices for Users

### 📌 **Before Running**
1. Check CHANGELOG.md for recent updates
2. Read `/README.md` to confirm you're using the right tool
3. Review demo dataset to understand expected input format

### 📌 **During Analysis**
1. Keep `/code/README.md` open for parameter reference
2. Start with demo data to validate your workflow
3. Refer to troubleshooting section for common issues

### 📌 **After Analysis**
1. Document which version you used (check CHANGELOG date)
2. Note any parameter customizations for reproducibility

---

## Questions or Feedback?

**Support:** NIDAP Team

**Tags for Discovery:**
- `OMIX`
- `pathway-analysis`
- `enrichment`
- `gene-sets`
- `bioinformatics`
- `R`
- `Bulk RNA-seq`
- `Differential expression`
- `MSigDB`

---

## Summary

The new documentation structure provides:
- **CHANGELOG.md** → Version history and updates
- **`/README.md`** → Conceptual overview for browsing
- **`/code/README.md`** → Practical tutorial for analysis

This approach ensures users get the right information at the right time, improving both the browsing and analysis experience.

---

**OMIX Collection** | **Bioinformatics** | **Pathway Analysis** | **R**
