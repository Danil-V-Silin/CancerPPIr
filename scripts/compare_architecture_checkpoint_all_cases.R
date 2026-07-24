#!/usr/bin/env Rscript

# Compare all seven CancerPPIr reference cases against a preserved baseline
# by reusing compare_architecture_checkpoint_case.R.
#
# Usage:
#   Rscript scripts/compare_architecture_checkpoint_all_cases.R \
#     <baseline_root> <candidate_root> <checkpoint_prefix>
#
# Example:
#   Rscript scripts/compare_architecture_checkpoint_all_cases.R \
#     ../results/renv_phase1_full \
#     ../results/phase2_string_mapping_full \
#     checkpoint_2_6_string_mapping

arguments <- commandArgs(
  trailingOnly = TRUE
)

if (length(arguments) != 3L) {
  stop(
    paste0(
      "Expected three arguments:\n",
      "1. baseline result root\n",
      "2. candidate result root\n",
      "3. checkpoint prefix"
    ),
    call. = FALSE
  )
}

baseline_root <- normalizePath(
  arguments[[1L]],
  winslash = "/",
  mustWork = TRUE
)

candidate_root <- normalizePath(
  arguments[[2L]],
  winslash = "/",
  mustWork = TRUE
)

checkpoint_prefix <- arguments[[3L]]

safe_checkpoint_prefix <- gsub(
  "[^A-Za-z0-9_.-]+",
  "_",
  checkpoint_prefix
)

comparison_script <- file.path(
  "scripts",
  "compare_architecture_checkpoint_case.R"
)

if (!file.exists(comparison_script)) {
  stop(
    paste0(
      "Comparison script was not found: ",
      comparison_script
    ),
    call. = FALSE
  )
}

case_table <- data.frame(
  case_id = c(
    "A01",
    "K01",
    "L01",
    "M01",
    "P01",
    "P02",
    "R01"
  ),
  case_directory = c(
    "Genes_A",
    "Genes_K",
    "Genes_L",
    "Genes_M",
    "Genes_P01",
    "Genes_P02",
    "Genes_R"
  ),
  stringsAsFactors = FALSE
)

output_directory <- file.path(
  "docs",
  "architecture"
)

dir.create(
  output_directory,
  recursive = TRUE,
  showWarnings = FALSE
)

aggregate_base <- file.path(
  output_directory,
  paste0(
    safe_checkpoint_prefix,
    "_all_cases"
  )
)

aggregate_summary_path <- paste0(
  aggregate_base,
  "_summary.csv"
)

aggregate_strict_path <- paste0(
  aggregate_base,
  "_strict_sheets.csv"
)

aggregate_schema_path <- paste0(
  aggregate_base,
  "_schema.csv"
)

aggregate_paths <- c(
  aggregate_summary_path,
  aggregate_strict_path,
  aggregate_schema_path
)

existing_aggregate_paths <- aggregate_paths[
  file.exists(aggregate_paths)
]

if (length(existing_aggregate_paths) > 0L) {
  stop(
    paste0(
      "Aggregate comparison files already exist:\n",
      paste(
        paste0("- ", existing_aggregate_paths),
        collapse = "\n"
      )
    ),
    call. = FALSE
  )
}

rscript_binary <- file.path(
  R.home("bin"),
  if (.Platform$OS.type == "windows") {
    "Rscript.exe"
  } else {
    "Rscript"
  }
)

summary_rows <- list()
strict_rows <- list()
schema_rows <- list()

for (case_index in seq_len(nrow(case_table))) {
  case_id <- case_table$case_id[[case_index]]
  case_directory <- case_table$case_directory[[case_index]]

  temporary_checkpoint <- paste0(
    safe_checkpoint_prefix,
    "_temporary_",
    case_id
  )

  temporary_base <- file.path(
    output_directory,
    temporary_checkpoint
  )

  temporary_summary_path <- paste0(
    temporary_base,
    "_summary.csv"
  )

  temporary_strict_path <- paste0(
    temporary_base,
    "_strict_sheets.csv"
  )

  temporary_schema_path <- paste0(
    temporary_base,
    "_schema.csv"
  )

  temporary_paths <- c(
    temporary_summary_path,
    temporary_strict_path,
    temporary_schema_path
  )

  stale_temporary_paths <- temporary_paths[
    file.exists(temporary_paths)
  ]

  if (length(stale_temporary_paths) > 0L) {
    stop(
      paste0(
        "Temporary files from an earlier comparison already exist:\n",
        paste(
          paste0("- ", stale_temporary_paths),
          collapse = "\n"
        ),
        "\nDelete or inspect them before rerunning."
      ),
      call. = FALSE
    )
  }

  message("")
  message(
    paste(
      rep("=", 68L),
      collapse = ""
    )
  )

  message(
    "[all-case comparison] Comparing ",
    case_id
  )

  message(
    paste(
      rep("=", 68L),
      collapse = ""
    )
  )

  command_arguments <- c(
    comparison_script,
    baseline_root,
    candidate_root,
    case_id,
    case_directory,
    temporary_checkpoint
  )

  exit_code <- system2(
    command = rscript_binary,
    args = vapply(
      command_arguments,
      shQuote,
      FUN.VALUE = character(1)
    ),
    stdout = "",
    stderr = ""
  )

  if (!identical(exit_code, 0L)) {
    stop(
      paste0(
        "Comparison failed for ",
        case_id,
        " with exit code ",
        exit_code,
        "."
      ),
      call. = FALSE
    )
  }

  missing_temporary_paths <- temporary_paths[
    !file.exists(temporary_paths)
  ]

  if (length(missing_temporary_paths) > 0L) {
    stop(
      paste0(
        "Comparison output files are missing for ",
        case_id,
        ":\n",
        paste(
          paste0("- ", missing_temporary_paths),
          collapse = "\n"
        )
      ),
      call. = FALSE
    )
  }

  case_summary <- utils::read.csv(
    temporary_summary_path,
    stringsAsFactors = FALSE,
    check.names = FALSE
  )

  case_strict <- utils::read.csv(
    temporary_strict_path,
    stringsAsFactors = FALSE,
    check.names = FALSE
  )

  case_schema <- utils::read.csv(
    temporary_schema_path,
    stringsAsFactors = FALSE,
    check.names = FALSE
  )

  if (
    nrow(case_summary) != 1L ||
      !identical(
        case_summary$case_id,
        case_id
      )
  ) {
    stop(
      paste0(
        "Unexpected summary content for ",
        case_id,
        "."
      ),
      call. = FALSE
    )
  }

  case_summary$checkpoint <- checkpoint_prefix

  summary_rows[[case_index]] <- case_summary
  strict_rows[[case_index]] <- case_strict
  schema_rows[[case_index]] <- case_schema

  unlink(
    temporary_paths,
    force = TRUE
  )

  message(
    "[all-case comparison] ",
    case_id,
    ": passed."
  )
}

aggregate_summary <- do.call(
  rbind,
  summary_rows
)

aggregate_strict <- do.call(
  rbind,
  strict_rows
)

aggregate_schema <- do.call(
  rbind,
  schema_rows
)

expected_case_order <- case_table$case_id

if (!identical(
  aggregate_summary$case_id,
  expected_case_order
)) {
  stop(
    "The aggregate case order is unexpected.",
    call. = FALSE
  )
}

required_summary_columns <- c(
  "candidate_completed",
  "candidate_error_free",
  "all_expected_files_exist",
  "string_links_identical",
  "graph_node_edge_counts_identical",
  "workbook_sheet_names_identical",
  "all_sheet_columns_identical",
  "strict_sheets_compared",
  "strict_sheets_identical",
  "log_summary_identical",
  "strict_regression_core_match"
)

missing_summary_columns <- setdiff(
  required_summary_columns,
  names(aggregate_summary)
)

if (length(missing_summary_columns) > 0L) {
  stop(
    paste0(
      "Aggregate summary is missing columns: ",
      paste(
        missing_summary_columns,
        collapse = ", "
      )
    ),
    call. = FALSE
  )
}

all_cases_passed <- all(
  aggregate_summary$candidate_completed,
  aggregate_summary$candidate_error_free,
  aggregate_summary$all_expected_files_exist,
  aggregate_summary$string_links_identical,
  aggregate_summary$graph_node_edge_counts_identical,
  aggregate_summary$workbook_sheet_names_identical,
  aggregate_summary$all_sheet_columns_identical,
  aggregate_summary$log_summary_identical,
  aggregate_summary$strict_regression_core_match
)

total_strict_sheets <- sum(
  aggregate_summary$strict_sheets_compared
)

total_identical_strict_sheets <- sum(
  aggregate_summary$strict_sheets_identical
)

strict_totals_passed <- identical(
  total_identical_strict_sheets,
  total_strict_sheets
)

if (
  nrow(aggregate_summary) != 7L ||
    !all_cases_passed ||
    !strict_totals_passed
) {
  stop(
    paste0(
      "The aggregate seven-case regression comparison failed.\n",
      "Cases passed: ",
      sum(
        aggregate_summary$strict_regression_core_match
      ),
      "/7\n",
      "Strict sheets identical: ",
      total_identical_strict_sheets,
      "/",
      total_strict_sheets
    ),
    call. = FALSE
  )
}

utils::write.csv(
  aggregate_summary,
  aggregate_summary_path,
  row.names = FALSE,
  na = ""
)

utils::write.csv(
  aggregate_strict,
  aggregate_strict_path,
  row.names = FALSE,
  na = ""
)

utils::write.csv(
  aggregate_schema,
  aggregate_schema_path,
  row.names = FALSE,
  na = ""
)

message("")
message(
  paste(
    rep("=", 68L),
    collapse = ""
  )
)

message(
  "[all-case comparison] ALL SEVEN CASES PASSED."
)

message(
  "[all-case comparison] Cases: 7/7."
)

message(
  "[all-case comparison] Strict sheets identical: ",
  total_identical_strict_sheets,
  "/",
  total_strict_sheets,
  "."
)

message(
  "[all-case comparison] Summary: ",
  aggregate_summary_path
)

message(
  "[all-case comparison] Strict sheets: ",
  aggregate_strict_path
)

message(
  "[all-case comparison] Schema: ",
  aggregate_schema_path
)

message(
  paste(
    rep("=", 68L),
    collapse = ""
  )
)