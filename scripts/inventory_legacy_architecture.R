#!/usr/bin/env Rscript

# Build a structural inventory of the current monolithic CancerPPIr
# implementation without modifying or executing its analytical workflow.

source_file <- "cancerppir.R"
output_dir <- file.path("docs", "architecture")

if (!file.exists(source_file)) {
  stop(
    "Run this script from the CancerPPIr repository root.",
    call. = FALSE
  )
}

dir.create(
  output_dir,
  recursive = TRUE,
  showWarnings = FALSE
)

source_lines <- readLines(
  source_file,
  warn = FALSE,
  encoding = "UTF-8"
)

parsed <- parse(
  file = source_file,
  keep.source = TRUE
)

parsed_srcrefs <- attr(
  parsed,
  "srcref"
)

if (
  is.null(parsed_srcrefs) ||
    length(parsed_srcrefs) != length(parsed)
) {
  stop(
    "Source references could not be extracted from cancerppir.R.",
    call. = FALSE
  )
}

expression_rows <- list()
function_rows <- list()
package_rows <- list()

expression_index <- 1L
function_index <- 1L
package_index <- 1L

get_line_range <- function(expression_position) {
  reference <- parsed_srcrefs[[expression_position]]

  if (
    is.null(reference) ||
      length(reference) < 3L
  ) {
    return(
      c(
        NA_integer_,
        NA_integer_
      )
    )
  }

  c(
    as.integer(reference[[1]]),
    as.integer(reference[[3]])
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
  call_name <- get_call_name(expression)

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

classify_expression <- function(expression) {
  call_name <- get_call_name(expression)

  if (is.na(call_name)) {
    return("top_level_expression")
  }

  if (call_name %in% c("<-", "=")) {
    value <- expression[[3]]

    if (
      is.call(value) &&
        identical(
          get_call_name(value),
          "function"
        )
    ) {
      return("function_definition")
    }

    return("top_level_assignment")
  }

  if (identical(call_name, "if")) {
    return("top_level_if")
  }

  if (identical(call_name, "for")) {
    return("top_level_for")
  }

  if (
    call_name %in%
      c(
        "library",
        "require",
        "requireNamespace"
      )
  ) {
    return("package_loading")
  }

  "top_level_expression"
}

extract_function_arguments <- function(function_expression) {
  argument_list <- function_expression[[2]]

  if (length(argument_list) == 0L) {
    return("")
  }

  argument_names <- names(argument_list)

  if (is.null(argument_names)) {
    return("")
  }

  paste(
    argument_names,
    collapse = ";"
  )
}

for (expression_position in seq_along(parsed)) {
  expression <- parsed[[expression_position]]

  line_range <- get_line_range(
    expression_position
  )

  expression_type <- classify_expression(
    expression
  )

  assignment_name <- get_assignment_name(
    expression
  )

  line_span <- if (anyNA(line_range)) {
    NA_integer_
  } else {
    line_range[[2]] - line_range[[1]] + 1L
  }

  expression_rows[[expression_index]] <- data.frame(
    expression_index = expression_position,
    expression_type = expression_type,
    object_name = assignment_name,
    start_line = line_range[[1]],
    end_line = line_range[[2]],
    line_span = line_span,
    stringsAsFactors = FALSE
  )

  expression_index <- expression_index + 1L

  if (identical(expression_type, "function_definition")) {
    function_expression <- expression[[3]]

    function_rows[[function_index]] <- data.frame(
      function_name = assignment_name,
      arguments = extract_function_arguments(
        function_expression
      ),
      start_line = line_range[[1]],
      end_line = line_range[[2]],
      line_span = line_span,
      stringsAsFactors = FALSE
    )

    function_index <- function_index + 1L
  }
}

package_patterns <- c(
  "library\\s*\\(",
  "require\\s*\\(",
  "requireNamespace\\s*\\(",
  "::"
)

for (line_number in seq_along(source_lines)) {
  line <- source_lines[[line_number]]

  contains_package_reference <- any(
    vapply(
      package_patterns,
      function(pattern) {
        grepl(
          pattern,
          line,
          perl = TRUE
        )
      },
      FUN.VALUE = logical(1)
    )
  )

  if (contains_package_reference) {
    package_rows[[package_index]] <- data.frame(
      line_number = line_number,
      code = trimws(line),
      stringsAsFactors = FALSE
    )

    package_index <- package_index + 1L
  }
}

expression_inventory <- do.call(
  rbind,
  expression_rows
)

function_inventory <- if (length(function_rows) > 0L) {
  do.call(
    rbind,
    function_rows
  )
} else {
  data.frame(
    function_name = character(),
    arguments = character(),
    start_line = integer(),
    end_line = integer(),
    line_span = integer(),
    stringsAsFactors = FALSE
  )
}

package_inventory <- if (length(package_rows) > 0L) {
  do.call(
    rbind,
    package_rows
  )
} else {
  data.frame(
    line_number = integer(),
    code = character(),
    stringsAsFactors = FALSE
  )
}

utils::write.csv(
  expression_inventory,
  file.path(
    output_dir,
    "legacy_top_level_expressions.csv"
  ),
  row.names = FALSE,
  na = ""
)

utils::write.csv(
  function_inventory,
  file.path(
    output_dir,
    "legacy_function_inventory.csv"
  ),
  row.names = FALSE,
  na = ""
)

utils::write.csv(
  package_inventory,
  file.path(
    output_dir,
    "legacy_package_references.csv"
  ),
  row.names = FALSE,
  na = ""
)

markers <- data.frame(
  marker = c(
    "commandArgs",
    "Reading input table",
    "Checking gene symbols",
    "Initializing STRINGdb",
    "Mapping genes to STRING identifiers",
    "Building STRING subnetwork",
    "Calculating network metrics",
    "Running functional enrichment analysis",
    "Writing consolidated output files"
  ),
  stringsAsFactors = FALSE
)

markers$line_numbers <- vapply(
  markers$marker,
  function(marker) {
    matched_lines <- grep(
      marker,
      source_lines,
      fixed = TRUE
    )

    if (length(matched_lines) == 0L) {
      return("")
    }

    paste(
      matched_lines,
      collapse = ";"
    )
  },
  FUN.VALUE = character(1)
)

utils::write.csv(
  markers,
  file.path(
    output_dir,
    "legacy_workflow_markers.csv"
  ),
  row.names = FALSE
)

summary_lines <- c(
  "# Legacy CancerPPIr architecture inventory",
  "",
  paste0(
    "- Source file: `",
    source_file,
    "`"
  ),
  paste0(
    "- Total lines: ",
    length(source_lines)
  ),
  paste0(
    "- Parsed top-level expressions: ",
    nrow(expression_inventory)
  ),
  paste0(
    "- Top-level function definitions: ",
    nrow(function_inventory)
  ),
  "",
  "## Largest functions",
  ""
)

if (nrow(function_inventory) > 0L) {
  largest_functions <- function_inventory[
    order(
      is.na(function_inventory$line_span),
      -function_inventory$line_span,
      function_inventory$function_name
    ),
    ,
    drop = FALSE
  ]

  largest_functions <- head(
    largest_functions,
    20L
  )

  function_description <- ifelse(
    is.na(largest_functions$line_span),
    paste0(
      "- `",
      largest_functions$function_name,
      "`: source range unavailable"
    ),
    paste0(
      "- `",
      largest_functions$function_name,
      "`: lines ",
      largest_functions$start_line,
      "-",
      largest_functions$end_line,
      " (",
      largest_functions$line_span,
      " lines)"
    )
  )

  summary_lines <- c(
    summary_lines,
    function_description
  )
}

summary_lines <- c(
  summary_lines,
  "",
  "## Workflow markers",
  ""
)

for (marker_index in seq_len(nrow(markers))) {
  marker_lines <- markers$line_numbers[[marker_index]]

  if (!nzchar(marker_lines)) {
    marker_lines <- "not found"
  }

  summary_lines <- c(
    summary_lines,
    paste0(
      "- `",
      markers$marker[[marker_index]],
      "`: ",
      marker_lines
    )
  )
}

summary_lines <- c(
  summary_lines,
  "",
  "## Generated files",
  "",
  "- `legacy_top_level_expressions.csv`",
  "- `legacy_function_inventory.csv`",
  "- `legacy_package_references.csv`",
  "- `legacy_workflow_markers.csv`"
)

writeLines(
  summary_lines,
  file.path(
    output_dir,
    "LEGACY_ARCHITECTURE.md"
  ),
  useBytes = TRUE
)

missing_function_ranges <- sum(
  is.na(function_inventory$start_line) |
    is.na(function_inventory$end_line)
)

message(
  "[architecture] Inventory written to ",
  output_dir,
  "."
)

message(
  "[architecture] Functions found: ",
  nrow(function_inventory),
  "."
)

message(
  "[architecture] Functions without source ranges: ",
  missing_function_ranges,
  "."
)