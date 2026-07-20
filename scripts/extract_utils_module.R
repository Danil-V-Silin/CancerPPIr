#!/usr/bin/env Rscript

# Extract the dependency-light utility functions from the monolithic
# cancerppir.R file into R/00_utils.R.
#
# This checkpoint performs an architecture-only change:
# - function bodies are copied without semantic rewriting;
# - original definitions are removed from cancerppir.R;
# - the explicit R/load_all.R loader is connected to cancerppir.R;
# - all changes are validated before they are retained.
#
# Run once from the repository root:
#   Rscript scripts/extract_utils_module.R

source_file <- "cancerppir.R"
legacy_file <- file.path(
  "legacy",
  "cancerppir_legacy.R"
)

module_file <- file.path(
  "R",
  "00_utils.R"
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

manifest_file <- file.path(
  "docs",
  "architecture",
  "checkpoint_2_4_utils_extraction.csv"
)

expected_legacy_md5 <- "0c5644140abbae2f17e30109432cc198"

required_files <- c(
  source_file,
  legacy_file,
  module_file,
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
      "The extraction manifest already exists:\n",
      manifest_file,
      "\nThis script is intended to run only once."
    ),
    call. = FALSE
  )
}

source_md5_before <- unname(
  tools::md5sum(source_file)
)

legacy_md5 <- unname(
  tools::md5sum(legacy_file)
)

if (!identical(source_md5_before, expected_legacy_md5)) {
  stop(
    paste0(
      "The current cancerppir.R checksum is unexpected.\n",
      "Expected: ",
      expected_legacy_md5,
      "\nObserved: ",
      source_md5_before,
      "\nNo files were changed."
    ),
    call. = FALSE
  )
}

if (!identical(legacy_md5, expected_legacy_md5)) {
  stop(
    paste0(
      "The preserved legacy implementation has an unexpected checksum.\n",
      "Expected: ",
      expected_legacy_md5,
      "\nObserved: ",
      legacy_md5,
      "\nNo files were changed."
    ),
    call. = FALSE
  )
}

read_raw_file <- function(path) {
  file_size <- file.info(path)$size

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

write_raw_file <- function(path, contents) {
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

  if (grepl("\r\n", text, fixed = TRUE)) {
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

  raw_text <- charToRaw(
    enc2utf8(text)
  )

  write_raw_file(
    path,
    raw_text
  )
}

text_md5 <- function(lines) {
  temporary_file <- tempfile(
    fileext = ".txt"
  )

  on.exit(
    unlink(temporary_file),
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

  call_head <- expression[[1]]

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

  target <- expression[[2]]

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
      !call_name %in% c("<-", "=")
  ) {
    return(FALSE)
  }

  if (length(expression) < 3L) {
    return(FALSE)
  }

  assigned_value <- expression[[3]]

  is.call(assigned_value) &&
    identical(
      get_call_name(assigned_value),
      "function"
    )
}

inventory_top_level_functions <- function(path) {
  parsed <- parse(
    file = path,
    keep.source = TRUE
  )

  if (length(parsed) == 0L) {
    return(
      data.frame(
        function_name = character(),
        expression_index = integer(),
        start_line = integer(),
        end_line = integer(),
        line_span = integer(),
        stringsAsFactors = FALSE
      )
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
          "A function in ",
          path,
          " has no usable source range."
        ),
        call. = FALSE
      )
    }

    start_line <- as.integer(
      source_reference[[1]]
    )

    end_line <- as.integer(
      source_reference[[3]]
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
      data.frame(
        function_name = character(),
        expression_index = integer(),
        start_line = integer(),
        end_line = integer(),
        line_span = integer(),
        stringsAsFactors = FALSE
      )
    )
  }

  do.call(
    rbind,
    rows
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
      "The architecture function map is missing columns: ",
      paste(
        missing_map_columns,
        collapse = ", "
      )
    ),
    call. = FALSE
  )
}

utility_map <- function_map[
  function_map$target_file == "R/00_utils.R",
  ,
  drop = FALSE
]

utility_names <- utility_map$function_name

if (length(utility_names) != 21L) {
  stop(
    paste0(
      "Expected 21 utility functions in the architecture map, found ",
      length(utility_names),
      "."
    ),
    call. = FALSE
  )
}

if (anyDuplicated(utility_names)) {
  stop(
    "The utility-function map contains duplicated names.",
    call. = FALSE
  )
}

source_inventory <- inventory_top_level_functions(
  source_file
)

module_inventory_before <- inventory_top_level_functions(
  module_file
)

if (nrow(module_inventory_before) != 0L) {
  stop(
    paste0(
      module_file,
      " already contains function definitions. ",
      "No files were changed."
    ),
    call. = FALSE
  )
}

source_function_counts <- table(
  source_inventory$function_name
)

missing_utility_functions <- utility_names[
  !utility_names %in%
    source_inventory$function_name
]

if (length(missing_utility_functions) > 0L) {
  stop(
    paste0(
      "Utility functions missing from cancerppir.R: ",
      paste(
        missing_utility_functions,
        collapse = ", "
      )
    ),
    call. = FALSE
  )
}

duplicated_source_functions <- utility_names[
  source_function_counts[utility_names] != 1L
]

if (length(duplicated_source_functions) > 0L) {
  stop(
    paste0(
      "Utility functions not defined exactly once in cancerppir.R: ",
      paste(
        duplicated_source_functions,
        collapse = ", "
      )
    ),
    call. = FALSE
  )
}

source_raw_before <- read_raw_file(
  source_file
)

module_raw_before <- read_raw_file(
  module_file
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
    utility_names,
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
  "# CancerPPIr: Shared utilities",
  "#",
  paste0(
    "# Dependency-light validation, normalization, numeric, ranking ",
    "and shared text helpers."
  ),
  "#",
  "# Architecture checkpoint 2.4",
  "#",
  paste0(
    "# The function bodies below were extracted from cancerppir.R ",
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

remaining_source_lines <- source_lines[
  !remove_lines
]

loader_marker <- "# Load extracted CancerPPIr source modules."

if (
  any(
    grepl(
      loader_marker,
      remaining_source_lines,
      fixed = TRUE
    )
  )
) {
  stop(
    paste0(
      "The CancerPPIr module-loader block is already present in ",
      source_file,
      "."
    ),
    call. = FALSE
  )
}

loader_block <- c(
  "",
  loader_marker,
  ".cancerppir_file_argument <- grep(",
  "  \"^--file=\",",
  "  commandArgs(trailingOnly = FALSE),",
  "  value = TRUE",
  ")",
  "",
  ".cancerppir_project_root <- if (",
  "  length(.cancerppir_file_argument) >= 1L",
  ") {",
  "  dirname(",
  "    normalizePath(",
  "      sub(",
  "        \"^--file=\",",
  "        \"\",",
  "        .cancerppir_file_argument[[1L]]",
  "      ),",
  "      winslash = \"/\",",
  "      mustWork = TRUE",
  "    )",
  "  )",
  "} else {",
  "  normalizePath(",
  "    \".\",",
  "    winslash = \"/\",",
  "    mustWork = TRUE",
  "  )",
  "}",
  "",
  "source(",
  "  file.path(",
  "    .cancerppir_project_root,",
  "    \"R\",",
  "    \"load_all.R\"",
  "  ),",
  "  local = TRUE",
  ")",
  "",
  "load_cancerppir_modules(",
  "  project_root = .cancerppir_project_root,",
  "  envir = environment()",
  ")",
  "",
  "rm(",
  "  .cancerppir_file_argument,",
  "  .cancerppir_project_root",
  ")",
  ""
)

insert_after <- if (
  length(remaining_source_lines) > 0L &&
    grepl(
      "^#!",
      remaining_source_lines[[1L]]
    )
) {
  1L
} else {
  0L
}

modified_source_lines <- append(
  remaining_source_lines,
  loader_block,
  after = insert_after
)

temporary_directory <- tempfile(
  pattern = "cancerppir-utils-extraction-"
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
  "00_utils.R"
)

write_text_file(
  modified_source_lines,
  temporary_source,
  line_ending = source_line_ending
)

write_text_file(
  module_lines,
  temporary_module,
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
    file = temporary_module,
    keep.source = TRUE
  )
)

temporary_source_inventory <-
  inventory_top_level_functions(
    temporary_source
  )

temporary_module_inventory <-
  inventory_top_level_functions(
    temporary_module
  )

utility_functions_left_in_source <- intersect(
  utility_names,
  temporary_source_inventory$function_name
)

if (length(utility_functions_left_in_source) > 0L) {
  stop(
    paste0(
      "Utility definitions remain in the temporary cancerppir.R: ",
      paste(
        utility_functions_left_in_source,
        collapse = ", "
      )
    ),
    call. = FALSE
  )
}

temporary_module_names <- sort(
  temporary_module_inventory$function_name
)

if (!identical(
  temporary_module_names,
  sort(utility_names)
)) {
  stop(
    paste0(
      "The temporary utility module does not contain the expected ",
      "21 functions."
    ),
    call. = FALSE
  )
}

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
      "Expected one module-loader marker, found ",
      loader_marker_count,
      "."
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
        module_file,
        module_raw_before
      )

      if (file.exists(manifest_file)) {
        unlink(
          manifest_file,
          force = TRUE
        )
      }

      message(
        "[utils extraction] Original files were restored."
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

module_copy_success <- file.copy(
  temporary_module,
  module_file,
  overwrite = TRUE
)

if (
  !isTRUE(source_copy_success) ||
    !isTRUE(module_copy_success)
) {
  stop(
    "Failed to write the extracted source files.",
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
    file = module_file,
    keep.source = TRUE
  )
)

source_inventory_after <-
  inventory_top_level_functions(
    source_file
  )

module_inventory_after <-
  inventory_top_level_functions(
    module_file
  )

remaining_utility_definitions <- intersect(
  utility_names,
  source_inventory_after$function_name
)

if (length(remaining_utility_definitions) > 0L) {
  stop(
    paste0(
      "Utility definitions remain in cancerppir.R after extraction: ",
      paste(
        remaining_utility_definitions,
        collapse = ", "
      )
    ),
    call. = FALSE
  )
}

if (!identical(
  sort(module_inventory_after$function_name),
  sort(utility_names)
)) {
  stop(
    "R/00_utils.R failed the post-write function validation.",
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

loaded_utility_status <- vapply(
  utility_names,
  function(function_name) {
    exists(
      function_name,
      envir = module_environment,
      inherits = FALSE
    ) &&
      is.function(
        get(
          function_name,
          envir = module_environment,
          inherits = FALSE
        )
      )
  },
  FUN.VALUE = logical(1)
)

if (!all(loaded_utility_status)) {
  failed_functions <- utility_names[
    !loaded_utility_status
  ]

  stop(
    paste0(
      "The module loader failed to expose utility functions: ",
      paste(
        failed_functions,
        collapse = ", "
      )
    ),
    call. = FALSE
  )
}

manifest <- data.frame(
  checkpoint = "2.4",
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
  target_file = "R/00_utils.R",
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

module_md5_after <- unname(
  tools::md5sum(module_file)
)

write_completed <- TRUE

message(
  "[utils extraction] Utility extraction completed."
)

message(
  "[utils extraction] Functions moved: ",
  nrow(manifest),
  "."
)

message(
  "[utils extraction] Utility functions remaining in cancerppir.R: 0."
)

message(
  "[utils extraction] Utility functions available through loader: ",
  sum(loaded_utility_status),
  "/",
  length(loaded_utility_status),
  "."
)

message(
  "[utils extraction] Loaded module files: ",
  length(loaded_modules),
  "."
)

message(
  "[utils extraction] cancerppir.R MD5 before: ",
  source_md5_before
)

message(
  "[utils extraction] cancerppir.R MD5 after:  ",
  source_md5_after
)

message(
  "[utils extraction] R/00_utils.R MD5:        ",
  module_md5_after
)

message(
  "[utils extraction] Manifest: ",
  manifest_file
)

message(
  "[utils extraction] legacy/cancerppir_legacy.R was not modified."
)