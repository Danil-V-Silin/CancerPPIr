# CancerPPIr static release audit
#
# This file defines a sourceable validator. It performs no network analysis,
# does not initialize STRINGdb and does not modify repository files.

cancerppir_validate_static_release_contract <- function(
  project_root = normalizePath(
    ".",
    winslash = "/",
    mustWork = TRUE
  )
) {
  checks <- list()

  add_check <- function(
    check_id,
    condition,
    details = ""
  ) {
    checks[[length(checks) + 1L]] <<- data.frame(
      check_id = as.character(check_id),
      status = if (isTRUE(condition)) "PASS" else "FAIL",
      details = paste(as.character(details), collapse = " | "),
      stringsAsFactors = FALSE
    )

    invisible(NULL)
  }

  read_utf8 <- function(path) {
    paste(
      readLines(
        path,
        warn = FALSE,
        encoding = "UTF-8"
      ),
      collapse = "\n"
    )
  }

  production_files <- c(
    list.files(
      file.path(project_root, "R"),
      pattern = "\\.R$",
      full.names = TRUE
    ),
    file.path(project_root, "cancerppir.R")
  )

  production_files <- production_files[
    file.exists(production_files)
  ]

  required_release_files <- file.path(
    project_root,
    c(
      "scripts/validate_release_contract.R",
      "scripts/run_release_qualification.R",
      "tests/testthat/test-release-edge-cases.R",
      "tests/testthat/test-release-static-contract.R",
      "docs/reference/contracts/release-validation.md",
      ".github/workflows/r-tests.yml"
    )
  )

  add_check(
    "release_files_exist",
    all(file.exists(required_release_files)),
    basename(required_release_files[!file.exists(required_release_files)])
  )

  parse_failures <- character()

  for (path in production_files) {
    parsed <- tryCatch(
      {
        parse(file = path, keep.source = FALSE)
        TRUE
      },
      error = function(error) {
        parse_failures <<- c(
          parse_failures,
          paste0(
            basename(path),
            ": ",
            conditionMessage(error)
          )
        )
        FALSE
      }
    )

    invisible(parsed)
  }

  release_r_files <- c(
    file.path(
      project_root,
      "scripts", "validate_release_contract.R"
    ),
    file.path(
      project_root,
      "scripts", "run_release_qualification.R"
    ),
    file.path(
      project_root,
      "tests",
      "testthat",
      "test-release-edge-cases.R"
    ),
    file.path(
      project_root,
      "tests",
      "testthat",
      "test-release-static-contract.R"
    )
  )

  for (path in release_r_files[file.exists(release_r_files)]) {
    tryCatch(
      parse(file = path, keep.source = FALSE),
      error = function(error) {
        parse_failures <<- c(
          parse_failures,
          paste0(
            basename(path),
            ": ",
            conditionMessage(error)
          )
        )
      }
    )
  }

  add_check(
    "release_r_files_parse",
    length(parse_failures) == 0L,
    parse_failures
  )

  production_text <- vapply(
    production_files,
    read_utf8,
    FUN.VALUE = character(1)
  )

  normalized_project_root <- normalizePath(
    project_root,
    winslash = "/",
    mustWork = TRUE
  )

  normalized_production_files <- normalizePath(
    production_files,
    winslash = "/",
    mustWork = TRUE
  )

  relative_production_files <- ifelse(
    startsWith(
      normalized_production_files,
      paste0(
        normalized_project_root,
        "/"
      )
    ),
    substring(
      normalized_production_files,
      nchar(normalized_project_root) + 2L
    ),
    basename(normalized_production_files)
  )

  names(production_text) <- relative_production_files

  deprecated_parallel_field <- paste0(
    "biological_evidence_",
    paste0(c("s", "h", "a", "d", "o", "w"), collapse = "")
  )

  deprecated_parallel_patterns <- c(
    paste0("\\$", deprecated_parallel_field),
    paste0(deprecated_parallel_field, "[[:space:]]*=")
  )

  deprecated_parallel_hits <- character()

  for (path in names(production_text)) {
    text <- production_text[[path]]

    hit_patterns <- deprecated_parallel_patterns[
      vapply(
        deprecated_parallel_patterns,
        grepl,
        x = text,
        perl = TRUE,
        FUN.VALUE = logical(1)
      )
    ]

    if (length(hit_patterns) > 0L) {
      deprecated_parallel_hits <- c(
        deprecated_parallel_hits,
        paste0(path, ": ", hit_patterns)
      )
    }
  }

  add_check(
    "deprecated_parallel_result_api_is_absent",
    length(deprecated_parallel_hits) == 0L,
    deprecated_parallel_hits
  )

  input_text <- production_text[["R/input.R"]]
  network_analysis_text <- production_text[["R/network_analysis.R"]]

  strict_input_contract_present <-
    !is.null(input_text) &&
    grepl(
      "CANCERPPIR_INPUT_CONTRACT_SCHEMA_VERSION",
      input_text,
      fixed = TRUE
    ) &&
    grepl(
      "positional_column_fallback = FALSE",
      input_text,
      fixed = TRUE
    ) &&
    grepl(
      "pvalue must lie in the closed interval [0, 1]",
      input_text,
      fixed = TRUE
    ) &&
    grepl(
      "Duplicate gene symbols are not permitted",
      input_text,
      fixed = TRUE
    ) &&
    !grepl(
      "assuming order: pvalue, logFC, gene",
      input_text,
      fixed = TRUE
    )

  add_check(
    "strict_scientific_input_contract_is_enforced",
    strict_input_contract_present,
    "Explicit headers, complete finite values, bounded raw p-values, unique genes and no positional fallback are required."
  )

  complete_candidate_score_present <-
    !is.null(network_analysis_text) &&
    grepl(
      "calculate_candidate_score <- function",
      network_analysis_text,
      fixed = TRUE
    ) &&
    grepl(
      "requires all five finite components",
      network_analysis_text,
      fixed = TRUE
    ) &&
    grepl(
      "node_metrics$candidate_score <- calculate_candidate_score",
      network_analysis_text,
      fixed = TRUE
    ) &&
    !grepl(
      "candidate_score = rowMeans",
      network_analysis_text,
      fixed = TRUE
    )

  add_check(
    "candidate_score_requires_complete_five_component_evidence",
    complete_candidate_score_present,
    "Variable-denominator candidate scoring is not permitted."
  )

  patient_id_pattern <-
    "\\b(A01|K01|L01|M01|P01|P02|R01)\\b"

  patient_id_hits <- names(production_text)[
    vapply(
      production_text,
      grepl,
      pattern = patient_id_pattern,
      perl = TRUE,
      FUN.VALUE = logical(1)
    )
  ]

  add_check(
    "production_code_has_no_hard_coded_case_ids",
    length(patient_id_hits) == 0L,
    patient_id_hits
  )

  personal_path_patterns <- c(
    "danil",
    "OneDrive",
    "Рабочий стол",
    "C:/Users/",
    "C:\\\\Users\\\\"
  )

  personal_path_hits <- character()

  for (path in names(production_text)) {
    text <- production_text[[path]]

    hit_patterns <- personal_path_patterns[
      vapply(
        personal_path_patterns,
        grepl,
        x = text,
        ignore.case = TRUE,
        FUN.VALUE = logical(1)
      )
    ]

    if (length(hit_patterns) > 0L) {
      personal_path_hits <- c(
        personal_path_hits,
        paste0(
          path,
          ": ",
          hit_patterns
        )
      )
    }
  }

  add_check(
    "production_code_has_no_personal_absolute_paths",
    length(personal_path_hits) == 0L,
    personal_path_hits
  )

  unfinished_pattern <-
    "(^|[^A-Za-z0-9_])(TODO|FIXME|DEBUG|TEMP)([^A-Za-z0-9_]|$)"

  unfinished_hits <- names(production_text)[
    vapply(
      production_text,
      grepl,
      pattern = unfinished_pattern,
      perl = TRUE,
      ignore.case = FALSE,
      FUN.VALUE = logical(1)
    )
  ]

  add_check(
    "production_code_has_no_unfinished_markers",
    length(unfinished_hits) == 0L,
    unfinished_hits
  )

  function_definitions <- list()

  function_pattern <-
    "^([A-Za-z][A-Za-z0-9_.]*)[[:space:]]*<-[[:space:]]*function[[:space:]]*\\("

  for (path in production_files) {
    lines <- readLines(
      path,
      warn = FALSE,
      encoding = "UTF-8"
    )

    matches <- regexec(
      function_pattern,
      lines,
      perl = TRUE
    )

    parts <- regmatches(
      lines,
      matches
    )

    function_names <- vapply(
      parts[lengths(parts) >= 2L],
      `[[`,
      character(1),
      2L
    )

    if (length(function_names) > 0L) {
      for (function_name in function_names) {
        function_definitions[[function_name]] <- c(
          function_definitions[[function_name]],
          basename(path)
        )
      }
    }
  }

  duplicated_functions <- names(function_definitions)[
    lengths(function_definitions) > 1L
  ]

  duplicated_function_details <- vapply(
    duplicated_functions,
    function(function_name) {
      paste0(
        function_name,
        ": ",
        paste(
          function_definitions[[function_name]],
          collapse = ", "
        )
      )
    },
    FUN.VALUE = character(1)
  )

  add_check(
    "production_function_names_are_unique",
    length(duplicated_functions) == 0L,
    duplicated_function_details
  )

  generated_example_outputs <- file.path(
    project_root,
    "examples",
    "output",
    c(
      "CancerPPIr_Analytical_Report.xlsx",
      "CancerPPIr_Technical_Report.xlsx",
      "Network_for_Cytoscape.graphml",
      "STRING_links.txt",
      "CancerPPIr_Output_Manifest.json",
      "CancerPPIr_Output_Checksums.sha256"
    )
  )

  add_check(
    "obsolete_generated_examples_are_absent",
    !any(file.exists(generated_example_outputs)),
    basename(generated_example_outputs[file.exists(generated_example_outputs)])
  )

  nested_git_directories <- character()

  nested_search_roots <- file.path(
    project_root,
    c(
      "R",
      "scripts",
      "tests",
      "docs",
      "examples",
      "renv",
      ".github"
    )
  )

  nested_search_roots <- nested_search_roots[
    dir.exists(nested_search_roots)
  ]

  for (search_root in nested_search_roots) {
    entries <- list.files(
      search_root,
      all.files = TRUE,
      recursive = TRUE,
      full.names = TRUE,
      include.dirs = TRUE,
      no.. = TRUE
    )

    nested_git_directories <- c(
      nested_git_directories,
      entries[
        basename(entries) == ".git" &
          dir.exists(entries)
      ]
    )
  }

  add_check(
    "no_nested_git_repositories",
    length(nested_git_directories) == 0L,
    nested_git_directories
  )

  semantic_scan_roots <- file.path(
    project_root,
    c(
      "R",
      "scripts",
      "tests/testthat",
      "docs",
      "examples",
      "tools/audit"
    )
  )

  semantic_scan_files <- unlist(lapply(
    semantic_scan_roots[dir.exists(semantic_scan_roots)],
    function(scan_root) {
      list.files(
        scan_root,
        pattern = "\\.(R|md|txt|csv|yml|yaml)$",
        recursive = TRUE,
        full.names = TRUE
      )
    }
  ), use.names = FALSE)

  obsolete_semantic_patterns <- c(
    paste0("phase", "4"),
    paste0("Phase", " 4"),
    paste0("run_release_", paste0(c("c", "h", "e", "c", "k", "p", "o", "i", "n", "t"), collapse = ""), ".R")
  )

  obsolete_semantic_hits <- character()

  for (path in semantic_scan_files[file.exists(semantic_scan_files)]) {
    text <- read_utf8(path)
    matched <- obsolete_semantic_patterns[vapply(
      obsolete_semantic_patterns,
      grepl,
      x = text,
      fixed = TRUE,
      FUN.VALUE = logical(1)
    )]

    if (length(matched) > 0L) {
      obsolete_semantic_hits <- c(
        obsolete_semantic_hits,
        paste0(basename(path), ": ", paste(matched, collapse = " | "))
      )
    }
  }

  add_check(
    "obsolete_development_stage_labels_are_absent",
    length(obsolete_semantic_hits) == 0L,
    obsolete_semantic_hits
  )

  obsolete_tree_paths <- file.path(
    project_root,
    c(
      "docs/development/history",
      "docs/development/architecture",
      "tools/development/history",
      "tools/development/architecture",
      "examples/input/Genes_R.csv"
    )
  )

  add_check(
    "superseded_repository_tree_is_absent",
    !any(file.exists(obsolete_tree_paths)),
    obsolete_tree_paths[file.exists(obsolete_tree_paths)]
  )

  schema_environment <- new.env(
    parent = globalenv()
  )

  schema_error <- NULL
  loaded_modules <- character()
  observed_schema_versions <- NULL

  tryCatch(
    {
      sys.source(
        file.path(
          project_root,
          "R",
          "load_all.R"
        ),
        envir = schema_environment,
        keep.source = FALSE
      )

      loaded_modules <-
        schema_environment$load_cancerppir_modules(
          project_root = project_root,
          envir = schema_environment
        )

      observed_schema_versions <-
        schema_environment$cancerppir_schema_versions()
    },
    error = function(error) {
      schema_error <<- conditionMessage(error)
    }
  )

  expected_schema_versions <- list(
    pipeline_result = "1.0.0",
    biological_evidence = "1.0.0",
    analytical_workbook = "2.0.0",
    technical_workbook = "1.0.0",
    graphml = "1.0.0",
    output_manifest = "1.0.0",
    output_checksums = "1.0.0"
  )

  expected_production_modules <- setdiff(
    basename(
      list.files(
        file.path(project_root, "R"),
        pattern = "\\.R$",
        full.names = FALSE
      )
    ),
    "load_all.R"
  )

  observed_production_modules <- basename(
    loaded_modules
  )

  add_check(
    "production_loader_is_complete",
    is.null(schema_error) &&
      length(observed_production_modules) ==
        length(expected_production_modules) &&
      setequal(
        observed_production_modules,
        expected_production_modules
      ),
    if (is.null(schema_error)) {
      paste(
        observed_production_modules,
        collapse = " | "
      )
    } else {
      schema_error
    }
  )
  add_check(
    "public_schema_versions_are_pinned",
    is.null(schema_error) &&
      identical(
        observed_schema_versions,
        expected_schema_versions
      ),
    if (is.null(schema_error)) {
      paste(
        names(observed_schema_versions),
        unlist(observed_schema_versions),
        sep = "=",
        collapse = "; "
      )
    } else {
      schema_error
    }
  )

  renv_lock_path <- file.path(
    project_root,
    "renv.lock"
  )

  required_locked_packages <- c(
    "HGNChelper",
    "STRINGdb",
    "igraph",
    "openxlsx",
    "dplyr",
    "tibble",
    "curl",
    "sna",
    "jsonlite",
    "digest",
    "testthat"
  )

  missing_locked_packages <- required_locked_packages

  if (
    file.exists(renv_lock_path) &&
      requireNamespace(
        "jsonlite",
        quietly = TRUE
      )
  ) {
    lock_data <- tryCatch(
      jsonlite::read_json(
        renv_lock_path,
        simplifyVector = FALSE
      ),
      error = function(error) NULL
    )

    if (
      is.list(lock_data) &&
        is.list(lock_data$Packages)
    ) {
      missing_locked_packages <- setdiff(
        required_locked_packages,
        names(lock_data$Packages)
      )
    }
  }

  add_check(
    "runtime_and_test_dependencies_are_locked",
    length(missing_locked_packages) == 0L,
    missing_locked_packages
  )

  workflow_path <- file.path(
    project_root,
    ".github",
    "workflows",
    "r-tests.yml"
  )

  workflow_text <- if (file.exists(workflow_path)) {
    read_utf8(workflow_path)
  } else {
    ""
  }

  cross_platform_ci <- all(
    vapply(
      c(
        "ubuntu-24.04",
        "windows-2022"
      ),
      grepl,
      x = workflow_text,
      fixed = TRUE,
      FUN.VALUE = logical(1)
    )
  )

  add_check(
    "ci_covers_ubuntu_and_windows",
    cross_platform_ci,
    "Expected ubuntu-24.04 and windows-2022."
  )

  output <- if (length(checks) > 0L) {
    do.call(
      rbind,
      checks
    )
  } else {
    data.frame(
      check_id = character(),
      status = character(),
      details = character(),
      stringsAsFactors = FALSE
    )
  }

  rownames(output) <- NULL
  output
}
