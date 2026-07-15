#!/usr/bin/env Rscript

# Finalize the seven-case CancerPPIr legacy regression baseline.
#
# The script:
# - exports compact reference tables from the primary legacy run;
# - computes canonical checksums for every Excel sheet;
# - compares the primary and repeated legacy runs;
# - records GraphML read-back status and structural counts;
# - documents known legacy limitations.
#
# Usage:
# Rscript scripts/finalize_legacy_baseline.R \
#   ../results/legacy_baseline_2026-07-15 \
#   ../results/legacy_baseline_repeat_2026-07-15

required_packages <- c(
  "openxlsx",
  "igraph"
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
      "Missing required packages: ",
      paste(missing_packages, collapse = ", ")
    ),
    call. = FALSE
  )
}

if (!file.exists("legacy/cancerppir_legacy.R")) {
  stop(
    "Run this script from the CancerPPIr repository root.",
    call. = FALSE
  )
}

arguments <- commandArgs(trailingOnly = TRUE)

primary_root <- if (length(arguments) >= 1L) {
  arguments[[1]]
} else {
  "../results/legacy_baseline_2026-07-15"
}

repeat_root <- if (length(arguments) >= 2L) {
  arguments[[2]]
} else {
  "../results/legacy_baseline_repeat_2026-07-15"
}

for (path in c(primary_root, repeat_root)) {
  if (!dir.exists(path)) {
    stop(
      "Legacy output directory does not exist: ",
      path,
      call. = FALSE
    )
  }
}

reference_root <- "tests/reference"
environment_dir <- file.path(
  reference_root,
  "environment"
)

dir.create(
  environment_dir,
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
  output_directory = c(
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

workbooks <- c(
  analytical_report = "CancerPPIr_Analytical_Report.xlsx",
  technical_report = "CancerPPIr_Technical_Report.xlsx"
)

artifacts <- c(
  analytical_report = "CancerPPIr_Analytical_Report.xlsx",
  technical_report = "CancerPPIr_Technical_Report.xlsx",
  cytoscape_graph = "Network_for_Cytoscape.graphml",
  string_links = "STRING_links.txt"
)

safe_file_name <- function(value) {
  value <- iconv(
    value,
    from = "",
    to = "ASCII//TRANSLIT"
  )

  if (is.na(value)) {
    value <- "sheet"
  }

  value <- tolower(value)
  value <- gsub("[^a-z0-9]+", "_", value)
  value <- gsub("^_+|_+$", "", value)

  if (!nzchar(value)) {
    value <- "sheet"
  }

  value
}

read_sheet_safely <- function(
  workbook_path,
  sheet_name
) {
  tryCatch(
    {
      data <- openxlsx::read.xlsx(
        workbook_path,
        sheet = sheet_name,
        detectDates = FALSE,
        skipEmptyRows = FALSE,
        skipEmptyCols = FALSE
      )

      list(
        data = data,
        error = NA_character_
      )
    },
    error = function(error) {
      list(
        data = NULL,
        error = conditionMessage(error)
      )
    }
  )
}

canonical_data_frame_md5 <- function(data) {
  if (is.null(data)) {
    return(NA_character_)
  }

  temporary_file <- tempfile(
    fileext = ".csv"
  )

  on.exit(
    unlink(temporary_file),
    add = TRUE
  )

  utils::write.csv(
    data,
    temporary_file,
    row.names = FALSE,
    na = "",
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

normalized_text_md5 <- function(
  path,
  sort_lines = FALSE
) {
  if (!file.exists(path)) {
    return(NA_character_)
  }

  lines <- readLines(
    path,
    warn = FALSE,
    encoding = "UTF-8"
  )

  lines <- sub(
    "\r$",
    "",
    lines
  )

  if (sort_lines) {
    lines <- sort(lines)
  }

  temporary_file <- tempfile(
    fileext = ".txt"
  )

  on.exit(
    unlink(temporary_file),
    add = TRUE
  )

  writeLines(
    lines,
    temporary_file,
    useBytes = TRUE
  )

  unname(
    tools::md5sum(temporary_file)
  )
}

count_xml_tag <- function(
  graph_path,
  tag_name
) {
  if (!file.exists(graph_path)) {
    return(NA_integer_)
  }

  lines <- readLines(
    graph_path,
    warn = FALSE,
    encoding = "UTF-8"
  )

  pattern <- paste0(
    "<",
    tag_name,
    "\\b"
  )

  matches <- gregexpr(
    pattern,
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

inspect_graphml <- function(path) {
  result <- data.frame(
    read_ok = FALSE,
    read_error = NA_character_,
    xml_nodes = count_xml_tag(path, "node"),
    xml_edges = count_xml_tag(path, "edge"),
    igraph_nodes = NA_integer_,
    igraph_edges = NA_integer_,
    stringsAsFactors = FALSE
  )

  if (!file.exists(path)) {
    result$read_error <- "File does not exist."
    return(result)
  }

  graph <- tryCatch(
    igraph::read_graph(
      path,
      format = "graphml"
    ),
    error = function(error) {
      result$read_error <<- conditionMessage(error)
      NULL
    }
  )

  if (!is.null(graph)) {
    result$read_ok <- TRUE
    result$read_error <- NA_character_
    result$igraph_nodes <- igraph::vcount(graph)
    result$igraph_edges <- igraph::ecount(graph)
  }

  result
}

select_technical_sheet <- function(sheet_name) {
  normalized <- tolower(sheet_name)

  grepl(
    paste(
      c(
        "network.*report",
        "network.*summary",
        "mapping.*report",
        "mapping.*audit",
        "major.*module",
        "module.*summary"
      ),
      collapse = "|"
    ),
    normalized
  )
}

sheet_rows <- list()
artifact_rows <- list()

sheet_index <- 1L
artifact_index <- 1L

for (case_index in seq_len(nrow(case_table))) {
  case_id <- case_table$case_id[[case_index]]
  directory_name <- case_table$output_directory[[case_index]]

  primary_case_dir <- file.path(
    primary_root,
    directory_name
  )

  repeat_case_dir <- file.path(
    repeat_root,
    directory_name
  )

  reference_case_dir <- file.path(
    reference_root,
    case_id
  )

  dir.create(
    reference_case_dir,
    recursive = TRUE,
    showWarnings = FALSE
  )

  message("[finalize] Processing ", case_id, ".")

  for (workbook_type in names(workbooks)) {
    workbook_name <- workbooks[[workbook_type]]

    primary_workbook <- file.path(
      primary_case_dir,
      workbook_name
    )

    repeat_workbook <- file.path(
      repeat_case_dir,
      workbook_name
    )

    primary_sheets <- if (file.exists(primary_workbook)) {
      openxlsx::getSheetNames(primary_workbook)
    } else {
      character(0)
    }

    repeat_sheets <- if (file.exists(repeat_workbook)) {
      openxlsx::getSheetNames(repeat_workbook)
    } else {
      character(0)
    }

    all_sheets <- unique(
      c(
        primary_sheets,
        repeat_sheets
      )
    )

    for (sheet_name in all_sheets) {
      primary_exists <- sheet_name %in% primary_sheets
      repeat_exists <- sheet_name %in% repeat_sheets

      primary_result <- if (primary_exists) {
        read_sheet_safely(
          primary_workbook,
          sheet_name
        )
      } else {
        list(
          data = NULL,
          error = "Sheet does not exist."
        )
      }

      repeat_result <- if (repeat_exists) {
        read_sheet_safely(
          repeat_workbook,
          sheet_name
        )
      } else {
        list(
          data = NULL,
          error = "Sheet does not exist."
        )
      }

      primary_md5 <- canonical_data_frame_md5(
        primary_result$data
      )

      repeat_md5 <- canonical_data_frame_md5(
        repeat_result$data
      )

      primary_rows <- if (
        is.null(primary_result$data)
      ) {
        NA_integer_
      } else {
        nrow(primary_result$data)
      }

      repeat_rows <- if (
        is.null(repeat_result$data)
      ) {
        NA_integer_
      } else {
        nrow(repeat_result$data)
      }

      primary_columns <- if (
        is.null(primary_result$data)
      ) {
        NA_integer_
      } else {
        ncol(primary_result$data)
      }

      repeat_columns <- if (
        is.null(repeat_result$data)
      ) {
        NA_integer_
      } else {
        ncol(repeat_result$data)
      }

      same_dimensions <- isTRUE(
        identical(
          c(primary_rows, primary_columns),
          c(repeat_rows, repeat_columns)
        )
      )

      identical_content <- isTRUE(
        !is.na(primary_md5) &&
          !is.na(repeat_md5) &&
          identical(primary_md5, repeat_md5)
      )

      selected_export <- FALSE

      if (
        selected_export &&
        !is.null(primary_result$data)
      ) {
        sheet_position <- match(
          sheet_name,
          primary_sheets
        )

        if (is.na(sheet_position)) {
          sheet_position <- 0L
        }

        export_name <- paste0(
          workbook_type,
          "__",
          sprintf("%02d", sheet_position),
          "__",
          safe_file_name(sheet_name),
          ".csv"
        )

        utils::write.csv(
          primary_result$data,
          file.path(
            reference_case_dir,
            export_name
          ),
          row.names = FALSE,
          na = "",
          fileEncoding = "UTF-8"
        )
      }

      sheet_rows[[sheet_index]] <- data.frame(
        case_id = case_id,
        workbook = workbook_type,
        sheet_name = sheet_name,
        selected_export = selected_export,
        primary_exists = primary_exists,
        repeat_exists = repeat_exists,
        primary_rows = primary_rows,
        repeat_rows = repeat_rows,
        primary_columns = primary_columns,
        repeat_columns = repeat_columns,
        primary_md5 = primary_md5,
        repeat_md5 = repeat_md5,
        same_dimensions = same_dimensions,
        identical_content = identical_content,
        primary_read_error = primary_result$error,
        repeat_read_error = repeat_result$error,
        stringsAsFactors = FALSE
      )

      sheet_index <- sheet_index + 1L
    }
  }

  for (artifact_name in names(artifacts)) {
    file_name <- artifacts[[artifact_name]]

    primary_path <- file.path(
      primary_case_dir,
      file_name
    )

    repeat_path <- file.path(
      repeat_case_dir,
      file_name
    )

    primary_exists <- file.exists(primary_path)
    repeat_exists <- file.exists(repeat_path)

    primary_raw_md5 <- file_md5(primary_path)
    repeat_raw_md5 <- file_md5(repeat_path)

    primary_normalized_md5 <- NA_character_
    repeat_normalized_md5 <- NA_character_

    primary_graph <- data.frame(
      read_ok = NA,
      read_error = NA_character_,
      xml_nodes = NA_integer_,
      xml_edges = NA_integer_,
      igraph_nodes = NA_integer_,
      igraph_edges = NA_integer_,
      stringsAsFactors = FALSE
    )

    repeat_graph <- primary_graph

    if (artifact_name == "string_links") {
      primary_normalized_md5 <- normalized_text_md5(
        primary_path,
        sort_lines = TRUE
      )

      repeat_normalized_md5 <- normalized_text_md5(
        repeat_path,
        sort_lines = TRUE
      )
    }

    if (artifact_name == "cytoscape_graph") {
      primary_graph <- inspect_graphml(
        primary_path
      )

      repeat_graph <- inspect_graphml(
        repeat_path
      )
    }

    artifact_rows[[artifact_index]] <- data.frame(
      case_id = case_id,
      artifact = artifact_name,
      primary_exists = primary_exists,
      repeat_exists = repeat_exists,
      primary_size_bytes = if (primary_exists) {
        file.info(primary_path)$size
      } else {
        NA_real_
      },
      repeat_size_bytes = if (repeat_exists) {
        file.info(repeat_path)$size
      } else {
        NA_real_
      },
      primary_raw_md5 = primary_raw_md5,
      repeat_raw_md5 = repeat_raw_md5,
      raw_identical = isTRUE(
        !is.na(primary_raw_md5) &&
          !is.na(repeat_raw_md5) &&
          identical(
            primary_raw_md5,
            repeat_raw_md5
          )
      ),
      primary_normalized_md5 = primary_normalized_md5,
      repeat_normalized_md5 = repeat_normalized_md5,
      normalized_identical = isTRUE(
        !is.na(primary_normalized_md5) &&
          !is.na(repeat_normalized_md5) &&
          identical(
            primary_normalized_md5,
            repeat_normalized_md5
          )
      ),
      primary_graph_read_ok = primary_graph$read_ok,
      repeat_graph_read_ok = repeat_graph$read_ok,
      primary_graph_read_error = primary_graph$read_error,
      repeat_graph_read_error = repeat_graph$read_error,
      primary_xml_nodes = primary_graph$xml_nodes,
      repeat_xml_nodes = repeat_graph$xml_nodes,
      primary_xml_edges = primary_graph$xml_edges,
      repeat_xml_edges = repeat_graph$xml_edges,
      graph_node_edge_counts_identical = isTRUE(
        identical(
          c(
            primary_graph$xml_nodes,
            primary_graph$xml_edges
          ),
          c(
            repeat_graph$xml_nodes,
            repeat_graph$xml_edges
          )
        )
      ),
      stringsAsFactors = FALSE
    )

    artifact_index <- artifact_index + 1L
  }
}

sheet_comparison <- do.call(
  rbind,
  sheet_rows
)

artifact_comparison <- do.call(
  rbind,
  artifact_rows
)

case_summary_rows <- list()

for (case_index in seq_len(nrow(case_table))) {
  case_id <- case_table$case_id[[case_index]]

  case_sheets <- sheet_comparison[
    sheet_comparison$case_id == case_id,
    ,
    drop = FALSE
  ]

  case_artifacts <- artifact_comparison[
    artifact_comparison$case_id == case_id,
    ,
    drop = FALSE
  ]

  string_row <- case_artifacts[
    case_artifacts$artifact == "string_links",
    ,
    drop = FALSE
  ]

  graph_row <- case_artifacts[
    case_artifacts$artifact == "cytoscape_graph",
    ,
    drop = FALSE
  ]

  all_sheets_identical <- nrow(case_sheets) > 0L &&
    all(case_sheets$identical_content)

  string_links_identical <- nrow(string_row) == 1L &&
    isTRUE(string_row$normalized_identical[[1]])

  graph_counts_identical <- nrow(graph_row) == 1L &&
    isTRUE(
      graph_row$graph_node_edge_counts_identical[[1]]
    )

  all_expected_files_exist <- all(
    case_artifacts$primary_exists &
      case_artifacts$repeat_exists
  )

  case_summary_rows[[case_index]] <- data.frame(
    case_id = case_id,
    compared_sheets = nrow(case_sheets),
    identical_sheets = sum(
      case_sheets$identical_content
    ),
    changed_sheets = sum(
      !case_sheets$identical_content
    ),
    all_sheet_content_identical = all_sheets_identical,
    string_links_identical = string_links_identical,
    graph_node_edge_counts_identical = graph_counts_identical,
    primary_graph_read_ok = graph_row$primary_graph_read_ok[[1]],
    repeat_graph_read_ok = graph_row$repeat_graph_read_ok[[1]],
    graphml_raw_identical = graph_row$raw_identical[[1]],
    all_expected_files_exist = all_expected_files_exist,
    structural_baseline_match = all(
      all_expected_files_exist,
      all_sheets_identical,
      string_links_identical,
      graph_counts_identical
    ),
    stringsAsFactors = FALSE
  )
}

case_summary <- do.call(
  rbind,
  case_summary_rows
)

primary_sheet_checksums <- sheet_comparison[
  ,
  c(
    "case_id",
    "workbook",
    "sheet_name",
    "selected_export",
    "primary_rows",
    "primary_columns",
    "primary_md5",
    "primary_read_error"
  )
]

names(primary_sheet_checksums) <- c(
  "case_id",
  "workbook",
  "sheet_name",
  "selected_export",
  "row_count",
  "column_count",
  "canonical_csv_md5",
  "read_error"
)

utils::write.csv(
  primary_sheet_checksums,
  file.path(
    environment_dir,
    "legacy_sheet_checksums.csv"
  ),
  row.names = FALSE,
  na = ""
)

utils::write.csv(
  sheet_comparison,
  file.path(
    environment_dir,
    "legacy_determinism_sheet_comparison.csv"
  ),
  row.names = FALSE,
  na = ""
)

utils::write.csv(
  artifact_comparison,
  file.path(
    environment_dir,
    "legacy_determinism_artifact_comparison.csv"
  ),
  row.names = FALSE,
  na = ""
)

utils::write.csv(
  case_summary,
  file.path(
    environment_dir,
    "legacy_determinism_case_summary.csv"
  ),
  row.names = FALSE,
  na = ""
)

config_files <- c(
  primary = file.path(
    primary_root,
    "run_config.txt"
  ),
  `repeat` = file.path(
    repeat_root,
    "run_config.txt"
  )
)

for (config_name in names(config_files)) {
  source_path <- config_files[[config_name]]

  if (file.exists(source_path)) {
    file.copy(
      source_path,
      file.path(
        environment_dir,
        paste0(
          "legacy_",
          config_name,
          "_run_config.txt"
        )
      ),
      overwrite = TRUE
    )
  }
}

primary_graph_failures <- unique(
  artifact_comparison$case_id[
    artifact_comparison$artifact == "cytoscape_graph" &
      artifact_comparison$primary_graph_read_ok == FALSE
  ]
)

nonidentical_cases <- case_summary$case_id[
  !case_summary$structural_baseline_match
]

known_issue_lines <- c(
  "# Known legacy baseline issues",
  "",
  "The following limitations were observed before refactoring:",
  "",
  paste0(
    "1. The legacy input reader may fall back to positional column ",
    "interpretation (`pvalue`, `logFC`, `gene`) when headers are not ",
    "fully recognized."
  ),
  paste0(
    "2. HGNChelper reports non-approved gene symbols, and STRING mapping ",
    "does not map all supplied identifiers."
  ),
  paste0(
    "3. Several installed packages were built under later R 4.5.x patch ",
    "versions than the active R 4.5.0 installation."
  ),
  if (length(primary_graph_failures) > 0L) {
    paste0(
      "4. GraphML read-back with igraph fails for: ",
      paste(primary_graph_failures, collapse = ", "),
      ". The files contain numerical attributes that trigger an ",
      "integer or double overflow in the GraphML parser."
    )
  } else {
    "4. All primary GraphML files were readable with igraph."
  },
  if (length(nonidentical_cases) > 0L) {
    paste0(
      "5. The repeated run was not structurally identical for: ",
      paste(nonidentical_cases, collapse = ", "),
      ". See `legacy_determinism_case_summary.csv` and the detailed ",
      "sheet comparison."
    )
  } else {
    paste0(
      "5. The repeated run matched the primary run for all seven cases ",
      "under the structural baseline criteria."
    )
  },
  "",
  paste0(
    "Raw XLSX and GraphML MD5 checksums are diagnostic only. Binary ",
    "metadata or serialization order can change even when the extracted ",
    "analytical tables remain equivalent."
  )
)

writeLines(
  known_issue_lines,
  file.path(
    reference_root,
    "KNOWN_LEGACY_ISSUES.md"
  ),
  useBytes = TRUE
)

message(
  "[finalize] Legacy regression baseline completed."
)

message(
  "[finalize] Case summary: ",
  file.path(
    environment_dir,
    "legacy_determinism_case_summary.csv"
  )
)

source("scripts/postprocess_legacy_baseline.R", local = TRUE)
