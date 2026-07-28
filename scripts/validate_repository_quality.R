# Repository-quality validator for CancerPPIr.
#
# This gate is release-version agnostic. Release-specific scientific and
# publication checks remain in validate_publication_readiness.R.

cancerppir_validate_repository_quality <- function(
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

  read_utf8 <- function(path) {
    paste(
      readLines(path, warn = FALSE, encoding = "UTF-8"),
      collapse = "\n"
    )
  }

  relative_path <- function(path) {
    normalized <- normalizePath(
      path,
      winslash = "/",
      mustWork = FALSE
    )
    prefix <- paste0(project_root, "/")
    if (startsWith(normalized, prefix)) {
      substring(normalized, nchar(prefix) + 1L)
    } else {
      basename(normalized)
    }
  }

  run_git <- function(arguments) {
    output <- system2(
      "git",
      arguments,
      stdout = TRUE,
      stderr = TRUE
    )
    list(
      output = output,
      status = attr(output, "status") %||% 0L
    )
  }

  `%||%` <- function(value, fallback) {
    if (is.null(value) || length(value) == 0L) {
      fallback
    } else {
      value
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
    "renv.lock",
    ".gitattributes",
    ".github/workflows/r-tests.yml",
    ".github/dependabot.yml",
    ".github/CODEOWNERS",
    ".github/pull_request_template.md",
    "scripts/validate_repository_quality.R",
    "scripts/validate_publication_readiness.R"
  )

  missing_files <- required_files[
    !file.exists(file.path(project_root, required_files))
  ]

  add_check(
    "required_repository_files_exist",
    length(missing_files) == 0L,
    missing_files
  )

  version_path <- file.path(project_root, "VERSION")
  citation_path <- file.path(project_root, "CITATION.cff")
  changelog_path <- file.path(project_root, "CHANGELOG.md")

  version <- if (file.exists(version_path)) {
    trimws(read_utf8(version_path))
  } else {
    ""
  }

  semver_valid <- grepl(
    "^[0-9]+\\.[0-9]+\\.[0-9]+(?:-[0-9A-Za-z.-]+)?$",
    version,
    perl = TRUE
  )

  citation_text <- if (file.exists(citation_path)) {
    read_utf8(citation_path)
  } else {
    ""
  }

  changelog_text <- if (file.exists(changelog_path)) {
    read_utf8(changelog_path)
  } else {
    ""
  }

  citation_version_valid <- semver_valid &&
    grepl(
      paste0('version: "', version, '"'),
      citation_text,
      fixed = TRUE
    )

  changelog_version_valid <- semver_valid &&
    grepl(
      paste0("## [", version, "]"),
      changelog_text,
      fixed = TRUE
    )

  add_check(
    "release_metadata_versions_are_consistent",
    semver_valid &&
      citation_version_valid &&
      changelog_version_valid,
    c(
      paste0("VERSION=", version),
      paste0("citation=", citation_version_valid),
      paste0("changelog=", changelog_version_valid)
    )
  )

  tracked_result <- run_git(c("ls-files"))
  tracked_files <- tracked_result$output

  add_check(
    "tracked_file_inventory_is_available",
    identical(tracked_result$status, 0L),
    tracked_result$output
  )

  r_files <- tracked_files[
    grepl("\\.R$", tracked_files, ignore.case = FALSE)
  ]

  parse_failures <- character()

  for (path in r_files) {
    absolute_path <- file.path(project_root, path)
    if (!file.exists(absolute_path)) {
      next
    }

    tryCatch(
      parse(file = absolute_path, keep.source = FALSE),
      error = function(error) {
        parse_failures <<- c(
          parse_failures,
          paste0(path, ": ", conditionMessage(error))
        )
      }
    )
  }

  add_check(
    "tracked_r_files_parse",
    length(parse_failures) == 0L,
    parse_failures
  )

  workflow_files <- tracked_files[
    grepl(
      "^\\.github/workflows/.*\\.(yml|yaml)$",
      tracked_files,
      ignore.case = TRUE
    )
  ]

  action_reference_failures <- character()
  forbidden_trigger_failures <- character()

  for (workflow in workflow_files) {
    workflow_path <- file.path(project_root, workflow)
    lines <- readLines(
      workflow_path,
      warn = FALSE,
      encoding = "UTF-8"
    )

    uses_lines <- grep(
      "^[[:space:]]*uses:[[:space:]]*",
      lines,
      value = TRUE
    )

    for (line in uses_lines) {
      reference <- sub(
        "^[[:space:]]*uses:[[:space:]]*",
        "",
        line
      )
      reference <- sub("[[:space:]]+#.*$", "", reference)
      reference <- trimws(reference)

      if (startsWith(reference, "./")) {
        next
      }

      pieces <- strsplit(reference, "@", fixed = TRUE)[[1L]]
      pinned <- length(pieces) >= 2L &&
        grepl("^[0-9a-fA-F]{40}$", tail(pieces, 1L))

      if (!pinned) {
        action_reference_failures <- c(
          action_reference_failures,
          paste0(workflow, ": ", trimws(line))
        )
      }
    }

    workflow_text <- paste(lines, collapse = "\n")

    if (grepl("pull_request_target", workflow_text, fixed = TRUE)) {
      forbidden_trigger_failures <- c(
        forbidden_trigger_failures,
        paste0(workflow, ": pull_request_target")
      )
    }
  }

  add_check(
    "third_party_actions_are_sha_pinned",
    length(action_reference_failures) == 0L,
    action_reference_failures
  )

  add_check(
    "unsafe_workflow_triggers_are_absent",
    length(forbidden_trigger_failures) == 0L,
    forbidden_trigger_failures
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

  workflow_hardening_tokens <- c(
    "permissions:",
    "contents: read",
    "concurrency:",
    "cancel-in-progress: true",
    "persist-credentials: false",
    "timeout-minutes:",
    "Repository quality",
    "Unit and CLI tests"
  )

  missing_workflow_tokens <- workflow_hardening_tokens[
    !vapply(
      workflow_hardening_tokens,
      grepl,
      x = workflow_text,
      fixed = TRUE,
      FUN.VALUE = logical(1)
    )
  ]

  add_check(
    "workflow_hardening_controls_are_present",
    length(missing_workflow_tokens) == 0L,
    missing_workflow_tokens
  )

  text_extensions <- c(
    "R", "md", "yml", "yaml", "cff", "txt", "csv",
    "tsv", "json", "lock"
  )

  candidate_text_files <- tracked_files[
    vapply(
      tracked_files,
      function(path) {
        extension <- tools::file_ext(path)
        extension %in% text_extensions ||
          basename(path) %in% c(
            "VERSION",
            "LICENSE",
            ".Rprofile",
            ".gitignore",
            ".gitattributes"
          )
      },
      FUN.VALUE = logical(1)
    )
  ]

  path_user_component <- "[A-Za-z0-9._-]+"

  personal_path_patterns <- c(
    paste0(
      "[A-Za-z]:[/\\\\]Users[/\\\\]",
      path_user_component,
      "([/\\\\]|$)"
    ),
    paste0(
      "/Users/",
      path_user_component,
      "(/|$)"
    ),
    paste0(
      "/home/",
      path_user_component,
      "(/|$)"
    ),
    "(OneDrive|Рабочий стол)[/\\\\]",
    "LAPTOP-[A-Za-z0-9-]+"
  )

  personal_path_hits <- character()

  secret_pattern <- paste(
    c(
      "gh[pousr]_[A-Za-z0-9_]{20,}",
      "github_pat_[A-Za-z0-9_]{20,}",
      "AKIA[0-9A-Z]{16}",
      "-----BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY-----"
    ),
    collapse = "|"
  )

  secret_hits <- character()

  for (path in candidate_text_files) {
    absolute_path <- file.path(project_root, path)
    if (!file.exists(absolute_path)) {
      next
    }

    text <- read_utf8(absolute_path)

    matched_path_patterns <- personal_path_patterns[
      vapply(
        personal_path_patterns,
        function(pattern) {
          grepl(
            pattern,
            text,
            perl = TRUE,
            ignore.case = TRUE
          )
        },
        FUN.VALUE = logical(1)
      )
    ]

    if (length(matched_path_patterns) > 0L) {
      personal_path_hits <- c(
        personal_path_hits,
        paste0(
          path,
          ": ",
          paste(matched_path_patterns, collapse = " | ")
        )
      )
    }

    if (grepl(secret_pattern, text, perl = TRUE)) {
      secret_hits <- c(secret_hits, path)
    }
  }

  add_check(
    "tracked_text_has_no_personal_absolute_paths",
    length(personal_path_hits) == 0L,
    personal_path_hits
  )

  add_check(
    "tracked_text_has_no_high_confidence_secret_patterns",
    length(secret_hits) == 0L,
    secret_hits
  )

  forbidden_binary_patterns <- c(
    "\\.RData$",
    "\\.rda$",
    "\\.rds$",
    "\\.xlsx$",
    "\\.xls$"
  )

  forbidden_binary_files <- tracked_files[
    vapply(
      tracked_files,
      function(path) {
        any(vapply(
          forbidden_binary_patterns,
          grepl,
          x = path,
          ignore.case = TRUE,
          FUN.VALUE = logical(1)
        ))
      },
      FUN.VALUE = logical(1)
    )
  ]

  add_check(
    "generated_binary_outputs_are_not_tracked",
    length(forbidden_binary_files) == 0L,
    forbidden_binary_files
  )

  diff_result <- run_git(c("diff", "--check"))

  add_check(
    "git_diff_check_passes",
    identical(diff_result$status, 0L),
    diff_result$output
  )

  results <- do.call(rbind, checks)
  rownames(results) <- NULL
  results
}

if (sys.nframe() == 0L) {
  results <- cancerppir_validate_repository_quality()
  print(results, row.names = FALSE)

  if (any(results$status != "PASS")) {
    cat("\nCANCERPPIR REPOSITORY QUALITY: FAILED\n")
    quit(status = 1L)
  }

  cat("\nCANCERPPIR REPOSITORY QUALITY: PASSED\n")
}
