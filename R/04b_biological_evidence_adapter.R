# CancerPPIr: biological evidence adapter
#
# Responsibility:
# Convert current in-memory pipeline tables into the explicit input schema
# required by the universal Phase 4 biological evidence engine.
#
# This module does not write files. It provides the canonical tested boundary
# between production network tables and the biological evidence engine.

phase4_require_pipeline_columns <- function(
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

phase4_prepare_pipeline_enrichment <- function(
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

  phase4_require_pipeline_columns(
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

phase4_pipeline_module_order <- function(
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

phase4_bind_pipeline_evidence <- function(
  node_metrics,
  module_enrichment = NULL,
  fdr_threshold = 0.05,
  rules = phase4_default_evidence_rules()
) {
  phase4_require_pipeline_columns(
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

  enrichment <- phase4_prepare_pipeline_enrichment(
    module_enrichment
  )

  module_ids <- phase4_pipeline_module_order(
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

    module_genes <- phase4_normalize_genes(
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

    evidence <- phase4_annotate_module_evidence(
      genes = module_genes,
      enrichment = module_terms,
      module_id = module_id,
      fdr_threshold = fdr_threshold,
      rules = rules
    )

    module_id_value <- module_nodes$community_louvain[[1L]]

    summary_row <- evidence$summary
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
    output <- phase4_significant_specific_terms(
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

  node_annotations <- nodes

  node_annotations$entity_class <- vapply(
    node_annotations$gene,
    phase4_classify_entity,
    FUN.VALUE = character(1)
  )

  node_annotations$candidate_eligibility <- vapply(
    node_annotations$entity_class,
    phase4_candidate_eligibility,
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

  validation <- phase4_validate_pipeline_evidence(
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

phase4_validate_pipeline_evidence <- function(
  module_annotations,
  significant_module_terms,
  node_annotations,
  fdr_threshold = 0.05
) {
  phase4_require_pipeline_columns(
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

  priority_confidence_valid <- !any(
    module_annotations$priority_eligible &
      !module_annotations$confidence %in% c("high", "moderate")
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
    priority_requires_moderate_or_high_confidence =
      priority_confidence_valid,
    no_cell_fraction_or_deconvolution_claims =
      no_cell_fraction_claims
  )

  data.frame(
    check_id = names(checks),
    status = ifelse(checks, "PASS", "FAIL"),
    stringsAsFactors = FALSE
  )
}
