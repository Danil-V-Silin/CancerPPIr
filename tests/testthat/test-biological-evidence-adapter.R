testthat::test_that(
  "pipeline adapter binds module and candidate evidence",
  {
    node_metrics <- tibble::tibble(
      STRING_id = paste0("9606.ENSP", seq_len(11L)),
      gene = c(
        "CD3D", "CD3E", "CD3G", "TRAC",
        "LCK", "IL7R", "GIMAP5",
        "RPS4Y1", "KDM5D", "DDX3Y", "UTY"
      ),
      community_louvain = c(
        rep(1L, 7L),
        rep(2L, 4L)
      ),
      candidate_score = seq(
        1,
        0.1,
        length.out = 11L
      ),
      module_direction = "legacy module label",
      clean_module_label = "legacy module label",
      marker_based_direction = "legacy marker direction",
      marker_clean_label = "legacy marker label",
      marker_evidence_genes = "CD3D;CD3E",
      enrichment_evidence_terms = "legacy enrichment term"
    )

    module_enrichment <- tibble::tibble(
      community_louvain = c(1L, 1L, 1L),
      category = c(
        "Biological Process (Gene Ontology)",
        "Biological Process (Gene Ontology)",
        "Biological Process (Gene Ontology)"
      ),
      term = c(
        "GO:0050852",
        "GO:0023052",
        "GO:0007049"
      ),
      description = c(
        "T cell receptor signaling pathway",
        "Signaling",
        "cell cycle"
      ),
      fdr = c(0.001, 0.0001, 0.20),
      preferred_names = c(
        "CD3D;CD3E;CD3G;TRAC;LCK",
        "CD3D;CD3E",
        "LCK"
      )
    )

    result <- bind_pipeline_evidence(
      node_metrics = node_metrics,
      module_enrichment = module_enrichment,
      fdr_threshold = 0.05
    )

    testthat::expect_type(result, "list")
    testthat::expect_equal(
      nrow(result$module_annotations),
      2L
    )
    testthat::expect_equal(
      nrow(result$node_annotations),
      nrow(node_metrics)
    )
    testthat::expect_identical(
      result$node_annotations$gene,
      node_metrics$gene
    )

    testthat::expect_true(
      any(
        CANCERPPIR_DEPRECATED_ANNOTATION_FIELDS %in%
          names(node_metrics)
      )
    )

    testthat::expect_false(
      any(
        CANCERPPIR_DEPRECATED_ANNOTATION_FIELDS %in%
          names(result$node_annotations)
      )
    )

    y_module <- result$module_annotations[
      result$module_annotations$community_louvain == 2L,
      ,
      drop = FALSE
    ]

    testthat::expect_identical(
      y_module$interpretation_class[[1L]],
      "technical_or_covariate"
    )
    testthat::expect_false(
      y_module$priority_eligible[[1L]]
    )

    testthat::expect_equal(
      nrow(result$significant_module_terms),
      1L
    )
    testthat::expect_identical(
      result$significant_module_terms$description[[1L]],
      "T cell receptor signaling pathway"
    )
    testthat::expect_true(
      grepl(
        "CD3D",
        result$significant_module_terms$supporting_genes[[1L]],
        fixed = TRUE
      )
    )
    testthat::expect_true(
      all(result$validation$status == "PASS")
    )
    testthat::expect_true(
      all(
        c(
          "entity_class",
          "candidate_eligibility",
          "module_primary_interpretation",
          "module_priority_eligible"
        ) %in% names(result$node_annotations)
      )
    )
  }
)

testthat::test_that(
  "pipeline adapter rejects an incomplete node schema",
  {
    incomplete_nodes <- tibble::tibble(
      gene = c("CD3D", "CD3E")
    )

    testthat::expect_error(
      bind_pipeline_evidence(
        node_metrics = incomplete_nodes
      ),
      "community_louvain",
      fixed = TRUE
    )
  }
)

testthat::test_that(
  "canonical module interpretation is database-primary",
  {
    node_metrics <- tibble::tibble(
      STRING_id = c(
        "9606.ENSP_TEST1",
        "9606.ENSP_TEST2",
        "9606.ENSP_TEST3"
      ),
      gene = c(
        "GENE_TEST_A",
        "GENE_TEST_B",
        "GENE_TEST_C"
      ),
      community_louvain = c(
        1L,
        1L,
        1L
      ),
      candidate_score = c(
        1,
        0.8,
        0.6
      )
    )

    module_enrichment <- tibble::tibble(
      community_louvain = 1L,
      category = "Biological Process (Gene Ontology)",
      term = "GO:TEST_DATABASE_PRIMARY",
      description = "mitotic chromosome segregation",
      fdr = 0.001,
      preferred_names =
        "GENE_TEST_A;GENE_TEST_B"
    )

    result <- bind_pipeline_evidence(
      node_metrics = node_metrics,
      module_enrichment = module_enrichment,
      fdr_threshold = 0.05
    )

    module <- result$module_annotations[
      1L,
      ,
      drop = FALSE
    ]

    testthat::expect_identical(
      module$interpretation_class[[1L]],
      "biological"
    )

    testthat::expect_identical(
      module$interpretation_scope[[1L]],
      "database_enrichment_supported"
    )

    testthat::expect_identical(
      module$primary_interpretation[[1L]],
      "mitotic chromosome segregation"
    )

    testthat::expect_true(
      module$priority_eligible[[1L]]
    )

    testthat::expect_identical(
      module$positive_marker_genes[[1L]],
      ""
    )

    testthat::expect_identical(
      module$supportive_marker_genes[[1L]],
      ""
    )

    testthat::expect_false(
      module$conflict_detected[[1L]]
    )

    testthat::expect_true(
      nrow(result$module_rule_evidence) > 0L
    )

    provenance_fields <- c(
      "curation_status",
      "rule_version",
      "rule_schema_version",
      "evidence_basis",
      "reference_count",
      "references"
    )

    testthat::expect_true(
      all(
        provenance_fields %in%
          names(result$module_rule_evidence)
      )
    )

    testthat::expect_setequal(
      unique(result$module_rule_evidence$curation_status),
      c("legacy_unverified", "provisional")
    )

    provisional <- result$module_rule_evidence[
      result$module_rule_evidence$curation_status ==
        "provisional",
      ,
      drop = FALSE
    ]

    testthat::expect_true(
      all(provisional$reference_count > 0L)
    )

    testthat::expect_true(
      all(nzchar(provisional$references))
    )

    testthat::expect_true(
      all(result$validation$status == "PASS")
    )

    testthat::expect_identical(
      result$validation$status[
        result$validation$check_id ==
          "rule_evidence_has_explicit_provenance"
      ],
      "PASS"
    )
  }
)

testthat::test_that(
  "marker evidence alone cannot define canonical module interpretation",
  {
    node_metrics <- tibble::tibble(
      STRING_id = paste0(
        "9606.ENSP_MARKER_",
        seq_len(5L)
      ),
      gene = c(
        "CD3D",
        "CD3E",
        "CD3G",
        "TRAC",
        "LCK"
      ),
      community_louvain = rep(
        1L,
        5L
      ),
      candidate_score = seq(
        1,
        0.6,
        length.out = 5L
      )
    )

    result <- bind_pipeline_evidence(
      node_metrics = node_metrics,
      module_enrichment = NULL,
      fdr_threshold = 0.05
    )

    module <- result$module_annotations[
      1L,
      ,
      drop = FALSE
    ]

    testthat::expect_identical(
      module$interpretation_class[[1L]],
      "unresolved"
    )

    testthat::expect_identical(
      module$primary_interpretation[[1L]],
      "unresolved biological context"
    )

    testthat::expect_false(
      module$priority_eligible[[1L]]
    )

    t_cell_rule <- result$module_rule_evidence[
      result$module_rule_evidence$rule_id ==
        "T_cell_associated",
      ,
      drop = FALSE
    ]

    testthat::expect_equal(
      nrow(t_cell_rule),
      1L
    )

    testthat::expect_true(
      t_cell_rule$positive_marker_count[[1L]] >= 2L
    )
  }
)
