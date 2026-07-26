# CancerPPIr: module_labeling
#
# Architecture checkpoint 2.8.
#
# Functions below were extracted from cancerppir.R without semantic rewriting.

##############################################################################
# label_module_by_markers - extracted from cancerppir.R lines 221-254
##############################################################################
label_module_by_markers <- function(genes, max_labels = 3L) {
  g <- toupper(unique(na.omit(genes)))

  hits <- lapply(marker_sets, function(markers) {
    intersect(g, markers)
  })

  n_hits <- vapply(hits, length, integer(1))
  n_hits <- n_hits[n_hits > 0]

  if (!length(n_hits)) {
    return(list(
      marker_summary = "no_marker_set_match",
      clean_label = "unassigned_module",
      evidence = NA_character_
    ))
  }

  n_hits <- sort(n_hits, decreasing = TRUE)
  selected <- head(names(n_hits), max_labels)
  best <- selected[[1]]

  marker_summary <- paste0(selected, "(", n_hits[selected], ")")
  evidence <- paste(
    vapply(selected, function(x) paste(head(hits[[x]], 8), collapse = ","), character(1)),
    collapse = " | "
  )

  list(
    marker_summary = paste(marker_summary, collapse = "; "),
    clean_label = unname(module_clean_labels[[best]]),
    evidence = evidence
  )
}

##############################################################################
# clean_module_label_from_terms - extracted from cancerppir.R lines 256-297
##############################################################################
clean_module_label_from_terms <- function(terms, fallback_label = "unassigned_module") {
  txt <- tolower(paste(na.omit(as.character(terms)), collapse = " | "))

  if (nzchar(txt)) {
    if (grepl("mhc|antigen processing|antigen presentation|class ii", txt)) {
      return("MHC_class_II_antigen_presentation_module")
    }
    if (grepl("chemokine|cytokine|ccr|cxcr|cell chemotaxis|leukocyte migration", txt)) {
      return("chemokine_cytokine_signaling_module")
    }
    if (grepl("complement|c1q|classical pathway", txt)) {
      return("C1q_complement_macrophage_module")
    }
    if (grepl("extracellular matrix|collagen|ecm|stromal|matrix organization|cell adhesion", txt)) {
      return("stromal_ECM_remodeling_module")
    }
    if (grepl("interferon|antiviral|defense response to virus|response to virus", txt)) {
      return("interferon_response_module")
    }
    if (grepl("t cell mediated cytotoxicity|cytotoxic|granzyme|natural killer", txt)) {
      return("T_cell_cytotoxic_module")
    }
    if (grepl("t cell activation|adaptive immunity|adaptive immune|lymphocyte activation", txt)) {
      return("T_cell_adaptive_immune_module")
    }
    if (grepl("myeloid|macrophage|phagocyt|monocyte|fc receptor|rho gtpase|leukocyte activation", txt)) {
      return("myeloid_leukocyte_signaling_module")
    }
    if (grepl("mitotic|cell cycle|chromosome segregation|dna replication", txt)) {
      return("cell_cycle_mitotic_module")
    }
    if (grepl("lipid|fatty acid|organic acid|small molecule metabolic|metabolic process", txt)) {
      return("metabolic_module")
    }
  }

  if (!is.na(fallback_label) && nzchar(fallback_label)) {
    return(fallback_label)
  }

  "unassigned_module"
}

##############################################################################
# max_marker_overlap_count - extracted from cancerppir.R lines 1157-1170
##############################################################################
max_marker_overlap_count <- function(marker_summary) {
  marker_summary <- as.character(marker_summary)
  vapply(marker_summary, function(z) {
    if (is.na(z) || !nzchar(z)) {
      return(0L)
    }
    nums <- regmatches(z, gregexpr("\\(([0-9]+)\\)", z, perl = TRUE))[[1]]
    if (!length(nums)) {
      return(0L)
    }
    nums <- as.integer(gsub("[^0-9]", "", nums))
    max(nums, na.rm = TRUE)
  }, integer(1))
}

##############################################################################
# has_assigned_label - extracted from cancerppir.R lines 1172-1174
##############################################################################
has_assigned_label <- function(x) {
  !is.na(x) & nzchar(x) & x != "unassigned_module"
}

##############################################################################
# label_rulebook_table - extracted from cancerppir.R lines 1296-1305
##############################################################################
label_rulebook_table <- function() {
  tibble(
    label_id = vapply(label_rulebook, `[[`, character(1), "label_id"),
    fallback_label = vapply(label_rulebook, `[[`, character(1), "fallback_label"),
    marker_patterns = vapply(label_rulebook, function(x) paste(x$marker_patterns, collapse = "; "), character(1)),
    core_term_patterns = vapply(label_rulebook, function(x) paste(x$core_term_patterns, collapse = "; "), character(1)),
    required_specific_patterns = vapply(label_rulebook, function(x) paste(x$required_specific_patterns, collapse = "; "), character(1)),
    supporting_theme = vapply(label_rulebook, `[[`, character(1), "theme")
  )
}

##############################################################################
# matches_any_pattern - extracted from cancerppir.R lines 1307-1316
##############################################################################
matches_any_pattern <- function(text, patterns) {
  if (is.null(patterns) || !length(patterns)) {
    return(FALSE)
  }
  txt <- tolower(paste(na.omit(as.character(text)), collapse = " | "))
  if (!nzchar(txt)) {
    return(FALSE)
  }
  any(vapply(patterns, function(pat) grepl(pat, txt, ignore.case = TRUE, perl = TRUE), logical(1)))
}

##############################################################################
# count_matching_patterns - extracted from cancerppir.R lines 1318-1327
##############################################################################
count_matching_patterns <- function(text, patterns) {
  if (is.null(patterns) || !length(patterns)) {
    return(0L)
  }
  txt <- tolower(paste(na.omit(as.character(text)), collapse = " | "))
  if (!nzchar(txt)) {
    return(0L)
  }
  sum(vapply(patterns, function(pat) grepl(pat, txt, ignore.case = TRUE, perl = TRUE), logical(1)))
}

##############################################################################
# extract_marker_counts - extracted from cancerppir.R lines 1329-1344
##############################################################################
extract_marker_counts <- function(marker_summary) {
  z <- as.character(marker_summary)
  if (is.na(z) || !nzchar(z) || z == "no_marker_set_match") {
    return(stats::setNames(integer(0), character(0)))
  }
  parts <- trimws(unlist(strsplit(z, ";", fixed = TRUE)))
  out <- integer(0)
  for (part in parts) {
    m <- regexec("^([A-Za-z0-9_]+)\\(([0-9]+)\\)", part, perl = TRUE)
    hit <- regmatches(part, m)[[1]]
    if (length(hit) == 3L) {
      out[hit[[2]]] <- as.integer(hit[[3]])
    }
  }
  out
}

##############################################################################
# marker_count_for_rule - extracted from cancerppir.R lines 1346-1352
##############################################################################
marker_count_for_rule <- function(marker_summary, marker_patterns) {
  counts <- extract_marker_counts(marker_summary)
  if (!length(counts)) {
    return(0L)
  }
  sum(counts[names(counts) %in% marker_patterns], na.rm = TRUE)
}

##############################################################################
# label_evidence_score - extracted from cancerppir.R lines 1354-1369
##############################################################################
label_evidence_score <- function(marker_count, term_hit_count, required_hit_count,
                                 best_fdr, module_size) {
  score <- 0L
  if (is.finite(marker_count) && marker_count >= 1L) score <- score + 1L
  if (is.finite(marker_count) && marker_count >= 3L) score <- score + 1L
  if (is.finite(term_hit_count) && term_hit_count >= 1L) score <- score + 1L
  if (is.finite(term_hit_count) && term_hit_count >= 3L) score <- score + 1L
  if (is.finite(required_hit_count) && required_hit_count >= 1L) score <- score + 1L
  if (is.finite(best_fdr) && best_fdr <= 0.05) score <- score + 1L
  if (is.finite(best_fdr) && best_fdr <= 0.01) score <- score + 1L
  if (is.finite(module_size) && module_size >= 10L) score <- score + 1L
  if (is.finite(marker_count) && marker_count > 0L && is.finite(term_hit_count) && term_hit_count > 0L) {
    score <- score + 2L
  }
  score
}

##############################################################################
# assign_label_confidence - extracted from cancerppir.R lines 1371-1388
##############################################################################
assign_label_confidence <- function(score, marker_count, term_hit_count, best_fdr,
                                    module_size, final_label_raw) {
  if (!has_assigned_label(final_label_raw)) {
    return("low_unassigned_or_insufficient_evidence")
  }
  significant_terms <- is.finite(best_fdr) && best_fdr <= 0.05 && term_hit_count > 0L
  dplyr::case_when(
    score >= 7L && marker_count > 0L && significant_terms ~
      "high_concordant_marker_and_specific_STRING_evidence",
    score >= 5L && significant_terms ~
      "medium_high_specific_STRING_evidence",
    score >= 4L && marker_count > 0L ~
      "medium_marker_supported",
    score >= 2L ~
      "medium_low_limited_support",
    TRUE ~ "low_unassigned_or_insufficient_evidence"
  )
}

##############################################################################
# label_source_from_counts - extracted from cancerppir.R lines 1390-1399
##############################################################################
label_source_from_counts <- function(marker_count, term_hit_count, best_fdr) {
  marker_ok <- is.finite(marker_count) && marker_count > 0L
  enrich_ok <- is.finite(term_hit_count) && term_hit_count > 0L && is.finite(best_fdr) && best_fdr <= 0.05
  dplyr::case_when(
    marker_ok && enrich_ok ~ "curated_marker_overlap_plus_specific_STRING_enrichment",
    enrich_ok ~ "specific_STRING_enrichment_only",
    marker_ok ~ "curated_marker_overlap_only",
    TRUE ~ "not_assigned"
  )
}

##############################################################################
# supporting_themes_from_evidence - extracted from cancerppir.R lines 1401-1444
##############################################################################
supporting_themes_from_evidence <- function(term_text, marker_summary,
                                            selected_label_id = NA_character_,
                                            max_secondary_themes = 2L) {
  # Keep supporting themes conservative. The final label should not be diluted by
  # every weakly matched biological keyword in broad enrichment terms.
  scored <- lapply(label_rulebook, function(rule) {
    marker_count <- marker_count_for_rule(marker_summary, rule$marker_patterns)
    term_hit_count <- count_matching_patterns(term_text, rule$core_term_patterns)
    required_hit_count <- count_matching_patterns(term_text, rule$required_specific_patterns)
    is_selected <- !is.na(selected_label_id) && identical(rule$label_id, selected_label_id)
    data.frame(
      label_id = rule$label_id,
      theme = rule$theme,
      marker_count = marker_count,
      term_hit_count = term_hit_count,
      required_hit_count = required_hit_count,
      is_selected = is_selected,
      stringsAsFactors = FALSE
    )
  }) %>% bind_rows()

  if (!nrow(scored)) {
    return("not_available")
  }

  selected <- scored %>% filter(is_selected, marker_count > 0L | term_hit_count > 0L | required_hit_count > 0L)
  secondary <- scored %>%
    filter(!is_selected) %>%
    mutate(
      secondary_support_score =
        as.integer(marker_count >= 5L) +
        as.integer(term_hit_count >= 2L) +
        as.integer(required_hit_count >= 1L)
    ) %>%
    filter(secondary_support_score >= 2L) %>%
    arrange(desc(secondary_support_score), desc(marker_count), desc(term_hit_count), desc(required_hit_count)) %>%
    slice_head(n = max_secondary_themes)

  themes <- unique(c(selected$theme, secondary$theme))
  if (!length(themes)) {
    return("not_available")
  }
  paste(themes, collapse = "; ")
}

##############################################################################
# assign_module_label_with_rules - extracted from cancerppir.R lines 1446-1528
##############################################################################
assign_module_label_with_rules <- function(marker_label, marker_summary, term_text,
                                           best_fdr, module_size) {
  evaluations <- lapply(seq_along(label_rulebook), function(i) {
    rule <- label_rulebook[[i]]
    marker_count <- marker_count_for_rule(marker_summary, rule$marker_patterns)
    term_hit_count <- count_matching_patterns(term_text, rule$core_term_patterns)
    required_hit_count <- count_matching_patterns(term_text, rule$required_specific_patterns)
    score <- label_evidence_score(marker_count, term_hit_count, required_hit_count, best_fdr, module_size)
    data.frame(
      rule_index = i,
      label_id = rule$label_id,
      fallback_label = rule$fallback_label,
      marker_count = marker_count,
      term_hit_count = term_hit_count,
      required_hit_count = required_hit_count,
      score = score,
      stringsAsFactors = FALSE
    )
  })
  eval_tbl <- bind_rows(evaluations)

  # Prefer evidence-supported rules; use the rule order only as a deterministic
  # tie-breaker after score, marker evidence, term evidence and required evidence.
  eval_tbl <- eval_tbl %>%
    arrange(desc(score), desc(marker_count), desc(term_hit_count), desc(required_hit_count), rule_index)

  best <- eval_tbl[1, , drop = FALSE]
  if (!nrow(best) || best$score < 2L) {
    return(list(
      final_label_raw = "unassigned_module",
      specific_label_candidate = NA_character_,
      fallback_label = NA_character_,
      label_assignment_mode = "unassigned_insufficient_evidence",
      label_source = "not_assigned",
      label_evidence_score = as.integer(best$score %||% 0L),
      marker_label_evidence_count = 0L,
      term_label_evidence_count = 0L,
      required_specific_evidence_detected = FALSE,
      supporting_biological_themes = supporting_themes_from_evidence(term_text, marker_summary),
      label_confidence = "low_unassigned_or_insufficient_evidence",
      label_warning = "no_reliable_marker_or_specific_STRING_evidence_for_label"
    ))
  }

  # A precise label is allowed when its required specific evidence is present, or
  # when curated marker evidence is strong enough to support that biological class.
  required_specific_detected <- is.finite(best$required_hit_count) && best$required_hit_count > 0L
  strong_marker_support <- is.finite(best$marker_count) && best$marker_count >= 3L
  specific_label_allowed <- required_specific_detected || strong_marker_support

  final_label_raw <- if (specific_label_allowed) best$label_id else best$fallback_label
  assignment_mode <- if (specific_label_allowed) "specific_label" else "fallback_label_due_to_missing_required_specific_evidence"
  source <- label_source_from_counts(best$marker_count, best$term_hit_count, best_fdr)
  confidence <- assign_label_confidence(best$score, best$marker_count, best$term_hit_count,
                                        best_fdr, module_size, final_label_raw)

  warning <- dplyr::case_when(
    assignment_mode != "specific_label" ~
      "label_downgraded_to_fallback_due_to_missing_required_specific_evidence",
    source == "specific_STRING_enrichment_only" ~
      "label_assigned_from_STRING_only_without_curated_marker_support",
    source == "curated_marker_overlap_only" ~
      "marker_supported_but_no_specific_STRING_terms",
    best$score < 4L ~
      "limited_evidence_low_label_score",
    TRUE ~ "no_warning"
  )

  list(
    final_label_raw = final_label_raw,
    specific_label_candidate = best$label_id,
    fallback_label = best$fallback_label,
    label_assignment_mode = assignment_mode,
    label_source = source,
    label_evidence_score = as.integer(best$score),
    marker_label_evidence_count = as.integer(best$marker_count),
    term_label_evidence_count = as.integer(best$term_hit_count),
    required_specific_evidence_detected = isTRUE(required_specific_detected),
    supporting_biological_themes = supporting_themes_from_evidence(term_text, marker_summary, selected_label_id = best$label_id),
    label_confidence = confidence,
    label_warning = warning
  )
}


##############################################################################
# Stable module-labeling configuration moved from cancerppir.R
##############################################################################

# Configuration object: marker_sets
marker_sets <- list(
  antigen_presentation = c("HLA-DRA", "HLA-DRB1", "HLA-DRB5", "HLA-DPA1", "HLA-DPB1", "HLA-DQA1", "HLA-DQB1", "HLA-DQB2", "HLA-DOA", "CD74", "B2M"),
  T_cell_cytotoxic = c("CD3D", "CD3E", "CD3G", "CD2", "CD4", "CD8A", "CD8B", "GZMA", "GZMB", "GZMH", "GZMK", "PRF1", "NKG7", "IFNG", "TBX21", "CTLA4", "ICOS", "CD28"),
  myeloid_macrophage = c("TYROBP", "CD163", "TREM2", "MRC1", "FCGR1A", "FCGR2A", "FCGR3A", "FCGR3B", "LILRB1", "LILRB2", "LILRB4", "SPI1", "IRF8", "AIF1", "FOLR2", "MARCO", "MS4A4A", "MS4A6A", "MS4A7"),
  chemokine_cytokine = c("TNF", "CCL2", "CCL3", "CCL4", "CCL5", "CCL18", "CCL19", "CCL21", "CCR1", "CCR5", "CXCL1", "CXCL9", "CXCL10", "CXCL11", "CXCL12", "CXCL13", "CXCL14", "CXCR4"),
  complement_C1q = c("C1QA", "C1QB", "C1QC", "C1R", "C1S", "C2", "C3", "C4A", "C4B", "SERPING1"),
  extracellular_matrix_stromal = c("COL1A1", "COL1A2", "COL3A1", "COL5A1", "COL5A2", "COL5A3", "COL6A1", "COL6A2", "COL6A3", "POSTN", "MMP2", "MMP9", "TIMP3", "LAMA4", "VWF", "PECAM1", "CD34", "PDGFRA", "SPARCL1", "VCAM1", "MGP"),
  cell_cycle_mitotic = c("CDK1", "TOP2A", "CDC20", "CCNB1", "AURKB", "BIRC5", "MKI67", "UBE2C", "KIF11", "KIF2C", "KIFC1", "PLK1", "FOXM1", "MCM2", "MCM7", "TYMS"),
  lipid_metabolic = c("FABP4", "LEP", "ADIPOQ", "LPL", "LIPE", "PLIN1", "DGAT2", "CIDEA", "CIDEC", "PCK1", "MLXIPL", "AQP7"),
  interferon_response = c("IDO1", "GBP4", "GBP5", "CXCL9", "CXCL10", "CXCL11", "EPSTI1", "IFITM2", "MX2", "ZBP1", "TRIM22", "CASP1", "CASP4")
)

# Configuration object: module_clean_labels
module_clean_labels <- c(
  antigen_presentation = "MHC_class_II_antigen_presentation_module",
  T_cell_cytotoxic = "T_cell_cytotoxic_module",
  myeloid_macrophage = "myeloid_macrophage_module",
  chemokine_cytokine = "chemokine_cytokine_signaling_module",
  complement_C1q = "C1q_complement_macrophage_module",
  extracellular_matrix_stromal = "stromal_ECM_remodeling_module",
  cell_cycle_mitotic = "cell_cycle_mitotic_module",
  lipid_metabolic = "lipid_metabolic_module",
  interferon_response = "interferon_response_module"
)

# Configuration object: label_rulebook
label_rulebook <- list(
  list(
    label_id = "MHC_class_II_antigen_presentation_module",
    fallback_label = "immune_antigen_presentation_associated_module",
    marker_patterns = c("antigen_presentation"),
    core_term_patterns = c(
      "antigen processing", "antigen presentation", "mhc", "major histocompatibility",
      "hla", "peptide antigen", "peptide presentation", "class ii"
    ),
    required_specific_patterns = c("antigen", "mhc", "major histocompatibility", "hla", "peptide"),
    theme = "antigen presentation / MHC biology"
  ),
  list(
    label_id = "chemokine_cytokine_signaling_module",
    fallback_label = "inflammatory_immune_signaling_module",
    marker_patterns = c("chemokine_cytokine", "interferon_response"),
    core_term_patterns = c(
      "chemokine", "cytokine", "interleukin", "tnf", "chemotaxis",
      "leukocyte migration", "response to chemokine", "response to cytokine",
      "cellular response to chemokine", "cellular response to cytokine"
    ),
    required_specific_patterns = c("chemokine", "cytokine", "interleukin", "tnf", "chemotaxis"),
    theme = "chemokine/cytokine inflammatory signaling"
  ),
  list(
    label_id = "C1q_complement_macrophage_module",
    fallback_label = "phagocytic_immune_cell_signaling_module",
    marker_patterns = c("complement_C1q", "myeloid_macrophage"),
    core_term_patterns = c(
      "complement activation", "classical complement", "c1q", "macrophage activation",
      "macrophage", "fc receptor", "phagocytosis", "phagocytic"
    ),
    # Phagocytosis alone is not sufficient for the specific C1q/complement label.
    # A module must contain complement/C1q/macrophage/Fc-receptor evidence, or strong
    # curated marker support, otherwise the fallback phagocytic label is used.
    required_specific_patterns = c("complement", "c1q", "classical complement", "macrophage", "fc receptor"),
    theme = "C1q/complement/macrophage or Fc-receptor biology"
  ),
  list(
    label_id = "myeloid_phagocytic_immune_signaling_module",
    fallback_label = "myeloid_innate_immune_signaling_module",
    marker_patterns = c("myeloid_macrophage"),
    core_term_patterns = c(
      "myeloid", "innate immune", "neutrophil degranulation", "immune receptor",
      "phagocytic cup", "phagocytosis", "phagocytic", "cdc42", "actin dynamics",
      "actin cytoskeleton", "cytoskeleton organization"
    ),
    required_specific_patterns = c("myeloid", "innate immune", "neutrophil", "phagocyt", "cdc42", "actin"),
    theme = "myeloid/phagocytic immune signaling; phagocytic actin/cytoskeleton remodeling"
  ),
  list(
    label_id = "T_cell_adaptive_immune_module",
    fallback_label = "adaptive_immune_cell_module",
    marker_patterns = c("T_cell_cytotoxic"),
    core_term_patterns = c(
      "t cell", "adaptive immune", "lymphocyte activation", "cytotoxic",
      "natural killer", "granzyme", "perforin", "lymphocyte mediated"
    ),
    required_specific_patterns = c("t cell", "adaptive immune", "lymphocyte", "cytotoxic", "natural killer", "granzyme", "perforin"),
    theme = "T-cell/adaptive cytotoxic immunity"
  ),
  list(
    label_id = "myeloid_leukocyte_signaling_module",
    fallback_label = "leukocyte_immune_signaling_module",
    marker_patterns = c("myeloid_macrophage"),
    core_term_patterns = c(
      "myeloid", "leukocyte activation", "immune receptor", "leukocyte mediated",
      "hematopoietic", "innate immune", "immune effector"
    ),
    required_specific_patterns = c("myeloid", "leukocyte", "immune receptor", "hematopoietic", "innate immune"),
    theme = "myeloid/leukocyte immune signaling"
  ),
  list(
    label_id = "stromal_ECM_remodeling_module",
    fallback_label = "stromal_matrix_associated_module",
    marker_patterns = c("extracellular_matrix_stromal"),
    core_term_patterns = c(
      "extracellular matrix", "ecm", "collagen", "matrix organization",
      "stromal", "focal adhesion", "cell-substrate adhesion", "cell adhesion"
    ),
    required_specific_patterns = c("extracellular matrix", "ecm", "collagen", "matrix", "stromal", "adhesion"),
    theme = "stromal/extracellular-matrix remodeling"
  ),
  list(
    label_id = "interferon_response_module",
    fallback_label = "antiviral_inflammatory_response_module",
    marker_patterns = c("interferon_response"),
    core_term_patterns = c("interferon", "antiviral", "response to virus", "viral process", "type i interferon"),
    required_specific_patterns = c("interferon", "antiviral", "virus", "viral"),
    theme = "interferon/antiviral response"
  ),
  list(
    label_id = "cell_cycle_mitotic_module",
    fallback_label = "proliferation_associated_module",
    marker_patterns = c("cell_cycle_mitotic"),
    core_term_patterns = c(
      "cell cycle", "mitotic", "mitosis", "chromosome segregation",
      "dna replication", "spindle", "cyclin"
    ),
    required_specific_patterns = c("cell cycle", "mitotic", "mitosis", "chromosome", "dna replication", "spindle"),
    theme = "cell-cycle/mitotic proliferation"
  ),
  list(
    label_id = "lipid_metabolic_module",
    fallback_label = "metabolic_lipid_associated_module",
    marker_patterns = c("lipid_metabolic"),
    core_term_patterns = c("lipid", "fatty acid", "cholesterol", "lipoprotein", "triglyceride"),
    required_specific_patterns = c("lipid", "fatty acid", "cholesterol", "lipoprotein", "triglyceride"),
    theme = "lipid/fatty-acid metabolism"
  )
)

