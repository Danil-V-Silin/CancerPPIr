#!/usr/bin/env Rscript

# CancerPPIr Phase 4.5 implementation checkpoint
#
# Performs one complete checkpoint:
#   1. runs the full unit-test suite;
#   2. runs one real CancerPPIr case;
#   3. validates the six-sheet analytical workbook;
#   4. verifies the Phase 4 technical sheets;
#   5. verifies GraphML readability.
#
# Optional positional arguments:
#   1. input CSV
#   2. results root
#   3. STRING cache directory
#
# Defaults:
#   ../input/Genes_A.csv
#   ../results/phase4_5_a01_checkpoint
#   ../string_cache
#
# Run from repository root:
#   Rscript scripts/run_phase4_5_checkpoint.R

arguments <- commandArgs(
  trailingOnly = TRUE
)

input_file <- if (length(arguments) >= 1L) {
  arguments[[1L]]
} else {
  file.path(
    "..",
    "input",
    "Genes_A.csv"
  )
}

results_root <- if (length(arguments) >= 2L) {
  arguments[[2L]]
} else {
  file.path(
    "..",
    "results",
    "phase4_5_a01_checkpoint"
  )
}

cache_dir <- if (length(arguments) >= 3L) {
  arguments[[3L]]
} else {
  file.path(
    "..",
    "string_cache"
  )
}

project_root <- normalizePath(
  ".",
  winslash = "/",
  mustWork = TRUE
)

input_file <- normalizePath(
  input_file,
  winslash = "/",
  mustWork = TRUE
)

cache_dir <- normalizePath(
  cache_dir,
  winslash = "/",
  mustWork = TRUE
)

if (dir.exists(results_root)) {
  existing_entries <- list.files(
    results_root,
    all.files = TRUE,
    no.. = TRUE
  )

  if (length(existing_entries) > 0L) {
    stop(
      paste0(
        "Checkpoint results directory already exists and is not empty: ",
        results_root,
        "\nRemove it or pass a different second argument."
      ),
      call. = FALSE
    )
  }
} else {
  dir.create(
    results_root,
    recursive = TRUE,
    showWarnings = FALSE
  )
}

results_root <- normalizePath(
  results_root,
  winslash = "/",
  mustWork = TRUE
)

rscript_command <- file.path(
  R.home("bin"),
  if (.Platform$OS.type == "windows") {
    "Rscript.exe"
  } else {
    "Rscript"
  }
)

unit_test_log <- file.path(
  results_root,
  "unit_tests.log"
)

unit_test_status <- system2(
  command = rscript_command,
  args = shQuote(
    file.path(
      project_root,
      "scripts",
      "run_unit_tests.R"
    )
  ),
  stdout = unit_test_log,
  stderr = unit_test_log,
  wait = TRUE
)

if (
  is.null(unit_test_status) ||
    is.na(unit_test_status) ||
    unit_test_status != 0L
) {
  log_tail <- tail(
    readLines(
      unit_test_log,
      warn = FALSE,
      encoding = "UTF-8"
    ),
    80L
  )

  stop(
    paste0(
      "Unit tests failed with exit status ",
      unit_test_status,
      ".\n\nLog tail:\n",
      paste(
        log_tail,
        collapse = "\n"
      )
    ),
    call. = FALSE
  )
}

source(
  file.path(
    project_root,
    "R",
    "load_all.R"
  ),
  local = .GlobalEnv
)

load_cancerppir_modules(
  project_root = project_root,
  envir = .GlobalEnv
)

message(
  "[Phase 4.5 checkpoint] Unit tests: PASS."
)

result <- run_cancerppir(
  input_file = input_file,
  results_root = results_root,
  cache_dir = cache_dir,
  score_threshold = 400L,
  top_n = 30L,
  run_enrichment = TRUE
)

analytical_workbook <- unname(
  result$files[[
    "analytical_report"
  ]]
)

technical_workbook <- unname(
  result$files[[
    "technical_report"
  ]]
)

graphml_file <- unname(
  result$files[[
    "graphml"
  ]]
)

required_files <- c(
  analytical_workbook,
  technical_workbook,
  graphml_file,
  unname(
    result$files[[
      "string_links"
    ]]
  )
)

if (!all(
  file.exists(
    required_files
  )
)) {
  stop(
    "One or more required checkpoint outputs are missing.",
    call. = FALSE
  )
}

analytical_sheet_names <- openxlsx::getSheetNames(
  analytical_workbook
)

if (!identical(
  analytical_sheet_names,
  CANCERPPIR_ANALYTICAL_SHEET_NAMES
)) {
  stop(
    paste0(
      "Analytical workbook sheet order is invalid: ",
      paste(
        analytical_sheet_names,
        collapse = " | "
      )
    ),
    call. = FALSE
  )
}

expected_columns <- phase4_expected_analytical_columns()

analytical_summary_rows <- list()

for (sheet_name in names(
  expected_columns
)) {
  sheet_data <- openxlsx::read.xlsx(
    analytical_workbook,
    sheet = sheet_name,
    colNames = TRUE,
    check.names = FALSE
  )

  if (!identical(
    names(sheet_data),
    expected_columns[[sheet_name]]
  )) {
    stop(
      paste0(
        "Analytical sheet schema mismatch for ",
        sheet_name,
        "."
      ),
      call. = FALSE
    )
  }

  analytical_summary_rows[[
    sheet_name
  ]] <- data.frame(
    sheet_name = sheet_name,
    row_count = nrow(
      sheet_data
    ),
    column_count = ncol(
      sheet_data
    ),
    stringsAsFactors = FALSE
  )
}

analytical_summary <- do.call(
  rbind,
  analytical_summary_rows
)

rownames(analytical_summary) <- NULL

technical_sheet_names <- openxlsx::getSheetNames(
  technical_workbook
)

required_technical_sheets <- c(
  "Phase4 module annotations",
  "Phase4 rule evidence",
  "Phase4 significant terms",
  "Phase4 node annotations",
  "Phase4 validation"
)

missing_technical_sheets <- setdiff(
  required_technical_sheets,
  technical_sheet_names
)

if (length(missing_technical_sheets) > 0L) {
  stop(
    paste0(
      "Technical workbook is missing Phase 4 sheet(s): ",
      paste(
        missing_technical_sheets,
        collapse = ", "
      ),
      "."
    ),
    call. = FALSE
  )
}

if (
  is.null(
    result$analytical_report_validation
  ) ||
    any(
      result$analytical_report_validation$status ==
        "FAIL"
    )
) {
  stop(
    "In-memory analytical report validation did not pass.",
    call. = FALSE
  )
}

graph <- igraph::read_graph(
  graphml_file,
  format = "graphml"
)

graph_summary <- data.frame(
  metric = c(
    "graph_nodes",
    "graph_edges"
  ),
  value = c(
    igraph::gorder(
      graph
    ),
    igraph::gsize(
      graph
    )
  ),
  stringsAsFactors = FALSE
)

utils::write.csv(
  analytical_summary,
  file.path(
    results_root,
    "phase4_5_analytical_sheet_summary.csv"
  ),
  row.names = FALSE,
  na = ""
)

utils::write.csv(
  result$analytical_report_validation,
  file.path(
    results_root,
    "phase4_5_analytical_validation.csv"
  ),
  row.names = FALSE,
  na = ""
)

utils::write.csv(
  graph_summary,
  file.path(
    results_root,
    "phase4_5_graphml_summary.csv"
  ),
  row.names = FALSE,
  na = ""
)

cat(
  "\nPHASE 4.5 IMPLEMENTATION CHECKPOINT\n\n"
)

cat(
  "Analytical workbook:\n"
)

print(
  analytical_summary,
  row.names = FALSE
)

cat(
  "\nGraphML:\n"
)

print(
  graph_summary,
  row.names = FALSE
)

cat(
  "\nValidation checks:\n"
)

print(
  result$analytical_report_validation,
  row.names = FALSE
)

cat(
  "\nPHASE 4.5 IMPLEMENTATION CHECKPOINT: PASSED\n"
)
