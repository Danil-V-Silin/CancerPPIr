# CancerPPIr: biological evidence adapter
#
# Responsibility:
# Convert current in-memory pipeline tables into the explicit input schema
# required by the universal CancerPPIr biological evidence engine.
#
# This module does not write files. It provides the canonical tested boundary
# between production network tables and the biological evidence engine.

require_evidence_pipeline_columns <- function(
  data,
  required_columns,
  object_name
) {
  if (!is.data.frame(data)) {
    stop(
      paste0(object_name, " must be a data.frame or tibble."),
      call. = FALSE
    )
  }

  missing_columns <- setdiff(
    required_columns,
    names(data)
  )

  if (length(missing_columns) > 0L) {
    stop(
      paste0(
        object_name,
        " is missing required column(s): ",
        paste(missing_columns, collapse = ", "),
        "."
      ),
      call. = FALSE
    )
  }

  invisible(TRUE)
}

prepare_pipeline_enrichment <- function(
  module_enrichment
) {
  if (
    is.null(module_enrichment) ||
    (is.data.frame(module_enrichment) && nrow(module_enrichment) == 0L)
  ) {
    return(data.frame())
  }

  if (!is.data.frame(module_enrichment)) {
    stop(
      "module_enrichment must be NULL, a data.frame or a tibble.",
      call. = FALSE
    )
  }

  require_evidence_pipeline_columns(
    module_enrichment,
    "community_louvain",
    "module_enrichment"
  )

  output <- as.data.frame(
    module_enrichment,
    stringsAsFactors = FALSE
  )

  if (
    "preferred_names" %in% names(output) &&
    !"matching_genes" %in% names(output)
  ) {
    output$matching_genes <- as.character(
      output$preferred_names
    )
  }

  if (
    "term" %in% names(output) &&
    !"term_id" %in% names(output)
  ) {
    output$term_id <- as.character(
      output$term
    )
  }

  output
}

order_pipeline_modules <- function(
  module_ids
) {
  module_ids <- unique(as.character(module_ids))
  numeric_ids <- suppressWarnings(
    as.numeric(module_ids)
  )

  module_ids[
    order(
      is.na(numeric_ids),
      numeric_ids,
      module_ids
    )
  ]
}

summarize_database_primary_module_evidence <- function(
  genes,
  significant_terms,
  technical_signature,
  module_id = NA
) {
  genes <- normalize_evidence_genes(genes)

  terms <- as.data.frame(
    significant_terms,
    stringsAsFactors = FALSE
  )

  required_term_columns <- c(
    "source",
    "term_id",
    "description",
    "fdr",
    "supporting_genes"
  )

  if (
    nrow(terms) > 0L &&
    !all(required_term_columns %in% names(terms))
  ) {
    stop(
      "Significant STRING/database terms have an invalid schema.",
      call. = FALSE
    )
  }

  if (nrow(terms) > 0L) {
    term_fdr <- suppressWarnings(
      as.numeric(terms$fdr)
    )

    terms <- terms[
      order(
        !is.finite(term_fdr),
        term_fdr,
        as.character(terms$source),
        as.character(terms$description),
        na.last = TRUE
      ),
      ,
      drop = FALSE
    ]

    rownames(terms) <- NULL
  }

  has_database_evidence <- nrow(terms) > 0L

  technical_detected <- (
    is.list(technical_signature) &&
    isTRUE(technical_signature$detected)
  )

  # Three terms are sufficient for the compact canonical view.
  # The complete significant-term table remains available separately.
  top_terms <- if (has_database_evidence) {
    utils::head(
      terms,
      3L
    )
  } else {
    terms
  }

  top_descriptions <- if (nrow(top_terms)) {
    trimws(
      as.character(top_terms$description)
    )
  } else {
    character()
  }

  top_descriptions <- top_descriptions[
    !is.na(top_descriptions) &
      nzchar(top_descriptions)
  ]

  secondary_descriptions <- if (
    length(top_descriptions) > 1L
  ) {
    top_descriptions[-1L]
  } else {
    character()
  }

  term_gene_text <- if (nrow(top_terms)) {
    as.character(
      top_terms$supporting_genes
    )
  } else {
    character()
  }

  term_gene_parts <- unlist(
    strsplit(
      term_gene_text,
      "[;,|]",
      perl = TRUE
    ),
    use.names = FALSE
  )

  term_supporting_genes <- normalize_evidence_genes(
    term_gene_parts
  )

  best_fdr <- if (has_database_evidence) {
    suppressWarnings(
      min(
        as.numeric(terms$fdr),
        na.rm = TRUE
      )
    )
  } else {
    NA_real_
  }

  if (!is.finite(best_fdr)) {
    best_fdr <- NA_real_
  }

  primary_interpretation <- if (technical_detected) {
    as.character(
      technical_signature$display_label
    )
  } else if (length(top_descriptions)) {
    top_descriptions[[1L]]
  } else {
    "unresolved biological context"
  }

  interpretation_class <- if (technical_detected) {
    "technical_or_covariate"
  } else if (has_database_evidence) {
    "biological"
  } else {
    "unresolved"
  }

  interpretation_scope <- if (technical_detected) {
    "technical_or_covariate"
  } else if (has_database_evidence) {
    "database_enrichment_supported"
  } else {
    "unresolved"
  }

  # Kept for schema compatibility during the transition.
  # These fields are no longer canonical decision variables.
  confidence <- if (technical_detected) {
    "not_applicable"
  } else if (has_database_evidence) {
    "moderate"
  } else {
    "unresolved"
  }

  priority_eligible <- (
    !technical_detected &&
    has_database_evidence
  )

  warning_text <- if (technical_detected) {
    paste0(
      "technical_or_covariate_signature_",
      "not_eligible_for_automatic_biological_priority"
    )
  } else if (!has_database_evidence) {
    "no_significant_specific_enrichment_terms_available"
  } else {
    ""
  }

  top_term_text <- if (nrow(top_terms)) {
    paste(
      paste0(
        as.character(top_terms$description),
        " [",
        as.character(top_terms$source),
        "; FDR=",
        format(
          suppressWarnings(
            as.numeric(top_terms$fdr)
          ),
          scientific = TRUE,
          digits = 3L
        ),
        "]"
      ),
      collapse = " | "
    )
  } else {
    ""
  }

  rationale <- if (technical_detected) {
    paste0(
      as.character(
        technical_signature$display_label
      ),
      ". This technical/covariate guard is independent ",
      "of biological rule assignment and is not eligible ",
      "for automatic biological priority."
    )
  } else if (has_database_evidence) {
    paste0(
      "Canonical interpretation is derived directly from ",
      "statistically significant, non-generic local ",
      "STRING/database enrichment evidence. Top terms: ",
      top_term_text,
      ". Curated marker-rule evidence is retained only ",
      "as auxiliary audit information and does not determine ",
      "the canonical interpretation or priority."
    )
  } else {
    paste0(
      "No statistically significant, non-generic local ",
      "STRING/database enrichment term passed the configured ",
      "FDR threshold. The module remains unresolved."
    )
  }

  data.frame(
    module_id = as.character(module_id),
    module_size = length(genes),
    interpretation_class = interpretation_class,
    interpretation_scope = interpretation_scope,

    # Compatibility fields retained in schema.
    # Marker-rule assignments no longer populate them canonically.
    compartment = if (technical_detected) {
      "not_applicable"
    } else {
      "unresolved"
    },
    lineage = if (technical_detected) {
      "not_applicable"
    } else {
      "unresolved_lineage"
    },
    conflicting_lineage_rules = "",
    conflicting_lineage_labels = "",
    state = "not_assigned",
    process = "not_assigned",

    primary_interpretation = primary_interpretation,
    secondary_themes = paste(
      secondary_descriptions,
      collapse = "; "
    ),
    confidence = confidence,
    priority_eligible = priority_eligible,

    # Marker evidence is intentionally absent from the
    # canonical decision layer.
    positive_marker_genes = "",
    supportive_marker_genes = "",

    term_supporting_genes = paste(
      term_supporting_genes,
      collapse = ";"
    ),
    significant_supporting_terms = paste(
      top_descriptions,
      collapse = " | "
    ),
    best_supporting_fdr = best_fdr,

    # Rule conflicts cannot block a database-primary result.
    conflict_detected = FALSE,
    warning = warning_text,
    evidence_rationale = rationale,
    stringsAsFactors = FALSE
  )
}

bind_pipeline_evidence <- function(
  node_metrics,
  module_enrichment = NULL,
  fdr_threshold = 0.05,
  rules = default_evidence_rules()
) {
  require_evidence_pipeline_columns(
    node_metrics,
    c("gene", "community_louvain"),
    "node_metrics"
  )

  if (nrow(node_metrics) == 0L) {
    stop(
      "node_metrics must contain at least one network node.",
      call. = FALSE
    )
  }

  if (
    length(fdr_threshold) != 1L ||
    !is.finite(fdr_threshold) ||
    fdr_threshold <= 0 ||
    fdr_threshold > 1
  ) {
    stop(
      "fdr_threshold must be one finite number in (0, 1].",
      call. = FALSE
    )
  }

  nodes <- as.data.frame(
    node_metrics,
    stringsAsFactors = FALSE
  )

  module_id_text <- trimws(
    as.character(nodes$community_louvain)
  )

  if (any(is.na(nodes$community_louvain) | !nzchar(module_id_text))) {
    stop(
      "node_metrics contains missing community_louvain values.",
      call. = FALSE
    )
  }

  enrichment <- prepare_pipeline_enrichment(
    module_enrichment
  )

  module_ids <- order_pipeline_modules(
    module_id_text
  )

  summary_rows <- vector(
    "list",
    length(module_ids)
  )

  rule_rows <- vector(
    "list",
    length(module_ids)
  )

  term_rows <- list()

  for (module_index in seq_along(module_ids)) {
    module_id <- module_ids[[module_index]]

    module_nodes <- nodes[
      module_id_text == module_id,
      ,
      drop = FALSE
    ]

    if ("candidate_score" %in% names(module_nodes)) {
      candidate_score <- suppressWarnings(
        as.numeric(module_nodes$candidate_score)
      )

      module_nodes <- module_nodes[
        order(
          -candidate_score,
          as.character(module_nodes$gene),
          na.last = TRUE
        ),
        ,
        drop = FALSE
      ]
    } else {
      module_nodes <- module_nodes[
        order(as.character(module_nodes$gene)),
        ,
        drop = FALSE
      ]
    }

    module_genes <- normalize_evidence_genes(
      module_nodes$gene
    )

    module_terms <- if (nrow(enrichment) > 0L) {
      enrichment[
        as.character(enrichment$community_louvain) == module_id,
        ,
        drop = FALSE
      ]
    } else {
      data.frame()
    }

    evidence <- annotate_module_evidence(
      genes = module_genes,
      enrichment = module_terms,
      module_id = module_id,
      fdr_threshold = fdr_threshold,
      rules = rules
    )

    module_id_value <- module_nodes$community_louvain[[1L]]

    summary_row <- summarize_database_primary_module_evidence(
      genes = module_genes,
      significant_terms = evidence$significant_terms,
      technical_signature = evidence$technical_signature,
      module_id = module_id
    )
    summary_row$community_louvain <- module_id_value
    summary_row$network_node_count <- nrow(module_nodes)
    summary_row$representative_genes <- paste(
      head(module_genes, 15L),
      collapse = ";"
    )

    summary_row <- summary_row[
      ,
      c(
        "community_louvain",
        "network_node_count",
        "representative_genes",
        setdiff(
          names(summary_row),
          c(
            "community_louvain",
            "network_node_count",
            "representative_genes"
          )
        )
      ),
      drop = FALSE
    ]

    summary_rows[[module_index]] <- summary_row

    rule_table <- evidence$rule_evaluations
    rule_table$community_louvain <- module_id_value
    rule_table$module_id <- as.character(module_id)

    rule_rows[[module_index]] <- rule_table[
      ,
      c(
        "community_louvain",
        "module_id",
        setdiff(
          names(rule_table),
          c("community_louvain", "module_id")
        )
      ),
      drop = FALSE
    ]

    significant_terms <- evidence$significant_terms

    if (nrow(significant_terms) > 0L) {
      significant_terms$community_louvain <- module_id_value
      significant_terms$module_id <- as.character(module_id)

      term_rows[[length(term_rows) + 1L]] <- significant_terms[
        ,
        c(
          "community_louvain",
          "module_id",
          setdiff(
            names(significant_terms),
            c("community_louvain", "module_id")
          )
        ),
        drop = FALSE
      ]
    }
  }

  module_annotations <- do.call(
    rbind,
    summary_rows
  )

  rownames(module_annotations) <- NULL

  module_rule_evidence <- do.call(
    rbind,
    rule_rows
  )

  rownames(module_rule_evidence) <- NULL

  significant_module_terms <- if (length(term_rows) > 0L) {
    output <- do.call(
      rbind,
      term_rows
    )

    rownames(output) <- NULL
    output
  } else {
    output <- significant_specific_terms(
      enrichment = NULL,
      fdr_threshold = fdr_threshold
    )

    output$community_louvain <- nodes$community_louvain[FALSE]
    output$module_id <- character()

    output[
      ,
      c(
        "community_louvain",
        "module_id",
        setdiff(
          names(output),
          c("community_louvain", "module_id")
        )
      ),
      drop = FALSE
    ]
  }

  # Deprecated readable labels remain in raw compatibility tables only.
  node_annotations <- nodes[
    ,
    setdiff(
      names(nodes),
      CANCERPPIR_DEPRECATED_ANNOTATION_FIELDS
    ),
    drop = FALSE
  ]

  node_annotations$entity_class <- vapply(
    node_annotations$gene,
    classify_evidence_entity,
    FUN.VALUE = character(1)
  )

  node_annotations$candidate_eligibility <- vapply(
    node_annotations$entity_class,
    determine_candidate_eligibility,
    FUN.VALUE = character(1)
  )

  annotation_index <- match(
    as.character(node_annotations$community_louvain),
    as.character(module_annotations$community_louvain)
  )

  module_fields <- c(
    "interpretation_class",
    "interpretation_scope",
    "compartment",
    "lineage",
    "state",
    "process",
    "primary_interpretation",
    "secondary_themes",
    "confidence",
    "priority_eligible",
    "positive_marker_genes",
    "supportive_marker_genes",
    "term_supporting_genes",
    "significant_supporting_terms",
    "best_supporting_fdr",
    "conflict_detected",
    "warning",
    "evidence_rationale"
  )

  for (field in module_fields) {
    node_annotations[[paste0("module_", field)]] <-
      module_annotations[[field]][annotation_index]
  }

  validation <- validate_pipeline_evidence(
    module_annotations = module_annotations,
    significant_module_terms = significant_module_terms,
    node_annotations = node_annotations,
    fdr_threshold = fdr_threshold
  )

  list(
    module_annotations = module_annotations,
    module_rule_evidence = module_rule_evidence,
    significant_module_terms = significant_module_terms,
    node_annotations = node_annotations,
    validation = validation
  )
}

validate_pipeline_evidence <- function(
  module_annotations,
  significant_module_terms,
  node_annotations,
  fdr_threshold = 0.05
) {
  require_evidence_pipeline_columns(
    module_annotations,
    c(
      "community_louvain",
      "interpretation_class",
      "confidence",
      "priority_eligible",
      "evidence_rationale"
    ),
    "module_annotations"
  )

  unique_modules <- !any(
    duplicated(
      as.character(module_annotations$community_louvain)
    )
  )

  all_nodes_annotated <- nrow(node_annotations) > 0L &&
    !any(
      is.na(node_annotations$module_interpretation_class)
    )

  significant_terms_valid <- nrow(significant_module_terms) == 0L ||
    all(
      is.finite(significant_module_terms$fdr) &
        significant_module_terms$fdr <= fdr_threshold
    )

  technical_not_priority <- !any(
    module_annotations$interpretation_class ==
      "technical_or_covariate" &
      module_annotations$priority_eligible
  )

  priority_module_ids <- as.character(
    module_annotations$community_louvain[
      !is.na(module_annotations$priority_eligible) &
        module_annotations$priority_eligible
    ]
  )

  significant_term_module_ids <- unique(
    as.character(
      significant_module_terms$community_louvain
    )
  )

  priority_has_database_evidence <- (
    !length(priority_module_ids) ||
    all(
      priority_module_ids %in%
        significant_term_module_ids
    )
  )

  forbidden_pattern <- paste(
    c(
      "cell fraction",
      "cellular fraction",
      "estimated proportion",
      "cell proportion",
      "deconvoluted cell",
      "deconvolved cell",
      "percentage of .* cells"
    ),
    collapse = "|"
  )

  no_cell_fraction_claims <- !any(
    grepl(
      forbidden_pattern,
      module_annotations$evidence_rationale,
      ignore.case = TRUE,
      perl = TRUE
    )
  )

  checks <- c(
    unique_module_rows = unique_modules,
    all_nodes_receive_module_annotations = all_nodes_annotated,
    significant_terms_respect_fdr_threshold = significant_terms_valid,
    technical_modules_are_not_priority = technical_not_priority,
    priority_requires_significant_database_evidence =
      priority_has_database_evidence,
    no_cell_fraction_or_deconvolution_claims =
      no_cell_fraction_claims
  )

  data.frame(
    check_id = names(checks),
    status = ifelse(checks, "PASS", "FAIL"),
    stringsAsFactors = FALSE
  )
}
