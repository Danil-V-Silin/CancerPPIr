#!/usr/bin/env Rscript

# Run one local end-to-end R01 smoke test and compare it with the
# frozen Phase 1 baseline.
#
# Optional positional arguments:
#   1 baseline_root
#   2 input_file
#   3 cache_dir
#   4 results_root
#
# Default invocation from the repository root:
#   Rscript scripts/run_r01_smoke_test.R

project_root <- normalizePath(
  ".",
  winslash = "/",
  mustWork = TRUE
)

arguments <- commandArgs(
  trailingOnly = TRUE
)

baseline_root <- if (length(arguments) >= 1L) {
  arguments[[1L]]
} else {
  file.path("..", "results", "renv_phase1_full")
}

input_file <- if (length(arguments) >= 2L) {
  arguments[[2L]]
} else {
  file.path("..", "input", "Genes_R.csv")
}

cache_dir <- if (length(arguments) >= 3L) {
  arguments[[3L]]
} else {
  file.path("..", "string_cache")
}

results_root <- if (length(arguments) >= 4L) {
  arguments[[4L]]
} else {
  file.path("..", "results", "phase3_r01_smoke")
}

required_paths <- c(
  baseline_root,
  input_file,
  cache_dir
)

missing_paths <- required_paths[
  !file.exists(required_paths)
]

if (length(missing_paths) > 0L) {
  stop(
    paste0(
      "Required smoke-test paths are missing:\n",
      paste0("- ", missing_paths, collapse = "\n")
    ),
    call. = FALSE
  )
}

if (dir.exists(results_root)) {
  stop(
    paste0(
      "Smoke-test output folder already exists: ",
      results_root,
      "\nRemove it or provide a different fourth argument."
    ),
    call. = FALSE
  )
}

dir.create(
  file.path(results_root, "logs"),
  recursive = TRUE,
  showWarnings = FALSE
)

log_file <- file.path(
  results_root,
  "logs",
  "R01.log"
)

rscript <- Sys.which(
  "Rscript"
)

pipeline_status <- system2(
  command = rscript,
  args = c(
    shQuote(
      file.path(project_root, "cancerppir.R")
    ),
    shQuote(input_file),
    shQuote(results_root),
    shQuote(cache_dir),
    "400",
    "30",
    "TRUE"
  ),
  stdout = log_file,
  stderr = log_file
)

if (!identical(as.integer(pipeline_status), 0L)) {
  stop(
    paste0(
      "R01 smoke pipeline failed with exit code ",
      pipeline_status,
      ". See: ",
      log_file
    ),
    call. = FALSE
  )
}

log_lines <- readLines(
  log_file,
  warn = FALSE,
  encoding = "UTF-8"
)

required_log_fragments <- c(
  "[CancerPPIr] Done.",
  "[CancerPPIr] Mapped genes: 359/399 (90%)",
  "[CancerPPIr] Network: 358 nodes, 4507 edges, 42 components"
)

missing_log_fragments <- required_log_fragments[
  !vapply(
    required_log_fragments,
    function(fragment) {
      any(grepl(
        fragment,
        log_lines,
        fixed = TRUE
      ))
    },
    FUN.VALUE = logical(1)
  )
]

if (length(missing_log_fragments) > 0L) {
  stop(
    paste0(
      "Smoke log is missing required completion evidence:\n",
      paste0("- ", missing_log_fragments, collapse = "\n")
    ),
    call. = FALSE
  )
}

error_patterns <- c(
  "Error",
  "failed",
  "Execution halted",
  "Выполнение остановлено"
)

if (any(vapply(
  error_patterns,
  function(pattern) {
    any(grepl(
      pattern,
      log_lines,
      ignore.case = TRUE
    ))
  },
  FUN.VALUE = logical(1)
))) {
  stop(
    paste0(
      "Smoke log contains an error marker. See: ",
      log_file
    ),
    call. = FALSE
  )
}

expected_files <- file.path(
  results_root,
  "Genes_R",
  c(
    "CancerPPIr_Analytical_Report.xlsx",
    "CancerPPIr_Technical_Report.xlsx",
    "Network_for_Cytoscape.graphml",
    "STRING_links.txt"
  )
)

if (!all(file.exists(expected_files))) {
  stop(
    paste0(
      "Smoke test did not produce all expected files:\n",
      paste0(
        "- ",
        expected_files[!file.exists(expected_files)],
        collapse = "\n"
      )
    ),
    call. = FALSE
  )
}

comparison_status <- system2(
  command = rscript,
  args = c(
    shQuote(
      file.path(
        project_root,
        "scripts",
        "compare_architecture_checkpoint_case.R"
      )
    ),
    shQuote(baseline_root),
    shQuote(results_root),
    "R01",
    "Genes_R",
    "phase_3_r01_smoke"
  )
)

if (!identical(as.integer(comparison_status), 0L)) {
  stop(
    paste0(
      "R01 baseline comparison failed with exit code ",
      comparison_status,
      "."
    ),
    call. = FALSE
  )
}

summary_file <- file.path(
  project_root,
  "docs",
  "architecture",
  "phase_3_r01_smoke_summary.csv"
)

summary_table <- utils::read.csv(
  summary_file,
  stringsAsFactors = FALSE
)

stopifnot(
  nrow(summary_table) == 1L,
  isTRUE(summary_table$strict_regression_core_match[[1L]]),
  summary_table$strict_sheets_compared[[1L]] == 12L,
  summary_table$strict_sheets_identical[[1L]] == 12L
)

cat("PHASE 3.2 R01 SMOKE TEST PASSED: 12/12 STRICT SHEETS\n")
