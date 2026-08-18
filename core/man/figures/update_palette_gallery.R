core_dir <- if (file.exists(file.path("core", "R", "color-utils.R"))) {
  "core"
} else {
  "."
}
source(file.path(core_dir, "R", "color-utils.R"))

figures_dir <- file.path(core_dir, "man", "figures")
dir.create(figures_dir, recursive = TRUE, showWarnings = FALSE)

palette_groups <- list(
  "default" = c("Default", "Okabeito"),
  "brewer" = c("Accent", "Dark2", "Paired", "Pastel1", "Pastel2", "Set1", "Set2", "Set3", "Qualitative"),
  "ggsci" = c("NPG_1", "NPG_2", "AAAS_1", "AAAS_2", "NEJM_1", "NEJM_2", "Lancet_1", "Lancet_2", "JAMA_1", "JAMA_2", "JCO_1", "JCO_2", "UCSCGB_1", "UCSCGB_2")
)

group_titles <- c(
  "default" = "Omix default palettes",
  "brewer" = "Omix RColorBrewer palettes",
  "ggsci" = "Omix ggsci palettes"
)

max_colors_per_row <- 12

make_palette_caption <- function(palette_name) {
  palette_colors <- unname(pick_palette(palette_name))
  palette_count <- length(palette_colors)

  if (palette_count <= max_colors_per_row) {
    sprintf("%s (%d colors; all colors shown)", palette_name, palette_count)
  } else {
    sprintf(
      "%s (%d colors; all colors shown in %d rows)",
      palette_name,
      palette_count,
      ceiling(palette_count / max_colors_per_row)
    )
  }
}

for (group_name in names(palette_groups)) {
  palette_names <- palette_groups[[group_name]]
  output_file <- file.path(figures_dir, paste0("palette-gallery-", group_name, ".png"))

  grDevices::png(
    filename = output_file,
    width = 1200,
    height = max(220, sum(vapply(
      palette_names,
      function(name) 170 * ceiling(length(pick_palette(name)) / max_colors_per_row),
      numeric(1)
    ))),
    res = 140
  )

  panel_heights <- vapply(
    palette_names,
    function(name) ceiling(length(pick_palette(name)) / max_colors_per_row),
    numeric(1)
  )
  graphics::layout(matrix(seq_along(palette_names), ncol = 1), heights = panel_heights)
  graphics::par(mar = c(1, 1, 3, 1), oma = c(0, 0, 2, 0))

  for (palette_name in palette_names) {
    palette_colors <- unname(pick_palette(palette_name))
    palette_count <- length(palette_colors)
    palette_rows <- ceiling(palette_count / max_colors_per_row)

    graphics::plot.new()
    graphics::plot.window(
      xlim = c(0, min(max_colors_per_row, palette_count)),
      ylim = c(0, palette_rows)
    )

    for (color_index in seq_along(palette_colors)) {
      color_row <- ceiling(color_index / max_colors_per_row)
      color_column <- (color_index - 1) %% max_colors_per_row
      y_bottom <- palette_rows - color_row
      graphics::rect(
        color_column,
        y_bottom,
        color_column + 1,
        y_bottom + 1,
        col = palette_colors[color_index],
        border = NA
      )
    }

    graphics::box(col = "grey80")
    graphics::title(main = make_palette_caption(palette_name), line = 0.6, cex.main = 1)
  }

  graphics::mtext(group_titles[[group_name]], outer = TRUE, line = 0.5, cex = 1.2, font = 2)
  grDevices::dev.off()
}
