# Changelog

All notable changes to OMIX GSEA will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).
Version numbers correspond to adapter release versions (integers: v1, v2, v3, etc.).

## [Unreleased]

### Changed
- Moved the reusable GSEA implementation to `R/GSEA_Preranked.R` and added
  the platform-neutral `scripts/run_gsea.R` entry point (2026-08-17).
- Auto-detect the gene-name column (`GeneName`, then `Gene`) when it is not
  supplied, and use the current `C2:CP:REACTOME` MSigDB collection identifier.
- Preserve the original gene-name column while mapping ortholog results back
  to the input species, so auto-detected columns such as `GeneName` complete
  successfully for cross-species analyses.
- Replaced the hard-coded `/results` figure path with an explicit output
  directory, allowing the same implementation to run outside a deployment platform.
- Removed platform-specific capsule files from the canonical OMIX module; capsule
  repositories are deployment adapters generated from this source.

### Added
- OMIX Suite Documentation Guide file included in results output (2026-01-08)
  - Explains CHANGELOG and two-README structure
  - Provides usage examples and best practices
  - Available via `/code/OMIX_Documentation_Guide.md`
- Comprehensive user documentation (2026-01-07)
  - Created conceptual `/README.md` with GSEA overview, algorithm explanation, and when to use GSEA vs. ORA
  - Created step-by-step `/code/README.md` App Panel tutorial
  - Added method comparison table (GSEA vs. ORA)
  - Documented all MSigDB collections with usage examples
  - Added demo dataset documentation with automatic usage instructions
- Demo dataset visibility in App Panel (2026-01-07)
  - Renamed "DEG Table (Example)" to "Demo DEG Table" for consistency
  - Added help text: "Mouse RNA-seq demo data with ranking scores (t-statistics) for multiple comparisons. Used automatically if no file is uploaded."
  - Renamed "Pathways Database" to "Pathways Database (MSigDB)" with descriptive help text
- Support section with NIDAP Team contact information (2026-01-07)
- Keyword footer for visual branding consistency across OMIX suite (2026-01-07)

### Changed
- App Panel instructions restructured to numbered steps (2026-01-07)
  - Clear workflow: Try demo data → Upload your own → Configure → Run
  - Added "Advanced users" note for optional parameters
  - Improved clarity around automatic demo dataset usage
- Parameter naming simplified (2026-01-07)
  - "DEG Table File (Upload)" → "DEG Table File"

### Fixed
- App Panel now uses named parameters mode (2026-01-08)
  - Passes arguments as `--param value` instead of positional arguments
  - Prevents optparse errors when file uploads are left blank
  - Enables proper demo dataset functionality
- Empty string argument handling in main.R (2026-01-08)
  - Filters out blank file upload parameters before parsing
  - Resolves "not a valid option" errors when using demo data
  - Updated help text to emphasize "Leave blank to automatically use the attached demo dataset"
- Updated capsule description to mention demo dataset availability (2026-07-08)
- Documentation style changed from command-line focused to App Panel user-focused (2026-07-08)
- Support contact updated to "NIDAP Team" (2026-07-08)

## [v5] - 2026-07-06

### Changed
- App Panel refinements and dataset naming improvements

## [v4] - 2026-07-06

### Changed
- App Panel configuration updates and metadata improvements

## [v3] - 2026-06-29

### Added
- Comprehensive species mismatch detection
  - Detect mouse vs human gene naming patterns (title case, Rik-suffix, number-prefix)
  - Fail early with clear error messages when species parameter doesn't match gene names
  - Prevent confusing downstream errors by validating before GSEA execution

### Changed
- Fixed deprecated dplyr syntax (arrange_ → arrange with tidy evaluation)
- Updated .gitignore to exclude /results/ and /scratch/ directories

## [v2] - 2026-06-28

### Changed
- Metadata updates

## [v1] - 2026-06-28

### Added
- Initial published release of OMIX GSEA
- Pre-ranked Gene Set Enrichment Analysis using fgsea
- Comprehensive MSigDB collection support (Hallmark, GO, REACTOME, KEGG, and more)
- Species ortholog mapping (Human, Mouse, Rat, Dog, Rabbit, Zebrafish, Drosophila, Chimpanzee, Macaque)
- Multiple contrast analysis in a single run
- Fast permutation testing with adaptive multi-level split Monte-Carlo scheme
- Leading edge gene identification
- FDR correction (within collection or across all collections)

### Fixed
- Runtime errors with size column conversion to numeric
- Missing graphicsFile variable for PNG output
- Modernized dplyr syntax throughout

### Technical
- Environment: MOSuite R v0.3.2 base with custom ortholog support
- Added fgsea (Bioconductor), l2p, l2psupp (CCBR) packages via postInstall
