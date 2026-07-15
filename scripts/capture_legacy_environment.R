#!/usr/bin/env Rscript

# Capture the software environment used by the legacy CancerPPIr workflow.
# Run this script from the root directory of the CancerPPIr repository.

required_project_files <- c(
  "cancerppir.R",
  "legacy/cancerppir_legacy.R"
)

missing_project_files <- required_project_files[
  !file.exists(required_project_files)
]

if (length(missing_project_files) > 0L) {
  stop(
    paste0(
      "Run this script from the CancerPPIr project root. Missing files: ",
      paste(missing_project_files, collapse = ", ")
    ),
    call. = FALSE
  )
}

output_dir <- "tests/reference/environment"

dir.create(
  output_dir,
  recursive = TRUE,
  showWarnings = FALSE
)

scalar_or_na <- function(x) {
  if (is.null(x) || length(x) == 0L || is.na(x[[1]])) {
    return(NA_character_)
  }

  as.character(x[[1]])
}

# 1. Full R session information
capture.output(
  sessionInfo(),
  file = file.path(output_dir, "legacy_session_info.txt")
)

# 2. R and operating-system information
r_environment <- data.frame(
  parameter = c(
    "snapshot_time",
    "R_version",
    "R_platform",
    "R_architecture",
    "operating_system",
    "operating_system_release",
    "machine",
    "timezone",
    "locale",
    "package_type",
    "working_directory",
    "R_home"
  ),
  value = c(
    format(Sys.time(), "%Y-%m-%d %H:%M:%S %z"),
    R.version.string,
    R.version$platform,
    R.version$arch,
    unname(Sys.info()[["sysname"]]),
    unname(Sys.info()[["release"]]),
    unname(Sys.info()[["machine"]]),
    Sys.timezone(),
    Sys.getlocale(),
    getOption("pkgType"),
    normalizePath(".", winslash = "/", mustWork = TRUE),
    normalizePath(R.home(), winslash = "/", mustWork = TRUE)
  ),
  stringsAsFactors = FALSE
)

utils::write.csv(
  r_environment,
  file.path(output_dir, "legacy_r_environment.csv"),
  row.names = FALSE,
  na = ""
)

# 3. R library paths
library_paths <- data.frame(
  priority = seq_along(.libPaths()),
  library_path = normalizePath(
    .libPaths(),
    winslash = "/",
    mustWork = FALSE
  ),
  stringsAsFactors = FALSE
)

utils::write.csv(
  library_paths,
  file.path(output_dir, "legacy_library_paths.csv"),
  row.names = FALSE,
  na = ""
)

# 4. Configured package repositories
repositories <- getOption("repos")

if (is.null(names(repositories))) {
  names(repositories) <- paste0(
    "repository_",
    seq_along(repositories)
  )
}

repository_table <- data.frame(
  repository = names(repositories),
  url = unname(repositories),
  stringsAsFactors = FALSE
)

utils::write.csv(
  repository_table,
  file.path(output_dir, "legacy_repositories.csv"),
  row.names = FALSE,
  na = ""
)

# 5. Direct CancerPPIr dependencies
direct_packages <- c(
  "HGNChelper",
  "STRINGdb",
  "igraph",
  "openxlsx",
  "dplyr",
  "tibble",
  "curl",
  "sna",
  "gprofiler2"
)

package_information <- lapply(
  direct_packages,
  function(package) {
    installed <- requireNamespace(
      package,
      quietly = TRUE
    )

    if (!installed) {
      return(
        data.frame(
          package = package,
          installed = FALSE,
          version = NA_character_,
          library_path = NA_character_,
          built = NA_character_,
          repository = NA_character_,
          stringsAsFactors = FALSE
        )
      )
    }

    description <- utils::packageDescription(package)

    data.frame(
      package = package,
      installed = TRUE,
      version = as.character(
        utils::packageVersion(package)
      ),
      library_path = normalizePath(
        find.package(package),
        winslash = "/",
        mustWork = TRUE
      ),
      built = scalar_or_na(description$Built),
      repository = scalar_or_na(description$Repository),
      stringsAsFactors = FALSE
    )
  }
)

package_versions <- do.call(
  rbind,
  package_information
)

utils::write.csv(
  package_versions,
  file.path(output_dir, "legacy_package_versions.csv"),
  row.names = FALSE,
  na = ""
)

# 6. Bioconductor information
biocmanager_installed <- requireNamespace(
  "BiocManager",
  quietly = TRUE
)

bioconductor_information <- data.frame(
  parameter = c(
    "BiocManager_installed",
    "Bioconductor_version"
  ),
  value = c(
    as.character(biocmanager_installed),
    if (biocmanager_installed) {
      as.character(BiocManager::version())
    } else {
      NA_character_
    }
  ),
  stringsAsFactors = FALSE
)

utils::write.csv(
  bioconductor_information,
  file.path(
    output_dir,
    "legacy_bioconductor_environment.csv"
  ),
  row.names = FALSE,
  na = ""
)

# 7. Relevant environment variables
environment_variable_names <- c(
  "R_LIBS_USER",
  "R_LIBS_SITE",
  "R_DEFAULT_INTERNET_TIMEOUT",
  "CURL_CA_BUNDLE",
  "SSL_CERT_FILE",
  "GIT_SSL_CAINFO"
)

environment_variables <- data.frame(
  variable = environment_variable_names,
  value = Sys.getenv(
    environment_variable_names,
    unset = NA_character_
  ),
  stringsAsFactors = FALSE
)

utils::write.csv(
  environment_variables,
  file.path(
    output_dir,
    "legacy_environment_variables.csv"
  ),
  row.names = FALSE,
  na = ""
)

# 8. Source-code checksums
source_files <- c(
  "cancerppir.R",
  "legacy/cancerppir_legacy.R"
)

code_manifest <- data.frame(
  file = source_files,
  size_bytes = file.info(source_files)$size,
  md5 = unname(tools::md5sum(source_files)),
  stringsAsFactors = FALSE
)

utils::write.csv(
  code_manifest,
  file.path(output_dir, "legacy_code_manifest.csv"),
  row.names = FALSE,
  na = ""
)

# 9. Validate required runtime packages
required_runtime_packages <- c(
  "HGNChelper",
  "STRINGdb",
  "igraph",
  "openxlsx",
  "dplyr",
  "tibble",
  "curl",
  "sna"
)

missing_runtime_packages <- required_runtime_packages[
  !vapply(
    required_runtime_packages,
    requireNamespace,
    quietly = TRUE,
    FUN.VALUE = logical(1)
  )
]

if (length(missing_runtime_packages) > 0L) {
  warning(
    paste0(
      "Missing required legacy packages: ",
      paste(missing_runtime_packages, collapse = ", ")
    ),
    call. = FALSE
  )
}

message(
  "Legacy environment snapshot written to: ",
  normalizePath(
    output_dir,
    winslash = "/",
    mustWork = TRUE
  )
)
