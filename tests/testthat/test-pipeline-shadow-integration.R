testthat::test_that(
  "production pipeline computes the Phase 4 shadow evidence object",
  {
    pipeline_body <- paste(
      deparse(
        body(run_cancerppir),
        width.cutoff = 500L
      ),
      collapse = "\n"
    )

    testthat::expect_equal(
      lengths(
        gregexpr(
          "phase4_bind_pipeline_evidence(",
          pipeline_body,
          fixed = TRUE
        )
      ),
      1L
    )

    testthat::expect_true(
      grepl(
        "node_metrics = node_metrics",
        pipeline_body,
        fixed = TRUE
      )
    )

    testthat::expect_true(
      grepl(
        paste0(
          "module_enrichment = ",
          "module_enrichment_string_local"
        ),
        pipeline_body,
        fixed = TRUE
      )
    )

    testthat::expect_true(
      grepl(
        "fdr_threshold = 0.05",
        pipeline_body,
        fixed = TRUE
      )
    )

    testthat::expect_true(
      grepl(
        paste0(
          "biological_evidence_shadow = ",
          "phase4_shadow_evidence"
        ),
        pipeline_body,
        fixed = TRUE
      )
    )
  }
)

testthat::test_that(
  "shadow integration preserves the legacy reporting path",
  {
    pipeline_body <- paste(
      deparse(
        body(run_cancerppir),
        width.cutoff = 500L
      ),
      collapse = "\n"
    )

    shadow_position <- regexpr(
      "phase4_bind_pipeline_evidence(",
      pipeline_body,
      fixed = TRUE
    )[[1L]]

    legacy_label_position <- regexpr(
      "assign_module_label_with_rules",
      pipeline_body,
      fixed = TRUE
    )[[1L]]

    analytical_export_position <- regexpr(
      '"CancerPPIr_Analytical_Report.xlsx"',
      pipeline_body,
      fixed = TRUE
    )[[1L]]

    technical_export_position <- regexpr(
      '"CancerPPIr_Technical_Report.xlsx"',
      pipeline_body,
      fixed = TRUE
    )[[1L]]

    testthat::expect_gt(shadow_position, 0L)
    testthat::expect_gt(
      legacy_label_position,
      shadow_position
    )
    testthat::expect_gt(
      analytical_export_position,
      legacy_label_position
    )
    testthat::expect_gt(
      technical_export_position,
      legacy_label_position
    )
  }
)

testthat::test_that(
  "shadow integration keeps the public pipeline interface unchanged",
  {
    testthat::expect_identical(
      names(formals(run_cancerppir)),
      c(
        "input_file",
        "results_root",
        "cache_dir",
        "score_threshold",
        "top_n",
        "run_enrichment"
      )
    )
  }
)
