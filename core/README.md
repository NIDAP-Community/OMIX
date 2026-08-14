# Omix Core

`core/` is the reusable R package in the OMIX monorepo. It contains stable
utilities that can be shared by multiple analysis modules. The current public
API focuses on selecting, extending, and plotting color palettes.

## Install from GitHub

For analysis use, install the released core package directly from GitHub:

```r
install.packages("remotes")
remotes::install_github("NIDAP-Community/Omix", subdir = "core")

library(Omix)
```

`remotes` installs the package dependencies declared in `core/DESCRIPTION`.
This is the recommended path for analysts and for modules running outside a
local OMIX checkout. Access to a private repository requires GitHub
credentials configured in the R environment.

## Use from a module

After installing core, call its utilities with the `Omix::` namespace:

```r
sample_colors <- Omix::get_color_palette(
  num_col = 6,
  sel_pal = "Dark2"
)
```

## Development setup

For contributors working inside a local OMIX checkout, load the package
without installing it:

```r
install.packages(c("colorspace", "ggsci", "RColorBrewer", "devtools"))
devtools::load_all("core")
```

Use this path while changing `core/`; analysis users should use the GitHub
installation above.

## Public utilities

| Utility | Use |
| --- | --- |
| `get_color_palette()` | Return exactly the requested number of colors, with optional plotting. |
| `get_colors()` | Return a palette plus its original size before extension. |
| `get_random_colors()` | Generate reproducible, visually distinct colors. |
| `get_hex_color()` | Convert named R colors to hexadecimal values. |
| `get_closest_color()` | Find the nearest named R color for a hex value. |
| `colorvect()` | Name a hex color vector with its closest R color names. |
| `plot_palette()` | Draw a supplied palette directly. |

## Get a palette

```r
colors <- get_color_palette(
  num_col = 8,
  sel_pal = "Dark2"
)
```

`get_color_palette()` returns a character vector of colors. It preserves the source palette colors first, then generates extra colors when a larger palette
is requested.

```r
# Extend an eight-color palette to 40 colors reproducibly.
extended_colors <- get_color_palette(
  num_col = 40,
  sel_pal = "Dark2",
  seed = 10
)

# Use your own colors, extending them only when needed.
custom_colors <- get_color_palette(
  num_col = 6,
  use_custom_pal = TRUE,
  custom_pal = c("red", "blue", "gold"),
  seed = 10
)

# Display the selected palette as well as returning it.
visible_colors <- get_color_palette(
  num_col = 12,
  sel_pal = "Default",
  print = TRUE
)
```

The function signature is:

```r
get_color_palette(
  num_col = 10,
  sel_pal = "Dark2",
  use_custom_pal = FALSE,
  custom_pal = c(),
  split_pal_plot = TRUE,
  seed = 10,
  print = FALSE
)
```

## Inspect and reuse colors

```r
palette_info <- get_colors(num_col = 10, sel_pal = "Default")
palette_info$colors
palette_info$palette_size

get_hex_color(c("red", "steelblue"))
get_closest_color("#1B9E77")
plot_palette(colors, n_colors = length(colors), split_columns = TRUE)
```

## Available palettes

Built-in palettes: `Default`, `Okabeito`.

RColorBrewer qualitative palettes: `Accent`, `Dark2`, `Paired`, `Pastel1`,
`Pastel2`, `Set1`, `Set2`, `Set3`, `Qualitative`.

ggsci palettes: `NPG_1`, `NPG_2`, `AAAS_1`, `AAAS_2`, `NEJM_1`, `NEJM_2`,
`Lancet_1`, `Lancet_2`, `JAMA_1`, `JAMA_2`, `JCO_1`, `JCO_2`, `UCSCGB_1`,
`UCSCGB_2`.

![Omix default palettes](man/figures/palette-gallery-default.png)

![RColorBrewer palettes](man/figures/palette-gallery-brewer.png)

![ggsci palettes](man/figures/palette-gallery-ggsci.png)

## Test core

Run the core tests from the monorepo root:

```r
testthat::test_local("core")
```

The palette test suite includes committed reference artifacts for the
40-color `Dark2` extension. Refresh them only when intentionally updating the
expected palette behavior:

```r
Sys.setenv(OMIX_UPDATE_COLOR_ARTIFACTS = "true")
testthat::test_file("core/tests/testthat/test-getcolorpalette.R")
```
