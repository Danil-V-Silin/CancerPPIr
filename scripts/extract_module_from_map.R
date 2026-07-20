#!/usr/bin/env Rscript

# Extract one group of top-level functions from cancerppir.R into a target
# module according to docs/architecture/target_function_module_map.csv.
#
# Usage:
#   Rscript scripts/extract_module_from_map.R \
#     <target_file> <expected_count> <checkpoint> <module_label>
#
# Example:
#   Rscript scripts/extract_module_from_map.R \
#     R/03_enrichment.R 15 2.7 enrichment

arguments <- commandArgs(
  trailingOnly = TRUE
)

if (length(arguments) != 4L) {
  stop(
    paste0(
      "Expected four arguments:\n",
      "1. target module file\n",
      "2. expected function count\n",
      "3. checkpoint number\n",
      "4. module label\n\n",
      "Example:\n",
      "Rscript scripts/extract_module_from_map.R ",
      "R/03_enrichment.R 15 2.7 enrichment"
    ),
    call. = FALSE
  )
}

target_file <- gsub(
  "\\\\",
  "/",
  arguments[[1L]]
)

expected_count <- suppressWarnings(
  as.integer(arguments[[2L]])
)

checkpoint <- arguments[[3L]]
module_label <- arguments[[4L]]

if (
  is.na(expected_count) ||
    expected_count < 1L
) {
  stop(
    "Expected function count must be a positive integer.",
    call. = FALSE
  )
}

source_file <- "cancerppir.R"

legacy_file <- file.path(
  "legacy",
  "cancerppir_legacy.R"
)

loader_file <- file.path(
  "R",
  "load_all.R"
)

function_map_file <- file.path(
  "docs",
  "architecture",
  "target_function_module_map.csv"
)

checkpoint_slug <- gsub(
  "[^A-Za-z0-9]+",
  "_",
  checkpoint
)

module_slug <- gsub(
  "[^A-Za-z0-9]+",
  "_",
  tolower(module_label)
)

manifest_file <- file.path(
  "docs",
  "architecture",
  paste0(
    "checkpoint_",
    checkpoint_slug,
    "_",
    module_slug,
    "_extraction.csv"
  )
)

expected_legacy_md5 <- "0c5644140abbae2f17e30109432cc198"

loader_order <- c(
  "R/00_utils.R",
  "R/01_input.R",
  "R/02_string_mapping.R",
  "R/03_enrichment.R",
  "R/04_module_labeling.R",
  "R/05_reporting.R",
  "R/06_network_analysis.R",
  "R/07_pipeline.R"
)

if (!target_file %in% loader_order) {
  stop(
    paste0(
      "Target file is not part of the approved module architecture:\n",
      target_file
    ),
    call. = FALSE
  )
}

required_files <- c(
  source_file,
  legacy_file,
  target_file,
  loader_file,
  function_map_file
)

missing_files <- required_files[
  !file.exists(required_files)
]

if (length(missing_files) > 0L) {
  stop(
    paste0(
      "Run this script from the CancerPPIr repository root.\n",
      "Required files are missing:\n",
      paste(
        paste0("- ", missing_files),
        collapse = "\n"
      )
    ),
    call. = FALSE
  )
}

if (file.exists(manifest_file)) {
  stop(
    paste0(
      "Extraction manifest already exists:\n",
      manifest_file,
      "\nThe extraction may already have been performed."
    ),
    call. = FALSE
  )
}

assert_clean_against_head <- function(path) {
  exit_code <- system2(
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

  if (identical(exit_code, 0L)) {
    return(
      invisible(TRUE)
    )
  }

  if (identical(exit_code, 1L)) {
    stop(
      paste0(
        path,
        " already differs from the committed HEAD version.\n",
        "Inspect, commit or restore the existing changes before extraction."
      ),
      call. = FALSE
    )
  }

  stop(
    paste0(
      "Git could not verify the state of ",
      path,
      "."
    ),
    call. = FALSE
  )
}

assert_clean_against_head(
  source_file
)

assert_clean_against_head(
  target_file
)

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
  file_size <- as.integer(
    file.info(path)$size
  )

  connection <- file(
    path,
    open = "rb"
  )

  on.exit(
    close(connection),
    add = TRUE
  )

  readBin(
    connection,
    what = "raw",
    n = file_size
  )
}

write_raw_file <- function(
  path,
  contents
) {
  connection <- file(
    path,
    open = "wb"
  )

  on.exit(
    close(connection),
    add = TRUE
  )

  writeBin(
    contents,
    connection
  )

  invisible(path)
}

detect_line_ending <- function(raw_contents) {
  text <- rawToChar(
    raw_contents
  )

  if (grepl(
    "\r\n",
    text,
    fixed = TRUE
  )) {
    return("\r\n")
  }

  "\n"
}

write_text_file <- function(
  lines,
  path,
  line_ending = "\n"
) {
  text <- if (length(lines) == 0L) {
    ""
  } else {
    paste0(
      paste(
        lines,
        collapse = line_ending
      ),
      line_ending
    )
  }

  write_raw_file(
    path,
    charToRaw(
      enc2utf8(text)
    )
  )
}

text_md5 <- function(lines) {
  temporary_file <- tempfile(
    fileext = ".txt"
  )

  on.exit(
    unlink(
      temporary_file,
      force = TRUE
    ),
    add = TRUE
  )

  write_text_file(
    lines,
    temporary_file,
    line_ending = "\n"
  )

  unname(
    tools::md5sum(temporary_file)
  )
}

get_call_name <- function(expression) {
  if (!is.call(expression)) {
    return(NA_character_)
  }

  call_head <- expression[[1L]]

  if (is.symbol(call_head)) {
    return(
      as.character(call_head)
    )
  }

  if (is.call(call_head)) {
    return(
      paste(
        deparse(
          call_head,
          width.cutoff = 500L
        ),
        collapse = ""
      )
    )
  }

  NA_character_
}

get_assignment_name <- function(expression) {
  call_name <- get_call_name(
    expression
  )

  if (
    is.na(call_name) ||
      !call_name %in% c("<-", "=")
  ) {
    return(NA_character_)
  }

  target <- expression[[2L]]

  if (is.symbol(target)) {
    return(
      as.character(target)
    )
  }

  NA_character_
}

is_function_definition <- function(expression) {
  call_name <- get_call_name(
    expression
  )

  if (
    is.na(call_name) ||
      !call_name %in% c("<-", "=") ||
      length(expression) < 3L
  ) {
    return(FALSE)
  }

  assigned_value <- expression[[3L]]

  is.call(assigned_value) &&
    identical(
      get_call_name(assigned_value),
      "function"
    )
}

empty_inventory <- function() {
  data.frame(
    function_name = character(),
    expression_index = integer(),
    start_line = integer(),
    end_line = integer(),
    line_span = integer(),
    stringsAsFactors = FALSE
  )
}

inventory_top_level_functions <- function(path) {
  parsed <- parse(
    file = path,
    keep.source = TRUE
  )

  if (length(parsed) == 0L) {
    return(
      empty_inventory()
    )
  }

  source_references <- attr(
    parsed,
    "srcref"
  )

  if (
    is.null(source_references) ||
      length(source_references) != length(parsed)
  ) {
    stop(
      paste0(
        "Source references could not be extracted from ",
        path,
        "."
      ),
      call. = FALSE
    )
  }

  rows <- list()
  row_index <- 1L

  for (expression_index in seq_along(parsed)) {
    expression <- parsed[[expression_index]]

    if (!is_function_definition(expression)) {
      next
    }

    source_reference <- source_references[[
      expression_index
    ]]

    if (
      is.null(source_reference) ||
        length(source_reference) < 3L
    ) {
      stop(
        paste0(
          "A top-level function in ",
          path,
          " has no usable source range."
        ),
        call. = FALSE
      )
    }

    start_line <- as.integer(
      source_reference[[1L]]
    )

    end_line <- as.integer(
      source_reference[[3L]]
    )

    rows[[row_index]] <- data.frame(
      function_name = get_assignment_name(
        expression
      ),
      expression_index = expression_index,
      start_line = start_line,
      end_line = end_line,
      line_span = end_line - start_line + 1L,
      stringsAsFactors = FALSE
    )

    row_index <- row_index + 1L
  }

  if (length(rows) == 0L) {
    return(
      empty_inventory()
    )
  }

  do.call(
    rbind,
    rows
  )
}

function_available <- function(
  function_name,
  environment
) {
  exists(
    function_name,
    envir = environment,
    inherits = FALSE
  ) &&
    is.function(
      get(
        function_name,
        envir = environment,
        inherits = FALSE
      )
    )
}

function_map <- utils::read.csv(
  function_map_file,
  stringsAsFactors = FALSE,
  check.names = FALSE
)

required_map_columns <- c(
  "function_name",
  "target_file"
)

missing_map_columns <- setdiff(
  required_map_columns,
  names(function_map)
)

if (length(missing_map_columns) > 0L) {
  stop(
    paste0(
      "Architecture map is missing columns: ",
      paste(
        missing_map_columns,
        collapse = ", "
      )
    ),
    call. = FALSE
  )
}

function_map$target_file <- gsub(
  "\\\\",
  "/",
  function_map$target_file
)

target_map <- function_map[
  function_map$target_file == target_file,
  ,
  drop = FALSE
]

target_names <- target_map$function_name

if (length(target_names) != expected_count) {
  stop(
    paste0(
      "Unexpected number of functions assigned to ",
      target_file,
      ".\nExpected: ",
      expected_count,
      "\nObserved: ",
      length(target_names)
    ),
    call. = FALSE
  )
}

if (
  anyNA(target_names) ||
    any(!nzchar(target_names)) ||
    anyDuplicated(target_names)
) {
  stop(
    "Target function mapping contains missing or duplicated names.",
    call. = FALSE
  )
}

source_inventory <- inventory_top_level_functions(
  source_file
)

target_inventory_before <- inventory_top_level_functions(
  target_file
)

if (nrow(target_inventory_before) != 0L) {
  stop(
    paste0(
      target_file,
      " already contains function definitions."
    ),
    call. = FALSE
  )
}

source_counts <- table(
  source_inventory$function_name
)

missing_target_functions <- target_names[
  !target_names %in%
    source_inventory$function_name
]

if (length(missing_target_functions) > 0L) {
  stop(
    paste0(
      "Functions missing from cancerppir.R:\n",
      paste(
        paste0(
          "- ",
          missing_target_functions
        ),
        collapse = "\n"
      )
    ),
    call. = FALSE
  )
}

invalid_definition_counts <- target_names[
  source_counts[target_names] != 1L
]

if (length(invalid_definition_counts) > 0L) {
  stop(
    paste0(
      "Functions not defined exactly once in cancerppir.R:\n",
      paste(
        paste0(
          "- ",
          invalid_definition_counts
        ),
        collapse = "\n"
      )
    ),
    call. = FALSE
  )
}

source_raw_before <- read_raw_file(
  source_file
)

target_raw_before <- read_raw_file(
  target_file
)

source_md5_before <- unname(
  tools::md5sum(source_file)
)

source_line_ending <- detect_line_ending(
  source_raw_before
)

source_lines <- readLines(
  source_file,
  warn = FALSE,
  encoding = "UTF-8"
)

selected_inventory <- source_inventory[
  match(
    target_names,
    source_inventory$function_name
  ),
  ,
  drop = FALSE
]

selected_inventory <- selected_inventory[
  order(
    selected_inventory$start_line,
    selected_inventory$function_name
  ),
  ,
  drop = FALSE
]

function_blocks <- lapply(
  seq_len(nrow(selected_inventory)),
  function(row_index) {
    start_line <- selected_inventory$start_line[[
      row_index
    ]]

    end_line <- selected_inventory$end_line[[
      row_index
    ]]

    source_lines[
      start_line:end_line
    ]
  }
)

names(function_blocks) <- selected_inventory$function_name

module_lines <- c(
  paste0(
    "# CancerPPIr: ",
    module_label
  ),
  "#",
  paste0(
    "# Architecture checkpoint ",
    checkpoint,
    "."
  ),
  "#",
  paste0(
    "# Functions below were extracted from cancerppir.R ",
    "without semantic rewriting."
  ),
  ""
)

for (row_index in seq_len(nrow(selected_inventory))) {
  function_name <- selected_inventory$function_name[[
    row_index
  ]]

  start_line <- selected_inventory$start_line[[
    row_index
  ]]

  end_line <- selected_inventory$end_line[[
    row_index
  ]]

  module_lines <- c(
    module_lines,
    paste(
      rep("#", 78L),
      collapse = ""
    ),
    paste0(
      "# ",
      function_name,
      " - extracted from cancerppir.R lines ",
      start_line,
      "-",
      end_line
    ),
    paste(
      rep("#", 78L),
      collapse = ""
    ),
    function_blocks[[function_name]],
    ""
  )
}

remove_lines <- rep(
  FALSE,
  length(source_lines)
)

for (row_index in seq_len(nrow(selected_inventory))) {
  start_line <- selected_inventory$start_line[[
    row_index
  ]]

  end_line <- selected_inventory$end_line[[
    row_index
  ]]

  remove_lines[
    start_line:end_line
  ] <- TRUE
}

modified_source_lines <- source_lines[
  !remove_lines
]

loader_marker <- "# Load extracted CancerPPIr source modules."

loader_marker_count <- sum(
  grepl(
    loader_marker,
    modified_source_lines,
    fixed = TRUE
  )
)

if (loader_marker_count != 1L) {
  stop(
    paste0(
      "Expected exactly one module-loader marker in cancerppir.R, found ",
      loader_marker_count,
      "."
    ),
    call. = FALSE
  )
}

temporary_directory <- tempfile(
  pattern = "cancerppir-module-extraction-"
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

temporary_target <- file.path(
  temporary_directory,
  basename(target_file)
)

write_text_file(
  modified_source_lines,
  temporary_source,
  line_ending = source_line_ending
)

write_text_file(
  module_lines,
  temporary_target,
  line_ending = "\n"
)

invisible(
  parse(
    file = temporary_source,
    keep.source = TRUE
  )
)

invisible(
  parse(
    file = temporary_target,
    keep.source = TRUE
  )
)

temporary_source_inventory <-
  inventory_top_level_functions(
    temporary_source
  )

temporary_target_inventory <-
  inventory_top_level_functions(
    temporary_target
  )

remaining_target_functions <- intersect(
  target_names,
  temporary_source_inventory$function_name
)

if (length(remaining_target_functions) > 0L) {
  stop(
    paste0(
      "Definitions remain in temporary cancerppir.R:\n",
      paste(
        paste0(
          "- ",
          remaining_target_functions
        ),
        collapse = "\n"
      )
    ),
    call. = FALSE
  )
}

if (!identical(
  sort(temporary_target_inventory$function_name),
  sort(target_names)
)) {
  stop(
    paste0(
      "Temporary ",
      target_file,
      " does not contain exactly the expected functions."
    ),
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
        target_file,
        target_raw_before
      )

      if (file.exists(manifest_file)) {
        unlink(
          manifest_file,
          force = TRUE
        )
      }

      message(
        "[module extraction] Original files were restored."
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

source_copy_success <- file.copy(
  temporary_source,
  source_file,
  overwrite = TRUE
)

target_copy_success <- file.copy(
  temporary_target,
  target_file,
  overwrite = TRUE
)

if (
  !isTRUE(source_copy_success) ||
    !isTRUE(target_copy_success)
) {
  stop(
    "Failed to write extracted source files.",
    call. = FALSE
  )
}

invisible(
  parse(
    file = source_file,
    keep.source = TRUE
  )
)

invisible(
  parse(
    file = target_file,
    keep.source = TRUE
  )
)

source_inventory_after <- inventory_top_level_functions(
  source_file
)

target_inventory_after <- inventory_top_level_functions(
  target_file
)

remaining_after_write <- intersect(
  target_names,
  source_inventory_after$function_name
)

if (length(remaining_after_write) > 0L) {
  stop(
    "Target function definitions remain in cancerppir.R after extraction.",
    call. = FALSE
  )
}

if (!identical(
  sort(target_inventory_after$function_name),
  sort(target_names)
)) {
  stop(
    paste0(
      target_file,
      " failed post-write function validation."
    ),
    call. = FALSE
  )
}

loader_environment <- new.env(
  parent = baseenv()
)

sys.source(
  loader_file,
  envir = loader_environment,
  keep.source = TRUE
)

if (
  !exists(
    "load_cancerppir_modules",
    envir = loader_environment,
    inherits = FALSE
  )
) {
  stop(
    "R/load_all.R did not define load_cancerppir_modules().",
    call. = FALSE
  )
}

module_environment <- new.env(
  parent = baseenv()
)

loaded_modules <-
  loader_environment$load_cancerppir_modules(
    project_root = ".",
    envir = module_environment
  )

current_module_index <- match(
  target_file,
  loader_order
)

validated_target_files <- loader_order[
  seq_len(current_module_index)
]

expected_loaded_names <- function_map$function_name[
  function_map$target_file %in%
    validated_target_files
]

loaded_status <- vapply(
  expected_loaded_names,
  function_available,
  environment = module_environment,
  FUN.VALUE = logical(1)
)

if (!all(loaded_status)) {
  missing_loaded_functions <- expected_loaded_names[
    !loaded_status
  ]

  stop(
    paste0(
      "Loader did not expose all extracted functions:\n",
      paste(
        paste0(
          "- ",
          missing_loaded_functions
        ),
        collapse = "\n"
      )
    ),
    call. = FALSE
  )
}

manifest <- data.frame(
  checkpoint = checkpoint,
  function_name = selected_inventory$function_name,
  original_start_line =
    selected_inventory$start_line,
  original_end_line =
    selected_inventory$end_line,
  original_line_span =
    selected_inventory$line_span,
  original_text_md5 = vapply(
    function_blocks,
    text_md5,
    FUN.VALUE = character(1)
  ),
  target_file = target_file,
  extraction_mode =
    "exact_source_range_without_semantic_rewrite",
  stringsAsFactors = FALSE
)

utils::write.csv(
  manifest,
  manifest_file,
  row.names = FALSE,
  na = ""
)

source_md5_after <- unname(
  tools::md5sum(source_file)
)

target_md5_after <- unname(
  tools::md5sum(target_file)
)

write_completed <- TRUE

message(
  "[module extraction] Extraction completed."
)

message(
  "[module extraction] Checkpoint: ",
  checkpoint
)

message(
  "[module extraction] Target module: ",
  target_file
)

message(
  "[module extraction] Functions moved: ",
  nrow(manifest),
  "."
)

message(
  "[module extraction] Target functions remaining in cancerppir.R: 0."
)

message(
  "[module extraction] Extracted functions available through loader: ",
  sum(loaded_status),
  "/",
  length(loaded_status),
  "."
)

message(
  "[module extraction] Loaded module files: ",
  length(loaded_modules),
  "."
)

message(
  "[module extraction] cancerppir.R MD5 before: ",
  source_md5_before
)

message(
  "[module extraction] cancerppir.R MD5 after:  ",
  source_md5_after
)

message(
  "[module extraction] ",
  target_file,
  " MD5: ",
  target_md5_after
)

message(
  "[module extraction] Manifest: ",
  manifest_file
)

message(
  "[module extraction] legacy/cancerppir_legacy.R was not modified."
)