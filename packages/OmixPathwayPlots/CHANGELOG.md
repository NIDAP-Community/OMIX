# Changelog

## 0.1.4

- Keep source prefixes only on the combined single-panel plot. Faceted
  cross-collection and one-collection figures already identify their source
  in a panel strip, so their pathway labels remain uncluttered.

## 0.1.3

- Retain every requested contrast as an x-axis column in automatically selected
  plot sets, even when none of the selected pathways has a retained result row
  for that contrast. An empty column now means "no selected pathway result",
  not "comparison absent".

## 0.1.2

- Suppress redundant source prefixes such as `Hallmark:` and `Reactome:` on
  collection-specific plots; retain them on combined and cross-collection
  plots where source identity is informative.

## 0.1.1

- Use an independent colour scale for each standalone collection plot by
  default, while retaining a shared scale for combined and across-collection
  plots. Explicit colour limits continue to override both behaviors.
- Add `save_pathway_bubble_set()` for writing an entire selected plot set and
  a provenance manifest with its actual colour limits and dimensions.

## 0.1.0

- Initial portable OMIX pathway bubble-plot package.
