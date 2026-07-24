#!/usr/bin/env Rscript

# CancerPPIr Phase 4.5 multicase checkpoint v2
#
# One consolidated regression checkpoint with source-aware mapping validation:
#   1. runs the complete unit-test suite once;
#   2. runs or revalidates the existing seven-case technical-export validator;
#   3. validates the new six-sheet analytical workbook for all seven cases;
#   4. verifies exact source-derived Final priorities, Module priorities,
#      Candidate evidence and Methods and limitations tables;
#   5. verifies GraphML readability and key graph-derived summary values.
#
# Optional positional arguments:
#   1. input directory
#   2. output directory
#   3. STRING cache directory
#   4. execution mode: run-pipeline or validate-existing
#   5. unit-test mode: run-unit-tests or skip-unit-tests
#
# Defaults:
#   ../input
#   ../results/phase4_5_multicase_checkpoint_v1
#   ../string_cache
#   run-pipeline
#   run-unit-tests
#
# Examples:
#   Rscript scripts/run_phase4_5_multicase_checkpoint.R
#
#   Rscript scripts/run_phase4_5_multicase_checkpoint.R \
#     "..\input" \
#     "..\results\phase4_5_multicase_checkpoint_v1" \
#     "..\string_cache" \
#     validate-existing

required_packages <- c(
  "openxlsx",
  "igraph"
)

missing_packages <- required_packages[
  !vapply(
    required_packages,
    requireNamespace,
    FUN.VALUE = logical(1),
    quietly = TRUE
  )
]

if (length(missing_packages) > 0L) {
  stop(
    paste0(
      "Required package(s) are not installed: ",
      paste(
        missing_packages,
        collapse = ", "
      ),
      "."
    ),
    call. = FALSE
  )
}

arguments <- commandArgs(
  trailingOnly = TRUE
)

project_root <- normalizePath(
  ".",
  winslash = "/",
  mustWork = TRUE
)

input_root <- if (length(arguments) >= 1L) {
  arguments[[1L]]
} else {
  file.path(
    "..",
    "input"
  )
}

output_root <- if (length(arguments) >= 2L) {
  arguments[[2L]]
} else {
  file.path(
    "..",
    "results",
    "phase4_5_multicase_checkpoint_v1"
  )
}

cache_root <- if (length(arguments) >= 3L) {
  arguments[[3L]]
} else {
  file.path(
    "..",
    "string_cache"
  )
}

execution_mode <- if (length(arguments) >= 4L) {
  tolower(
    trimws(
      as.character(
        arguments[[4L]]
      )
    )
  )
} else {
  "run-pipeline"
}

valid_execution_modes <- c(
  "run-pipeline",
  "validate-existing"
)

if (!(execution_mode %in% valid_execution_modes)) {
  stop(
    paste0(
      "Unsupported execution mode: ",
      execution_mode,
      ". Use run-pipeline or validate-existing."
    ),
    call. = FALSE
  )
}

validate_existing <- identical(
  execution_mode,
  "validate-existing"
)

unit_test_mode <- if (length(arguments) >= 5L) {
  tolower(
    trimws(
      as.character(
        arguments[[5L]]
      )
    )
  )
} else {
  "run-unit-tests"
}

valid_unit_test_modes <- c(
  "run-unit-tests",
  "skip-unit-tests"
)

if (!(unit_test_mode %in% valid_unit_test_modes)) {
  stop(
    paste0(
      "Unsupported unit-test mode: ",
      unit_test_mode,
      ". Use run-unit-tests or skip-unit-tests."
    ),
    call. = FALSE
  )
}

run_unit_tests <- identical(
  unit_test_mode,
  "run-unit-tests"
)

if (!dir.exists(input_root)) {
  stop(
    paste0(
      "Input directory does not exist: ",
      input_root
    ),
    call. = FALSE
  )
}

if (!dir.exists(cache_root)) {
  stop(
    paste0(
      "STRING cache directory does not exist: ",
      cache_root
    ),
    call. = FALSE
  )
}

input_root <- normalizePath(
  input_root,
  winslash = "/",
  mustWork = TRUE
)

cache_root <- normalizePath(
  cache_root,
  winslash = "/",
  mustWork = TRUE
)

if (validate_existing) {
  if (!dir.exists(output_root)) {
    stop(
      paste0(
        "validate-existing mode requires an existing output directory: ",
        output_root
      ),
      call. = FALSE
    )
  }

  existing_output <- list.files(
    output_root,
    all.files = TRUE,
    no.. = TRUE
  )

  if (length(existing_output) == 0L) {
    stop(
      paste0(
        "validate-existing mode requires a non-empty output directory: ",
        output_root
      ),
      call. = FALSE
    )
  }
} else {
  if (dir.exists(output_root)) {
    existing_output <- list.files(
      output_root,
      all.files = TRUE,
      no.. = TRUE
    )

    if (length(existing_output) > 0L) {
      stop(
        paste0(
          "Output directory already exists and is not empty: ",
          output_root,
          "\nRemove it, pass a different second argument, or use validate-existing."
        ),
        call. = FALSE
      )
    }
  }
}

case_map <- data.frame(
  sample_id = c(
    "A01",
    "K01",
    "L01",
    "M01",
    "P01",
    "P02",
    "R01"
  ),
  input_file = c(
    "Genes_A.csv",
    "Genes_K.csv",
    "Genes_L.csv",
    "Genes_M.csv",
    "Genes_P01.csv",
    "Genes_P02.csv",
    "Genes_R.csv"
  ),
  output_folder = c(
    "Genes_A",
    "Genes_K",
    "Genes_L",
    "Genes_M",
    "Genes_P01",
    "Genes_P02",
    "Genes_R"
  ),
  stringsAsFactors = FALSE
)

missing_input_files <- file.path(
  input_root,
  case_map$input_file
)

missing_input_files <- missing_input_files[
  !file.exists(
    missing_input_files
  )
]

if (length(missing_input_files) > 0L) {
  stop(
    paste0(
      "Required clinical input file(s) are missing:\n",
      paste0(
        "- ",
        missing_input_files,
        collapse = "\n"
      )
    ),
    call. = FALSE
  )
}

unit_test_runner <- file.path(
  project_root,
  "scripts",
  "run_unit_tests.R"
)

technical_validator <- file.path(
  project_root,
  "scripts",
  "run_phase4_multicase_technical_export_validation.R"
)

loader_file <- file.path(
  project_root,
  "R",
  "load_all.R"
)

required_project_files <- c(
  unit_test_runner,
  technical_validator,
  loader_file
)

missing_project_files <- required_project_files[
  !file.exists(
    required_project_files
  )
]

if (length(missing_project_files) > 0L) {
  stop(
    paste0(
      "Required project file(s) are missing:\n",
      paste0(
        "- ",
        missing_project_files,
        collapse = "\n"
      )
    ),
    call. = FALSE
  )
}

rscript_command <- file.path(
  R.home("bin"),
  if (.Platform$OS.type == "windows") {
    "Rscript.exe"
  } else {
    "Rscript"
  }
)

tail_log <- function(
  path,
  maximum_lines = 80L
) {
  if (!file.exists(path)) {
    return(
      "Log file was not created."
    )
  }

  paste(
    tail(
      readLines(
        path,
        warn = FALSE,
        encoding = "UTF-8"
      ),
      maximum_lines
    ),
    collapse = "\n"
  )
}

unit_test_log_temporary <- tempfile(
  pattern = "phase4_5_multicase_unit_tests_",
  fileext = ".log"
)

technical_validator_log_temporary <- tempfile(
  pattern = "phase4_5_multicase_technical_validator_",
  fileext = ".log"
)

on.exit(
  unlink(
    c(
      unit_test_log_temporary,
      technical_validator_log_temporary
    )
  ),
  add = TRUE
)

if (run_unit_tests) {
  message(
    "[Phase 4.5 multicase] Running unit tests once."
  )

  unit_test_status <- system2(
    command = rscript_command,
    args = shQuote(
      unit_test_runner
    ),
    stdout = unit_test_log_temporary,
    stderr = unit_test_log_temporary,
    wait = TRUE
  )

  if (
    is.null(unit_test_status) ||
      is.na(unit_test_status) ||
      unit_test_status != 0L
  ) {
    stop(
      paste0(
        "Unit tests failed with exit status ",
        unit_test_status,
        ".\n\nLog tail:\n",
        tail_log(
          unit_test_log_temporary
        )
      ),
      call. = FALSE
    )
  }

  message(
    "[Phase 4.5 multicase] Unit tests: PASS."
  )
} else {
  writeLines(
    "Unit tests skipped because they were already completed by the parent release checkpoint.",
    unit_test_log_temporary,
    useBytes = TRUE
  )

  message(
    "[Phase 4.5 multicase] Unit tests: SKIPPED (completed by parent checkpoint)."
  )
}

technical_arguments <- c(
  shQuote(
    technical_validator
  ),
  shQuote(
    input_root
  ),
  shQuote(
    output_root
  ),
  shQuote(
    cache_root
  )
)

if (validate_existing) {
  technical_arguments <- c(
    technical_arguments,
    "validate-existing"
  )
}

message(
  "[Phase 4.5 multicase] ",
  if (validate_existing) {
    "Revalidating existing seven-case outputs."
  } else {
    "Running seven production cases and validating technical exports."
  }
)

technical_status <- system2(
  command = rscript_command,
  args = technical_arguments,
  stdout = technical_validator_log_temporary,
  stderr = technical_validator_log_temporary,
  wait = TRUE
)

if (
  is.null(technical_status) ||
    is.na(technical_status) ||
    technical_status != 0L
) {
  stop(
    paste0(
      "Seven-case technical validator failed with exit status ",
      technical_status,
      ".\n\nLog tail:\n",
      tail_log(
        technical_validator_log_temporary,
        maximum_lines = 120L
      )
    ),
    call. = FALSE
  )
}

output_root <- normalizePath(
  output_root,
  winslash = "/",
  mustWork = TRUE
)

invisible(
  file.copy(
    unit_test_log_temporary,
  file.path(
    output_root,
    "phase4_5_unit_tests.log"
  ),
    overwrite = TRUE
  )
)

invisible(
  file.copy(
    technical_validator_log_temporary,
  file.path(
    output_root,
    "phase4_5_technical_validator.log"
  ),
    overwrite = TRUE
  )
)

source(
  loader_file,
  local = .GlobalEnv
)

load_cancerppir_modules(
  project_root = project_root,
  envir = .GlobalEnv
)

expected_columns <- phase4_expected_analytical_columns()

read_sheet <- function(
  workbook,
  sheet
) {
  as.data.frame(
    openxlsx::read.xlsx(
      workbook,
      sheet = sheet,
      colNames = TRUE,
      check.names = FALSE,
      detectDates = TRUE
    ),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
}

normalize_character <- function(x) {
  x <- as.character(x)
  x[is.na(x)] <- ""
  x
}

compare_frames <- function(
  observed,
  expected,
  tolerance = 1e-10
) {
  if (!identical(
    names(observed),
    names(expected)
  )) {
    return(
      list(
        pass = FALSE,
        details = paste0(
          "column mismatch; observed=",
          paste(
            names(observed),
            collapse = " | "
          ),
          "; expected=",
          paste(
            names(expected),
            collapse = " | "
          )
        )
      )
    )
  }

  if (nrow(observed) != nrow(expected)) {
    return(
      list(
        pass = FALSE,
        details = paste0(
          "row-count mismatch; observed=",
          nrow(observed),
          "; expected=",
          nrow(expected)
        )
      )
    )
  }

  differing_columns <- character(0)

  for (column_name in names(expected)) {
    expected_column <- expected[[column_name]]
    observed_column <- observed[[column_name]]

    column_pass <- if (
      is.numeric(expected_column) ||
        is.integer(expected_column)
    ) {
      expected_numeric <- suppressWarnings(
        as.numeric(
          expected_column
        )
      )

      observed_numeric <- suppressWarnings(
        as.numeric(
          observed_column
        )
      )

      same_missing <- identical(
        is.na(expected_numeric),
        is.na(observed_numeric)
      )

      finite_index <- (
        !is.na(expected_numeric) &
          !is.na(observed_numeric) &
          is.finite(expected_numeric) &
          is.finite(observed_numeric)
      )

      finite_pass <- all(
        abs(
          expected_numeric[finite_index] -
            observed_numeric[finite_index]
        ) <=
          tolerance *
            pmax(
              1,
              abs(
                expected_numeric[finite_index]
              )
            )
      )

      nonfinite_index <- (
        !is.na(expected_numeric) &
          !is.na(observed_numeric) &
          (
            !is.finite(expected_numeric) |
              !is.finite(observed_numeric)
          )
      )

      nonfinite_pass <- all(
        expected_numeric[nonfinite_index] ==
          observed_numeric[nonfinite_index]
      )

      same_missing &&
        finite_pass &&
        nonfinite_pass
    } else if (is.logical(expected_column)) {
      identical(
        as.logical(
          observed_column
        ),
        as.logical(
          expected_column
        )
      )
    } else {
      identical(
        normalize_character(
          observed_column
        ),
        normalize_character(
          expected_column
        )
      )
    }

    if (!isTRUE(column_pass)) {
      differing_columns <- c(
        differing_columns,
        column_name
      )
    }
  }

  list(
    pass = length(differing_columns) == 0L,
    details = if (length(differing_columns) == 0L) {
      "exact within numeric tolerance"
    } else {
      paste0(
        "differing column(s): ",
        paste(
          differing_columns,
          collapse = " | "
        )
      )
    }
  )
}

all_checks <- list()
case_summaries <- list()

add_check <- function(
  sample_id,
  check_id,
  condition,
  details = ""
) {
  all_checks[[
    paste(
      sample_id,
      check_id,
      length(all_checks) + 1L,
      sep = "::"
    )
  ]] <<- data.frame(
    sample_id = sample_id,
    check_id = check_id,
    status = if (isTRUE(condition)) {
      "PASS"
    } else {
      "FAIL"
    },
    details = as.character(details),
    stringsAsFactors = FALSE
  )
}

executive_items <- c(
  "input_rows",
  "mapped_proteins",
  "unmapped_input_rows",
  "mapping_rate_percent",
  "network_nodes",
  "network_edges",
  "connected_components",
  "largest_component_nodes",
  "largest_component_fraction",
  "louvain_modules",
  "priority_eligible_modules",
  "technical_or_covariate_modules",
  "mixed_biological_modules",
  "unresolved_modules",
  "final_priority_candidates",
  "run_configuration"
)

network_metric_items <- c(
  "nodes",
  "edges",
  "components",
  "largest_component_nodes",
  "largest_component_fraction",
  "density",
  "average_degree",
  "global_clustering",
  "average_shortest_path_lcc",
  "diameter_lcc",
  "radius_lcc",
  "louvain_communities",
  "louvain_modularity",
  "string_score_threshold"
)

for (case_index in seq_len(
  nrow(case_map)
)) {
  sample_id <- case_map$sample_id[[case_index]]

  message(
    "[Phase 4.5 multicase] Validating analytical workbook for ",
    sample_id,
    "."
  )

  case_error <- NULL

  tryCatch(
    {
      case_directory <- file.path(
        output_root,
        case_map$output_folder[[case_index]]
      )

      analytical_workbook <- file.path(
        case_directory,
        "CancerPPIr_Analytical_Report.xlsx"
      )

      technical_workbook <- file.path(
        case_directory,
        "CancerPPIr_Technical_Report.xlsx"
      )

      graphml_file <- file.path(
        case_directory,
        "Network_for_Cytoscape.graphml"
      )

      required_outputs <- c(
        analytical_workbook,
        technical_workbook,
        graphml_file,
        file.path(
          case_directory,
          "STRING_links.txt"
        )
      )

      add_check(
        sample_id,
        "required_output_files_exist",
        all(
          file.exists(
            required_outputs
          )
        ),
        paste(
          basename(
            required_outputs[
              !file.exists(
                required_outputs
              )
            ]
          ),
          collapse = " | "
        )
      )

      if (!all(
        file.exists(
          required_outputs
        )
      )) {
        stop(
          "One or more required output files are missing.",
          call. = FALSE
        )
      }

      analytical_sheet_names <- openxlsx::getSheetNames(
        analytical_workbook
      )

      add_check(
        sample_id,
        "exact_analytical_sheet_order",
        identical(
          analytical_sheet_names,
          CANCERPPIR_ANALYTICAL_SHEET_NAMES
        ),
        paste(
          analytical_sheet_names,
          collapse = " | "
        )
      )

      sheets <- lapply(
        CANCERPPIR_ANALYTICAL_SHEET_NAMES,
        function(sheet_name) {
          read_sheet(
            analytical_workbook,
            sheet_name
          )
        }
      )

      names(sheets) <- CANCERPPIR_ANALYTICAL_SHEET_NAMES

      for (sheet_name in names(
        expected_columns
      )) {
        add_check(
          sample_id,
          paste0(
            "schema_",
            gsub(
              "[^a-z0-9]+",
              "_",
              tolower(
                sheet_name
              )
            )
          ),
          identical(
            names(
              sheets[[sheet_name]]
            ),
            expected_columns[[sheet_name]]
          ),
          paste(
            names(
              sheets[[sheet_name]]
            ),
            collapse = " | "
          )
        )
      }

      node_annotations <- read_sheet(
        technical_workbook,
        "Phase4 node annotations"
      )

      module_annotations <- read_sheet(
        technical_workbook,
        "Phase4 module annotations"
      )

      significant_terms <- read_sheet(
        technical_workbook,
        "Phase4 significant terms"
      )

      phase4_validation <- read_sheet(
        technical_workbook,
        "Phase4 validation"
      )

      mapping_summary <- read_sheet(
        technical_workbook,
        "Mapping summary"
      )

      genes_used_table <- read_sheet(
        technical_workbook,
        "Genes used table"
      )

      phase4_require_columns(
        mapping_summary,
        c(
          "metric",
          "value"
        ),
        "Mapping summary"
      )

      mapping_metric_values <- setNames(
        suppressWarnings(
          as.numeric(
            mapping_summary$value
          )
        ),
        as.character(
          mapping_summary$metric
        )
      )

      required_mapping_metrics <- c(
        "input_rows",
        "final_unmapped",
        "final_mapped_percent",
        "nodes_in_network"
      )

      missing_mapping_metrics <- setdiff(
        required_mapping_metrics,
        names(
          mapping_metric_values
        )
      )

      if (length(missing_mapping_metrics) > 0L) {
        stop(
          paste0(
            "Mapping summary is missing required metric(s): ",
            paste(
              missing_mapping_metrics,
              collapse = ", "
            ),
            "."
          ),
          call. = FALSE
        )
      }

      graph <- igraph::read_graph(
        graphml_file,
        format = "graphml"
      )

      graph_nodes <- igraph::gorder(
        graph
      )

      graph_edges <- igraph::gsize(
        graph
      )

      graph_components <- igraph::components(
        graph
      )$no

      candidate_audit <- phase4_prepare_candidate_table(
        node_annotations
      )

      in_memory_validation <- tryCatch(
        validate_phase4_analytical_workbook(
          sheets = sheets,
          candidate_audit = candidate_audit,
          significant_terms = significant_terms,
          phase4_validation = phase4_validation,
          fdr_threshold = 0.05
        ),
        error = function(error) {
          error
        }
      )

      add_check(
        sample_id,
        "in_memory_analytical_validation",
        !inherits(
          in_memory_validation,
          "error"
        ),
        if (inherits(
          in_memory_validation,
          "error"
        )) {
          conditionMessage(
            in_memory_validation
          )
        } else {
          paste0(
            nrow(in_memory_validation),
            " checks passed"
          )
        }
      )

      expected_final_priorities <-
        phase4_build_final_priorities(
          candidates = candidate_audit,
          maximum_rows = 10L
        )

      expected_module_priorities <-
        phase4_build_module_priorities(
          module_annotations = module_annotations,
          network_nodes = graph_nodes,
          maximum_rows = 5L
        )

      expected_candidate_evidence <-
        phase4_build_candidate_evidence(
          candidates = candidate_audit,
          final_priorities =
            expected_final_priorities,
          top_n = 30L
        )

      expected_methods <-
        phase4_build_methods_and_limitations()

      final_comparison <- compare_frames(
        sheets[[
          "Final priorities"
        ]],
        expected_final_priorities
      )

      module_comparison <- compare_frames(
        sheets[[
          "Module priorities"
        ]],
        expected_module_priorities
      )

      candidate_comparison <- compare_frames(
        sheets[[
          "Candidate evidence"
        ]],
        expected_candidate_evidence
      )

      methods_comparison <- compare_frames(
        sheets[[
          "Methods and limitations"
        ]],
        expected_methods
      )

      add_check(
        sample_id,
        "final_priorities_match_phase4_source",
        final_comparison$pass,
        final_comparison$details
      )

      add_check(
        sample_id,
        "module_priorities_match_phase4_source",
        module_comparison$pass,
        module_comparison$details
      )

      add_check(
        sample_id,
        "candidate_evidence_matches_phase4_source",
        candidate_comparison$pass,
        candidate_comparison$details
      )

      add_check(
        sample_id,
        "methods_table_is_exact",
        methods_comparison$pass,
        methods_comparison$details
      )

      executive_summary <- sheets[[
        "Executive summary"
      ]]

      add_check(
        sample_id,
        "executive_item_order",
        identical(
          as.character(
            executive_summary$item
          ),
          executive_items
        ),
        paste(
          executive_summary$item,
          collapse = " | "
        )
      )

      executive_values <- setNames(
        as.character(
          executive_summary$value
        ),
        as.character(
          executive_summary$item
        )
      )

      module_class <- as.character(
        module_annotations$interpretation_class
      )

      priority_eligible <- (
        !is.na(
          module_annotations$priority_eligible
        ) &
          as.logical(
            module_annotations$priority_eligible
          )
      )

      conflict_detected <- (
        !is.na(
          module_annotations$conflict_detected
        ) &
          as.logical(
            module_annotations$conflict_detected
          )
      )

      expected_executive_numeric <- c(
        input_rows =
          mapping_metric_values[[
            "input_rows"
          ]],
        mapped_proteins =
          mapping_metric_values[[
            "nodes_in_network"
          ]],
        unmapped_input_rows =
          mapping_metric_values[[
            "final_unmapped"
          ]],
        mapping_rate_percent =
          mapping_metric_values[[
            "final_mapped_percent"
          ]],
        network_nodes =
          graph_nodes,
        network_edges =
          graph_edges,
        connected_components =
          graph_components,
        louvain_modules =
          nrow(module_annotations),
        priority_eligible_modules =
          sum(
            module_class == "biological" &
              priority_eligible &
              !conflict_detected,
            na.rm = TRUE
          ),
        technical_or_covariate_modules =
          sum(
            module_class ==
              "technical_or_covariate",
            na.rm = TRUE
          ),
        mixed_biological_modules =
          sum(
            module_class ==
              "mixed_biological",
            na.rm = TRUE
          ),
        unresolved_modules =
          sum(
            module_class ==
              "unresolved",
            na.rm = TRUE
          ),
        final_priority_candidates =
          nrow(
            expected_final_priorities
          )
      )

      executive_numeric_values <- executive_values[
        names(
          expected_executive_numeric
        )
      ]

      executive_numeric_values[[
        "mapping_rate_percent"
      ]] <- sub(
        "%$",
        "",
        executive_numeric_values[[
          "mapping_rate_percent"
        ]]
      )

      observed_executive_numeric <- suppressWarnings(
        as.numeric(
          executive_numeric_values
        )
      )

      executive_count_difference <- abs(
        observed_executive_numeric -
          as.numeric(
            expected_executive_numeric
          )
      )

      executive_count_tolerance <- rep(
        1e-12,
        length(
          executive_count_difference
        )
      )

      names(executive_count_tolerance) <- names(
        expected_executive_numeric
      )

      executive_count_tolerance[[
        "mapping_rate_percent"
      ]] <- 5e-2

      add_check(
        sample_id,
        "executive_source_counts_match",
        all(
          is.finite(
            observed_executive_numeric
          )
        ) &&
          all(
            executive_count_difference <=
              executive_count_tolerance
          ),
        paste0(
          names(
            expected_executive_numeric
          ),
          "=",
          observed_executive_numeric,
          " (expected ",
          as.numeric(
            expected_executive_numeric
          ),
          ")",
          collapse = "; "
        )
      )

      mapping_stage_consistent <- (
        nrow(genes_used_table) ==
          mapping_metric_values[[
            "nodes_in_network"
          ]] &&
          mapping_metric_values[[
            "input_rows"
          ]] >=
            mapping_metric_values[[
              "nodes_in_network"
            ]] &&
          mapping_metric_values[[
            "nodes_in_network"
          ]] >=
            graph_nodes &&
          mapping_metric_values[[
            "final_unmapped"
          ]] >= 0 &&
          mapping_metric_values[[
            "final_unmapped"
          ]] <=
            mapping_metric_values[[
              "input_rows"
            ]] &&
          mapping_metric_values[[
            "final_mapped_percent"
          ]] >= 0 &&
          mapping_metric_values[[
            "final_mapped_percent"
          ]] <= 100
      )

      add_check(
        sample_id,
        "mapping_stage_internal_consistency",
        mapping_stage_consistent,
        paste0(
          "input_rows=",
          mapping_metric_values[[
            "input_rows"
          ]],
          "; unique_mapped_proteins=",
          mapping_metric_values[[
            "nodes_in_network"
          ]],
          "; genes_used_rows=",
          nrow(genes_used_table),
          "; graph_nodes=",
          graph_nodes,
          "; final_unmapped=",
          mapping_metric_values[[
            "final_unmapped"
          ]],
          "; final_mapped_percent=",
          mapping_metric_values[[
            "final_mapped_percent"
          ]]
        )
      )

      run_configuration <- executive_values[[
        "run_configuration"
      ]]

      required_configuration_tokens <- c(
        "schema=4.5.0",
        "STRING=12.0",
        "score_threshold=400",
        "offline_enrichment=TRUE",
        "FDR<=0.05",
        "Louvain_seed=1729"
      )

      add_check(
        sample_id,
        "run_configuration_is_pinned",
        all(
          vapply(
            required_configuration_tokens,
            function(token) {
              grepl(
                token,
                run_configuration,
                fixed = TRUE
              )
            },
            FUN.VALUE = logical(1)
          )
        ),
        run_configuration
      )

      network_overview <- sheets[[
        "Network overview"
      ]]

      observed_metric_rows <- network_overview[
        network_overview$section ==
          "network_metric",
        ,
        drop = FALSE
      ]

      add_check(
        sample_id,
        "network_metric_order",
        identical(
          as.character(
            observed_metric_rows$item
          ),
          network_metric_items
        ),
        paste(
          observed_metric_rows$item,
          collapse = " | "
        )
      )

      metric_values <- setNames(
        suppressWarnings(
          as.numeric(
            observed_metric_rows$value
          )
        ),
        as.character(
          observed_metric_rows$item
        )
      )

      expected_graph_metrics <- c(
        nodes = graph_nodes,
        edges = graph_edges,
        components = graph_components,
        louvain_communities =
          nrow(module_annotations),
        string_score_threshold = 400
      )

      add_check(
        sample_id,
        "network_metrics_match_graph_and_modules",
        all(
          abs(
            metric_values[
              names(
                expected_graph_metrics
              )
            ] -
              expected_graph_metrics
          ) <= 1e-12
        ),
        paste0(
          names(
            expected_graph_metrics
          ),
          "=",
          metric_values[
            names(
              expected_graph_metrics
            )
          ],
          collapse = "; "
        )
      )

      dummy_graph_summary <- data.frame(
        metric = "__validator_dummy_metric__",
        value = NA_real_,
        stringsAsFactors = FALSE
      )

      dummy_degree_distribution <- data.frame(
        degree = 0,
        n_nodes = 0,
        stringsAsFactors = FALSE
      )

      expected_nonmetric_overview <-
        phase4_build_network_overview(
          graph_summary = dummy_graph_summary,
          candidates = candidate_audit,
          degree_distribution =
            dummy_degree_distribution
        )

      expected_hub_rows <-
        expected_nonmetric_overview[
          expected_nonmetric_overview$section ==
            "topological_hub",
          ,
          drop = FALSE
        ]

      observed_hub_rows <- network_overview[
        network_overview$section ==
          "topological_hub",
        ,
        drop = FALSE
      ]

      hub_comparison <- compare_frames(
        observed_hub_rows,
        expected_hub_rows
      )

      add_check(
        sample_id,
        "topological_hubs_match_node_metrics",
        hub_comparison$pass,
        hub_comparison$details
      )

      observed_degree_rows <- network_overview[
        network_overview$section ==
          "degree_distribution",
        ,
        drop = FALSE
      ]

      observed_degree <- suppressWarnings(
        as.numeric(
          observed_degree_rows$item
        )
      )

      observed_degree_count <- suppressWarnings(
        as.numeric(
          observed_degree_rows$value
        )
      )

      candidate_degree <- suppressWarnings(
        as.numeric(
          candidate_audit$degree
        )
      )

      expected_degree_table <- table(
        candidate_degree[
          is.finite(candidate_degree) &
            candidate_degree > 0
        ]
      )

      expected_degree <- suppressWarnings(
        as.numeric(
          names(
            expected_degree_table
          )
        )
      )

      expected_degree_count <- as.numeric(
        expected_degree_table
      )

      degree_distribution_matches <- (
        identical(
          observed_degree,
          expected_degree
        ) &&
          identical(
            observed_degree_count,
            expected_degree_count
          )
      )

      add_check(
        sample_id,
        "degree_distribution_matches_node_metrics",
        degree_distribution_matches,
        paste0(
          "observed_bins=",
          length(observed_degree),
          "; expected_bins=",
          length(expected_degree)
        )
      )

      case_checks <- do.call(
        rbind,
        all_checks
      )

      case_checks <- case_checks[
        case_checks$sample_id ==
          sample_id,
        ,
        drop = FALSE
      ]

      case_pass <- !any(
        case_checks$status ==
          "FAIL"
      )

      case_summaries[[sample_id]] <- data.frame(
        sample_id = sample_id,
        analytical_sheet_count =
          length(
            analytical_sheet_names
          ),
        final_priority_rows =
          nrow(
            sheets[[
              "Final priorities"
            ]]
          ),
        module_priority_rows =
          nrow(
            sheets[[
              "Module priorities"
            ]]
          ),
        candidate_evidence_rows =
          nrow(
            sheets[[
              "Candidate evidence"
            ]]
          ),
        graph_nodes =
          graph_nodes,
        graph_edges =
          graph_edges,
        failed_checks =
          sum(
            case_checks$status ==
              "FAIL"
          ),
        case_pass =
          case_pass,
        stringsAsFactors = FALSE
      )
    },
    error = function(error) {
      case_error <<- conditionMessage(
        error
      )
    }
  )

  if (!is.null(case_error)) {
    add_check(
      sample_id,
      "unexpected_case_error",
      FALSE,
      case_error
    )

    case_summaries[[sample_id]] <- data.frame(
      sample_id = sample_id,
      analytical_sheet_count = NA_integer_,
      final_priority_rows = NA_integer_,
      module_priority_rows = NA_integer_,
      candidate_evidence_rows = NA_integer_,
      graph_nodes = NA_integer_,
      graph_edges = NA_integer_,
      failed_checks = NA_integer_,
      case_pass = FALSE,
      stringsAsFactors = FALSE
    )
  }

  message(
    "[Phase 4.5 multicase] ",
    sample_id,
    ": ",
    if (isTRUE(
      case_summaries[[sample_id]]$case_pass[[1L]]
    )) {
      "PASS"
    } else {
      "FAIL"
    },
    "."
  )
}

validation_table <- do.call(
  rbind,
  all_checks
)

case_summary <- do.call(
  rbind,
  case_summaries
)

rownames(validation_table) <- NULL
rownames(case_summary) <- NULL

case_failure_counts <- aggregate(
  x = list(
    failed_checks =
      validation_table$status ==
        "FAIL"
  ),
  by = list(
    sample_id =
      validation_table$sample_id
  ),
  FUN = sum
)

case_summary <- merge(
  case_summary[
    ,
    setdiff(
      names(case_summary),
      "failed_checks"
    ),
    drop = FALSE
  ],
  case_failure_counts,
  by = "sample_id",
  all.x = TRUE,
  sort = FALSE
)

case_summary <- case_summary[
  match(
    case_map$sample_id,
    case_summary$sample_id
  ),
  ,
  drop = FALSE
]

case_summary$case_pass <- (
  !is.na(
    case_summary$failed_checks
  ) &
    case_summary$failed_checks == 0L
)

summary_file <- file.path(
  output_root,
  "phase4_5_multicase_analytical_summary.csv"
)

validation_file <- file.path(
  output_root,
  "phase4_5_multicase_analytical_validation.csv"
)

utils::write.csv(
  case_summary,
  summary_file,
  row.names = FALSE,
  na = ""
)

utils::write.csv(
  validation_table,
  validation_file,
  row.names = FALSE,
  na = ""
)

cat(
  "\nPHASE 4.5 MULTICASE IMPLEMENTATION CHECKPOINT\n\n"
)

print(
  case_summary,
  row.names = FALSE
)

failed_validation <- validation_table[
  validation_table$status ==
    "FAIL",
  ,
  drop = FALSE
]

if (nrow(failed_validation) > 0L) {
  cat(
    "\nFailed analytical checks:\n"
  )

  print(
    failed_validation,
    row.names = FALSE
  )
}

cat(
  "\nOutput files:\n",
  "- ",
  summary_file,
  "\n- ",
  validation_file,
  "\n- ",
  file.path(
    output_root,
    "phase4_5_unit_tests.log"
  ),
  "\n- ",
  file.path(
    output_root,
    "phase4_5_technical_validator.log"
  ),
  "\n",
  sep = ""
)

overall_pass <- (
  nrow(case_summary) == 7L &&
    all(
      case_summary$case_pass
    ) &&
    !any(
      validation_table$status ==
        "FAIL"
    )
)

if (!overall_pass) {
  cat(
    "\nPHASE 4.5 MULTICASE IMPLEMENTATION CHECKPOINT: FAILED\n"
  )

  quit(
    save = "no",
    status = 1L
  )
}

cat(
  "\nPHASE 4.5 MULTICASE IMPLEMENTATION CHECKPOINT: PASSED\n"
)
