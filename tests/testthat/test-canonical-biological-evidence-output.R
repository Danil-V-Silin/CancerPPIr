phase4_test_canonical_node_annotations <- function() {
  data.frame(
    STRING_id = c("9606.ENSP1", "9606.ENSP2"),
    gene = c("CD3D", "TYROBP"),
    pvalue = c(0, 1e-12),
    logFC = c(2.5, 1.7),
    abs_logFC = c(2.5, 1.7),
    neg_log10_pvalue = c(307.65266, 12),
    degree = c(5, 3),
    betweenness = c(0.5, 0.2),
    closeness = c(0.7, 0.6),
    harmonic_closeness = c(0.8, 0.7),
    stress_centrality = c(20, 10),
    local_clustering = c(0.2, 0.4),
    component = c(1, 1),
    in_largest_component = c(TRUE, TRUE),
    community_louvain = c(1, 2),
    candidate_score = c(1, 0),
    entity_class = c(
      "canonical_or_unclassified_protein_coding",
      "canonical_or_unclassified_protein_coding"
    ),
    candidate_eligibility = c(
      "review_ready_canonical",
      "review_ready_canonical"
    ),
    module_interpretation_class = c(
      "biological",
      "biological"
    ),
    module_interpretation_scope = c(
      "lineage_supported",
      "lineage_supported"
    ),
    module_compartment = c("immune", "immune"),
    module_lineage = c(
      "T_cell_associated",
      "myeloid_macrophage_associated"
    ),
    module_state = c("not_assigned", "not_assigned"),
    module_process = c(
      "T_cell_receptor_signaling",
      "innate_immune_response"
    ),
    module_primary_interpretation = c(
      "T-cell-associated / T-cell-receptor-signaling",
      "myeloid/macrophage-associated / innate-immune-response"
    ),
    module_secondary_themes = c("", "complement-associated"),
    module_confidence = c("high", "high"),
    module_priority_eligible = c(TRUE, TRUE),
    module_positive_marker_genes = c("CD3D", "TYROBP"),
    module_supportive_marker_genes = c("", ""),
    module_term_supporting_genes = c("CD3D", "TYROBP"),
    module_significant_supporting_terms = c(
      "T cell receptor signaling pathway",
      "Innate immune response"
    ),
    module_best_supporting_fdr = c(0.001, 0.002),
    module_conflict_detected = c(FALSE, FALSE),
    module_warning = c("no_warning", "no_warning"),
    module_evidence_rationale = c(
      "Canonical T-cell evidence.",
      "Canonical myeloid evidence."
    ),
    stringsAsFactors = FALSE
  )
}

phase4_test_canonical_module_annotations <- function() {
  data.frame(
    community_louvain = c(1, 2),
    module_id = c("1", "2"),
    module_size = c(1, 1),
    interpretation_class = c("biological", "biological"),
    interpretation_scope = c("lineage_supported", "lineage_supported"),
    compartment = c("immune", "immune"),
    lineage = c("T_cell_associated", "myeloid_macrophage_associated"),
    state = c("not_assigned", "not_assigned"),
    process = c("T_cell_receptor_signaling", "innate_immune_response"),
    primary_interpretation = c(
      "T-cell-associated / T-cell-receptor-signaling",
      "myeloid/macrophage-associated / innate-immune-response"
    ),
    secondary_themes = c("", "complement-associated"),
    confidence = c("high", "high"),
    priority_eligible = c(TRUE, TRUE),
    positive_marker_genes = c("CD3D", "TYROBP"),
    supportive_marker_genes = c("", ""),
    term_supporting_genes = c("CD3D", "TYROBP"),
    significant_supporting_terms = c(
      "T cell receptor signaling pathway",
      "Innate immune response"
    ),
    best_supporting_fdr = c(0.001, 0.002),
    conflict_detected = c(FALSE, FALSE),
    warning = c("no_warning", "no_warning"),
    evidence_rationale = c(
      "Canonical T-cell evidence.",
      "Canonical myeloid evidence."
    ),
    stringsAsFactors = FALSE
  )
}

testthat::test_that(
  "production pipeline uses canonical biological evidence without shadow API",
  {
    pipeline_body <- paste(
      deparse(
        body(run_cancerppir),
        width.cutoff = 500L
      ),
      collapse = "\n"
    )

    testthat::expect_equal(
      lengths(
        gregexpr(
          "phase4_bind_pipeline_evidence(",
          pipeline_body,
          fixed = TRUE
        )
      ),
      1L
    )

    testthat::expect_true(
      grepl(
        "biological_evidence <- phase4_bind_pipeline_evidence(",
        pipeline_body,
        fixed = TRUE
      )
    )

    testthat::expect_true(
      grepl(
        "phase4_build_canonical_graphml_attributes(",
        pipeline_body,
        fixed = TRUE
      )
    )

    testthat::expect_true(
      grepl(
        "phase4_build_canonical_pipeline_result(",
        pipeline_body,
        fixed = TRUE
      )
    )

    testthat::expect_false(
      grepl(
        "biological_evidence_shadow",
        pipeline_body,
        fixed = TRUE
      )
    )

    testthat::expect_false(
      grepl(
        "phase4_shadow_evidence",
        pipeline_body,
        fixed = TRUE
      )
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
  }
)

testthat::test_that(
  "canonical GraphML attributes exclude legacy label fields",
  {
    nodes <- phase4_test_canonical_node_annotations()

    final_priorities <- data.frame(
      STRING_id = "9606.ENSP1",
      stringsAsFactors = FALSE
    )

    candidate_evidence <- data.frame(
      STRING_id = c("9606.ENSP1", "9606.ENSP2"),
      priority_status = c("final_priority", "extended_review_ready"),
      stringsAsFactors = FALSE
    )

    attributes <- phase4_build_canonical_graphml_attributes(
      node_annotations = nodes,
      final_priorities = final_priorities,
      candidate_evidence = candidate_evidence
    )

    testthat::expect_true(
      all(
        phase4_validate_canonical_graphml_attributes(
          attributes
        )$status == "PASS"
      )
    )

    testthat::expect_false(
      any(
        CANCERPPIR_LEGACY_ANNOTATION_FIELDS %in%
          names(attributes)
      )
    )

    testthat::expect_identical(
      attributes$cytoscape_module_label,
      attributes$module_primary_interpretation
    )

    testthat::expect_identical(
      attributes$pvalue[[1L]],
      CANCERPPIR_GRAPHML_PVALUE_FLOOR
    )

    graph <- igraph::make_empty_graph(
      n = 2L,
      directed = FALSE
    )

    graph <- igraph::set_vertex_attr(
      graph,
      "name",
      value = nodes$STRING_id
    )

    graph <- phase4_apply_canonical_graphml_attributes(
      graph,
      attributes
    )

    graphml_file <- tempfile(
      fileext = ".graphml"
    )

    on.exit(
      unlink(graphml_file),
      add = TRUE
    )

    igraph::write_graph(
      graph,
      graphml_file,
      format = "graphml"
    )

    imported <- igraph::read_graph(
      graphml_file,
      format = "graphml"
    )

    imported_fields <- igraph::vertex_attr_names(
      imported
    )

    testthat::expect_true(
      all(
        c(
          "module_primary_interpretation",
          "candidate_eligibility",
          "annotation_schema_version",
          "graphml_schema_version"
        ) %in% imported_fields
      )
    )

    testthat::expect_false(
      any(
        CANCERPPIR_LEGACY_ANNOTATION_FIELDS %in%
          imported_fields
      )
    )
  }
)

testthat::test_that(
  "canonical pipeline result has one explicit evidence source",
  {
    nodes <- phase4_test_canonical_node_annotations()
    modules <- phase4_test_canonical_module_annotations()

    evidence <- list(
      module_annotations = modules,
      module_rule_evidence = data.frame(),
      significant_module_terms = data.frame(),
      node_annotations = nodes,
      validation = data.frame(
        check_id = "fixture_validation",
        status = "PASS",
        stringsAsFactors = FALSE
      )
    )

    final_priorities <- data.frame(
      STRING_id = "9606.ENSP1",
      stringsAsFactors = FALSE
    )

    candidate_evidence <- data.frame(
      STRING_id = c("9606.ENSP1", "9606.ENSP2"),
      priority_status = c("final_priority", "extended_review_ready"),
      stringsAsFactors = FALSE
    )

    attributes <- phase4_build_canonical_graphml_attributes(
      nodes,
      final_priorities,
      candidate_evidence
    )

    graph <- igraph::make_empty_graph(
      n = 2L,
      directed = FALSE
    )

    graph <- igraph::set_vertex_attr(
      graph,
      "name",
      value = nodes$STRING_id
    )

    graph <- phase4_apply_canonical_graphml_attributes(
      graph,
      attributes
    )

    result <- phase4_build_canonical_pipeline_result(
      output_dir = tempdir(),
      graph = graph,
      biological_evidence = evidence,
      analytical_report_tables = list(
        "Final priorities" = final_priorities,
        "Module priorities" = data.frame(
          module_id = c("1", "2"),
          stringsAsFactors = FALSE
        ),
        "Candidate evidence" = candidate_evidence
      ),
      analytical_report_validation = data.frame(
        check_id = "analytical",
        status = "PASS",
        stringsAsFactors = FALSE
      ),
      graphml_validation =
        phase4_validate_canonical_graphml_attributes(
          attributes
        ),
      graph_summary = data.frame(),
      mapping_summary = data.frame(),
      files = c(
        analytical_report = "analytical.xlsx",
        technical_report = "technical.xlsx",
        string_links = "STRING_links.txt",
        graphml = "network.graphml"
      ),
      compatibility = list(
        status = "deprecated_compatibility_only"
      )
    )

    testthat::expect_s3_class(
      result,
      "cancerppir_result"
    )

    testthat::expect_true(
      all(
        phase4_validate_canonical_pipeline_result(
          result
        )$status == "PASS"
      )
    )

    testthat::expect_false(
      "biological_evidence_shadow" %in%
        names(result)
    )

    testthat::expect_identical(
      result$schema_versions$pipeline_result,
      CANCERPPIR_PIPELINE_RESULT_SCHEMA_VERSION
    )
  }
)
