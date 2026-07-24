testthat::test_that(
  "release edge case: no eligible candidates produces a valid empty priority table",
  {
    node_annotations <- data.frame(
      STRING_id = c(
        "9606.ENSP00000000001",
        "9606.ENSP00000000002"
      ),
      gene = c(
        "LOC_TEST",
        "IGHV_TEST"
      ),
      pvalue = c(
        0,
        0.5
      ),
      logFC = c(
        3,
        -2
      ),
      abs_logFC = c(
        3,
        2
      ),
      neg_log10_pvalue = c(
        300,
        -log10(0.5)
      ),
      degree = c(
        2,
        1
      ),
      betweenness = c(
        0.2,
        0
      ),
      stress_centrality = c(
        8,
        0
      ),
      community_louvain = c(
        1L,
        2L
      ),
      candidate_score = c(
        0.9,
        0.2
      ),
      entity_class = c(
        "predicted_LOC",
        "immunoglobulin_locus"
      ),
      candidate_eligibility = c(
        "network_evidence_only",
        "excluded_from_automatic_priority"
      ),
      module_interpretation_class = c(
        "technical_or_covariate",
        "unresolved"
      ),
      module_primary_interpretation = c(
        "technical/covariate signature",
        "unresolved biological context"
      ),
      module_confidence = c(
        "technical_or_covariate",
        "low"
      ),
      module_priority_eligible = c(
        FALSE,
        FALSE
      ),
      module_conflict_detected = c(
        FALSE,
        FALSE
      ),
      module_warning = c(
        "not eligible",
        "not eligible"
      ),
      stringsAsFactors = FALSE
    )

    candidates <- phase4_prepare_candidate_table(
      node_annotations
    )

    final_priorities <- phase4_build_final_priorities(
      candidates = candidates,
      maximum_rows = 10L
    )

    testthat::expect_equal(
      nrow(final_priorities),
      0L
    )

    testthat::expect_identical(
      names(final_priorities),
      phase4_expected_analytical_columns()[[
        "Final priorities"
      ]]
    )
  }
)

testthat::test_that(
  "release edge case: no eligible biological modules produces a valid empty module table",
  {
    module_annotations <- data.frame(
      module_id = c(
        "1",
        "2"
      ),
      module_size = c(
        4L,
        3L
      ),
      interpretation_class = c(
        "technical_or_covariate",
        "unresolved"
      ),
      interpretation_scope = c(
        "technical_or_covariate",
        "process_supported_lineage_unresolved"
      ),
      primary_interpretation = c(
        "technical/covariate signature",
        "unresolved biological context"
      ),
      confidence = c(
        "technical_or_covariate",
        "low"
      ),
      priority_eligible = c(
        FALSE,
        FALSE
      ),
      representative_genes = c(
        "RPS4Y1; KDM5D",
        "GENE1; GENE2"
      ),
      positive_marker_genes = c(
        "",
        ""
      ),
      supportive_marker_genes = c(
        "",
        ""
      ),
      significant_supporting_terms = c(
        "",
        ""
      ),
      best_supporting_fdr = c(
        NA_real_,
        NA_real_
      ),
      secondary_themes = c(
        "",
        ""
      ),
      conflict_detected = c(
        FALSE,
        FALSE
      ),
      warning = c(
        "technical module",
        "unresolved module"
      ),
      evidence_rationale = c(
        "Technical evidence only.",
        "Insufficient evidence for automatic priority."
      ),
      stringsAsFactors = FALSE
    )

    module_priorities <- phase4_build_module_priorities(
      module_annotations = module_annotations,
      network_nodes = 7L,
      maximum_rows = 5L
    )

    testthat::expect_equal(
      nrow(module_priorities),
      0L
    )

    testthat::expect_identical(
      names(module_priorities),
      phase4_expected_analytical_columns()[[
        "Module priorities"
      ]]
    )
  }
)

testthat::test_that(
  "release edge case: zero p-values remain finite and parser-safe in GraphML",
  {
    safe <- prepare_graphml_pvalue_export(
      c(
        0,
        1e-320,
        0.05,
        NA_real_
      )
    )

    testthat::expect_true(
      all(
        is.na(safe$value) |
          is.finite(safe$value)
      )
    )

    testthat::expect_true(
      all(
        is.na(safe$value) |
          safe$value >=
            CANCERPPIR_GRAPHML_PVALUE_FLOOR
      )
    )

    testthat::expect_true(
      safe$floor_applied[[1L]]
    )

    testthat::expect_true(
      safe$floor_applied[[2L]]
    )

    testthat::expect_false(
      safe$floor_applied[[3L]]
    )
  }
)

testthat::test_that(
  "release edge case: public schemas and canonical GraphML fields remain pinned",
  {
    testthat::expect_identical(
      cancerppir_schema_versions(),
      list(
        pipeline_result = "4.7.0",
        biological_evidence = "1.0.0",
        analytical_workbook = "4.5.0",
        technical_workbook = "4.4.0",
        graphml = "4.6.0",
        output_manifest = "1.0.0",
        output_checksums = "1.0.0"
      )
    )

    canonical_fields <-
      phase4_canonical_graphml_attribute_names()

    testthat::expect_true(
      all(
        phase4_required_canonical_node_fields() %in%
          canonical_fields
      )
    )

    testthat::expect_false(
      any(
        CANCERPPIR_LEGACY_ANNOTATION_FIELDS %in%
          canonical_fields
      )
    )
  }
)
