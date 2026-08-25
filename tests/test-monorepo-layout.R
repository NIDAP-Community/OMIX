script_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
if (length(script_arg) != 1L) {
  stop("Run this check with Rscript tests/test-monorepo-layout.R")
}

repo_root <- normalizePath(file.path(dirname(sub("^--file=", "", script_arg)), ".."))

required_root_paths <- c(
  "core/DESCRIPTION",
  "core/NAMESPACE",
  "core/R",
  "modules",
  "bridges/README.md",
  "docs/module-contract.md"
)

missing_root_paths <- required_root_paths[
  !file.exists(file.path(repo_root, required_root_paths))
]
stopifnot(length(missing_root_paths) == 0L)

module_dirs <- list.dirs(file.path(repo_root, "modules"), recursive = FALSE)
stopifnot(length(module_dirs) > 0L)

required_module_paths <- c(
  "R",
  "tests",
  "schemas",
  "module.yml",
  "README.md",
  "CHANGELOG.md"
)

for (module_dir in module_dirs) {
  missing_module_paths <- required_module_paths[
    !file.exists(file.path(module_dir, required_module_paths))
  ]
  if (length(missing_module_paths) > 0L) {
    stop(
      "Module contract failed for ", basename(module_dir), ": ",
      paste(missing_module_paths, collapse = ", "),
      call. = FALSE
    )
  }

  forbidden_platform_paths <- c(
    ".codeocean",
    "metadata",
    "environment",
    "code"
  )
  present_platform_paths <- forbidden_platform_paths[
    file.exists(file.path(module_dir, forbidden_platform_paths))
  ]
  if (length(present_platform_paths) > 0L) {
    stop(
      "Module contract failed for ", basename(module_dir),
      ": Code Ocean adapter paths belong in the individual repository, not ",
      "the canonical module: ",
      paste(present_platform_paths, collapse = ", "),
      call. = FALSE
    )
  }
}

bridge_dirs <- list.dirs(file.path(repo_root, "bridges"), recursive = FALSE)
required_bridge_paths <- c("DESCRIPTION", "NAMESPACE", "R", "tests", "README.md")
for (bridge_dir in bridge_dirs) {
  missing_bridge_paths <- required_bridge_paths[
    !file.exists(file.path(bridge_dir, required_bridge_paths))
  ]
  if (length(missing_bridge_paths) > 0L) {
    stop(
      "Bridge contract failed for ", basename(bridge_dir), ": ",
      paste(missing_bridge_paths, collapse = ", "),
      call. = FALSE
    )
  }
}

message("OMIX monorepo layout check passed.")
