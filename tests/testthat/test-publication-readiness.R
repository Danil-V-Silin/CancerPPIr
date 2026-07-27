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
    "scripts",
    "validate_publication_readiness.R"
  ),
  local = TRUE
)

testthat::test_that("publication-readiness contract passes", {
  validation <- cancerppir_validate_publication_readiness(
    project_root = project_root,
    include_git_diff_check = TRUE
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
      paste(
        failures$check_id,
        failures$details,
        sep = ": "
      ),
      collapse = "\n"
    )
  )
})
