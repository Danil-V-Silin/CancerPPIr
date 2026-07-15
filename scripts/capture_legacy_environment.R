#!/usr/bin/env Rscript

# Capture the software environment used by the legacy CancerPPIr workflow.
#
# This script uses only base R functions. It must be executed from the
# root directory of the CancerPPIr repository.

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
      "The script must be run from the CancerPPIr project root.\n",
      "Missing files: ",
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

# -------------------------------------------------------------------------
# 1. Full R session information
# -------------------------------------------------------------------------

capture.output(
  sessionInfo(),
  file = file.path(
    output_dir,
    "legacy_session_info.txt"
  )
)

# -------------------------------------------------------------------------
# 2. General R and operating-system information
# -------------------------------------------------------------------------

r_environment <- data.frame(
  parameter = c(
    "snapshot_time",
    "R_version",
    "R_version_major",
    "R_version_minor",
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
    R.version$major,
    R.version$minor,
    R.version$platform,
    R.version$arch,
    unname(Sys.info()[["sysname"]]),
    unname(Sys.info()[["release"]]),
    unname(Sys.info()[["machine"]]),
    Sys.timezone(),
    Sys.getlocale(),
    getOption("pkgType"),
    normalizePath(
      ".",
      winslash = "/",
      mustWork = TRUE
    ),
    normalizePath(
      R.home(),
      winslash = "/",
      mustWork = TRUE
    )
  ),
  stringsAsFactors = FALSE
)

utils::write.csv(
  r_environment,
  file.path(
    output_dir,
    "legacy_r_environment.csv"
  ),
  row.names = FALSE,
  na = ""
)

# -------------------------------------------------------------------------
# 3. R library paths
# -------------------------------------------------------------------------

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
  file.path(
    output_dir,
    "legacy_library_paths.csv"
  ),
  row.names = FALSE,
  na = ""
)

# -------------------------------------------------------------------------
# 4. Package repositories
# -------------------------------------------------------------------------

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
  file.path(
    output_dir,
    "legacy_repositories.csv"
  ),
  row.names = FALSE,
  na = ""
)

# -------------------------------------------------------------------------
# 5. Direct CancerPPIr dependencies
# -------------------------------------------------------------------------

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
          built_under_R = NA_character_,
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
      built_under_R = if (
        is.null(description$Built)
      ) {
        NA_character_
      } else {
        as.character(description$Built)
      },
      repository = if (
        is.null(description$Repository)
      ) {
        NA_character_
      } else {
        as.character(description$Repository)
      },
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
  file.path(
    output_dir,
    "legacy_package_versions.csv"
  ),
  row.names = FALSE,
  na = ""
)

# -------------------------------------------------------------------------
# 6. Bioconductor version
# -------------------------------------------------------------------------

bioconductor_information <- data.frame(
  parameter = c(
    "BiocManager_installed",
    "Bioconductor_version"
  ),
  value = c(
    as.character(
      requireNamespace(
        "BiocManager",
        quietly = TRUE
      )
    ),
    if (
      requireNamespace(
        "BiocManager",
        quietly = TRUE
      )
    ) {
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

# -------------------------------------------------------------------------
# 7. Selected environment variables relevant to R and HTTPS
# -------------------------------------------------------------------------

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

# -------------------------------------------------------------------------
# 8. Available compilation tools
# -------------------------------------------------------------------------

toolchain_commands <- c(
  "make",
  "gcc",
  "g++"
)

toolchain <- data.frame(
  command = toolchain_commands,
  path = unname(
    Sys.which(toolchain_commands)
  ),
  available = nzchar(
    unname(
      Sys.which(toolchain_commands)
    )
  ),
  stringsAsFactors = FALSE
)

utils::write.csv(
  toolchain,
  file.path(
    output_dir,
    "legacy_toolchain.csv"
  ),
  row.names = FALSE,
  na = ""
)

# -------------------------------------------------------------------------
# 9. Checksums of the current and preserved source files
# -------------------------------------------------------------------------

source_files <- c(
  "cancerppir.R",
  "legacy/cancerppir_legacy.R"
)

code_manifest <- data.frame(
  file = source_files,
  size_bytes = file.info(source_files)$size,
  md5 = unname(
    tools::md5sum(source_files)
  ),
  stringsAsFactors = FALSE
)

utils::write.csv(
  code_manifest,
  file.path(
    output_dir,
    "legacy_code_manifest.csv"
  ),
  row.names = FALSE,
  na = ""
)

# -------------------------------------------------------------------------
# 10. Simple validation
# -------------------------------------------------------------------------

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
      paste(
        missing_runtime_packages,
        collapse = ", "
      )
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