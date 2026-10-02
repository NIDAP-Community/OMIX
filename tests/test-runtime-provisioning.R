script_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
if (length(script_arg) != 1L) {
  stop("Run this check with Rscript tests/test-runtime-provisioning.R")
}

repo_root <- normalizePath(file.path(dirname(sub("^--file=", "", script_arg)), ".."))
helper <- file.path(repo_root, "scripts", "restore-omix-runtime.R")
stopifnot(file.exists(helper))
help_output <- system2("Rscript", c(helper, "--help"), stdout = TRUE, stderr = TRUE)
stopifnot(is.null(attr(help_output, "status")) || attr(help_output, "status") == 0L)
stopifnot(any(grepl("--module <module-directory>", help_output, fixed = TRUE)))

# Load helper functions without entering its command-line main block.
helper_lines <- readLines(helper, warn = FALSE)
helper_main <- grep("^arguments <-", helper_lines)[1L]
stopifnot(!is.na(helper_main))
eval(parse(text = helper_lines[seq_len(helper_main - 1L)]))
stopifnot(is.function(install_omix_pathway_packages))

pathway_source_packages <- c(
  OmixPathwayInputs = "0.1.0",
  OmixPathwayPlots = "0.2.0"
)
dockerignore <- readLines(file.path(repo_root, ".dockerignore"), warn = FALSE)
for (package in names(pathway_source_packages)) {
  description <- read.dcf(
    file.path(repo_root, "packages", package, "DESCRIPTION")
  )
  observed_version <- unname(description[1L, "Version"])
  stopifnot(identical(observed_version, pathway_source_packages[[package]]))
  stopifnot(any(grepl(paste0("!packages/", package, "/**"), dockerignore, fixed = TRUE)))
}

profile_locks <- file.path(
  repo_root,
  "starter-environments",
  c("r-statistics", "r-visualization", "r-pathway"),
  "renv.lock"
)
stopifnot(all(file.exists(profile_locks)))

module_dirs <- list.dirs(file.path(repo_root, "modules"), recursive = FALSE)
for (module_dir in module_dirs) {
  module_yml <- readLines(file.path(module_dir, "module.yml"), warn = FALSE)
  profile_line <- grep("^runtime_profile:[[:space:]]*", module_yml, value = TRUE)
  stopifnot(length(profile_line) == 1L)
  profile <- trimws(sub("^runtime_profile:[[:space:]]*", "", profile_line))
  stopifnot(file.exists(file.path(repo_root, "starter-environments", profile, "renv.lock")))
  readme <- readLines(file.path(module_dir, "README.md"), warn = FALSE)
  # Documentation may call this a runtime or a runtime profile. Require the
  # actual profile identifier instead of coupling the check to one heading.
  stopifnot(any(grepl(profile, readme, fixed = TRUE)))
  stopifnot(any(grepl("restore-omix-runtime.R", readme, fixed = TRUE)))
}

gsea_metadata <- readLines(
  file.path(repo_root, "modules", "OMIX-GSEA-Visualization-Legacy", "module.yml"),
  warn = FALSE
)
stopifnot(any(grepl("package: ComplexHeatmap", gsea_metadata, fixed = TRUE)))
stopifnot(any(grepl("version: 2.22.0", gsea_metadata, fixed = TRUE)))
gsea_runtime <- parse_module_runtime(
  file.path(repo_root, "modules", "OMIX-GSEA-Visualization-Legacy", "module.yml")
)
stopifnot(identical(gsea_runtime$profile, "r-pathway"))
stopifnot(length(gsea_runtime$overlays) == 1L)
stopifnot(identical(gsea_runtime$overlays[[1L]]$package, "ComplexHeatmap"))
stopifnot(identical(gsea_runtime$overlays[[1L]]$version, "2.22.0"))

root_readme <- readLines(file.path(repo_root, "README.md"), warn = FALSE)
stopifnot(any(grepl("OMIX-GSEA-Visualization-Legacy", root_readme, fixed = TRUE)))
message("OMIX runtime provisioning check passed.")
