#!/usr/bin/env Rscript

# Compare a seven-case run produced inside renv with the preserved
# pre-renv legacy baseline.
#
# This script compares only public, non-patient-specific regression
# metadata and the strict deterministic workbook core.
#
# Usage:
# Rscript scripts/compare_renv_to_legacy.R \
#   ../results/legacy_baseline_2026-07-15 \
#   ../results/renv_phase1_full

if (!requireNamespace("openxlsx", quietly = TRUE)) {
  stop("Package 'openxlsx' is required.", call. = FALSE)
}

if (!requireNamespace("renv", quietly = TRUE)) {
  stop("Package 'renv' is required.", call. = FALSE)
}

arguments <- commandArgs(trailingOnly = TRUE)

legacy_root <- if (length(arguments) >= 1L) {
  arguments[[1]]
} else {
  "../results/legacy_baseline_2026-07-15"
}

renv_root <- if (length(arguments) >= 2L) {
  arguments[[2]]
} else {
  "../results/renv_phase1_full"
}

for (path in c(legacy_root, renv_root)) {
  if (!dir.exists(path)) {
    stop("Output directory does not exist: ", path, call. = FALSE)
  }
}

if (!file.exists("renv.lock")) {
  stop("renv.lock was not found.", call. = FALSE)
}

scope_path <- file.path(
  "tests",
  "reference",
  "environment",
  "legacy_regression_scope.csv"
)

if (!file.exists(scope_path)) {
  stop("Legacy regression scope was not found.", call. = FALSE)
}

output_dir <- file.path(
  "tests",
  "reference",
  "environment"
)

dir.create(
  output_dir,
  recursive = TRUE,
  showWarnings = FALSE
)

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
  directory = c(
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

workbook_files <- c(
  analytical_report = "CancerPPIr_Analytical_Report.xlsx",
  technical_report = "CancerPPIr_Technical_Report.xlsx"
)

expected_files <- c(
  "CancerPPIr_Analytical_Report.xlsx",
  "CancerPPIr_Technical_Report.xlsx",
  "Network_for_Cytoscape.graphml",
  "STRING_links.txt"
)

regression_scope <- utils::read.csv(
  scope_path,
  stringsAsFactors = FALSE
)

strict_scope <- regression_scope[
  regression_scope$baseline_class == "strict_deterministic",
  c("workbook", "sheet_name"),
  drop = FALSE
]
# Session info is deterministic only within the same environment.
# Its exact content is expected to change after renv activation because
# library paths and environment metadata are different. The sheet itself
# and its column schema remain covered by the general schema checks.
strict_scope <- strict_scope[
  !(
    strict_scope$workbook == "technical_report" &
      strict_scope$sheet_name == "Session info"
  ),
  ,
  drop = FALSE
]
canonical_table_md5 <- function(data) {
  temporary_file <- tempfile(fileext = ".csv")

  on.exit(
    unlink(temporary_file),
    add = TRUE
  )

  utils::write.table(
    data,
    file = temporary_file,
    sep = ",",
    row.names = FALSE,
    col.names = TRUE,
    quote = TRUE,
    qmethod = "double",
    na = "",
    eol = "\n",
    fileEncoding = "UTF-8"
  )

  unname(tools::md5sum(temporary_file))
}

read_sheet_safely <- function(path, sheet) {
  tryCatch(
    list(
      data = openxlsx::read.xlsx(
        path,
        sheet = sheet,
        detectDates = FALSE,
        skipEmptyRows = FALSE,
        skipEmptyCols = FALSE
      ),
      error = NA_character_
    ),
    error = function(error) {
      list(
        data = NULL,
        error = conditionMessage(error)
      )
    }
  )
}

normalized_text_md5 <- function(path) {
  if (!file.exists(path)) {
    return(NA_character_)
  }

  lines <- readLines(
    path,
    warn = FALSE,
    encoding = "UTF-8"
  )

  lines <- sort(sub("\r$", "", lines))

  temporary_file <- tempfile(fileext = ".txt")

  on.exit(
    unlink(temporary_file),
    add = TRUE
  )

  writeLines(
    lines,
    temporary_file,
    useBytes = TRUE
  )

  unname(tools::md5sum(temporary_file))
}

count_xml_tag <- function(path, tag) {
  if (!file.exists(path)) {
    return(NA_integer_)
  }

  lines <- readLines(
    path,
    warn = FALSE,
    encoding = "UTF-8"
  )

  matches <- gregexpr(
    paste0("<", tag, "\\b"),
    lines,
    perl = TRUE
  )

  sum(
    vapply(
      matches,
      function(positions) {
        sum(positions > 0L)
      },
      FUN.VALUE = integer(1)
    )
  )
}

parse_log <- function(path) {
  result <- data.frame(
    mapped_genes = NA_integer_,
    input_genes = NA_integer_,
    nodes = NA_integer_,
    edges = NA_integer_,
    components = NA_integer_,
    stringsAsFactors = FALSE
  )

  if (!file.exists(path)) {
    return(result)
  }

  lines <- readLines(
    path,
    warn = FALSE,
    encoding = "UTF-8"
  )

  mapped_line <- grep(
    "Mapped genes:",
    lines,
    value = TRUE,
    fixed = TRUE
  )

  if (length(mapped_line) > 0L) {
    values <- regmatches(
      tail(mapped_line, 1L),
      regexec(
        "Mapped genes: ([0-9]+)/([0-9]+)",
        tail(mapped_line, 1L)
      )
    )[[1]]

    if (length(values) == 3L) {
      result$mapped_genes <- as.integer(values[[2]])
      result$input_genes <- as.integer(values[[3]])
    }
  }

  network_line <- grep(
    "Network:",
    lines,
    value = TRUE,
    fixed = TRUE
  )

  if (length(network_line) > 0L) {
    values <- regmatches(
      tail(network_line, 1L),
      regexec(
        paste0(
          "Network: ([0-9]+) nodes, ",
          "([0-9]+) edges, ([0-9]+) components"
        ),
        tail(network_line, 1L)
      )
    )[[1]]

    if (length(values) == 4L) {
      result$nodes <- as.integer(values[[2]])
      result$edges <- as.integer(values[[3]])
      result$components <- as.integer(values[[4]])
    }
  }

  result
}

strict_rows <- list()
schema_rows <- list()
artifact_rows <- list()
summary_rows <- list()

strict_index <- 1L
schema_index <- 1L
artifact_index <- 1L

renv_status_path <- file.path(
  renv_root,
  "run_status.csv"
)

renv_status <- utils::read.csv(
  renv_status_path,
  stringsAsFactors = FALSE
)

for (case_index in seq_len(nrow(case_table))) {
  case_id <- case_table$case_id[[case_index]]
  directory <- case_table$directory[[case_index]]

  legacy_case <- file.path(legacy_root, directory)
  renv_case <- file.path(renv_root, directory)

  message("[compare renv] Processing ", case_id, ".")

  expected_legacy <- file.path(
    legacy_case,
    expected_files
  )

  expected_renv <- file.path(
    renv_case,
    expected_files
  )

  all_expected_files_exist <- all(
    file.exists(expected_legacy) &
      file.exists(expected_renv)
  )

  legacy_links <- file.path(
    legacy_case,
    "STRING_links.txt"
  )

  renv_links <- file.path(
    renv_case,
    "STRING_links.txt"
  )

  string_links_identical <- identical(
    normalized_text_md5(legacy_links),
    normalized_text_md5(renv_links)
  )

  legacy_graph <- file.path(
    legacy_case,
    "Network_for_Cytoscape.graphml"
  )

  renv_graph <- file.path(
    renv_case,
    "Network_for_Cytoscape.graphml"
  )

  legacy_xml_nodes <- count_xml_tag(
    legacy_graph,
    "node"
  )

  renv_xml_nodes <- count_xml_tag(
    renv_graph,
    "node"
  )

  legacy_xml_edges <- count_xml_tag(
    legacy_graph,
    "edge"
  )

  renv_xml_edges <- count_xml_tag(
    renv_graph,
    "edge"
  )

  graph_counts_identical <- identical(
    c(legacy_xml_nodes, legacy_xml_edges),
    c(renv_xml_nodes, renv_xml_edges)
  )

  workbook_sheet_names_identical <- TRUE
  all_sheet_columns_identical <- TRUE

  for (workbook_name in names(workbook_files)) {
    file_name <- workbook_files[[workbook_name]]

    legacy_workbook <- file.path(
      legacy_case,
      file_name
    )

    renv_workbook <- file.path(
      renv_case,
      file_name
    )

    legacy_sheets <- openxlsx::getSheetNames(
      legacy_workbook
    )

    renv_sheets <- openxlsx::getSheetNames(
      renv_workbook
    )

    workbook_sheet_names_identical <-
      workbook_sheet_names_identical &&
      identical(legacy_sheets, renv_sheets)

    all_sheets <- union(
      legacy_sheets,
      renv_sheets
    )

    for (sheet_name in all_sheets) {
      legacy_exists <- sheet_name %in% legacy_sheets
      renv_exists <- sheet_name %in% renv_sheets

      legacy_result <- if (legacy_exists) {
        read_sheet_safely(
          legacy_workbook,
          sheet_name
        )
      } else {
        list(
          data = NULL,
          error = "Missing sheet."
        )
      }

      renv_result <- if (renv_exists) {
        read_sheet_safely(
          renv_workbook,
          sheet_name
        )
      } else {
        list(
          data = NULL,
          error = "Missing sheet."
        )
      }

      same_column_names <- isTRUE(
        !is.null(legacy_result$data) &&
          !is.null(renv_result$data) &&
          identical(
            names(legacy_result$data),
            names(renv_result$data)
          )
      )

      all_sheet_columns_identical <-
        all_sheet_columns_identical &&
        same_column_names

      schema_rows[[schema_index]] <- data.frame(
        case_id = case_id,
        workbook = workbook_name,
        sheet_name = sheet_name,
        legacy_exists = legacy_exists,
        renv_exists = renv_exists,
        legacy_columns = if (
          is.null(legacy_result$data)
        ) {
          NA_integer_
        } else {
          ncol(legacy_result$data)
        },
        renv_columns = if (
          is.null(renv_result$data)
        ) {
          NA_integer_
        } else {
          ncol(renv_result$data)
        },
        same_column_names = same_column_names,
        legacy_read_error = legacy_result$error,
        renv_read_error = renv_result$error,
        stringsAsFactors = FALSE
      )

      schema_index <- schema_index + 1L
    }
  }

  for (strict_index_case in seq_len(nrow(strict_scope))) {
    workbook_name <- strict_scope$workbook[
      strict_index_case
    ]

    sheet_name <- strict_scope$sheet_name[
      strict_index_case
    ]

    file_name <- workbook_files[[workbook_name]]

    legacy_workbook <- file.path(
      legacy_case,
      file_name
    )

    renv_workbook <- file.path(
      renv_case,
      file_name
    )

    legacy_result <- read_sheet_safely(
      legacy_workbook,
      sheet_name
    )

    renv_result <- read_sheet_safely(
      renv_workbook,
      sheet_name
    )

    legacy_md5 <- if (
      is.null(legacy_result$data)
    ) {
      NA_character_
    } else {
      canonical_table_md5(
        legacy_result$data
      )
    }

    renv_md5 <- if (
      is.null(renv_result$data)
    ) {
      NA_character_
    } else {
      canonical_table_md5(
        renv_result$data
      )
    }

    identical_content <- isTRUE(
      !is.na(legacy_md5) &&
        !is.na(renv_md5) &&
        identical(legacy_md5, renv_md5)
    )

    strict_rows[[strict_index]] <- data.frame(
      case_id = case_id,
      workbook = workbook_name,
      sheet_name = sheet_name,
      legacy_rows = if (
        is.null(legacy_result$data)
      ) {
        NA_integer_
      } else {
        nrow(legacy_result$data)
      },
      renv_rows = if (
        is.null(renv_result$data)
      ) {
        NA_integer_
      } else {
        nrow(renv_result$data)
      },
      legacy_columns = if (
        is.null(legacy_result$data)
      ) {
        NA_integer_
      } else {
        ncol(legacy_result$data)
      },
      renv_columns = if (
        is.null(renv_result$data)
      ) {
        NA_integer_
      } else {
        ncol(renv_result$data)
      },
      legacy_md5 = legacy_md5,
      renv_md5 = renv_md5,
      identical_content = identical_content,
      legacy_read_error = legacy_result$error,
      renv_read_error = renv_result$error,
      stringsAsFactors = FALSE
    )

    strict_index <- strict_index + 1L
  }

  legacy_log <- parse_log(
    file.path(
      legacy_root,
      "logs",
      paste0(case_id, ".log")
    )
  )

  renv_log <- parse_log(
    file.path(
      renv_root,
      "logs",
      paste0(case_id, ".log")
    )
  )

  log_summary_identical <- identical(
    unname(unlist(legacy_log)),
    unname(unlist(renv_log))
  )

  case_status <- renv_status[
    renv_status$case_id == case_id,
    ,
    drop = FALSE
  ]

  renv_run_completed <- (
    nrow(case_status) == 1L &&
      case_status$exit_code[[1]] == 0L &&
      isTRUE(case_status$outputs_complete[[1]]) &&
      identical(
        case_status$status[[1]],
        "completed"
      )
  )

  case_strict_rows <- strict_rows[
    vapply(
      strict_rows,
      function(row) {
        identical(row$case_id[[1]], case_id)
      },
      FUN.VALUE = logical(1)
    )
  ]

  case_strict_data <- do.call(
    rbind,
    case_strict_rows
  )

  strict_sheets_identical <- (
    nrow(case_strict_data) ==
      nrow(strict_scope) &&
      all(case_strict_data$identical_content)
  )

  strict_regression_core_match <- all(
    renv_run_completed,
    all_expected_files_exist,
    string_links_identical,
    graph_counts_identical,
    workbook_sheet_names_identical,
    all_sheet_columns_identical,
    strict_sheets_identical,
    log_summary_identical
  )

  summary_rows[[case_index]] <- data.frame(
    case_id = case_id,
    renv_run_completed = renv_run_completed,
    all_expected_files_exist =
      all_expected_files_exist,
    string_links_identical =
      string_links_identical,
    graph_node_edge_counts_identical =
      graph_counts_identical,
    workbook_sheet_names_identical =
      workbook_sheet_names_identical,
    all_sheet_columns_identical =
      all_sheet_columns_identical,
    strict_sheets_compared =
      nrow(case_strict_data),
    strict_sheets_identical =
      sum(case_strict_data$identical_content),
    log_summary_identical =
      log_summary_identical,
    strict_regression_core_match =
      strict_regression_core_match,
    stringsAsFactors = FALSE
  )

  artifact_rows[[artifact_index]] <- data.frame(
    case_id = case_id,
    legacy_xml_nodes = legacy_xml_nodes,
    renv_xml_nodes = renv_xml_nodes,
    legacy_xml_edges = legacy_xml_edges,
    renv_xml_edges = renv_xml_edges,
    graph_node_edge_counts_identical =
      graph_counts_identical,
    string_links_identical =
      string_links_identical,
    stringsAsFactors = FALSE
  )

  artifact_index <- artifact_index + 1L
}

strict_comparison <- do.call(
  rbind,
  strict_rows
)

schema_comparison <- do.call(
  rbind,
  schema_rows
)

artifact_comparison <- do.call(
  rbind,
  artifact_rows
)

case_summary <- do.call(
  rbind,
  summary_rows
)

utils::write.csv(
  strict_comparison,
  file.path(
    output_dir,
    "phase1_renv_strict_sheet_comparison.csv"
  ),
  row.names = FALSE,
  na = ""
)

utils::write.csv(
  schema_comparison,
  file.path(
    output_dir,
    "phase1_renv_schema_comparison.csv"
  ),
  row.names = FALSE,
  na = ""
)

utils::write.csv(
  artifact_comparison,
  file.path(
    output_dir,
    "phase1_renv_artifact_comparison.csv"
  ),
  row.names = FALSE,
  na = ""
)

utils::write.csv(
  case_summary,
  file.path(
    output_dir,
    "phase1_renv_case_summary.csv"
  ),
  row.names = FALSE,
  na = ""
)

lockfile <- renv::lockfile_read(
  "renv.lock"
)

package_names <- c(
  "BiocVersion",
  "STRINGdb",
  "HGNChelper",
  "igraph",
  "openxlsx",
  "dplyr",
  "tibble",
  "curl",
  "sna",
  "gprofiler2",
  "renv"
)

package_manifest <- do.call(
  rbind,
  lapply(
    package_names,
    function(package_name) {
      record <- lockfile$Packages[[package_name]]

      data.frame(
        package = package_name,
        version = if (is.null(record)) {
          NA_character_
        } else {
          record$Version
        },
        source = if (is.null(record)) {
          NA_character_
        } else {
          record$Source
        },
        stringsAsFactors = FALSE
      )
    }
  )
)

utils::write.csv(
  package_manifest,
  file.path(
    output_dir,
    "phase1_renv_package_manifest.csv"
  ),
  row.names = FALSE,
  na = ""
)

writeLines(
  c(
    paste0("R=", R.version.string),
    paste0(
      "Bioconductor=",
      renv::settings$bioconductor.version()
    ),
    paste0(
      "renv=",
      as.character(packageVersion("renv"))
    ),
    paste0(
      "renv_lock_md5=",
      unname(tools::md5sum("renv.lock"))
    )
  ),
  file.path(
    output_dir,
    "phase1_renv_environment.txt"
  ),
  useBytes = TRUE
)

if (!all(case_summary$strict_regression_core_match)) {
  print(case_summary, row.names = FALSE)

  stop(
    "The renv run does not match the strict legacy regression core.",
    call. = FALSE
  )
}

message(
  "[compare renv] All seven cases match the strict legacy regression core."
)