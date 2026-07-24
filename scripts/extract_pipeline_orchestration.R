#!/usr/bin/env Rscript

# Final Phase 2 extraction:
# move runtime dependency setup and the remaining end-to-end workflow from
# cancerppir.R into R/07_pipeline.R as run_cancerppir().
#
# The CLI argument parser remains in cancerppir.R and calls run_cancerppir().
#
# Run from the repository root:
#   Rscript scripts/extract_pipeline_orchestration.R

source_file <- "cancerppir.R"
module_file <- file.path("R", "07_pipeline.R")
loader_file <- file.path("R", "load_all.R")
legacy_file <- file.path("legacy", "cancerppir_legacy.R")

manifest_file <- file.path(
  "docs",
  "architecture",
  "checkpoint_2_12_pipeline_extraction.csv"
)

validation_file <- file.path(
  "docs",
  "architecture",
  "checkpoint_2_12_pipeline_validation.txt"
)

expected_legacy_md5 <- "0c5644140abbae2f17e30109432cc198"

function_arguments <- c(
  "input_file",
  "results_root",
  "cache_dir",
  "score_threshold",
  "top_n",
  "run_enrichment"
)

required_files <- c(
  source_file,
  module_file,
  loader_file,
  legacy_file
)

missing_files <- required_files[
  !file.exists(required_files)
]

if (length(missing_files) > 0L) {
  stop(
    paste0(
      "Run this script from the repository root.\n",
      "Missing files:\n",
      paste(
        paste0("- ", missing_files),
        collapse = "\n"
      )
    ),
    call. = FALSE
  )
}

existing_outputs <- c(
  manifest_file,
  validation_file
)

existing_outputs <- existing_outputs[
  file.exists(existing_outputs)
]

if (length(existing_outputs) > 0L) {
  stop(
    paste0(
      "Checkpoint output files already exist:\n",
      paste(
        paste0("- ", existing_outputs),
        collapse = "\n"
      )
    ),
    call. = FALSE
  )
}

assert_matches_head <- function(path) {
  status <- system2(
    command = "git",
    args = c(
      "diff",
      "--quiet",
      "HEAD",
      "--",
      path
    ),
    stdout = FALSE,
    stderr = FALSE
  )

  if (identical(status, 0L)) {
    return(invisible(TRUE))
  }

  if (identical(status, 1L)) {
    stop(
      paste0(
        path,
        " differs from the committed HEAD version.\n",
        "Inspect, commit or restore it before extraction."
      ),
      call. = FALSE
    )
  }

  stop(
    paste0(
      "Git could not verify ",
      path,
      "."
    ),
    call. = FALSE
  )
}

assert_matches_head(source_file)
assert_matches_head(module_file)

legacy_md5_before <- unname(
  tools::md5sum(legacy_file)
)

if (!identical(
  legacy_md5_before,
  expected_legacy_md5
)) {
  stop(
    paste0(
      "Unexpected legacy checksum.\n",
      "Expected: ",
      expected_legacy_md5,
      "\nObserved: ",
      legacy_md5_before
    ),
    call. = FALSE
  )
}

read_raw_file <- function(path) {
  connection <- file(path, open = "rb")

  on.exit(
    close(connection),
    add = TRUE
  )

  readBin(
    connection,
    what = "raw",
    n = as.integer(file.info(path)$size)
  )
}

write_raw_file <- function(path, contents) {
  connection <- file(path, open = "wb")

  on.exit(
    close(connection),
    add = TRUE
  )

  writeBin(contents, connection)

  invisible(path)
}

source_raw_before <- read_raw_file(source_file)
module_raw_before <- read_raw_file(module_file)

source_md5_before <- unname(
  tools::md5sum(source_file)
)

module_md5_before <- unname(
  tools::md5sum(module_file)
)

source_lines <- readLines(
  source_file,
  warn = FALSE,
  encoding = "UTF-8"
)

module_lines <- readLines(
  module_file,
  warn = FALSE,
  encoding = "UTF-8"
)

if (any(grepl(
  "run_cancerppir <- function",
  module_lines,
  fixed = TRUE
))) {
  stop(
    "R/07_pipeline.R already defines run_cancerppir().",
    call. = FALSE
  )
}

find_exact_line <- function(text) {
  matches <- which(
    trimws(source_lines) == text
  )

  if (length(matches) != 1L) {
    stop(
      paste0(
        "Expected exactly one line:\n",
        text,
        "\nObserved matches: ",
        length(matches)
      ),
      call. = FALSE
    )
  }

  as.integer(matches[[1L]])
}

package_start_line <- find_exact_line(
  'required_cran <- c("HGNChelper", "igraph", "openxlsx", "dplyr", "tibble", "curl", "sna")'
)

suppress_start_line <- find_exact_line(
  "suppressPackageStartupMessages({"
)

args_line <- find_exact_line(
  "args <- commandArgs(trailingOnly = TRUE)"
)

package_end_candidates <- which(
  seq_along(source_lines) > suppress_start_line &
    seq_along(source_lines) < args_line &
    trimws(source_lines) == "})"
)

if (length(package_end_candidates) < 1L) {
  stop(
    "Could not identify the end of the runtime package-loading block.",
    call. = FALSE
  )
}

package_end_line <- max(package_end_candidates)

pipeline_start_matches <- which(
  grepl(
    "# Derive output directory from the input filename.",
    source_lines,
    fixed = TRUE
  )
)

if (length(pipeline_start_matches) != 1L) {
  stop(
    paste0(
      "Expected one pipeline-start marker, observed ",
      length(pipeline_start_matches),
      "."
    ),
    call. = FALSE
  )
}

pipeline_start_line <- as.integer(
  pipeline_start_matches[[1L]]
)

pipeline_end_line <- find_exact_line(
  'msg("Main files: CancerPPIr_Analytical_Report.xlsx, CancerPPIr_Technical_Report.xlsx, STRING_links.txt, Network_for_Cytoscape.graphml")'
)

if (
  package_start_line >= package_end_line ||
    package_end_line >= args_line ||
    args_line >= pipeline_start_line ||
    pipeline_start_line >= pipeline_end_line
) {
  stop(
    "Detected source block boundaries are inconsistent.",
    call. = FALSE
  )
}

package_block <- source_lines[
  package_start_line:package_end_line
]

pipeline_block <- source_lines[
  pipeline_start_line:pipeline_end_line
]

function_body <- c(
  package_block,
  "",
  pipeline_block
)

indented_function_body <- ifelse(
  nzchar(function_body),
  paste0("  ", function_body),
  ""
)

function_signature <- c(
  "run_cancerppir <- function(",
  "  input_file,",
  "  results_root,",
  "  cache_dir,",
  "  score_threshold = 400L,",
  "  top_n = 30L,",
  "  run_enrichment = TRUE",
  ") {"
)

return_block <- c(
  "",
  "  invisible(list(",
  "    output_dir = output_dir,",
  "    graph = ppi,",
  "    node_metrics = node_metrics_readable,",
  "    module_summary = module_summary_readable,",
  "    candidate_evidence_matrix = candidate_evidence_matrix,",
  "    priority_directions = priority_directions,",
  "    final_priorities = final_priorities,",
  "    graph_summary = graph_summary,",
  "    mapping_summary = mapping_summary,",
  "    files = c(",
  '      analytical_report = file.path(output_dir, "CancerPPIr_Analytical_Report.xlsx"),',
  '      technical_report = file.path(output_dir, "CancerPPIr_Technical_Report.xlsx"),',
  '      string_links = file.path(output_dir, "STRING_links.txt"),',
  '      graphml = file.path(output_dir, "Network_for_Cytoscape.graphml")',
  "    )",
  "  ))",
  "}"
)

new_module_lines <- c(
  module_lines,
  "",
  "# -----------------------------------------------------------------------------",
  "# End-to-end CancerPPIr workflow",
  "# Architecture checkpoint 2.12",
  "# -----------------------------------------------------------------------------",
  "",
  function_signature,
  indented_function_body,
  return_block
)

remove_lines <- rep(
  FALSE,
  length(source_lines)
)

remove_lines[
  package_start_line:package_end_line
] <- TRUE

remove_lines[
  pipeline_start_line:pipeline_end_line
] <- TRUE

source_prefix <- source_lines[
  seq_len(pipeline_start_line - 1L)
]

source_prefix <- source_prefix[
  !remove_lines[
    seq_len(pipeline_start_line - 1L)
  ]
]

source_suffix <- if (
  pipeline_end_line < length(source_lines)
) {
  source_lines[
    seq.int(
      pipeline_end_line + 1L,
      length(source_lines)
    )
  ]
} else {
  character()
}

cli_call <- c(
  "",
  "invisible(",
  "  run_cancerppir(",
  "    input_file = input_file,",
  "    results_root = results_root,",
  "    cache_dir = cache_dir,",
  "    score_threshold = score_threshold,",
  "    top_n = top_n,",
  "    run_enrichment = run_enrichment",
  "  )",
  ")"
)

new_source_lines <- c(
  source_prefix,
  cli_call,
  source_suffix
)

temporary_directory <- tempfile(
  pattern = "cancerppir-pipeline-extraction-"
)

dir.create(
  temporary_directory,
  recursive = TRUE,
  showWarnings = FALSE
)

temporary_source <- file.path(
  temporary_directory,
  "cancerppir.R"
)

temporary_module <- file.path(
  temporary_directory,
  "07_pipeline.R"
)

writeLines(
  new_source_lines,
  temporary_source,
  useBytes = TRUE
)

writeLines(
  new_module_lines,
  temporary_module,
  useBytes = TRUE
)

invisible(parse(file = temporary_source))
invisible(parse(file = temporary_module))

temporary_source_lines <- readLines(
  temporary_source,
  warn = FALSE,
  encoding = "UTF-8"
)

temporary_module_lines <- readLines(
  temporary_module,
  warn = FALSE,
  encoding = "UTF-8"
)

if (any(grepl(
  'msg("Reading input table.")',
  temporary_source_lines,
  fixed = TRUE
))) {
  stop(
    "The analytical workflow remains in temporary cancerppir.R.",
    call. = FALSE
  )
}

if (
  sum(grepl(
    "run_cancerppir <- function",
    temporary_module_lines,
    fixed = TRUE
  )) != 1L
) {
  stop(
    "Temporary R/07_pipeline.R does not contain exactly one run_cancerppir() definition.",
    call. = FALSE
  )
}

if (
  sum(grepl(
    "run_cancerppir(",
    temporary_source_lines,
    fixed = TRUE
  )) != 1L
) {
  stop(
    "Temporary cancerppir.R does not contain exactly one run_cancerppir() call.",
    call. = FALSE
  )
}

write_completed <- FALSE

on.exit(
  {
    if (!write_completed) {
      write_raw_file(
        source_file,
        source_raw_before
      )

      write_raw_file(
        module_file,
        module_raw_before
      )

      unlink(
        c(
          manifest_file,
          validation_file
        ),
        force = TRUE
      )

      message(
        "[pipeline extraction] Original analytical files were restored."
      )
    }

    unlink(
      temporary_directory,
      recursive = TRUE,
      force = TRUE
    )
  },
  add = TRUE
)

if (!isTRUE(file.copy(
  temporary_source,
  source_file,
  overwrite = TRUE
))) {
  stop(
    "Failed to update cancerppir.R.",
    call. = FALSE
  )
}

if (!isTRUE(file.copy(
  temporary_module,
  module_file,
  overwrite = TRUE
))) {
  stop(
    "Failed to update R/07_pipeline.R.",
    call. = FALSE
  )
}

invisible(parse(file = source_file))
invisible(parse(file = module_file))

loader_environment <- new.env(
  parent = baseenv()
)

sys.source(
  loader_file,
  envir = loader_environment,
  keep.source = TRUE
)

module_environment <- new.env(
  parent = baseenv()
)

loaded_files <-
  loader_environment$load_cancerppir_modules(
    project_root = ".",
    envir = module_environment
  )

if (length(loaded_files) != 8L) {
  stop(
    paste0(
      "Expected eight loaded module files, observed ",
      length(loaded_files),
      "."
    ),
    call. = FALSE
  )
}

if (!exists(
  "run_cancerppir",
  envir = module_environment,
  inherits = FALSE
)) {
  stop(
    "run_cancerppir() is unavailable through the module loader.",
    call. = FALSE
  )
}

pipeline_function <- get(
  "run_cancerppir",
  envir = module_environment,
  inherits = FALSE
)

if (!is.function(pipeline_function)) {
  stop(
    "run_cancerppir is not a function.",
    call. = FALSE
  )
}

if (!identical(
  names(formals(pipeline_function)),
  function_arguments
)) {
  stop(
    paste0(
      "Unexpected run_cancerppir() arguments:\n",
      paste(
        names(formals(pipeline_function)),
        collapse = ", "
      )
    ),
    call. = FALSE
  )
}

legacy_md5_after <- unname(
  tools::md5sum(legacy_file)
)

if (!identical(
  legacy_md5_after,
  expected_legacy_md5
)) {
  stop(
    "legacy/cancerppir_legacy.R was modified.",
    call. = FALSE
  )
}

source_md5_after <- unname(
  tools::md5sum(source_file)
)

module_md5_after <- unname(
  tools::md5sum(module_file)
)

source_expression_count <- length(
  parse(file = source_file)
)

module_expression_count <- length(
  parse(file = module_file)
)

manifest <- data.frame(
  checkpoint = "2.12",
  item_type = c(
    "runtime_dependency_setup",
    "pipeline_workflow",
    rep("function_argument", length(function_arguments))
  ),
  item_name = c(
    "package_checks_and_runtime_libraries",
    "run_cancerppir",
    function_arguments
  ),
  source_start_line = c(
    package_start_line,
    pipeline_start_line,
    rep(NA_integer_, length(function_arguments))
  ),
  source_end_line = c(
    package_end_line,
    pipeline_end_line,
    rep(NA_integer_, length(function_arguments))
  ),
  target_file = module_file,
  stringsAsFactors = FALSE
)

dir.create(
  dirname(manifest_file),
  recursive = TRUE,
  showWarnings = FALSE
)

utils::write.csv(
  manifest,
  manifest_file,
  row.names = FALSE,
  na = ""
)

validation_lines <- c(
  "CancerPPIr checkpoint 2.12 pipeline extraction",
  "================================================",
  "",
  paste0(
    "cancerppir.R MD5 before: ",
    source_md5_before
  ),
  paste0(
    "cancerppir.R MD5 after: ",
    source_md5_after
  ),
  paste0(
    "R/07_pipeline.R MD5 before: ",
    module_md5_before
  ),
  paste0(
    "R/07_pipeline.R MD5 after: ",
    module_md5_after
  ),
  paste0(
    "Runtime dependency block moved: lines ",
    package_start_line,
    "-",
    package_end_line
  ),
  paste0(
    "Pipeline block moved: lines ",
    pipeline_start_line,
    "-",
    pipeline_end_line
  ),
  paste0(
    "run_cancerppir() arguments: ",
    paste(
      function_arguments,
      collapse = ", "
    )
  ),
  "run_cancerppir() available through loader: TRUE",
  paste0(
    "Loaded module files: ",
    length(loaded_files)
  ),
  paste0(
    "CLI top-level expressions after extraction: ",
    source_expression_count
  ),
  paste0(
    "Pipeline module top-level expressions: ",
    module_expression_count
  ),
  paste0(
    "Legacy MD5 unchanged: ",
    legacy_md5_after
  )
)

writeLines(
  validation_lines,
  validation_file,
  useBytes = TRUE
)

write_completed <- TRUE

message(
  "[pipeline extraction] Extraction completed."
)

message(
  "[pipeline extraction] Runtime dependency setup moved: lines ",
  package_start_line,
  "-",
  package_end_line,
  "."
)

message(
  "[pipeline extraction] Pipeline workflow moved: lines ",
  pipeline_start_line,
  "-",
  pipeline_end_line,
  "."
)

message(
  "[pipeline extraction] run_cancerppir() available through loader."
)

message(
  "[pipeline extraction] CLI top-level expressions: ",
  source_expression_count,
  "."
)

message(
  "[pipeline extraction] cancerppir.R MD5 before: ",
  source_md5_before
)

message(
  "[pipeline extraction] cancerppir.R MD5 after:  ",
  source_md5_after
)

message(
  "[pipeline extraction] Manifest: ",
  manifest_file
)

message(
  "[pipeline extraction] Validation: ",
  validation_file
)

message(
  "[pipeline extraction] legacy/cancerppir_legacy.R was not modified."
)