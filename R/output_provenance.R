# CancerPPIr: output provenance, schema registry and checksums
#
# Responsibility:
# Create a privacy-safe, machine-readable record of each successful run and
# verify that the principal output files have not changed after generation.
#
# The JSON manifest contains checksums for the principal analysis outputs.
# The separate SHA-256 file contains checksums for those outputs plus the JSON
# manifest itself. The checksum file deliberately does not contain its own hash.

CANCERPPIR_TECHNICAL_WORKBOOK_SCHEMA_VERSION <- "4.4.0"
CANCERPPIR_OUTPUT_MANIFEST_SCHEMA_VERSION <- "1.0.0"
CANCERPPIR_OUTPUT_CHECKSUMS_SCHEMA_VERSION <- "1.0.0"

cancerppir_schema_versions <- function() {
  list(
    pipeline_result = CANCERPPIR_PIPELINE_RESULT_SCHEMA_VERSION,
    biological_evidence = CANCERPPIR_BIOLOGICAL_EVIDENCE_SCHEMA_VERSION,
    analytical_workbook = CANCERPPIR_ANALYTICAL_SCHEMA_VERSION,
    technical_workbook = CANCERPPIR_TECHNICAL_WORKBOOK_SCHEMA_VERSION,
    graphml = CANCERPPIR_GRAPHML_SCHEMA_VERSION,
    output_manifest = CANCERPPIR_OUTPUT_MANIFEST_SCHEMA_VERSION,
    output_checksums = CANCERPPIR_OUTPUT_CHECKSUMS_SCHEMA_VERSION
  )
}

cancerppir_sha256_file <- function(path) {
  if (!requireNamespace("digest", quietly = TRUE)) {
    stop(
      "Package 'digest' is required to calculate SHA-256 checksums.",
      call. = FALSE
    )
  }

  if (!file.exists(path)) {
    stop(
      "Cannot calculate SHA-256 because the file does not exist: ",
      path,
      call. = FALSE
    )
  }

  tolower(
    digest::digest(
      object = path,
      algo = "sha256",
      file = TRUE,
      serialize = FALSE
    )
  )
}

cancerppir_package_versions <- function(
  packages = c(
    "R",
    "HGNChelper",
    "STRINGdb",
    "igraph",
    "openxlsx",
    "dplyr",
    "tibble",
    "curl",
    "sna",
    "jsonlite",
    "digest"
  )
) {
  output <- lapply(
    packages,
    function(package_name) {
      if (identical(package_name, "R")) {
        return(as.character(getRversion()))
      }

      if (!requireNamespace(package_name, quietly = TRUE)) {
        return("not_installed")
      }

      as.character(
        utils::packageVersion(package_name)
      )
    }
  )

  names(output) <- packages
  output
}

cancerppir_git_value <- function(
  project_root,
  arguments
) {
  if (
    is.null(project_root) ||
      length(project_root) != 1L ||
      is.na(project_root) ||
      !nzchar(project_root) ||
      !dir.exists(project_root)
  ) {
    return(character())
  }

  output <- tryCatch(
    suppressWarnings(
      system2(
        command = "git",
        args = c(
          "-C",
          shQuote(project_root),
          arguments
        ),
        stdout = TRUE,
        stderr = FALSE
      )
    ),
    error = function(error) character()
  )

  output <- trimws(as.character(output))
  output[nzchar(output)]
}

cancerppir_git_metadata <- function(
  project_root = getOption(
    "cancerppir.project_root",
    default = ""
  )
) {
  project_root <- as.character(project_root)[1L]

  commit <- cancerppir_git_value(
    project_root,
    c("rev-parse", "HEAD")
  )

  branch <- cancerppir_git_value(
    project_root,
    c("branch", "--show-current")
  )

  status <- cancerppir_git_value(
    project_root,
    c("status", "--porcelain")
  )

  list(
    commit = if (length(commit) > 0L) commit[[1L]] else "unavailable",
    branch = if (length(branch) > 0L) branch[[1L]] else "unavailable",
    working_tree_clean = if (length(commit) > 0L) {
      length(status) == 0L
    } else {
      NA
    },
    metadata_source = if (length(commit) > 0L) {
      "git"
    } else {
      "unavailable"
    }
  )
}

cancerppir_named_file_metadata <- function(
  files,
  roles,
  schema_versions = NULL
) {
  file_keys <- names(files)
  files <- as.character(files)
  names(files) <- file_keys

  if (is.null(names(files)) || any(!nzchar(names(files)))) {
    stop(
      "Output files must be a named character vector.",
      call. = FALSE
    )
  }

  missing_files <- files[!file.exists(files)]

  if (length(missing_files) > 0L) {
    stop(
      paste0(
        "Cannot create output provenance because file(s) are missing: ",
        paste(basename(missing_files), collapse = ", "),
        "."
      ),
      call. = FALSE
    )
  }

  if (is.null(names(roles))) {
    names(roles) <- names(files)
  }

  if (is.null(schema_versions)) {
    schema_versions <- rep(NA_character_, length(files))
    names(schema_versions) <- names(files)
  }

  lapply(
    names(files),
    function(file_key) {
      path <- files[[file_key]]
      info <- file.info(path)

      list(
        file_key = file_key,
        file_name = basename(path),
        role = as.character(roles[[file_key]]),
        schema_version = as.character(schema_versions[[file_key]]),
        size_bytes = unname(as.numeric(info$size)),
        sha256 = cancerppir_sha256_file(path)
      )
    }
  ) |>
    stats::setNames(
      vapply(
        files,
        basename,
        FUN.VALUE = character(1)
      )
    )
}


cancerppir_cache_resource_summary <- function(cache_dir) {
  string_manifest <- cancerppir_stringdb_cache_manifest(
    cache_dir = cache_dir,
    species = 9606L,
    version = "12.0",
    network_type = "full",
    link_data = "combined_only"
  )

  string_resources <- lapply(
    seq_len(nrow(string_manifest)),
    function(row_index) {
      list(
        role = as.character(
          string_manifest$cache_role[[row_index]]
        ),
        file_name = as.character(
          string_manifest$filename[[row_index]]
        ),
        exists = isTRUE(
          string_manifest$exists[[row_index]]
        ),
        size_bytes = unname(
          as.numeric(
            string_manifest$size_bytes[[row_index]]
          )
        )
      )
    }
  )

  names(string_resources) <- as.character(
    string_manifest$cache_role
  )

  enrichment_path <- find_string_enrichment_terms(
    cache_dir
  )

  enrichment_resource <- if (
    length(enrichment_path) == 1L &&
      !is.na(enrichment_path) &&
      file.exists(enrichment_path)
  ) {
    list(
      file_name = basename(enrichment_path),
      exists = TRUE,
      size_bytes = unname(
        as.numeric(
          file.info(enrichment_path)$size
        )
      )
    )
  } else {
    list(
      file_name = "not_available",
      exists = FALSE,
      size_bytes = NA_real_
    )
  }

  list(
    STRINGdb_resources = string_resources,
    enrichment_terms_resource = enrichment_resource,
    cache_checksums_calculated = FALSE,
    cache_checksum_policy = paste(
      "Standard runs record cache basenames and sizes but do not re-read",
      "multi-gigabyte STRING resources solely to hash them."
    )
  )
}

cancerppir_build_output_manifest <- function(
  input_file,
  output_files,
  output_roles,
  output_schema_versions,
  input_summary,
  analysis_configuration,
  run_summary,
  project_root = getOption(
    "cancerppir.project_root",
    default = ""
  )
) {
  if (!file.exists(input_file)) {
    stop(
      "Input file does not exist: ",
      input_file,
      call. = FALSE
    )
  }

  input_info <- file.info(input_file)
  git_metadata <- cancerppir_git_metadata(project_root)

  list(
    manifest_schema_version =
      CANCERPPIR_OUTPUT_MANIFEST_SCHEMA_VERSION,
    generated_at_utc = format(
      as.POSIXct(Sys.time(), tz = "UTC"),
      "%Y-%m-%dT%H:%M:%SZ",
      tz = "UTC"
    ),
    software = list(
      name = "CancerPPIr",
      git_commit = git_metadata$commit,
      git_branch = git_metadata$branch,
      working_tree_clean = git_metadata$working_tree_clean,
      git_metadata_source = git_metadata$metadata_source
    ),
    runtime = list(
      r_version = as.character(getRversion()),
      platform = R.version$platform,
      operating_system = Sys.info()[["sysname"]],
      package_versions = cancerppir_package_versions()
    ),
    schemas = cancerppir_schema_versions(),
    input = c(
      list(
        file_name = basename(input_file),
        size_bytes = unname(as.numeric(input_info$size)),
        sha256 = cancerppir_sha256_file(input_file)
      ),
      input_summary
    ),
    analysis = analysis_configuration,
    summary = run_summary,
    outputs = cancerppir_named_file_metadata(
      files = output_files,
      roles = output_roles,
      schema_versions = output_schema_versions
    ),
    privacy = list(
      absolute_paths_in_manifest = FALSE,
      path_policy = paste(
        "Only basenames and non-path metadata are recorded;",
        "absolute input, cache, project and output paths are excluded."
      )
    )
  )
}

cancerppir_write_checksum_file <- function(
  files,
  path
) {
  file_keys <- names(files)
  files <- as.character(files)
  names(files) <- file_keys

  if (is.null(names(files)) || any(!nzchar(names(files)))) {
    stop(
      "Checksum inputs must be a named character vector.",
      call. = FALSE
    )
  }

  missing_files <- files[!file.exists(files)]

  if (length(missing_files) > 0L) {
    stop(
      paste0(
        "Cannot write checksum file because file(s) are missing: ",
        paste(basename(missing_files), collapse = ", "),
        "."
      ),
      call. = FALSE
    )
  }

  lines <- vapply(
    files,
    function(file_path) {
      paste0(
        cancerppir_sha256_file(file_path),
        "  ",
        basename(file_path)
      )
    },
    FUN.VALUE = character(1)
  )

  writeLines(
    lines,
    con = path,
    useBytes = TRUE
  )

  invisible(path)
}

cancerppir_parse_checksum_file <- function(path) {
  if (!file.exists(path)) {
    stop(
      "Checksum file does not exist: ",
      path,
      call. = FALSE
    )
  }

  lines <- readLines(
    path,
    warn = FALSE,
    encoding = "UTF-8"
  )

  lines <- trimws(lines)
  lines <- lines[nzchar(lines)]

  matches <- regexec(
    "^([0-9a-fA-F]{64})[[:space:]]{2}(.+)$",
    lines
  )

  parts <- regmatches(lines, matches)

  valid <- lengths(parts) == 3L

  if (!all(valid)) {
    stop(
      "Checksum file contains one or more malformed lines.",
      call. = FALSE
    )
  }

  data.frame(
    sha256 = tolower(
      vapply(parts, `[[`, character(1), 2L)
    ),
    file_name = vapply(parts, `[[`, character(1), 3L),
    stringsAsFactors = FALSE
  )
}

cancerppir_validate_output_provenance <- function(
  manifest_file,
  checksums_file,
  output_dir,
  forbidden_paths = character()
) {
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

  manifest_exists <- file.exists(manifest_file)
  checksums_exists <- file.exists(checksums_file)

  add_check(
    "manifest_file_exists",
    manifest_exists,
    basename(manifest_file)
  )

  add_check(
    "checksums_file_exists",
    checksums_exists,
    basename(checksums_file)
  )

  manifest <- NULL
  checksum_table <- NULL

  if (manifest_exists) {
    manifest <- tryCatch(
      jsonlite::read_json(
        manifest_file,
        simplifyVector = FALSE
      ),
      error = function(error) error
    )
  }

  add_check(
    "manifest_json_is_readable",
    is.list(manifest) && !inherits(manifest, "error"),
    if (inherits(manifest, "error")) {
      conditionMessage(manifest)
    } else {
      "readable JSON"
    }
  )

  required_sections <- c(
    "manifest_schema_version",
    "generated_at_utc",
    "software",
    "runtime",
    "schemas",
    "input",
    "analysis",
    "summary",
    "outputs",
    "privacy"
  )

  sections_present <- is.list(manifest) &&
    all(required_sections %in% names(manifest))

  add_check(
    "required_manifest_sections_present",
    sections_present,
    if (is.list(manifest)) {
      paste(
        setdiff(required_sections, names(manifest)),
        collapse = "; "
      )
    } else {
      "manifest unavailable"
    }
  )

  schema_versions_valid <- FALSE

  if (sections_present) {
    observed_versions <- unlist(
      manifest$schemas,
      use.names = TRUE
    )

    expected_versions <- unlist(
      cancerppir_schema_versions(),
      use.names = TRUE
    )

    schema_versions_valid <- identical(
      observed_versions[names(expected_versions)],
      expected_versions
    ) &&
      identical(
        as.character(manifest$manifest_schema_version),
        CANCERPPIR_OUTPUT_MANIFEST_SCHEMA_VERSION
      )
  }

  add_check(
    "schema_versions_are_pinned",
    schema_versions_valid,
    if (sections_present) {
      paste(
        unlist(manifest$schemas),
        collapse = " | "
      )
    } else {
      "manifest unavailable"
    }
  )

  output_entries_valid <- FALSE
  manifest_output_files <- character()

  if (sections_present && is.list(manifest$outputs)) {
    manifest_output_files <- names(manifest$outputs)

    output_entries_valid <- length(manifest_output_files) > 0L &&
      all(
        vapply(
          manifest$outputs,
          function(entry) {
            is.list(entry) &&
              all(
                c(
                  "file_key",
                  "file_name",
                  "role",
                  "schema_version",
                  "size_bytes",
                  "sha256"
                ) %in% names(entry)
              ) &&
              grepl(
                "^[0-9a-f]{64}$",
                as.character(entry$sha256)
              )
          },
          FUN.VALUE = logical(1)
        )
      )
  }

  add_check(
    "manifest_output_entries_are_complete",
    output_entries_valid,
    paste(manifest_output_files, collapse = " | ")
  )

  manifest_hashes_match <- FALSE
  missing_manifest_outputs <- character()
  mismatched_manifest_outputs <- character()

  if (output_entries_valid) {
    missing_manifest_outputs <- manifest_output_files[
      !file.exists(
        file.path(output_dir, manifest_output_files)
      )
    ]

    if (length(missing_manifest_outputs) == 0L) {
      mismatched_manifest_outputs <- manifest_output_files[
        !vapply(
          manifest_output_files,
          function(file_name) {
            identical(
              cancerppir_sha256_file(
                file.path(output_dir, file_name)
              ),
              tolower(
                as.character(
                  manifest$outputs[[file_name]]$sha256
                )
              )
            )
          },
          FUN.VALUE = logical(1)
        )
      ]

      manifest_hashes_match <-
        length(mismatched_manifest_outputs) == 0L
    }
  }

  add_check(
    "manifest_output_hashes_match_files",
    manifest_hashes_match,
    paste(
      c(
        paste0("missing:", missing_manifest_outputs),
        paste0("mismatch:", mismatched_manifest_outputs)
      ),
      collapse = "; "
    )
  )

  if (checksums_exists) {
    checksum_table <- tryCatch(
      cancerppir_parse_checksum_file(checksums_file),
      error = function(error) error
    )
  }

  add_check(
    "checksums_file_is_readable",
    is.data.frame(checksum_table),
    if (inherits(checksum_table, "error")) {
      conditionMessage(checksum_table)
    } else {
      "readable SHA-256 list"
    }
  )

  expected_checksum_files <- c(
    manifest_output_files,
    basename(manifest_file)
  )

  checksum_file_set_valid <- is.data.frame(checksum_table) &&
    identical(
      sort(checksum_table$file_name),
      sort(expected_checksum_files)
    ) &&
    !basename(checksums_file) %in% checksum_table$file_name

  add_check(
    "checksum_file_lists_outputs_and_manifest_only",
    checksum_file_set_valid,
    if (is.data.frame(checksum_table)) {
      paste(checksum_table$file_name, collapse = " | ")
    } else {
      "checksum table unavailable"
    }
  )

  checksum_hashes_match <- FALSE
  checksum_mismatches <- character()

  if (checksum_file_set_valid) {
    checksum_mismatches <- checksum_table$file_name[
      !vapply(
        seq_len(nrow(checksum_table)),
        function(row_index) {
          file_name <- checksum_table$file_name[[row_index]]
          identical(
            cancerppir_sha256_file(
              file.path(output_dir, file_name)
            ),
            checksum_table$sha256[[row_index]]
          )
        },
        FUN.VALUE = logical(1)
      )
    ]

    checksum_hashes_match <- length(checksum_mismatches) == 0L
  }

  add_check(
    "checksum_hashes_match_files",
    checksum_hashes_match,
    paste(checksum_mismatches, collapse = "; ")
  )

  forbidden_paths <- unique(
    as.character(forbidden_paths)
  )

  forbidden_paths <- forbidden_paths[
    !is.na(forbidden_paths) & nzchar(forbidden_paths)
  ]

  manifest_text <- if (manifest_exists) {
    paste(
      readLines(
        manifest_file,
        warn = FALSE,
        encoding = "UTF-8"
      ),
      collapse = "\n"
    )
  } else {
    ""
  }

  path_variants <- unique(
    c(
      forbidden_paths,
      gsub("\\\\", "/", forbidden_paths),
      gsub("/", "\\\\", forbidden_paths)
    )
  )

  path_variants <- path_variants[nzchar(path_variants)]

  leaked_paths <- path_variants[
    vapply(
      path_variants,
      function(path_value) {
        grepl(
          path_value,
          manifest_text,
          fixed = TRUE
        )
      },
      FUN.VALUE = logical(1)
    )
  ]

  windows_path_prefixes <- c(
    paste0(LETTERS, ":/"),
    paste0(LETTERS, ":", intToUtf8(92L)),
    paste0(
      LETTERS,
      ":",
      intToUtf8(92L),
      intToUtf8(92L)
    )
  )

  unix_path_prefixes <- c(
    "/Users/",
    "/home/",
    "/mnt/",
    "/var/",
    "/tmp/"
  )

  generic_absolute_path_detected <- any(
    vapply(
      c(windows_path_prefixes, unix_path_prefixes),
      function(path_prefix) {
        grepl(
          path_prefix,
          manifest_text,
          fixed = TRUE
        )
      },
      FUN.VALUE = logical(1)
    )
  )

  add_check(
    "absolute_user_paths_are_absent",
    length(leaked_paths) == 0L &&
      !generic_absolute_path_detected,
    paste(leaked_paths, collapse = "; ")
  )

  input_name_is_basename <- sections_present &&
    identical(
      as.character(manifest$input$file_name),
      basename(as.character(manifest$input$file_name))
    )

  add_check(
    "input_file_name_is_path_free",
    input_name_is_basename,
    if (sections_present) {
      as.character(manifest$input$file_name)
    } else {
      "manifest unavailable"
    }
  )

  validation <- do.call(rbind, checks)
  rownames(validation) <- NULL
  validation
}

cancerppir_write_output_provenance <- function(
  input_file,
  output_dir,
  output_files,
  output_roles,
  output_schema_versions,
  input_summary,
  analysis_configuration,
  run_summary,
  project_root = getOption(
    "cancerppir.project_root",
    default = ""
  ),
  forbidden_paths = character()
) {
  if (!requireNamespace("jsonlite", quietly = TRUE)) {
    stop(
      "Package 'jsonlite' is required to write the output manifest.",
      call. = FALSE
    )
  }

  manifest_file <- file.path(
    output_dir,
    "CancerPPIr_Output_Manifest.json"
  )

  checksums_file <- file.path(
    output_dir,
    "CancerPPIr_Output_Checksums.sha256"
  )

  manifest <- cancerppir_build_output_manifest(
    input_file = input_file,
    output_files = output_files,
    output_roles = output_roles,
    output_schema_versions = output_schema_versions,
    input_summary = input_summary,
    analysis_configuration = analysis_configuration,
    run_summary = run_summary,
    project_root = project_root
  )

  jsonlite::write_json(
    manifest,
    path = manifest_file,
    pretty = TRUE,
    auto_unbox = TRUE,
    null = "null",
    na = "null",
    digits = NA
  )

  checksum_inputs <- c(
    output_files,
    output_manifest = manifest_file
  )

  cancerppir_write_checksum_file(
    files = checksum_inputs,
    path = checksums_file
  )

  validation <- cancerppir_validate_output_provenance(
    manifest_file = manifest_file,
    checksums_file = checksums_file,
    output_dir = output_dir,
    forbidden_paths = unique(
      c(
        forbidden_paths,
        dirname(input_file),
        output_dir,
        project_root
      )
    )
  )

  failures <- validation[
    validation$status == "FAIL",
    ,
    drop = FALSE
  ]

  if (nrow(failures) > 0L) {
    stop(
      paste0(
        "Output provenance validation failed: ",
        paste(failures$check_id, collapse = ", "),
        "."
      ),
      call. = FALSE
    )
  }

  list(
    schema_version = CANCERPPIR_OUTPUT_MANIFEST_SCHEMA_VERSION,
    manifest = manifest,
    manifest_file = manifest_file,
    checksums_file = checksums_file,
    validation = validation
  )
}
