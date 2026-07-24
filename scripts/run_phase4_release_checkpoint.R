#!/usr/bin/env Rscript

# CancerPPIr Phase 4 final release checkpoint
#
# One final release gate:
#   1. runs the complete unit-test suite once in run-pipeline mode;
#   2. performs static release, documentation and CLI checks;
#   3. runs all seven clinical regression cases once through the existing
#      multicase technical and analytical validator;
#   4. validates canonical GraphML, manifests and SHA-256 checksums;
#   5. verifies exact network/module regression counts and source consistency.
#
# If the seven production outputs already exist, validate-existing mode reuses
# them and skips the unit suite by default.
#
# Positional arguments:
#   1. input directory
#   2. output directory
#   3. STRING cache directory
#   4. execution mode: run-pipeline or validate-existing
#   5. test mode: run-tests or skip-tests
#
# Defaults:
#   ../input
#   ../results/phase4_release_checkpoint_v1
#   ../string_cache
#   run-pipeline
#   run-tests for run-pipeline; skip-tests for validate-existing
#
# Examples:
#   Rscript scripts/run_phase4_release_checkpoint.R
#
#   Rscript scripts/run_phase4_release_checkpoint.R \
#     "..\input" \
#     "..\results\phase4_release_checkpoint_v1" \
#     "..\string_cache" \
#     validate-existing \
#     skip-tests

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
    "phase4_release_checkpoint_v1"
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

test_mode <- if (length(arguments) >= 5L) {
  tolower(
    trimws(
      as.character(
        arguments[[5L]]
      )
    )
  )
} else if (validate_existing) {
  "skip-tests"
} else {
  "run-tests"
}

valid_test_modes <- c(
  "run-tests",
  "skip-tests"
)

if (!(test_mode %in% valid_test_modes)) {
  stop(
    paste0(
      "Unsupported test mode: ",
      test_mode,
      ". Use run-tests or skip-tests."
    ),
    call. = FALSE
  )
}

run_tests <- identical(
  test_mode,
  "run-tests"
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

  existing_entries <- list.files(
    output_root,
    all.files = TRUE,
    no.. = TRUE
  )

  if (length(existing_entries) == 0L) {
    stop(
      paste0(
        "validate-existing mode requires a non-empty output directory: ",
        output_root
      ),
      call. = FALSE
    )
  }
} else if (dir.exists(output_root)) {
  existing_entries <- list.files(
    output_root,
    all.files = TRUE,
    no.. = TRUE
  )

  if (length(existing_entries) > 0L) {
    stop(
      paste0(
        "Output directory already exists and is not empty: ",
        output_root,
        "\nRemove it, pass a new directory, or use validate-existing."
      ),
      call. = FALSE
    )
  }
}

required_packages <- c(
  "testthat",
  "openxlsx",
  "igraph",
  "jsonlite",
  "digest"
)

missing_packages <- required_packages[
  !vapply(
    required_packages,
    requireNamespace,
    quietly = TRUE,
    FUN.VALUE = logical(1)
  )
]

if (length(missing_packages) > 0L) {
  stop(
    paste0(
      "Release-checkpoint dependencies are missing: ",
      paste(
        missing_packages,
        collapse = ", "
      ),
      "."
    ),
    call. = FALSE
  )
}

required_project_files <- file.path(
  project_root,
  c(
    "R/load_all.R",
    "scripts/run_unit_tests.R",
    "scripts/run_phase4_5_multicase_checkpoint.R",
    "scripts/validate_phase4_release_static.R",
    "scripts/validate_phase4_8_documentation.R",
    "cancerppir.R"
  )
)

missing_project_files <- required_project_files[
  !file.exists(required_project_files)
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
  expected_nodes = c(
    169L,
    248L,
    200L,
    338L,
    311L,
    285L,
    358L
  ),
  expected_edges = c(
    630L,
    397L,
    800L,
    1630L,
    1765L,
    1005L,
    4507L
  ),
  expected_modules = c(
    43L,
    100L,
    50L,
    82L,
    74L,
    76L,
    46L
  ),
  stringsAsFactors = FALSE
)

missing_inputs <- file.path(
  input_root,
  case_map$input_file
)

missing_inputs <- missing_inputs[
  !file.exists(missing_inputs)
]

if (length(missing_inputs) > 0L) {
  stop(
    paste0(
      "Required clinical regression input file(s) are missing:\n",
      paste0(
        "- ",
        missing_inputs,
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
  maximum_lines = 120L
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
  pattern = "phase4_release_unit_tests_",
  fileext = ".log"
)

multicase_log_temporary <- tempfile(
  pattern = "phase4_release_multicase_",
  fileext = ".log"
)

on.exit(
  unlink(
    c(
      unit_test_log_temporary,
      multicase_log_temporary
    )
  ),
  add = TRUE
)

if (run_tests) {
  message(
    "[Phase 4 release] Running the complete unit-test suite once."
  )

  unit_status <- system2(
    command = rscript_command,
    args = shQuote(
      file.path(
        project_root,
        "scripts",
        "run_unit_tests.R"
      )
    ),
    stdout = unit_test_log_temporary,
    stderr = unit_test_log_temporary,
    wait = TRUE
  )

  if (
    is.null(unit_status) ||
      is.na(unit_status) ||
      unit_status != 0L
  ) {
    stop(
      paste0(
        "Unit tests failed with exit status ",
        unit_status,
        ".\n\nLog tail:\n",
        tail_log(
          unit_test_log_temporary
        )
      ),
      call. = FALSE
    )
  }

  message(
    "[Phase 4 release] Unit tests: PASS."
  )
} else {
  writeLines(
    "Unit tests skipped in validate-existing mode.",
    unit_test_log_temporary,
    useBytes = TRUE
  )

  message(
    "[Phase 4 release] Unit tests: SKIPPED."
  )
}

source(
  file.path(
    project_root,
    "scripts",
    "validate_phase4_release_static.R"
  ),
  local = TRUE
)

static_validation <- phase4_9_validate_static_release(
  project_root
)

source(
  file.path(
    project_root,
    "scripts",
    "validate_phase4_8_documentation.R"
  ),
  local = TRUE
)

documentation_validation <-
  phase4_8_validate_documentation(
    project_root
  )

cli_output <- suppressWarnings(
  system2(
    command = rscript_command,
    args = c(
      shQuote(
        file.path(
          project_root,
          "cancerppir.R"
        )
      ),
      "--help"
    ),
    stdout = TRUE,
    stderr = TRUE
  )
)

cli_status <- attr(
  cli_output,
  "status"
)

if (is.null(cli_status)) {
  cli_status <- 0L
}

cli_validation <- data.frame(
  check_id = "cli_help_release_smoke_test",
  status = if (
    identical(
      as.integer(cli_status),
      0L
    ) &&
      any(
        grepl(
          "Usage:",
          cli_output,
          fixed = TRUE
        )
      ) &&
      any(
        grepl(
          "CancerPPIr_Output_Manifest.json",
          cli_output,
          fixed = TRUE
        )
      )
  ) {
    "PASS"
  } else {
    "FAIL"
  },
  details = paste(
    cli_output,
    collapse = " | "
  ),
  stringsAsFactors = FALSE
)

preflight_validation <- rbind(
  data.frame(
    section = "static_release",
    static_validation,
    stringsAsFactors = FALSE
  ),
  data.frame(
    section = "documentation",
    documentation_validation,
    stringsAsFactors = FALSE
  ),
  data.frame(
    section = "cli",
    cli_validation,
    stringsAsFactors = FALSE
  )
)

rownames(preflight_validation) <- NULL

preflight_failures <- preflight_validation[
  preflight_validation$status == "FAIL",
  ,
  drop = FALSE
]

if (nrow(preflight_failures) > 0L) {
  cat(
    "\nPHASE 4 RELEASE PREFLIGHT: FAILED\n\n"
  )

  print(
    preflight_failures,
    row.names = FALSE
  )

  quit(
    save = "no",
    status = 1L
  )
}

message(
  "[Phase 4 release] Static, documentation and CLI preflight: PASS."
)

multicase_arguments <- c(
  shQuote(
    file.path(
      project_root,
      "scripts",
      "run_phase4_5_multicase_checkpoint.R"
    )
  ),
  shQuote(
    input_root
  ),
  shQuote(
    output_root
  ),
  shQuote(
    cache_root
  ),
  execution_mode,
  "skip-unit-tests"
)

message(
  "[Phase 4 release] ",
  if (validate_existing) {
    "Revalidating existing seven-case outputs."
  } else {
    "Running the final seven-case production regression once."
  }
)

multicase_status <- system2(
  command = rscript_command,
  args = multicase_arguments,
  stdout = multicase_log_temporary,
  stderr = multicase_log_temporary,
  wait = TRUE
)

if (
  is.null(multicase_status) ||
    is.na(multicase_status) ||
    multicase_status != 0L
) {
  stop(
    paste0(
      "Seven-case multicase checkpoint failed with exit status ",
      multicase_status,
      ".\n\nLog tail:\n",
      tail_log(
        multicase_log_temporary,
        maximum_lines = 160L
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
      "phase4_release_unit_tests.log"
    ),
    overwrite = TRUE
  )
)

invisible(
  file.copy(
    multicase_log_temporary,
    file.path(
      output_root,
      "phase4_release_multicase.log"
    ),
    overwrite = TRUE
  )
)

source(
  file.path(
    project_root,
    "R",
    "load_all.R"
  ),
  local = .GlobalEnv
)

loaded_modules <- load_cancerppir_modules(
  project_root = project_root,
  envir = .GlobalEnv
)

if (length(loaded_modules) != 13L) {
  stop(
    paste0(
      "Expected 13 production modules, loaded ",
      length(loaded_modules),
      "."
    ),
    call. = FALSE
  )
}

checks <- list()

add_check <- function(
  sample_id,
  check_id,
  condition,
  details = ""
) {
  checks[[length(checks) + 1L]] <<- data.frame(
    sample_id = as.character(sample_id),
    check_id = as.character(check_id),
    status = if (isTRUE(condition)) {
      "PASS"
    } else {
      "FAIL"
    },
    details = paste(
      as.character(details),
      collapse = " | "
    ),
    stringsAsFactors = FALSE
  )

  invisible(NULL)
}

for (row_index in seq_len(
  nrow(preflight_validation)
)) {
  add_check(
    sample_id = "repository",
    check_id = paste0(
      preflight_validation$section[[row_index]],
      "::",
      preflight_validation$check_id[[row_index]]
    ),
    condition = identical(
      preflight_validation$status[[row_index]],
      "PASS"
    ),
    details =
      preflight_validation$details[[row_index]]
  )
}

multicase_summary_file <- file.path(
  output_root,
  "phase4_5_multicase_analytical_summary.csv"
)

multicase_summary <- if (
  file.exists(multicase_summary_file)
) {
  utils::read.csv(
    multicase_summary_file,
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
} else {
  data.frame()
}

multicase_summary_valid <- (
  nrow(multicase_summary) == 7L &&
    all(
      as.logical(
        multicase_summary$case_pass
      )
    ) &&
    all(
      as.integer(
        multicase_summary$failed_checks
      ) == 0L
    )
)

add_check(
  "repository",
  "multicase_analytical_checkpoint_passes",
  multicase_summary_valid,
  if (nrow(multicase_summary) > 0L) {
    paste0(
      multicase_summary$sample_id,
      "=",
      multicase_summary$case_pass,
      collapse = "; "
    )
  } else {
    "summary unavailable"
  }
)

expected_output_names <- c(
  "CancerPPIr_Analytical_Report.xlsx",
  "CancerPPIr_Technical_Report.xlsx",
  "STRING_links.txt",
  "Network_for_Cytoscape.graphml",
  "CancerPPIr_Output_Manifest.json",
  "CancerPPIr_Output_Checksums.sha256"
)

case_summary_rows <- list()

for (case_index in seq_len(
  nrow(case_map)
)) {
  sample_id <- case_map$sample_id[[case_index]]

  message(
    "[Phase 4 release] Validating canonical release outputs for ",
    sample_id,
    "."
  )

  case_directory <- file.path(
    output_root,
    case_map$output_folder[[case_index]]
  )

  output_paths <- file.path(
    case_directory,
    expected_output_names
  )

  outputs_exist <- all(
    file.exists(
      output_paths
    )
  )

  add_check(
    sample_id,
    "all_six_public_outputs_exist",
    outputs_exist,
    basename(
      output_paths[
        !file.exists(
          output_paths
        )
      ]
    )
  )

  case_error <- NULL
  graph_nodes <- NA_integer_
  graph_edges <- NA_integer_
  graph_modules <- NA_integer_

  if (outputs_exist) {
    tryCatch(
      {
        analytical_file <- file.path(
          case_directory,
          "CancerPPIr_Analytical_Report.xlsx"
        )

        technical_file <- file.path(
          case_directory,
          "CancerPPIr_Technical_Report.xlsx"
        )

        graphml_file <- file.path(
          case_directory,
          "Network_for_Cytoscape.graphml"
        )

        manifest_file <- file.path(
          case_directory,
          "CancerPPIr_Output_Manifest.json"
        )

        checksums_file <- file.path(
          case_directory,
          "CancerPPIr_Output_Checksums.sha256"
        )

        provenance_validation <-
          cancerppir_validate_output_provenance(
            manifest_file = manifest_file,
            checksums_file = checksums_file,
            output_dir = case_directory,
            forbidden_paths = c(
              project_root,
              input_root,
              cache_root,
              output_root
            )
          )

        for (validation_index in seq_len(
          nrow(provenance_validation)
        )) {
          add_check(
            sample_id,
            paste0(
              "provenance::",
              provenance_validation$check_id[[
                validation_index
              ]]
            ),
            identical(
              provenance_validation$status[[
                validation_index
              ]],
              "PASS"
            ),
            provenance_validation$details[[
              validation_index
            ]]
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

        observed_vertex_attributes <-
          igraph::vertex_attr_names(
            graph
          )

        expected_vertex_attributes <-
          phase4_canonical_graphml_attribute_names()

        add_check(
          sample_id,
          "canonical_graphml_fields_present",
          all(
            expected_vertex_attributes %in%
              observed_vertex_attributes
          ),
          setdiff(
            expected_vertex_attributes,
            observed_vertex_attributes
          )
        )

        add_check(
          sample_id,
          "legacy_graphml_fields_absent",
          !any(
            CANCERPPIR_LEGACY_ANNOTATION_FIELDS %in%
              observed_vertex_attributes
          ),
          intersect(
            CANCERPPIR_LEGACY_ANNOTATION_FIELDS,
            observed_vertex_attributes
          )
        )

        graphml_schema_values <- unique(
          as.character(
            igraph::vertex_attr(
              graph,
              "graphml_schema_version"
            )
          )
        )

        annotation_schema_values <- unique(
          as.character(
            igraph::vertex_attr(
              graph,
              "annotation_schema_version"
            )
          )
        )

        add_check(
          sample_id,
          "graphml_schema_versions_are_pinned",
          identical(
            graphml_schema_values,
            CANCERPPIR_GRAPHML_SCHEMA_VERSION
          ) &&
            identical(
              annotation_schema_values,
              CANCERPPIR_BIOLOGICAL_EVIDENCE_SCHEMA_VERSION
            ),
          paste(
            graphml_schema_values,
            annotation_schema_values,
            sep = " | ",
            collapse = "; "
          )
        )

        technical_nodes <- as.data.frame(
          openxlsx::read.xlsx(
            technical_file,
            sheet = "Phase4 node annotations",
            colNames = TRUE,
            check.names = FALSE
          ),
          stringsAsFactors = FALSE,
          check.names = FALSE
        )

        technical_modules <- as.data.frame(
          openxlsx::read.xlsx(
            technical_file,
            sheet = "Phase4 module annotations",
            colNames = TRUE,
            check.names = FALSE
          ),
          stringsAsFactors = FALSE,
          check.names = FALSE
        )

        graph_ids <- as.character(
          igraph::vertex_attr(
            graph,
            "STRING_id"
          )
        )

        graph_candidate_score <- suppressWarnings(
          as.numeric(
            igraph::vertex_attr(
              graph,
              "candidate_score"
            )
          )
        )

        graph_community <- suppressWarnings(
          as.integer(
            igraph::vertex_attr(
              graph,
              "community_louvain"
            )
          )
        )

        technical_match <- match(
          graph_ids,
          as.character(
            technical_nodes$STRING_id
          )
        )

        node_source_complete <- (
          length(graph_ids) ==
            nrow(technical_nodes) &&
            !anyNA(technical_match) &&
            !any(
              duplicated(
                graph_ids
              )
            )
        )

        add_check(
          sample_id,
          "graphml_nodes_match_technical_source",
          node_source_complete,
          paste0(
            "graph=",
            length(graph_ids),
            "; technical=",
            nrow(technical_nodes)
          )
        )

        score_consistent <- FALSE
        community_consistent <- FALSE

        if (node_source_complete) {
          technical_score <- suppressWarnings(
            as.numeric(
              technical_nodes$candidate_score[
                technical_match
              ]
            )
          )

          technical_community <- suppressWarnings(
            as.integer(
              technical_nodes$community_louvain[
                technical_match
              ]
            )
          )

          score_consistent <- identical(
            is.na(graph_candidate_score),
            is.na(technical_score)
          ) &&
            all(
              abs(
                graph_candidate_score[
                  !is.na(graph_candidate_score)
                ] -
                  technical_score[
                    !is.na(technical_score)
                  ]
              ) <=
                1e-10 *
                  pmax(
                    1,
                    abs(
                      technical_score[
                        !is.na(technical_score)
                      ]
                    )
                  )
            )

          community_consistent <- identical(
            graph_community,
            technical_community
          )
        }

        add_check(
          sample_id,
          "candidate_scores_match_technical_source",
          score_consistent,
          "GraphML versus Phase4 node annotations."
        )

        add_check(
          sample_id,
          "louvain_membership_matches_technical_source",
          community_consistent,
          "GraphML versus Phase4 node annotations."
        )

        final_priorities <- as.data.frame(
          openxlsx::read.xlsx(
            analytical_file,
            sheet = "Final priorities",
            colNames = TRUE,
            check.names = FALSE
          ),
          stringsAsFactors = FALSE,
          check.names = FALSE
        )

        graph_priority_status <- as.character(
          igraph::vertex_attr(
            graph,
            "candidate_priority_status"
          )
        )

        graph_final_ids <- sort(
          graph_ids[
            graph_priority_status ==
              "final_priority"
          ]
        )

        workbook_final_ids <- sort(
          as.character(
            final_priorities$STRING_id
          )
        )

        add_check(
          sample_id,
          "final_priority_membership_matches_graphml",
          identical(
            graph_final_ids,
            workbook_final_ids
          ),
          paste0(
            "graph=",
            length(graph_final_ids),
            "; workbook=",
            length(workbook_final_ids)
          )
        )

        graph_modules <- nrow(
          technical_modules
        )

        add_check(
          sample_id,
          "network_node_regression_count",
          identical(
            as.integer(graph_nodes),
            as.integer(
              case_map$expected_nodes[[
                case_index
              ]]
            )
          ),
          paste0(
            "observed=",
            graph_nodes,
            "; expected=",
            case_map$expected_nodes[[case_index]]
          )
        )

        add_check(
          sample_id,
          "network_edge_regression_count",
          identical(
            as.integer(graph_edges),
            as.integer(
              case_map$expected_edges[[
                case_index
              ]]
            )
          ),
          paste0(
            "observed=",
            graph_edges,
            "; expected=",
            case_map$expected_edges[[case_index]]
          )
        )

        add_check(
          sample_id,
          "louvain_module_regression_count",
          identical(
            as.integer(graph_modules),
            as.integer(
              case_map$expected_modules[[
                case_index
              ]]
            )
          ),
          paste0(
            "observed=",
            graph_modules,
            "; expected=",
            case_map$expected_modules[[case_index]]
          )
        )

        manifest <- jsonlite::read_json(
          manifest_file,
          simplifyVector = TRUE
        )

        manifest_summary_valid <- (
          identical(
            as.integer(
              manifest$summary$network_nodes
            ),
            as.integer(graph_nodes)
          ) &&
            identical(
              as.integer(
                manifest$summary$network_edges
              ),
              as.integer(graph_edges)
            ) &&
            identical(
              as.integer(
                manifest$summary$Louvain_modules
              ),
              as.integer(graph_modules)
            )
        )

        add_check(
          sample_id,
          "manifest_summary_matches_outputs",
          manifest_summary_valid,
          paste0(
            "nodes=",
            manifest$summary$network_nodes,
            "; edges=",
            manifest$summary$network_edges,
            "; modules=",
            manifest$summary$Louvain_modules
          )
        )
      },
      error = function(error) {
        case_error <<- conditionMessage(
          error
        )
      }
    )
  }

  if (!is.null(case_error)) {
    add_check(
      sample_id,
      "unexpected_release_validation_error",
      FALSE,
      case_error
    )
  }

  current_checks <- if (length(checks) > 0L) {
    do.call(
      rbind,
      checks
    )
  } else {
    data.frame()
  }

  sample_checks <- current_checks[
    current_checks$sample_id ==
      sample_id,
    ,
    drop = FALSE
  ]

  case_summary_rows[[sample_id]] <- data.frame(
    sample_id = sample_id,
    graph_nodes = graph_nodes,
    graph_edges = graph_edges,
    louvain_modules = graph_modules,
    failed_checks = sum(
      sample_checks$status ==
        "FAIL"
    ),
    case_pass = !any(
      sample_checks$status ==
        "FAIL"
    ),
    stringsAsFactors = FALSE
  )
}

validation <- do.call(
  rbind,
  checks
)

rownames(validation) <- NULL

case_summary <- do.call(
  rbind,
  case_summary_rows
)

rownames(case_summary) <- NULL

summary_table <- data.frame(
  metric = c(
    "unit_tests",
    "static_release_checks",
    "documentation_checks",
    "clinical_cases",
    "clinical_cases_passed",
    "failed_checks",
    "execution_mode"
  ),
  value = c(
    if (run_tests) "PASS" else "SKIPPED",
    as.character(
      nrow(static_validation)
    ),
    as.character(
      nrow(documentation_validation)
    ),
    as.character(
      nrow(case_summary)
    ),
    as.character(
      sum(
        case_summary$case_pass
      )
    ),
    as.character(
      sum(
        validation$status ==
          "FAIL"
      )
    ),
    execution_mode
  ),
  stringsAsFactors = FALSE
)

summary_file <- file.path(
  output_root,
  "phase4_release_summary.csv"
)

case_summary_file <- file.path(
  output_root,
  "phase4_release_case_summary.csv"
)

validation_file <- file.path(
  output_root,
  "phase4_release_validation.csv"
)

preflight_file <- file.path(
  output_root,
  "phase4_release_preflight_validation.csv"
)

utils::write.csv(
  summary_table,
  summary_file,
  row.names = FALSE,
  na = ""
)

utils::write.csv(
  case_summary,
  case_summary_file,
  row.names = FALSE,
  na = ""
)

utils::write.csv(
  validation,
  validation_file,
  row.names = FALSE,
  na = ""
)

utils::write.csv(
  preflight_validation,
  preflight_file,
  row.names = FALSE,
  na = ""
)

cat(
  "\nPHASE 4 RELEASE CHECKPOINT\n\n"
)

print(
  summary_table,
  row.names = FALSE
)

cat(
  "\nClinical-case summary:\n"
)

print(
  case_summary,
  row.names = FALSE
)

failures <- validation[
  validation$status ==
    "FAIL",
  ,
  drop = FALSE
]

if (nrow(failures) > 0L) {
  cat(
    "\nFailed release checks:\n"
  )

  print(
    failures,
    row.names = FALSE
  )
}

cat(
  "\nOutput files:\n",
  "- ",
  summary_file,
  "\n- ",
  case_summary_file,
  "\n- ",
  validation_file,
  "\n- ",
  preflight_file,
  "\n- ",
  file.path(
    output_root,
    "phase4_release_unit_tests.log"
  ),
  "\n- ",
  file.path(
    output_root,
    "phase4_release_multicase.log"
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
      validation$status ==
        "FAIL"
    )
)

if (!overall_pass) {
  cat(
    "\nPHASE 4 RELEASE CHECKPOINT: FAILED\n"
  )

  quit(
    save = "no",
    status = 1L
  )
}

cat(
  "\nPHASE 4 RELEASE CHECKPOINT: PASSED\n"
)
