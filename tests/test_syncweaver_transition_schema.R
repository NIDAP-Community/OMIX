#!/usr/bin/env Rscript

script_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
if (length(script_arg) != 1L) {
  stop("Run this check with Rscript tests/test_syncweaver_transition_schema.R")
}

repo_root <- normalizePath(file.path(dirname(sub("^--file=", "", script_arg)), ".."))
contract_path <- file.path(repo_root, "docs", "syncweaver-transition-wave1.json")
schema_path <- file.path(
  repo_root,
  "docs",
  "schemas",
  "syncweaver-transition-contract.schema.json"
)

stopifnot(file.exists(contract_path), file.exists(schema_path))
stopifnot(requireNamespace("jsonlite", quietly = TRUE))
stopifnot(requireNamespace("jsonvalidate", quietly = TRUE))
stopifnot(isTRUE(jsonvalidate::json_validate(
  contract_path,
  schema_path,
  engine = "ajv"
)))

contract <- jsonlite::fromJSON(contract_path, simplifyVector = FALSE)
stopifnot(identical(contract$schema_version, "1.0.0"))
stopifnot(identical(contract$status, "preparation_only"))
stopifnot(identical(contract$policy$scientific_flow, "canonical_to_adapter_only"))
stopifnot(identical(contract$policy$timestamp_resolution_allowed, FALSE))
stopifnot(identical(contract$policy$all_unlisted_adapter_paths_protected, TRUE))

adapter_ids <- vapply(contract$adapters, `[[`, character(1), "id")
stopifnot(!anyDuplicated(adapter_ids), length(adapter_ids) == 3L)
for (adapter in contract$adapters) {
  source_paths <- vapply(adapter$mappings, `[[`, character(1), "source_path")
  destination_paths <- vapply(adapter$mappings, `[[`, character(1), "destination_path")
  source_hashes <- vapply(adapter$mappings, `[[`, character(1), "source_sha256")
  destination_hashes <- vapply(
    adapter$mappings,
    `[[`,
    character(1),
    "expected_destination_sha256"
  )
  stopifnot(!anyDuplicated(source_paths), !anyDuplicated(destination_paths))
  stopifnot(identical(source_hashes, destination_hashes))
  stopifnot(all(startsWith(source_paths, paste0(adapter$canonical$source_root, "/"))))
  stopifnot(all(startsWith(destination_paths, "code/functions/")))
}

cat("Syncweaver transition JSON Schema check passed.\n")
