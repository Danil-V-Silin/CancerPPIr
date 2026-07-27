#!/usr/bin/env Rscript
# Audit workbook duplication without modifying output files.
#
# Severity semantics:
# - FAIL: structural duplication that is invalid independently of patient data
#   (duplicate column names or identical sheets inside one workbook).
# - REVIEW: exact value equality that can be case-specific and requires human
#   interpretation, duplicate rows, or identical sheets across workbooks.
# - INFO: expected equivalence between documented provenance/stage fields or
#   equality caused only by both columns being empty.

cancerppir_empty_audit_report <- function() {
  data.frame(
    workbook = character(),
    sheet = character(),
    finding_type = character(),
    severity = character(),
    left_column = character(),
    right_column = character(),
    details = character(),
    stringsAsFactors = FALSE
  )
}

cancerppir_pair_key <- function(left, right) {
  paste(
    sort(c(as.character(left), as.character(right))),
    collapse = "||"
  )
}

cancerppir_expected_equivalent_column_pairs <- function() {
  pairs <- list(
    c("community_louvain", "module_id"),
    c("gene", "input_gene"),
    c("original_gene", "suggested_symbol"),
    c("mapped_initially", "final_in_network"),
    c("network_node_count", "module_size"),
    c("module_direction", "clean_module_label"),
    c("module_direction", "marker_clean_label"),
    c("clean_module_label", "marker_clean_label"),
    c("final_label_raw", "specific_label_candidate_raw"),
    c("specific_label_candidate", "final_functional_label"),
    c("specific_label_candidate", "putative_biological_program"),
    c("final_functional_label", "putative_biological_program"),
    c("major_module_rank", "module_rank"),
    c("standard_eligible", "eligible")
  )

  stats::setNames(
    c(
      "same Louvain identifier represented at pipeline and evidence boundaries",
      "input symbol is unchanged after normalization",
      "HGNC helper retained the submitted symbol",
      "no alias-only mapping changed final network membership",
      "both fields count nodes in the same Louvain module",
      "cleaned and selected module label agree",
      "marker-derived and selected module label agree",
      "marker-derived and cleaned module label agree",
      "raw rulebook label is unchanged after raw-stage selection",
      "specific candidate is retained as the final functional label",
      "specific candidate is retained as the putative program",
      "final functional label is exported as the putative program",
      "major-module rank retains the parent module rank",
      "standard eligibility is retained as final eligibility"
    ),
    vapply(
      pairs,
      function(pair) {
        cancerppir_pair_key(pair[[1L]], pair[[2L]])
      },
      FUN.VALUE = character(1)
    )
  )
}

cancerppir_column_values <- function(column) {
  if (is.list(column)) {
    values <- vapply(
      column,
      function(value) {
        paste(as.character(value), collapse = ";")
      },
      FUN.VALUE = character(1)
    )
  } else {
    values <- as.character(column)
  }

  values[is.na(values)] <- "<NA>"
  values
}

cancerppir_column_is_empty <- function(column) {
  if (is.list(column)) {
    values <- vapply(
      column,
      function(value) {
        paste(as.character(value), collapse = ";")
      },
      FUN.VALUE = character(1)
    )
  } else {
    values <- as.character(column)
  }

  all(
    is.na(values) |
      !nzchar(trimws(values))
  )
}

cancerppir_normalize_table <- function(data) {
  data <- as.data.frame(
    data,
    stringsAsFactors = FALSE,
    check.names = FALSE
  )

  data[] <- lapply(
    data,
    cancerppir_column_values
  )

  list(
    columns = names(data),
    rows = unname(as.matrix(data))
  )
}

cancerppir_classify_equivalent_columns <- function(
  left_name,
  right_name,
  left_values,
  right_values
) {
  if (
    cancerppir_column_is_empty(left_values) &&
      cancerppir_column_is_empty(right_values)
  ) {
    return(list(
      finding_type = "empty_columns",
      severity = "INFO",
      details = "Both columns contain only blank or missing values."
    ))
  }

  pair_key <- cancerppir_pair_key(
    left_name,
    right_name
  )
  expected_pairs <- cancerppir_expected_equivalent_column_pairs()

  if (pair_key %in% names(expected_pairs)) {
    return(list(
      finding_type = "expected_equivalent_columns",
      severity = "INFO",
      details = unname(expected_pairs[[pair_key]])
    ))
  }

  list(
    finding_type = "value_equivalent_columns",
    severity = "REVIEW",
    details = paste(
      "Distinct fields have identical values in this workbook.",
      "Their semantics must be reviewed before release."
    )
  )
}

cancerppir_add_audit_finding <- function(
  report,
  workbook,
  sheet,
  finding_type,
  severity,
  left_column = "",
  right_column = "",
  details = ""
) {
  rbind(
    report,
    data.frame(
      workbook = as.character(workbook),
      sheet = as.character(sheet),
      finding_type = as.character(finding_type),
      severity = as.character(severity),
      left_column = as.character(left_column),
      right_column = as.character(right_column),
      details = as.character(details),
      stringsAsFactors = FALSE
    )
  )
}

cancerppir_audit_table <- function(
  data,
  workbook = "",
  sheet = ""
) {
  data <- as.data.frame(
    data,
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  report <- cancerppir_empty_audit_report()

  duplicate_names <- unique(
    names(data)[duplicated(names(data))]
  )
  if (length(duplicate_names) > 0L) {
    for (duplicate_name in duplicate_names) {
      report <- cancerppir_add_audit_finding(
        report = report,
        workbook = workbook,
        sheet = sheet,
        finding_type = "duplicate_column_names",
        severity = "FAIL",
        left_column = duplicate_name,
        right_column = duplicate_name,
        details = paste0(
          "Column name occurs ",
          sum(names(data) == duplicate_name),
          " times."
        )
      )
    }
  }

  if (ncol(data) > 1L) {
    for (left in seq_len(ncol(data) - 1L)) {
      for (right in seq.int(left + 1L, ncol(data))) {
        left_name <- names(data)[[left]]
        right_name <- names(data)[[right]]

        if (identical(left_name, right_name)) {
          next
        }

        left_values <- cancerppir_column_values(
          data[[left]]
        )
        right_values <- cancerppir_column_values(
          data[[right]]
        )

        if (!identical(left_values, right_values)) {
          next
        }

        classification <-
          cancerppir_classify_equivalent_columns(
            left_name = left_name,
            right_name = right_name,
            left_values = data[[left]],
            right_values = data[[right]]
          )

        report <- cancerppir_add_audit_finding(
          report = report,
          workbook = workbook,
          sheet = sheet,
          finding_type = classification$finding_type,
          severity = classification$severity,
          left_column = left_name,
          right_column = right_name,
          details = classification$details
        )
      }
    }
  }

  normalized <- cancerppir_normalize_table(data)
  duplicate_rows <- if (nrow(data) > 0L) {
    sum(duplicated(normalized$rows))
  } else {
    0L
  }

  if (duplicate_rows > 0L) {
    report <- cancerppir_add_audit_finding(
      report = report,
      workbook = workbook,
      sheet = sheet,
      finding_type = "duplicate_rows",
      severity = "REVIEW",
      details = paste0(
        "exact_duplicate_rows=",
        duplicate_rows
      )
    )
  }

  report
}

cancerppir_audit_workbooks <- function(
  output_root,
  report_path = file.path(
    output_root,
    "workbook_duplication_audit.csv"
  )
) {
  if (!requireNamespace("openxlsx", quietly = TRUE)) {
    stop("Package 'openxlsx' is required.", call. = FALSE)
  }
  if (!requireNamespace("digest", quietly = TRUE)) {
    stop("Package 'digest' is required.", call. = FALSE)
  }

  output_root <- normalizePath(
    output_root,
    winslash = "/",
    mustWork = TRUE
  )

  workbooks <- list.files(
    output_root,
    pattern = "^CancerPPIr_(Analytical|Technical)_Report\\.xlsx$",
    recursive = TRUE,
    full.names = TRUE
  )
  if (length(workbooks) == 0L) {
    stop(
      "No CancerPPIr workbooks were found under: ",
      output_root,
      call. = FALSE
    )
  }

  report <- cancerppir_empty_audit_report()
  sheet_registry <- list()

  for (workbook in workbooks) {
    sheet_names <- openxlsx::getSheetNames(workbook)
    workbook_key <- normalizePath(
      workbook,
      winslash = "/",
      mustWork = TRUE
    )
    hashes <- character()

    for (sheet_name in sheet_names) {
      data <- openxlsx::read.xlsx(
        workbook,
        sheet = sheet_name,
        check.names = FALSE,
        detectDates = FALSE,
        skipEmptyRows = FALSE,
        skipEmptyCols = FALSE
      )

      table_report <- cancerppir_audit_table(
        data = data,
        workbook = workbook_key,
        sheet = sheet_name
      )
      if (nrow(table_report) > 0L) {
        report <- rbind(
          report,
          table_report
        )
      }

      normalized <- cancerppir_normalize_table(data)
      sheet_hash <- digest::digest(
        normalized,
        algo = "sha256",
        serialize = TRUE
      )
      hashes[[sheet_name]] <- sheet_hash

      sheet_registry[[length(sheet_registry) + 1L]] <-
        data.frame(
          workbook = workbook_key,
          sheet = sheet_name,
          hash = sheet_hash,
          stringsAsFactors = FALSE
        )
    }

    duplicate_hashes <- unique(
      hashes[duplicated(hashes)]
    )
    for (duplicate_hash in duplicate_hashes) {
      duplicate_sheets <- names(hashes)[
        hashes == duplicate_hash
      ]

      report <- cancerppir_add_audit_finding(
        report = report,
        workbook = workbook_key,
        sheet = paste(
          duplicate_sheets,
          collapse = " | "
        ),
        finding_type = "duplicate_sheets_within_workbook",
        severity = "FAIL",
        details = paste0(
          "sha256=",
          duplicate_hash
        )
      )
    }
  }

  registry <- do.call(
    rbind,
    sheet_registry
  )
  cross_groups <- split(
    registry,
    registry$hash
  )

  for (group in cross_groups) {
    if (nrow(group) < 2L) {
      next
    }
    if (length(unique(group$workbook)) < 2L) {
      next
    }

    report <- cancerppir_add_audit_finding(
      report = report,
      workbook = paste(
        unique(group$workbook),
        collapse = " | "
      ),
      sheet = paste(
        group$sheet,
        collapse = " | "
      ),
      finding_type = "identical_sheet_across_workbooks",
      severity = "REVIEW",
      details = paste0(
        "sha256=",
        unique(group$hash)
      )
    )
  }

  rownames(report) <- NULL

  dir.create(
    dirname(report_path),
    recursive = TRUE,
    showWarnings = FALSE
  )
  utils::write.csv(
    report,
    report_path,
    row.names = FALSE,
    na = ""
  )

  severity_counts <- table(
    factor(
      report$severity,
      levels = c("FAIL", "REVIEW", "INFO")
    )
  )

  cat(
    "Workbooks audited: ", length(workbooks), "\n",
    "Findings: ", nrow(report), "\n",
    "FAIL findings: ", severity_counts[["FAIL"]], "\n",
    "REVIEW findings: ", severity_counts[["REVIEW"]], "\n",
    "INFO findings: ", severity_counts[["INFO"]], "\n",
    "Report: ",
    normalizePath(
      report_path,
      winslash = "/",
      mustWork = TRUE
    ),
    "\n",
    sep = ""
  )

  invisible(
    list(
      report = report,
      workbooks = workbooks,
      report_path = report_path
    )
  )
}

cancerppir_workbook_audit_main <- function(
  arguments = commandArgs(trailingOnly = TRUE)
) {
  if (
    length(arguments) < 1L ||
      length(arguments) > 2L
  ) {
    stop(
      paste(
        "Usage:",
        paste(
          "  Rscript",
          "tools/audit/audit_workbook_duplication.R",
          "OUTPUT_ROOT [REPORT_CSV]"
        ),
        sep = "\n"
      ),
      call. = FALSE
    )
  }

  output_root <- normalizePath(
    arguments[[1L]],
    winslash = "/",
    mustWork = TRUE
  )
  report_path <- if (length(arguments) == 2L) {
    arguments[[2L]]
  } else {
    file.path(
      output_root,
      "workbook_duplication_audit.csv"
    )
  }

  result <- cancerppir_audit_workbooks(
    output_root = output_root,
    report_path = report_path
  )

  if (any(result$report$severity == "FAIL")) {
    quit(
      save = "no",
      status = 1L
    )
  }

  invisible(result)
}

if (!identical(
  tolower(
    Sys.getenv(
      "CANCERPPIR_AUDIT_LIBRARY_ONLY",
      unset = "false"
    )
  ),
  "true"
)) {
  cancerppir_workbook_audit_main()
}
