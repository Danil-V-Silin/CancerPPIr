#!/usr/bin/env Rscript
# Audit exact workbook duplication without modifying output files.

arguments <- commandArgs(trailingOnly = TRUE)

if (length(arguments) < 1L || length(arguments) > 2L) {
  stop(
    paste(
      "Usage:",
      "  Rscript tools/audit/audit_workbook_duplication.R OUTPUT_ROOT [REPORT_CSV]",
      sep = "\n"
    ),
    call. = FALSE
  )
}

if (!requireNamespace("openxlsx", quietly = TRUE)) {
  stop("Package 'openxlsx' is required.", call. = FALSE)
}

if (!requireNamespace("digest", quietly = TRUE)) {
  stop("Package 'digest' is required.", call. = FALSE)
}

output_root <- normalizePath(
  arguments[[1L]],
  winslash = "/",
  mustWork = TRUE
)

report_path <- if (length(arguments) == 2L) {
  arguments[[2L]]
} else {
  file.path(output_root, "workbook_duplication_audit.csv")
}

workbooks <- list.files(
  output_root,
  pattern = "^CancerPPIr_(Analytical|Technical)_Report\\.xlsx$",
  recursive = TRUE,
  full.names = TRUE
)

if (length(workbooks) == 0L) {
  stop("No CancerPPIr workbooks were found under: ", output_root, call. = FALSE)
}

normalize_table <- function(data) {
  data <- as.data.frame(
    data,
    stringsAsFactors = FALSE,
    check.names = FALSE
  )

  data[] <- lapply(data, function(column) {
    if (is.list(column)) {
      vapply(
        column,
        function(value) paste(as.character(value), collapse = ";"),
        character(1)
      )
    } else {
      as.character(column)
    }
  })

  data[is.na(data)] <- "<NA>"

  list(
    columns = names(data),
    rows = unname(as.matrix(data))
  )
}

findings <- list()
sheet_registry <- list()

add_finding <- function(
  workbook,
  sheet,
  finding_type,
  severity,
  details
) {
  findings[[length(findings) + 1L]] <<- data.frame(
    workbook = as.character(workbook),
    sheet = as.character(sheet),
    finding_type = as.character(finding_type),
    severity = as.character(severity),
    details = as.character(details),
    stringsAsFactors = FALSE
  )
  invisible(NULL)
}

for (workbook in workbooks) {
  sheet_names <- openxlsx::getSheetNames(workbook)
  workbook_key <- normalizePath(workbook, winslash = "/", mustWork = TRUE)
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

    normalized <- normalize_table(data)
    sheet_hash <- digest::digest(
      normalized,
      algo = "sha256",
      serialize = TRUE
    )

    hashes[[sheet_name]] <- sheet_hash

    sheet_registry[[length(sheet_registry) + 1L]] <- data.frame(
      workbook = workbook_key,
      sheet = sheet_name,
      hash = sheet_hash,
      stringsAsFactors = FALSE
    )

    if (ncol(data) > 1L) {
      duplicate_column_pairs <- character()

      for (left in seq_len(ncol(data) - 1L)) {
        for (right in seq.int(left + 1L, ncol(data))) {
          left_values <- as.character(data[[left]])
          right_values <- as.character(data[[right]])
          left_values[is.na(left_values)] <- "<NA>"
          right_values[is.na(right_values)] <- "<NA>"

          if (identical(left_values, right_values)) {
            duplicate_column_pairs <- c(
              duplicate_column_pairs,
              paste0(names(data)[[left]], " == ", names(data)[[right]])
            )
          }
        }
      }

      if (length(duplicate_column_pairs) > 0L) {
        add_finding(
          workbook_key,
          sheet_name,
          "duplicate_columns",
          "FAIL",
          paste(duplicate_column_pairs, collapse = " | ")
        )
      }
    }

    duplicate_rows <- if (nrow(data) > 0L) {
      sum(duplicated(normalized$rows))
    } else {
      0L
    }

    if (duplicate_rows > 0L) {
      add_finding(
        workbook_key,
        sheet_name,
        "duplicate_rows",
        "REVIEW",
        paste0("exact_duplicate_rows=", duplicate_rows)
      )
    }
  }

  duplicate_hashes <- unique(hashes[duplicated(hashes)])
  for (duplicate_hash in duplicate_hashes) {
    duplicate_sheets <- names(hashes)[hashes == duplicate_hash]
    add_finding(
      workbook_key,
      paste(duplicate_sheets, collapse = " | "),
      "duplicate_sheets_within_workbook",
      "FAIL",
      paste0("sha256=", duplicate_hash)
    )
  }
}

registry <- do.call(rbind, sheet_registry)
cross_groups <- split(
  registry,
  registry$hash
)

for (group in cross_groups) {
  if (nrow(group) < 2L) next
  if (length(unique(group$workbook)) < 2L) next

  add_finding(
    paste(unique(group$workbook), collapse = " | "),
    paste(group$sheet, collapse = " | "),
    "identical_sheet_across_workbooks",
    "REVIEW",
    paste0("sha256=", unique(group$hash))
  )
}

report <- if (length(findings) > 0L) {
  do.call(rbind, findings)
} else {
  data.frame(
    workbook = character(),
    sheet = character(),
    finding_type = character(),
    severity = character(),
    details = character(),
    stringsAsFactors = FALSE
  )
}

dir.create(dirname(report_path), recursive = TRUE, showWarnings = FALSE)
utils::write.csv(
  report,
  report_path,
  row.names = FALSE,
  na = ""
)

cat(
  "Workbooks audited: ", length(workbooks), "\n",
  "Findings: ", nrow(report), "\n",
  "FAIL findings: ", sum(report$severity == "FAIL"), "\n",
  "REVIEW findings: ", sum(report$severity == "REVIEW"), "\n",
  "Report: ", normalizePath(report_path, winslash = "/", mustWork = TRUE), "\n",
  sep = ""
)

if (any(report$severity == "FAIL")) {
  quit(save = "no", status = 1L)
}
