#!/usr/bin/env Rscript

# CancerPPIr Phase 4.6 canonical annotation checkpoint
#
# Efficient release gate for the canonicalization package:
#   1. runs the complete unit-test suite once;
#   2. runs one real production case once (A01 by default);
#   3. validates the canonical pipeline result object;
#   4. validates canonical technical evidence tables;
#   5. validates canonical GraphML attributes and legacy-field removal;
#   6. optionally compares topology, Louvain membership, candidate scores and
#      analytical workbook tables with the completed Phase 4.5 A01 baseline.
#
# It deliberately does not rerun all seven clinical cases. The full seven-case
# release regression is deferred to the final Phase 4 release checkpoint.
#
# Optional positional arguments:
#   1. input CSV
#   2. results root
#   3. STRING cache directory
#   4. Phase 4.5 baseline case directory, or "none"
#
# Defaults:
#   ../input/Genes_A.csv
#   ../results/phase4_6_a01_checkpoint_v1
#   ../string_cache
#   ../results/phase4_5_a01_checkpoint_v2/Genes_A
#
# Run from repository root:
#   Rscript scripts/run_phase4_6_checkpoint.R

arguments <- commandArgs(
  trailingOnly = TRUE
)

input_file <- if (length(arguments) >= 1L) {
  arguments[[1L]]
} else {
  file.path("..", "input", "Genes_A.csv")
}

results_root <- if (length(arguments) >= 2L) {
  arguments[[2L]]
} else {
  file.path("..", "results", "phase4_6_a01_checkpoint_v1")
}

cache_dir <- if (length(arguments) >= 3L) {
  arguments[[3L]]
} else {
  file.path("..", "string_cache")
}

baseline_case_dir <- if (length(arguments) >= 4L) {
  arguments[[4L]]
} else {
  file.path(
    "..",
    "results",
    "phase4_5_a01_checkpoint_v2",
    "Genes_A"
  )
}

baseline_enabled <- !tolower(
  trimws(
    as.character(baseline_case_dir)
  )
) %in% c("", "none", "false", "skip")

project_root <- normalizePath(
  ".",
  winslash = "/",
  mustWork = TRUE
)

input_file <- normalizePath(
  input_file,
  winslash = "/",
  mustWork = TRUE
)

cache_dir <- normalizePath(
  cache_dir,
  winslash = "/",
  mustWork = TRUE
)

if (dir.exists(results_root)) {
  existing_entries <- list.files(
    results_root,
    all.files = TRUE,
    no.. = TRUE
  )

  if (length(existing_entries) > 0L) {
    stop(
      paste0(
        "Checkpoint results directory already exists and is not empty: ",
        results_root,
        "\nRemove it or pass a different second argument."
      ),
      call. = FALSE
    )
  }
} else {
  dir.create(
    results_root,
    recursive = TRUE,
    showWarnings = FALSE
  )
}

results_root <- normalizePath(
  results_root,
  winslash = "/",
  mustWork = TRUE
)

if (baseline_enabled) {
  if (dir.exists(baseline_case_dir)) {
    baseline_case_dir <- normalizePath(
      baseline_case_dir,
      winslash = "/",
      mustWork = TRUE
    )
  } else {
    message(
      "[Phase 4.6 checkpoint] Baseline directory not found; ",
      "baseline comparison will be skipped: ",
      baseline_case_dir
    )

    baseline_enabled <- FALSE
  }
}

required_packages <- c(
  "openxlsx",
  "igraph"
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
      "Checkpoint dependency or dependencies are missing: ",
      paste(missing_packages, collapse = ", "),
      "."
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

unit_test_log <- file.path(
  results_root,
  "phase4_6_unit_tests.log"
)

unit_test_status <- system2(
  command = rscript_command,
  args = shQuote(
    file.path(
      project_root,
      "scripts",
      "run_unit_tests.R"
    )
  ),
  stdout = unit_test_log,
  stderr = unit_test_log,
  wait = TRUE
)

if (
  is.null(unit_test_status) ||
    is.na(unit_test_status) ||
    unit_test_status != 0L
) {
  log_tail <- if (file.exists(unit_test_log)) {
    tail(
      readLines(
        unit_test_log,
        warn = FALSE,
        encoding = "UTF-8"
      ),
      100L
    )
  } else {
    "Unit-test log was not created."
  }

  stop(
    paste0(
      "Unit tests failed with exit status ",
      unit_test_status,
      ".\n\nLog tail:\n",
      paste(log_tail, collapse = "\n")
    ),
    call. = FALSE
  )
}

message(
  "[Phase 4.6 checkpoint] Unit tests: PASS."
)

source(
  file.path(project_root, "R", "load_all.R"),
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

message(
  "[Phase 4.6 checkpoint] Running one production case."
)

result <- run_cancerppir(
  input_file = input_file,
  results_root = results_root,
  cache_dir = cache_dir,
  score_threshold = 400L,
  top_n = 30L,
  run_enrichment = TRUE
)

checks <- list()

add_check <- function(
  check_id,
  condition,
  details = ""
) {
  checks[[
    paste0(check_id, "::", length(checks) + 1L)
  ]] <<- data.frame(
    check_id = check_id,
    status = if (isTRUE(condition)) "PASS" else "FAIL",
    details = as.character(details),
    stringsAsFactors = FALSE
  )
}

frames_equal <- function(observed, expected) {
  observed <- as.data.frame(
    observed,
    stringsAsFactors = FALSE,
    check.names = FALSE
  )

  expected <- as.data.frame(
    expected,
    stringsAsFactors = FALSE,
    check.names = FALSE
  )

  if (!identical(names(observed), names(expected))) {
    return(FALSE)
  }

  if (nrow(observed) != nrow(expected)) {
    return(FALSE)
  }

  column_matches <- vapply(
    names(expected),
    function(column_name) {
      observed_column <- observed[[column_name]]
      expected_column <- expected[[column_name]]

      if (is.logical(expected_column)) {
        normalize_logical <- function(x) {
          if (is.logical(x)) {
            return(x)
          }

          text <- tolower(
            trimws(
              as.character(x)
            )
          )

          output <- rep(
            NA,
            length(text)
          )

          output[text %in% c("true", "t", "1")] <- TRUE
          output[text %in% c("false", "f", "0")] <- FALSE
          output
        }

        return(
          identical(
            normalize_logical(observed_column),
            normalize_logical(expected_column)
          )
        )
      }

      if (
        is.numeric(expected_column) ||
          is.integer(expected_column)
      ) {
        observed_numeric <- suppressWarnings(
          as.numeric(observed_column)
        )

        expected_numeric <- suppressWarnings(
          as.numeric(expected_column)
        )

        if (!identical(
          is.na(observed_numeric),
          is.na(expected_numeric)
        )) {
          return(FALSE)
        }

        finite_index <- is.finite(expected_numeric) &
          is.finite(observed_numeric)

        finite_match <- all(
          abs(
            observed_numeric[finite_index] -
              expected_numeric[finite_index]
          ) <=
            1e-10 *
              pmax(
                1,
                abs(expected_numeric[finite_index])
              )
        )

        nonfinite_index <- !is.na(expected_numeric) &
          !is.na(observed_numeric) &
          (!finite_index)

        nonfinite_match <- all(
          observed_numeric[nonfinite_index] ==
            expected_numeric[nonfinite_index]
        )

        return(finite_match && nonfinite_match)
      }

      observed_text <- as.character(observed_column)
      expected_text <- as.character(expected_column)

      observed_text[is.na(observed_text)] <- ""
      expected_text[is.na(expected_text)] <- ""

      identical(observed_text, expected_text)
    },
    FUN.VALUE = logical(1)
  )

  all(column_matches)
}

canonical_result_validation <-
  phase4_validate_canonical_pipeline_result(
    result
  )

add_check(
  "canonical_pipeline_result_validation",
  all(
    canonical_result_validation$status == "PASS"
  ),
  paste(
    canonical_result_validation$check_id[
      canonical_result_validation$status == "FAIL"
    ],
    collapse = "; "
  )
)

canonical_evidence_validation <-
  phase4_validate_canonical_biological_evidence(
    result$biological_evidence
  )

add_check(
  "canonical_biological_evidence_validation",
  all(
    canonical_evidence_validation$status == "PASS"
  ),
  paste(
    canonical_evidence_validation$check_id[
      canonical_evidence_validation$status == "FAIL"
    ],
    collapse = "; "
  )
)

add_check(
  "shadow_public_field_absent",
  !"biological_evidence_shadow" %in% names(result),
  paste(names(result), collapse = " | ")
)

add_check(
  "canonical_result_class",
  inherits(result, "cancerppir_result"),
  paste(class(result), collapse = " | ")
)

add_check(
  "canonical_schema_versions",
  identical(
    result$schema_versions$pipeline_result,
    CANCERPPIR_PIPELINE_RESULT_SCHEMA_VERSION
  ) &&
    identical(
      result$schema_versions$biological_evidence,
      CANCERPPIR_BIOLOGICAL_EVIDENCE_SCHEMA_VERSION
    ) &&
    identical(
      result$schema_versions$graphml,
      CANCERPPIR_GRAPHML_SCHEMA_VERSION
    ),
  paste(
    unlist(result$schema_versions),
    collapse = " | "
  )
)

required_file_keys <- c(
  "analytical_report",
  "technical_report",
  "string_links",
  "graphml",
  "output_manifest",
  "output_checksums"
)

add_check(
  "canonical_output_file_keys",
  identical(
    names(result$files),
    required_file_keys
  ),
  paste(names(result$files), collapse = " | ")
)

required_files <- unname(
  result$files[required_file_keys]
)

add_check(
  "required_output_files_exist",
  all(file.exists(required_files)),
  paste(
    basename(
      required_files[!file.exists(required_files)]
    ),
    collapse = " | "
  )
)

analytical_workbook <- unname(
  result$files[["analytical_report"]]
)

technical_workbook <- unname(
  result$files[["technical_report"]]
)

graphml_file <- unname(
  result$files[["graphml"]]
)

analytical_sheet_names <- openxlsx::getSheetNames(
  analytical_workbook
)

add_check(
  "analytical_workbook_contract_unchanged",
  identical(
    analytical_sheet_names,
    CANCERPPIR_ANALYTICAL_SHEET_NAMES
  ),
  paste(analytical_sheet_names, collapse = " | ")
)

add_check(
  "analytical_validation_passes",
  !any(
    result$reports$analytical_validation$status == "FAIL"
  ),
  paste(
    result$reports$analytical_validation$check_id[
      result$reports$analytical_validation$status == "FAIL"
    ],
    collapse = "; "
  )
)

technical_sheet_names <- openxlsx::getSheetNames(
  technical_workbook
)

required_technical_sheets <- c(
  "Phase4 module annotations",
  "Phase4 rule evidence",
  "Phase4 significant terms",
  "Phase4 node annotations",
  "Phase4 validation"
)

add_check(
  "canonical_technical_sheets_present",
  all(
    required_technical_sheets %in%
      technical_sheet_names
  ),
  paste(
    setdiff(
      required_technical_sheets,
      technical_sheet_names
    ),
    collapse = " | "
  )
)

technical_validation <- openxlsx::read.xlsx(
  technical_workbook,
  sheet = "Phase4 validation",
  colNames = TRUE,
  check.names = FALSE
)

add_check(
  "technical_evidence_validation_passes",
  !any(
    as.character(technical_validation$status) == "FAIL"
  ),
  paste(
    technical_validation$check_id[
      as.character(technical_validation$status) == "FAIL"
    ],
    collapse = " | "
  )
)

technical_nodes <- openxlsx::read.xlsx(
  technical_workbook,
  sheet = "Phase4 node annotations",
  colNames = TRUE,
  check.names = FALSE
)

technical_modules <- openxlsx::read.xlsx(
  technical_workbook,
  sheet = "Phase4 module annotations",
  colNames = TRUE,
  check.names = FALSE
)

add_check(
  "technical_node_schema_is_canonical",
  all(
    phase4_required_canonical_node_fields() %in%
      names(technical_nodes)
  ),
  paste(
    setdiff(
      phase4_required_canonical_node_fields(),
      names(technical_nodes)
    ),
    collapse = " | "
  )
)

add_check(
  "technical_module_schema_is_canonical",
  all(
    phase4_required_canonical_module_fields() %in%
      names(technical_modules)
  ),
  paste(
    setdiff(
      phase4_required_canonical_module_fields(),
      names(technical_modules)
    ),
    collapse = " | "
  )
)

technical_rule_evidence <- openxlsx::read.xlsx(
  technical_workbook,
  sheet = "Phase4 rule evidence",
  colNames = TRUE,
  check.names = FALSE
)

technical_significant_terms <- openxlsx::read.xlsx(
  technical_workbook,
  sheet = "Phase4 significant terms",
  colNames = TRUE,
  check.names = FALSE
)

add_check(
  "technical_module_annotations_match_result",
  frames_equal(
    technical_modules,
    result$biological_evidence$module_annotations
  ),
  "Phase4 module annotations"
)

add_check(
  "technical_node_annotations_match_result",
  frames_equal(
    technical_nodes,
    result$biological_evidence$node_annotations
  ),
  "Phase4 node annotations"
)

add_check(
  "technical_rule_evidence_matches_result",
  frames_equal(
    technical_rule_evidence,
    result$biological_evidence$module_rule_evidence
  ),
  "Phase4 rule evidence"
)

add_check(
  "technical_significant_terms_match_result",
  frames_equal(
    technical_significant_terms,
    result$biological_evidence$significant_module_terms
  ),
  "Phase4 significant terms"
)

add_check(
  "technical_validation_matches_result",
  frames_equal(
    technical_validation,
    result$biological_evidence$validation
  ),
  "Phase4 validation"
)

graph <- igraph::read_graph(
  graphml_file,
  format = "graphml"
)

graphml_fields <- igraph::vertex_attr_names(
  graph
)

required_graphml_fields <- c(
  "STRING_id",
  "annotation_schema_version",
  "graphml_schema_version",
  "entity_class",
  "candidate_eligibility",
  "candidate_priority_status",
  "module_interpretation_class",
  "module_interpretation_scope",
  "module_compartment",
  "module_lineage",
  "module_state",
  "module_process",
  "module_primary_interpretation",
  "module_confidence",
  "module_priority_eligible",
  "module_conflict_detected",
  "module_warning",
  "module_evidence_rationale",
  "cytoscape_module_label"
)

add_check(
  "canonical_graphml_fields_present",
  all(required_graphml_fields %in% graphml_fields),
  paste(
    setdiff(required_graphml_fields, graphml_fields),
    collapse = " | "
  )
)

legacy_graphml_fields <- intersect(
  CANCERPPIR_LEGACY_ANNOTATION_FIELDS,
  graphml_fields
)

add_check(
  "legacy_graphml_fields_absent",
  length(legacy_graphml_fields) == 0L,
  paste(legacy_graphml_fields, collapse = " | ")
)

add_check(
  "graphml_node_count_matches_canonical_nodes",
  igraph::gorder(graph) ==
    nrow(result$biological_evidence$node_annotations),
  paste0(
    "graph=",
    igraph::gorder(graph),
    "; canonical_nodes=",
    nrow(result$biological_evidence$node_annotations)
  )
)

vertex_ids <- as.character(
  igraph::V(graph)$name
)

canonical_nodes <- result$biological_evidence$node_annotations
canonical_index <- match(
  vertex_ids,
  as.character(canonical_nodes$STRING_id)
)

add_check(
  "graphml_vertex_ids_match_canonical_nodes",
  !any(is.na(canonical_index)) &&
    setequal(
      vertex_ids,
      as.character(canonical_nodes$STRING_id)
    ),
  paste(
    setdiff(
      vertex_ids,
      as.character(canonical_nodes$STRING_id)
    ),
    collapse = " | "
  )
)

imported_STRING_ids <- as.character(
  igraph::vertex_attr(
    graph,
    "STRING_id"
  )
)

add_check(
  "graphml_STRING_id_attribute_matches_vertex_name",
  identical(imported_STRING_ids, vertex_ids),
  "STRING_id"
)

imported_primary_interpretation <- as.character(
  igraph::vertex_attr(
    graph,
    "module_primary_interpretation"
  )
)

add_check(
  "graphml_interpretation_matches_evidence",
  identical(
    imported_primary_interpretation,
    as.character(
      canonical_nodes$module_primary_interpretation[
        canonical_index
      ]
    )
  ),
  "module_primary_interpretation"
)

imported_eligibility <- as.character(
  igraph::vertex_attr(
    graph,
    "candidate_eligibility"
  )
)

add_check(
  "graphml_eligibility_matches_evidence",
  identical(
    imported_eligibility,
    as.character(
      canonical_nodes$candidate_eligibility[
        canonical_index
      ]
    )
  ),
  "candidate_eligibility"
)

imported_annotation_schema <- as.character(
  igraph::vertex_attr(
    graph,
    "annotation_schema_version"
  )
)

imported_graphml_schema <- as.character(
  igraph::vertex_attr(
    graph,
    "graphml_schema_version"
  )
)

add_check(
  "graphml_schema_versions_are_pinned",
  all(
    imported_annotation_schema ==
      CANCERPPIR_BIOLOGICAL_EVIDENCE_SCHEMA_VERSION
  ) &&
    all(
      imported_graphml_schema ==
        CANCERPPIR_GRAPHML_SCHEMA_VERSION
    ),
  paste0(
    "annotation=",
    paste(unique(imported_annotation_schema), collapse = ";"),
    "; graphml=",
    paste(unique(imported_graphml_schema), collapse = ";")
  )
)

canonical_graphml_validation <-
  result$reports$graphml_validation

add_check(
  "in_memory_graphml_validation_passes",
  !any(
    canonical_graphml_validation$status == "FAIL"
  ),
  paste(
    canonical_graphml_validation$check_id[
      canonical_graphml_validation$status == "FAIL"
    ],
    collapse = " | "
  )
)

canonical_compatibility_names <- c(
  "status",
  "migration",
  "legacy_module_summary",
  "legacy_candidate_evidence_matrix",
  "legacy_priority_directions",
  "legacy_final_priorities"
)

add_check(
  "legacy_outputs_are_isolated_in_compatibility",
  is.list(result$compatibility) &&
    all(
      canonical_compatibility_names %in%
        names(result$compatibility)
    ) &&
    identical(
      result$compatibility$status,
      "deprecated_compatibility_only"
    ),
  paste(names(result$compatibility), collapse = " | ")
)

edge_keys <- function(graph_object) {
  edge_matrix <- igraph::as_edgelist(
    graph_object,
    names = TRUE
  )

  if (nrow(edge_matrix) == 0L) {
    return(character())
  }

  sort(
    apply(
      edge_matrix,
      1L,
      function(edge) {
        paste(sort(as.character(edge)), collapse = "::")
      }
    )
  )
}

read_sheet <- function(workbook, sheet) {
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

if (baseline_enabled) {
  baseline_graphml <- file.path(
    baseline_case_dir,
    "Network_for_Cytoscape.graphml"
  )

  baseline_analytical <- file.path(
    baseline_case_dir,
    "CancerPPIr_Analytical_Report.xlsx"
  )

  baseline_files_exist <- all(
    file.exists(
      c(baseline_graphml, baseline_analytical)
    )
  )

  add_check(
    "phase4_5_baseline_files_exist",
    baseline_files_exist,
    paste(
      basename(
        c(baseline_graphml, baseline_analytical)[
          !file.exists(
            c(baseline_graphml, baseline_analytical)
          )
        ]
      ),
      collapse = " | "
    )
  )

  if (baseline_files_exist) {
    baseline_graph <- igraph::read_graph(
      baseline_graphml,
      format = "graphml"
    )

    add_check(
      "topology_vertex_set_unchanged",
      setequal(
        as.character(igraph::V(graph)$name),
        as.character(igraph::V(baseline_graph)$name)
      ),
      paste0(
        "current=",
        igraph::gorder(graph),
        "; baseline=",
        igraph::gorder(baseline_graph)
      )
    )

    add_check(
      "topology_edge_set_unchanged",
      identical(
        edge_keys(graph),
        edge_keys(baseline_graph)
      ),
      paste0(
        "current=",
        igraph::gsize(graph),
        "; baseline=",
        igraph::gsize(baseline_graph)
      )
    )

    baseline_vertex_ids <- as.character(
      igraph::V(baseline_graph)$name
    )

    current_to_baseline <- match(
      vertex_ids,
      baseline_vertex_ids
    )

    current_community <- as.character(
      igraph::vertex_attr(
        graph,
        "community_louvain"
      )
    )

    baseline_community <- as.character(
      igraph::vertex_attr(
        baseline_graph,
        "community_louvain"
      )
    )[
      current_to_baseline
    ]

    add_check(
      "louvain_partition_unchanged",
      !any(is.na(current_to_baseline)) &&
        identical(
          current_community,
          baseline_community
        ),
      "community_louvain"
    )

    current_score <- suppressWarnings(
      as.numeric(
        igraph::vertex_attr(
          graph,
          "candidate_score"
        )
      )
    )

    baseline_score <- suppressWarnings(
      as.numeric(
        igraph::vertex_attr(
          baseline_graph,
          "candidate_score"
        )
      )
    )[
      current_to_baseline
    ]

    score_difference <- max(
      abs(current_score - baseline_score),
      na.rm = TRUE
    )

    if (!is.finite(score_difference)) {
      score_difference <- 0
    }

    add_check(
      "candidate_scores_unchanged",
      !any(is.na(current_to_baseline)) &&
        score_difference <= 1e-12,
      paste0("maximum_difference=", score_difference)
    )

    baseline_sheet_names <- openxlsx::getSheetNames(
      baseline_analytical
    )

    analytical_tables_unchanged <- identical(
      analytical_sheet_names,
      baseline_sheet_names
    )

    differing_analytical_sheets <- character()

    if (analytical_tables_unchanged) {
      for (sheet_name in analytical_sheet_names) {
        if (!frames_equal(
          read_sheet(analytical_workbook, sheet_name),
          read_sheet(baseline_analytical, sheet_name)
        )) {
          differing_analytical_sheets <- c(
            differing_analytical_sheets,
            sheet_name
          )
        }
      }

      analytical_tables_unchanged <-
        length(differing_analytical_sheets) == 0L
    }

    add_check(
      "phase4_5_analytical_tables_unchanged",
      analytical_tables_unchanged,
      paste(differing_analytical_sheets, collapse = " | ")
    )
  }
} else {
  add_check(
    "phase4_5_baseline_comparison",
    TRUE,
    "skipped because no baseline directory was supplied"
  )
}

validation_table <- do.call(
  rbind,
  checks
)

rownames(validation_table) <- NULL

summary_table <- data.frame(
  metric = c(
    "loaded_modules",
    "network_nodes",
    "network_edges",
    "canonical_modules",
    "final_priority_proteins",
    "module_priorities",
    "candidate_evidence_rows",
    "validation_failures",
    "baseline_comparison_enabled"
  ),
  value = c(
    length(loaded_modules),
    igraph::gorder(graph),
    igraph::gsize(graph),
    nrow(result$biological_evidence$module_annotations),
    nrow(result$priorities$proteins),
    nrow(result$priorities$modules),
    nrow(result$priorities$candidate_evidence),
    sum(validation_table$status == "FAIL"),
    baseline_enabled
  ),
  stringsAsFactors = FALSE
)

validation_file <- file.path(
  results_root,
  "phase4_6_checkpoint_validation.csv"
)

summary_file <- file.path(
  results_root,
  "phase4_6_checkpoint_summary.csv"
)

utils::write.csv(
  validation_table,
  validation_file,
  row.names = FALSE,
  na = ""
)

utils::write.csv(
  summary_table,
  summary_file,
  row.names = FALSE,
  na = ""
)

cat(
  "\nPHASE 4.6 CANONICAL ANNOTATION CHECKPOINT\n\n"
)

print(
  summary_table,
  row.names = FALSE
)

cat("\nValidation checks:\n")

print(
  validation_table,
  row.names = FALSE
)

failed_checks <- validation_table[
  validation_table$status == "FAIL",
  ,
  drop = FALSE
]

cat(
  "\nOutput files:\n",
  "- ",
  summary_file,
  "\n- ",
  validation_file,
  "\n- ",
  unit_test_log,
  "\n",
  sep = ""
)

if (nrow(failed_checks) > 0L) {
  cat(
    "\nPHASE 4.6 CANONICAL ANNOTATION CHECKPOINT: FAILED\n"
  )

  quit(
    save = "no",
    status = 1L
  )
}

cat(
  "\nPHASE 4.6 CANONICAL ANNOTATION CHECKPOINT: PASSED\n"
)
