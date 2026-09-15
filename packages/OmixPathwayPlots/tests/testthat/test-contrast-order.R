test_that("plot contrast order retains intentionally empty comparison columns", {
  results <- data.frame(
    contrast = c("B-A", "C-A"),
    collection = c("H", "H"),
    pathway = c("PATHWAY_1", "PATHWAY_1"),
    score = c(2, -2),
    pval = c(0.01, 0.02),
    size = c(10, 10),
    stringsAsFactors = FALSE
  )

  selected <- select_pathway_bubble_data(
    results,
    input_format = "canonical",
    selection_scopes = "combined_single_panel",
    selection_contrasts = c("B-A", "C-A"),
    plot_contrasts = c("B-A", "C-A", "C-B")
  )
  selection <- attr(selected, "omix_pathway_bubble_selection")

  expect_identical(selection$plot_contrasts, c("B-A", "C-A", "C-B"))
  expect_false(any(as.character(selected[["Combined Pathways"]]$contrast) == "C-B"))

  plots <- plot_pathway_bubble_set(
    results,
    input_format = "canonical",
    selection_scopes = "combined_single_panel",
    selection_contrasts = c("B-A", "C-A"),
    plot_contrasts = c("B-A", "C-A", "C-B")
  )
  expect_s3_class(plots[["Combined Pathways"]], "ggplot")
  expect_identical(
    attr(plots, "omix_pathway_bubble_selection")$plot_contrasts,
    c("B-A", "C-A", "C-B")
  )
})
