project_root <- Sys.getenv(
  "CANCERPPIR_PROJECT_ROOT",
  unset = normalizePath(file.path("..", ".."), winslash = "/", mustWork = TRUE)
)

source(
  file.path(project_root, "scripts", "validate_documentation_contract.R"),
  local = TRUE
)

testthat::test_that("public documentation satisfies the documentation contract", {
  validation <- cancerppir_validate_documentation_contract(project_root)

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
