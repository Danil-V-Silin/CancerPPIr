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

