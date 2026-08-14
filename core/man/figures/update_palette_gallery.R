source("R/Utilities/color-utils.R")

dir.create("man/figures", recursive = TRUE, showWarnings = FALSE)

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

make_palette_caption <- function(palette_name) {
  palette_colors <- unname(pick_palette(palette_name))
  palette_count <- length(palette_colors)

  if (palette_count <= 12) {
    sprintf("%s (%d colors; all colors shown)", palette_name, palette_count)
  } else {
    sprintf("%s (%d colors; first 12 shown)", palette_name, palette_count)
  }
}

for (group_name in names(palette_groups)) {
  palette_names <- palette_groups[[group_name]]
  output_file <- file.path("man", "figures", paste0("palette-gallery-", group_name, ".png"))

  grDevices::png(
    filename = output_file,
    width = 1200,
    height = max(220, 170 * length(palette_names)),
    res = 140
  )

  graphics::par(mfrow = c(length(palette_names), 1), mar = c(1, 1, 3, 1), oma = c(0, 0, 2, 0))

  for (palette_name in palette_names) {
    palette_colors <- unname(pick_palette(palette_name))
    displayed_colors <- palette_colors[seq_len(min(12, length(palette_colors)))]

    graphics::plot.new()
    graphics::plot.window(xlim = c(0, length(displayed_colors)), ylim = c(0, 1))

    for (color_index in seq_along(displayed_colors)) {
      graphics::rect(color_index - 1, 0, color_index, 1, col = displayed_colors[color_index], border = NA)
    }

    graphics::box(col = "grey80")
    graphics::title(main = make_palette_caption(palette_name), line = 0.6, cex.main = 1)
  }

  graphics::mtext(group_titles[[group_name]], outer = TRUE, line = 0.5, cex = 1.2, font = 2)
  grDevices::dev.off()
}