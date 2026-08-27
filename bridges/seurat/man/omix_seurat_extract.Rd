\name{omix_seurat_extract}
\alias{omix_seurat_extract}
\title{Extract raw counts and cell metadata from a Seurat object}
\usage{
omix_seurat_extract(seurat_object, assay = "RNA", layer = "counts")
}
\arguments{
\item{seurat_object}{A Seurat object supported by SeuratObject.}
\item{assay}{Assay containing raw counts.}
\item{layer}{Assay layer containing raw counts.}
}
\value{A list containing feature-by-cell raw counts, aligned cell metadata, and provenance.}
\description{Extracts one explicit raw-count layer from a Seurat object using SeuratObject, without importing the full Seurat package.}
\examples{
\dontrun{
cells <- omix_seurat_extract(object, assay = "RNA", layer = "counts")
}
}
