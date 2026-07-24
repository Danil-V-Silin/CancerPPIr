testthat::test_that(
  "repository satisfies the Phase 4 static release contract",
  {
    project_root <- Sys.getenv(
      "CANCERPPIR_PROJECT_ROOT",
      unset = normalizePath(
        ".",
        winslash = "/",
        mustWork = TRUE
      )
    )

    source(
      file.path(
        project_root,
        "scripts",
        "validate_phase4_release_static.R"
      ),
      local = TRUE
    )

    validation <- phase4_9_validate_static_release(
      project_root
    )

    failures <- validation[
      validation$status == "FAIL",
      ,
      drop = FALSE
    ]

    testthat::expect_equal(
      nrow(failures),
      0L,
      info = paste(
        paste0(
          failures$check_id,
          ": ",
          failures$details
        ),
        collapse = "\n"
      )
    )
  }
)
