# CancerPPIr: canonical biological annotation output
#
# Responsibility:
# Provide the public Phase 4.6 contracts for canonical biological evidence,
# GraphML node attributes and the structured pipeline return object.
#
# Legacy labeling tables may remain available under result$compatibility for
# migration and audit. They must not drive analytical priorities, GraphML
# annotation or the canonical public result object.

CANCERPPIR_BIOLOGICAL_EVIDENCE_SCHEMA_VERSION <- "1.0.0"
CANCERPPIR_GRAPHML_SCHEMA_VERSION <- "4.6.0"
CANCERPPIR_PIPELINE_RESULT_SCHEMA_VERSION <- "4.7.0"

CANCERPPIR_LEGACY_ANNOTATION_FIELDS <- c(
  "module_direction",
  "clean_module_label",
  "marker_clean_label",
  "marker_based_direction",
  "marker_evidence_genes",
  "enrichment_evidence_terms",
  "final_functional_label",
  "putative_biological_program",
  "specific_label_candidate",
  "fallback_label",
  "label_assignment_mode",
  "label_source",
  "label_evidence_score",
  "label_confidence",
  "label_warning",
  "biological_direction_rationale"
)

phase4_legacy_annotation_migration <- function() {
  data.frame(
    legacy_field = CANCERPPIR_LEGACY_ANNOTATION_FIELDS,
    canonical_replacement = c(
      "module_primary_interpretation",
      "module_primary_interpretation",
      "module_primary_interpretation",
      "module_lineage/module_state/module_process",
      "module_positive_marker_genes/module_supportive_marker_genes",
      "module_significant_supporting_terms",
      "module_primary_interpretation",
      "module_primary_interpretation",
      "module_primary_interpretation",
      "module_interpretation_scope",
      "module_interpretation_scope",
      "module_interpretation_class plus evidence fields",
      "module_confidence plus explicit evidence fields",
      "module_confidence",
      "module_warning",
      "module_evidence_rationale"
    ),
    compatibility_status = c(
      rep("deprecated_compatibility_only", 16L)
    ),
    decision_use = c(
      rep("forbidden_for_canonical_priority_and_graphml", 16L)
    ),
    stringsAsFactors = FALSE
  )
}

phase4_required_canonical_module_fields <- function() {
  c(
    "community_louvain",
    "module_id",
    "module_size",
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
}

phase4_required_canonical_node_fields <- function() {
  c(
    "STRING_id",
    "gene",
    "pvalue",
    "logFC",
    "abs_logFC",
    "neg_log10_pvalue",
    "degree",
    "betweenness",
    "closeness",
    "harmonic_closeness",
    "stress_centrality",
    "local_clustering",
    "component",
    "in_largest_component",
    "community_louvain",
    "candidate_score",
    "entity_class",
    "candidate_eligibility",
    "module_interpretation_class",
    "module_interpretation_scope",
    "module_compartment",
    "module_lineage",
    "module_state",
    "module_process",
    "module_primary_interpretation",
    "module_secondary_themes",
    "module_confidence",
    "module_priority_eligible",
    "module_positive_marker_genes",
    "module_supportive_marker_genes",
    "module_term_supporting_genes",
    "module_significant_supporting_terms",
    "module_best_supporting_fdr",
    "module_conflict_detected",
    "module_warning",
    "module_evidence_rationale"
  )
}


phase4_canonical_graphml_attribute_names <- function() {
  c(
    "STRING_id",
    "gene",
    "annotation_schema_version",
    "graphml_schema_version",
    "pvalue",
    "pvalue_was_floored_for_graphml",
    "logFC",
    "abs_logFC",
    "neg_log10_pvalue",
    "degree",
    "betweenness",
    "stress_centrality",
    "closeness",
    "harmonic_closeness",
    "local_clustering",
    "component",
    "in_largest_component",
    "community_louvain",
    "louvain_module_id",
    "candidate_score",
    "network_candidate_rank",
    "degree_rank",
    "betweenness_rank",
    "stress_rank",
    "degree_component",
    "betweenness_component",
    "log_stress_component",
    "abs_logFC_component",
    "statistical_component",
    "entity_class",
    "candidate_eligibility",
    "candidate_priority_status",
    "module_interpretation_class",
    "module_interpretation_scope",
    "module_compartment",
    "module_lineage",
    "module_state",
    "module_process",
    "module_primary_interpretation",
    "module_secondary_themes",
    "module_confidence",
    "module_priority_eligible",
    "module_positive_marker_genes",
    "module_supportive_marker_genes",
    "module_term_supporting_genes",
    "module_significant_supporting_terms",
    "module_best_supporting_fdr",
    "module_conflict_detected",
    "module_warning",
    "module_evidence_rationale",
    "cytoscape_label",
    "cytoscape_module_label",
    "cytoscape_priority_class"
  )
}

phase4_validate_canonical_biological_evidence <- function(
  biological_evidence
) {
  required_objects <- c(
    "module_annotations",
    "module_rule_evidence",
    "significant_module_terms",
    "node_annotations",
    "validation"
  )

  object_is_list <- is.list(biological_evidence)

  missing_objects <- if (object_is_list) {
    setdiff(required_objects, names(biological_evidence))
  } else {
    required_objects
  }

  module_schema_valid <- FALSE
  node_schema_valid <- FALSE
  validation_passes <- FALSE
  module_ids_unique <- FALSE
  node_ids_unique <- FALSE

  if (object_is_list && length(missing_objects) == 0L) {
    module_schema_valid <- all(
      phase4_required_canonical_module_fields() %in%
        names(biological_evidence$module_annotations)
    )

    node_schema_valid <- all(
      phase4_required_canonical_node_fields() %in%
        names(biological_evidence$node_annotations)
    )

    validation_passes <- is.data.frame(
      biological_evidence$validation
    ) &&
      all(c("check_id", "status") %in%
        names(biological_evidence$validation)) &&
      !any(
        as.character(biological_evidence$validation$status) == "FAIL"
      )

    if (module_schema_valid) {
      module_ids_unique <- !any(
        duplicated(
          as.character(
            biological_evidence$module_annotations$community_louvain
          )
        )
      )
    }

    if (node_schema_valid) {
      node_ids <- as.character(
        biological_evidence$node_annotations$STRING_id
      )

      node_ids_unique <- all(!is.na(node_ids) & nzchar(node_ids)) &&
        !any(duplicated(node_ids))
    }
  }

  checks <- c(
    evidence_object_is_list = object_is_list,
    required_evidence_objects_present = length(missing_objects) == 0L,
    canonical_module_schema_present = module_schema_valid,
    canonical_node_schema_present = node_schema_valid,
    upstream_evidence_validation_passes = validation_passes,
    module_ids_are_unique = module_ids_unique,
    node_STRING_ids_are_unique = node_ids_unique
  )

  data.frame(
    check_id = names(checks),
    status = ifelse(checks, "PASS", "FAIL"),
    details = c(
      if (object_is_list) {
        "list"
      } else {
        object_class <- paste(class(biological_evidence), collapse = " | ")
        if (nzchar(object_class)) object_class else "no_class"
      },
      if (length(missing_objects) == 0L) {
        "all required objects present"
      } else {
        paste(missing_objects, collapse = "; ")
      },
      paste(
        setdiff(
          phase4_required_canonical_module_fields(),
          if (object_is_list && "module_annotations" %in%
            names(biological_evidence)) {
            names(biological_evidence$module_annotations)
          } else {
            character()
          }
        ),
        collapse = "; "
      ),
      paste(
        setdiff(
          phase4_required_canonical_node_fields(),
          if (object_is_list && "node_annotations" %in%
            names(biological_evidence)) {
            names(biological_evidence$node_annotations)
          } else {
            character()
          }
        ),
        collapse = "; "
      ),
      if (validation_passes) "no upstream FAIL rows" else "upstream validation unavailable or failed",
      if (module_ids_unique) "unique" else "missing or duplicated",
      if (node_ids_unique) "unique" else "missing or duplicated"
    ),
    stringsAsFactors = FALSE
  )
}

phase4_stop_on_failed_validation <- function(
  validation,
  context
) {
  failures <- validation[
    as.character(validation$status) == "FAIL",
    ,
    drop = FALSE
  ]

  if (nrow(failures) > 0L) {
    stop(
      paste0(
        context,
        " validation failed: ",
        paste(
          failures$check_id,
          collapse = ", "
        ),
        "."
      ),
      call. = FALSE
    )
  }

  invisible(TRUE)
}

phase4_build_canonical_graphml_attributes <- function(
  node_annotations,
  final_priorities,
  candidate_evidence
) {
  phase4_require_columns(
    node_annotations,
    phase4_required_canonical_node_fields(),
    "Canonical node annotations"
  )

  phase4_require_columns(
    final_priorities,
    c("STRING_id"),
    "Final priorities"
  )

  phase4_require_columns(
    candidate_evidence,
    c("STRING_id", "priority_status"),
    "Candidate evidence"
  )

  candidates <- phase4_prepare_candidate_table(
    node_annotations
  )

  final_ids <- as.character(
    final_priorities$STRING_id
  )

  candidate_status <- as.character(
    candidate_evidence$priority_status[
      match(
        as.character(candidates$STRING_id),
        as.character(candidate_evidence$STRING_id)
      )
    ]
  )

  candidate_status[
    as.character(candidates$STRING_id) %in% final_ids
  ] <- "final_priority"

  missing_status <- is.na(candidate_status) | !nzchar(candidate_status)

  missing_eligibility <- as.character(
    candidates$candidate_eligibility[missing_status]
  )

  missing_eligibility[
    is.na(missing_eligibility) | !nzchar(missing_eligibility)
  ] <- "eligibility_not_available"

  candidate_status[missing_status] <- ifelse(
    missing_eligibility == "review_ready_canonical",
    "not_in_reported_top_n",
    missing_eligibility
  )

  pvalue_export <- prepare_graphml_pvalue_export(
    candidates$pvalue
  )

  attributes <- data.frame(
    STRING_id = as.character(candidates$STRING_id),
    gene = as.character(candidates$gene),
    annotation_schema_version =
      CANCERPPIR_BIOLOGICAL_EVIDENCE_SCHEMA_VERSION,
    graphml_schema_version =
      CANCERPPIR_GRAPHML_SCHEMA_VERSION,
    pvalue = as.numeric(pvalue_export$value),
    pvalue_was_floored_for_graphml =
      as.logical(pvalue_export$floor_applied),
    logFC = as.numeric(candidates$logFC),
    abs_logFC = as.numeric(candidates$abs_logFC),
    neg_log10_pvalue = as.numeric(candidates$neg_log10_pvalue),
    degree = as.numeric(candidates$degree),
    betweenness = as.numeric(candidates$betweenness),
    stress_centrality = as.numeric(candidates$stress_centrality),
    closeness = as.numeric(candidates$closeness),
    harmonic_closeness = as.numeric(candidates$harmonic_closeness),
    local_clustering = as.numeric(candidates$local_clustering),
    component = as.numeric(candidates$component),
    in_largest_component = as.logical(candidates$in_largest_component),
    community_louvain = as.character(candidates$community_louvain),
    louvain_module_id = as.character(candidates$community_louvain),
    candidate_score = as.numeric(candidates$candidate_score),
    network_candidate_rank = as.integer(candidates$network_candidate_rank),
    degree_rank = as.integer(candidates$degree_rank),
    betweenness_rank = as.integer(candidates$betweenness_rank),
    stress_rank = as.integer(candidates$stress_rank),
    degree_component = as.numeric(candidates$degree_component),
    betweenness_component = as.numeric(candidates$betweenness_component),
    log_stress_component = as.numeric(candidates$log_stress_component),
    abs_logFC_component = as.numeric(candidates$abs_logFC_component),
    statistical_component = as.numeric(candidates$statistical_component),
    entity_class = as.character(candidates$entity_class),
    candidate_eligibility = as.character(candidates$candidate_eligibility),
    candidate_priority_status = candidate_status,
    module_interpretation_class =
      as.character(candidates$module_interpretation_class),
    module_interpretation_scope =
      as.character(candidates$module_interpretation_scope),
    module_compartment = as.character(candidates$module_compartment),
    module_lineage = as.character(candidates$module_lineage),
    module_state = as.character(candidates$module_state),
    module_process = as.character(candidates$module_process),
    module_primary_interpretation =
      as.character(candidates$module_primary_interpretation),
    module_secondary_themes =
      as.character(candidates$module_secondary_themes),
    module_confidence = as.character(candidates$module_confidence),
    module_priority_eligible =
      as.logical(candidates$module_priority_eligible),
    module_positive_marker_genes =
      as.character(candidates$module_positive_marker_genes),
    module_supportive_marker_genes =
      as.character(candidates$module_supportive_marker_genes),
    module_term_supporting_genes =
      as.character(candidates$module_term_supporting_genes),
    module_significant_supporting_terms =
      as.character(candidates$module_significant_supporting_terms),
    module_best_supporting_fdr =
      as.numeric(candidates$module_best_supporting_fdr),
    module_conflict_detected =
      as.logical(candidates$module_conflict_detected),
    module_warning = as.character(candidates$module_warning),
    module_evidence_rationale =
      as.character(candidates$module_evidence_rationale),
    cytoscape_label = as.character(candidates$gene),
    cytoscape_module_label =
      as.character(candidates$module_primary_interpretation),
    cytoscape_priority_class = candidate_status,
    stringsAsFactors = FALSE,
    check.names = FALSE
  )

  validation <- phase4_validate_canonical_graphml_attributes(
    attributes
  )

  phase4_stop_on_failed_validation(
    validation,
    "Canonical GraphML attributes"
  )

  attributes
}

phase4_validate_canonical_graphml_attributes <- function(
  attributes
) {
  expected_columns <-
    phase4_canonical_graphml_attribute_names()

  schema_complete <- is.data.frame(attributes) &&
    identical(names(attributes), expected_columns)

  legacy_absent <- is.data.frame(attributes) &&
    !any(
      CANCERPPIR_LEGACY_ANNOTATION_FIELDS %in%
        names(attributes)
    )

  ids_unique <- FALSE
  pvalues_safe <- FALSE
  schema_versions_valid <- FALSE
  canonical_labels_used <- FALSE

  if (schema_complete) {
    ids <- as.character(attributes$STRING_id)
    ids_unique <- all(!is.na(ids) & nzchar(ids)) &&
      !any(duplicated(ids))

    pvalues <- suppressWarnings(
      as.numeric(attributes$pvalue)
    )

    pvalues_safe <- all(
      is.na(pvalues) |
        (
          is.finite(pvalues) &
            pvalues >= CANCERPPIR_GRAPHML_PVALUE_FLOOR &
            pvalues <= 1
        )
    )

    schema_versions_valid <- all(
      as.character(attributes$annotation_schema_version) ==
        CANCERPPIR_BIOLOGICAL_EVIDENCE_SCHEMA_VERSION
    ) &&
      all(
        as.character(attributes$graphml_schema_version) ==
          CANCERPPIR_GRAPHML_SCHEMA_VERSION
      )

    canonical_labels_used <- identical(
      as.character(attributes$cytoscape_module_label),
      as.character(attributes$module_primary_interpretation)
    )
  }

  checks <- c(
    canonical_graphml_schema_complete = schema_complete,
    legacy_annotation_fields_absent = legacy_absent,
    STRING_ids_are_unique = ids_unique,
    graphml_pvalues_are_parser_safe = pvalues_safe,
    graphml_schema_versions_are_pinned = schema_versions_valid,
    cytoscape_labels_use_canonical_interpretation =
      canonical_labels_used
  )

  data.frame(
    check_id = names(checks),
    status = ifelse(checks, "PASS", "FAIL"),
    stringsAsFactors = FALSE
  )
}

phase4_apply_canonical_graphml_attributes <- function(
  graph,
  attributes
) {
  if (!inherits(graph, "igraph")) {
    stop(
      "graph must be an igraph object.",
      call. = FALSE
    )
  }

  validation <- phase4_validate_canonical_graphml_attributes(
    attributes
  )

  phase4_stop_on_failed_validation(
    validation,
    "Canonical GraphML attributes"
  )

  vertex_ids <- as.character(
    igraph::V(graph)$name
  )

  attribute_ids <- as.character(
    attributes$STRING_id
  )

  if (!setequal(vertex_ids, attribute_ids)) {
    stop(
      "Graph vertices and canonical GraphML attribute STRING IDs differ.",
      call. = FALSE
    )
  }

  attribute_index <- match(
    vertex_ids,
    attribute_ids
  )

  for (column_name in names(attributes)) {
    graph <- igraph::set_vertex_attr(
      graph,
      column_name,
      value = attributes[[column_name]][attribute_index]
    )
  }

  graph
}

phase4_build_canonical_pipeline_result <- function(
  output_dir,
  graph,
  biological_evidence,
  analytical_report_tables,
  analytical_report_validation,
  graphml_validation,
  graph_summary,
  mapping_summary,
  files,
  compatibility = NULL,
  provenance = NULL
) {
  evidence_validation <-
    phase4_validate_canonical_biological_evidence(
      biological_evidence
    )

  phase4_stop_on_failed_validation(
    evidence_validation,
    "Canonical biological evidence"
  )

  required_analytical_tables <- c(
    "Final priorities",
    "Module priorities",
    "Candidate evidence"
  )

  missing_analytical_tables <- setdiff(
    required_analytical_tables,
    names(analytical_report_tables)
  )

  if (length(missing_analytical_tables) > 0L) {
    stop(
      paste0(
        "Analytical report is missing canonical table(s): ",
        paste(missing_analytical_tables, collapse = ", "),
        "."
      ),
      call. = FALSE
    )
  }

  result <- list(
    schema_versions = cancerppir_schema_versions(),
    output_dir = output_dir,
    network = list(
      graph = graph,
      node_annotations =
        biological_evidence$node_annotations,
      module_annotations =
        biological_evidence$module_annotations,
      graph_summary = graph_summary
    ),
    biological_evidence = biological_evidence,
    priorities = list(
      proteins = analytical_report_tables[[
        "Final priorities"
      ]],
      modules = analytical_report_tables[[
        "Module priorities"
      ]],
      candidate_evidence = analytical_report_tables[[
        "Candidate evidence"
      ]]
    ),
    reports = list(
      analytical_tables = analytical_report_tables,
      analytical_validation =
        analytical_report_validation,
      graphml_validation = graphml_validation
    ),
    mapping = list(
      summary = mapping_summary
    ),
    files = files,
    compatibility = compatibility,
    provenance = if (is.null(provenance)) {
      list(status = "not_generated")
    } else {
      provenance
    }
  )

  class(result) <- c(
    "cancerppir_result",
    "list"
  )

  result_validation <-
    phase4_validate_canonical_pipeline_result(
      result
    )

  phase4_stop_on_failed_validation(
    result_validation,
    "Canonical pipeline result"
  )

  result
}

phase4_validate_canonical_pipeline_result <- function(
  result
) {
  required_top_level <- c(
    "schema_versions",
    "output_dir",
    "network",
    "biological_evidence",
    "priorities",
    "reports",
    "mapping",
    "files",
    "compatibility",
    "provenance"
  )

  top_level_complete <- is.list(result) &&
    all(required_top_level %in% names(result))

  shadow_absent <- is.list(result) &&
    !"biological_evidence_shadow" %in% names(result)

  canonical_priorities_present <- FALSE
  canonical_network_present <- FALSE
  schema_versions_valid <- FALSE

  if (top_level_complete) {
    canonical_priorities_present <- all(
      c("proteins", "modules", "candidate_evidence") %in%
        names(result$priorities)
    )

    canonical_network_present <- all(
      c("graph", "node_annotations", "module_annotations", "graph_summary") %in%
        names(result$network)
    )

    schema_versions_valid <- identical(
      result$schema_versions,
      cancerppir_schema_versions()
    )
  }

  provenance_present <- top_level_complete &&
    is.list(result$provenance)

  checks <- c(
    canonical_result_top_level_complete = top_level_complete,
    shadow_result_field_absent = shadow_absent,
    canonical_priorities_present = canonical_priorities_present,
    canonical_network_present = canonical_network_present,
    canonical_schema_versions_valid = schema_versions_valid,
    output_provenance_present = provenance_present
  )

  data.frame(
    check_id = names(checks),
    status = ifelse(checks, "PASS", "FAIL"),
    stringsAsFactors = FALSE
  )
}
