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
      )
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

    result <- phase4_bind_pipeline_evidence(
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
      phase4_bind_pipeline_evidence(
        node_metrics = incomplete_nodes
      ),
      "community_louvain",
      fixed = TRUE
    )
  }
)
