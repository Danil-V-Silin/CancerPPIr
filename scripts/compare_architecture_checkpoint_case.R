#!/usr/bin/env Rscript

# Compare one CancerPPIr architecture checkpoint against a preserved
# pre-refactor run produced in the same renv environment.
#
# Usage:
#   Rscript scripts/compare_architecture_checkpoint_case.R \
#     <baseline_root> <candidate_root> <case_id> <case_directory> <checkpoint>
#
# Example:
#   Rscript scripts/compare_architecture_checkpoint_case.R \
#     ../results/renv_phase1_full \
#     ../results/phase2_utils_pilot_R01 \
#     R01 \
#     Genes_R \
#     checkpoint_2_4_utils_R01

if (!requireNamespace("openxlsx", quietly = TRUE)) {
  stop(
    "Package 'openxlsx' is required.",
    call. = FALSE
  )
}

arguments <- commandArgs(
  trailingOnly = TRUE
)

if (length(arguments) != 5L) {
  stop(
    paste0(
      "Expected five arguments:\n",
      "1. baseline root\n",
      "2. candidate root\n",
      "3. case ID\n",
      "4. case output directory\n",
      "5. checkpoint identifier"
    ),
    call. = FALSE
  )
}

baseline_root <- arguments[[1L]]
candidate_root <- arguments[[2L]]
case_id <- arguments[[3L]]
case_directory <- arguments[[4L]]
checkpoint_id <- arguments[[5L]]

safe_checkpoint_id <- gsub(
  "[^A-Za-z0-9_.-]+",
  "_",
  checkpoint_id
)

output_directory <- file.path(
  "docs",
  "architecture"
)

scope_path <- file.path(
  "tests",
  "reference",
  "environment",
  "legacy_regression_scope.csv"
)

required_directories <- c(
  baseline_root,
  candidate_root
)

missing_directories <- required_directories[
  !dir.exists(required_directories)
]

if (length(missing_directories) > 0L) {
  stop(
    paste0(
      "Required result directories are missing:\n",
      paste(
        paste0("- ", missing_directories),
        collapse = "\n"
      )
    ),
    call. = FALSE
  )
}

if (!file.exists(scope_path)) {
  stop(
    paste0(
      "Regression scope file was not found: ",
      scope_path
    ),
    call. = FALSE
  )
}

dir.create(
  output_directory,
  recursive = TRUE,
  showWarnings = FALSE
)

baseline_case <- file.path(
  baseline_root,
  case_directory
)

candidate_case <- file.path(
  candidate_root,
  case_directory
)

if (!dir.exists(baseline_case)) {
  stop(
    "Baseline case directory does not exist: ",
    baseline_case,
    call. = FALSE
  )
}

if (!dir.exists(candidate_case)) {
  stop(
    "Candidate case directory does not exist: ",
    candidate_case,
    call. = FALSE
  )
}

workbook_files <- c(
  analytical_report =
    "CancerPPIr_Analytical_Report.xlsx",
  technical_report =
    "CancerPPIr_Technical_Report.xlsx"
)

expected_files <- c(
  "CancerPPIr_Analytical_Report.xlsx",
  "CancerPPIr_Technical_Report.xlsx",
  "Network_for_Cytoscape.graphml",
  "STRING_links.txt"
)

regression_scope <- utils::read.csv(
  scope_path,
  stringsAsFactors = FALSE,
  check.names = FALSE
)

required_scope_columns <- c(
  "workbook",
  "sheet_name",
  "baseline_class"
)

missing_scope_columns <- setdiff(
  required_scope_columns,
  names(regression_scope)
)

if (length(missing_scope_columns) > 0L) {
  stop(
    paste0(
      "Regression scope is missing columns: ",
      paste(
        missing_scope_columns,
        collapse = ", "
      )
    ),
    call. = FALSE
  )
}

strict_scope <- regression_scope[
  regression_scope$baseline_class ==
    "strict_deterministic",
  c(
    "workbook",
    "sheet_name"
  ),
  drop = FALSE
]

if (nrow(strict_scope) == 0L) {
  stop(
    "No strict deterministic sheets were found.",
    call. = FALSE
  )
}

unknown_workbooks <- setdiff(
  unique(strict_scope$workbook),
  names(workbook_files)
)

if (length(unknown_workbooks) > 0L) {
  stop(
    paste0(
      "Unknown workbook identifiers in regression scope: ",
      paste(
        unknown_workbooks,
        collapse = ", "
      )
    ),
    call. = FALSE
  )
}

canonical_table_md5 <- function(data) {
  temporary_file <- tempfile(
    fileext = ".csv"
  )

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

  unname(
    tools::md5sum(temporary_file)
  )
}

file_md5 <- function(path) {
  if (!file.exists(path)) {
    return(NA_character_)
  }

  unname(
    tools::md5sum(path)
  )
}

read_sheet_safely <- function(
  workbook_path,
  sheet_name
) {
  tryCatch(
    list(
      data = openxlsx::read.xlsx(
        workbook_path,
        sheet = sheet_name,
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

count_xml_tag <- function(
  path,
  tag_name
) {
  if (!file.exists(path)) {
    return(NA_integer_)
  }

  lines <- readLines(
    path,
    warn = FALSE,
    encoding = "UTF-8"
  )

  matches <- gregexpr(
    paste0(
      "<",
      tag_name,
      "\\b"
    ),
    lines,
    perl = TRUE
  )

  as.integer(
    sum(
      vapply(
        matches,
        function(positions) {
          sum(positions > 0L)
        },
        FUN.VALUE = numeric(1)
      )
    )
  )
}

parse_log_summary <- function(path) {
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

  mapped_lines <- grep(
    "Mapped genes:",
    lines,
    value = TRUE,
    fixed = TRUE
  )

  if (length(mapped_lines) > 0L) {
    mapped_line <- tail(
      mapped_lines,
      1L
    )

    values <- regmatches(
      mapped_line,
      regexec(
        "Mapped genes: ([0-9]+)/([0-9]+)",
        mapped_line
      )
    )[[1L]]

    if (length(values) == 3L) {
      result$mapped_genes <- as.integer(
        values[[2L]]
      )

      result$input_genes <- as.integer(
        values[[3L]]
      )
    }
  }

  network_lines <- grep(
    "Network:",
    lines,
    value = TRUE,
    fixed = TRUE
  )

  if (length(network_lines) > 0L) {
    network_line <- tail(
      network_lines,
      1L
    )

    values <- regmatches(
      network_line,
      regexec(
        paste0(
          "Network: ([0-9]+) nodes, ",
          "([0-9]+) edges, ",
          "([0-9]+) components"
        ),
        network_line
      )
    )[[1L]]

    if (length(values) == 4L) {
      result$nodes <- as.integer(
        values[[2L]]
      )

      result$edges <- as.integer(
        values[[3L]]
      )

      result$components <- as.integer(
        values[[4L]]
      )
    }
  }

  result
}

log_completed <- function(path) {
  if (!file.exists(path)) {
    return(FALSE)
  }

  lines <- readLines(
    path,
    warn = FALSE,
    encoding = "UTF-8"
  )

  any(
    grepl(
      "[CancerPPIr] Done.",
      lines,
      fixed = TRUE
    )
  )
}

log_contains_error <- function(path) {
  if (!file.exists(path)) {
    return(TRUE)
  }

  lines <- readLines(
    path,
    warn = FALSE,
    encoding = "UTF-8"
  )

  any(
    grepl(
      "error|execution halted|failed",
      lines,
      ignore.case = TRUE,
      perl = TRUE
    )
  )
}

baseline_expected_paths <- file.path(
  baseline_case,
  expected_files
)

candidate_expected_paths <- file.path(
  candidate_case,
  expected_files
)

all_expected_files_exist <- all(
  file.exists(baseline_expected_paths)
) &&
  all(
    file.exists(candidate_expected_paths)
  )

baseline_links <- file.path(
  baseline_case,
  "STRING_links.txt"
)

candidate_links <- file.path(
  candidate_case,
  "STRING_links.txt"
)

string_links_identical <- isTRUE(
  !is.na(file_md5(baseline_links)) &&
    identical(
      file_md5(baseline_links),
      file_md5(candidate_links)
    )
)

baseline_graph <- file.path(
  baseline_case,
  "Network_for_Cytoscape.graphml"
)

candidate_graph <- file.path(
  candidate_case,
  "Network_for_Cytoscape.graphml"
)

baseline_graph_nodes <- count_xml_tag(
  baseline_graph,
  "node"
)

candidate_graph_nodes <- count_xml_tag(
  candidate_graph,
  "node"
)

baseline_graph_edges <- count_xml_tag(
  baseline_graph,
  "edge"
)

candidate_graph_edges <- count_xml_tag(
  candidate_graph,
  "edge"
)

graph_counts_identical <- isTRUE(
  identical(
    c(
      baseline_graph_nodes,
      baseline_graph_edges
    ),
    c(
      candidate_graph_nodes,
      candidate_graph_edges
    )
  )
)

schema_rows <- list()
schema_index <- 1L

workbook_sheet_names_identical <- TRUE
all_sheet_columns_identical <- TRUE

for (workbook_name in names(workbook_files)) {
  workbook_file <- workbook_files[[
    workbook_name
  ]]

  baseline_workbook <- file.path(
    baseline_case,
    workbook_file
  )

  candidate_workbook <- file.path(
    candidate_case,
    workbook_file
  )

  baseline_sheets <- openxlsx::getSheetNames(
    baseline_workbook
  )

  candidate_sheets <- openxlsx::getSheetNames(
    candidate_workbook
  )

  workbook_sheet_names_identical <-
    workbook_sheet_names_identical &&
    identical(
      baseline_sheets,
      candidate_sheets
    )

  all_sheets <- union(
    baseline_sheets,
    candidate_sheets
  )

  for (sheet_name in all_sheets) {
    baseline_exists <-
      sheet_name %in% baseline_sheets

    candidate_exists <-
      sheet_name %in% candidate_sheets

    baseline_result <- if (baseline_exists) {
      read_sheet_safely(
        baseline_workbook,
        sheet_name
      )
    } else {
      list(
        data = NULL,
        error = "Missing sheet."
      )
    }

    candidate_result <- if (candidate_exists) {
      read_sheet_safely(
        candidate_workbook,
        sheet_name
      )
    } else {
      list(
        data = NULL,
        error = "Missing sheet."
      )
    }

    same_column_names <- isTRUE(
      !is.null(baseline_result$data) &&
        !is.null(candidate_result$data) &&
        identical(
          names(baseline_result$data),
          names(candidate_result$data)
        )
    )

    all_sheet_columns_identical <-
      all_sheet_columns_identical &&
      same_column_names

    schema_rows[[schema_index]] <- data.frame(
      case_id = case_id,
      workbook = workbook_name,
      sheet_name = sheet_name,
      baseline_exists = baseline_exists,
      candidate_exists = candidate_exists,
      baseline_rows = if (
        is.null(baseline_result$data)
      ) {
        NA_integer_
      } else {
        nrow(baseline_result$data)
      },
      candidate_rows = if (
        is.null(candidate_result$data)
      ) {
        NA_integer_
      } else {
        nrow(candidate_result$data)
      },
      baseline_columns = if (
        is.null(baseline_result$data)
      ) {
        NA_integer_
      } else {
        ncol(baseline_result$data)
      },
      candidate_columns = if (
        is.null(candidate_result$data)
      ) {
        NA_integer_
      } else {
        ncol(candidate_result$data)
      },
      same_column_names = same_column_names,
      baseline_read_error =
        baseline_result$error,
      candidate_read_error =
        candidate_result$error,
      stringsAsFactors = FALSE
    )

    schema_index <- schema_index + 1L
  }
}

schema_comparison <- do.call(
  rbind,
  schema_rows
)

strict_rows <- list()

for (strict_index in seq_len(nrow(strict_scope))) {
  workbook_name <- strict_scope$workbook[[
    strict_index
  ]]

  sheet_name <- strict_scope$sheet_name[[
    strict_index
  ]]

  workbook_file <- workbook_files[[
    workbook_name
  ]]

  baseline_workbook <- file.path(
    baseline_case,
    workbook_file
  )

  candidate_workbook <- file.path(
    candidate_case,
    workbook_file
  )

  baseline_result <- read_sheet_safely(
    baseline_workbook,
    sheet_name
  )

  candidate_result <- read_sheet_safely(
    candidate_workbook,
    sheet_name
  )

  baseline_md5 <- if (
    is.null(baseline_result$data)
  ) {
    NA_character_
  } else {
    canonical_table_md5(
      baseline_result$data
    )
  }

  candidate_md5 <- if (
    is.null(candidate_result$data)
  ) {
    NA_character_
  } else {
    canonical_table_md5(
      candidate_result$data
    )
  }

  identical_content <- isTRUE(
    !is.na(baseline_md5) &&
      !is.na(candidate_md5) &&
      identical(
        baseline_md5,
        candidate_md5
      )
  )

  strict_rows[[strict_index]] <- data.frame(
    case_id = case_id,
    workbook = workbook_name,
    sheet_name = sheet_name,
    baseline_rows = if (
      is.null(baseline_result$data)
    ) {
      NA_integer_
    } else {
      nrow(baseline_result$data)
    },
    candidate_rows = if (
      is.null(candidate_result$data)
    ) {
      NA_integer_
    } else {
      nrow(candidate_result$data)
    },
    baseline_columns = if (
      is.null(baseline_result$data)
    ) {
      NA_integer_
    } else {
      ncol(baseline_result$data)
    },
    candidate_columns = if (
      is.null(candidate_result$data)
    ) {
      NA_integer_
    } else {
      ncol(candidate_result$data)
    },
    baseline_md5 = baseline_md5,
    candidate_md5 = candidate_md5,
    identical_content = identical_content,
    baseline_read_error =
      baseline_result$error,
    candidate_read_error =
      candidate_result$error,
    stringsAsFactors = FALSE
  )
}

strict_comparison <- do.call(
  rbind,
  strict_rows
)

baseline_log <- file.path(
  baseline_root,
  "logs",
  paste0(
    case_id,
    ".log"
  )
)

candidate_log <- file.path(
  candidate_root,
  "logs",
  paste0(
    case_id,
    ".log"
  )
)

baseline_log_summary <- parse_log_summary(
  baseline_log
)

candidate_log_summary <- parse_log_summary(
  candidate_log
)

log_summary_identical <- isTRUE(
  identical(
    unname(
      unlist(
        baseline_log_summary
      )
    ),
    unname(
      unlist(
        candidate_log_summary
      )
    )
  )
)

baseline_completed <- log_completed(
  baseline_log
)

candidate_completed <- log_completed(
  candidate_log
)

candidate_error_free <- !log_contains_error(
  candidate_log
)

strict_sheets_compared <- nrow(
  strict_comparison
)

strict_sheets_identical <- sum(
  strict_comparison$identical_content
)

strict_regression_core_match <- all(
  baseline_completed,
  candidate_completed,
  candidate_error_free,
  all_expected_files_exist,
  string_links_identical,
  graph_counts_identical,
  workbook_sheet_names_identical,
  all_sheet_columns_identical,
  strict_sheets_compared == nrow(strict_scope),
  strict_sheets_identical ==
    strict_sheets_compared,
  log_summary_identical
)

summary_table <- data.frame(
  checkpoint = checkpoint_id,
  case_id = case_id,
  baseline_completed = baseline_completed,
  candidate_completed = candidate_completed,
  candidate_error_free = candidate_error_free,
  all_expected_files_exist =
    all_expected_files_exist,
  string_links_identical =
    string_links_identical,
  baseline_graph_nodes =
    baseline_graph_nodes,
  candidate_graph_nodes =
    candidate_graph_nodes,
  baseline_graph_edges =
    baseline_graph_edges,
  candidate_graph_edges =
    candidate_graph_edges,
  graph_node_edge_counts_identical =
    graph_counts_identical,
  workbook_sheet_names_identical =
    workbook_sheet_names_identical,
  all_sheet_columns_identical =
    all_sheet_columns_identical,
  strict_sheets_compared =
    strict_sheets_compared,
  strict_sheets_identical =
    strict_sheets_identical,
  log_summary_identical =
    log_summary_identical,
  strict_regression_core_match =
    strict_regression_core_match,
  stringsAsFactors = FALSE
)

summary_path <- file.path(
  output_directory,
  paste0(
    safe_checkpoint_id,
    "_summary.csv"
  )
)

strict_path <- file.path(
  output_directory,
  paste0(
    safe_checkpoint_id,
    "_strict_sheets.csv"
  )
)

schema_path <- file.path(
  output_directory,
  paste0(
    safe_checkpoint_id,
    "_schema.csv"
  )
)

utils::write.csv(
  summary_table,
  summary_path,
  row.names = FALSE,
  na = ""
)

utils::write.csv(
  strict_comparison,
  strict_path,
  row.names = FALSE,
  na = ""
)

utils::write.csv(
  schema_comparison,
  schema_path,
  row.names = FALSE,
  na = ""
)

print(
  summary_table,
  row.names = FALSE
)

if (!strict_regression_core_match) {
  failed_strict_sheets <- strict_comparison[
    !strict_comparison$identical_content,
    c(
      "workbook",
      "sheet_name",
      "baseline_rows",
      "candidate_rows",
      "baseline_columns",
      "candidate_columns"
    ),
    drop = FALSE
  ]

  if (nrow(failed_strict_sheets) > 0L) {
    message(
      "[checkpoint comparison] Non-identical strict sheets:"
    )

    print(
      failed_strict_sheets,
      row.names = FALSE
    )
  }

  stop(
    paste0(
      "Architecture checkpoint ",
      checkpoint_id,
      " failed the strict regression comparison."
    ),
    call. = FALSE
  )
}

message(
  "[checkpoint comparison] Checkpoint: ",
  checkpoint_id
)

message(
  "[checkpoint comparison] Case: ",
  case_id
)

message(
  "[checkpoint comparison] Strict sheets: ",
  strict_sheets_identical,
  "/",
  strict_sheets_compared,
  " identical."
)

message(
  "[checkpoint comparison] Strict regression core passed."
)