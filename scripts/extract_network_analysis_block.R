#!/usr/bin/env Rscript

# Extract the current network-analysis orchestration block from cancerppir.R
# into R/06_network_analysis.R as run_network_analysis().
#
# The analytical statements are moved without semantic rewriting.
#
# Run from the repository root:
#   Rscript scripts/extract_network_analysis_block.R

source_file <- "cancerppir.R"
module_file <- file.path("R", "06_network_analysis.R")
loader_file <- file.path("R", "load_all.R")
legacy_file <- file.path("legacy", "cancerppir_legacy.R")

manifest_file <- file.path(
  "docs",
  "architecture",
  "checkpoint_2_11_network_analysis_extraction.csv"
)

validation_file <- file.path(
  "docs",
  "architecture",
  "checkpoint_2_11_network_analysis_validation.txt"
)

expected_source_md5 <- "f31c1e473a0ee401e1e5b27dcea1030e"
expected_legacy_md5 <- "0c5644140abbae2f17e30109432cc198"

input_objects <- c(
  "string_db",
  "mapped_final",
  "input_tbl",
  "mapped_initial",
  "mapped_final_raw",
  "valid_alias_corrections",
  "initial_mapped",
  "initial_unmapped",
  "initial_pct",
  "after_mapped",
  "after_unmapped",
  "after_pct",
  "score_threshold",
  "top_n"
)

output_objects <- c(
  "ppi",
  "comp",
  "node_metrics",
  "top_n",
  "top_candidates",
  "top_by_degree",
  "top_by_betweenness",
  "top_by_stress",
  "degree_distribution",
  "module_summary",
  "major_module_ids",
  "graph_summary",
  "mapping_summary",
  "gene_status",
  "still_unmapped"
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
    "git",
    c(
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

  stop(
    paste0(
      path,
      " differs from the committed HEAD version.\n",
      "Inspect, commit or restore it before extraction."
    ),
    call. = FALSE
  )
}

assert_matches_head(source_file)
assert_matches_head(module_file)

source_md5_before <- unname(
  tools::md5sum(source_file)
)

if (!identical(
  source_md5_before,
  expected_source_md5
)) {
  stop(
    paste0(
      "Unexpected cancerppir.R checksum.\n",
      "Expected: ",
      expected_source_md5,
      "\nObserved: ",
      source_md5_before
    ),
    call. = FALSE
  )
}

legacy_md5 <- unname(
  tools::md5sum(legacy_file)
)

if (!identical(
  legacy_md5,
  expected_legacy_md5
)) {
  stop(
    paste0(
      "Unexpected legacy checksum.\n",
      "Expected: ",
      expected_legacy_md5,
      "\nObserved: ",
      legacy_md5
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
  "run_network_analysis <- function",
  module_lines,
  fixed = TRUE
))) {
  stop(
    "R/06_network_analysis.R already defines run_network_analysis().",
    call. = FALSE
  )
}

parsed <- parse(
  file = source_file,
  keep.source = TRUE
)

source_references <- attr(
  parsed,
  "srcref"
)

if (
  is.null(source_references) ||
    length(source_references) != length(parsed)
) {
  stop(
    "Could not obtain source ranges for cancerppir.R.",
    call. = FALSE
  )
}

find_marker_line <- function(marker) {
  matches <- which(
    trimws(source_lines) == marker
  )

  if (length(matches) != 1L) {
    stop(
      paste0(
        "Expected exactly one marker:\n",
        marker,
        "\nObserved matches: ",
        length(matches)
      ),
      call. = FALSE
    )
  }

  as.integer(matches[[1L]])
}

find_expression_index <- function(line_number) {
  matches <- which(
    vapply(
      source_references,
      function(reference) {
        start_line <- as.integer(reference[[1L]])
        end_line <- as.integer(reference[[3L]])

        start_line <= line_number &&
          end_line >= line_number
      },
      FUN.VALUE = logical(1)
    )
  )

  if (length(matches) != 1L) {
    stop(
      paste0(
        "Could not resolve expression containing line ",
        line_number,
        "."
      ),
      call. = FALSE
    )
  }

  as.integer(matches[[1L]])
}

start_marker <- 'msg("Building STRING subnetwork.")'
next_block_marker <- "enrichment_string_online_all <- tibble()"

start_marker_line <- find_marker_line(start_marker)
next_block_marker_line <- find_marker_line(next_block_marker)

start_expression_index <- find_expression_index(
  start_marker_line
)

next_block_expression_index <- find_expression_index(
  next_block_marker_line
)

end_expression_index <- next_block_expression_index - 1L

if (end_expression_index < start_expression_index) {
  stop(
    "Invalid network-analysis expression boundaries.",
    call. = FALSE
  )
}

start_line <- as.integer(
  source_references[[start_expression_index]][[1L]]
)

end_line <- as.integer(
  source_references[[end_expression_index]][[3L]]
)

if (
  start_line != 404L ||
    end_line != 689L
) {
  stop(
    paste0(
      "Unexpected network block boundaries.\n",
      "Expected lines: 404-689\n",
      "Observed lines: ",
      start_line,
      "-",
      end_line
    ),
    call. = FALSE
  )
}

network_block <- source_lines[
  start_line:end_line
]

indented_network_block <- ifelse(
  nzchar(network_block),
  paste0("  ", network_block),
  ""
)

function_signature <- c(
  "run_network_analysis <- function(",
  paste0(
    "  ",
    input_objects,
    ifelse(
      seq_along(input_objects) <
        length(input_objects),
      ",",
      ""
    )
  ),
  ") {"
)

return_block <- c(
  "",
  "  list(",
  paste0(
    "    ",
    output_objects,
    " = ",
    output_objects,
    ifelse(
      seq_along(output_objects) <
        length(output_objects),
      ",",
      ""
    )
  ),
  "  )",
  "}"
)

new_module_lines <- c(
  module_lines,
  "",
  "# -----------------------------------------------------------------------------",
  "# Network construction, metrics, Louvain modules and candidate prioritization",
  "# Architecture checkpoint 2.11",
  "# -----------------------------------------------------------------------------",
  "",
  function_signature,
  indented_network_block,
  return_block
)

call_lines <- c(
  "network_analysis <- run_network_analysis(",
  paste0(
    "  ",
    input_objects,
    " = ",
    input_objects,
    ifelse(
      seq_along(input_objects) <
        length(input_objects),
      ",",
      ""
    )
  ),
  ")",
  "",
  paste0(
    output_objects,
    " <- network_analysis$",
    output_objects
  ),
  "",
  "rm(network_analysis)"
)

new_source_lines <- c(
  if (start_line > 1L) {
    source_lines[
      seq_len(start_line - 1L)
    ]
  } else {
    character()
  },
  call_lines,
  if (end_line < length(source_lines)) {
    source_lines[
      seq.int(
        end_line + 1L,
        length(source_lines)
      )
    ]
  } else {
    character()
  }
)

temporary_directory <- tempfile(
  pattern = "cancerppir-network-extraction-"
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
  "06_network_analysis.R"
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

if (any(trimws(temporary_source_lines) == start_marker)) {
  stop(
    "The original network block remains in temporary cancerppir.R.",
    call. = FALSE
  )
}

if (
  sum(grepl(
    "run_network_analysis <- function",
    temporary_module_lines,
    fixed = TRUE
  )) != 1L
) {
  stop(
    "Temporary network module does not contain exactly one function definition.",
    call. = FALSE
  )
}

if (
  sum(grepl(
    "network_analysis <- run_network_analysis(",
    temporary_source_lines,
    fixed = TRUE
  )) != 1L
) {
  stop(
    "Temporary cancerppir.R does not contain exactly one network-analysis call.",
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
        "[network extraction] Original analytical files were restored."
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
    "Failed to update R/06_network_analysis.R.",
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
  "run_network_analysis",
  envir = module_environment,
  inherits = FALSE
)) {
  stop(
    "run_network_analysis() is unavailable through the module loader.",
    call. = FALSE
  )
}

network_function <- get(
  "run_network_analysis",
  envir = module_environment,
  inherits = FALSE
)

if (!is.function(network_function)) {
  stop(
    "run_network_analysis is not a function.",
    call. = FALSE
  )
}

if (!identical(
  names(formals(network_function)),
  input_objects
)) {
  stop(
    paste0(
      "Unexpected function arguments:\n",
      paste(
        names(formals(network_function)),
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

manifest <- data.frame(
  checkpoint = "2.11",
  item_name = c(
    input_objects,
    output_objects
  ),
  interface_role = c(
    rep("input", length(input_objects)),
    rep("output", length(output_objects))
  ),
  source_start_line = start_line,
  source_end_line = end_line,
  source_expression_start = start_expression_index,
  source_expression_end = end_expression_index,
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
  "CancerPPIr checkpoint 2.11 network-analysis extraction",
  "======================================================",
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
    "R/06_network_analysis.R MD5 after: ",
    module_md5_after
  ),
  paste0(
    "Source block moved: lines ",
    start_line,
    "-",
    end_line
  ),
  paste0(
    "Top-level expressions moved: ",
    end_expression_index -
      start_expression_index + 1L
  ),
  paste0(
    "Explicit inputs: ",
    length(input_objects)
  ),
  paste0(
    "Returned outputs: ",
    length(output_objects)
  ),
  "run_network_analysis() available through loader: TRUE",
  paste0(
    "Loaded module files: ",
    length(loaded_files)
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
  "[network extraction] Extraction completed."
)

message(
  "[network extraction] Source block moved: lines ",
  start_line,
  "-",
  end_line,
  "."
)

message(
  "[network extraction] Explicit inputs: ",
  length(input_objects),
  "."
)

message(
  "[network extraction] Returned outputs: ",
  length(output_objects),
  "."
)

message(
  "[network extraction] run_network_analysis() available through loader."
)

message(
  "[network extraction] cancerppir.R MD5 before: ",
  source_md5_before
)

message(
  "[network extraction] cancerppir.R MD5 after:  ",
  source_md5_after
)

message(
  "[network extraction] Manifest: ",
  manifest_file
)

message(
  "[network extraction] Validation: ",
  validation_file
)

message(
  "[network extraction] legacy/cancerppir_legacy.R was not modified."
)