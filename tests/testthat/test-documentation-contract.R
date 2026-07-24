project_root <- Sys.getenv(
  "CANCERPPIR_PROJECT_ROOT",
  unset = normalizePath(file.path("..", ".."), winslash = "/", mustWork = TRUE)
)

source(
  file.path(project_root, "scripts", "validate_phase4_8_documentation.R"),
  local = TRUE
)

testthat::test_that("public documentation satisfies the Phase 4.8 contract", {
  validation <- phase4_8_validate_documentation(project_root)

  failures <- validation[validation$status == "FAIL", , drop = FALSE]

  testthat::expect_equal(
    nrow(failures),
    0L,
    info = if (nrow(failures)) {
      paste(
        paste(failures$check_id, failures$details, sep = ": "),
        collapse = "\n"
      )
    } else {
      ""
    }
  )
})
