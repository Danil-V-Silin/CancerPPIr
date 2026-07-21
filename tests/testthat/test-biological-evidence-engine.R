project_root <- Sys.getenv(
  "CANCERPPIR_PROJECT_ROOT",
  unset = normalizePath(
    file.path("..", ".."),
    winslash = "/",
    mustWork = TRUE
  )
)

source(
  file.path(
    project_root,
    "R",
    "04a_biological_evidence_engine.R"
  ),
  local = FALSE
)

testthat::test_that(
  "only statistically significant specific terms support interpretation",
  {
    enrichment <- data.frame(
      category = c("Process", "Process", "Process"),
      term_id = c("T1", "T2", "T3"),
      description = c(
        "immunoglobulin production",
        "phagocytosis",
        "Signal transduction"
      ),
      fdr = c(0.001, 0.20, 0.0001),
      genes = c(
        "MZB1;JCHAIN",
        "IGLL5",
        "MZB1"
      ),
      stringsAsFactors = FALSE
    )

    observed <- phase4_significant_specific_terms(
      enrichment
    )

    testthat::expect_identical(
      observed$term_id,
      "T1"
    )

    testthat::expect_true(
      all(observed$fdr <= 0.05)
    )

    testthat::expect_false(
      any(observed$is_generic)
    )
  }
)

testthat::test_that(
  "B-cell and plasma-cell evidence is not misclassified as myeloid",
  {
    genes <- c(
      "MZB1", "JCHAIN", "TNFRSF17", "IRF4",
      "IGLL5", "IGHV3-11", "IGHV3-15",
      "IGHV1-3", "CD74", "HLA-DRA"
    )

    enrichment <- data.frame(
      category = c("GO", "GO", "Reactome"),
      term_id = c("GO:0019731", "GO:0006959", "R-HSA-BCR"),
      description = c(
        "antibacterial humoral response",
        "humoral immune response",
        "B cell receptor signaling"
      ),
      fdr = c(0.002, 0.004, 0.008),
      genes = c(
        "JCHAIN;IGLL5",
        "MZB1;JCHAIN;TNFRSF17",
        "IGLL5;CD74"
      ),
      stringsAsFactors = FALSE
    )

    result <- phase4_annotate_module_evidence(
      genes = genes,
      enrichment = enrichment,
      module_id = 2
    )

    summary <- result$summary

    testthat::expect_identical(
      summary$lineage,
      "plasma_cell_associated"
    )

    testthat::expect_identical(
      summary$state,
      "immunoglobulin_secretion"
    )

    testthat::expect_false(
      grepl(
        "myeloid",
        summary$primary_interpretation,
        ignore.case = TRUE
      )
    )

    testthat::expect_match(
      summary$positive_marker_genes,
      "MZB1"
    )

    testthat::expect_match(
      summary$positive_marker_genes,
      "JCHAIN"
    )

    testthat::expect_match(
      summary$evidence_rationale,
      "not an estimate of cell abundance",
      fixed = TRUE
    )

    myeloid_row <- result$rule_evaluations[
      result$rule_evaluations$rule_id ==
        "myeloid_macrophage_associated",
      ,
      drop = FALSE
    ]

    testthat::expect_false(
      myeloid_row$eligible[[1L]]
    )
  }
)

testthat::test_that(
  "myeloid antigen-presentation and complement evidence remains specific",
  {
    genes <- c(
      "TYROBP", "FCER1G", "CTSS", "LILRB2",
      "FCGR3A", "AIF1", "C1QA", "C1QB",
      "C1QC", "HLA-DRA", "HLA-DRB1", "CD74"
    )

    enrichment <- data.frame(
      category = c("GO", "GO", "Reactome"),
      term_id = c("GO:0019882", "GO:0006958", "R-HSA-FCGR"),
      description = c(
        "antigen processing and presentation",
        "complement activation, classical pathway",
        "FC receptor signaling"
      ),
      fdr = c(0.0005, 0.001, 0.009),
      genes = c(
        "HLA-DRA;HLA-DRB1;CD74;CTSS",
        "C1QA;C1QB;C1QC",
        "FCER1G;FCGR3A;TYROBP"
      ),
      stringsAsFactors = FALSE
    )

    result <- phase4_annotate_module_evidence(
      genes = genes,
      enrichment = enrichment,
      module_id = 8
    )

    summary <- result$summary

    testthat::expect_identical(
      summary$lineage,
      "myeloid_macrophage_associated"
    )

    testthat::expect_identical(
      summary$state,
      "antigen_presentation"
    )

    testthat::expect_match(
      summary$significant_supporting_terms,
      "complement activation"
    )

    testthat::expect_true(
      summary$priority_eligible
    )
  }
)

testthat::test_that(
  "Y-linked modules are technical covariate signatures",
  {
    genes <- c(
      "RPS4Y1", "EIF1AY", "KDM5D", "ZFY",
      "DDX3Y", "UTY", "USP9Y"
    )

    result <- phase4_annotate_module_evidence(
      genes = genes,
      enrichment = NULL,
      module_id = 4
    )

    summary <- result$summary

    testthat::expect_identical(
      summary$interpretation_class,
      "technical_or_covariate"
    )

    testthat::expect_identical(
      result$technical_signature$signature_id,
      "Y_chromosome_associated_signature"
    )

    testthat::expect_false(
      summary$priority_eligible
    )

    testthat::expect_match(
      summary$warning,
      "not_eligible_for_automatic_biological_priority"
    )
  }
)

testthat::test_that(
  "conflicting lineage evidence is reported rather than forced",
  {
    genes <- c(
      "CD3D", "CD3E", "CD247", "CD8A",
      "TYROBP", "FCER1G", "LILRB2", "CTSS"
    )

    enrichment <- data.frame(
      category = c("GO", "GO"),
      term_id = c("T_CELL", "MYELOID"),
      description = c(
        "T cell receptor signaling",
        "myeloid leukocyte activation"
      ),
      fdr = c(0.003, 0.004),
      genes = c(
        "CD3D;CD3E;CD247",
        "TYROBP;FCER1G;LILRB2;CTSS"
      ),
      stringsAsFactors = FALSE
    )

    result <- phase4_annotate_module_evidence(
      genes = genes,
      enrichment = enrichment,
      module_id = 99,
      conflict_delta = 0.15
    )

    summary <- result$summary

    testthat::expect_identical(
      summary$lineage,
      "mixed_lineage_associated"
    )

    testthat::expect_true(
      summary$conflict_detected
    )

    testthat::expect_false(
      summary$priority_eligible
    )
  }
)

testthat::test_that(
  "special entities are separated from canonical candidate eligibility",
  {
    genes <- c(
      "LOC102723407",
      "IGLL5",
      "TRBC1",
      "RPS4Y1",
      "CD34"
    )

    classes <- vapply(
      genes,
      phase4_classify_entity,
      FUN.VALUE = character(1)
    )

    eligibility <- vapply(
      classes,
      phase4_candidate_eligibility,
      FUN.VALUE = character(1)
    )

    testthat::expect_identical(
      unname(classes),
      c(
        "predicted_LOC",
        "immunoglobulin_locus",
        "T_cell_receptor_locus",
        "Y_chromosome_associated",
        "canonical_or_unclassified_protein_coding"
      )
    )

    testthat::expect_identical(
      unname(eligibility),
      c(
        "network_evidence_only",
        "network_evidence_only",
        "network_evidence_only",
        "excluded_from_automatic_priority",
        "review_ready_canonical"
      )
    )
  }
)
