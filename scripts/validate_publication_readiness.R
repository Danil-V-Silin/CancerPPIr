# Publication-readiness validator for CancerPPIr.

cancerppir_validate_publication_readiness <- function(
  project_root = normalizePath(".", winslash = "/", mustWork = TRUE),
  include_git_diff_check = TRUE
) {
  project_root <- normalizePath(project_root, winslash = "/", mustWork = TRUE)

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

  read_utf8 <- function(path) {
    paste(readLines(path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
  }

  rel <- function(path) {
    normalized <- normalizePath(path, winslash = "/", mustWork = FALSE)
    prefix <- paste0(project_root, "/")
    if (startsWith(normalized, prefix)) {
      substring(normalized, nchar(prefix) + 1L)
    } else {
      basename(normalized)
    }
  }

  required_files <- c(
    "VERSION",
    "LICENSE",
    "CITATION.cff",
    "CHANGELOG.md",
    "CONTRIBUTING.md",
    "SECURITY.md",
    "README.md",
    "cancerppir.R",
    "R/load_all.R",
    "scripts/run_release_checkpoint.R",
    "scripts/validate_release_contract.R",
    "scripts/validate_documentation_contract.R",
    "scripts/validate_publication_readiness.R",
    "tools/audit/audit_workbook_duplication.R",
    "docs/README.md",
    "docs/reference/cli.md",
    "docs/reference/output-contract.md",
    "docs/reference/schema-versioning.md",
    "docs/reference/contracts/analytical-workbook.md",
    "docs/reference/contracts/canonical-annotations.md",
    "docs/reference/contracts/output-provenance.md",
    "docs/reference/contracts/release-validation.md",
    "docs/development/release-process.md",
    "docs/development/repository-governance.md",
    "docs/development/publication-readiness-checklist.md",
    "docs/development/release-notes-v1.0.0-rc.1.md"
  )

  missing_files <- required_files[
    !file.exists(file.path(project_root, required_files))
  ]

  add_check(
    "publication_files_exist",
    length(missing_files) == 0L,
    missing_files
  )

  version_text <- trimws(read_utf8(file.path(project_root, "VERSION")))
  citation_text <- read_utf8(file.path(project_root, "CITATION.cff"))

  add_check(
    "release_candidate_version_is_consistent",
    identical(version_text, "1.0.0-rc.1") &&
      grepl('version: "1.0.0-rc.1"', citation_text, fixed = TRUE),
    paste0("VERSION=", version_text)
  )

  git_command <- Sys.which("git")
  tag_exists <- FALSE

  if (nzchar(git_command)) {
    tag_output <- suppressWarnings(
      system2(
        git_command,
        args = c(
          "-C",
          shQuote(project_root),
          "tag",
          "--list",
          "v1.0.0-rc.1"
        ),
        stdout = TRUE,
        stderr = TRUE
      )
    )
    tag_exists <- any(trimws(tag_output) == "v1.0.0-rc.1")
  }

  citation_has_date <- grepl(
    "(?m)^date-released:",
    citation_text,
    perl = TRUE
  )

  changelog_text <- read_utf8(file.path(project_root, "CHANGELOG.md"))
  notes_text <- read_utf8(file.path(
    project_root,
    "docs/development/release-notes-v1.0.0-rc.1.md"
  ))

  date_state_valid <- if (tag_exists) {
    citation_has_date &&
      !grepl("[1.0.0-rc.1] - Unreleased", changelog_text, fixed = TRUE) &&
      !grepl("Release date: pending.", notes_text, fixed = TRUE)
  } else {
    !citation_has_date &&
      grepl("[1.0.0-rc.1] - Unreleased", changelog_text, fixed = TRUE) &&
      grepl("Release date: pending.", notes_text, fixed = TRUE)
  }

  add_check(
    "release_date_matches_tag_state",
    date_state_valid,
    paste0(
      "tag_exists=", tag_exists,
      "; citation_date=", citation_has_date
    )
  )

  parse_files <- unique(c(
    list.files(
      file.path(project_root, "R"),
      pattern = "\\.R$",
      recursive = TRUE,
      full.names = TRUE
    ),
    file.path(project_root, "cancerppir.R"),
    list.files(
      file.path(project_root, "scripts"),
      pattern = "\\.R$",
      recursive = TRUE,
      full.names = TRUE
    ),
    list.files(
      file.path(project_root, "tests"),
      pattern = "\\.R$",
      recursive = TRUE,
      full.names = TRUE
    ),
    list.files(
      file.path(project_root, "tools", "audit"),
      pattern = "\\.R$",
      recursive = TRUE,
      full.names = TRUE
    )
  ))

  parse_failures <- character()

  for (path in parse_files[file.exists(parse_files)]) {
    tryCatch(
      parse(file = path, keep.source = FALSE),
      error = function(error) {
        parse_failures <<- c(
          parse_failures,
          paste0(rel(path), ": ", conditionMessage(error))
        )
      }
    )
  }

  add_check(
    "active_r_files_parse",
    length(parse_failures) == 0L,
    parse_failures
  )

  schema_environment <- new.env(parent = globalenv())
  schema_error <- NULL
  observed_schema_versions <- NULL

  tryCatch(
    {
      sys.source(
        file.path(project_root, "R", "load_all.R"),
        envir = schema_environment,
        keep.source = FALSE
      )
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

  expected_schema_versions <- as.list(
    stats::setNames(
      rep("1.0.0", 7L),
      c(
        "pipeline_result",
        "biological_evidence",
        "analytical_workbook",
        "technical_workbook",
        "graphml",
        "output_manifest",
        "output_checksums"
      )
    )
  )

  add_check(
    "public_schema_registry_is_1_0_0",
    is.null(schema_error) &&
      identical(observed_schema_versions, expected_schema_versions),
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

  pipeline_text <- read_utf8(file.path(project_root, "R", "pipeline.R"))
  technical_sheet_names <- c(
    "Module annotations",
    "Rule evidence",
    "Significant terms",
    "Node annotations",
    "Validation"
  )
  obsolete_sheet_names <- paste0(
    paste0("Phase", "4"),
    " ",
    tolower(technical_sheet_names)
  )

  add_check(
    "technical_evidence_sheet_names_are_semantic",
    all(vapply(
      technical_sheet_names,
      grepl,
      x = pipeline_text,
      fixed = TRUE,
      FUN.VALUE = logical(1)
    )) &&
      !any(vapply(
        obsolete_sheet_names,
        grepl,
        x = pipeline_text,
        fixed = TRUE,
        FUN.VALUE = logical(1)
      )),
    paste(technical_sheet_names, collapse = " | ")
  )

  cli_text <- read_utf8(file.path(project_root, "cancerppir.R"))
  cli_tokens <- c(
    "Too many arguments.",
    "score_threshold must be an integer from 1 to 1000.",
    "top_n must be a positive integer.",
    "run_enrichment must be TRUE or FALSE."
  )

  add_check(
    "cli_validation_is_strict",
    all(vapply(
      cli_tokens,
      grepl,
      x = cli_text,
      fixed = TRUE,
      FUN.VALUE = logical(1)
    )) &&
      !grepl("are ignored", cli_text, fixed = TRUE),
    paste(cli_tokens, collapse = " | ")
  )

  release_script_text <- read_utf8(file.path(
    project_root,
    "scripts/run_release_checkpoint.R"
  ))

  release_tokens <- c(
    "release_summary.csv",
    "release_case_summary.csv",
    "release_validation.csv",
    "release_preflight_validation.csv",
    "release_unit_tests.log",
    "release_multicase.log",
    "CANCERPPIR RELEASE PREFLIGHT: FAILED",
    "CANCERPPIR RELEASE CHECKPOINT",
    "CANCERPPIR RELEASE CHECKPOINT: PASSED",
    "validate_publication_readiness.R",
    'section = "publication"'
  )

  add_check(
    "release_checkpoint_uses_publication_gate_and_semantic_names",
    all(vapply(
      release_tokens,
      grepl,
      x = release_script_text,
      fixed = TRUE,
      FUN.VALUE = logical(1)
    )) &&
      !grepl(
        "PHASE 4 RELEASE PREFLIGHT",
        release_script_text,
        fixed = TRUE
      ) &&
      !grepl(
        "PHASE 4 RELEASE CHECKPOINT",
        release_script_text,
        fixed = TRUE
      ),
    paste(release_tokens, collapse = " | ")
  )

  public_documents <- unique(c(
    file.path(
      project_root,
      c(
        "README.md",
        "CHANGELOG.md",
        "CONTRIBUTING.md",
        "SECURITY.md",
        "CITATION.cff",
        "docs/README.md",
        "docs/development/release-process.md",
        "docs/development/repository-governance.md",
        "docs/development/publication-readiness-checklist.md",
        "docs/development/release-notes-v1.0.0-rc.1.md"
      )
    ),
    list.files(
      file.path(project_root, "docs", "user-guide"),
      pattern = "\\.md$",
      recursive = TRUE,
      full.names = TRUE
    ),
    list.files(
      file.path(project_root, "docs", "reference"),
      pattern = "\\.md$",
      recursive = TRUE,
      full.names = TRUE
    )
  ))

  public_text <- vapply(
    public_documents[file.exists(public_documents)],
    read_utf8,
    FUN.VALUE = character(1)
  )
  names(public_text) <- vapply(
    public_documents[file.exists(public_documents)],
    rel,
    FUN.VALUE = character(1)
  )

  roadmap_patterns <- c(
    paste0("Phase", " 4"),
    paste0("Phase", "4"),
    paste0("PHASE", " 4"),
    paste0("phase", "4_"),
    paste0("phase", "4-")
  )

  roadmap_hits <- character()

  for (path in names(public_text)) {
    hits <- roadmap_patterns[vapply(
      roadmap_patterns,
      grepl,
      x = public_text[[path]],
      fixed = TRUE,
      FUN.VALUE = logical(1)
    )]

    if (length(hits) > 0L) {
      roadmap_hits <- c(
        roadmap_hits,
        paste0(path, ": ", paste(hits, collapse = ", "))
      )
    }
  }

  add_check(
    "public_documents_have_no_roadmap_labels",
    length(roadmap_hits) == 0L,
    roadmap_hits
  )

  obsolete_schema_versions <- vapply(
    4:7,
    function(minor) paste(4, minor, 0, sep = "."),
    FUN.VALUE = character(1)
  )

  obsolete_schema_hits <- character()

  for (path in names(public_text)) {
    hits <- obsolete_schema_versions[vapply(
      obsolete_schema_versions,
      grepl,
      x = public_text[[path]],
      fixed = TRUE,
      FUN.VALUE = logical(1)
    )]

    if (length(hits) > 0L) {
      obsolete_schema_hits <- c(
        obsolete_schema_hits,
        paste0(path, ": ", paste(hits, collapse = ", "))
      )
    }
  }

  add_check(
    "public_documents_have_no_development_schema_versions",
    length(obsolete_schema_hits) == 0L,
    obsolete_schema_hits
  )

  release_process_text <- read_utf8(file.path(
    project_root,
    "docs/development/release-process.md"
  ))
  order_terms <- c(
    "Run the complete seven-case release checkpoint",
    "Perform clean-clone qualification",
    "Create an annotated"
  )
  order_positions <- vapply(
    order_terms,
    function(term) {
      position <- regexpr(
        term,
        release_process_text,
        fixed = TRUE
      )[[1L]]
      if (position < 0L) Inf else position
    },
    FUN.VALUE = numeric(1)
  )

  add_check(
    "release_qualification_precedes_tagging",
    all(is.finite(order_positions)) &&
      order_positions[[1L]] < order_positions[[2L]] &&
      order_positions[[2L]] < order_positions[[3L]],
    paste(order_terms, order_positions, sep = "@", collapse = " | ")
  )

  security_text <- read_utf8(file.path(project_root, "SECURITY.md"))

  add_check(
    "security_reporting_channel_is_explicit",
    grepl(
      "Private vulnerability reporting",
      security_text,
      fixed = TRUE
    ),
    "Expected GitHub Private vulnerability reporting."
  )

  production_files <- unique(c(
    list.files(
      file.path(project_root, "R"),
      pattern = "\\.R$",
      recursive = TRUE,
      full.names = TRUE
    ),
    file.path(project_root, "cancerppir.R")
  ))

  personal_patterns <- c(
    paste0("C:/", "Users/"),
    paste0("C:", "\\", "Users", "\\"),
    paste0("One", "Drive"),
    paste0("Рабочий", " стол")
  )

  personal_hits <- character()

  for (path in production_files[file.exists(production_files)]) {
    text <- read_utf8(path)
    hits <- personal_patterns[vapply(
      personal_patterns,
      grepl,
      x = text,
      fixed = TRUE,
      FUN.VALUE = logical(1)
    )]

    if (length(hits) > 0L) {
      personal_hits <- c(
        personal_hits,
        paste0(rel(path), ": ", paste(hits, collapse = ", "))
      )
    }
  }

  add_check(
    "production_has_no_personal_absolute_paths",
    length(personal_hits) == 0L,
    personal_hits
  )

  whitespace_files <- unique(c(
    production_files,
    file.path(project_root, "scripts/run_release_checkpoint.R"),
    public_documents
  ))

  whitespace_hits <- character()

  for (path in whitespace_files[file.exists(whitespace_files)]) {
    lines <- readLines(path, warn = FALSE, encoding = "UTF-8")
    hit_lines <- which(grepl("[ \t]+$", lines, perl = TRUE))

    if (length(hit_lines) > 0L) {
      whitespace_hits <- c(
        whitespace_hits,
        paste0(rel(path), ":", paste(hit_lines, collapse = ","))
      )
    }
  }

  add_check(
    "public_and_production_text_has_no_trailing_whitespace",
    length(whitespace_hits) == 0L,
    whitespace_hits
  )

  license_text <- read_utf8(file.path(project_root, "LICENSE"))

  add_check(
    "mit_license_is_present",
    grepl("MIT License", license_text, fixed = TRUE) &&
      grepl("Copyright", license_text, fixed = TRUE),
    "LICENSE"
  )

  if (isTRUE(include_git_diff_check) && nzchar(git_command)) {
    diff_output <- suppressWarnings(
      system2(
        git_command,
        args = c(
          "-C",
          shQuote(project_root),
          "diff",
          "--check"
        ),
        stdout = TRUE,
        stderr = TRUE
      )
    )
    diff_status <- attr(diff_output, "status")
    if (is.null(diff_status)) diff_status <- 0L

    add_check(
      "git_diff_check_passes",
      identical(as.integer(diff_status), 0L),
      diff_output
    )
  }

  output <- do.call(rbind, checks)
  rownames(output) <- NULL
  output
}

if (sys.nframe() == 0L) {
  validation <- cancerppir_validate_publication_readiness()
  print(validation, row.names = FALSE)

  if (any(validation$status == "FAIL")) {
    quit(save = "no", status = 1L)
  }

  cat("\nCANCERPPIR PUBLICATION READINESS: PASSED\n")
}
