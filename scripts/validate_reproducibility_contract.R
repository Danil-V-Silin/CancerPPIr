#!/usr/bin/env Rscript
# CancerPPIr reproducible software-environment contract.
#
# This validator is static and fast. It does not restore packages, access STRING,
# execute network analysis, or run the seven clinical regression cases.

cancerppir_validate_reproducibility_contract <- function(
  project_root = normalizePath(".", winslash = "/", mustWork = TRUE)
) {
  project_root <- normalizePath(
    project_root,
    winslash = "/",
    mustWork = TRUE
  )

  checks <- list()

  add_check <- function(check_id, condition, details = "") {
    checks[[length(checks) + 1L]] <<- data.frame(
      check_id = as.character(check_id),
      status = if (isTRUE(condition)) "PASS" else "FAIL",
      details = paste(as.character(details), collapse = " | "),
      stringsAsFactors = FALSE
    )
    invisible(NULL)
  }

  `%||%` <- function(value, fallback) {
    if (is.null(value) || length(value) == 0L) fallback else value
  }

  read_utf8 <- function(path) {
    paste(
      readLines(path, warn = FALSE, encoding = "UTF-8"),
      collapse = "\n"
    )
  }

  major_minor <- function(version) {
    pieces <- strsplit(as.character(version), ".", fixed = TRUE)[[1L]]
    if (length(pieces) < 2L) return("")
    paste(pieces[1:2], collapse = ".")
  }

  required_files <- c(
    ".Rprofile",
    "renv.lock",
    "renv/activate.R",
    "renv/settings.json",
    ".github/workflows/r-tests.yml",
    "docs/reference/contracts/reproducible-environment.md"
  )

  missing_files <- required_files[
    !file.exists(file.path(project_root, required_files))
  ]

  add_check(
    "reproducibility_files_exist",
    length(missing_files) == 0L,
    missing_files
  )

  if (!requireNamespace("jsonlite", quietly = TRUE)) {
    add_check(
      "jsonlite_is_available",
      FALSE,
      "jsonlite is required to validate renv.lock."
    )
    results <- do.call(rbind, checks)
    rownames(results) <- NULL
    return(results)
  }

  add_check("jsonlite_is_available", TRUE)

  lockfile_path <- file.path(project_root, "renv.lock")
  lockfile <- tryCatch(
    jsonlite::fromJSON(
      lockfile_path,
      simplifyVector = FALSE
    ),
    error = function(error) error
  )

  lockfile_valid <- !inherits(lockfile, "error")
  add_check(
    "renv_lock_is_valid_json",
    lockfile_valid,
    if (!lockfile_valid) conditionMessage(lockfile) else ""
  )

  if (!lockfile_valid) {
    results <- do.call(rbind, checks)
    rownames(results) <- NULL
    return(results)
  }

  lock_r_version <- as.character(lockfile$R$Version %||% "")
  bioconductor_version <- as.character(
    lockfile$Bioconductor$Version %||% ""
  )
  repositories <- lockfile$R$Repositories %||% list()

  repository_names <- vapply(
    repositories,
    function(repository) {
      as.character(repository$Name %||% "")
    },
    FUN.VALUE = character(1)
  )
  repository_urls <- vapply(
    repositories,
    function(repository) {
      as.character(repository$URL %||% "")
    },
    FUN.VALUE = character(1)
  )

  cran_index <- which(repository_names == "CRAN")
  cran_url <- if (length(cran_index) == 1L) {
    repository_urls[[cran_index]]
  } else {
    ""
  }

  add_check(
    "lockfile_r_version_is_4_5_0",
    identical(lock_r_version, "4.5.0"),
    paste0("lockfile R=", lock_r_version)
  )

  runtime_version <- as.character(getRversion())
  add_check(
    "runtime_matches_lockfile_r_series",
    identical(
      major_minor(runtime_version),
      major_minor(lock_r_version)
    ),
    paste0(
      "runtime R=",
      runtime_version,
      "; lockfile R=",
      lock_r_version
    )
  )

  add_check(
    "bioconductor_release_is_3_21",
    identical(bioconductor_version, "3.21"),
    paste0("Bioconductor=", bioconductor_version)
  )

  expected_cran_url <-
    "https://packagemanager.posit.co/cran/2026-07-20"

  add_check(
    "cran_repository_is_date_pinned",
    identical(cran_url, expected_cran_url),
    paste0("CRAN=", cran_url)
  )

  moving_repository_hits <- repository_urls[
    grepl("/latest/?$", repository_urls, perl = TRUE) |
      grepl("cloud\\.r-project\\.org", repository_urls, perl = TRUE)
  ]

  add_check(
    "moving_repository_aliases_are_absent",
    length(moving_repository_hits) == 0L,
    moving_repository_hits
  )

  package_count <- length(lockfile$Packages %||% list())
  add_check(
    "lockfile_contains_package_records",
    package_count >= 20L,
    paste0("package records=", package_count)
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

  workflow_tokens <- c(
    "r-version: '4.5.0'",
    "r-lib/actions/setup-renv@",
    "Validate reproducibility contract",
    "Rscript scripts/validate_reproducibility_contract.R"
  )
  missing_workflow_tokens <- workflow_tokens[
    !vapply(
      workflow_tokens,
      grepl,
      x = workflow_text,
      fixed = TRUE,
      FUN.VALUE = logical(1)
    )
  ]

  add_check(
    "ci_enforces_reproducibility_contract",
    length(missing_workflow_tokens) == 0L,
    missing_workflow_tokens
  )

  forbidden_workflow_tokens <- c(
    "RENV_CONFIG_REPOS_OVERRIDE",
    "https://cloud.r-project.org"
  )
  workflow_override_hits <- forbidden_workflow_tokens[
    vapply(
      forbidden_workflow_tokens,
      grepl,
      x = workflow_text,
      fixed = TRUE,
      FUN.VALUE = logical(1)
    )
  ]

  add_check(
    "ci_repository_override_is_absent",
    length(workflow_override_hits) == 0L,
    workflow_override_hits
  )

  release_gate_path <- file.path(
    project_root,
    "scripts",
    "run_release_qualification.R"
  )
  release_gate_text <- if (file.exists(release_gate_path)) {
    read_utf8(release_gate_path)
  } else {
    ""
  }
  release_gate_tokens <- c(
    "scripts/validate_reproducibility_contract.R",
    "cancerppir_validate_reproducibility_contract",
    'section = "reproducibility"',
    "reproducibility and CLI preflight: PASS"
  )
  missing_release_gate_tokens <- release_gate_tokens[
    !vapply(
      release_gate_tokens,
      grepl,
      x = release_gate_text,
      fixed = TRUE,
      FUN.VALUE = logical(1)
    )
  ]

  add_check(
    "release_preflight_enforces_reproducibility_contract",
    length(missing_release_gate_tokens) == 0L,
    missing_release_gate_tokens
  )

  contract_path <- file.path(
    project_root,
    "docs",
    "reference",
    "contracts",
    "reproducible-environment.md"
  )
  contract_text <- if (file.exists(contract_path)) {
    read_utf8(contract_path)
  } else {
    ""
  }
  documentation_tokens <- c(
    "R 4.5.x",
    "R 4.5.0",
    "Bioconductor 3.21",
    expected_cran_url,
    "renv::restore()",
    "repository override"
  )
  missing_documentation_tokens <- documentation_tokens[
    !vapply(
      documentation_tokens,
      grepl,
      x = contract_text,
      fixed = TRUE,
      FUN.VALUE = logical(1)
    )
  ]

  add_check(
    "environment_contract_is_documented",
    length(missing_documentation_tokens) == 0L,
    missing_documentation_tokens
  )

  results <- do.call(rbind, checks)
  rownames(results) <- NULL
  results
}

if (sys.nframe() == 0L) {
  validation <- cancerppir_validate_reproducibility_contract()
  print(validation, row.names = FALSE)

  failures <- validation[
    validation$status == "FAIL",
    ,
    drop = FALSE
  ]

  if (nrow(failures) > 0L) {
    cat("\nCANCERPPIR REPRODUCIBILITY CONTRACT: FAILED\n")
    quit(save = "no", status = 1L)
  }

  cat("\nCANCERPPIR REPRODUCIBILITY CONTRACT: PASSED\n")
}
