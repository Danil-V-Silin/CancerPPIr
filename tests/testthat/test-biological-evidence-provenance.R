project_root <- Sys.getenv(
  "CANCERPPIR_PROJECT_ROOT",
  unset = normalizePath(
    file.path("..", ".."),
    winslash = "/",
    mustWork = TRUE
  )
)

source(
  file.path(
    project_root,
    "R",
    "biological_evidence_rules.R"
  ),
  local = FALSE
)

testthat::test_that(
  "legacy rulebook has explicit provenance",
  {
    rules <- default_evidence_rules()
    provenance <- default_evidence_rule_provenance(rules)
    axes <- vapply(rules, function(rule) rule$axis, character(1))

    testthat::expect_length(rules, 36L)
    testthat::expect_equal(sum(axes == "lineage"), 16L)
    testthat::expect_equal(sum(axes == "state"), 8L)
    testthat::expect_equal(sum(axes == "process"), 12L)
    testthat::expect_equal(nrow(provenance), 36L)
    testthat::expect_true(
      all(provenance$curation_status == "legacy_unverified")
    )
    testthat::expect_true(
      validate_evidence_rule_provenance(rules, provenance)
    )
  }
)

testthat::test_that(
  "verified rules require references",
  {
    rules <- default_evidence_rules()
    provenance <- default_evidence_rule_provenance(rules)
    provenance$curation_status[[1L]] <- "verified"

    testthat::expect_error(
      validate_evidence_rule_provenance(rules, provenance),
      regexp = "must contain at least one scientific reference"
    )
  }
)

testthat::test_that(
  "duplicate rule identifiers are rejected",
  {
    rules <- default_evidence_rules()
    rules[[2L]]$rule_id <- rules[[1L]]$rule_id
    provenance <- default_evidence_rule_provenance(rules)

    testthat::expect_error(
      validate_evidence_rule_provenance(rules, provenance),
      regexp = "duplicate rule_id"
    )
  }
)

testthat::test_that(
  "provenance table exposes all rules",
  {
    provenance <- evidence_rule_provenance_table()
    testthat::expect_equal(nrow(provenance), 36L)
    testthat::expect_true(all(provenance$reference_count == 0L))
  }
)
