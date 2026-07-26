# CancerPPIr: Phase 4 analytical workbook
#
# Responsibility:
# Build and validate the concise six-sheet human-readable workbook from the
# deterministic Phase 4 biological evidence objects.
#
# This module contains no patient-specific rules and performs no file I/O.

CANCERPPIR_ANALYTICAL_SCHEMA_VERSION <- "4.5.0"

CANCERPPIR_ANALYTICAL_SHEET_NAMES <- c(
  "Executive summary",
  "Final priorities",
  "Module priorities",
  "Candidate evidence",
  "Network overview",
  "Methods and limitations"
)

phase4_require_columns <- function(
  data,
  required_columns,
  object_name
) {
  if (!is.data.frame(data)) {
    stop(
      object_name,
      " must be a data frame.",
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
        paste(
          missing_columns,
          collapse = ", "
        ),
        "."
      ),
      call. = FALSE
    )
  }

  invisible(TRUE)
}

phase4_scalar_text <- function(
  x,
  fallback = "not_available"
) {
  x <- as.character(x)

  if (
    length(x) == 0L ||
      is.na(x[[1L]]) ||
      !nzchar(
        trimws(
          x[[1L]]
        )
      )
  ) {
    return(fallback)
  }

  trimws(
    x[[1L]]
  )
}

phase4_vector_text <- function(
  x,
  fallback = "not_available"
) {
  x <- as.character(x)
  x[is.na(x)] <- ""
  x <- trimws(x)
  x[!nzchar(x)] <- fallback
  x
}

phase4_format_number <- function(
  x,
  digits = 5L
) {
  if (
    length(x) == 0L ||
      is.na(x[[1L]]) ||
      !is.finite(
        suppressWarnings(
          as.numeric(
            x[[1L]]
          )
        )
      )
  ) {
    return("not_available")
  }

  format(
    signif(
      as.numeric(
        x[[1L]]
      ),
      digits = digits
    ),
    scientific = FALSE,
    trim = TRUE
  )
}

phase4_metric_numeric <- function(
  graph_summary,
  metric_name
) {
  phase4_require_columns(
    graph_summary,
    c(
      "metric",
      "value"
    ),
    "graph_summary"
  )

  index <- match(
    metric_name,
    as.character(
      graph_summary$metric
    )
  )

  if (is.na(index)) {
    return(NA_real_)
  }

  suppressWarnings(
    as.numeric(
      graph_summary$value[[index]]
    )
  )
}

phase4_rank_desc <- function(x) {
  x <- suppressWarnings(
    as.numeric(x)
  )

  rank(
    -x,
    ties.method = "min",
    na.last = "keep"
  )
}

phase4_stable_candidate_order <- function(nodes) {
  order(
    -suppressWarnings(
      as.numeric(
        nodes$candidate_score
      )
    ),
    -suppressWarnings(
      as.numeric(
        nodes$degree
      )
    ),
    -suppressWarnings(
      as.numeric(
        nodes$betweenness
      )
    ),
    phase4_vector_text(
      nodes$gene,
      fallback = ""
    ),
    phase4_vector_text(
      nodes$STRING_id,
      fallback = ""
    ),
    na.last = TRUE
  )
}

phase4_combine_evidence_text <- function(...) {
  values <- unlist(
    list(...),
    use.names = FALSE
  )

  values <- as.character(values)
  values[is.na(values)] <- ""
  values <- trimws(values)
  values <- values[nzchar(values)]
  values <- unique(values)

  if (length(values) == 0L) {
    return("not_available")
  }

  paste(
    values,
    collapse = " | "
  )
}

phase4_candidate_warning <- function(
  module_warning,
  candidate_eligibility,
  conflict_detected
) {
  warning_parts <- character(0)

  module_warning <- phase4_scalar_text(
    module_warning,
    fallback = ""
  )

  if (
    nzchar(module_warning) &&
      !identical(
        module_warning,
        "no_warning"
      )
  ) {
    warning_parts <- c(
      warning_parts,
      module_warning
    )
  }

  candidate_eligibility <- phase4_scalar_text(
    candidate_eligibility,
    fallback = "eligibility_not_available"
  )

  if (!identical(
    candidate_eligibility,
    "review_ready_canonical"
  )) {
    warning_parts <- c(
      warning_parts,
      paste0(
        "candidate_eligibility=",
        candidate_eligibility
      )
    )
  }

  if (isTRUE(conflict_detected)) {
    warning_parts <- c(
      warning_parts,
      "module_conflict_detected"
    )
  }

  if (length(warning_parts) == 0L) {
    return("no_warning")
  }

  paste(
    unique(warning_parts),
    collapse = "; "
  )
}

phase4_prepare_candidate_table <- function(node_annotations) {
  required_columns <- c(
    "STRING_id",
    "gene",
    "pvalue",
    "logFC",
    "abs_logFC",
    "neg_log10_pvalue",
    "degree",
    "betweenness",
    "stress_centrality",
    "community_louvain",
    "candidate_score",
    "entity_class",
    "candidate_eligibility",
    "module_interpretation_class",
    "module_primary_interpretation",
    "module_confidence",
    "module_priority_eligible",
    "module_conflict_detected",
    "module_warning"
  )

  phase4_require_columns(
    node_annotations,
    required_columns,
    "Phase 4 node annotations"
  )

  candidates <- as.data.frame(
    node_annotations,
    stringsAsFactors = FALSE,
    check.names = FALSE
  )

  candidates$degree_component <- minmax(
    candidates$degree
  )

  candidates$betweenness_component <- minmax(
    candidates$betweenness
  )

  candidates$log_stress_component <- minmax(
    log1p(
      suppressWarnings(
        as.numeric(
          candidates$stress_centrality
        )
      )
    )
  )

  candidates$abs_logFC_component <- minmax(
    candidates$abs_logFC
  )

  candidates$statistical_component <- minmax(
    candidates$neg_log10_pvalue
  )

  score_matrix <- cbind(
    candidates$degree_component,
    candidates$betweenness_component,
    candidates$log_stress_component,
    candidates$abs_logFC_component,
    candidates$statistical_component
  )

  candidates$candidate_score_reconstructed <- rowMeans(
    score_matrix,
    na.rm = TRUE
  )

  candidates$score_reconstruction_error <- abs(
    suppressWarnings(
      as.numeric(
        candidates$candidate_score
      )
    ) -
      candidates$candidate_score_reconstructed
  )

  candidate_order <- phase4_stable_candidate_order(
    candidates
  )

  candidates$network_candidate_rank <- NA_integer_
  candidates$network_candidate_rank[candidate_order] <-
    seq_along(candidate_order)

  candidates$degree_rank <- phase4_rank_desc(
    candidates$degree
  )

  candidates$betweenness_rank <- phase4_rank_desc(
    candidates$betweenness
  )

  candidates$stress_rank <- phase4_rank_desc(
    candidates$stress_centrality
  )

  candidates
}

phase4_build_final_priorities <- function(
  candidates,
  maximum_rows = 10L
) {
  eligible <- (
    phase4_vector_text(
      candidates$candidate_eligibility,
      fallback = ""
    ) == "review_ready_canonical" &
      phase4_vector_text(
        candidates$module_interpretation_class,
        fallback = ""
      ) == "biological" &
      !is.na(
        candidates$module_priority_eligible
      ) &
      candidates$module_priority_eligible &
      (
        is.na(
          candidates$module_conflict_detected
        ) |
          !candidates$module_conflict_detected
      )
  )

  selected <- candidates[
    eligible,
    ,
    drop = FALSE
  ]

  if (nrow(selected) > 0L) {
    selected <- selected[
      order(
        selected$network_candidate_rank,
        phase4_vector_text(
          selected$gene,
          fallback = ""
        ),
        phase4_vector_text(
          selected$STRING_id,
          fallback = ""
        ),
        na.last = TRUE
      ),
      ,
      drop = FALSE
    ]

    selected <- utils::head(
      selected,
      maximum_rows
    )
  }

  if (nrow(selected) == 0L) {
    return(
      data.frame(
        priority_rank = integer(),
        network_candidate_rank = integer(),
        gene = character(),
        STRING_id = character(),
        candidate_score = numeric(),
        module_id = character(),
        biological_context = character(),
        candidate_eligibility = character(),
        module_confidence = character(),
        degree_rank = integer(),
        betweenness_rank = integer(),
        stress_rank = integer(),
        logFC = numeric(),
        pvalue = numeric(),
        neg_log10_pvalue = numeric(),
        priority_rationale = character(),
        priority_warning = character(),
        stringsAsFactors = FALSE
      )
    )
  }

  priority_rationale <- vapply(
    seq_len(
      nrow(selected)
    ),
    function(index) {
      paste0(
        selected$gene[[index]],
        " is retained as an exploratory network priority at full-network composite rank ",
        selected$network_candidate_rank[[index]],
        ". Candidate score=",
        phase4_format_number(
          selected$candidate_score[[index]],
          digits = 5L
        ),
        "; degree rank=",
        selected$degree_rank[[index]],
        "; betweenness rank=",
        selected$betweenness_rank[[index]],
        "; stress rank=",
        selected$stress_rank[[index]],
        "; logFC=",
        phase4_format_number(
          selected$logFC[[index]],
          digits = 5L
        ),
        "; module context: ",
        phase4_scalar_text(
          selected$module_primary_interpretation[[index]],
          fallback = "unresolved"
        ),
        ". This rank is exploratory and does not establish therapeutic efficacy or clinical actionability."
      )
    },
    FUN.VALUE = character(1)
  )

  priority_warning <- vapply(
    seq_len(
      nrow(selected)
    ),
    function(index) {
      phase4_candidate_warning(
        module_warning =
          selected$module_warning[[index]],
        candidate_eligibility =
          selected$candidate_eligibility[[index]],
        conflict_detected =
          selected$module_conflict_detected[[index]]
      )
    },
    FUN.VALUE = character(1)
  )

  data.frame(
    priority_rank = seq_len(
      nrow(selected)
    ),
    network_candidate_rank =
      as.integer(
        selected$network_candidate_rank
      ),
    gene = as.character(
      selected$gene
    ),
    STRING_id = as.character(
      selected$STRING_id
    ),
    candidate_score = as.numeric(
      selected$candidate_score
    ),
    module_id = as.character(
      selected$community_louvain
    ),
    biological_context = phase4_vector_text(
      selected$module_primary_interpretation,
      fallback = "unresolved"
    ),
    candidate_eligibility = as.character(
      selected$candidate_eligibility
    ),
    module_confidence = phase4_vector_text(
      selected$module_confidence,
      fallback = "not_available"
    ),
    degree_rank = as.integer(
      selected$degree_rank
    ),
    betweenness_rank = as.integer(
      selected$betweenness_rank
    ),
    stress_rank = as.integer(
      selected$stress_rank
    ),
    logFC = as.numeric(
      selected$logFC
    ),
    pvalue = as.numeric(
      selected$pvalue
    ),
    neg_log10_pvalue = as.numeric(
      selected$neg_log10_pvalue
    ),
    priority_rationale = truncate_text(
      priority_rationale,
      1200L
    ),
    priority_warning = priority_warning,
    stringsAsFactors = FALSE
  )
}

phase4_build_module_priorities <- function(
  module_annotations,
  network_nodes,
  maximum_rows = 5L
) {
  required_columns <- c(
    "module_id",
    "module_size",
    "interpretation_class",
    "interpretation_scope",
    "primary_interpretation",
    "confidence",
    "priority_eligible",
    "representative_genes",
    "positive_marker_genes",
    "supportive_marker_genes",
    "significant_supporting_terms",
    "best_supporting_fdr",
    "secondary_themes",
    "conflict_detected",
    "warning",
    "evidence_rationale"
  )

  phase4_require_columns(
    module_annotations,
    required_columns,
    "Phase 4 module annotations"
  )

  modules <- as.data.frame(
    module_annotations,
    stringsAsFactors = FALSE,
    check.names = FALSE
  )

  eligible <- (
    phase4_vector_text(
      modules$interpretation_class,
      fallback = ""
    ) == "biological" &
      !is.na(
        modules$priority_eligible
      ) &
      modules$priority_eligible &
      (
        is.na(
          modules$conflict_detected
        ) |
          !modules$conflict_detected
      )
  )

  modules <- modules[
    eligible,
    ,
    drop = FALSE
  ]

  if (nrow(modules) == 0L) {
    return(
      data.frame(
        module_priority_rank = integer(),
        module_id = character(),
        module_size = integer(),
        network_fraction = numeric(),
        biological_context = character(),
        interpretation_scope = character(),
        confidence = character(),
        representative_genes = character(),
        marker_evidence_genes = character(),
        significant_supporting_terms = character(),
        best_supporting_fdr = numeric(),
        secondary_themes = character(),
        conflict_detected = logical(),
        warning = character(),
        evidence_rationale = character(),
        stringsAsFactors = FALSE
      )
    )
  }

  confidence_order <- match(
    phase4_vector_text(
      modules$confidence,
      fallback = ""
    ),
    c(
      "high",
      "moderate",
      "low"
    )
  )

  confidence_order[is.na(confidence_order)] <- 99L

  best_fdr_order <- suppressWarnings(
    as.numeric(
      modules$best_supporting_fdr
    )
  )

  best_fdr_order[
    !is.finite(
      best_fdr_order
    )
  ] <- Inf

  module_id_numeric <- suppressWarnings(
    as.numeric(
      modules$module_id
    )
  )

  modules <- modules[
    order(
      confidence_order,
      -suppressWarnings(
        as.numeric(
          modules$module_size
        )
      ),
      best_fdr_order,
      module_id_numeric,
      phase4_vector_text(
        modules$module_id,
        fallback = ""
      ),
      na.last = TRUE
    ),
    ,
    drop = FALSE
  ]

  modules <- utils::head(
    modules,
    maximum_rows
  )

  marker_evidence <- vapply(
    seq_len(
      nrow(modules)
    ),
    function(index) {
      phase4_combine_evidence_text(
        modules$positive_marker_genes[[index]],
        modules$supportive_marker_genes[[index]]
      )
    },
    FUN.VALUE = character(1)
  )

  network_nodes <- suppressWarnings(
    as.numeric(
      network_nodes
    )
  )

  network_fraction <- if (
    length(network_nodes) == 1L &&
      is.finite(network_nodes) &&
      network_nodes > 0
  ) {
    as.numeric(
      modules$module_size
    ) /
      network_nodes
  } else {
    rep(
      NA_real_,
      nrow(modules)
    )
  }

  data.frame(
    module_priority_rank = seq_len(
      nrow(modules)
    ),
    module_id = as.character(
      modules$module_id
    ),
    module_size = as.integer(
      modules$module_size
    ),
    network_fraction = round(
      network_fraction,
      4L
    ),
    biological_context = phase4_vector_text(
      modules$primary_interpretation,
      fallback = "unresolved"
    ),
    interpretation_scope = phase4_vector_text(
      modules$interpretation_scope,
      fallback = "not_available"
    ),
    confidence = phase4_vector_text(
      modules$confidence,
      fallback = "not_available"
    ),
    representative_genes = phase4_vector_text(
      modules$representative_genes,
      fallback = "not_available"
    ),
    marker_evidence_genes = marker_evidence,
    significant_supporting_terms = phase4_vector_text(
      modules$significant_supporting_terms,
      fallback = "not_available"
    ),
    best_supporting_fdr = suppressWarnings(
      as.numeric(
        modules$best_supporting_fdr
      )
    ),
    secondary_themes = phase4_vector_text(
      modules$secondary_themes,
      fallback = "not_available"
    ),
    conflict_detected = as.logical(
      modules$conflict_detected
    ),
    warning = phase4_vector_text(
      modules$warning,
      fallback = "no_warning"
    ),
    evidence_rationale = truncate_text(
      phase4_vector_text(
        modules$evidence_rationale,
        fallback = "not_available"
      ),
      1600L
    ),
    stringsAsFactors = FALSE
  )
}

phase4_build_candidate_evidence <- function(
  candidates,
  final_priorities,
  top_n
) {
  top_n <- suppressWarnings(
    as.integer(
      top_n
    )
  )

  if (
    length(top_n) != 1L ||
      is.na(top_n) ||
      top_n < 1L
  ) {
    stop(
      "top_n must be a positive integer.",
      call. = FALSE
    )
  }

  final_ids <- as.character(
    final_priorities$STRING_id
  )

  include <- (
    candidates$network_candidate_rank <=
      min(
        top_n,
        nrow(candidates)
      ) |
      as.character(
        candidates$STRING_id
      ) %in% final_ids
  )

  selected <- candidates[
    include,
    ,
    drop = FALSE
  ]

  selected <- selected[
    order(
      selected$network_candidate_rank,
      phase4_vector_text(
        selected$gene,
        fallback = ""
      ),
      phase4_vector_text(
        selected$STRING_id,
        fallback = ""
      ),
      na.last = TRUE
    ),
    ,
    drop = FALSE
  ]

  if (nrow(selected) == 0L) {
    stop(
      "Candidate evidence selection produced no rows.",
      call. = FALSE
    )
  }

  priority_status <- ifelse(
    as.character(
      selected$STRING_id
    ) %in% final_ids,
    "final_priority",
    ifelse(
      phase4_vector_text(
        selected$candidate_eligibility,
        fallback = ""
      ) == "review_ready_canonical",
      "extended_review_ready",
      phase4_vector_text(
        selected$candidate_eligibility,
        fallback = "eligibility_not_available"
      )
    )
  )

  warning <- vapply(
    seq_len(
      nrow(selected)
    ),
    function(index) {
      phase4_candidate_warning(
        module_warning =
          selected$module_warning[[index]],
        candidate_eligibility =
          selected$candidate_eligibility[[index]],
        conflict_detected =
          selected$module_conflict_detected[[index]]
      )
    },
    FUN.VALUE = character(1)
  )

  evidence_rationale <- vapply(
    seq_len(
      nrow(selected)
    ),
    function(index) {
      paste0(
        "Composite rank ",
        selected$network_candidate_rank[[index]],
        " combines normalized degree=",
        phase4_format_number(
          selected$degree_component[[index]],
          digits = 4L
        ),
        ", betweenness=",
        phase4_format_number(
          selected$betweenness_component[[index]],
          digits = 4L
        ),
        ", log-stress=",
        phase4_format_number(
          selected$log_stress_component[[index]],
          digits = 4L
        ),
        ", |logFC|=",
        phase4_format_number(
          selected$abs_logFC_component[[index]],
          digits = 4L
        ),
        " and statistical evidence=",
        phase4_format_number(
          selected$statistical_component[[index]],
          digits = 4L
        ),
        ". Module context: ",
        phase4_scalar_text(
          selected$module_primary_interpretation[[index]],
          fallback = "unresolved"
        ),
        ". Eligibility: ",
        phase4_scalar_text(
          selected$candidate_eligibility[[index]],
          fallback = "not_available"
        ),
        "."
      )
    },
    FUN.VALUE = character(1)
  )

  data.frame(
    network_candidate_rank = as.integer(
      selected$network_candidate_rank
    ),
    gene = as.character(
      selected$gene
    ),
    STRING_id = as.character(
      selected$STRING_id
    ),
    candidate_score = as.numeric(
      selected$candidate_score
    ),
    priority_status = priority_status,
    candidate_eligibility = as.character(
      selected$candidate_eligibility
    ),
    entity_class = as.character(
      selected$entity_class
    ),
    module_id = as.character(
      selected$community_louvain
    ),
    biological_context = phase4_vector_text(
      selected$module_primary_interpretation,
      fallback = "unresolved"
    ),
    module_confidence = phase4_vector_text(
      selected$module_confidence,
      fallback = "not_available"
    ),
    degree_rank = as.integer(
      selected$degree_rank
    ),
    betweenness_rank = as.integer(
      selected$betweenness_rank
    ),
    stress_rank = as.integer(
      selected$stress_rank
    ),
    logFC = as.numeric(
      selected$logFC
    ),
    pvalue = as.numeric(
      selected$pvalue
    ),
    neg_log10_pvalue = as.numeric(
      selected$neg_log10_pvalue
    ),
    degree_component = as.numeric(
      selected$degree_component
    ),
    betweenness_component = as.numeric(
      selected$betweenness_component
    ),
    log_stress_component = as.numeric(
      selected$log_stress_component
    ),
    abs_logFC_component = as.numeric(
      selected$abs_logFC_component
    ),
    statistical_component = as.numeric(
      selected$statistical_component
    ),
    evidence_rationale = truncate_text(
      evidence_rationale,
      1200L
    ),
    warning = warning,
    stringsAsFactors = FALSE
  )
}

phase4_network_metric_explanation <- function(metric) {
  explanations <- c(
    nodes =
      "Proteins represented as graph nodes.",
    edges =
      "STRING associations retained as graph edges.",
    components =
      "Disconnected graph components.",
    largest_component_nodes =
      "Nodes in the largest connected component.",
    largest_component_fraction =
      "Fraction of all nodes in the largest connected component.",
    density =
      "Fraction of possible edges that are present.",
    average_degree =
      "Average number of retained associations per protein.",
    global_clustering =
      "Overall tendency of neighboring proteins to form triangles.",
    average_shortest_path_lcc =
      "Mean shortest-path length inside the largest component.",
    diameter_lcc =
      "Longest shortest path inside the largest component.",
    radius_lcc =
      "Minimum eccentricity inside the largest component.",
    louvain_communities =
      "Number of deterministic Louvain modules.",
    louvain_modularity =
      "Modularity of the deterministic Louvain partition.",
    string_score_threshold =
      "Minimum STRING association score retained."
  )

  metric <- as.character(metric)

  result <- unname(
    explanations[metric]
  )

  result[is.na(result)] <-
    "Network-level summary metric."

  result
}

phase4_build_network_overview <- function(
  graph_summary,
  candidates,
  degree_distribution
) {
  phase4_require_columns(
    graph_summary,
    c(
      "metric",
      "value"
    ),
    "graph_summary"
  )

  phase4_require_columns(
    degree_distribution,
    c(
      "degree",
      "n_nodes"
    ),
    "degree_distribution"
  )

  metric_rows <- data.frame(
    section = "network_metric",
    rank = NA_integer_,
    item = as.character(
      graph_summary$metric
    ),
    value = as.character(
      graph_summary$value
    ),
    module_id = NA_character_,
    details = phase4_network_metric_explanation(
      graph_summary$metric
    ),
    stringsAsFactors = FALSE
  )

  hub_filter <- (
    candidates$degree_rank <= 10L |
      candidates$betweenness_rank <= 10L |
      candidates$stress_rank <= 10L
  )

  hubs <- candidates[
    !is.na(hub_filter) &
      hub_filter,
    ,
    drop = FALSE
  ]

  hub_rows <- data.frame(
    section = character(),
    rank = integer(),
    item = character(),
    value = character(),
    module_id = character(),
    details = character(),
    stringsAsFactors = FALSE
  )

  if (nrow(hubs) > 0L) {
    hubs$topology_support_count <- rowSums(
      cbind(
        hubs$degree_rank <= 10L,
        hubs$betweenness_rank <= 10L,
        hubs$stress_rank <= 10L
      ),
      na.rm = TRUE
    )

    hubs$best_topology_rank <- apply(
      cbind(
        hubs$degree_rank,
        hubs$betweenness_rank,
        hubs$stress_rank
      ),
      1L,
      function(values) {
        values <- values[
          is.finite(values)
        ]

        if (length(values) == 0L) {
          Inf
        } else {
          min(values)
        }
      }
    )

    hubs <- hubs[
      order(
        -hubs$topology_support_count,
        hubs$best_topology_rank,
        -suppressWarnings(
          as.numeric(
            hubs$candidate_score
          )
        ),
        phase4_vector_text(
          hubs$gene,
          fallback = ""
        ),
        phase4_vector_text(
          hubs$STRING_id,
          fallback = ""
        ),
        na.last = TRUE
      ),
      ,
      drop = FALSE
    ]

    hub_rows <- data.frame(
      section = "topological_hub",
      rank = seq_len(
        nrow(hubs)
      ),
      item = as.character(
        hubs$gene
      ),
      value = paste0(
        "candidate_score=",
        vapply(
          hubs$candidate_score,
          phase4_format_number,
          FUN.VALUE = character(1),
          digits = 5L
        )
      ),
      module_id = as.character(
        hubs$community_louvain
      ),
      details = paste0(
        "degree=",
        hubs$degree,
        " (rank ",
        hubs$degree_rank,
        "); betweenness=",
        signif(
          hubs$betweenness,
          5L
        ),
        " (rank ",
        hubs$betweenness_rank,
        "); stress=",
        hubs$stress_centrality,
        " (rank ",
        hubs$stress_rank,
        "); topology_top10_support_count=",
        hubs$topology_support_count
      ),
      stringsAsFactors = FALSE
    )
  }

  degree_rows <- data.frame(
    section = "degree_distribution",
    rank = as.integer(
      degree_distribution$degree
    ),
    item = as.character(
      degree_distribution$degree
    ),
    value = as.character(
      degree_distribution$n_nodes
    ),
    module_id = NA_character_,
    details = paste0(
      "degree=",
      degree_distribution$degree,
      "; n_nodes=",
      degree_distribution$n_nodes,
      if (
        all(
          c(
            "log10_degree",
            "log10_n_nodes"
          ) %in%
            names(
              degree_distribution
            )
        )
      ) {
        paste0(
          "; log10_degree=",
          signif(
            degree_distribution$log10_degree,
            5L
          ),
          "; log10_n_nodes=",
          signif(
            degree_distribution$log10_n_nodes,
            5L
          )
        )
      } else {
        ""
      }
    ),
    stringsAsFactors = FALSE
  )

  rbind(
    metric_rows,
    hub_rows,
    degree_rows
  )
}

phase4_build_methods_and_limitations <- function() {
  data.frame(
    section = c(
      rep(
        "Report use",
        3L
      ),
      rep(
        "Candidate prioritization",
        5L
      ),
      rep(
        "Biological interpretation",
        7L
      ),
      rep(
        "Limitations",
        5L
      ),
      rep(
        "Reproducibility",
        3L
      )
    ),
    item = c(
      "purpose",
      "reading_order",
      "analytical_vs_technical",
      "candidate_score",
      "score_components",
      "score_scope",
      "automatic_priority_filter",
      "priority_is_not_efficacy",
      "evidence_engine",
      "hierarchical_context",
      "significance_policy",
      "generic_term_filter",
      "conflicts_and_warnings",
      "technical_covariate_signatures",
      "protein_module_context",
      "bulk_RNA_seq_composition",
      "no_deconvolution",
      "STRING_scope",
      "putative_interpretation",
      "special_entities",
      "offline_mode",
      "STRING_and_Louvain_pinning",
      "pvalue_underflow"
    ),
    description = c(
      "The analytical workbook is a concise human-readable summary of the reconstructed patient-specific STRING-derived PPI subnetwork.",
      "Read Executive summary, Final priorities, Module priorities, Candidate evidence, Network overview, then Methods and limitations.",
      "Raw mapping, complete modules, unfiltered enrichment, complete node metrics and validation tables remain in the technical workbook.",
      "candidate_score is an exploratory within-network rank, not a probability or clinical actionability estimate.",
      "The score is the mean of normalized degree, betweenness, log-transformed stress, absolute logFC and -log10(p-value) components.",
      "Score values are comparable within the reconstructed case network; cross-patient numerical comparison requires separate calibration.",
      "Automatic final priority requires a review-ready canonical entity in an eligible non-conflicting biological module.",
      "A high rank does not establish druggability, tumor dependency, therapeutic efficacy or expected clinical response.",
      "The Phase 4 engine integrates curated positive, supportive and exclusion markers with significant specific local STRING terms.",
      "Interpretations are separated into compartment, lineage, state and process; primary_interpretation is a conservative synthesis.",
      "Only non-generic supporting enrichment terms with FDR <= 0.05 are used as analytical biological evidence.",
      "Broad generic terms are excluded from primary analytical interpretation and retained only for technical audit.",
      "Mixed lineage evidence, insufficient evidence and eligibility restrictions are reported explicitly rather than silently resolved.",
      "Y-chromosome and similar signatures are reported as technical or covariate context and are ineligible for automatic biological priority.",
      "A protein inherits biological context through module membership; this does not prove that the protein causally drives the program.",
      "Bulk tumor RNA-seq can contain malignant, immune, stromal, endothelial and other specimen components.",
      "CancerPPIr does not estimate cell fractions and does not perform reference-based deconvolution in this workflow.",
      "STRING associations are database-derived known or predicted associations, not patient-specific physical interaction measurements.",
      "Module labels are evidence-supported putative contexts and require histological, molecular or experimental validation.",
      "Predicted loci, immune-receptor loci and other special entities remain visible for network evidence but may be excluded from automatic protein priority.",
      "Functional annotation runs from pinned local STRING cache files without online enrichment dependence.",
      "STRING version, confidence threshold and Louvain seed are recorded as analytical method parameters.",
      "Raw Excel p-values are preserved; -log10(p-value) provides a stable representation when floating-point underflow produces zero."
    ),
    stringsAsFactors = FALSE
  )
}

phase4_build_executive_summary <- function(
  input_rows,
  mapped_proteins,
  unmapped_input_rows,
  mapping_rate_percent,
  graph_summary,
  module_annotations,
  final_priorities,
  score_threshold,
  string_version,
  louvain_seed,
  fdr_threshold
) {
  module_class <- phase4_vector_text(
    module_annotations$interpretation_class,
    fallback = ""
  )

  priority_eligible <- (
    !is.na(
      module_annotations$priority_eligible
    ) &
      module_annotations$priority_eligible
  )

  conflict_detected <- (
    !is.na(
      module_annotations$conflict_detected
    ) &
      module_annotations$conflict_detected
  )

  values <- c(
    as.character(input_rows),
    as.character(mapped_proteins),
    as.character(unmapped_input_rows),
    paste0(
      phase4_format_number(
        mapping_rate_percent,
        digits = 5L
      ),
      "%"
    ),
    phase4_format_number(
      phase4_metric_numeric(
        graph_summary,
        "nodes"
      ),
      digits = 8L
    ),
    phase4_format_number(
      phase4_metric_numeric(
        graph_summary,
        "edges"
      ),
      digits = 8L
    ),
    phase4_format_number(
      phase4_metric_numeric(
        graph_summary,
        "components"
      ),
      digits = 8L
    ),
    phase4_format_number(
      phase4_metric_numeric(
        graph_summary,
        "largest_component_nodes"
      ),
      digits = 8L
    ),
    phase4_format_number(
      phase4_metric_numeric(
        graph_summary,
        "largest_component_fraction"
      ),
      digits = 5L
    ),
    as.character(
      nrow(
        module_annotations
      )
    ),
    as.character(
      sum(
        module_class == "biological" &
          priority_eligible &
          !conflict_detected,
        na.rm = TRUE
      )
    ),
    as.character(
      sum(
        module_class ==
          "technical_or_covariate",
        na.rm = TRUE
      )
    ),
    as.character(
      sum(
        module_class ==
          "mixed_biological",
        na.rm = TRUE
      )
    ),
    as.character(
      sum(
        module_class ==
          "unresolved",
        na.rm = TRUE
      )
    ),
    as.character(
      nrow(
        final_priorities
      )
    ),
    paste0(
      "schema=",
      CANCERPPIR_ANALYTICAL_SCHEMA_VERSION,
      "; STRING=",
      string_version,
      "; score_threshold=",
      score_threshold,
      "; offline_enrichment=TRUE; FDR<=",
      fdr_threshold,
      "; Louvain_seed=",
      louvain_seed
    )
  )

  data.frame(
    item = c(
      "input_rows",
      "mapped_proteins",
      "unmapped_input_rows",
      "mapping_rate_percent",
      "network_nodes",
      "network_edges",
      "connected_components",
      "largest_component_nodes",
      "largest_component_fraction",
      "louvain_modules",
      "priority_eligible_modules",
      "technical_or_covariate_modules",
      "mixed_biological_modules",
      "unresolved_modules",
      "final_priority_candidates",
      "run_configuration"
    ),
    value = values,
    interpretation = c(
      "Rows in the normalized input table.",
      "Unique human STRING proteins retained after final mapping.",
      "Input rows not represented by a final STRING protein.",
      "Final mapped percentage reported by the mapping stage.",
      "Proteins in the reconstructed network.",
      "STRING associations retained after thresholding and graph simplification.",
      "Disconnected network components.",
      "Nodes in the largest connected component.",
      "Fraction of network nodes in the largest connected component.",
      "Deterministically detected Louvain modules.",
      "Biological modules eligible for automatic priority reporting.",
      "Modules classified as technical or covariate signatures.",
      "Modules with conflicting biological evidence.",
      "Modules without sufficient specific evidence for a resolved priority.",
      "Proteins retained after entity and module eligibility filtering.",
      "Pinned analytical configuration for reproducibility."
    ),
    stringsAsFactors = FALSE
  )
}

phase4_expected_analytical_columns <- function() {
  list(
    "Executive summary" = c(
      "item",
      "value",
      "interpretation"
    ),
    "Final priorities" = c(
      "priority_rank",
      "network_candidate_rank",
      "gene",
      "STRING_id",
      "candidate_score",
      "module_id",
      "biological_context",
      "candidate_eligibility",
      "module_confidence",
      "degree_rank",
      "betweenness_rank",
      "stress_rank",
      "logFC",
      "pvalue",
      "neg_log10_pvalue",
      "priority_rationale",
      "priority_warning"
    ),
    "Module priorities" = c(
      "module_priority_rank",
      "module_id",
      "module_size",
      "network_fraction",
      "biological_context",
      "interpretation_scope",
      "confidence",
      "representative_genes",
      "marker_evidence_genes",
      "significant_supporting_terms",
      "best_supporting_fdr",
      "secondary_themes",
      "conflict_detected",
      "warning",
      "evidence_rationale"
    ),
    "Candidate evidence" = c(
      "network_candidate_rank",
      "gene",
      "STRING_id",
      "candidate_score",
      "priority_status",
      "candidate_eligibility",
      "entity_class",
      "module_id",
      "biological_context",
      "module_confidence",
      "degree_rank",
      "betweenness_rank",
      "stress_rank",
      "logFC",
      "pvalue",
      "neg_log10_pvalue",
      "degree_component",
      "betweenness_component",
      "log_stress_component",
      "abs_logFC_component",
      "statistical_component",
      "evidence_rationale",
      "warning"
    ),
    "Network overview" = c(
      "section",
      "rank",
      "item",
      "value",
      "module_id",
      "details"
    ),
    "Methods and limitations" = c(
      "section",
      "item",
      "description"
    )
  )
}

validate_phase4_analytical_workbook <- function(
  sheets,
  candidate_audit,
  significant_terms,
  phase4_validation,
  fdr_threshold = 0.05
) {
  checks <- list()

  add_check <- function(
    check_id,
    condition,
    details
  ) {
    checks[[length(checks) + 1L]] <<-
      data.frame(
        check_id = check_id,
        status = if (isTRUE(condition)) {
          "PASS"
        } else {
          "FAIL"
        },
        details = details,
        stringsAsFactors = FALSE
      )
  }

  add_check(
    "exact_sheet_order",
    identical(
      names(sheets),
      CANCERPPIR_ANALYTICAL_SHEET_NAMES
    ),
    paste(
      names(sheets),
      collapse = " | "
    )
  )

  expected_columns <- phase4_expected_analytical_columns()

  for (sheet_name in names(
    expected_columns
  )) {
    observed_columns <- if (
      sheet_name %in% names(sheets)
    ) {
      names(
        sheets[[sheet_name]]
      )
    } else {
      character(0)
    }

    add_check(
      paste0(
        "schema_",
        gsub(
          "[^a-z0-9]+",
          "_",
          tolower(
            sheet_name
          )
        )
      ),
      identical(
        observed_columns,
        expected_columns[[sheet_name]]
      ),
      paste(
        observed_columns,
        collapse = " | "
      )
    )
  }

  final_priorities <- sheets[[
    "Final priorities"
  ]]

  module_priorities <- sheets[[
    "Module priorities"
  ]]

  candidate_evidence <- sheets[[
    "Candidate evidence"
  ]]

  add_check(
    "executive_summary_has_16_rows",
    nrow(
      sheets[[
        "Executive summary"
      ]]
    ) == 16L,
    as.character(
      nrow(
        sheets[[
          "Executive summary"
        ]]
      )
    )
  )

  add_check(
    "methods_has_23_rows",
    nrow(
      sheets[[
        "Methods and limitations"
      ]]
    ) == 23L,
    as.character(
      nrow(
        sheets[[
          "Methods and limitations"
        ]]
      )
    )
  )

  add_check(
    "final_priorities_maximum_10",
    nrow(
      final_priorities
    ) <= 10L,
    as.character(
      nrow(
        final_priorities
      )
    )
  )

  add_check(
    "module_priorities_maximum_5",
    nrow(
      module_priorities
    ) <= 5L,
    as.character(
      nrow(
        module_priorities
      )
    )
  )

  add_check(
    "final_priority_ids_unique",
    !anyDuplicated(
      as.character(
        final_priorities$STRING_id
      )
    ),
    "STRING_id"
  )

  add_check(
    "candidate_evidence_ids_unique",
    !anyDuplicated(
      as.character(
        candidate_evidence$STRING_id
      )
    ),
    "STRING_id"
  )

  add_check(
    "final_priorities_review_ready_canonical",
    nrow(
      final_priorities
    ) == 0L ||
      all(
        final_priorities$candidate_eligibility ==
          "review_ready_canonical"
      ),
    paste(
      unique(
        final_priorities$candidate_eligibility
      ),
      collapse = " | "
    )
  )

  finite_error <- suppressWarnings(
    as.numeric(
      candidate_audit$score_reconstruction_error
    )
  )

  finite_error <- finite_error[
    is.finite(
      finite_error
    )
  ]

  add_check(
    "candidate_score_reconstructs",
    length(finite_error) > 0L &&
      max(
        finite_error
      ) <= 1e-12,
    if (length(finite_error) > 0L) {
      format(
        max(finite_error),
        scientific = TRUE
      )
    } else {
      "no_finite_rows"
    }
  )

  phase4_require_columns(
    significant_terms,
    c(
      "fdr",
      "is_significant",
      "is_generic"
    ),
    "Phase 4 significant terms"
  )

  term_fdr <- suppressWarnings(
    as.numeric(
      significant_terms$fdr
    )
  )

  term_ok <- (
    nrow(
      significant_terms
    ) == 0L ||
      all(
        significant_terms$is_significant &
          !significant_terms$is_generic &
          is.finite(
            term_fdr
          ) &
          term_fdr <=
            fdr_threshold
      )
  )

  add_check(
    "analytical_terms_respect_fdr_and_generic_filter",
    term_ok,
    paste0(
      "rows=",
      nrow(significant_terms),
      "; threshold=",
      fdr_threshold
    )
  )

  phase4_require_columns(
    phase4_validation,
    c(
      "check_id",
      "status"
    ),
    "Phase 4 validation"
  )

  add_check(
    "upstream_phase4_validation_passes",
    !any(
      as.character(
        phase4_validation$status
      ) == "FAIL"
    ),
    paste(
      phase4_validation$check_id[
        as.character(
          phase4_validation$status
        ) == "FAIL"
      ],
      collapse = " | "
    )
  )

  forbidden_columns <- c(
    "final_functional_label",
    "putative_biological_program",
    "label_source",
    "label_evidence_score",
    "label_assignment_mode"
  )

  analytical_columns <- unique(
    unlist(
      lapply(
        sheets,
        names
      ),
      use.names = FALSE
    )
  )

  add_check(
    "legacy_label_columns_absent",
    length(
      intersect(
        forbidden_columns,
        analytical_columns
      )
    ) == 0L,
    paste(
      intersect(
        forbidden_columns,
        analytical_columns
      ),
      collapse = " | "
    )
  )

  validation <- do.call(
    rbind,
    checks
  )

  rownames(validation) <- NULL

  failures <- validation[
    validation$status == "FAIL",
    ,
    drop = FALSE
  ]

  if (nrow(failures) > 0L) {
    stop(
      paste0(
        "Phase 4 analytical workbook validation failed: ",
        paste(
          failures$check_id,
          collapse = ", "
        ),
        "."
      ),
      call. = FALSE
    )
  }

  validation
}

build_phase4_analytical_workbook <- function(
  input_rows,
  mapped_proteins,
  unmapped_input_rows,
  mapping_rate_percent,
  graph_summary,
  score_threshold,
  top_n,
  degree_distribution,
  phase4_evidence,
  string_version = "12.0",
  louvain_seed = CANCERPPIR_LOUVAIN_SEED,
  fdr_threshold = 0.05
) {
  required_evidence_objects <- c(
    "module_annotations",
    "significant_module_terms",
    "node_annotations",
    "validation"
  )

  missing_evidence_objects <- setdiff(
    required_evidence_objects,
    names(
      phase4_evidence
    )
  )

  if (length(missing_evidence_objects) > 0L) {
    stop(
      paste0(
        "phase4_evidence is missing object(s): ",
        paste(
          missing_evidence_objects,
          collapse = ", "
        ),
        "."
      ),
      call. = FALSE
    )
  }

  candidates <- phase4_prepare_candidate_table(
    phase4_evidence$node_annotations
  )

  final_priorities <- phase4_build_final_priorities(
    candidates = candidates,
    maximum_rows = 10L
  )

  network_nodes <- phase4_metric_numeric(
    graph_summary,
    "nodes"
  )

  module_priorities <- phase4_build_module_priorities(
    module_annotations =
      phase4_evidence$module_annotations,
    network_nodes = network_nodes,
    maximum_rows = 5L
  )

  candidate_evidence <- phase4_build_candidate_evidence(
    candidates = candidates,
    final_priorities = final_priorities,
    top_n = top_n
  )

  executive_summary <- phase4_build_executive_summary(
    input_rows = input_rows,
    mapped_proteins = mapped_proteins,
    unmapped_input_rows = unmapped_input_rows,
    mapping_rate_percent = mapping_rate_percent,
    graph_summary = graph_summary,
    module_annotations =
      phase4_evidence$module_annotations,
    final_priorities = final_priorities,
    score_threshold = score_threshold,
    string_version = string_version,
    louvain_seed = louvain_seed,
    fdr_threshold = fdr_threshold
  )

  network_overview <- phase4_build_network_overview(
    graph_summary = graph_summary,
    candidates = candidates,
    degree_distribution = degree_distribution
  )

  methods_and_limitations <-
    phase4_build_methods_and_limitations()

  sheets <- list(
    "Executive summary" = executive_summary,
    "Final priorities" = final_priorities,
    "Module priorities" = module_priorities,
    "Candidate evidence" = candidate_evidence,
    "Network overview" = network_overview,
    "Methods and limitations" =
      methods_and_limitations
  )

  validation <- validate_phase4_analytical_workbook(
    sheets = sheets,
    candidate_audit = candidates,
    significant_terms =
      phase4_evidence$significant_module_terms,
    phase4_validation =
      phase4_evidence$validation,
    fdr_threshold = fdr_threshold
  )

  list(
    schema_version =
      CANCERPPIR_ANALYTICAL_SCHEMA_VERSION,
    sheets = sheets,
    validation = validation,
    candidate_score_audit = candidates[
      ,
      c(
        "STRING_id",
        "gene",
        "candidate_score",
        "candidate_score_reconstructed",
        "score_reconstruction_error"
      ),
      drop = FALSE
    ]
  )
}
