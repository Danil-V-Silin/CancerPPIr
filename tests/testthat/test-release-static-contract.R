testthat::test_that(
  "repository satisfies the CancerPPIr static release contract",
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
        "scripts", "validate_release_contract.R"
      ),
      local = TRUE
    )

    validation <- cancerppir_validate_static_release_contract(
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
