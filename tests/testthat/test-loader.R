testthat::test_that("module loader exposes the complete architecture", {
  expected_functions <- c(
    "parse_bool",
    "read_gene_table",
    "run_local_string_enrichment",
    "label_module_by_markers",
    "run_network_analysis",
    "run_cancerppir"
  )

  testthat::expect_true(
    all(vapply(
      expected_functions,
      exists,
      envir = .GlobalEnv,
      inherits = FALSE,
      FUN.VALUE = logical(1)
    ))
  )

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
})
