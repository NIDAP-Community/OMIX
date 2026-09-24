#!/usr/bin/env Rscript

root <- normalizePath(getwd(), mustWork = TRUE)
example_dir <- file.path(root, "docs", "examples", "pathway-data-export", "v1")
manifest_path <- file.path(example_dir, "manifest.json")
schema_path <- file.path(root, "docs", "schemas", "pathway-export-manifest.schema.json")

stopifnot(file.exists(manifest_path), file.exists(schema_path))
stopifnot(requireNamespace("jsonlite", quietly = TRUE))
stopifnot(requireNamespace("jsonvalidate", quietly = TRUE))

schema_valid <- jsonvalidate::json_validate(
  manifest_path,
  schema_path,
  engine = "ajv",
  verbose = TRUE
)
stopifnot(isTRUE(schema_valid))

manifest <- jsonlite::fromJSON(manifest_path, simplifyVector = FALSE)
schema <- jsonlite::fromJSON(schema_path, simplifyVector = FALSE)
stopifnot(identical(manifest$schema_version, "1.0.0"))
stopifnot(identical(schema$properties$schema_version$const, "1.0.0"))
stopifnot(manifest$content_profile %in% c("open", "restricted-site", "custom"))

invalid_open_manifest <- manifest
invalid_open_manifest$sources[[2L]]$included <- TRUE
invalid_open_json <- jsonlite::toJSON(invalid_open_manifest, auto_unbox = TRUE)
stopifnot(!isTRUE(jsonvalidate::json_validate(
  invalid_open_json,
  schema_path,
  engine = "ajv"
)))

source_rows <- manifest$sources
source_ids <- vapply(source_rows, `[[`, character(1), "source_id")
stopifnot(!anyDuplicated(source_ids))
included <- vapply(source_rows, `[[`, logical(1), "included")
redistribution <- vapply(source_rows, `[[`, character(1), "redistribution")
stopifnot(all(redistribution[included] == "allowed"))
stopifnot(any(source_ids == "msigdb" & !included & redistribution == "restricted"))

genesets_path <- file.path(example_dir, manifest$files$genesets$path)
memberships_path <- file.path(example_dir, manifest$files$memberships$path)
notice_path <- file.path(example_dir, manifest$files$notice$path)
stopifnot(file.exists(genesets_path), file.exists(memberships_path), file.exists(notice_path))

genesets <- read.delim(genesets_path, sep = "\t", quote = "", check.names = FALSE, stringsAsFactors = FALSE)
memberships <- read.delim(memberships_path, sep = "\t", quote = "", check.names = FALSE, stringsAsFactors = FALSE)

expected_geneset_columns <- c(
  "geneset_id", "source_id", "geneset_type", "source_accession", "collection_id",
  "collection_name", "name", "description", "source_record_url",
  "organism_tax_id", "organism_name", "member_namespace"
)
stopifnot(identical(colnames(genesets), expected_geneset_columns))
stopifnot(identical(colnames(memberships), c("geneset_id", "member_id")))
stopifnot(nrow(genesets) == manifest$files$genesets$row_count)
stopifnot(nrow(memberships) == manifest$files$memberships$row_count)
stopifnot(!anyDuplicated(genesets$geneset_id))
stopifnot(!anyDuplicated(paste(memberships$geneset_id, memberships$member_id, sep = "\r")))
stopifnot(all(memberships$geneset_id %in% genesets$geneset_id))
stopifnot(all(genesets$source_id %in% source_ids[included]))
stopifnot(all(genesets$organism_tax_id %in% unlist(manifest$organism_tax_ids)))
stopifnot(all(genesets$member_namespace %in% unlist(manifest$identifier_namespaces)))
stopifnot(all(genesets$geneset_id %in% memberships$geneset_id))

long_table <- merge(memberships, genesets, by = "geneset_id", sort = FALSE)
legacy_table <- data.frame(
  pathways_database = paste0(long_table$source_id, "@1.0"),
  collection = long_table$collection_name,
  gene_set_id = long_table$geneset_id,
  gene_set_name = long_table$name,
  gene_symbol = long_table$member_id,
  species = ifelse(long_table$organism_tax_id == 9606L, "Human", NA_character_),
  stringsAsFactors = FALSE
)
stopifnot(nrow(legacy_table) == nrow(memberships))
stopifnot(!anyNA(legacy_table$species))
stopifnot(all(legacy_table$gene_set_id %in% genesets$geneset_id))

sha256 <- function(path) {
  output <- system2("shasum", c("-a", "256", path), stdout = TRUE)
  if (!length(output)) stop("shasum produced no output for ", path)
  sub("[[:space:]].*$", "", output[[1L]])
}

stopifnot(identical(sha256(genesets_path), manifest$files$genesets$sha256))
stopifnot(identical(sha256(memberships_path), manifest$files$memberships$sha256))
stopifnot(identical(sha256(notice_path), manifest$files$notice$sha256))

checksums_path <- file.path(example_dir, "CHECKSUMS.sha256")
stopifnot(file.exists(checksums_path))
checksum_lines <- readLines(checksums_path, warn = FALSE)
stopifnot(length(checksum_lines) == 4L)
checksum_values <- sub("[[:space:]].*$", "", checksum_lines)
checksum_files <- sub("^[0-9a-f]{64}[[:space:]]+", "", checksum_lines)
names(checksum_values) <- checksum_files
expected_checksum_files <- c("manifest.json", "genesets.tsv", "memberships.tsv", "NOTICE.md")
stopifnot(setequal(names(checksum_values), expected_checksum_files))
for (file_name in expected_checksum_files) {
  stopifnot(identical(
    unname(checksum_values[[file_name]]),
    sha256(file.path(example_dir, file_name))
  ))
}

cat("Pathway data export contract fixture passed.\n")
