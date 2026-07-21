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


testthat::test_that(
  "strong process evidence resolves a module even when lineage is unresolved",
  {
    genes <- c(
      "TOP2A", "MKI67", "CDK1", "FOXM1",
      "CDC20", "CCNB1", "KIF11", "UBE2C"
    )

    enrichment <- data.frame(
      category = c("GO", "Reactome"),
      term_id = c("MITOSIS", "CELL_CYCLE"),
      description = c(
        "mitotic chromosome segregation",
        "cell cycle"
      ),
      fdr = c(0.0001, 0.0002),
      genes = c(
        "TOP2A;MKI67;CDK1;CDC20;CCNB1",
        "FOXM1;KIF11;UBE2C"
      ),
      stringsAsFactors = FALSE
    )

    result <- phase4_annotate_module_evidence(
      genes = genes,
      enrichment = enrichment,
      module_id = 200
    )

    summary <- result$summary

    testthat::expect_identical(
      summary$interpretation_class,
      "biological"
    )

    testthat::expect_identical(
      summary$interpretation_scope,
      "process_supported_lineage_unresolved"
    )

    testthat::expect_identical(
      summary$lineage,
      "unresolved_lineage"
    )

    testthat::expect_identical(
      summary$process,
      "mitotic_proliferation"
    )

    testthat::expect_false(
      grepl(
        "unresolved biological context",
        summary$primary_interpretation,
        fixed = TRUE
      )
    )

    testthat::expect_true(
      summary$priority_eligible
    )
  }
)

testthat::test_that(
  "strong state evidence resolves a module without forcing a lineage",
  {
    genes <- c(
      "HLA-DRA", "HLA-DRB1", "HLA-DPA1",
      "HLA-DPB1", "CD74", "CIITA"
    )

    enrichment <- data.frame(
      category = "GO",
      term_id = "ANTIGEN",
      description = "antigen processing and presentation",
      fdr = 0.0005,
      genes = "HLA-DRA;HLA-DRB1;HLA-DPA1;HLA-DPB1;CD74;CIITA",
      stringsAsFactors = FALSE
    )

    result <- phase4_annotate_module_evidence(
      genes = genes,
      enrichment = enrichment,
      module_id = 201
    )

    summary <- result$summary

    testthat::expect_identical(
      summary$interpretation_class,
      "biological"
    )

    testthat::expect_identical(
      summary$interpretation_scope,
      "state_supported_lineage_unresolved"
    )

    testthat::expect_identical(
      summary$state,
      "antigen_presentation"
    )

    testthat::expect_true(
      summary$priority_eligible
    )
  }
)

testthat::test_that(
  "specific marker-only neuroendocrine evidence is reportable but not automatically prioritized",
  {
    genes <- c(
      "ASCL1", "INSM1", "SOX2", "ELAVL4", "STMN2"
    )

    result <- phase4_annotate_module_evidence(
      genes = genes,
      enrichment = NULL,
      module_id = 202
    )

    summary <- result$summary

    testthat::expect_identical(
      summary$interpretation_class,
      "biological"
    )

    testthat::expect_identical(
      summary$lineage,
      "neuroendocrine_associated"
    )

    testthat::expect_false(
      summary$priority_eligible
    )

    testthat::expect_match(
      summary$warning,
      "marker_only_interpretation_not_eligible_for_automatic_priority"
    )
  }
)

testthat::test_that(
  "erythroid signatures are recognized by universal rules",
  {
    genes <- c(
      "HBB", "SLC4A1", "ALAS2", "EPB42",
      "AHSP", "CA1", "HBD", "HBG2"
    )

    enrichment <- data.frame(
      category = c("GO", "GO"),
      term_id = c("ERYTHROCYTE", "OXYGEN"),
      description = c(
        "erythrocyte differentiation",
        "oxygen transport"
      ),
      fdr = c(0.0002, 0.0003),
      genes = c(
        "HBB;SLC4A1;ALAS2;EPB42;AHSP",
        "HBB;HBD;HBG2"
      ),
      stringsAsFactors = FALSE
    )

    result <- phase4_annotate_module_evidence(
      genes = genes,
      enrichment = enrichment,
      module_id = 203
    )

    summary <- result$summary

    testthat::expect_identical(
      summary$lineage,
      "erythroid_associated"
    )

    testthat::expect_identical(
      summary$process,
      "heme_oxygen_transport"
    )

    testthat::expect_true(
      summary$priority_eligible
    )
  }
)

testthat::test_that(
  "secretory epithelial signatures are recognized without sample-specific logic",
  {
    genes <- c(
      "SCGB2A2", "PIP", "DCD", "AQP5",
      "MUCL1", "MUC7", "TMPRSS2", "CA6"
    )

    enrichment <- data.frame(
      category = c("GO", "Process"),
      term_id = c("SECRETORY", "EPITHELIAL"),
      description = c(
        "regulated secretory pathway",
        "epithelial cell differentiation"
      ),
      fdr = c(0.002, 0.004),
      genes = c(
        "SCGB2A2;PIP;DCD;AQP5",
        "MUCL1;MUC7;TMPRSS2;CA6"
      ),
      stringsAsFactors = FALSE
    )

    result <- phase4_annotate_module_evidence(
      genes = genes,
      enrichment = enrichment,
      module_id = 204
    )

    summary <- result$summary

    testthat::expect_identical(
      summary$lineage,
      "secretory_epithelial_associated"
    )

    testthat::expect_identical(
      summary$compartment,
      "epithelial"
    )
  }
)

testthat::test_that(
  "developmental HOX programmes are represented as processes rather than forced lineages",
  {
    genes <- c(
      "HOXA7", "HOXA9", "HOXA10", "HOXA11",
      "HOXD10", "HOXD11", "HOXD12", "PRRX1",
      "FZD10", "EMX2"
    )

    enrichment <- data.frame(
      category = c("GO", "GO"),
      term_id = c("PATTERN", "REGION"),
      description = c(
        "anterior posterior pattern specification",
        "regionalization"
      ),
      fdr = c(0.0004, 0.0008),
      genes = c(
        "HOXA7;HOXA9;HOXA10;HOXD10",
        "HOXD11;HOXD12;PRRX1;EMX2"
      ),
      stringsAsFactors = FALSE
    )

    result <- phase4_annotate_module_evidence(
      genes = genes,
      enrichment = enrichment,
      module_id = 205
    )

    summary <- result$summary

    testthat::expect_identical(
      summary$interpretation_class,
      "biological"
    )

    testthat::expect_identical(
      summary$process,
      "developmental_patterning"
    )

    testthat::expect_identical(
      summary$lineage,
      "unresolved_lineage"
    )
  }
)

testthat::test_that(
  "broad leukocyte modules can be reported without pretending to know a specific lineage",
  {
    genes <- c(
      "PTPRC", "LCP1", "LCP2", "PLEK",
      "LAPTM5", "CD48", "CD53", "NCKAP1L",
      "INPP5D", "SYK", "FGR", "SRGN"
    )

    enrichment <- data.frame(
      category = c("GO", "Process"),
      term_id = c("LEUKOCYTE", "IMMUNE_RECEPTOR"),
      description = c(
        "leukocyte activation",
        "immune receptor signaling"
      ),
      fdr = c(0.0003, 0.0007),
      genes = c(
        "PTPRC;LCP1;LCP2;PLEK;LAPTM5;CD48",
        "INPP5D;SYK;FGR;NCKAP1L"
      ),
      stringsAsFactors = FALSE
    )

    result <- phase4_annotate_module_evidence(
      genes = genes,
      enrichment = enrichment,
      module_id = 206
    )

    summary <- result$summary

    testthat::expect_identical(
      summary$lineage,
      "immune_leukocyte_associated"
    )

    testthat::expect_match(
      summary$primary_interpretation,
      "immune-leukocyte-associated"
    )
  }
)
