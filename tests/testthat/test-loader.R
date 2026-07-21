testthat::test_that("module loader exposes the complete architecture", {
  expected_functions <- c(
    "parse_bool",
    "read_gene_table",
    "run_local_string_enrichment",
    "label_module_by_markers",
    "phase4_annotate_module_evidence",
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

testthat::test_that(
  "module loader uses the deterministic nine-module order",
  {
    project_root <- Sys.getenv(
      "CANCERPPIR_PROJECT_ROOT",
      unset = ""
    )

    testthat::expect_true(nzchar(project_root))

    isolated_environment <- new.env(
      parent = .GlobalEnv
    )

    loaded_files <- load_cancerppir_modules(
      project_root = project_root,
      envir = isolated_environment
    )

    expected_files <- c(
      "00_utils.R",
      "01_input.R",
      "02_string_mapping.R",
      "03_enrichment.R",
      "04_module_labeling.R",
      "04a_biological_evidence_engine.R",
      "05_reporting.R",
      "06_network_analysis.R",
      "07_pipeline.R"
    )

    testthat::expect_identical(
      basename(loaded_files),
      expected_files
    )

    testthat::expect_true(
      exists(
        "phase4_annotate_module_evidence",
        envir = isolated_environment,
        inherits = FALSE
      )
    )
  }
)
