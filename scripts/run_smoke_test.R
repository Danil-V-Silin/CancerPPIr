#!/usr/bin/env Rscript

# Run one synthetic, non-clinical end-to-end analysis using an existing
# STRING v12 cache and verify the current public output contracts.

arguments <- commandArgs(trailingOnly = TRUE)
usage <- paste(
  "CancerPPIr synthetic end-to-end smoke test",
  "",
  "Usage:",
  "  Rscript scripts/run_smoke_test.R STRING_CACHE OUTPUT_ROOT",
  "",
  "Uses examples/minimal_input.csv and never runs clinical cases.",
  "STRING_CACHE and OUTPUT_ROOT must be outside the repository.",
  "All four pinned STRING v12 resources must already be cached.",
  sep = "\n"
)

if (length(arguments) == 1L && arguments[[1L]] %in% c("--help", "-h")) {
  cat(usage, "\n")
  quit(save = "no", status = 0L)
}

if (length(arguments) != 2L) {
  stop(usage, call. = FALSE)
}

project_root <- normalizePath(".", winslash = "/", mustWork = TRUE)
cache_dir <- normalizePath(arguments[[1L]], winslash = "/", mustWork = FALSE)
results_root <- normalizePath(arguments[[2L]], winslash = "/", mustWork = FALSE)
input_file <- file.path(project_root, "examples", "minimal_input.csv")

if (!file.exists(input_file)) {
  stop("Bundled synthetic example is missing: ", input_file, call. = FALSE)
}

if (!dir.exists(cache_dir)) {
  stop("STRING cache directory does not exist: ", cache_dir, call. = FALSE)
}

if (file.exists(results_root)) {
  stop("Smoke-test output root already exists: ", results_root, call. = FALSE)
}

path_is_within_project <- function(path) {
  root <- project_root

  if (identical(.Platform$OS.type, "windows")) {
    root <- tolower(root)
    path <- tolower(path)
  }

  identical(path, root) || startsWith(path, paste0(root, "/"))
}

if (path_is_within_project(cache_dir) || path_is_within_project(results_root)) {
  stop(
    "STRING_CACHE and OUTPUT_ROOT must be outside the repository.",
    call. = FALSE
  )
}

required_packages <- c("openxlsx", "igraph", "jsonlite", "digest")
missing_packages <- required_packages[
  !vapply(required_packages, requireNamespace, logical(1), quietly = TRUE)
]

if (length(missing_packages)) {
  stop(
    "Smoke test requires package(s): ",
    paste(missing_packages, collapse = ", "),
    call. = FALSE
  )
}

source(file.path(project_root, "R", "load_all.R"), local = .GlobalEnv)
load_cancerppir_modules(project_root = project_root, envir = .GlobalEnv)

example_input <- read_gene_table(input_file)
resource_manifest <- cancerppir_string_v12_resource_manifest(cache_dir)
invalid_resources <- resource_manifest$filename[!resource_manifest$valid]

if (length(invalid_resources)) {
  stop(
    "Smoke test will not download missing or invalid STRING resources: ",
    paste(invalid_resources, collapse = ", "),
    call. = FALSE
  )
}

logs_dir <- file.path(results_root, "logs")

if (!dir.create(logs_dir, recursive = TRUE, showWarnings = FALSE)) {
  stop("Could not create smoke-test output root: ", results_root, call. = FALSE)
}

case_id <- "SMOKE01"
log_file <- file.path(logs_dir, paste0(case_id, ".log"))
rscript <- file.path(
  R.home("bin"),
  if (.Platform$OS.type == "windows") "Rscript.exe" else "Rscript"
)

message("[CancerPPIr smoke] Running one bundled synthetic case.")

pipeline_status <- system2(
  command = rscript,
  args = c(
    shQuote(file.path(project_root, "cancerppir.R")),
    shQuote(input_file),
    shQuote(results_root),
    shQuote(cache_dir),
    "400",
    "30",
    "TRUE",
    "--case-id",
    case_id
  ),
  stdout = log_file,
  stderr = log_file,
  wait = TRUE
)

if (is.null(pipeline_status) || is.na(pipeline_status) || pipeline_status != 0L) {
  log_tail <- if (file.exists(log_file)) {
    tail(readLines(log_file, warn = FALSE, encoding = "UTF-8"), 40L)
  } else {
    "Pipeline log was not created."
  }

  stop(
    "Synthetic smoke pipeline failed with exit status ",
    pipeline_status,
    ".\n\nLog tail:\n",
    paste(log_tail, collapse = "\n"),
    call. = FALSE
  )
}

case_dir <- file.path(results_root, case_id)
output_names <- c(
  "CancerPPIr_Analytical_Report.xlsx",
  "CancerPPIr_Technical_Report.xlsx",
  "Network_for_Cytoscape.graphml",
  "STRING_links.txt",
  "CancerPPIr_Output_Manifest.json",
  "CancerPPIr_Output_Checksums.sha256"
)
output_paths <- file.path(case_dir, output_names)
missing_outputs <- output_names[!file.exists(output_paths)]

if (length(missing_outputs)) {
  stop(
    "Synthetic smoke case did not create required output(s): ",
    paste(missing_outputs, collapse = ", "),
    call. = FALSE
  )
}

analytical_file <- file.path(case_dir, output_names[[1L]])
technical_file <- file.path(case_dir, output_names[[2L]])
graph_file <- file.path(case_dir, output_names[[3L]])
manifest_file <- file.path(case_dir, output_names[[5L]])
checksum_file <- file.path(case_dir, output_names[[6L]])

log_lines <- readLines(log_file, warn = FALSE, encoding = "UTF-8")
graph <- igraph::read_graph(graph_file, format = "graphml")
manifest <- jsonlite::read_json(manifest_file, simplifyVector = FALSE)
technical_sheets <- openxlsx::getSheetNames(technical_file)
technical_nodes <- openxlsx::read.xlsx(technical_file, sheet = "Node annotations")
technical_mapping <- openxlsx::read.xlsx(technical_file, sheet = "Mapping summary")
mapping_values <- stats::setNames(
  as.character(technical_mapping$value),
  as.character(technical_mapping$metric)
)
analytical_summary <- openxlsx::read.xlsx(analytical_file, sheet = "Executive summary")
run_configuration <- analytical_summary$value[
  analytical_summary$item == "run_configuration"
]
provenance <- cancerppir_validate_output_provenance(
  manifest_file = manifest_file,
  checksums_file = checksum_file,
  output_dir = case_dir,
  forbidden_paths = c(project_root, cache_dir, results_root)
)

checks <- c(
  current_completion_marker = cancerppir_log_has_completion_marker(log_lines),
  expected_example_input_rows = nrow(example_input) == 20L,
  analytical_sheet_order = identical(
    openxlsx::getSheetNames(analytical_file),
    CANCERPPIR_ANALYTICAL_SHEET_NAMES
  ),
  canonical_technical_sheets = all(
    c(
      "Module annotations",
      "Rule evidence",
      "Significant terms",
      "Node annotations",
      "Validation"
    ) %in% technical_sheets
  ),
  graph_has_nodes_and_edges = igraph::vcount(graph) > 0L &&
    igraph::ecount(graph) > 0L,
  graph_node_count_matches_workbook =
    igraph::vcount(graph) == nrow(technical_nodes),
  canonical_graphml_attributes = all(
    canonical_graphml_attribute_names() %in% igraph::vertex_attr_names(graph)
  ),
  manifest_product_version = identical(
    as.character(manifest$software$version),
    cancerppir_product_version(project_root)
  ),
  manifest_pseudonymous_case_id =
    identical(as.character(manifest$input$case_id), case_id) &&
    identical(as.character(manifest$input$case_id_source), "explicit_case_id"),
  manifest_input_checksum = identical(
    tolower(as.character(manifest$input$sha256)),
    cancerppir_sha256_file(input_file)
  ),
  manifest_network_summary =
    identical(
      as.integer(manifest$summary$network_nodes),
      as.integer(igraph::vcount(graph))
    ) &&
    identical(
      as.integer(manifest$summary$network_edges),
      as.integer(igraph::ecount(graph))
    ),
  collision_counts_match =
    identical(
      as.integer(mapping_values[["STRING_mapping_collision_proteins"]]),
      as.integer(manifest$input$STRING_mapping_collision_proteins)
    ) &&
    identical(
      as.integer(mapping_values[["STRING_mapping_collision_rows_dropped"]]),
      as.integer(manifest$input$STRING_mapping_collision_rows_dropped)
    ),
  enrichment_mode_matches_manifest =
    isTRUE(manifest$analysis$local_enrichment_enabled) &&
    length(run_configuration) == 1L &&
    grepl("offline_enrichment=TRUE", run_configuration, fixed = TRUE),
  provenance_checks_pass = all(provenance$status == "PASS")
)

validation <- data.frame(
  check_id = names(checks),
  status = ifelse(checks, "PASS", "FAIL"),
  stringsAsFactors = FALSE
)

print(validation, row.names = FALSE)

if (!all(checks)) {
  stop(
    "Synthetic smoke validation failed: ",
    paste(names(checks)[!checks], collapse = ", "),
    call. = FALSE
  )
}

cat(
  "\nCANCERPPIR SYNTHETIC SMOKE TEST: PASSED\n",
  "Output: ", normalizePath(case_dir, winslash = "/"), "\n",
  sep = ""
)
