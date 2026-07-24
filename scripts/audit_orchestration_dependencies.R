#!/usr/bin/env Rscript

# Audit dependencies between extracted CancerPPIr functions and objects
# that are still assigned by the top-level cancerppir.R orchestration.
#
# This script does not modify analytical source files.
#
# Run from the repository root:
#   Rscript scripts/audit_orchestration_dependencies.R

source_file <- "cancerppir.R"
loader_file <- file.path(
  "R",
  "load_all.R"
)

function_map_file <- file.path(
  "docs",
  "architecture",
  "target_function_module_map.csv"
)

orchestration_inventory_file <- file.path(
  "docs",
  "architecture",
  "checkpoint_2_10_current_orchestration_inventory.csv"
)

output_dependencies <- file.path(
  "docs",
  "architecture",
  "checkpoint_2_10_function_orchestration_dependencies.csv"
)

output_assignments <- file.path(
  "docs",
  "architecture",
  "checkpoint_2_10_orchestration_assignments.csv"
)

output_summary <- file.path(
  "docs",
  "architecture",
  "checkpoint_2_10_dependency_audit_summary.txt"
)

required_files <- c(
  source_file,
  loader_file,
  function_map_file,
  orchestration_inventory_file
)

missing_files <- required_files[
  !file.exists(required_files)
]

if (length(missing_files) > 0L) {
  stop(
    paste0(
      "Required files are missing:\n",
      paste(
        paste0("- ", missing_files),
        collapse = "\n"
      )
    ),
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
      "Inspect or restore it before running the dependency audit."
    ),
    call. = FALSE
  )
}

if (!requireNamespace(
  "codetools",
  quietly = TRUE
)) {
  stop(
    "The recommended R package 'codetools' is unavailable.",
    call. = FALSE
  )
}

get_call_head <- function(expression) {
  if (!is.call(expression)) {
    return(NA_character_)
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

collect_assigned_symbols <- function(expression) {
  assigned <- character()

  walk_expression <- function(node) {
    if (!is.call(node)) {
      return(invisible(NULL))
    }

    call_head <- get_call_head(node)

    # Do not interpret assignments inside nested function bodies as
    # top-level orchestration assignments.
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

      # The right-hand side can itself contain assignments.
      walk_expression(
        node[[3L]]
      )

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

      walk_expression(
        node[[3L]]
      )

      walk_expression(
        node[[4L]]
      )

      return(invisible(NULL))
    }

    if (
      identical(call_head, "local") &&
        length(node) >= 2L
    ) {
      return(invisible(NULL))
    }

    if (length(node) >= 2L) {
      for (element_index in 2:length(node)) {
        walk_expression(
          node[[element_index]]
        )
      }
    }

    invisible(NULL)
  }

  walk_expression(
    expression
  )

  sort(
    unique(assigned)
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
      "Function map is missing columns: ",
      paste(
        missing_map_columns,
        collapse = ", "
      )
    ),
    call. = FALSE
  )
}

if (
  nrow(function_map) != 63L ||
    anyDuplicated(function_map$function_name)
) {
  stop(
    paste0(
      "Expected 63 uniquely mapped functions, observed ",
      nrow(function_map),
      "."
    ),
    call. = FALSE
  )
}

orchestration_inventory <- utils::read.csv(
  orchestration_inventory_file,
  stringsAsFactors = FALSE,
  check.names = FALSE
)

required_inventory_columns <- c(
  "expression_index",
  "phase",
  "start_line",
  "end_line"
)

missing_inventory_columns <- setdiff(
  required_inventory_columns,
  names(orchestration_inventory)
)

if (length(missing_inventory_columns) > 0L) {
  stop(
    paste0(
      "Orchestration inventory is missing columns: ",
      paste(
        missing_inventory_columns,
        collapse = ", "
      )
    ),
    call. = FALSE
  )
}

parsed <- parse(
  file = source_file,
  keep.source = TRUE
)

if (
  length(parsed) !=
    nrow(orchestration_inventory)
) {
  stop(
    paste0(
      "Expression count differs between cancerppir.R and the inventory.\n",
      "Source: ",
      length(parsed),
      "\nInventory: ",
      nrow(orchestration_inventory)
    ),
    call. = FALSE
  )
}

assignment_rows <- list()
assignment_row_index <- 1L

for (expression_index in seq_along(parsed)) {
  assigned_symbols <- collect_assigned_symbols(
    parsed[[expression_index]]
  )

  if (length(assigned_symbols) == 0L) {
    next
  }

  inventory_row <- orchestration_inventory[
    orchestration_inventory$expression_index ==
      expression_index,
    ,
    drop = FALSE
  ]

  if (nrow(inventory_row) != 1L) {
    stop(
      paste0(
        "Could not resolve inventory row for expression ",
        expression_index,
        "."
      ),
      call. = FALSE
    )
  }

  for (assigned_symbol in assigned_symbols) {
    assignment_rows[[assignment_row_index]] <-
      data.frame(
        assigned_symbol = assigned_symbol,
        expression_index = expression_index,
        phase = inventory_row$phase,
        start_line = inventory_row$start_line,
        end_line = inventory_row$end_line,
        stringsAsFactors = FALSE
      )

    assignment_row_index <-
      assignment_row_index + 1L
  }
}

if (length(assignment_rows) == 0L) {
  stop(
    "No orchestration assignments were detected.",
    call. = FALSE
  )
}

orchestration_assignments <- do.call(
  rbind,
  assignment_rows
)

orchestration_assignments <-
  orchestration_assignments[
    order(
      orchestration_assignments$start_line,
      orchestration_assignments$assigned_symbol
    ),
    ,
    drop = FALSE
  ]

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
  missing_functions <- function_map$function_name[
    !function_status
  ]

  stop(
    paste0(
      "Mapped functions unavailable through the loader:\n",
      paste(
        paste0("- ", missing_functions),
        collapse = "\n"
      )
    ),
    call. = FALSE
  )
}

assigned_symbol_names <- unique(
  orchestration_assignments$assigned_symbol
)

dependency_rows <- list()
dependency_row_index <- 1L

for (
  function_index in
  seq_len(nrow(function_map))
) {
  function_name <-
    function_map$function_name[[
      function_index
    ]]

  target_file <-
    function_map$target_file[[
      function_index
    ]]

  function_object <- get(
    function_name,
    envir = module_environment,
    inherits = FALSE
  )

  globals <- codetools::findGlobals(
    function_object,
    merge = FALSE
  )

  referenced_variables <- sort(
    unique(
      globals$variables
    )
  )

  orchestration_dependencies <- intersect(
    referenced_variables,
    assigned_symbol_names
  )

  if (length(orchestration_dependencies) == 0L) {
    next
  }

  for (
    dependency_name in
    orchestration_dependencies
  ) {
    assignment_locations <-
      orchestration_assignments[
        orchestration_assignments$assigned_symbol ==
          dependency_name,
        ,
        drop = FALSE
      ]

    location_text <- paste(
      paste0(
        "expression_",
        assignment_locations$expression_index,
        ":lines_",
        assignment_locations$start_line,
        "-",
        assignment_locations$end_line,
        ":",
        assignment_locations$phase
      ),
      collapse = " | "
    )

    dependency_rows[[dependency_row_index]] <-
      data.frame(
        function_name = function_name,
        target_file = target_file,
        orchestration_dependency =
          dependency_name,
        assignment_locations =
          location_text,
        stringsAsFactors = FALSE
      )

    dependency_row_index <-
      dependency_row_index + 1L
  }
}

if (length(dependency_rows) == 0L) {
  function_dependencies <- data.frame(
    function_name = character(),
    target_file = character(),
    orchestration_dependency = character(),
    assignment_locations = character(),
    stringsAsFactors = FALSE
  )
} else {
  function_dependencies <- do.call(
    rbind,
    dependency_rows
  )

  function_dependencies <-
    function_dependencies[
      order(
        function_dependencies$orchestration_dependency,
        function_dependencies$target_file,
        function_dependencies$function_name
      ),
      ,
      drop = FALSE
    ]
}

dependent_function_names <- unique(
  function_dependencies$function_name
)

dependency_names <- unique(
  function_dependencies$orchestration_dependency
)

dependency_summary_rows <- lapply(
  dependency_names,
  function(dependency_name) {
    affected <- function_dependencies[
      function_dependencies$orchestration_dependency ==
        dependency_name,
      ,
      drop = FALSE
    ]

    paste0(
      dependency_name,
      ": ",
      paste(
        affected$function_name,
        collapse = ", "
      )
    )
  }
)

summary_lines <- c(
  "CancerPPIr orchestration dependency audit",
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
    "Extracted functions analyzed: ",
    nrow(function_map)
  ),
  paste0(
    "Top-level orchestration expressions: ",
    length(parsed)
  ),
  paste0(
    "Assigned orchestration symbols detected: ",
    length(assigned_symbol_names)
  ),
  paste0(
    "Functions with orchestration dependencies: ",
    length(dependent_function_names)
  ),
  paste0(
    "Unique orchestration dependencies referenced by functions: ",
    length(dependency_names)
  ),
  "",
  "Dependencies referenced from extracted functions",
  "-----------------------------------------------"
)

if (length(dependency_summary_rows) == 0L) {
  summary_lines <- c(
    summary_lines,
    "No dependencies detected."
  )
} else {
  summary_lines <- c(
    summary_lines,
    unlist(
      dependency_summary_rows,
      use.names = FALSE
    )
  )
}

summary_lines <- c(
  summary_lines,
  "",
  "Interpretation",
  "--------------",
  paste0(
    "Any listed dependency must be moved into a stable module, ",
    "passed explicitly as a function argument, or deliberately ",
    "preserved in the defining environment before the workflow ",
    "is wrapped inside run_cancerppir()."
  )
)

dir.create(
  dirname(output_dependencies),
  recursive = TRUE,
  showWarnings = FALSE
)

utils::write.csv(
  function_dependencies,
  output_dependencies,
  row.names = FALSE,
  na = ""
)

utils::write.csv(
  orchestration_assignments,
  output_assignments,
  row.names = FALSE,
  na = ""
)

writeLines(
  summary_lines,
  output_summary,
  useBytes = TRUE
)

message(
  "[dependency audit] Audit completed."
)

message(
  "[dependency audit] Functions analyzed: ",
  nrow(function_map),
  "."
)

message(
  "[dependency audit] Assigned orchestration symbols: ",
  length(assigned_symbol_names),
  "."
)

message(
  "[dependency audit] Functions with orchestration dependencies: ",
  length(dependent_function_names),
  "."
)

message(
  "[dependency audit] Unique dependencies: ",
  length(dependency_names),
  "."
)

message(
  "[dependency audit] Dependency table: ",
  output_dependencies
)

message(
  "[dependency audit] Assignment table: ",
  output_assignments
)

message(
  "[dependency audit] Summary: ",
  output_summary
)

message(
  "[dependency audit] No analytical source files were modified."
)