\name{new_omix_standard_input}
\alias{new_omix_standard_input}
\title{Construct a portable OMIX standard input}
\usage{
new_omix_standard_input(
  counts,
  metadata,
  feature_id_column = NULL,
  sample_id_column = NULL,
  sample_columns = NULL,
  provenance = list()
)
}
\arguments{
\item{counts}{A feature-by-sample data frame, optionally with annotation columns.}
\item{metadata}{A data frame containing unique sample identifiers.}
\item{feature_id_column}{Feature identifier column in \code{counts}.}
\item{sample_id_column}{Sample identifier column in \code{metadata}.}
\item{sample_columns}{Explicit numeric sample columns in \code{counts}.}
\item{provenance}{Optional named list describing the input source.}
}
\value{An object of class \code{omix_standard_input}.}
\description{Validates the portable counts-plus-metadata contract used by OMIX modules and aligns metadata to the selected count-table sample columns.}
\examples{
counts <- data.frame(feature_id = "gene_1", A1 = 10L, B1 = 12L)
metadata <- data.frame(Sample = c("A1", "B1"), Group = c("A", "B"))
new_omix_standard_input(counts, metadata)
}
