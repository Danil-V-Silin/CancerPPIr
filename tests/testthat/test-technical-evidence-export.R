phase4_read_pipeline_source <- function() {
  project_root <- Sys.getenv(
    "CANCERPPIR_PROJECT_ROOT",
    unset = ""
  )

  testthat::expect_true(
    nzchar(project_root)
  )

  pipeline_file <- file.path(
    project_root,
    "R",
    "07_pipeline.R"
  )

  testthat::expect_true(
    file.exists(pipeline_file)
  )

  paste(
    readLines(
      pipeline_file,
      warn = FALSE,
      encoding = "UTF-8"
    ),
    collapse = "\n"
  )
}

testthat::test_that(
  "technical workbook exports all Phase 4 evidence tables",
  {
    pipeline_source <- phase4_read_pipeline_source()

    technical_start <- regexpr(
      "technical_sheets <- list(",
      pipeline_source,
      fixed = TRUE
    )[[1L]]

    technical_end <- regexpr(
      "\"CancerPPIr_Technical_Report.xlsx\"",
      pipeline_source,
      fixed = TRUE
    )[[1L]]

    testthat::expect_gt(
      technical_start,
      0L
    )

    testthat::expect_gt(
      technical_end,
      technical_start
    )

    technical_block <- substr(
      pipeline_source,
      technical_start,
      technical_end - 1L
    )

    sheet_to_object <- c(
      "Phase4 module annotations" =
        "biological_evidence$module_annotations",
      "Phase4 rule evidence" =
        "biological_evidence$module_rule_evidence",
      "Phase4 significant terms" =
        "biological_evidence$significant_module_terms",
      "Phase4 node annotations" =
        "biological_evidence$node_annotations",
      "Phase4 validation" =
        "biological_evidence$validation"
    )

    for (sheet_name in names(
      sheet_to_object
    )) {
      object_name <- unname(
        sheet_to_object[[sheet_name]]
      )

      testthat::expect_equal(
        lengths(
          gregexpr(
            paste0(
              "\"",
              sheet_name,
              "\""
            ),
            technical_block,
            fixed = TRUE
          )
        ),
        1L,
        info = sheet_name
      )

      testthat::expect_equal(
        lengths(
          gregexpr(
            object_name,
            technical_block,
            fixed = TRUE
          )
        ),
        1L,
        info = object_name
      )
    }
  }
)

testthat::test_that(
  "analytical workbook is built from the Phase 4 evidence contract",
  {
    pipeline_source <- phase4_read_pipeline_source()

    testthat::expect_true(
      grepl(
        "phase4_analytical_report <- build_phase4_analytical_workbook(",
        pipeline_source,
        fixed = TRUE
      )
    )

    testthat::expect_true(
      grepl(
        "phase4_evidence = biological_evidence",
        pipeline_source,
        fixed = TRUE
      )
    )

    testthat::expect_true(
      grepl(
        "analytical_sheets <- phase4_analytical_report$sheets",
        pipeline_source,
        fixed = TRUE
      )
    )

    legacy_sheet_names <- c(
      "\"Major module priorities\"",
      "\"Candidate rationale\"",
      "\"Top candidates\"",
      "\"Graph summary\"",
      "\"All modules\"",
      "\"Top degree\"",
      "\"Top betweenness\"",
      "\"Top stress\"",
      "\"Degree distribution\""
    )

    analytical_write_start <- regexpr(
      "# Main analytical workbook",
      pipeline_source,
      fixed = TRUE
    )[[1L]]

    analytical_write_end <- regexpr(
      "# Technical workbook",
      pipeline_source,
      fixed = TRUE
    )[[1L]]

    testthat::expect_gt(
      analytical_write_start,
      0L
    )

    testthat::expect_gt(
      analytical_write_end,
      analytical_write_start
    )

    analytical_write_block <- substr(
      pipeline_source,
      analytical_write_start,
      analytical_write_end - 1L
    )

    for (legacy_sheet in legacy_sheet_names) {
      testthat::expect_false(
        grepl(
          legacy_sheet,
          analytical_write_block,
          fixed = TRUE
        ),
        info = legacy_sheet
      )
    }
  }
)

testthat::test_that(
  "GraphML export uses the canonical biological annotation contract",
  {
    pipeline_source <- phase4_read_pipeline_source()

    testthat::expect_true(
      grepl(
        "canonical_graphml_attributes <-",
        pipeline_source,
        fixed = TRUE
      )
    )

    testthat::expect_true(
      grepl(
        "phase4_build_canonical_graphml_attributes(",
        pipeline_source,
        fixed = TRUE
      )
    )

    testthat::expect_true(
      grepl(
        "node_annotations = biological_evidence$node_annotations",
        pipeline_source,
        fixed = TRUE
      )
    )

    testthat::expect_false(
      grepl(
        "cytoscape_module_label = final_functional_label",
        pipeline_source,
        fixed = TRUE
      )
    )

    testthat::expect_false(
      grepl(
        "cytoscape_node_attributes <- node_metrics_readable",
        pipeline_source,
        fixed = TRUE
      )
    )
  }
)
