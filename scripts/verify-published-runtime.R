#!/usr/bin/env Rscript

# Verify the package set in a published OMIX runtime against the checked-in
# release manifest. This script deliberately uses only jsonlite, which is part
# of every published OMIX runtime, so it can run inside the image being tested.

usage <- function() {
  paste(
    "Usage:",
    "  Rscript verify-published-runtime.R --manifest <release-manifest.json> --profile <r-base|r-statistics|r-visualization|r-pathway>",
    sep = "\n"
  )
}

parse_args <- function(args) {
  out <- list()
  i <- 1L
  while (i <= length(args)) {
    key <- args[[i]]
    if (!startsWith(key, "--") || i == length(args)) {
      stop(usage(), call. = FALSE)
    }
    out[[sub("^--", "", key)]] <- args[[i + 1L]]
    i <- i + 2L
  }
  out
}

args <- parse_args(commandArgs(trailingOnly = TRUE))
if (is.null(args$manifest) || is.null(args$profile)) {
  stop(usage(), call. = FALSE)
}
if (!file.exists(args$manifest)) {
  stop("Manifest does not exist: ", args$manifest, call. = FALSE)
}

manifest <- jsonlite::fromJSON(args$manifest, simplifyVector = FALSE)
entry <- manifest$images[[args$profile]]
if (is.null(entry)) {
  stop("Unknown runtime profile in manifest: ", args$profile, call. = FALSE)
}

installed <- utils::installed.packages()
observed_version <- function(package) {
  if (!package %in% rownames(installed)) return(NA_character_)
  installed[package, "Version"]
}

expected <- list()
if (!is.null(entry$lockfile)) {
  lock_path <- file.path(dirname(args$manifest), "..", entry$lockfile)
  lock_path <- normalizePath(lock_path, mustWork = FALSE)
  if (!file.exists(lock_path)) {
    stop("Profile lockfile does not exist: ", lock_path, call. = FALSE)
  }
  lock <- jsonlite::fromJSON(lock_path, simplifyVector = FALSE)
  expected <- vapply(lock$Packages, `[[`, character(1), "Version")
}
if (!is.null(entry$required_packages)) {
  required <- unlist(entry$required_packages, use.names = TRUE)
  expected[names(required)] <- as.character(required)
}

if (!length(expected)) {
  stop("Manifest has neither a lockfile nor required packages for ", args$profile, call. = FALSE)
}

actual <- vapply(names(expected), observed_version, character(1))
missing <- names(actual)[is.na(actual)]
mismatch <- names(actual)[!is.na(actual) & actual != expected]
if (length(missing) || length(mismatch)) {
  details <- c(
    if (length(missing)) paste0("missing: ", paste(missing, collapse = ", ")),
    if (length(mismatch)) paste0(
      "version mismatch: ",
      paste(sprintf("%s expected %s observed %s", mismatch, expected[mismatch], actual[mismatch]), collapse = "; ")
    )
  )
  stop("Published ", args$profile, " runtime does not match its release record (", paste(details, collapse = "; "), ").", call. = FALSE)
}

cat("Published ", args$profile, " runtime verified: ", length(expected), " package version(s) match the release record.\n", sep = "")
