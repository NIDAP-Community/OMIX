wide_findmarkers_example <- function() {
  data.frame(
    Gene = c("GeneA", "GeneB"),
    C_1_vs_2_pval = c(0.01, 0.20),
    C_1_vs_2_logFC = c(0.8, -0.4),
    C_1_vs_2_pct1 = c(0.7, 0.2),
    C_1_vs_2_pct2 = c(0.3, 0.5),
    C_1_vs_2_adjpval = c(0.03, 0.40),
    C_3_vs_all_pval = c(0.02, 0.30),
    C_3_vs_all_logFC = c(-0.6, 0.5),
    C_3_vs_all_pct1 = c(0.2, 0.6),
    C_3_vs_all_pct2 = c(0.5, 0.2),
    C_3_vs_all_adjpval = c(0.05, 0.50),
    check.names = FALSE
  )
}

test_that("wide FindMarkers tables preserve source contrast order", {
  data <- wide_findmarkers_example()
  profile <- normalize_findmarkers_deg_input(data)

  expect_identical(profile$format, "seurat_findmarkers_wide")
  expect_identical(profile$gene_column, "Gene")
  expect_identical(profile$comparisons, c("C_1_vs_2", "C_3_vs_all"))
  expect_identical(
    unname(profile$source_columns$fold_change),
    c("C_1_vs_2_logFC", "C_3_vs_all_logFC")
  )
  expect_identical(
    profile$ignored_percentage_columns,
    c("C_1_vs_2_pct1", "C_1_vs_2_pct2", "C_3_vs_all_pct1", "C_3_vs_all_pct2")
  )
})

test_that("explicit wide comparison order is preserved", {
  data <- wide_findmarkers_example()
  profile <- normalize_findmarkers_deg_input(
    data,
    comparison_labels = c("C_3_vs_all", "C_1_vs_2")
  )

  expect_identical(profile$comparisons, c("C_3_vs_all", "C_1_vs_2"))
  expect_identical(
    unname(profile$analysis_columns$fold_change),
    c("C_3_vs_all_logFC", "C_1_vs_2_logFC")
  )
})

test_that("native current and legacy Seurat profiles receive explicit labels", {
  current <- data.frame(
    p_val = c(0.01, 0.20),
    avg_log2FC = c(0.8, -0.4),
    pct.1 = c(0.7, 0.2),
    pct.2 = c(0.3, 0.5),
    p_val_adj = c(0.03, 0.40),
    row.names = c("GeneA", "GeneB"),
    check.names = FALSE
  )
  current_profile <- normalize_findmarkers_deg_input(
    current,
    comparison_labels = "cluster_1_vs_2"
  )
  expect_identical(current_profile$format, "seurat_findmarkers_native")
  expect_identical(current_profile$gene_column, ".omix_gene")
  expect_identical(current_profile$data$.omix_gene, c("GeneA", "GeneB"))
  expect_identical(
    current_profile$data$cluster_1_vs_2_logFC,
    current$avg_log2FC
  )

  legacy <- current
  legacy$avg_logFC <- legacy$avg_log2FC
  legacy$avg_log2FC <- NULL
  legacy$Gene <- rownames(legacy)
  rownames(legacy) <- NULL
  legacy_profile <- normalize_findmarkers_deg_input(
    legacy,
    gene_column = "Gene",
    comparison_labels = "legacy"
  )
  expect_identical(legacy_profile$gene_column, "Gene")
  expect_identical(legacy_profile$data$legacy_logFC, legacy$avg_logFC)

  repaired <- cbind(X = legacy$Gene, legacy[setdiff(names(legacy), "Gene")])
  repaired_profile <- normalize_findmarkers_deg_input(
    repaired,
    comparison_labels = "repaired"
  )
  expect_identical(repaired_profile$gene_column, "X")
})

test_that("native profiles never invent a biological comparison label", {
  native <- data.frame(
    p_val = 0.01,
    avg_log2FC = 0.8,
    pct.1 = 0.7,
    pct.2 = 0.3,
    p_val_adj = 0.03,
    row.names = "GeneA",
    check.names = FALSE
  )
  expect_error(
    normalize_findmarkers_deg_input(native),
    "requires exactly one user-supplied comparison label",
    fixed = TRUE
  )
  native$avg_logFC <- native$avg_log2FC
  expect_error(
    normalize_findmarkers_deg_input(native, comparison_labels = "A-B"),
    "both `avg_log2FC` and `avg_logFC`",
    fixed = TRUE
  )
})

test_that("non-FindMarkers tables are left to existing module resolvers", {
  ordinary <- data.frame(
    GeneName = c("GeneA", "GeneB"),
    `A-B_tstat` = c(2, -2),
    check.names = FALSE
  )
  expect_null(normalize_findmarkers_deg_input(ordinary))
})
