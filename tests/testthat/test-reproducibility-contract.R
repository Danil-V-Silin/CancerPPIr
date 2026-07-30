project_root <- Sys.getenv(
  "CANCERPPIR_PROJECT_ROOT",
  unset = normalizePath(".", winslash = "/", mustWork = TRUE)
)

source(
  file.path(
    project_root,
    "scripts",
    "validate_reproducibility_contract.R"
  ),
  local = TRUE
)

testthat::test_that(
  "repository satisfies the reproducible environment contract",
  {
    validation <-
      cancerppir_validate_reproducibility_contract(project_root)

    failures <- validation[
      validation$status == "FAIL",
      ,
      drop = FALSE
    ]

    testthat::expect_equal(
      nrow(failures),
      0L,
      info = if (nrow(failures)) {
        paste(
          paste(
            failures$check_id,
            failures$details,
            sep = ": "
          ),
          collapse = "\n"
        )
      } else {
        ""
      }
    )
  }
)
