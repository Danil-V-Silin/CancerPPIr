#!/usr/bin/env Rscript

# Move stable configuration objects from cancerppir.R into their modules
# and make string_db an explicit run_string_enrichment_online() argument.
#
# Checkpoint 2.10 dependency migration.
#
# Run from the repository root:
#   Rscript scripts/migrate_orchestration_dependencies.R

source_file <- "cancerppir.R"
enrichment_file <- file.path("R", "03_enrichment.R")
labeling_file <- file.path("R", "04_module_labeling.R")
loader_file <- file.path("R", "load_all.R")
legacy_file <- file.path("legacy", "cancerppir_legacy.R")

function_map_file <- file.path(
  "docs",
  "architecture",
  "target_function_module_map.csv"
)

manifest_file <- file.path(
  "docs",
  "architecture",
  "checkpoint_2_10_dependency_migration.csv"
)

validation_file <- file.path(
  "docs",
  "architecture",
  "checkpoint_2_10_dependency_migration_validation.txt"
)

expected_legacy_md5 <- "0c5644140abbae2f17e30109432cc198"

constant_targets <- data.frame(
  object_name = c(
    "marker_sets",
    "module_clean_labels",
    "preferred_enrichment_categories",
    "secondary_enrichment_categories",
    "specific_biology_pattern",
    "generic_exact_terms",
    "label_rulebook"
  ),
  target_file = c(
    labeling_file,
    labeling_file,
    enrichment_file,
    enrichment_file,
    enrichment_file,
    enrichment_file,
    labeling_file
  ),
  stringsAsFactors = FALSE
)

required_files <- c(
  source_file,
  enrichment_file,
  labeling_file,
  loader_file,
  legacy_file,
  function_map_file
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
      "Migration output files already exist:\n",
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
        " already differs from HEAD.\n",
        "Inspect, commit or restore it before migration."
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

for (path in c(
  source_file,
  enrichment_file,
  labeling_file
)) {
  assert_matches_head(path)
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

if (!requireNamespace(
  "codetools",
  quietly = TRUE
)) {
  stop(
    "Package 'codetools' is required.",
    call. = FALSE
  )
}

read_raw_file <- function(path) {
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
    n = as.integer(file.info(path)$size)
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

detect_line_ending <- function(contents) {
  text <- rawToChar(contents)

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
    charToRaw(enc2utf8(text))
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

get_call_head <- function(expression) {
  if (!is.call(expression)) {
    return(NA_character_)
  }

  head <- expression[[1L]]

  if (is.symbol(head)) {
    return(as.character(head))
  }

  paste(
    deparse(
      head,
      width.cutoff = 500L
    ),
    collapse = ""
  )
}

get_assignment_name <- function(expression) {
  if (!is.call(expression)) {
    return(NA_character_)
  }

  call_head <- get_call_head(expression)

  if (
    is.na(call_head) ||
      !call_head %in% c("<-", "=") ||
      length(expression) < 2L
  ) {
    return(NA_character_)
  }

  target <- expression[[2L]]

  if (is.symbol(target)) {
    return(as.character(target))
  }

  NA_character_
}

inventory_top_level_assignments <- function(path) {
  parsed <- parse(
    file = path,
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
      paste0(
        "Could not obtain source ranges for ",
        path,
        "."
      ),
      call. = FALSE
    )
  }

  rows <- vector(
    mode = "list",
    length = length(parsed)
  )

  for (expression_index in seq_along(parsed)) {
    source_reference <- source_references[[
      expression_index
    ]]

    rows[[expression_index]] <- data.frame(
      expression_index = expression_index,
      assignment_name = get_assignment_name(
        parsed[[expression_index]]
      ),
      start_line = as.integer(
        source_reference[[1L]]
      ),
      end_line = as.integer(
        source_reference[[3L]]
      ),
      stringsAsFactors = FALSE
    )
  }

  do.call(
    rbind,
    rows
  )
}

count_fixed_occurrences <- function(
  lines,
  pattern
) {
  matches <- gregexpr(
    pattern,
    lines,
    fixed = TRUE
  )

  as.integer(
    sum(
      vapply(
        matches,
        function(positions) {
          if (
            length(positions) == 1L &&
              positions[[1L]] < 0L
          ) {
            return(0L)
          }

          length(positions)
        },
        FUN.VALUE = integer(1)
      )
    )
  )
}

collect_assigned_symbols <- function(expression) {
  assigned <- character()

  walk <- function(node) {
    if (!is.call(node)) {
      return(invisible(NULL))
    }

    call_head <- get_call_head(node)

    if (identical(call_head, "function")) {
      return(invisible(NULL))
    }

    if (
      call_head %in% c("<-", "=", "<<-") &&
        length(node) >= 3L
    ) {
      target <- node[[2L]]

      if (is.symbol(target)) {
        assigned <<- c(
          assigned,
          as.character(target)
        )
      }

      walk(node[[3L]])

      return(invisible(NULL))
    }

    if (
      identical(call_head, "for") &&
        length(node) >= 4L
    ) {
      loop_variable <- node[[2L]]

      if (is.symbol(loop_variable)) {
        assigned <<- c(
          assigned,
          as.character(loop_variable)
        )
      }

      walk(node[[3L]])
      walk(node[[4L]])

      return(invisible(NULL))
    }

    if (length(node) >= 2L) {
      for (index in 2:length(node)) {
        walk(node[[index]])
      }
    }

    invisible(NULL)
  }

  walk(expression)

  sort(unique(assigned))
}

source_raw_before <- read_raw_file(
  source_file
)

enrichment_raw_before <- read_raw_file(
  enrichment_file
)

labeling_raw_before <- read_raw_file(
  labeling_file
)

source_md5_before <- unname(
  tools::md5sum(source_file)
)

source_lines <- readLines(
  source_file,
  warn = FALSE,
  encoding = "UTF-8"
)

enrichment_lines <- readLines(
  enrichment_file,
  warn = FALSE,
  encoding = "UTF-8"
)

labeling_lines <- readLines(
  labeling_file,
  warn = FALSE,
  encoding = "UTF-8"
)

source_line_ending <- detect_line_ending(
  source_raw_before
)

enrichment_line_ending <- detect_line_ending(
  enrichment_raw_before
)

labeling_line_ending <- detect_line_ending(
  labeling_raw_before
)

source_inventory <- inventory_top_level_assignments(
  source_file
)

selected_rows <- source_inventory[
  match(
    constant_targets$object_name,
    source_inventory$assignment_name
  ),
  ,
  drop = FALSE
]

if (
  nrow(selected_rows) !=
    nrow(constant_targets) ||
    anyNA(selected_rows$assignment_name)
) {
  missing_constants <- constant_targets$object_name[
    !constant_targets$object_name %in%
      source_inventory$assignment_name
  ]

  stop(
    paste0(
      "Could not locate all configuration objects:\n",
      paste(
        paste0("- ", missing_constants),
        collapse = "\n"
      )
    ),
    call. = FALSE
  )
}

assignment_counts <- table(
  source_inventory$assignment_name
)

invalid_counts <- constant_targets$object_name[
  assignment_counts[
    constant_targets$object_name
  ] != 1L
]

if (length(invalid_counts) > 0L) {
  stop(
    paste0(
      "Configuration objects not assigned exactly once:\n",
      paste(
        paste0("- ", invalid_counts),
        collapse = "\n"
      )
    ),
    call. = FALSE
  )
}

selected_rows$target_file <-
  constant_targets$target_file[
    match(
      selected_rows$assignment_name,
      constant_targets$object_name
    )
  ]

selected_rows <- selected_rows[
  order(selected_rows$start_line),
  ,
  drop = FALSE
]

constant_blocks <- lapply(
  seq_len(nrow(selected_rows)),
  function(row_index) {
    source_lines[
      selected_rows$start_line[[row_index]]:
        selected_rows$end_line[[row_index]]
    ]
  }
)

names(constant_blocks) <-
  selected_rows$assignment_name

remove_lines <- rep(
  FALSE,
  length(source_lines)
)

for (row_index in seq_len(nrow(selected_rows))) {
  remove_lines[
    selected_rows$start_line[[row_index]]:
      selected_rows$end_line[[row_index]]
  ] <- TRUE
}

modified_source_lines <- source_lines[
  !remove_lines
]

old_signature <- paste0(
  "run_string_enrichment_online <- function(",
  "ids, query_name = \"STRING_online_query\") {"
)

new_signature <- paste0(
  "run_string_enrichment_online <- function(",
  "string_db, ids, query_name = \"STRING_online_query\") {"
)

signature_count <- count_fixed_occurrences(
  enrichment_lines,
  old_signature
)

if (signature_count != 1L) {
  stop(
    paste0(
      "Expected one original online-enrichment signature, found ",
      signature_count,
      "."
    ),
    call. = FALSE
  )
}

modified_enrichment_lines <- gsub(
  old_signature,
  new_signature,
  enrichment_lines,
  fixed = TRUE
)

old_call_prefix <-
  "run_string_enrichment_online("

new_call_prefix <-
  "run_string_enrichment_online(string_db, "

call_count <- count_fixed_occurrences(
  modified_source_lines,
  old_call_prefix
)

if (call_count != 3L) {
  stop(
    paste0(
      "Expected three online-enrichment calls, found ",
      call_count,
      "."
    ),
    call. = FALSE
  )
}

modified_source_lines <- gsub(
  old_call_prefix,
  new_call_prefix,
  modified_source_lines,
  fixed = TRUE
)

if (
  count_fixed_occurrences(
    modified_source_lines,
    new_call_prefix
  ) != 3L
) {
  stop(
    "The three online-enrichment calls were not updated correctly.",
    call. = FALSE
  )
}

enrichment_constants <- selected_rows[
  selected_rows$target_file ==
    enrichment_file,
  ,
  drop = FALSE
]

if (nrow(enrichment_constants) > 0L) {
  modified_enrichment_lines <- c(
    modified_enrichment_lines,
    "",
    paste(
      rep("#", 78L),
      collapse = ""
    ),
    "# Stable enrichment configuration moved from cancerppir.R",
    paste(
      rep("#", 78L),
      collapse = ""
    ),
    ""
  )

  for (
    object_name in
    enrichment_constants$assignment_name
  ) {
    modified_enrichment_lines <- c(
      modified_enrichment_lines,
      paste0(
        "# Configuration object: ",
        object_name
      ),
      constant_blocks[[object_name]],
      ""
    )
  }
}

labeling_constants <- selected_rows[
  selected_rows$target_file ==
    labeling_file,
  ,
  drop = FALSE
]

modified_labeling_lines <- labeling_lines

if (nrow(labeling_constants) > 0L) {
  modified_labeling_lines <- c(
    modified_labeling_lines,
    "",
    paste(
      rep("#", 78L),
      collapse = ""
    ),
    "# Stable module-labeling configuration moved from cancerppir.R",
    paste(
      rep("#", 78L),
      collapse = ""
    ),
    ""
  )

  for (
    object_name in
    labeling_constants$assignment_name
  ) {
    modified_labeling_lines <- c(
      modified_labeling_lines,
      paste0(
        "# Configuration object: ",
        object_name
      ),
      constant_blocks[[object_name]],
      ""
    )
  }
}

temporary_directory <- tempfile(
  pattern = "cancerppir-dependency-migration-"
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

temporary_enrichment <- file.path(
  temporary_directory,
  "03_enrichment.R"
)

temporary_labeling <- file.path(
  temporary_directory,
  "04_module_labeling.R"
)

write_text_file(
  modified_source_lines,
  temporary_source,
  source_line_ending
)

write_text_file(
  modified_enrichment_lines,
  temporary_enrichment,
  enrichment_line_ending
)

write_text_file(
  modified_labeling_lines,
  temporary_labeling,
  labeling_line_ending
)

invisible(parse(file = temporary_source))
invisible(parse(file = temporary_enrichment))
invisible(parse(file = temporary_labeling))

temporary_source_inventory <-
  inventory_top_level_assignments(
    temporary_source
  )

remaining_constants <- intersect(
  constant_targets$object_name,
  temporary_source_inventory$assignment_name
)

if (length(remaining_constants) > 0L) {
  stop(
    paste0(
      "Configuration objects remain in temporary cancerppir.R:\n",
      paste(
        paste0("- ", remaining_constants),
        collapse = "\n"
      )
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
        enrichment_file,
        enrichment_raw_before
      )

      write_raw_file(
        labeling_file,
        labeling_raw_before
      )

      unlink(
        c(
          manifest_file,
          validation_file
        ),
        force = TRUE
      )

      message(
        "[dependency migration] Original files were restored."
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
  temporary_enrichment,
  enrichment_file,
  overwrite = TRUE
))) {
  stop(
    "Failed to update R/03_enrichment.R.",
    call. = FALSE
  )
}

if (!isTRUE(file.copy(
  temporary_labeling,
  labeling_file,
  overwrite = TRUE
))) {
  stop(
    "Failed to update R/04_module_labeling.R.",
    call. = FALSE
  )
}

invisible(parse(file = source_file))
invisible(parse(file = enrichment_file))
invisible(parse(file = labeling_file))

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
    "The module loader did not load eight files.",
    call. = FALSE
  )
}

function_map <- utils::read.csv(
  function_map_file,
  stringsAsFactors = FALSE
)

function_status <- vapply(
  function_map$function_name,
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

if (!all(function_status)) {
  stop(
    "Not all 63 mapped functions are available through the loader.",
    call. = FALSE
  )
}

constant_status <- vapply(
  constant_targets$object_name,
  exists,
  envir = module_environment,
  inherits = FALSE,
  FUN.VALUE = logical(1)
)

if (!all(constant_status)) {
  stop(
    paste0(
      "Configuration objects unavailable through the loader:\n",
      paste(
        paste0(
          "- ",
          constant_targets$object_name[
            !constant_status
          ]
        ),
        collapse = "\n"
      )
    ),
    call. = FALSE
  )
}

online_function <- get(
  "run_string_enrichment_online",
  envir = module_environment,
  inherits = FALSE
)

expected_formals <- c(
  "string_db",
  "ids",
  "query_name"
)

if (!identical(
  names(formals(online_function)),
  expected_formals
)) {
  stop(
    paste0(
      "Unexpected run_string_enrichment_online() formals: ",
      paste(
        names(formals(online_function)),
        collapse = ", "
      )
    ),
    call. = FALSE
  )
}

modified_parsed <- parse(
  file = source_file,
  keep.source = TRUE
)

assigned_symbols <- sort(
  unique(
    unlist(
      lapply(
        modified_parsed,
        collect_assigned_symbols
      ),
      use.names = FALSE
    )
  )
)

dependency_rows <- list()
dependency_index <- 1L

for (function_name in function_map$function_name) {
  function_object <- get(
    function_name,
    envir = module_environment,
    inherits = FALSE
  )

  globals <- codetools::findGlobals(
    function_object,
    merge = FALSE
  )

  dependencies <- intersect(
    globals$variables,
    assigned_symbols
  )

  if (length(dependencies) == 0L) {
    next
  }

  for (dependency in dependencies) {
    dependency_rows[[dependency_index]] <-
      data.frame(
        function_name = function_name,
        dependency = dependency,
        stringsAsFactors = FALSE
      )

    dependency_index <- dependency_index + 1L
  }
}

if (length(dependency_rows) > 0L) {
  remaining_dependency_table <- do.call(
    rbind,
    dependency_rows
  )

  stop(
    paste0(
      "Hidden orchestration dependencies remain:\n",
      paste(
        paste0(
          "- ",
          remaining_dependency_table$function_name,
          ": ",
          remaining_dependency_table$dependency
        ),
        collapse = "\n"
      )
    ),
    call. = FALSE
  )
}

manifest_constants <- data.frame(
  checkpoint = "2.10",
  item_type = "configuration_object",
  item_name = selected_rows$assignment_name,
  original_start_line = selected_rows$start_line,
  original_end_line = selected_rows$end_line,
  original_text_md5 = vapply(
    constant_blocks[
      selected_rows$assignment_name
    ],
    text_md5,
    FUN.VALUE = character(1)
  ),
  target_file = selected_rows$target_file,
  migration_action =
    "move_exact_top_level_assignment",
  stringsAsFactors = FALSE
)

manifest_signature <- data.frame(
  checkpoint = "2.10",
  item_type = "function_interface",
  item_name =
    "run_string_enrichment_online",
  original_start_line = NA_integer_,
  original_end_line = NA_integer_,
  original_text_md5 = NA_character_,
  target_file = enrichment_file,
  migration_action =
    "add_explicit_string_db_parameter_and_update_three_calls",
  stringsAsFactors = FALSE
)

manifest <- rbind(
  manifest_constants,
  manifest_signature
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

validation_lines <- c(
  "CancerPPIr checkpoint 2.10 dependency migration",
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
    "Configuration objects moved: ",
    nrow(constant_targets)
  ),
  "Online enrichment calls updated: 3",
  "run_string_enrichment_online() explicit string_db parameter: TRUE",
  "Mapped functions available through loader: 63/63",
  "Configuration objects available through loader: 7/7",
  "Remaining hidden orchestration dependencies: 0",
  paste0(
    "Legacy MD5 unchanged: ",
    legacy_md5
  )
)

writeLines(
  validation_lines,
  validation_file,
  useBytes = TRUE
)

write_completed <- TRUE

message(
  "[dependency migration] Migration completed."
)

message(
  "[dependency migration] Configuration objects moved: 7."
)

message(
  "[dependency migration] Online enrichment calls updated: 3."
)

message(
  "[dependency migration] Functions available through loader: 63/63."
)

message(
  "[dependency migration] Configuration objects available: 7/7."
)

message(
  "[dependency migration] Hidden orchestration dependencies remaining: 0."
)

message(
  "[dependency migration] cancerppir.R MD5 before: ",
  source_md5_before
)

message(
  "[dependency migration] cancerppir.R MD5 after:  ",
  source_md5_after
)

message(
  "[dependency migration] Manifest: ",
  manifest_file
)

message(
  "[dependency migration] Validation: ",
  validation_file
)

message(
  "[dependency migration] legacy/cancerppir_legacy.R was not modified."
)