make_gsea_fixture <- function() {
  data.frame(
    contrast = rep(c("B-A", "C-A"), each = 2L),
    collection = rep("H: Hallmark", 4L),
    pathway = rep(c("IFN_ALPHA_RESPONSE", "TNFA_SIGNALING"), 2L),
    pval = c(0.001, 0.20, 0.01, 0.04),
    padj = c(0.01, 0.30, 0.02, 0.05),
    NES = c(2.1, -1.2, 1.7, -2.2),
    size_leadingEdge = c(10, 5, 8, 4),
    fraction_leadingEdge = c(0.20, 0.10, 0.16, 0.08),
    check.names = FALSE
  )
}

test_that("GSEA tables standardize to the pathway bubble contract", {
  standardized <- standardize_pathway_results(make_gsea_fixture())
  expect_s3_class(standardized, "omix_pathway_results")
  expect_named(standardized, c("contrast", "collection", "pathway", "pval", "padj", "score", "size", "fraction"))
  expect_equal(standardized$score, c(2.1, -1.2, 1.7, -2.2))
  expect_equal(attr(standardized, "omix_pathway_input")$input_format, "gsea")
})

test_that("L2P percentage fractions retain magnitude and become fractions", {
  l2p <- data.frame(
    group = c("B-A", "B-A"), categ = c("H: Hallmark", "H: Hallmark"), pathway_name = c("A", "B"),
    pval = c(0.01, 0.02), fdr = c(0.02, 0.04), enrichment_score = c(2, -1.5),
    number_hits = c(5, 4), percent_gene_hits_per_pathway = c(25, -10), check.names = FALSE
  )
  standardized <- standardize_pathway_results(l2p)
  expect_equal(standardized$fraction, c(0.25, 0.10))
  expect_match(paste(attr(standardized, "omix_pathway_input")$transformations, collapse = " "), "signed L2P")
})

test_that("L2P-Single exports map direction and category to the shared contract", {
  l2p_single <- data.frame(
    pathway_name = c("A", "B"),
    category = c("H", "H"),
    direction = c("upregulated", "downregulated"),
    number_hits = c(5, 4),
    percent_gene_hits_per_pathway = c(25, 10),
    enrichment_score = c(2, -1.5),
    pval = c("1.00e-02", "2.00e-02"),
    fdr = c("2.00e-02", "4.00e-02"),
    check.names = FALSE
  )

  standardized <- standardize_pathway_results(l2p_single)

  expect_equal(attr(standardized, "omix_pathway_input")$input_format, "l2p_single")
  expect_equal(standardized$contrast, c("upregulated", "downregulated"))
  expect_equal(standardized$collection, c("H", "H"))
  expect_equal(standardized$fraction, c(0.25, 0.10))
})

test_that("the shared renderer preserves the established defaults", {
  plot <- plot_pathway_bubble(make_gsea_fixture())
  settings <- attr(plot, "omix_pathway_plot_settings")
  dimensions <- attr(plot, "omix_pathway_plot_dimensions")
  expect_s3_class(plot, "ggplot")
  expect_equal(settings$p_value_column, "pval")
  expect_equal(settings$p_value_cutoff, 0.05)
  expect_true(settings$show_non_significant)
  expect_equal(settings$layout_style, "facet")
  expect_equal(settings$facet_title_mode, "full collection name")
  expect_equal(settings$palette, "blue_vermilion")
  expect_equal(settings$color_scale$method, "symmetric_percentile")
  expect_equal(settings$color_scale$percentile, 99)
  expect_equal(settings$size_by, "size")
  expect_equal(settings$pathway_wrap_width, 28L)
  expect_equal(settings$vertical_lines, numeric())
  expect_equal(settings$figure_aspect, 2.5)
  expect_equal(dimensions$height, 7)
  expect_equal(dimensions$n_pathways, 2L)
  expect_equal(dimensions$n_collections, 1L)
})

test_that("adjusted p-values can drive bubble selection and the shape legend", {
  plot <- plot_pathway_bubble(make_gsea_fixture(), p_value_column = "padj")
  settings <- attr(plot, "omix_pathway_plot_settings")
  shape_scale <- plot$scales$get_scales("shape")

  expect_equal(settings$p_value_column, "padj")
  expect_equal(
    as.character(shape_scale$get_breaks()),
    c("padj<0.05", "padj>0.05")
  )
  expect_false(shape_scale$drop)
})

test_that("shared pathway selection defaults to 20 distinct pathways", {
  input <- data.frame(
    contrast = rep("B-A", 25L),
    collection = rep("H: Hallmark", 25L),
    pathway = paste("Pathway", seq_len(25L)),
    pval = seq_len(25L) / 1000,
    padj = seq_len(25L) / 1000,
    score = seq_len(25L),
    size = seq_len(25L),
    stringsAsFactors = FALSE
  )

  selected <- select_pathway_bubble_data(
    input,
    input_format = "canonical",
    selection_scopes = "combined_single_panel"
  )

  expect_equal(nrow(selected[["Combined Pathways"]]), 20L)
  expect_equal(attr(selected, "omix_pathway_bubble_selection")$top_n_pathways, 20L)
})

test_that("automatic pathway-label text remains readable at 30 rows", {
  expect_equal(pathway_bubble_dynamic_font_size(10L), 16L)
  expect_equal(pathway_bubble_dynamic_font_size(20L), 14L)
  expect_equal(pathway_bubble_dynamic_font_size(30L), 12L)
  expect_equal(pathway_bubble_dynamic_font_size(55L), 10L)
})

test_that("pathway labels are black and panel plots have no grid lines", {
  plot <- plot_pathway_bubble(make_gsea_fixture(), layout_style = "panel")

  expect_equal(plot$theme$axis.text.y$colour, "#000000")
  expect_true(inherits(plot$theme$panel.grid.major, "element_blank"))
  expect_true(inherits(plot$theme$panel.grid.minor, "element_blank"))
  expect_null(plot$theme$panel.grid.major.y)
})

test_that("pathway-axis labels use consistent display casing", {
  expect_equal(
    pathway_bubble_format_labels(c(
      "HALLMARK_HYPOXIA",
      "REACTOME_GPCR_LIGAND_BINDING",
      "HALLMARK_IL6_JAK_STAT3_SIGNALING",
      "HALLMARK_G2M_CHECKPOINT",
      "HALLMARK_E2F_TARGETS",
      "HALLMARK_FOXP3_RESPONSE",
      "hexose biosynthetic process",
      "Response of EIF2AK1 (HRI) to heme deficiency"
    )),
    c(
      "Hallmark: HYPOXIA",
      "Reactome: GPCR LIGAND BINDING",
      "Hallmark: IL6 JAK STAT3 SIGNALING",
      "Hallmark: G2M CHECKPOINT",
      "Hallmark: E2F TARGETS",
      "Hallmark: FOXP3 RESPONSE",
      "Hexose biosynthetic process",
      "Response of EIF2AK1 (HRI) to heme deficiency"
    )
  )
  expect_equal(
    pathway_bubble_format_labels(
      c("HALLMARK_HYPOXIA", "REACTOME_GPCR_LIGAND_BINDING"),
      include_source_prefix = FALSE
    ),
    c("HYPOXIA", "GPCR LIGAND BINDING")
  )
  expect_equal(
    pathway_bubble_format_labels(
      c("HALLMARK_HYPOXIA", "Eukaryotic_Translation_Elongation"),
      collections = c("H", "REACTOME")
    ),
    c("Hallmark: HYPOXIA", "Reactome: Eukaryotic Translation Elongation")
  )
  expect_equal(
    pathway_bubble_format_labels(
      "Eukaryotic_Translation_Elongation",
      include_source_prefix = FALSE,
      collections = "REACTOME"
    ),
    "Eukaryotic Translation Elongation"
  )
})

test_that("only combined plot sets retain source prefixes", {
  plots <- plot_pathway_bubble_set(
    make_gsea_fixture(),
    top_n_pathways = 1L,
    selection_scopes = c("combined_single_panel", "across_all_collections", "within_each_collection")
  )
  collection_plot_name <- names(plots)[grepl("^H:", names(plots))][[1L]]

  expect_true(attr(plots[["Combined Pathways"]], "omix_pathway_plot_settings")$include_source_prefix)
  expect_false(attr(plots[["Across Collections"]], "omix_pathway_plot_settings")$include_source_prefix)
  expect_false(attr(plots[[collection_plot_name]], "omix_pathway_plot_settings")$include_source_prefix)
})

test_that("selected plot sets retain requested contrasts with no selected rows", {
  sparse <- data.frame(
    contrast = c("B-A", "C-A"),
    collection = c("H: Hallmark", "H: Hallmark"),
    pathway = c("B_ONLY", "C_ONLY"),
    pval = c(0.01, 0.001),
    NES = c(1.5, 2.0),
    size_leadingEdge = c(5, 6),
    fraction_leadingEdge = c(0.10, 0.12)
  )

  plots <- plot_pathway_bubble_set(
    sparse,
    top_n_pathways = 1L,
    selection_scopes = "within_each_collection"
  )
  plot <- plots[["H: Hallmark"]]

  expect_true(attr(plot, "omix_pathway_plot_settings")$retain_empty_contrasts)
  expect_equal(levels(plot$data$contrast_name), c("B-A", "C-A"))
  expect_false(plot$scales$get_scales("x")$drop)
})

test_that("automatic dimensions make room for the plotted pathways", {
  dimensions <- pathway_bubble_dimensions(28L, 2L)

  expect_equal(dimensions$width, 16.36)
  expect_equal(dimensions$height, 20.7)
  expect_equal(dimensions$units, "in")

  long_label_dimensions <- pathway_bubble_dimensions(
    28L,
    1L,
    longest_pathway_label = 100L
  )
  expect_gt(long_label_dimensions$width, pathway_bubble_dimensions(28L, 1L)$width)
})

test_that("selection returns no more than the requested number of pathway rows", {
  pathways <- paste0("PATHWAY_", seq_len(25L))
  selection_fixture <- data.frame(
    contrast = rep(c("B-A", "C-A"), each = 25L),
    collection = "H: Hallmark",
    pathway = rep(pathways, 2L),
    pval = c(seq_len(25L) / 1000, seq_len(25L) / 100),
    padj = c(seq_len(25L) / 100, seq_len(25L) / 100),
    NES = rep(c(2, -2), each = 25L),
    size_leadingEdge = 10L,
    fraction_leadingEdge = 0.2,
    check.names = FALSE
  )

  selected <- select_pathway_bubble_data(
    selection_fixture,
    selection_scopes = "within_each_collection"
  )
  details <- attr(selected, "omix_pathway_bubble_selection")$details[["H: Hallmark"]]

  expect_length(details$selected_pathways, 20L)
  expect_length(unique(selected[["H: Hallmark"]]$pathway), 20L)
  expect_equal(nrow(selected[["H: Hallmark"]]), 40L)
})

test_that("legacy-style selection defaults to top 20 in both scopes", {
  selected <- select_pathway_bubble_data(make_gsea_fixture())
  selection <- attr(selected, "omix_pathway_bubble_selection")

  expect_s3_class(selected, "omix_pathway_bubble_selection")
  expect_equal(selection$top_n_pathways, 20L)
  expect_equal(
    selection$selection_scopes,
    c("combined_single_panel", "across_all_collections", "within_each_collection")
  )
  expect_named(selected, c("Combined Pathways", "Across Collections", "H: Hallmark"))
})

test_that("combined single-panel selection keeps the strongest source per pathway", {
  multi_source <- data.frame(
    contrast = c("B-A", "C-A", "B-A", "C-A"),
    collection = c("GO", "GO", "H", "H"),
    pathway = "SHARED_PATHWAY",
    pval = c(0.020, 0.400, 0.001, 0.200),
    padj = c(0.030, 0.500, 0.002, 0.300),
    NES = c(1.0, 0.8, 2.0, 1.5),
    size_leadingEdge = c(4, 4, 8, 8),
    fraction_leadingEdge = c(0.10, 0.10, 0.20, 0.20),
    check.names = FALSE
  )

  selected <- select_pathway_bubble_data(
    multi_source,
    top_n_pathways = 1L,
    selection_scopes = "combined_single_panel"
  )
  details <- attr(selected, "omix_pathway_bubble_selection")$details[["Combined Pathways"]]
  plot <- plot_pathway_bubble_set(
    multi_source,
    top_n_pathways = 1L,
    selection_scopes = "combined_single_panel"
  )[["Combined Pathways"]]

  expect_equal(details$selected_pathways, "SHARED_PATHWAY")
  expect_equal(details$selected_pathway_sources$collection, "H")
  expect_true(all(selected[["Combined Pathways"]]$collection == "H"))
  expect_false(".facet_group" %in% names(plot$data))
  expect_equal(attr(plot, "omix_pathway_plot_settings")$layout_style, "panel")
})

test_that("selected plots tolerate filtered tables with incomplete contrast coverage", {
  incomplete <- data.frame(
    contrast = c("B-A", "C-A", "B-A"),
    collection = "H: Hallmark",
    pathway = c("PATHWAY_ONE", "PATHWAY_ONE", "PATHWAY_TWO"),
    pval = c(0.001, 0.02, 0.003),
    padj = c(0.01, 0.03, 0.02),
    NES = c(2, 1.5, -1.8),
    size_leadingEdge = c(10, 9, 8),
    fraction_leadingEdge = c(0.2, 0.18, 0.16),
    check.names = FALSE
  )

  plots <- plot_pathway_bubble_set(
    incomplete,
    top_n_pathways = 1L,
    selection_scopes = "within_each_collection",
    selection_contrasts = c("B-A", "C-A"),
    plot_contrasts = c("B-A", "C-A")
  )

  expect_s3_class(plots[["H: Hallmark"]], "ggplot")
  expect_equal(levels(plots[["H: Hallmark"]]$data$contrast_name), c("B-A", "C-A"))
})

test_that("collection plots have independent color scales unless sharing is requested", {
  multi_scale_l2p <- data.frame(
    group = c("B-A", "C-A", "B-A", "C-A"),
    categ = c("GO", "GO", "H", "H"),
    pathway_name = c("GO_PATH", "GO_PATH", "H_PATH", "H_PATH"),
    pval = c(0.001, 0.020, 0.002, 0.040),
    fdr = c(0.002, 0.030, 0.004, 0.050),
    enrichment_score = c(100, -80, 2, -1),
    number_hits = c(10, 10, 10, 10),
    percent_gene_hits_per_pathway = c(20, -20, 20, -20),
    check.names = FALSE
  )

  plots <- plot_pathway_bubble_set(multi_scale_l2p, top_n_pathways = 1L)
  color_scales <- attr(plots, "omix_pathway_bubble_color_scales")

  expect_s3_class(plots, "omix_pathway_bubble_set")
  expect_true(all(vapply(plots, inherits, logical(1), what = "ggplot")))
  expect_equal(length(attr(plots, "omix_pathway_bubble_color_limits")), 2L)
  expect_equal(length(attr(plots, "omix_pathway_bubble_dimensions")), 4L)
  expect_equal(attr(plots, "omix_pathway_bubble_collection_color_scale"), "independent")
  expect_lt(max(abs(color_scales[["H"]])), max(abs(color_scales[["Combined Pathways"]])))
  expect_gt(max(abs(color_scales[["GO"]])), max(abs(color_scales[["H"]])))

  shared_plots <- plot_pathway_bubble_set(
    multi_scale_l2p,
    top_n_pathways = 1L,
    collection_color_scale = "shared"
  )
  shared_scales <- attr(shared_plots, "omix_pathway_bubble_color_scales")
  expect_equal(shared_scales[["H"]], shared_scales[["Combined Pathways"]])

  fixed_plots <- plot_pathway_bubble_set(
    multi_scale_l2p,
    top_n_pathways = 1L,
    color_limits = c(-10, 10)
  )
  fixed_scales <- attr(fixed_plots, "omix_pathway_bubble_color_scales")
  expect_true(all(vapply(fixed_scales, identical, logical(1), c(-10, 10))))
})

test_that("a pathway bubble plot set saves plots with a color-scale manifest", {
  plots <- plot_pathway_bubble_set(
    make_gsea_fixture(),
    top_n_pathways = 1L,
    selection_scopes = c("combined_single_panel", "within_each_collection")
  )
  output_dir <- tempfile("omix-pathway-bubbles-")
  on.exit(unlink(output_dir, recursive = TRUE), add = TRUE)

  written <- save_pathway_bubble_set(
    plots,
    output_dir = output_dir,
    file_prefix = "example"
  )
  manifest <- utils::read.csv(written$manifest, stringsAsFactors = FALSE)

  expect_length(written$files, 2L)
  expect_true(all(file.exists(written$files)))
  expect_true(file.exists(written$manifest))
  expect_named(
    manifest,
    c(
      "plot_name", "selection_scope", "significance_statistic",
      "significance_threshold", "selected_pathway_count", "selected_row_count",
      "color_min", "color_max", "width_inches", "height_inches", "file"
    )
  )
  expect_equal(manifest$plot_name, c("Combined Pathways", "H: Hallmark"))
  expect_true(all(manifest$significance_statistic == "pval"))
  expect_true(all(manifest$significance_threshold == 0.05))
})
