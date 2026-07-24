# CancerPPIr Phase 4.9 static release audit
#
# This file defines a sourceable validator. It performs no network analysis,
# does not initialize STRINGdb and does not modify repository files.

phase4_9_validate_static_release <- function(
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
      "scripts/validate_phase4_release_static.R",
      "scripts/run_phase4_release_checkpoint.R",
      "tests/testthat/test-release-edge-cases.R",
      "tests/testthat/test-release-static-contract.R",
      "docs/architecture/phase4_9_release_contract.md",
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
      "scripts",
      "validate_phase4_release_static.R"
    ),
    file.path(
      project_root,
      "scripts",
      "run_phase4_release_checkpoint.R"
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

  active_shadow_patterns <- c(
    "\\$biological_evidence_shadow",
    "biological_evidence_shadow[[:space:]]*="
  )

  active_shadow_hits <- character()

  for (path in names(production_text)) {
    text <- production_text[[path]]

    hit_patterns <- active_shadow_patterns[
      vapply(
        active_shadow_patterns,
        grepl,
        x = text,
        perl = TRUE,
        FUN.VALUE = logical(1)
      )
    ]

    if (length(hit_patterns) > 0L) {
      active_shadow_hits <- c(
        active_shadow_hits,
        paste0(
          path,
          ": ",
          hit_patterns
        )
      )
    }
  }

  add_check(
    "shadow_api_is_not_active",
    length(active_shadow_hits) == 0L,
    active_shadow_hits
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
        fixed = TRUE,
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
      "legacy",
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
    pipeline_result = "4.7.0",
    biological_evidence = "1.0.0",
    analytical_workbook = "4.5.0",
    technical_workbook = "4.4.0",
    graphml = "4.6.0",
    output_manifest = "1.0.0",
    output_checksums = "1.0.0"
  )

  add_check(
    "production_loader_is_complete",
    is.null(schema_error) &&
      length(loaded_modules) == 13L,
    if (is.null(schema_error)) {
      paste(basename(loaded_modules), collapse = " | ")
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
    "gprofiler2",
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
