library(testthat)

write_color_wheel <- function(colors, file) {
  grDevices::png(filename = file, width = 1200, height = 1200)
  on.exit(grDevices::dev.off(), add = TRUE)

  graphics::par(mar = c(0, 0, 2, 0))
  graphics::plot.new()
  graphics::plot.window(xlim = c(-1.1, 1.1), ylim = c(-1.1, 1.1), asp = 1)

  angles <- seq(0, 2 * pi, length.out = length(colors) + 1)
  for (i in seq_along(colors)) {
    graphics::polygon(
      x = c(0, cos(angles[i]), cos(angles[i + 1])),
      y = c(0, sin(angles[i]), sin(angles[i + 1])),
      col = colors[i],
      border = NA
    )
  }

  graphics::symbols(0, 0, circles = 0.25, inches = FALSE, add = TRUE, bg = "white", fg = "white")
  graphics::title(main = sprintf("%d-color wheel", length(colors)))
}

write_color_artifacts <- function(colors, colors_file, wheel_file) {
  writeLines(unname(colors), colors_file)
  write_color_wheel(colors, wheel_file)
}

test_that("get_color_palette generates correct number of colors", {
  num_colors <- 10
  result <- get_color_palette(num_col = num_colors, sel_pal = "Dark2", use_custom_pal = FALSE)
  
  # Check if result is a named vector
  expect_type(result, "character")
  
  # Ensure the correct number of colors are generated
  expect_equal(length(result), num_colors)
})

test_that("get_color_palette handles custom palette correctly", {
  custom_colors <- c("red", "blue", "green", "yellow")
  result <- get_color_palette(num_col = 4, use_custom_pal = TRUE, custom_pal = custom_colors)
  
  # Ensure it returns the expected number of colors
  expect_equal(length(result), 4)
  
  # Check if all returned colors are in the custom palette
  expect_true(all(names(result) %in% colors()))
})

test_that("get_color_palette supplements missing custom colors", {
  custom_colors <- c("red", "blue") # Only 2 colors provided, but 5 requested
  expected_hex <- get_hex_color(custom_colors) # Convert to hex for comparison
  
  result <- get_color_palette(num_col = 5, use_custom_pal = TRUE, custom_pal = custom_colors)
  
  # Ensure the correct number of colors are generated
  expect_equal(length(result), 5)
  
  # Check that the original custom colors (in hex format) are present in the result
  expect_true(all(expected_hex %in% result))
})



test_that("get_color_palette handles large requests gracefully", {
  num_colors <- 50
  result <- get_color_palette(num_col = num_colors, sel_pal = "Set3", use_custom_pal = FALSE)
  
  # Check if we get the requested number of colors
  expect_equal(length(result), num_colors)
})

test_that("get_color_palette extends a built-in palette to 40 colors", {
  base_result <- get_color_palette(num_col = 8, sel_pal = "Dark2", use_custom_pal = FALSE, seed = 10)
  extended_result <- get_color_palette(num_col = 40, sel_pal = "Dark2", use_custom_pal = FALSE, seed = 10)

  expect_equal(length(extended_result), 40)
  expect_equal(extended_result[seq_along(base_result)], base_result)
})

test_that("get_color_palette matches the 40-color artifact standard", {
  artifact_dir <- testthat::test_path("artifacts", "color-palettes")
  reference_colors_file <- file.path(artifact_dir, "dark2-40-seed10-colors.txt")
  reference_wheel_file <- file.path(artifact_dir, "dark2-40-seed10-wheel.png")
  rendered_wheel_file <- tempfile(pattern = "omix-color-wheel-", fileext = ".png")
  update_artifacts <- identical(Sys.getenv("OMIX_UPDATE_COLOR_ARTIFACTS"), "true")
  colors_40 <- get_color_palette(num_col = 40, sel_pal = "Dark2", use_custom_pal = FALSE, seed = 10)

  dir.create(artifact_dir, recursive = TRUE, showWarnings = FALSE)

  if (update_artifacts) {
    write_color_artifacts(colors_40, reference_colors_file, reference_wheel_file)
  }

  if (!file.exists(reference_colors_file)) {
    skip(paste(
      "Reference color artifact missing:",
      reference_colors_file,
      "Set OMIX_UPDATE_COLOR_ARTIFACTS=true to create the baseline."
    ))
  }

  expected_colors <- readLines(reference_colors_file, warn = FALSE)
  expect_equal(unname(colors_40), expected_colors)

  write_color_wheel(colors_40, rendered_wheel_file)

  expect_true(file.exists(rendered_wheel_file))
  expect_gt(file.info(rendered_wheel_file)$size, 0)

  if (file.exists(reference_wheel_file)) {
    expect_equal(
      unname(tools::md5sum(rendered_wheel_file)),
      unname(tools::md5sum(reference_wheel_file))
    )
  }
})

test_that("get_color_palette handles invalid color names gracefully", {
  invalid_colors <- c("not_a_color", "another_fake_color")
  
  # Ensure an error is thrown when invalid colors are provided
  expect_error(get_color_palette(num_col = 2, use_custom_pal = TRUE, custom_pal = invalid_colors),
               "invalid color name")
})

test_that("get_color_palette correctly applies splitpalplot", {
  num_colors <- 8
  result <- get_color_palette(num_col = num_colors, sel_pal = "Dark2", use_custom_pal = FALSE, split_pal_plot = TRUE)
  
  # Ensure the correct number of colors are returned
  expect_equal(length(result), num_colors)
})
