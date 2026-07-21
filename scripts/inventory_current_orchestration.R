#!/usr/bin/env Rscript

# Inventory the current top-level CancerPPIr orchestration after all
# original function definitions have been extracted into R modules.
#
# This script does not modify cancerppir.R.
#
# Run from the repository root:
#   Rscript scripts/inventory_current_orchestration.R

source_file <- "cancerppir.R"

output_csv <- file.path(
  "docs",
  "architecture",
  "checkpoint_2_10_current_orchestration_inventory.csv"
)

output_markers_csv <- file.path(
  "docs",
  "architecture",
  "checkpoint_2_10_current_orchestration_markers.csv"
)

output_summary <- file.path(
  "docs",
  "architecture",
  "checkpoint_2_10_current_orchestration_summary.txt"
)

if (!file.exists(source_file)) {
  stop(
    "cancerppir.R was not found. Run this script from the repository root.",
    call. = FALSE
  )
}

source_diff_status <- system2(
  command = "git",
  args = c(
    "diff",
    "--quiet",
    "HEAD",
    "--",
    source_file
  ),
  stdout = FALSE,
  stderr = FALSE
)

if (!identical(source_diff_status, 0L)) {
  stop(
    paste0(
      "cancerppir.R differs from the committed HEAD version.\n",
      "Commit, restore or inspect the file before inventory."
    ),
    call. = FALSE
  )
}

source_lines <- readLines(
  source_file,
  warn = FALSE,
  encoding = "UTF-8"
)

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
    "Could not obtain source ranges for all top-level expressions.",
    call. = FALSE
  )
}

get_call_head <- function(expression) {
  if (!is.call(expression)) {
    return(
      typeof(expression)
    )
  }

  head <- expression[[1L]]

  if (is.symbol(head)) {
    return(
      as.character(head)
    )
  }

  paste(
    deparse(
      head,
      width.cutoff = 500L
    ),
    collapse = ""
  )
}

get_assignment_target <- function(expression) {
  if (!is.call(expression)) {
    return(NA_character_)
  }

  head <- get_call_head(expression)

  if (
    !head %in% c("<-", "=") ||
      length(expression) < 2L
  ) {
    return(NA_character_)
  }

  target <- expression[[2L]]

  if (is.symbol(target)) {
    return(
      as.character(target)
    )
  }

  paste(
    deparse(
      target,
      width.cutoff = 500L
    ),
    collapse = ""
  )
}

is_function_definition <- function(expression) {
  if (
    !is.call(expression) ||
      length(expression) < 3L
  ) {
    return(FALSE)
  }

  head <- get_call_head(expression)

  if (!head %in% c("<-", "=")) {
    return(FALSE)
  }

  value <- expression[[3L]]

  is.call(value) &&
    identical(
      get_call_head(value),
      "function"
    )
}

make_preview <- function(
  start_line,
  end_line,
  maximum_characters = 180L
) {
  block <- source_lines[
    start_line:end_line
  ]

  block <- trimws(block)
  block <- block[nzchar(block)]

  if (length(block) == 0L) {
    return("")
  }

  preview <- paste(
    block,
    collapse = " "
  )

  preview <- gsub(
    "[[:space:]]+",
    " ",
    preview
  )

  if (nchar(preview) > maximum_characters) {
    preview <- paste0(
      substr(
        preview,
        1L,
        maximum_characters - 3L
      ),
      "..."
    )
  }

  preview
}

inventory_rows <- vector(
  mode = "list",
  length = length(parsed)
)

for (expression_index in seq_along(parsed)) {
  source_reference <- source_references[[
    expression_index
  ]]

  start_line <- as.integer(
    source_reference[[1L]]
  )

  end_line <- as.integer(
    source_reference[[3L]]
  )

  expression <- parsed[[
    expression_index
  ]]

  inventory_rows[[expression_index]] <- data.frame(
    expression_index = expression_index,
    start_line = start_line,
    end_line = end_line,
    line_span = end_line - start_line + 1L,
    call_head = get_call_head(expression),
    assignment_target =
      get_assignment_target(expression),
    is_function_definition =
      is_function_definition(expression),
    preview = make_preview(
      start_line,
      end_line
    ),
    stringsAsFactors = FALSE
  )
}

inventory <- do.call(
  rbind,
  inventory_rows
)

marker_definitions <- data.frame(
  marker = c(
    "module_loader",
    "cli_arguments",
    "read_input",
    "build_string_subnetwork",
    "calculate_network_metrics",
    "functional_enrichment",
    "write_outputs",
    "workflow_done"
  ),
  pattern = c(
    "# Load extracted CancerPPIr source modules.",
    "args <- commandArgs(trailingOnly = TRUE)",
    "msg(\"Reading input table.\")",
    "msg(\"Building STRING subnetwork.\")",
    "msg(\"Calculating network metrics.\")",
    "msg(\"Running functional enrichment analysis.\")",
    "msg(\"Writing consolidated output files.\")",
    "msg(\"Done.\")"
  ),
  stringsAsFactors = FALSE
)

find_marker_line <- function(pattern) {
  matches <- which(
    grepl(
      pattern,
      source_lines,
      fixed = TRUE
    )
  )

  if (length(matches) == 0L) {
    return(NA_integer_)
  }

  as.integer(
    matches[[1L]]
  )
}

marker_definitions$line <- vapply(
  marker_definitions$pattern,
  find_marker_line,
  FUN.VALUE = integer(1)
)

find_containing_expression <- function(line_number) {
  if (is.na(line_number)) {
    return(NA_integer_)
  }

  matches <- which(
    inventory$start_line <= line_number &
      inventory$end_line >= line_number
  )

  if (length(matches) == 0L) {
    return(NA_integer_)
  }

  inventory$expression_index[
    matches[[1L]]
  ]
}

marker_definitions$expression_index <- vapply(
  marker_definitions$line,
  find_containing_expression,
  FUN.VALUE = integer(1)
)

required_phase_markers <- c(
  cli_arguments =
    marker_definitions$line[
      marker_definitions$marker == "cli_arguments"
    ],
  read_input =
    marker_definitions$line[
      marker_definitions$marker == "read_input"
    ],
  build_string_subnetwork =
    marker_definitions$line[
      marker_definitions$marker ==
        "build_string_subnetwork"
    ],
  calculate_network_metrics =
    marker_definitions$line[
      marker_definitions$marker ==
        "calculate_network_metrics"
    ],
  functional_enrichment =
    marker_definitions$line[
      marker_definitions$marker ==
        "functional_enrichment"
    ],
  write_outputs =
    marker_definitions$line[
      marker_definitions$marker ==
        "write_outputs"
    ]
)

if (anyNA(required_phase_markers)) {
  stop(
    paste0(
      "One or more required workflow markers were not found:\n",
      paste(
        names(required_phase_markers)[
          is.na(required_phase_markers)
        ],
        collapse = ", "
      )
    ),
    call. = FALSE
  )
}

assign_phase <- function(start_line) {
  if (start_line < required_phase_markers[["cli_arguments"]]) {
    return("bootstrap_and_module_loading")
  }

  if (start_line < required_phase_markers[["read_input"]]) {
    return("cli_configuration_and_setup")
  }

  if (
    start_line <
      required_phase_markers[["build_string_subnetwork"]]
  ) {
    return("input_normalization_and_string_mapping")
  }

  if (
    start_line <
      required_phase_markers[["calculate_network_metrics"]]
  ) {
    return("string_subnetwork_construction")
  }

  if (
    start_line <
      required_phase_markers[["functional_enrichment"]]
  ) {
    return("network_metrics_modules_and_candidates")
  }

  if (
    start_line <
      required_phase_markers[["write_outputs"]]
  ) {
    return("enrichment_and_module_annotation")
  }

  "reporting_export_and_completion"
}

inventory$phase <- vapply(
  inventory$start_line,
  assign_phase,
  FUN.VALUE = character(1)
)

inventory <- inventory[
  c(
    "expression_index",
    "phase",
    "start_line",
    "end_line",
    "line_span",
    "call_head",
    "assignment_target",
    "is_function_definition",
    "preview"
  )
]

phase_summary <- aggregate(
  cbind(
    expression_count = inventory$expression_index,
    total_lines = inventory$line_span
  ),
  by = list(
    phase = inventory$phase
  ),
  FUN = function(values) {
    if (length(values) == 0L) {
      return(0L)
    }

    if (
      all(values %in% inventory$expression_index)
    ) {
      return(length(values))
    }

    sum(values)
  }
)

phase_order <- c(
  "bootstrap_and_module_loading",
  "cli_configuration_and_setup",
  "input_normalization_and_string_mapping",
  "string_subnetwork_construction",
  "network_metrics_modules_and_candidates",
  "enrichment_and_module_annotation",
  "reporting_export_and_completion"
)

phase_rows <- lapply(
  phase_order,
  function(phase_name) {
    phase_inventory <- inventory[
      inventory$phase == phase_name,
      ,
      drop = FALSE
    ]

    data.frame(
      phase = phase_name,
      expression_count = nrow(phase_inventory),
      first_line = if (nrow(phase_inventory) == 0L) {
        NA_integer_
      } else {
        min(phase_inventory$start_line)
      },
      last_line = if (nrow(phase_inventory) == 0L) {
        NA_integer_
      } else {
        max(phase_inventory$end_line)
      },
      covered_source_lines = if (
        nrow(phase_inventory) == 0L
      ) {
        0L
      } else {
        sum(phase_inventory$line_span)
      },
      stringsAsFactors = FALSE
    )
  }
)

phase_summary <- do.call(
  rbind,
  phase_rows
)

large_expressions <- inventory[
  inventory$line_span >= 20L,
  c(
    "expression_index",
    "phase",
    "start_line",
    "end_line",
    "line_span",
    "call_head",
    "assignment_target",
    "preview"
  ),
  drop = FALSE
]

dir.create(
  dirname(output_csv),
  recursive = TRUE,
  showWarnings = FALSE
)

utils::write.csv(
  inventory,
  output_csv,
  row.names = FALSE,
  na = ""
)

utils::write.csv(
  marker_definitions,
  output_markers_csv,
  row.names = FALSE,
  na = ""
)

summary_lines <- c(
  "CancerPPIr current orchestration inventory",
  "==========================================",
  "",
  paste0(
    "Source file: ",
    source_file
  ),
  paste0(
    "Source MD5: ",
    unname(
      tools::md5sum(source_file)
    )
  ),
  paste0(
    "Physical lines: ",
    length(source_lines)
  ),
  paste0(
    "Top-level expressions: ",
    nrow(inventory)
  ),
  paste0(
    "Top-level function definitions: ",
    sum(inventory$is_function_definition)
  ),
  "",
  "Workflow markers",
  "----------------",
  paste0(
    marker_definitions$marker,
    ": line ",
    ifelse(
      is.na(marker_definitions$line),
      "NOT FOUND",
      marker_definitions$line
    ),
    "; expression ",
    ifelse(
      is.na(marker_definitions$expression_index),
      "NOT FOUND",
      marker_definitions$expression_index
    )
  ),
  "",
  "Expressions by phase",
  "--------------------",
  paste0(
    phase_summary$phase,
    ": ",
    phase_summary$expression_count,
    " expressions; lines ",
    phase_summary$first_line,
    "-",
    phase_summary$last_line
  ),
  "",
  paste0(
    "Expressions spanning at least 20 lines: ",
    nrow(large_expressions)
  )
)

if (nrow(large_expressions) > 0L) {
  summary_lines <- c(
    summary_lines,
    paste0(
      "Expression ",
      large_expressions$expression_index,
      ": lines ",
      large_expressions$start_line,
      "-",
      large_expressions$end_line,
      " (",
      large_expressions$line_span,
      " lines); phase=",
      large_expressions$phase,
      "; head=",
      large_expressions$call_head,
      ifelse(
        is.na(large_expressions$assignment_target),
        "",
        paste0(
          "; target=",
          large_expressions$assignment_target
        )
      )
    )
  )
}

writeLines(
  summary_lines,
  output_summary,
  useBytes = TRUE
)

if (sum(inventory$is_function_definition) != 0L) {
  stop(
    "Unexpected top-level function definitions remain in cancerppir.R.",
    call. = FALSE
  )
}

message(
  "[orchestration inventory] Inventory completed."
)

message(
  "[orchestration inventory] Source lines: ",
  length(source_lines),
  "."
)

message(
  "[orchestration inventory] Top-level expressions: ",
  nrow(inventory),
  "."
)

message(
  "[orchestration inventory] Top-level function definitions: 0."
)

message(
  "[orchestration inventory] Inventory: ",
  output_csv
)

message(
  "[orchestration inventory] Markers: ",
  output_markers_csv
)

message(
  "[orchestration inventory] Summary: ",
  output_summary
)

message(
  "[orchestration inventory] cancerppir.R was not modified."
)