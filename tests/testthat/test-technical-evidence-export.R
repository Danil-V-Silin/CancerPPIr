phase4_read_pipeline_source <- function() {
  project_root <- Sys.getenv(
    "CANCERPPIR_PROJECT_ROOT",
    unset = ""
  )

  testthat::expect_true(nzchar(project_root))

  pipeline_file <- file.path(
    project_root,
    "R",
    "07_pipeline.R"
  )

  testthat::expect_true(file.exists(pipeline_file))

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

    testthat::expect_gt(technical_start, 0L)
    testthat::expect_gt(technical_end, technical_start)

    technical_block <- substr(
      pipeline_source,
      technical_start,
      technical_end - 1L
    )

    sheet_to_object <- c(
      "Phase4 module annotations" =
        "phase4_shadow_evidence$module_annotations",
      "Phase4 rule evidence" =
        "phase4_shadow_evidence$module_rule_evidence",
      "Phase4 significant terms" =
        "phase4_shadow_evidence$significant_module_terms",
      "Phase4 node annotations" =
        "phase4_shadow_evidence$node_annotations",
      "Phase4 validation" =
        "phase4_shadow_evidence$validation"
    )

    for (sheet_name in names(sheet_to_object)) {
      object_name <- unname(
        sheet_to_object[[sheet_name]]
      )

      testthat::expect_equal(
        lengths(
          gregexpr(
            paste0("\"", sheet_name, "\""),
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
  "Phase 4 evidence remains technical-only at this checkpoint",
  {
    pipeline_source <- phase4_read_pipeline_source()

    analytical_start <- regexpr(
      "analytical_sheets <- list(",
      pipeline_source,
      fixed = TRUE
    )[[1L]]

    analytical_end <- regexpr(
      "\"CancerPPIr_Analytical_Report.xlsx\"",
      pipeline_source,
      fixed = TRUE
    )[[1L]]

    testthat::expect_gt(analytical_start, 0L)
    testthat::expect_gt(analytical_end, analytical_start)

    analytical_block <- substr(
      pipeline_source,
      analytical_start,
      analytical_end - 1L
    )

    phase4_sheet_names <- c(
      "Phase4 module annotations",
      "Phase4 rule evidence",
      "Phase4 significant terms",
      "Phase4 node annotations",
      "Phase4 validation"
    )

    for (sheet_name in phase4_sheet_names) {
      testthat::expect_false(
        grepl(
          sheet_name,
          analytical_block,
          fixed = TRUE
        ),
        info = sheet_name
      )
    }
  }
)

testthat::test_that(
  "technical evidence export does not replace legacy GraphML attributes",
  {
    pipeline_source <- phase4_read_pipeline_source()

    testthat::expect_true(
      grepl(
        "cytoscape_node_attributes <- node_metrics_readable",
        pipeline_source,
        fixed = TRUE
      )
    )

    testthat::expect_false(
      grepl(
        "cytoscape_node_attributes <- phase4_shadow_evidence$node_annotations",
        pipeline_source,
        fixed = TRUE
      )
    )
  }
)
