# OmixPathwayPlots

`OmixPathwayPlots` standardizes supported GSEA and L2P pathway-result tables
and creates the shared OMIX pathway bubble plot. It is an optional plotting
package: its `ggplot2` dependencies intentionally do **not** belong in the
lightweight `Omix` Core package.

## What it does

- Recognizes the stable output fields from OMIX GSEA, L2P-Multi, and
  L2P-Single tables, or accepts an explicit mapping for a compatible custom
  table.
- Converts those fields to a documented pathway plotting contract: contrast,
  collection, pathway, nominal p-value and/or FDR, score, hit count, and hit
  fraction.
- Preserves the established Multi-Pathway Bubble Plot visual defaults:
  Blue-Vermilion colours, a symmetric 99th-percentile score scale, split
  collection facets, hit-count bubbles, dynamically sized and automatically
  wrapped pathway labels, and retained non-significant X-shaped points.

`plot_pathway_bubble()` is the low-level renderer: it displays every row it is
given. `plot_pathway_bubble_set()` is the higher-level legacy-compatible
selector and renderer. It uses the defaults below to return an unfaceted
combined-pathway plot, a cross-collection plot, and one plot per collection.

## Use it

The package is available from an OMIX checkout. `r-pathway` already contains
its runtime dependencies.

```bash
git clone https://github.com/NIDAP-Community/OMIX.git
R CMD INSTALL OMIX/packages/OmixPathwayPlots
```

Then start R and give the function an OMIX GSEA, L2P-Multi, or L2P-Single
table. Input format is auto-detected from the published output fields.

```r
library(OmixPathwayPlots)

gsea <- read.csv("GSEA_Results.csv", check.names = FALSE)

# Select rows with the module's own pathway-selection rule before plotting.
selected <- subset(gsea, pval <= 0.05)
plot <- plot_pathway_bubble(selected)
ggplot2::ggsave("pathway_bubble_plot.png", plot, width = 12, height = 7)
```

For the legacy-compatible automatic selection and a readable default figure
set, use `plot_pathway_bubble_set()` instead:

```r
plots <- plot_pathway_bubble_set(gsea)
save_pathway_bubble("pathway_bubble_combined.png", plots[["Combined Pathways"]])
```

For a custom stable table, explicitly map its columns. The required plotting
fields are `contrast`, `pathway`, and `score`, with at least one of `pval` or
`padj` and one of `size` or `fraction`.

```r
plot <- plot_pathway_bubble(
  my_results,
  input_format = "canonical",
  mapping = c(
    contrast = "comparison",
    collection = "database",
    pathway = "term",
    pval = "p_value",
    score = "normalized_score",
    size = "hit_count"
  )
)
```

## Defaults and options

`plot_pathway_bubble()` prefers nominal `pval` when available, uses a 0.05
threshold only to choose circle versus X point shapes, and retains all input
rows by default. `plot_pathway_bubble_set()` adds the validated legacy
automatic selection policy. Its initial visual and selection defaults are:

Pass `selection_contrasts` and `plot_contrasts` when a workflow needs a
specific biological contrast order. `selection_contrasts` must have retained
results and controls which contrasts rank pathways. `plot_contrasts` controls
the x-axis order and may include an analysis contrast with no retained rows;
that contrast is drawn as an empty column rather than omitted.

| Setting | Default |
| --- | --- |
| Automatic selection | Top 20 distinct pathways per selection scope, ranked by their lowest selected p-value across contrasts (`pval` when available, otherwise `padj`) |
| Selection scopes | Combined single panel, across all collections, and within each collection; returned as separate plots |
| Output dimensions | Automatic: 0.65 inches per displayed pathway plus 2.5 inches for axes and legends; width also expands for additional collection panels and long unwrapped pathway names |
| Layout | Split facets by full collection name |
| Palette | `blue_vermilion` |
| Score colour range | Combined and across-collection plots share a symmetric 99th-percentile range; each standalone collection plot uses its own range by default |
| Bubble size | Hit count (`size`), else hit fraction (`fraction`) |
| Size scale | Legacy area scale with maximum size 14 |
| Labels | 16 pt at 10 rows, 12 pt for 21–35 rows, smaller only for denser plots; all-uppercase source labels retain their source capitalization and other labels retain their supplied capitalization; automatic wrap width of 28 characters for up to 10 rows, narrowing as row count grows; contrast angle 30 degrees. The combined single-panel plot retains source prefixes; faceted and one-collection plots omit them because the panel strip already identifies the source. All requested contrasts remain on the x-axis; an empty column means none of the selected pathways had a retained result row for that comparison. |
| Reference lines | None |
| Aspect ratio | 2.5 |

Use `pathway_bubble_color_limits()` when several plots must use an identical
colour range, then supply its `limits` to `plot_pathway_bubble(color_limits =
...)`.

`plot_pathway_bubble_set()` keeps the combined and across-collection plots on
one shared colour scale, so their colours are directly comparable. Its
standalone collection plots default to an independent scale, which avoids a
narrow-range collection looking washed out because another collection has much
larger scores. Set `collection_color_scale = "shared"`, or provide explicit
`color_limits`, when cross-collection colour comparability is more important
than within-collection contrast.

`save_pathway_bubble()` uses the recommended dimensions stored on each plot.
This preserves the legacy maximum bubble diameter while preventing adjacent
pathway rows from overlapping. To override the recommendation, supply an
explicit `width` and/or `height`.

For a reproducible module or workflow output, pass a complete plot set to
`save_pathway_bubble_set()`. It writes each PNG at its recommended dimensions
and a CSV manifest containing the significance statistic and threshold,
selection scope, pathway count, colour limits, dimensions, and filename.

## Provenance

This package extracts the portable input-standardization and rendering logic
from the archived Multi-Pathway Bubble Plot application bundle. It deliberately
does not include that bundle's Shiny server, UI, manifest, or static assets.
The initial regression tests cover the GSEA and L2P column contracts and the
established rendering defaults before the L2P and GSEA modules are migrated.

## Development

Run the package tests after installing its dependencies:

```r
testthat::test_local("packages/OmixPathwayPlots")
```

Also run the repository layout check from the OMIX root:

```bash
Rscript tests/test-monorepo-layout.R
```
