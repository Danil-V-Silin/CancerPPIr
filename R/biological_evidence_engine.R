# CancerPPIr: biological evidence engine
#
# This module provides the canonical transparent, hierarchical biological
# evidence model used by the production pipeline, analytical report and GraphML
# export. It remains independent of deprecated compatibility labeling functions.
#
# The engine does not estimate cell fractions and must not be described as
# transcriptomic deconvolution.

normalize_evidence_genes <- function(genes) {
  genes <- toupper(trimws(as.character(genes)))
  genes <- genes[!is.na(genes) & nzchar(genes)]
  unique(genes)
}

find_evidence_column <- function(data, candidates) {
  if (is.null(data) || !ncol(data)) {
    return(NA_character_)
  }

  normalize <- function(x) {
    x <- tolower(trimws(as.character(x)))
    gsub("[^a-z0-9]+", "", x)
  }

  observed <- normalize(names(data))
  wanted <- normalize(candidates)
  index <- match(wanted, observed)
  index <- index[!is.na(index)]

  if (!length(index)) {
    return(NA_character_)
  }

  names(data)[index[[1L]]]
}

split_gene_text <- function(x) {
  if (is.null(x) || !length(x)) {
    return(character())
  }

  tokens <- unlist(
    strsplit(
      paste(as.character(x), collapse = ";"),
      "[,;|/[:space:]]+",
      perl = TRUE
    ),
    use.names = FALSE
  )

  normalize_evidence_genes(tokens)
}

is_generic_evidence_term <- function(term) {
  term <- tolower(trimws(as.character(term)))

  if (!nzchar(term)) {
    return(TRUE)
  }

  generic_patterns <- c(
    "^signaling$",
    "^signal transduction$",
    "^cell communication$",
    "^biological process$",
    "^cellular process$",
    "^cellular metabolic process$",
    "^immune system process$",
    "^immune response$",
    "^metabolic process$",
    "^regulation of biological process$",
    "^response to stimulus$",
    "^gene expression$",
    "^transport of small molecules$",
    "^mixed, incl\\.",
    "^mostly uncharacterized",
    "uncharacterized",
    "the function of this family is unknown",
    "family consists of several"
  )

  any(vapply(
    generic_patterns,
    function(pattern) {
      grepl(pattern, term, perl = TRUE)
    },
    FUN.VALUE = logical(1)
  ))
}

prepare_enrichment_evidence <- function(
  enrichment,
  fdr_threshold = 0.05
) {
  empty <- data.frame(
    source = character(),
    term_id = character(),
    description = character(),
    fdr = numeric(),
    supporting_genes = character(),
    is_significant = logical(),
    is_generic = logical(),
    stringsAsFactors = FALSE
  )

  if (
    is.null(enrichment) ||
    !is.data.frame(enrichment) ||
    nrow(enrichment) == 0L
  ) {
    return(empty)
  }

  description_column <- find_evidence_column(
    enrichment,
    c(
      "description",
      "term",
      "term_name",
      "name"
    )
  )

  fdr_column <- find_evidence_column(
    enrichment,
    c(
      "fdr",
      "false_discovery_rate",
      "padj",
      "adjusted_pvalue",
      "p_adjust"
    )
  )

  source_column <- find_evidence_column(
    enrichment,
    c(
      "category",
      "source",
      "database"
    )
  )

  term_id_column <- find_evidence_column(
    enrichment,
    c(
      "term_id",
      "termid",
      "id"
    )
  )

  genes_column <- find_evidence_column(
    enrichment,
    c(
      "inputGenes",
      "input_genes",
      "genes",
      "gene_symbols",
      "matching_genes"
    )
  )

  if (is.na(description_column)) {
    return(empty)
  }

  description <- trimws(
    as.character(
      enrichment[[description_column]]
    )
  )

  fdr <- if (!is.na(fdr_column)) {
    suppressWarnings(
      as.numeric(
        gsub(
          ",",
          ".",
          as.character(enrichment[[fdr_column]]),
          fixed = TRUE
        )
      )
    )
  } else {
    rep(NA_real_, nrow(enrichment))
  }

  source <- if (!is.na(source_column)) {
    as.character(
      enrichment[[source_column]]
    )
  } else {
    rep("not_available", nrow(enrichment))
  }

  term_id <- if (!is.na(term_id_column)) {
    as.character(
      enrichment[[term_id_column]]
    )
  } else {
    rep("", nrow(enrichment))
  }

  supporting_genes <- if (!is.na(genes_column)) {
    vapply(
      enrichment[[genes_column]],
      function(value) {
        paste(
          split_gene_text(value),
          collapse = ";"
        )
      },
      FUN.VALUE = character(1)
    )
  } else {
    rep("", nrow(enrichment))
  }

  is_significant <- is.finite(fdr) & fdr <= fdr_threshold

  data.frame(
    source = source,
    term_id = term_id,
    description = description,
    fdr = fdr,
    supporting_genes = supporting_genes,
    is_significant = is_significant,
    is_generic = vapply(
      description,
      is_generic_evidence_term,
      FUN.VALUE = logical(1)
    ),
    stringsAsFactors = FALSE
  )
}

significant_specific_terms <- function(
  enrichment,
  fdr_threshold = 0.05
) {
  prepared <- prepare_enrichment_evidence(
    enrichment = enrichment,
    fdr_threshold = fdr_threshold
  )

  prepared[
    prepared$is_significant &
      !prepared$is_generic &
      nzchar(prepared$description),
    ,
    drop = FALSE
  ]
}

# Biological evidence rules are defined in biological_evidence_rules.R.
# The engine evaluates rules but does not own their scientific curation.

match_evidence_terms <- function(terms, patterns) {
  if (
    is.null(terms) ||
    !nrow(terms) ||
    is.null(patterns) ||
    !length(patterns)
  ) {
    return(logical(0))
  }

  descriptions <- tolower(
    as.character(
      terms$description
    )
  )

  vapply(
    descriptions,
    function(description) {
      any(vapply(
        patterns,
        function(pattern) {
          grepl(
            pattern,
            description,
            ignore.case = TRUE,
            perl = TRUE
          )
        },
        FUN.VALUE = logical(1)
      ))
    },
    FUN.VALUE = logical(1)
  )
}

evaluate_evidence_rule <- function(
  genes,
  significant_terms,
  rule
) {
  genes <- normalize_evidence_genes(genes)

  positive_hits <- intersect(
    genes,
    normalize_evidence_genes(
      rule$positive_markers
    )
  )

  supportive_hits <- intersect(
    genes,
    normalize_evidence_genes(
      rule$supportive_markers
    )
  )

  exclusion_hits <- intersect(
    genes,
    normalize_evidence_genes(
      rule$exclusion_markers
    )
  )

  term_matches <- match_evidence_terms(
    significant_terms,
    rule$term_patterns
  )

  required_matches <- match_evidence_terms(
    significant_terms,
    rule$required_term_patterns
  )

  matched_terms <- if (length(term_matches)) {
    significant_terms[
      term_matches,
      ,
      drop = FALSE
    ]
  } else {
    significant_terms[
      FALSE,
      ,
      drop = FALSE
    ]
  }

  positive_count <- length(positive_hits)
  supportive_count <- length(supportive_hits)
  exclusion_count <- length(exclusion_hits)
  term_count <- nrow(matched_terms)
  required_term_count <- if (length(required_matches)) {
    sum(required_matches)
  } else {
    0L
  }

  marker_component <- min(
    1,
    positive_count / max(
      1,
      as.numeric(rule$min_positive) + 1
    )
  )

  supportive_component <- min(
    1,
    supportive_count / 4
  )

  term_component <- min(
    1,
    term_count / 2
  )

  coverage_denominator <- max(
    3,
    min(
      8,
      sqrt(
        max(
          1,
          length(genes)
        )
      ) + 1
    )
  )

  coverage_component <- min(
    1,
    (positive_count + supportive_count) /
      coverage_denominator
  )

  exclusion_penalty <- min(
    1,
    exclusion_count / 2
  )

  evidence_score <- (
    0.45 * marker_component +
      0.15 * supportive_component +
      0.25 * term_component +
      0.15 * coverage_component -
      0.30 * exclusion_penalty
  )

  evidence_score <- max(
    0,
    min(
      1,
      evidence_score
    )
  )

  standard_eligible <- (
    positive_count >= as.integer(rule$min_positive)
  ) || (
    positive_count >= 1L &&
      required_term_count >= 1L &&
      term_count >= 1L
  )

  marker_only_min_positive <- if (
    is.null(rule$marker_only_min_positive)
  ) {
    Inf
  } else {
    as.numeric(
      rule$marker_only_min_positive
    )
  }

  marker_only_min_supportive <- if (
    is.null(rule$marker_only_min_supportive)
  ) {
    Inf
  } else {
    as.numeric(
      rule$marker_only_min_supportive
    )
  }

  marker_only_min_score <- if (
    is.null(rule$marker_only_min_score)
  ) {
    as.numeric(
      rule$min_score
    )
  } else {
    as.numeric(
      rule$marker_only_min_score
    )
  }

  marker_only_eligible <- term_count == 0L &&
    (
      positive_count >= marker_only_min_positive ||
        (
          positive_count >= as.integer(rule$min_positive) &&
            supportive_count >= marker_only_min_supportive
        )
    ) &&
    evidence_score >= marker_only_min_score

  eligible <- (
    isTRUE(standard_eligible) &&
      evidence_score >= as.numeric(rule$min_score)
  ) || isTRUE(marker_only_eligible)

  term_supporting_genes <- normalize_evidence_genes(
    unlist(
      lapply(
        matched_terms$supporting_genes,
        split_gene_text
      ),
      use.names = FALSE
    )
  )

  data.frame(
    rule_id = rule$rule_id,
    axis = rule$axis,
    display_label = rule$display_label,
    compartment = rule$compartment,
    positive_marker_count = positive_count,
    supportive_marker_count = supportive_count,
    exclusion_marker_count = exclusion_count,
    significant_term_count = term_count,
    required_term_count = required_term_count,
    positive_marker_genes = paste(
      positive_hits,
      collapse = ";"
    ),
    supportive_marker_genes = paste(
      supportive_hits,
      collapse = ";"
    ),
    exclusion_marker_genes = paste(
      exclusion_hits,
      collapse = ";"
    ),
    significant_terms = paste(
      matched_terms$description,
      collapse = " | "
    ),
    significant_term_ids = paste(
      matched_terms$term_id[
        nzchar(matched_terms$term_id)
      ],
      collapse = ";"
    ),
    term_supporting_genes = paste(
      term_supporting_genes,
      collapse = ";"
    ),
    best_fdr = if (nrow(matched_terms)) {
      min(
        matched_terms$fdr,
        na.rm = TRUE
      )
    } else {
      NA_real_
    },
    marker_component = marker_component,
    supportive_component = supportive_component,
    term_component = term_component,
    coverage_component = coverage_component,
    coverage_denominator = coverage_denominator,
    exclusion_penalty = exclusion_penalty,
    evidence_score = evidence_score,
    standard_eligible = isTRUE(standard_eligible),
    marker_only_eligible = isTRUE(marker_only_eligible),
    eligible = eligible,
    priority = as.integer(rule$priority),
    stringsAsFactors = FALSE
  )
}

detect_technical_signature <- function(genes) {
  genes <- normalize_evidence_genes(genes)
  module_size <- length(genes)

  if (!module_size) {
    return(list(
      detected = FALSE,
      signature_id = NA_character_,
      display_label = NA_character_,
      supporting_genes = character(),
      evidence_fraction = 0
    ))
  }

  y_markers <- c(
    "RPS4Y1", "EIF1AY", "KDM5D", "ZFY",
    "DDX3Y", "UTY", "USP9Y", "TMSB4Y",
    "NLGN4Y", "PRKY"
  )

  y_hits <- intersect(
    genes,
    y_markers
  )

  if (
    length(y_hits) >= 3L &&
    length(y_hits) / module_size >= 0.30
  ) {
    return(list(
      detected = TRUE,
      signature_id = "Y_chromosome_associated_signature",
      display_label = "Y-chromosome-associated technical/covariate signature",
      supporting_genes = y_hits,
      evidence_fraction = length(y_hits) / module_size
    ))
  }

  mitochondrial_hits <- genes[
    grepl(
      "^MT-",
      genes
    )
  ]

  if (
    length(mitochondrial_hits) >= 5L &&
    length(mitochondrial_hits) / module_size >= 0.50
  ) {
    return(list(
      detected = TRUE,
      signature_id = "mitochondrial_dominant_signature",
      display_label = "mitochondrial-dominant technical signature",
      supporting_genes = mitochondrial_hits,
      evidence_fraction = length(mitochondrial_hits) / module_size
    ))
  }

  ribosomal_hits <- genes[
    grepl(
      "^RP[SL][0-9]",
      genes
    )
  ]

  if (
    length(ribosomal_hits) >= 8L &&
    length(ribosomal_hits) / module_size >= 0.50
  ) {
    return(list(
      detected = TRUE,
      signature_id = "ribosomal_translation_dominant_signature",
      display_label = "ribosomal/translation-dominant technical signature",
      supporting_genes = ribosomal_hits,
      evidence_fraction = length(ribosomal_hits) / module_size
    ))
  }

  immunoglobulin_hits <- genes[
    grepl(
      "^(IGH|IGK|IGL)",
      genes
    )
  ]

  plasma_core <- intersect(
    genes,
    c(
      "MZB1", "JCHAIN", "TNFRSF17", "SDC1",
      "PRDM1", "XBP1", "DERL3"
    )
  )

  if (
    length(immunoglobulin_hits) >= 5L &&
    length(immunoglobulin_hits) / module_size >= 0.60 &&
    length(plasma_core) < 2L
  ) {
    return(list(
      detected = TRUE,
      signature_id = "immunoglobulin_locus_dominant_signature",
      display_label = "immunoglobulin-locus-dominant technical/covariate signature",
      supporting_genes = immunoglobulin_hits,
      evidence_fraction = length(immunoglobulin_hits) / module_size
    ))
  }

  tcr_hits <- genes[
    grepl(
      "^TR[ABDG][CVJ]",
      genes
    )
  ]

  t_cell_core <- intersect(
    genes,
    c(
      "CD3D", "CD3E", "CD3G", "TRAC",
      "CD2", "CD247", "LCK"
    )
  )

  if (
    length(tcr_hits) >= 5L &&
    length(tcr_hits) / module_size >= 0.60 &&
    length(t_cell_core) < 2L
  ) {
    return(list(
      detected = TRUE,
      signature_id = "TCR_locus_dominant_signature",
      display_label = "T-cell-receptor-locus-dominant technical/covariate signature",
      supporting_genes = tcr_hits,
      evidence_fraction = length(tcr_hits) / module_size
    ))
  }

  list(
    detected = FALSE,
    signature_id = NA_character_,
    display_label = NA_character_,
    supporting_genes = character(),
    evidence_fraction = 0
  )
}

select_axis_evidence <- function(
  evidence_table,
  axis,
  conflict_delta = 0.08
) {
  all_axis_table <- evidence_table[
    evidence_table$axis == axis,
    ,
    drop = FALSE
  ]

  axis_table <- all_axis_table[
    all_axis_table$eligible,
    ,
    drop = FALSE
  ]

  if (!nrow(axis_table)) {
    return(list(
      selected = axis_table,
      alternatives = axis_table,
      conflict = FALSE,
      conflict_evidence = all_axis_table[
        FALSE,
        ,
        drop = FALSE
      ]
    ))
  }

  axis_table <- axis_table[
    order(
      -axis_table$evidence_score,
      -axis_table$positive_marker_count,
      -axis_table$significant_term_count,
      -axis_table$priority,
      axis_table$rule_id
    ),
    ,
    drop = FALSE
  ]

  selected <- axis_table[
    1L,
    ,
    drop = FALSE
  ]

  alternatives <- if (nrow(axis_table) > 1L) {
    axis_table[
      -1L,
      ,
      drop = FALSE
    ]
  } else {
    axis_table[
      FALSE,
      ,
      drop = FALSE
    ]
  }

  conflict <- FALSE
  conflict_evidence <- all_axis_table[
    FALSE,
    ,
    drop = FALSE
  ]

  # Exclusion markers reduce confidence in a single-lineage assignment, but
  # they must not hide a genuine mixed-lineage module. Therefore lineage
  # conflict detection evaluates independently supported competing rules
  # before the exclusion penalty is applied.
  #
  # States and processes are not treated this way because compatible states
  # such as antigen presentation and complement activity can coexist.
  if (identical(axis, "lineage")) {
    competing <- all_axis_table[
      all_axis_table$rule_id != selected$rule_id[[1L]] &
        all_axis_table$positive_marker_count >= 2L &
        (
          all_axis_table$significant_term_count >= 1L |
            all_axis_table$marker_only_eligible
        ),
      ,
      drop = FALSE
    ]

    if (nrow(competing)) {
      selected_support_score <- min(
        1,
        selected$evidence_score[[1L]] +
          0.30 * selected$exclusion_penalty[[1L]]
      )

      competing$conflict_support_score <- pmin(
        1,
        competing$evidence_score +
          0.30 * competing$exclusion_penalty
      )

      competing <- competing[
        order(
          -competing$conflict_support_score,
          -competing$positive_marker_count,
          -competing$significant_term_count,
          -competing$priority,
          competing$rule_id
        ),
        ,
        drop = FALSE
      ]

      second <- competing[
        1L,
        ,
        drop = FALSE
      ]

      score_difference <- abs(
        selected_support_score -
          second$conflict_support_score[[1L]]
      )

      marker_only_comparison <- isTRUE(
        selected$marker_only_eligible[[1L]]
      ) || isTRUE(
        second$marker_only_eligible[[1L]]
      )

      allowed_delta <- if (marker_only_comparison) {
        max(
          conflict_delta,
          0.18
        )
      } else {
        conflict_delta
      }

      conflict <- (
        selected_support_score >= 0.35 &&
          second$conflict_support_score[[1L]] >= 0.35 &&
          score_difference <= allowed_delta
      )

      if (isTRUE(conflict)) {
        # conflict_support_score is a temporary ranking column. Returning it
        # would make conflict_evidence structurally different from the other
        # rule-evidence tables and break later row binding.
        conflict_evidence <- second[
          ,
          names(all_axis_table),
          drop = FALSE
        ]
      }
    }
  }

  list(
    selected = selected,
    alternatives = alternatives,
    conflict = conflict,
    conflict_evidence = conflict_evidence
  )
}

secondary_axis_evidence <- function(
  axis_selection,
  minimum_score = 0.40,
  maximum_rows = 3L
) {
  alternatives <- axis_selection$alternatives

  if (
    is.null(alternatives) ||
    !is.data.frame(alternatives) ||
    nrow(alternatives) == 0L
  ) {
    return(
      alternatives[
        FALSE,
        ,
        drop = FALSE
      ]
    )
  }

  keep <- alternatives$evidence_score >= minimum_score &
    (
      alternatives$positive_marker_count >= 2L |
        alternatives$significant_term_count >= 1L
    )

  retained <- alternatives[
    keep,
    ,
    drop = FALSE
  ]

  if (nrow(retained) > maximum_rows) {
    retained <- retained[
      seq_len(maximum_rows),
      ,
      drop = FALSE
    ]
  }

  retained
}

confidence_from_evidence <- function(
  selected_rows,
  has_conflict,
  technical_override
) {
  if (isTRUE(technical_override)) {
    return("technical_or_covariate")
  }

  if (!nrow(selected_rows)) {
    return("unresolved")
  }

  best_score <- max(
    selected_rows$evidence_score,
    na.rm = TRUE
  )

  marker_supported <- any(
    selected_rows$positive_marker_count >= 2L
  )

  term_supported <- any(
    selected_rows$significant_term_count >= 1L
  )

  if (
    best_score >= 0.72 &&
    marker_supported &&
    term_supported &&
    !isTRUE(has_conflict)
  ) {
    return("high")
  }

  if (
    best_score >= 0.50 &&
    (marker_supported || term_supported) &&
    !isTRUE(has_conflict)
  ) {
    return("moderate")
  }

  if (best_score >= 0.35) {
    return("low")
  }

  "unresolved"
}

join_nonempty_evidence <- function(values, separator = "; ") {
  values <- unique(
    trimws(
      as.character(values)
    )
  )

  values <- values[
    !is.na(values) &
      nzchar(values)
  ]

  paste(
    values,
    collapse = separator
  )
}

infer_selected_compartment <- function(
  selected_rows,
  lineage_selection
) {
  if (
    is.data.frame(lineage_selection) &&
    nrow(lineage_selection) > 0L
  ) {
    return(
      lineage_selection$compartment[[1L]]
    )
  }

  if (
    is.null(selected_rows) ||
    !is.data.frame(selected_rows) ||
    nrow(selected_rows) == 0L
  ) {
    return("unresolved")
  }

  compartments <- unique(
    trimws(
      as.character(
        selected_rows$compartment
      )
    )
  )

  compartments <- compartments[
    !is.na(compartments) &
      nzchar(compartments) &
      compartments != "multi-compartment"
  ]

  if (length(compartments) == 1L) {
    return(compartments[[1L]])
  }

  if (length(compartments) > 1L) {
    return("multi-compartment")
  }

  "multi-compartment"
}

annotate_module_evidence <- function(
  genes,
  enrichment = NULL,
  module_id = NA,
  fdr_threshold = 0.05,
  rules = default_evidence_rules(),
  conflict_delta = 0.08
) {
  genes <- normalize_evidence_genes(genes)

  significant_terms <- significant_specific_terms(
    enrichment = enrichment,
    fdr_threshold = fdr_threshold
  )

  rule_evaluations <- do.call(
    rbind,
    lapply(
      rules,
      function(rule) {
        evaluate_evidence_rule(
          genes = genes,
          significant_terms = significant_terms,
          rule = rule
        )
      }
    )
  )

  technical <- detect_technical_signature(
    genes
  )

  lineage <- select_axis_evidence(
    rule_evaluations,
    axis = "lineage",
    conflict_delta = conflict_delta
  )

  state <- select_axis_evidence(
    rule_evaluations,
    axis = "state",
    conflict_delta = conflict_delta
  )

  process <- select_axis_evidence(
    rule_evaluations,
    axis = "process",
    conflict_delta = conflict_delta
  )

  # Lineage is represented by one primary assignment (or a mixed-lineage
  # result). States and processes are multi-label evidence dimensions: several
  # compatible, well-supported themes may coexist and must remain visible.
  secondary_state_rows <- secondary_axis_evidence(
    state
  )

  secondary_process_rows <- secondary_axis_evidence(
    process
  )

  state_evidence_rows <- do.call(
    rbind,
    Filter(
      function(x) {
        is.data.frame(x) && nrow(x) > 0L
      },
      list(
        state$selected,
        secondary_state_rows
      )
    )
  )

  process_evidence_rows <- do.call(
    rbind,
    Filter(
      function(x) {
        is.data.frame(x) && nrow(x) > 0L
      },
      list(
        process$selected,
        secondary_process_rows
      )
    )
  )

  if (is.null(state_evidence_rows)) {
    state_evidence_rows <- rule_evaluations[
      FALSE,
      ,
      drop = FALSE
    ]
  }

  if (is.null(process_evidence_rows)) {
    process_evidence_rows <- rule_evaluations[
      FALSE,
      ,
      drop = FALSE
    ]
  }

  selected_rows <- do.call(
    rbind,
    Filter(
      function(x) {
        is.data.frame(x) && nrow(x) > 0L
      },
      list(
        lineage$selected,
        lineage$conflict_evidence,
        state_evidence_rows,
        process_evidence_rows
      )
    )
  )

  if (is.null(selected_rows)) {
    selected_rows <- rule_evaluations[
      FALSE,
      ,
      drop = FALSE
    ]
  }

  secondary_theme_rows <- do.call(
    rbind,
    Filter(
      function(x) {
        is.data.frame(x) && nrow(x) > 0L
      },
      list(
        secondary_state_rows,
        secondary_process_rows
      )
    )
  )

  if (is.null(secondary_theme_rows)) {
    secondary_theme_rows <- rule_evaluations[
      FALSE,
      ,
      drop = FALSE
    ]
  }

  lineage_label <- if (isTRUE(technical$detected)) {
    "not_applicable"
  } else if (isTRUE(lineage$conflict)) {
    "mixed_lineage_associated"
  } else if (nrow(lineage$selected)) {
    lineage$selected$rule_id[[1L]]
  } else {
    "unresolved_lineage"
  }

  state_label <- if (
    !isTRUE(technical$detected) &&
    nrow(state$selected)
  ) {
    state$selected$rule_id[[1L]]
  } else {
    "not_assigned"
  }

  process_label <- if (
    !isTRUE(technical$detected) &&
    nrow(process$selected)
  ) {
    process$selected$rule_id[[1L]]
  } else {
    "not_assigned"
  }

  selected_labels <- if (isTRUE(technical$detected)) {
    technical$display_label
  } else if (nrow(selected_rows) > 0L) {
    join_nonempty_evidence(
      c(
        if (isTRUE(lineage$conflict)) {
          paste0(
            "mixed-lineage-associated (",
            lineage$selected$display_label[[1L]],
            " + ",
            lineage$conflict_evidence$display_label[[1L]],
            ")"
          )
        } else if (nrow(lineage$selected)) {
          lineage$selected$display_label[[1L]]
        },
        state_evidence_rows$display_label,
        process_evidence_rows$display_label
      ),
      separator = " / "
    )
  } else {
    "unresolved biological context"
  }

  has_conflict <- isTRUE(lineage$conflict) ||
    isTRUE(state$conflict) ||
    isTRUE(process$conflict)

  confidence <- confidence_from_evidence(
    selected_rows = selected_rows,
    has_conflict = has_conflict,
    technical_override = technical$detected
  )

  selected_positive_genes <- normalize_evidence_genes(
    unlist(
      lapply(
        selected_rows$positive_marker_genes,
        split_gene_text
      ),
      use.names = FALSE
    )
  )

  selected_supportive_genes <- normalize_evidence_genes(
    unlist(
      lapply(
        selected_rows$supportive_marker_genes,
        split_gene_text
      ),
      use.names = FALSE
    )
  )

  selected_term_genes <- normalize_evidence_genes(
    unlist(
      lapply(
        selected_rows$term_supporting_genes,
        split_gene_text
      ),
      use.names = FALSE
    )
  )

  warning_text <- join_nonempty_evidence(
    c(
      if (isTRUE(technical$detected)) {
        "technical_or_covariate_signature_not_eligible_for_automatic_biological_priority"
      },
      if (isTRUE(lineage$conflict)) {
        "conflicting_lineage_evidence_label_broadened_to_mixed_lineage"
      },
      if (isTRUE(state$conflict)) {
        "conflicting_state_evidence"
      },
      if (isTRUE(process$conflict)) {
        "conflicting_process_evidence"
      },
      if (
        !isTRUE(technical$detected) &&
        !nrow(lineage$selected) &&
        nrow(selected_rows) > 0L
      ) {
        "lineage_not_resolved_state_or_process_evidence_only"
      },
      if (
        !isTRUE(technical$detected) &&
        nrow(selected_rows) > 0L &&
        any(selected_rows$marker_only_eligible) &&
        !any(selected_rows$significant_term_count >= 1L)
      ) {
        "marker_only_interpretation_not_eligible_for_automatic_priority"
      },
      if (
        !isTRUE(technical$detected) &&
        !nrow(selected_rows)
      ) {
        "insufficient_specific_marker_and_significant_enrichment_evidence"
      },
      if (!nrow(significant_terms)) {
        "no_significant_specific_enrichment_terms_available"
      }
    )
  )

  rationale <- if (isTRUE(technical$detected)) {
    paste0(
      technical$display_label,
      ". Supporting genes: ",
      join_nonempty_evidence(
        technical$supporting_genes
      ),
      ". This module is reported as a technical/covariate signature and is not automatically promoted as a biological priority."
    )
  } else if (nrow(selected_rows)) {
    paste0(
      "Primary interpretation: ",
      selected_labels,
      ". Positive marker genes: ",
      join_nonempty_evidence(
        selected_positive_genes
      ),
      ". Supportive genes: ",
      join_nonempty_evidence(
        selected_supportive_genes
      ),
      ". Significant supporting terms: ",
      join_nonempty_evidence(
        selected_rows$significant_terms,
        separator = " | "
      ),
      ". This is marker- and enrichment-supported cell-context evidence, not an estimate of cell abundance."
    )
  } else {
    paste0(
      "No sufficiently specific marker and statistically significant enrichment evidence was available. ",
      "The module remains unresolved."
    )
  }

  summary <- data.frame(
    module_id = as.character(module_id),
    module_size = length(genes),
    interpretation_class = if (isTRUE(technical$detected)) {
      "technical_or_covariate"
    } else if (lineage_label == "mixed_lineage_associated") {
      "mixed_biological"
    } else if (nrow(selected_rows) > 0L) {
      "biological"
    } else {
      "unresolved"
    },
    interpretation_scope = if (isTRUE(technical$detected)) {
      "technical_or_covariate"
    } else if (lineage_label == "mixed_lineage_associated") {
      "mixed_lineage"
    } else if (nrow(lineage$selected) > 0L) {
      "lineage_supported"
    } else if (
      nrow(state_evidence_rows) > 0L &&
        nrow(process_evidence_rows) > 0L
    ) {
      "state_and_process_supported_lineage_unresolved"
    } else if (nrow(state_evidence_rows) > 0L) {
      "state_supported_lineage_unresolved"
    } else if (nrow(process_evidence_rows) > 0L) {
      "process_supported_lineage_unresolved"
    } else {
      "unresolved"
    },
    compartment = if (isTRUE(technical$detected)) {
      "not_applicable"
    } else {
      infer_selected_compartment(
        selected_rows = selected_rows,
        lineage_selection = lineage$selected
      )
    },
    lineage = lineage_label,
    conflicting_lineage_rules = if (isTRUE(lineage$conflict)) {
      join_nonempty_evidence(
        c(
          lineage$selected$rule_id,
          lineage$conflict_evidence$rule_id
        )
      )
    } else {
      ""
    },
    conflicting_lineage_labels = if (isTRUE(lineage$conflict)) {
      join_nonempty_evidence(
        c(
          lineage$selected$display_label,
          lineage$conflict_evidence$display_label
        )
      )
    } else {
      ""
    },
    state = state_label,
    process = process_label,
    primary_interpretation = selected_labels,
    secondary_themes = join_nonempty_evidence(
      secondary_theme_rows$display_label
    ),
    confidence = confidence,
    priority_eligible = !isTRUE(technical$detected) &&
      confidence %in% c("high", "moderate") &&
      !isTRUE(has_conflict) &&
      nrow(selected_rows) > 0L &&
      any(selected_rows$significant_term_count >= 1L),
    positive_marker_genes = join_nonempty_evidence(
      selected_positive_genes
    ),
    supportive_marker_genes = join_nonempty_evidence(
      selected_supportive_genes
    ),
    term_supporting_genes = join_nonempty_evidence(
      selected_term_genes
    ),
    significant_supporting_terms = join_nonempty_evidence(
      selected_rows$significant_terms,
      separator = " | "
    ),
    best_supporting_fdr = if (nrow(selected_rows)) {
      suppressWarnings(
        min(
          selected_rows$best_fdr,
          na.rm = TRUE
        )
      )
    } else {
      NA_real_
    },
    conflict_detected = has_conflict,
    warning = warning_text,
    evidence_rationale = rationale,
    stringsAsFactors = FALSE
  )

  if (
    is.infinite(
      summary$best_supporting_fdr[[1L]]
    )
  ) {
    summary$best_supporting_fdr[[1L]] <- NA_real_
  }

  list(
    summary = summary,
    rule_evaluations = rule_evaluations,
    significant_terms = significant_terms,
    technical_signature = technical
  )
}

classify_evidence_entity <- function(gene) {
  gene <- normalize_evidence_genes(gene)

  if (!length(gene)) {
    return("unknown")
  }

  gene <- gene[[1L]]

  if (grepl("^LOC[0-9]+$", gene)) {
    return("predicted_LOC")
  }

  if (grepl("^(IGH|IGK|IGL)", gene)) {
    return("immunoglobulin_locus")
  }

  if (grepl("^TR[ABDG][CVJ]", gene)) {
    return("T_cell_receptor_locus")
  }

  if (grepl("^MT-", gene)) {
    return("mitochondrial")
  }

  # Y-linked symbols such as RPS4Y1 can also match a broad ribosomal prefix.
  # Test the curated Y-chromosome set before generic ribosomal classification.
  if (
    gene %in% c(
      "RPS4Y1", "EIF1AY", "KDM5D", "ZFY",
      "DDX3Y", "UTY", "USP9Y", "TMSB4Y",
      "NLGN4Y", "PRKY"
    )
  ) {
    return("Y_chromosome_associated")
  }

  if (grepl("^RP[SL][0-9]", gene)) {
    return("ribosomal")
  }

  if (
    grepl("P[0-9]+$", gene) ||
    grepl("PSEUDOGENE", gene)
  ) {
    return("pseudogene_or_pseudogene_like")
  }

  if (
    grepl("-AS[0-9]*$", gene) ||
    grepl("^LINC[0-9]+$", gene)
  ) {
    return("lncRNA_or_antisense")
  }

  "canonical_or_unclassified_protein_coding"
}

determine_candidate_eligibility <- function(entity_class) {
  entity_class <- as.character(entity_class)

  if (
    entity_class == "canonical_or_unclassified_protein_coding"
  ) {
    return("review_ready_canonical")
  }

  if (
    entity_class %in% c(
      "immunoglobulin_locus",
      "T_cell_receptor_locus",
      "predicted_LOC",
      "pseudogene_or_pseudogene_like",
      "lncRNA_or_antisense"
    )
  ) {
    return("network_evidence_only")
  }

  if (
    entity_class %in% c(
      "mitochondrial",
      "ribosomal",
      "Y_chromosome_associated"
    )
  ) {
    return("excluded_from_automatic_priority")
  }

  "manual_review_required"
}

