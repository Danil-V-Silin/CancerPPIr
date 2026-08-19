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

    testthat::expect_length(rules, 35L)
    testthat::expect_equal(sum(axes == "lineage"), 16L)
    testthat::expect_equal(sum(axes == "state"), 8L)
    testthat::expect_equal(sum(axes == "process"), 11L)
    testthat::expect_equal(nrow(provenance), 35L)
    testthat::expect_equal(
      sum(
        provenance$curation_status ==
          "provisional"
      ),
      3L
    )
    testthat::expect_equal(
      sum(
        provenance$curation_status ==
          "legacy_unverified"
      ),
      32L
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
    provenance$references[[1L]] <- ""

    testthat::expect_error(
      validate_evidence_rule_provenance(rules, provenance),
      regexp = "must contain at least one scientific reference"
    )
  }
)

testthat::test_that(
  "custom rulebooks receive conservative provenance",
  {
    rules <- default_evidence_rules()
    rule_ids <- vapply(
      rules,
      function(rule) rule$rule_id,
      character(1)
    )

    plasma_index <- match(
      "plasma_cell_associated",
      rule_ids
    )
    rules[[plasma_index]]$positive_markers <- c(
      rules[[plasma_index]]$positive_markers,
      "CUSTOM_MARKER"
    )

    provenance <- default_evidence_rule_provenance(
      rules
    )

    testthat::expect_identical(
      provenance$curation_status[[plasma_index]],
      "legacy_unverified"
    )

    subset_provenance <- default_evidence_rule_provenance(
      rules[seq_len(2L)]
    )

    testthat::expect_equal(
      nrow(subset_provenance),
      2L
    )

    testthat::expect_true(
      validate_evidence_rule_provenance(
        rules[seq_len(2L)],
        subset_provenance
      )
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
    testthat::expect_equal(nrow(provenance), 35L)
    testthat::expect_equal(
      sum(provenance$curation_status == "provisional"),
      3L
    )
    testthat::expect_equal(
      sum(provenance$reference_count > 0L),
      3L
    )
  }
)

testthat::test_that(
  "curation removes exact cross-axis biological duplicates",
  {
    rules <- default_evidence_rules()

    rule_ids <- vapply(
      rules,
      function(rule) rule$rule_id,
      character(1)
    )

    testthat::expect_false(
      "perivascular_contractile" %in% rule_ids
    )

    plasma <- rules[[
      match(
        "plasma_cell_associated",
        rule_ids
      )
    ]]

    secretion <- rules[[
      match(
        "immunoglobulin_secretion",
        rule_ids
      )
    ]]

    testthat::expect_false(
      identical(
        sort(plasma$positive_markers),
        sort(secretion$positive_markers)
      )
    )

    testthat::expect_length(
      intersect(
        plasma$positive_markers,
        secretion$positive_markers
      ),
      0L
    )
  }
)
