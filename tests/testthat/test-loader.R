testthat::test_that(
  "module loader exposes the complete architecture",
  {
    expected_functions <- c(
      "parse_bool",
      "read_gene_table",
      "run_local_string_enrichment",
      "label_module_by_markers",
      "annotate_module_evidence",
      "bind_pipeline_evidence",
      "build_analytical_workbook",
      "validate_analytical_workbook",
      "build_canonical_graphml_attributes",
      "build_canonical_pipeline_result",
      "cancerppir_write_output_provenance",
      "cancerppir_validate_output_provenance",
      "run_network_analysis",
      "run_cancerppir"
    )

    testthat::expect_true(
      all(
        vapply(
          expected_functions,
          exists,
          envir = .GlobalEnv,
          inherits = FALSE,
          FUN.VALUE = logical(1)
        )
      )
    )

    testthat::expect_identical(
      names(
        formals(
          run_cancerppir
        )
      ),
      c(
        "input_file",
        "results_root",
        "cache_dir",
        "score_threshold",
        "top_n",
        "run_enrichment"
      )
    )
  }
)

testthat::test_that(
  "module loader uses the deterministic twelve-module order",
  {
    project_root <- Sys.getenv(
      "CANCERPPIR_PROJECT_ROOT",
      unset = ""
    )

    testthat::expect_true(
      nzchar(project_root)
    )

    isolated_environment <- new.env(
      parent = .GlobalEnv
    )

    loaded_files <- load_cancerppir_modules(
      project_root = project_root,
      envir = isolated_environment
    )

    expected_files <- c(
      "utils.R",
      "input.R",
      "string_mapping.R",
      "enrichment.R",
      "module_labeling.R",
      "biological_evidence_engine.R",
      "biological_evidence_adapter.R",
      "reporting.R",
      "analytical_workbook.R",
      "canonical_annotation_output.R",
      "output_provenance.R",
      "network_analysis.R",
      "pipeline.R"
    )

    testthat::expect_identical(
      basename(
        loaded_files
      ),
      expected_files
    )

    testthat::expect_true(
      exists(
        "annotate_module_evidence",
        envir = isolated_environment,
        inherits = FALSE
      )
    )

    testthat::expect_true(
      exists(
        "build_analytical_workbook",
        envir = isolated_environment,
        inherits = FALSE
      )
    )

    testthat::expect_true(
      exists(
        "build_canonical_graphml_attributes",
        envir = isolated_environment,
        inherits = FALSE
      )
    )

    testthat::expect_true(
      exists(
        "cancerppir_write_output_provenance",
        envir = isolated_environment,
        inherits = FALSE
      )
    )
  }
)
