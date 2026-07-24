phase4_analytical_test_fixture <- function() {
  node_annotations <- data.frame(
    STRING_id = paste0(
      "9606.ENSP",
      sprintf(
        "%011d",
        1:6
      )
    ),
    gene = c(
      "LOC_TEST",
      "GENE1",
      "GENE2",
      "IGHV_TEST",
      "GENE3",
      "GENE4"
    ),
    pvalue = c(
      1e-30,
      1e-20,
      1e-12,
      1e-18,
      1e-6,
      0.01
    ),
    logFC = c(
      8,
      6,
      5,
      7,
      2,
      -1
    ),
    abs_logFC = c(
      8,
      6,
      5,
      7,
      2,
      1
    ),
    neg_log10_pvalue = c(
      30,
      20,
      12,
      18,
      6,
      2
    ),
    degree = c(
      12,
      11,
      9,
      8,
      3,
      1
    ),
    betweenness = c(
      0.50,
      0.45,
      0.30,
      0.20,
      0.05,
      0.00
    ),
    closeness = c(
      0.50,
      0.49,
      0.47,
      0.45,
      0.30,
      0.20
    ),
    harmonic_closeness = c(
      0.45,
      0.44,
      0.42,
      0.40,
      0.25,
      0.15
    ),
    stress_centrality = c(
      1200,
      1100,
      800,
      600,
      50,
      0
    ),
    local_clustering = c(
      0.2,
      0.3,
      0.4,
      0.5,
      0.1,
      0
    ),
    component = c(
      1L,
      1L,
      1L,
      1L,
      2L,
      3L
    ),
    in_largest_component = c(
      TRUE,
      TRUE,
      TRUE,
      TRUE,
      FALSE,
      FALSE
    ),
    community_louvain = c(
      2L,
      1L,
      1L,
      2L,
      3L,
      3L
    ),
    entity_class = c(
      "predicted_LOC",
      "canonical_or_unclassified_protein_coding",
      "canonical_or_unclassified_protein_coding",
      "immunoglobulin_locus",
      "canonical_or_unclassified_protein_coding",
      "canonical_or_unclassified_protein_coding"
    ),
    candidate_eligibility = c(
      "network_evidence_only",
      "review_ready_canonical",
      "review_ready_canonical",
      "excluded_from_automatic_priority",
      "review_ready_canonical",
      "review_ready_canonical"
    ),
    module_interpretation_class = c(
      "technical_or_covariate",
      "biological",
      "biological",
      "technical_or_covariate",
      "unresolved",
      "unresolved"
    ),
    module_interpretation_scope = c(
      "technical_or_covariate",
      "lineage_supported",
      "lineage_supported",
      "technical_or_covariate",
      "process_supported_lineage_unresolved",
      "process_supported_lineage_unresolved"
    ),
    module_compartment = c(
      "not_applicable",
      "immune",
      "immune",
      "not_applicable",
      "multi-compartment",
      "multi-compartment"
    ),
    module_lineage = c(
      "not_applicable",
      "myeloid_macrophage_associated",
      "myeloid_macrophage_associated",
      "not_applicable",
      "unresolved_lineage",
      "unresolved_lineage"
    ),
    module_state = c(
      "not_assigned",
      "complement_associated",
      "complement_associated",
      "not_assigned",
      "not_assigned",
      "not_assigned"
    ),
    module_process = c(
      "not_assigned",
      "antigen_presentation",
      "antigen_presentation",
      "not_assigned",
      "developmental_patterning",
      "developmental_patterning"
    ),
    module_primary_interpretation = c(
      "Y-chromosome-associated technical/covariate signature",
      "myeloid/macrophage-associated / complement-associated / antigen-presentation",
      "myeloid/macrophage-associated / complement-associated / antigen-presentation",
      "Y-chromosome-associated technical/covariate signature",
      "developmental-patterning/HOX-associated",
      "developmental-patterning/HOX-associated"
    ),
    module_secondary_themes = c(
      "",
      "innate immunity",
      "innate immunity",
      "",
      "",
      ""
    ),
    module_confidence = c(
      "technical_or_covariate",
      "high",
      "high",
      "technical_or_covariate",
      "moderate",
      "moderate"
    ),
    module_priority_eligible = c(
      FALSE,
      TRUE,
      TRUE,
      FALSE,
      FALSE,
      FALSE
    ),
    module_positive_marker_genes = c(
      "",
      "GENE1; GENE2",
      "GENE1; GENE2",
      "",
      "GENE3",
      "GENE3"
    ),
    module_supportive_marker_genes = c(
      "",
      "GENE5",
      "GENE5",
      "",
      "",
      ""
    ),
    module_term_supporting_genes = c(
      "",
      "GENE1; GENE2",
      "GENE1; GENE2",
      "",
      "",
      ""
    ),
    module_significant_supporting_terms = c(
      "",
      "Innate immune response | Antigen processing and presentation",
      "Innate immune response | Antigen processing and presentation",
      "",
      "",
      ""
    ),
    module_best_supporting_fdr = c(
      NA,
      0.001,
      0.001,
      NA,
      NA,
      NA
    ),
    module_conflict_detected = c(
      FALSE,
      FALSE,
      FALSE,
      FALSE,
      FALSE,
      FALSE
    ),
    module_warning = c(
      "technical_or_covariate_signature_not_eligible_for_automatic_biological_priority",
      "no_warning",
      "no_warning",
      "technical_or_covariate_signature_not_eligible_for_automatic_biological_priority",
      "lineage_not_resolved_state_or_process_evidence_only",
      "lineage_not_resolved_state_or_process_evidence_only"
    ),
    module_evidence_rationale = c(
      "Technical/covariate signature.",
      "Specific marker and term evidence supports the module.",
      "Specific marker and term evidence supports the module.",
      "Technical/covariate signature.",
      "Process evidence is present but lineage is unresolved.",
      "Process evidence is present but lineage is unresolved."
    ),
    stringsAsFactors = FALSE
  )

  node_annotations$candidate_score <- rowMeans(
    cbind(
      minmax(
        node_annotations$degree
      ),
      minmax(
        node_annotations$betweenness
      ),
      minmax(
        log1p(
          node_annotations$stress_centrality
        )
      ),
      minmax(
        node_annotations$abs_logFC
      ),
      minmax(
        node_annotations$neg_log10_pvalue
      )
    ),
    na.rm = TRUE
  )

  module_annotations <- data.frame(
    community_louvain = c(
      1L,
      2L,
      3L
    ),
    network_node_count = c(
      2L,
      2L,
      2L
    ),
    representative_genes = c(
      "GENE1;GENE2",
      "LOC_TEST;IGHV_TEST",
      "GENE3;GENE4"
    ),
    module_id = c(
      "1",
      "2",
      "3"
    ),
    module_size = c(
      2L,
      2L,
      2L
    ),
    interpretation_class = c(
      "biological",
      "technical_or_covariate",
      "unresolved"
    ),
    interpretation_scope = c(
      "lineage_supported",
      "technical_or_covariate",
      "process_supported_lineage_unresolved"
    ),
    compartment = c(
      "immune",
      "not_applicable",
      "multi-compartment"
    ),
    lineage = c(
      "myeloid_macrophage_associated",
      "not_applicable",
      "unresolved_lineage"
    ),
    conflicting_lineage_rules = c(
      "",
      "",
      ""
    ),
    conflicting_lineage_labels = c(
      "",
      "",
      ""
    ),
    state = c(
      "complement_associated",
      "not_assigned",
      "not_assigned"
    ),
    process = c(
      "antigen_presentation",
      "not_assigned",
      "developmental_patterning"
    ),
    primary_interpretation = c(
      "myeloid/macrophage-associated / complement-associated / antigen-presentation",
      "Y-chromosome-associated technical/covariate signature",
      "developmental-patterning/HOX-associated"
    ),
    secondary_themes = c(
      "innate immunity",
      "",
      ""
    ),
    confidence = c(
      "high",
      "technical_or_covariate",
      "moderate"
    ),
    priority_eligible = c(
      TRUE,
      FALSE,
      FALSE
    ),
    positive_marker_genes = c(
      "GENE1; GENE2",
      "",
      "GENE3"
    ),
    supportive_marker_genes = c(
      "GENE5",
      "",
      ""
    ),
    term_supporting_genes = c(
      "GENE1; GENE2",
      "",
      ""
    ),
    significant_supporting_terms = c(
      "Innate immune response | Antigen processing and presentation",
      "",
      ""
    ),
    best_supporting_fdr = c(
      0.001,
      NA,
      NA
    ),
    conflict_detected = c(
      FALSE,
      FALSE,
      FALSE
    ),
    warning = c(
      "no_warning",
      "technical_or_covariate_signature_not_eligible_for_automatic_biological_priority",
      "lineage_not_resolved_state_or_process_evidence_only"
    ),
    evidence_rationale = c(
      "Specific marker and term evidence supports the module.",
      "Technical/covariate signature.",
      "Process evidence is present but lineage is unresolved."
    ),
    stringsAsFactors = FALSE
  )

  significant_terms <- data.frame(
    community_louvain = c(
      1L,
      1L
    ),
    module_id = c(
      "1",
      "1"
    ),
    source = c(
      "Biological Process (Gene Ontology)",
      "Reactome Pathways"
    ),
    term_id = c(
      "GO:0045087",
      "R-HSA-168256"
    ),
    description = c(
      "Innate immune response",
      "Immune System"
    ),
    fdr = c(
      0.001,
      0.01
    ),
    supporting_genes = c(
      "GENE1;GENE2",
      "GENE1;GENE2"
    ),
    is_significant = c(
      TRUE,
      TRUE
    ),
    is_generic = c(
      FALSE,
      FALSE
    ),
    stringsAsFactors = FALSE
  )

  graph_summary <- data.frame(
    metric = c(
      "nodes",
      "edges",
      "components",
      "largest_component_nodes",
      "largest_component_fraction",
      "density",
      "average_degree",
      "global_clustering",
      "average_shortest_path_lcc",
      "diameter_lcc",
      "radius_lcc",
      "louvain_communities",
      "louvain_modularity",
      "string_score_threshold"
    ),
    value = c(
      6,
      8,
      3,
      4,
      4 / 6,
      0.5333,
      2.6667,
      0.4,
      1.5,
      3,
      2,
      3,
      0.42,
      400
    ),
    stringsAsFactors = FALSE
  )

  degree_distribution <- data.frame(
    degree = c(
      1L,
      3L,
      8L,
      9L,
      11L,
      12L
    ),
    n_nodes = rep(
      1L,
      6L
    ),
    log10_degree = log10(
      c(
        1,
        3,
        8,
        9,
        11,
        12
      )
    ),
    log10_n_nodes = rep(
      0,
      6L
    ),
    stringsAsFactors = FALSE
  )

  list(
    graph_summary = graph_summary,
    degree_distribution = degree_distribution,
    phase4_evidence = list(
      module_annotations = module_annotations,
      significant_module_terms = significant_terms,
      node_annotations = node_annotations,
      validation = data.frame(
        check_id = c(
          "unique_module_rows",
          "all_nodes_receive_module_annotations"
        ),
        status = c(
          "PASS",
          "PASS"
        ),
        stringsAsFactors = FALSE
      )
    )
  )
}

testthat::test_that(
  "Phase 4 analytical workbook has the exact six-sheet contract",
  {
    fixture <- phase4_analytical_test_fixture()

    report <- build_phase4_analytical_workbook(
      input_rows = 10L,
      mapped_proteins = 6L,
      unmapped_input_rows = 4L,
      mapping_rate_percent = 60,
      graph_summary = fixture$graph_summary,
      score_threshold = 400L,
      top_n = 6L,
      degree_distribution =
        fixture$degree_distribution,
      phase4_evidence =
        fixture$phase4_evidence
    )

    testthat::expect_identical(
      names(
        report$sheets
      ),
      CANCERPPIR_ANALYTICAL_SHEET_NAMES
    )

    expected_columns <-
      phase4_expected_analytical_columns()

    for (sheet_name in names(
      expected_columns
    )) {
      testthat::expect_identical(
        names(
          report$sheets[[sheet_name]]
        ),
        expected_columns[[sheet_name]],
        info = sheet_name
      )
    }

    testthat::expect_true(
      all(
        report$validation$status ==
          "PASS"
      )
    )
  }
)

testthat::test_that(
  "automatic priorities respect entity and module eligibility",
  {
    fixture <- phase4_analytical_test_fixture()

    report <- build_phase4_analytical_workbook(
      input_rows = 10L,
      mapped_proteins = 6L,
      unmapped_input_rows = 4L,
      mapping_rate_percent = 60,
      graph_summary = fixture$graph_summary,
      score_threshold = 400L,
      top_n = 6L,
      degree_distribution =
        fixture$degree_distribution,
      phase4_evidence =
        fixture$phase4_evidence
    )

    final_priorities <- report$sheets[[
      "Final priorities"
    ]]

    candidate_evidence <- report$sheets[[
      "Candidate evidence"
    ]]

    testthat::expect_setequal(
      final_priorities$gene,
      c(
        "GENE1",
        "GENE2"
      )
    )

    testthat::expect_false(
      "LOC_TEST" %in%
        final_priorities$gene
    )

    testthat::expect_true(
      "LOC_TEST" %in%
        candidate_evidence$gene
    )

    loc_row <- candidate_evidence[
      candidate_evidence$gene ==
        "LOC_TEST",
      ,
      drop = FALSE
    ]

    testthat::expect_identical(
      loc_row$candidate_eligibility[[1L]],
      "network_evidence_only"
    )
  }
)

testthat::test_that(
  "candidate score components reconstruct the production score",
  {
    fixture <- phase4_analytical_test_fixture()

    report <- build_phase4_analytical_workbook(
      input_rows = 10L,
      mapped_proteins = 6L,
      unmapped_input_rows = 4L,
      mapping_rate_percent = 60,
      graph_summary = fixture$graph_summary,
      score_threshold = 400L,
      top_n = 6L,
      degree_distribution =
        fixture$degree_distribution,
      phase4_evidence =
        fixture$phase4_evidence
    )

    testthat::expect_true(
      max(
        report$candidate_score_audit$
          score_reconstruction_error,
        na.rm = TRUE
      ) <= 1e-12
    )
  }
)

testthat::test_that(
  "six-sheet workbook can be written and reopened",
  {
    testthat::skip_if_not_installed(
      "openxlsx"
    )

    fixture <- phase4_analytical_test_fixture()

    report <- build_phase4_analytical_workbook(
      input_rows = 10L,
      mapped_proteins = 6L,
      unmapped_input_rows = 4L,
      mapping_rate_percent = 60,
      graph_summary = fixture$graph_summary,
      score_threshold = 400L,
      top_n = 6L,
      degree_distribution =
        fixture$degree_distribution,
      phase4_evidence =
        fixture$phase4_evidence
    )

    output_file <- tempfile(
      fileext = ".xlsx"
    )

    on.exit(
      unlink(
        output_file
      ),
      add = TRUE
    )

    write_readable_xlsx(
      output_file,
      report$sheets
    )

    testthat::expect_true(
      file.exists(
        output_file
      )
    )

    testthat::expect_identical(
      openxlsx::getSheetNames(
        output_file
      ),
      CANCERPPIR_ANALYTICAL_SHEET_NAMES
    )
  }
)
