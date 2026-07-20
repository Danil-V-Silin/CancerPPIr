#!/usr/bin/env Rscript

# Extract CancerPPIr HGNC and STRING mapping helpers from cancerppir.R
# into R/02_string_mapping.R.
#
# Checkpoint 2.6:
# - seven existing functions are copied without semantic rewriting;
# - their original definitions are removed from cancerppir.R;
# - previously extracted utility and input modules are preserved;
# - the loader is validated after extraction;
# - source files are restored automatically if validation fails.
#
# Run once from the repository root:
#   Rscript scripts/extract_string_mapping_module.R

source_file <- "cancerppir.R"

legacy_file <- file.path(
  "legacy",
  "cancerppir_legacy.R"
)

module_file <- file.path(
  "R",
  "02_string_mapping.R"
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
  "checkpoint_2_6_string_mapping_extraction.csv"
)

expected_legacy_md5 <- "0c5644140abbae2f17e30109432cc198"

expected_mapping_functions <- c(
  "classify_symbol_pattern",
  "status_from_mapping",
  "pick_string_id_col",
  "pick_alias_col",
  "pick_preferred_name_col",
  "make_string_links",
  "map_to_string"
)

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
      "\nThis extraction script is intended to run only once."
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

read_head_file <- function(repository_path) {
  output_file <- tempfile(
    fileext = ".txt"
  )

  error_file <- tempfile(
    fileext = ".txt"
  )

  on.exit(
    unlink(
      c(
        output_file,
        error_file
      ),
      force = TRUE
    ),
    add = TRUE
  )

  exit_code <- system2(
    command = "git",
    args = c(
      "show",
      paste0(
        "HEAD:",
        repository_path
      )
    ),
    stdout = output_file,
    stderr = error_file
  )

  if (!identical(exit_code, 0L)) {
    error_text <- readLines(
      error_file,
      warn = FALSE,
      encoding = "UTF-8"
    )

    stop(
      paste0(
        "Could not read ",
        repository_path,
        " from HEAD.\n",
        paste(
          error_text,
          collapse = "\n"
        )
      ),
      call. = FALSE
    )
  }

  readLines(
    output_file,
    warn = FALSE,
    encoding = "UTF-8"
  )
}

assert_matches_head <- function(path) {
  working_lines <- readLines(
    path,
    warn = FALSE,
    encoding = "UTF-8"
  )

  head_lines <- read_head_file(
    path
  )

  if (!identical(working_lines, head_lines)) {
    stop(
      paste0(
        path,
        " already differs from the committed HEAD version.\n",
        "Commit, restore or inspect the existing changes before extraction."
      ),
      call. = FALSE
    )
  }

  invisible(TRUE)
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

empty_function_inventory <- function() {
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
      empty_function_inventory()
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
      empty_function_inventory()
    )
  }

  do.call(
    rbind,
    rows
  )
}

function_exists_in_environment <- function(
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

assert_matches_head(
  source_file
)

assert_matches_head(
  module_file
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
      "The preserved legacy implementation has an unexpected checksum.\n",
      "Expected: ",
      expected_legacy_md5,
      "\nObserved: ",
      legacy_md5
    ),
    call. = FALSE
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

mapping_map <- function_map[
  function_map$target_file ==
    "R/02_string_mapping.R",
  ,
  drop = FALSE
]

mapping_names <- mapping_map$function_name

if (
  length(mapping_names) != 7L ||
    !setequal(
      mapping_names,
      expected_mapping_functions
    )
) {
  stop(
    paste0(
      "R/02_string_mapping.R must receive exactly these seven functions:\n",
      paste(
        paste0(
          "- ",
          expected_mapping_functions
        ),
        collapse = "\n"
      )
    ),
    call. = FALSE
  )
}

if (anyDuplicated(mapping_names)) {
  stop(
    "The STRING-mapping function map contains duplicated names.",
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
      " already contains function definitions."
    ),
    call. = FALSE
  )
}

source_function_counts <- table(
  source_inventory$function_name
)

missing_mapping_functions <- mapping_names[
  !mapping_names %in%
    source_inventory$function_name
]

if (length(missing_mapping_functions) > 0L) {
  stop(
    paste0(
      "Mapping functions missing from cancerppir.R: ",
      paste(
        missing_mapping_functions,
        collapse = ", "
      )
    ),
    call. = FALSE
  )
}

invalid_source_counts <- mapping_names[
  source_function_counts[mapping_names] != 1L
]

if (length(invalid_source_counts) > 0L) {
  stop(
    paste0(
      "Mapping functions not defined exactly once in cancerppir.R: ",
      paste(
        invalid_source_counts,
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
    mapping_names,
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
  "# CancerPPIr: HGNC and STRING mapping",
  "#",
  paste0(
    "# HGNC symbol handling, STRING identifier mapping, alias correction ",
    "and STRING interaction retrieval."
  ),
  "#",
  "# Architecture checkpoint 2.6",
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
      "Expected exactly one existing module-loader marker in cancerppir.R, ",
      "found ",
      loader_marker_count,
      "."
    ),
    call. = FALSE
  )
}

temporary_directory <- tempfile(
  pattern = "cancerppir-string-mapping-extraction-"
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
  "02_string_mapping.R"
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

mapping_functions_left_in_source <- intersect(
  mapping_names,
  temporary_source_inventory$function_name
)

if (length(mapping_functions_left_in_source) > 0L) {
  stop(
    paste0(
      "Mapping definitions remain in the temporary cancerppir.R: ",
      paste(
        mapping_functions_left_in_source,
        collapse = ", "
      )
    ),
    call. = FALSE
  )
}

if (!identical(
  sort(temporary_module_inventory$function_name),
  sort(mapping_names)
)) {
  stop(
    paste0(
      "The temporary STRING-mapping module does not contain exactly ",
      "the expected seven functions."
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
        "[string mapping extraction] Original files were restored."
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
    "Failed to write the extracted STRING-mapping source files.",
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

remaining_mapping_definitions <- intersect(
  mapping_names,
  source_inventory_after$function_name
)

if (length(remaining_mapping_definitions) > 0L) {
  stop(
    paste0(
      "Mapping definitions remain in cancerppir.R after extraction: ",
      paste(
        remaining_mapping_definitions,
        collapse = ", "
      )
    ),
    call. = FALSE
  )
}

if (!identical(
  sort(module_inventory_after$function_name),
  sort(mapping_names)
)) {
  stop(
    "R/02_string_mapping.R failed post-write function validation.",
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

loaded_mapping_status <- vapply(
  mapping_names,
  function_exists_in_environment,
  environment = module_environment,
  FUN.VALUE = logical(1)
)

if (!all(loaded_mapping_status)) {
  failed_functions <- mapping_names[
    !loaded_mapping_status
  ]

  stop(
    paste0(
      "The module loader failed to expose mapping functions: ",
      paste(
        failed_functions,
        collapse = ", "
      )
    ),
    call. = FALSE
  )
}

previous_target_files <- c(
  "R/00_utils.R",
  "R/01_input.R"
)

previous_function_names <- function_map$function_name[
  function_map$target_file %in%
    previous_target_files
]

loaded_previous_status <- vapply(
  previous_function_names,
  function_exists_in_environment,
  environment = module_environment,
  FUN.VALUE = logical(1)
)

if (!all(loaded_previous_status)) {
  failed_previous_functions <- previous_function_names[
    !loaded_previous_status
  ]

  stop(
    paste0(
      "Previously extracted functions are unavailable through the loader: ",
      paste(
        failed_previous_functions,
        collapse = ", "
      )
    ),
    call. = FALSE
  )
}

manifest <- data.frame(
  checkpoint = "2.6",
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
  target_file = "R/02_string_mapping.R",
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
  "[string mapping extraction] STRING mapping extraction completed."
)

message(
  "[string mapping extraction] Functions moved: ",
  nrow(manifest),
  "."
)

message(
  "[string mapping extraction] Mapping functions remaining in cancerppir.R: 0."
)

message(
  "[string mapping extraction] Mapping functions available through loader: ",
  sum(loaded_mapping_status),
  "/",
  length(loaded_mapping_status),
  "."
)

message(
  "[string mapping extraction] Previously extracted functions available: ",
  sum(loaded_previous_status),
  "/",
  length(loaded_previous_status),
  "."
)

message(
  "[string mapping extraction] Loaded module files: ",
  length(loaded_modules),
  "."
)

message(
  "[string mapping extraction] cancerppir.R MD5 before: ",
  source_md5_before
)

message(
  "[string mapping extraction] cancerppir.R MD5 after:  ",
  source_md5_after
)

message(
  "[string mapping extraction] R/02_string_mapping.R MD5: ",
  module_md5_after
)

message(
  "[string mapping extraction] Manifest: ",
  manifest_file
)

message(
  "[string mapping extraction] legacy/cancerppir_legacy.R was not modified."
)