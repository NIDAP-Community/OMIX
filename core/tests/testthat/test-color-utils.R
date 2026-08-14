library(testthat)

### TESTING get_random_colors() ###
test_that("get_random_colors generates the correct number of colors", {
  set.seed(10)
  colors <- get_random_colors(k = 5)
  
  # Ensure we get exactly 5 colors
  expect_equal(length(colors), 5)
  
  # Ensure colors are valid hex codes
  expect_true(all(grepl("^#[A-Fa-f0-9]{6}$", colors)))
})

test_that("get_random_colors generates reproducible colors with the same seed", {
  set.seed(10)
  colors1 <- get_random_colors(k = 5)
  
  set.seed(10)
  colors2 <- get_random_colors(k = 5)
  
  expect_equal(colors1, colors2)  # Ensures the function is deterministic
})

### TESTING get_hex_color() ###
test_that("get_hex_color correctly converts color names to hex", {
  input_colors <- c("red", "blue", "green")
  expected_hex <- c("#FF0000", "#0000FF", "#00FF00")  # Adjusted "green"
  
  result <- get_hex_color(input_colors)
  
  expect_equal(result, expected_hex)
})


test_that("get_hex_color throws an error for invalid colors", {
  invalid_colors <- c("not_a_color", "another_fake_color")
  
  expect_error(get_hex_color(invalid_colors), "invalid color name")
})

### TESTING get_closest_color() ###
test_that("get_closest_color returns a valid R color name", {
  hex_value <- "#FF4500"  # Should return something like "orangered"
  closest_color <- get_closest_color(hex_value)
  
  expect_true(closest_color %in% colors())  # Check if it's a valid R color
})

test_that("get_closest_color is deterministic", {
  hex_value <- "#FF4500"
  
  result1 <- get_closest_color(hex_value)
  result2 <- get_closest_color(hex_value)
  
  expect_equal(result1, result2)  # Should return the same result every time
})

### TESTING colorvect() ###
test_that("colorvect returns a named vector", {
  hex_codes <- c("#FF0000", "#0000FF", "#008000")
  result <- colorvect(hex_codes)
  
  expect_type(result, "character")  # Should return a named character vector
  expect_equal(length(result), 3)   # Should have the same length as input
  expect_true(all(names(result) %in% colors()))  # Names should be valid R colors
})

### TESTING get_colors() ###
test_that("get_colors retrieves exactly the requested number of colors", {
  palette_result <- get_colors(num_col = 5, sel_pal = "Dark2")
  
  expect_equal(length(palette_result$colors), 5)  # Ensures exactly 5 colors are returned
})

test_that("get_colors correctly retrieves the Default palette", {
  num_colors <- 5  # Request 5 colors from Default
  palette_result <- get_colors(num_col = num_colors, sel_pal = "Default")
  
  # Ensure exactly `num_colors` are returned
  expect_equal(length(palette_result$colors), num_colors)
  
  # Ensure all returned colors are valid hex codes
  expect_true(all(grepl("^#[A-Fa-f0-9]{6}$", palette_result$colors)))
})

test_that("get_colors correctly retrieves the NPG_1 palette", {
  num_colors <- 5  # Request 5 colors from NPG_1
  palette_result <- get_colors(num_col = num_colors, sel_pal = "NPG_1")
  
  # Ensure exactly `num_colors` are returned
  expect_equal(length(palette_result$colors), num_colors)
  
  # Ensure all returned colors are valid hex codes
  expect_true(all(grepl("^#[A-Fa-f0-9]{8}$", palette_result$colors)))
  
  # Check that the function does not return an empty list
  expect_true(length(palette_result$colors) > 0)
})


test_that("get_colors generates additional colors if needed", {
  palette_result <- get_colors(num_col = 20, sel_pal = "Set3")  # Set3 has < 20 colors
  
  expect_equal(length(palette_result$colors), 20)  # Should fill in missing colors
  expect_type(palette_result$colors, "character")
})
