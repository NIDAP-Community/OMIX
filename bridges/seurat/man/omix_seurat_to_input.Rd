\name{omix_seurat_to_input}
\alias{omix_seurat_to_input}
\alias{omix_read_seurat_rds}
\title{Create an OMIX pseudobulk input from a Seurat object}
\usage{
omix_seurat_to_input(
  seurat_object,
  donor_column,
  group_column,
  cell_type_column,
  cell_type,
  cell_filter_column = NULL,
  cell_filter_values = NULL,
  assay = "RNA",
  layer = "counts",
  feature_id_column = "Gene",
  min_cells = 20L,
  on_insufficient_cells = c("error", "drop")
)

omix_read_seurat_rds(path, ...)
}
\arguments{
\item{seurat_object}{A Seurat object supported by SeuratObject.}
\item{donor_column}{Cell-metadata column identifying biological donors.}
\item{group_column}{Cell-metadata column identifying experimental groups.}
\item{cell_type_column}{Cell-metadata column identifying cell types.}
\item{cell_type}{One exact cell-type value to aggregate.}
\item{cell_filter_column}{Optional cell-metadata column used for an explicit pre-aggregation filter.}
\item{cell_filter_values}{Values retained from \code{cell_filter_column}.}
\item{assay}{Assay containing raw counts.}
\item{layer}{Assay layer containing raw counts.}
\item{feature_id_column}{Output feature-ID column name.}
\item{min_cells}{Minimum selected cells per donor-by-group profile.}
\item{on_insufficient_cells}{Whether under-populated profiles cause an error or are dropped.}
\item{path}{Path to an \code{.rds} file containing a Seurat object.}
\item{...}{Arguments passed to \code{omix_seurat_to_input}.}
}
\value{An \code{omix_standard_input} object with one raw-count pseudobulk profile per donor-by-group pair.}
\description{Selects one cell type and sums raw counts per donor and condition. Individual cells are never represented as independent DEG replicates.}
\examples{
\dontrun{
input <- omix_seurat_to_input(
  object,
  donor_column = "donor",
  group_column = "condition",
  cell_type_column = "cell_type",
  cell_type = "CD14+ Monocytes"
)
}
}
