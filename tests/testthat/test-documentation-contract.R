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

  required_semantic_checks <- c(
    "scientific_input_contract_is_internally_consistent",
    "canonical_interpretation_is_database_primary",
    "current_canonical_decision_states_are_documented",
    "schema_registry_and_publication_checklist_agree",
    "qualified_r_runtime_is_consistently_documented",
    "implemented_output_specification_matches_public_contract"
  )

  testthat::expect_true(
    all(required_semantic_checks %in% validation$check_id),
    info = paste(
      setdiff(required_semantic_checks, validation$check_id),
      collapse = "\n"
    )
  )

  testthat::expect_false(anyDuplicated(validation$check_id) > 0L)

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
