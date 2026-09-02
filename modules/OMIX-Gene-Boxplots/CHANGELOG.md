# Changelog

## 0.2.0

- Preserve the original `Boxplot_with_Stats.R` implementation verbatim as the
  module's compatibility reference, including its public functions and
  advanced behavior.
- Replace the simplified implementation with a thin OMIX workflow wrapper.
- Restore original category ordering, duplicate-gene handling, three-sample
  default, and ANOVA/Tukey behavior.
- Retain nominal p-values as the intentional default for the OMIX precomputed
  DEG workflow; adjusted values remain selectable.

## 0.1.2

- Restore the original CCBR boxplot visual defaults: the ordered custom group
  colors, lighter boxes, smaller filled points, right-side legend, and black
  italic comparison annotations.

## 0.1.1

- Draw each p-value as a horizontal comparison bar above its corresponding
  groups, while retaining nominal p-values as the default selectable source.

## 0.1.0

- Initial portable OMIX Gene Boxplots module.
- Supports model-consistent precomputed DEG annotations and optional
  independent within-plot statistical tests.
