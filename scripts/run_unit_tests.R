#!/usr/bin/env Rscript

# Fast local unit-test runner for the modular CancerPPIr workflow.

project_root <- normalizePath(
  ".",
  winslash = "/",
  mustWork = TRUE
)

required_packages <- c(
  "testthat",
  "dplyr",
  "tibble"
)

missing_packages <- required_packages[
  !vapply(
    required_packages,
    requireNamespace,
    quietly = TRUE,
    FUN.VALUE = logical(1)
  )
]

if (length(missing_packages) > 0L) {
  stop(
    paste0(
      "Missing test dependencies: ",
      paste(missing_packages, collapse = ", "),
      "\nInstall them through renv before running the tests."
    ),
    call. = FALSE
  )
}

suppressPackageStartupMessages({
  library(dplyr)
  library(tibble)
})

source(
  file.path(project_root, "R", "load_all.R"),
  local = .GlobalEnv
)

loaded_files <- load_cancerppir_modules(
  project_root = project_root,
  envir = .GlobalEnv
)

stopifnot(length(loaded_files) == 11L)

Sys.setenv(
  CANCERPPIR_PROJECT_ROOT = project_root
)

testthat::test_dir(
  file.path(project_root, "tests", "testthat"),
  reporter = "summary",
  env = .GlobalEnv,
  stop_on_failure = TRUE,
  stop_on_warning = FALSE
)

cat("\nCANCERPPIR TEST SUITE PASSED\n")
