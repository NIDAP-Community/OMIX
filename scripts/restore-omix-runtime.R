#!/usr/bin/env Rscript

# Create a reproducible, writable OMIX runtime for one portable module.
#
# Shared profile locks intentionally avoid a repository-wide dependency set.
# This helper restores the profile selected by module.yml, installs the two
# immutable source packages that are intentionally outside r-pathway's lock,
# applies a pinned module overlay when declared, then snapshots the resulting
# run project. The generated <project>/renv.lock is the effective lockfile for
# that specific module and should be retained with the analysis provenance.

abort <- function(...) {
  stop(paste0(...), call. = FALSE)
}

usage <- function() {
  cat(
    "Usage:\n",
    "  Rscript scripts/restore-omix-runtime.R --module <module-directory> --project <writable-run-directory>\n\n",
    "Examples:\n",
    "  Rscript scripts/restore-omix-runtime.R \\\n",
    "    --module OMIX-DEG-Analysis \\\n",
    "    --project /data/$USER/omix-deg-runtime\n\n",
    "The module selects its shared runtime profile in module.yml. The helper\n",
    "writes the fully resolved effective lockfile to <project>/renv.lock.\n",
    sep = ""
  )
}

parse_args <- function(args) {
  parsed <- list()
  index <- 1L
  while (index <= length(args)) {
    argument <- args[[index]]
    if (argument %in% c("--help", "-h")) {
      parsed$help <- TRUE
      index <- index + 1L
      next
    }
    if (!startsWith(argument, "--")) {
      abort("Unexpected argument: ", argument)
    }
    if (index == length(args)) {
      abort("Missing value for ", argument)
    }
    key <- sub("^--", "", argument)
    parsed[[gsub("-", "_", key, fixed = TRUE)]] <- args[[index + 1L]]
    index <- index + 2L
  }
  parsed
}

trim_scalar <- function(value) {
  sub("^['\"]|['\"]$", "", trimws(value))
}

parse_module_runtime <- function(module_yml) {
  lines <- readLines(module_yml, warn = FALSE)
  profile_line <- grep("^runtime_profile:[[:space:]]*", lines, value = TRUE)
  if (length(profile_line) != 1L) {
    abort("module.yml must declare exactly one runtime_profile: ", module_yml)
  }
  profile <- trim_scalar(sub("^runtime_profile:[[:space:]]*", "", profile_line))

  overlays <- list()
  current_kind <- NULL
  current_package <- NULL
  current_version <- NULL
  flush_overlay <- function() {
    if (!is.null(current_package)) {
      if (is.null(current_kind) || current_kind != "bioconductor" || is.null(current_version)) {
        abort(
          "Each runtime_overlay package must declare a Bioconductor version in ",
          module_yml
        )
      }
      overlays[[length(overlays) + 1L]] <<- list(
        kind = current_kind,
        package = current_package,
        version = current_version
      )
    }
  }

  overlay_start <- grep("^runtime_overlay:[[:space:]]*$", lines)
  if (length(overlay_start) > 1L) {
    abort("module.yml must contain at most one runtime_overlay block: ", module_yml)
  }
  if (length(overlay_start) == 1L) {
    for (line in lines[seq.int(overlay_start + 1L, length(lines))]) {
      if (nzchar(line) && !grepl("^[[:space:]]", line)) {
        break
      }
      trimmed <- trimws(line)
      if (identical(trimmed, "bioconductor:")) {
        flush_overlay()
        current_kind <- "bioconductor"
        current_package <- NULL
        current_version <- NULL
      } else if (grepl("^- package:[[:space:]]*", trimmed)) {
        flush_overlay()
        current_package <- trim_scalar(sub("^- package:[[:space:]]*", "", trimmed))
        current_version <- NULL
      } else if (grepl("^version:[[:space:]]*", trimmed) && !is.null(current_package)) {
        current_version <- trim_scalar(sub("^version:[[:space:]]*", "", trimmed))
      } else if (grepl("^- [^[:space:]]", trimmed)) {
        abort(
          "Use '- package:' plus an explicit 'version:' for runtime_overlay entries in ",
          module_yml
        )
      }
    }
    flush_overlay()
  }

  list(profile = profile, overlays = overlays)
}

profile_repositories <- function() {
  c(
    CRAN = "https://cran.r-project.org",
    BioCsoft = "https://bioconductor.org/packages/3.20/bioc",
    BioCann = "https://bioconductor.org/packages/3.20/data/annotation",
    BioCexp = "https://bioconductor.org/packages/3.20/data/experiment",
    BioCworkflows = "https://bioconductor.org/packages/3.20/workflows",
    BioCbooks = "https://bioconductor.org/packages/3.20/books"
  )
}

install_pathway_archives <- function(repo_root, project) {
  dockerfile <- file.path(repo_root, "starter-environments", "r-pathway", "Dockerfile")
  docker_lines <- readLines(dockerfile, warn = FALSE)
  ref_line <- grep("^ARG L2P_REF=", docker_lines, value = TRUE)
  if (length(ref_line) != 1L) {
    abort("Could not find the immutable L2P_REF in ", dockerfile)
  }
  l2p_ref <- sub("^ARG L2P_REF=", "", ref_line)
  library_path <- renv::paths$library(project = project)
  packages <- c("l2p_0.0-14.tar.gz", "l2psupp_0.0-14.tar.gz")

  for (archive_name in packages) {
    archive <- tempfile(pattern = sub("\\.tar\\.gz$", "-", archive_name), fileext = ".tar.gz")
    on.exit(unlink(archive), add = TRUE)
    url <- paste0("https://raw.githubusercontent.com/CCBR/l2p/", l2p_ref, "/", archive_name)
    message("Installing immutable pathway package from ", url)
    utils::download.file(url, archive, mode = "wb", quiet = TRUE)
    utils::install.packages(archive, repos = NULL, type = "source", lib = library_path)
  }
}

install_bioconductor_overlays <- function(overlays, project) {
  if (length(overlays) == 0L) {
    return(invisible(NULL))
  }
  library_path <- renv::paths$library(project = project)
  repos <- profile_repositories()
  old_repos <- getOption("repos")
  on.exit(options(repos = old_repos), add = TRUE)
  options(repos = repos, pkgType = "source")

  for (overlay in overlays) {
    message(
      "Installing Bioconductor overlay ", overlay$package,
      " ", overlay$version, " from Bioconductor 3.20"
    )
    utils::install.packages(
      overlay$package,
      lib = library_path,
      repos = repos,
      dependencies = c("Depends", "Imports", "LinkingTo"),
      quiet = TRUE
    )
    installed_version <- as.character(utils::packageVersion(overlay$package, lib.loc = library_path))
    if (!identical(installed_version, overlay$version)) {
      abort(
        "Expected ", overlay$package, " ", overlay$version,
        " from Bioconductor 3.20 but installed ", installed_version,
        ". Do not snapshot this runtime; verify the configured repositories."
      )
    }
  }
}

arguments <- parse_args(commandArgs(trailingOnly = TRUE))
if (isTRUE(arguments$help)) {
  usage()
  quit(status = 0L)
}
if (is.null(arguments$module) || is.null(arguments$project)) {
  usage()
  abort("Both --module and --project are required.")
}
if (!requireNamespace("renv", quietly = TRUE)) {
  abort(
    "The renv package is required to prepare an OMIX runtime. Install it first with: ",
    "Rscript -e 'install.packages(\"renv\", repos = \"https://cran.r-project.org\")'"
  )
}

script_argument <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
if (length(script_argument) != 1L) {
  abort("Run this helper with Rscript scripts/restore-omix-runtime.R")
}
repo_root <- normalizePath(file.path(dirname(sub("^--file=", "", script_argument)), ".."))
module_dir <- file.path(repo_root, "modules", arguments$module)
module_yml <- file.path(module_dir, "module.yml")
if (!file.exists(module_yml)) {
  abort("No OMIX module metadata found at ", module_yml)
}

runtime <- parse_module_runtime(module_yml)
profile_dir <- file.path(repo_root, "starter-environments", runtime$profile)
profile_lock <- file.path(profile_dir, "renv.lock")
if (!file.exists(profile_lock)) {
  abort("The module runtime profile has no committed lockfile: ", profile_lock)
}

project <- normalizePath(arguments$project, mustWork = FALSE)
dir.create(project, recursive = TRUE, showWarnings = FALSE)
renv::activate(project = project)
file.copy(profile_lock, file.path(project, "renv.lock"), overwrite = TRUE)

message("Restoring shared runtime profile ", runtime$profile)
renv::restore(project = project, lockfile = file.path(project, "renv.lock"), prompt = FALSE)
if (identical(runtime$profile, "r-pathway")) {
  install_pathway_archives(repo_root, project)
}
install_bioconductor_overlays(runtime$overlays, project)

message("Snapshotting the complete effective runtime lockfile")
renv::snapshot(project = project, type = "all", prompt = FALSE, force = TRUE)
message(
  "OMIX runtime is ready for ", arguments$module, ".\n",
  "Effective lockfile: ", file.path(project, "renv.lock"), "\n",
  "Run module commands from this project directory so renv activates automatically."
)
