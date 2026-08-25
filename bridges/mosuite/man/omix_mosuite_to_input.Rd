\name{omix_mosuite_to_input}
\alias{omix_mosuite_to_input}
\title{Convert a MOSuite MOO to the OMIX standard input}
\usage{
omix_mosuite_to_input(
  moo,
  count_type = "raw",
  sub_count_type = NULL,
  annotation_columns = NULL,
  annotation_feature_id_column = NULL
)
}
\arguments{
\item{moo}{A MOSuite \code{multiOmicDataSet} object.}
\item{count_type}{MOSuite count layer to extract.}
\item{sub_count_type}{Optional subtype of a list-valued count layer.}
\item{annotation_columns}{Optional feature annotations to add to the count table.}
\item{annotation_feature_id_column}{Feature ID column in MOSuite annotation.}
}
\value{An \code{omix_standard_input} object created by the Omix Core package.}
\description{Uses the supported MOSuite count extractor, collects documented sample metadata and feature annotations, and returns the portable counts-plus-metadata contract used by OMIX modules.}
\examples{
\dontrun{
input <- omix_mosuite_to_input(moo, "raw", annotation_columns = "GeneName")
}
}
