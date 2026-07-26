#!/usr/bin/env Rscript

# CancerPPIr Phase 4.7 output provenance checkpoint
#
# Efficient release gate:
#   1. run the complete unit-test suite once;
#   2. run one real production case once (A01 by default);
#   3. validate JSON manifest and SHA-256 checksums;
#   4. confirm the public result exposes provenance and six output files;
#   5. compare topology, Louvain membership, candidate scores and analytical
#      workbook content with the completed Phase 4.6 A01 baseline.
#
# It deliberately does not rerun all seven clinical cases.
#
# Optional positional arguments:
#   1. input CSV
#   2. results root
#   3. STRING cache directory
#   4. Phase 4.6 baseline case directory, or "none"
#
# Defaults:
#   ../input/Genes_A.csv
#   ../results/phase4_7_a01_checkpoint_v1
#   ../string_cache
#   ../results/phase4_6_a01_checkpoint_v1/Genes_A

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
  file.path("..", "results", "phase4_7_a01_checkpoint_v1")
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
    "phase4_6_a01_checkpoint_v1",
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

if (baseline_enabled) {
  baseline_case_dir <- normalizePath(
    baseline_case_dir,
    winslash = "/",
    mustWork = TRUE
  )
}

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
      "Checkpoint dependencies are missing: ",
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
  "phase4_7_unit_tests.log"
)

message(
  "[Phase 4.7 checkpoint] Running unit tests once."
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
  "[Phase 4.7 checkpoint] Unit tests: PASS."
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
  "[Phase 4.7 checkpoint] Running one production case."
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
  checks[[length(checks) + 1L]] <<- data.frame(
    check_id = check_id,
    status = if (isTRUE(condition)) "PASS" else "FAIL",
    details = as.character(details),
    stringsAsFactors = FALSE
  )
}

expected_file_keys <- c(
  "analytical_report",
  "technical_report",
  "string_links",
  "graphml",
  "output_manifest",
  "output_checksums"
)

add_check(
  "canonical_result_class",
  inherits(result, "cancerppir_result"),
  paste(class(result), collapse = " | ")
)

add_check(
  "canonical_schema_registry",
  identical(
    result$schema_versions,
    cancerppir_schema_versions()
  ),
  paste(
    unlist(result$schema_versions),
    collapse = " | "
  )
)

add_check(
  "canonical_output_file_keys",
  identical(
    names(result$files),
    expected_file_keys
  ),
  paste(names(result$files), collapse = " | ")
)

add_check(
  "all_result_files_exist",
  all(file.exists(result$files)),
  paste(
    basename(result$files[!file.exists(result$files)]),
    collapse = " | "
  )
)

add_check(
  "provenance_object_present",
  is.list(result$provenance) &&
    all(
      c(
        "schema_version",
        "manifest",
        "manifest_file",
        "checksums_file",
        "validation"
      ) %in% names(result$provenance)
    ),
  paste(names(result$provenance), collapse = " | ")
)

provenance_validation <- cancerppir_validate_output_provenance(
  manifest_file = result$files[["output_manifest"]],
  checksums_file = result$files[["output_checksums"]],
  output_dir = result$output_dir,
  forbidden_paths = c(
    project_root,
    dirname(input_file),
    cache_dir,
    results_root,
    result$output_dir
  )
)

add_check(
  "output_provenance_validation",
  all(provenance_validation$status == "PASS"),
  paste(
    provenance_validation$check_id[
      provenance_validation$status == "FAIL"
    ],
    collapse = " | "
  )
)

manifest <- jsonlite::read_json(
  result$files[["output_manifest"]],
  simplifyVector = FALSE
)

add_check(
  "manifest_input_checksum",
  identical(
    manifest$input$sha256,
    cancerppir_sha256_file(input_file)
  ),
  as.character(manifest$input$sha256)
)

add_check(
  "manifest_input_name_is_basename",
  identical(
    manifest$input$file_name,
    basename(input_file)
  ),
  as.character(manifest$input$file_name)
)

add_check(
  "manifest_summary_matches_result_graph",
  identical(
    as.integer(manifest$summary$network_nodes),
    as.integer(igraph::gorder(result$network$graph))
  ) &&
    identical(
      as.integer(manifest$summary$network_edges),
      as.integer(igraph::gsize(result$network$graph))
    ) &&
    identical(
      as.integer(manifest$summary$Louvain_modules),
      as.integer(nrow(result$network$module_annotations))
    ),
  paste0(
    "nodes=", manifest$summary$network_nodes,
    "; edges=", manifest$summary$network_edges,
    "; modules=", manifest$summary$Louvain_modules
  )
)

current_git_commit <- cancerppir_git_metadata(
  project_root
)$commit

add_check(
  "manifest_git_commit_matches_runtime_repository",
  identical(
    as.character(manifest$software$git_commit),
    as.character(current_git_commit)
  ),
  paste0(
    "manifest=", manifest$software$git_commit,
    "; runtime=", current_git_commit
  )
)

manifest_text <- paste(
  readLines(
    result$files[["output_manifest"]],
    warn = FALSE,
    encoding = "UTF-8"
  ),
  collapse = "\n"
)

forbidden_paths <- unique(
  c(
    project_root,
    dirname(input_file),
    cache_dir,
    results_root,
    result$output_dir
  )
)

path_leak <- any(
  vapply(
    forbidden_paths,
    function(path_value) {
      grepl(
        path_value,
        manifest_text,
        fixed = TRUE
      )
    },
    FUN.VALUE = logical(1)
  )
)

add_check(
  "manifest_contains_no_known_absolute_paths",
  !path_leak,
  paste(forbidden_paths, collapse = " | ")
)

edge_signature <- function(graph) {
  edges <- igraph::as_data_frame(
    graph,
    what = "edges"
  )

  if (nrow(edges) == 0L) {
    return(data.frame(
      node_a = character(),
      node_b = character(),
      stringsAsFactors = FALSE
    ))
  }

  node_a <- pmin(
    as.character(edges$from),
    as.character(edges$to)
  )

  node_b <- pmax(
    as.character(edges$from),
    as.character(edges$to)
  )

  output <- data.frame(
    node_a = node_a,
    node_b = node_b,
    stringsAsFactors = FALSE
  )

  if ("combined_score" %in% names(edges)) {
    output$combined_score <- as.numeric(
      edges$combined_score
    )
  }

  output[order(output$node_a, output$node_b), , drop = FALSE]
}

workbook_semantic_hashes <- function(path) {
  sheet_names <- openxlsx::getSheetNames(path)

  hashes <- vapply(
    sheet_names,
    function(sheet_name) {
      table <- openxlsx::read.xlsx(
        path,
        sheet = sheet_name,
        colNames = TRUE,
        check.names = FALSE,
        detectDates = TRUE
      )

      digest::digest(
        list(
          sheet_name = sheet_name,
          columns = names(table),
          values = as.data.frame(
            table,
            stringsAsFactors = FALSE,
            check.names = FALSE
          )
        ),
        algo = "sha256",
        serialize = TRUE
      )
    },
    FUN.VALUE = character(1)
  )

  hashes
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

  add_check(
    "baseline_files_exist",
    file.exists(baseline_graphml) &&
      file.exists(baseline_analytical),
    paste(
      basename(
        c(
          baseline_graphml,
          baseline_analytical
        )[
          !file.exists(
            c(
              baseline_graphml,
              baseline_analytical
            )
          )
        ]
      ),
      collapse = " | "
    )
  )

  if (
    file.exists(baseline_graphml) &&
      file.exists(baseline_analytical)
  ) {
    baseline_graph <- igraph::read_graph(
      baseline_graphml,
      format = "graphml"
    )

    new_graph <- igraph::read_graph(
      result$files[["graphml"]],
      format = "graphml"
    )

    add_check(
      "baseline_vertex_set_unchanged",
      setequal(
        as.character(igraph::V(new_graph)$name),
        as.character(igraph::V(baseline_graph)$name)
      ),
      paste0(
        "new=", igraph::gorder(new_graph),
        "; baseline=", igraph::gorder(baseline_graph)
      )
    )

    add_check(
      "baseline_edge_set_unchanged",
      identical(
        edge_signature(new_graph),
        edge_signature(baseline_graph)
      ),
      paste0(
        "new=", igraph::gsize(new_graph),
        "; baseline=", igraph::gsize(baseline_graph)
      )
    )

    baseline_vertex_index <- match(
      as.character(igraph::V(new_graph)$name),
      as.character(igraph::V(baseline_graph)$name)
    )

    add_check(
      "baseline_louvain_membership_unchanged",
      identical(
        as.character(
          igraph::vertex_attr(
            new_graph,
            "community_louvain"
          )
        ),
        as.character(
          igraph::vertex_attr(
            baseline_graph,
            "community_louvain"
          )[
            baseline_vertex_index
          ]
        )
      ),
      "community_louvain"
    )

    new_scores <- as.numeric(
      igraph::vertex_attr(
        new_graph,
        "candidate_score"
      )
    )

    baseline_scores <- as.numeric(
      igraph::vertex_attr(
        baseline_graph,
        "candidate_score"
      )[
        baseline_vertex_index
      ]
    )

    add_check(
      "baseline_candidate_scores_unchanged",
      isTRUE(
        all.equal(
          new_scores,
          baseline_scores,
          tolerance = 1e-12,
          check.attributes = FALSE
        )
      ),
      paste0(
        "maximum_absolute_difference=",
        max(abs(new_scores - baseline_scores), na.rm = TRUE)
      )
    )

    new_workbook_hashes <- workbook_semantic_hashes(
      result$files[["analytical_report"]]
    )

    baseline_workbook_hashes <- workbook_semantic_hashes(
      baseline_analytical
    )

    add_check(
      "baseline_analytical_workbook_unchanged",
      identical(
        new_workbook_hashes,
        baseline_workbook_hashes
      ),
      paste(names(new_workbook_hashes), collapse = " | ")
    )
  }
} else {
  add_check(
    "baseline_comparison_skipped_by_request",
    TRUE,
    "baseline argument was none/false/skip"
  )
}

validation <- do.call(rbind, checks)
rownames(validation) <- NULL

summary_table <- data.frame(
  metric = c(
    "unit_tests",
    "network_nodes",
    "network_edges",
    "Louvain_modules",
    "manifest_outputs",
    "checksum_entries",
    "failed_checks"
  ),
  value = c(
    "PASS",
    as.character(igraph::gorder(result$network$graph)),
    as.character(igraph::gsize(result$network$graph)),
    as.character(nrow(result$network$module_annotations)),
    as.character(length(manifest$outputs)),
    as.character(
      nrow(
        cancerppir_parse_checksum_file(
          result$files[["output_checksums"]]
        )
      )
    ),
    as.character(sum(validation$status == "FAIL"))
  ),
  stringsAsFactors = FALSE
)

summary_file <- file.path(
  results_root,
  "phase4_7_checkpoint_summary.csv"
)

validation_file <- file.path(
  results_root,
  "phase4_7_checkpoint_validation.csv"
)

utils::write.csv(
  summary_table,
  summary_file,
  row.names = FALSE,
  na = ""
)

utils::write.csv(
  validation,
  validation_file,
  row.names = FALSE,
  na = ""
)

cat(
  "\nPHASE 4.7 OUTPUT PROVENANCE CHECKPOINT\n\n"
)

print(
  summary_table,
  row.names = FALSE
)

failed_checks <- validation[
  validation$status == "FAIL",
  ,
  drop = FALSE
]

if (nrow(failed_checks) > 0L) {
  cat("\nFailed checks:\n")
  print(failed_checks, row.names = FALSE)
}

cat(
  "\nOutput files:\n",
  "- ", summary_file, "\n",
  "- ", validation_file, "\n",
  "- ", unit_test_log, "\n",
  sep = ""
)

if (nrow(failed_checks) > 0L) {
  cat(
    "\nPHASE 4.7 OUTPUT PROVENANCE CHECKPOINT: FAILED\n"
  )

  quit(
    save = "no",
    status = 1L
  )
}

cat(
  "\nPHASE 4.7 OUTPUT PROVENANCE CHECKPOINT: PASSED\n"
)
