\name{omix_read_mosuite_rds}
\alias{omix_read_mosuite_rds}
\title{Read a serialized MOSuite MOO as an OMIX standard input}
\usage{
omix_read_mosuite_rds(path, ...)
}
\arguments{
\item{path}{Path to an RDS file containing a MOSuite MOO.}
\item{...}{Arguments passed to \code{omix_mosuite_to_input}.}
}
\value{An \code{omix_standard_input} object.}
\description{Reads a serialized MOSuite MOO and converts it with \code{omix_mosuite_to_input}.}
