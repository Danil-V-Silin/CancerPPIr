#!/usr/bin/env Rscript

# Create a compact inventory of outputs produced by the preserved
# legacy CancerPPIr implementation for all seven reference cases.
#
# Usage:
#   Rscript scripts/inventory_legacy_outputs.R
#
# Optional custom output root:
#   Rscript scripts/inventory_legacy_outputs.R ../results/legacy_baseline_2026-07-15

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

output_root <- if (length(arguments) >= 1L) {
  arguments[[1]]
} else {
  "../results/legacy_baseline_2026-07-15"
}

if (!dir.exists(output_root)) {
  stop(
    "Legacy output directory does not exist: ",
    output_root,
    call. = FALSE
  )
}

reference_root <- "tests/reference"
environment_dir <- file.path(reference_root, "environment")

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

expected_artifacts <- c(
  analytical_report = "CancerPPIr_Analytical_Report.xlsx",
  technical_report = "CancerPPIr_Technical_Report.xlsx",
  cytoscape_graph = "Network_for_Cytoscape.graphml",
  string_links = "STRING_links.txt"
)

empty_to_na <- function(value) {
  if (length(value) == 0L || is.na(value) || !nzchar(value)) {
    return(NA_character_)
  }

  value
}

parse_log_summary <- function(log_path) {
  result <- data.frame(
    mapped_genes = NA_integer_,
    input_genes = NA_integer_,
    mapped_percent = NA_real_,
    reported_nodes = NA_integer_,
    reported_edges = NA_integer_,
    reported_components = NA_integer_,
    stringsAsFactors = FALSE
  )

  if (!file.exists(log_path)) {
    return(result)
  }

  lines <- readLines(
    log_path,
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
    mapped_line <- tail(mapped_lines, 1L)

    match <- regexec(
      "Mapped genes: ([0-9]+)/([0-9]+) \\(([0-9.]+)%\\)",
      mapped_line
    )

    values <- regmatches(mapped_line, match)[[1]]

    if (length(values) == 4L) {
      result$mapped_genes <- as.integer(values[[2]])
      result$input_genes <- as.integer(values[[3]])
      result$mapped_percent <- as.numeric(values[[4]])
    }
  }

  network_lines <- grep(
    "Network:",
    lines,
    value = TRUE,
    fixed = TRUE
  )

  if (length(network_lines) > 0L) {
    network_line <- tail(network_lines, 1L)

    match <- regexec(
      "Network: ([0-9]+) nodes, ([0-9]+) edges, ([0-9]+) components",
      network_line
    )

    values <- regmatches(network_line, match)[[1]]

    if (length(values) == 4L) {
      result$reported_nodes <- as.integer(values[[2]])
      result$reported_edges <- as.integer(values[[3]])
      result$reported_components <- as.integer(values[[4]])
    }
  }

  result
}

artifact_rows <- list()
workbook_rows <- list()
network_rows <- list()
run_rows <- list()

artifact_index <- 1L
workbook_index <- 1L
network_index <- 1L
run_index <- 1L

for (case_index in seq_len(nrow(case_table))) {
  case_id <- case_table$case_id[[case_index]]
  directory_name <- case_table$output_directory[[case_index]]

  case_output_dir <- file.path(
    output_root,
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

  message("[inventory] Processing ", case_id, ".")

  for (artifact_name in names(expected_artifacts)) {
    file_name <- expected_artifacts[[artifact_name]]
    artifact_path <- file.path(
      case_output_dir,
      file_name
    )

    exists <- file.exists(artifact_path)

    artifact_rows[[artifact_index]] <- data.frame(
      case_id = case_id,
      artifact = artifact_name,
      file_name = file_name,
      external_relative_path = file.path(
        "..",
        "results",
        basename(output_root),
        directory_name,
        file_name
      ),
      exists = exists,
      size_bytes = if (exists) {
        file.info(artifact_path)$size
      } else {
        NA_real_
      },
      md5 = if (exists) {
        unname(tools::md5sum(artifact_path))
      } else {
        NA_character_
      },
      stringsAsFactors = FALSE
    )

    artifact_index <- artifact_index + 1L
  }

  workbook_files <- c(
    analytical_report = expected_artifacts[["analytical_report"]],
    technical_report = expected_artifacts[["technical_report"]]
  )

  for (workbook_type in names(workbook_files)) {
    workbook_path <- file.path(
      case_output_dir,
      workbook_files[[workbook_type]]
    )

    if (!file.exists(workbook_path)) {
      next
    }

    message(
      "[inventory] Reading workbook structure: ",
      case_id,
      " / ",
      workbook_type,
      "."
    )

    sheet_names <- openxlsx::getSheetNames(workbook_path)

    for (sheet_name in sheet_names) {
      sheet_data <- tryCatch(
        openxlsx::read.xlsx(
          workbook_path,
          sheet = sheet_name,
          detectDates = FALSE,
          skipEmptyRows = FALSE,
          skipEmptyCols = FALSE
        ),
        error = function(error) {
          structure(
            data.frame(),
            read_error = conditionMessage(error)
          )
        }
      )

      read_error <- attr(
        sheet_data,
        "read_error",
        exact = TRUE
      )

      workbook_rows[[workbook_index]] <- data.frame(
        case_id = case_id,
        workbook = workbook_type,
        sheet_name = sheet_name,
        row_count = nrow(sheet_data),
        column_count = ncol(sheet_data),
        read_error = empty_to_na(read_error),
        stringsAsFactors = FALSE
      )

      workbook_index <- workbook_index + 1L
    }
  }

  graph_path <- file.path(
    case_output_dir,
    expected_artifacts[["cytoscape_graph"]]
  )

    if (file.exists(graph_path)) {
    graph_read_error <- NA_character_

    graph <- tryCatch(
      igraph::read_graph(
        graph_path,
        format = "graphml"
      ),
      error = function(error) {
        graph_read_error <<- conditionMessage(error)
        NULL
      }
    )

    if (is.null(graph)) {
      message(
        "[inventory] GraphML could not be read for ",
        case_id,
        ": ",
        graph_read_error
      )

      graph_lines <- readLines(
        graph_path,
        warn = FALSE,
        encoding = "UTF-8"
      )

      count_xml_tags <- function(tag_name) {
        pattern <- paste0(
          "<",
          tag_name,
          "\\b"
        )

        matches <- gregexpr(
          pattern,
          graph_lines,
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

      network_rows[[network_index]] <- data.frame(
        case_id = case_id,
        graph_read_ok = FALSE,
        graph_read_error = graph_read_error,
        nodes = count_xml_tags("node"),
        edges = count_xml_tags("edge"),
        components = NA_integer_,
        largest_component_nodes = NA_integer_,
        largest_component_percent = NA_real_,
        isolated_nodes = NA_integer_,
        mean_degree = NA_real_,
        maximum_degree = NA_real_,
        density = NA_real_,
        global_transitivity = NA_real_,
        mean_distance = NA_real_,
        diameter = NA_real_,
        vertex_attribute_count = NA_integer_,
        edge_attribute_count = NA_integer_,
        vertex_attributes = NA_character_,
        edge_attributes = NA_character_,
        stringsAsFactors = FALSE
      )
    } else {
      component_data <- igraph::components(graph)
      degrees <- igraph::degree(graph)

      global_transitivity <- suppressWarnings(
        igraph::transitivity(
          graph,
          type = "global",
          isolates = "zero"
        )
      )

      if (!is.finite(global_transitivity)) {
        global_transitivity <- NA_real_
      }

      network_rows[[network_index]] <- data.frame(
        case_id = case_id,
        graph_read_ok = TRUE,
        graph_read_error = NA_character_,
        nodes = igraph::vcount(graph),
        edges = igraph::ecount(graph),
        components = component_data$no,
        largest_component_nodes = max(component_data$csize),
        largest_component_percent = round(
          100 * max(component_data$csize) / igraph::vcount(graph),
          6
        ),
        isolated_nodes = sum(degrees == 0),
        mean_degree = mean(degrees),
        maximum_degree = max(degrees),
        density = igraph::edge_density(
          graph,
          loops = FALSE
        ),
        global_transitivity = global_transitivity,
        mean_distance = igraph::mean_distance(
          graph,
          directed = igraph::is_directed(graph),
          unconnected = TRUE
        ),
        diameter = igraph::diameter(
          graph,
          directed = igraph::is_directed(graph),
          unconnected = TRUE,
          weights = NA
        ),
        vertex_attribute_count = length(
          igraph::vertex_attr_names(graph)
        ),
        edge_attribute_count = length(
          igraph::edge_attr_names(graph)
        ),
        vertex_attributes = paste(
          sort(igraph::vertex_attr_names(graph)),
          collapse = ";"
        ),
        edge_attributes = paste(
          sort(igraph::edge_attr_names(graph)),
          collapse = ";"
        ),
        stringsAsFactors = FALSE
      )
    }

    network_index <- network_index + 1L
  }

  log_path <- file.path(
    output_root,
    "logs",
    paste0(case_id, ".log")
  )

  parsed_log <- parse_log_summary(log_path)

  run_rows[[run_index]] <- data.frame(
    case_id = case_id,
    log_exists = file.exists(log_path),
    mapped_genes = parsed_log$mapped_genes,
    input_genes = parsed_log$input_genes,
    mapped_percent = parsed_log$mapped_percent,
    reported_nodes = parsed_log$reported_nodes,
    reported_edges = parsed_log$reported_edges,
    reported_components = parsed_log$reported_components,
    stringsAsFactors = FALSE
  )

  run_index <- run_index + 1L
}

artifact_manifest <- do.call(
  rbind,
  artifact_rows
)

workbook_inventory <- do.call(
  rbind,
  workbook_rows
)

network_summary <- do.call(
  rbind,
  network_rows
)

run_summary <- do.call(
  rbind,
  run_rows
)

utils::write.csv(
  artifact_manifest,
  file.path(
    environment_dir,
    "legacy_output_artifacts.csv"
  ),
  row.names = FALSE,
  na = ""
)

utils::write.csv(
  workbook_inventory,
  file.path(
    environment_dir,
    "legacy_workbook_inventory.csv"
  ),
  row.names = FALSE,
  na = ""
)

utils::write.csv(
  network_summary,
  file.path(
    environment_dir,
    "legacy_network_summary.csv"
  ),
  row.names = FALSE,
  na = ""
)

utils::write.csv(
  run_summary,
  file.path(
    environment_dir,
    "legacy_run_summary.csv"
  ),
  row.names = FALSE,
  na = ""
)

for (case_id in case_table$case_id) {
  case_network <- network_summary[
    network_summary$case_id == case_id,
    ,
    drop = FALSE
  ]

  case_artifacts <- artifact_manifest[
    artifact_manifest$case_id == case_id,
    ,
    drop = FALSE
  ]

  utils::write.csv(
    case_network,
    file.path(
      reference_root,
      case_id,
      "network_summary.csv"
    ),
    row.names = FALSE,
    na = ""
  )

  utils::write.csv(
    case_artifacts,
    file.path(
      reference_root,
      case_id,
      "artifact_manifest.csv"
    ),
    row.names = FALSE,
    na = ""
  )
}

external_status_path <- file.path(
  output_root,
  "run_status.csv"
)

if (file.exists(external_status_path)) {
  run_status <- utils::read.csv(
    external_status_path,
    stringsAsFactors = FALSE
  )

  utils::write.csv(
    run_status,
    file.path(
      environment_dir,
      "legacy_batch_run_status.csv"
    ),
    row.names = FALSE,
    na = ""
  )
}

message(
  "[inventory] Legacy output inventory written to tests/reference."
)
