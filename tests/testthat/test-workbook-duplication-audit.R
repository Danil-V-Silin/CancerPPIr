project_root <- Sys.getenv(
  "CANCERPPIR_PROJECT_ROOT",
  unset = normalizePath(
    file.path("..", ".."),
    winslash = "/",
    mustWork = TRUE
  )
)

audit_path <- file.path(
  project_root,
  "tools",
  "audit",
  "audit_workbook_duplication.R"
)

previous_library_only <- Sys.getenv(
  "CANCERPPIR_AUDIT_LIBRARY_ONLY",
  unset = NA_character_
)
Sys.setenv(
  CANCERPPIR_AUDIT_LIBRARY_ONLY = "true"
)
source(
  audit_path,
  local = .GlobalEnv
)
if (is.na(previous_library_only)) {
  Sys.unsetenv(
    "CANCERPPIR_AUDIT_LIBRARY_ONLY"
  )
} else {
  Sys.setenv(
    CANCERPPIR_AUDIT_LIBRARY_ONLY =
      previous_library_only
  )
}

testthat::test_that(
  "empty value-equivalent columns are informational",
  {
    data <- data.frame(
      corrected_gene = c(NA_character_, ""),
      method = c(NA_character_, ""),
      stringsAsFactors = FALSE,
      check.names = FALSE
    )

    report <- cancerppir_audit_table(
      data,
      workbook = "test.xlsx",
      sheet = "Alias corrections"
    )

    testthat::expect_equal(
      report$finding_type,
      "empty_columns"
    )
    testthat::expect_equal(
      report$severity,
      "INFO"
    )
  }
)

testthat::test_that(
  "documented stage-equivalent columns are informational",
  {
    data <- data.frame(
      community_louvain = c(1L, 2L),
      module_id = c(1L, 2L),
      stringsAsFactors = FALSE,
      check.names = FALSE
    )

    report <- cancerppir_audit_table(
      data,
      workbook = "test.xlsx",
      sheet = "Significant terms"
    )

    testthat::expect_equal(
      report$finding_type,
      "expected_equivalent_columns"
    )
    testthat::expect_equal(
      report$severity,
      "INFO"
    )
  }
)

testthat::test_that(
  "unexpected exact value equality requires review",
  {
    data <- data.frame(
      logFC = c(1, 2, 3),
      abs_logFC = c(1, 2, 3),
      stringsAsFactors = FALSE,
      check.names = FALSE
    )

    report <- cancerppir_audit_table(
      data,
      workbook = "test.xlsx",
      sheet = "Raw node metrics"
    )

    testthat::expect_equal(
      report$finding_type,
      "value_equivalent_columns"
    )
    testthat::expect_equal(
      report$severity,
      "REVIEW"
    )
  }
)

testthat::test_that(
  "duplicate column names remain blocking failures",
  {
    data <- data.frame(
      first = c(1, 2),
      second = c(3, 4),
      stringsAsFactors = FALSE,
      check.names = FALSE
    )
    names(data) <- c(
      "duplicate_name",
      "duplicate_name"
    )

    report <- cancerppir_audit_table(
      data,
      workbook = "test.xlsx",
      sheet = "Test"
    )

    testthat::expect_true(
      any(
        report$finding_type ==
          "duplicate_column_names" &
          report$severity == "FAIL"
      )
    )
  }
)
