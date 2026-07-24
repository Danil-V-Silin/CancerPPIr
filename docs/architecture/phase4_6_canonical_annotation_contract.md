# Phase 4.6 canonical biological annotation contract

Contract version: `4.6.0`

## Purpose

Phase 4.6 makes the tested Phase 4 biological evidence engine the single
canonical source of biological interpretation in the CancerPPIr production
pipeline. The analytical workbook already uses this evidence model. This
contract extends the same source of truth to GraphML and the public R result
object while isolating the former labeling system behind an explicit
compatibility boundary.

This checkpoint does not change network construction, STRING mapping,
Louvain community detection, candidate-score calculation, analytical workbook
membership or technical evidence tables.

## Canonical evidence source

The canonical evidence object is returned by
`phase4_bind_pipeline_evidence()` and is exposed as
`result$biological_evidence`.

It contains exactly these public components:

1. `module_annotations`
2. `module_rule_evidence`
3. `significant_module_terms`
4. `node_annotations`
5. `validation`

A successful pipeline run is not allowed to continue when any row of
`biological_evidence$validation` has status `FAIL`.

## Canonical module annotation fields

The following module fields define the public biological interpretation:

- `interpretation_class`
- `interpretation_scope`
- `compartment`
- `lineage`
- `state`
- `process`
- `primary_interpretation`
- `secondary_themes`
- `confidence`
- `priority_eligible`
- `positive_marker_genes`
- `supportive_marker_genes`
- `term_supporting_genes`
- `significant_supporting_terms`
- `best_supporting_fdr`
- `conflict_detected`
- `warning`
- `evidence_rationale`

The canonical node table exposes these values with the `module_` prefix.

## Interpretation hierarchy

CancerPPIr reports biological context through separate axes:

1. compartment;
2. lineage;
3. state;
4. process.

`module_primary_interpretation` is a conservative synthesis of supported
axes. It is not a cell-fraction estimate, deconvolution result, proof of tumor
cell origin or therapeutic recommendation.

## GraphML contract

`Network_for_Cytoscape.graphml` uses an explicit allowlist of canonical
attributes. It does not export legacy labeling fields.

The GraphML node contract includes:

### Identity and expression

- `STRING_id`
- `gene`
- `pvalue`
- `pvalue_was_floored_for_graphml`
- `logFC`
- `abs_logFC`
- `neg_log10_pvalue`

### Network topology

- `degree`
- `betweenness`
- `stress_centrality`
- `closeness`
- `harmonic_closeness`
- `local_clustering`
- `component`
- `in_largest_component`
- `community_louvain`
- `louvain_module_id`
- `candidate_score`
- topology ranks and five candidate-score components

### Entity and priority status

- `entity_class`
- `candidate_eligibility`
- `candidate_priority_status`

### Canonical biological context

- `module_interpretation_class`
- `module_interpretation_scope`
- `module_compartment`
- `module_lineage`
- `module_state`
- `module_process`
- `module_primary_interpretation`
- `module_secondary_themes`
- `module_confidence`
- `module_priority_eligible`
- `module_conflict_detected`
- `module_warning`
- `module_evidence_rationale`
- marker and significant-term evidence fields

### Cytoscape convenience fields

- `cytoscape_label`
- `cytoscape_module_label`
- `cytoscape_priority_class`

`cytoscape_module_label` must equal `module_primary_interpretation`.

## Schema versions

Phase 4.6 defines:

- biological evidence schema: `1.0.0`;
- GraphML schema: `4.6.0`;
- pipeline result schema: `4.6.0`;
- analytical workbook schema: inherited from the Phase 4.5 contract.

GraphML stores the biological-evidence and GraphML schema versions as vertex
attributes. Full output-manifest versioning is deferred to Phase 4.7.

## Public pipeline result

`run_cancerppir()` returns an object of class `cancerppir_result` with the
following top-level structure:

```r
list(
  schema_versions = list(...),
  output_dir = ...,
  network = list(
    graph = ...,
    node_annotations = ...,
    module_annotations = ...,
    graph_summary = ...
  ),
  biological_evidence = list(...),
  priorities = list(
    proteins = ...,
    modules = ...,
    candidate_evidence = ...
  ),
  reports = list(
    analytical_tables = ...,
    analytical_validation = ...,
    graphml_validation = ...
  ),
  mapping = list(summary = ...),
  files = ...,
  compatibility = list(...)
)
```

The previous `biological_evidence_shadow` public field is removed.

## Compatibility boundary

Legacy readable tables are retained temporarily only under
`result$compatibility`:

- `legacy_module_summary`
- `legacy_candidate_evidence_matrix`
- `legacy_priority_directions`
- `legacy_final_priorities`

They are marked `deprecated_compatibility_only`. They may support migration or
historical audit but must not drive:

- analytical priorities;
- GraphML biological attributes;
- candidate eligibility;
- canonical module interpretation;
- the public evidence object.

## Legacy-field migration

| Legacy field | Canonical replacement |
|---|---|
| `module_direction` | `module_primary_interpretation` |
| `clean_module_label` | `module_primary_interpretation` |
| `marker_clean_label` | hierarchical module fields |
| `marker_based_direction` | lineage/state/process evidence fields |
| `marker_evidence_genes` | positive and supportive marker fields |
| `enrichment_evidence_terms` | significant supporting terms |
| `final_functional_label` | `module_primary_interpretation` |
| `putative_biological_program` | `module_primary_interpretation` |
| `specific_label_candidate` | `module_primary_interpretation` plus scope |
| `fallback_label` | `module_interpretation_scope` |
| `label_assignment_mode` | `module_interpretation_scope` |
| `label_source` | explicit marker and term evidence fields |
| `label_evidence_score` | confidence plus explicit evidence components |
| `label_confidence` | `module_confidence` |
| `label_warning` | `module_warning` |
| `biological_direction_rationale` | `module_evidence_rationale` |

## Regression policy

Phase 4.6 must not change:

- the STRING node set;
- the STRING edge set;
- Louvain module membership;
- candidate scores;
- expression values;
- the six analytical workbook tables;
- canonical technical evidence tables.

Expected changes are limited to:

- GraphML attribute names and biological content;
- pipeline return-object structure;
- removal of shadow terminology;
- explicit compatibility isolation;
- schema-version fields;
- tests and documentation.

## Efficient validation policy

Phase 4.6 uses one unit-test run and one real A01 production run. When the
Phase 4.5 A01 baseline is available, the checkpoint compares topology,
Louvain membership, candidate scores and all analytical workbook tables.

The seven clinical cases are not recalculated during this checkpoint. They are
reserved for one final Phase 4 release regression after provenance,
documentation and cleanup work are complete.

## Definition of done

Phase 4.6 is complete when:

1. unit tests pass;
2. one real production case passes;
3. no shadow field or shadow log message remains in the public pipeline;
4. the public result validates against schema `4.6.0`;
5. GraphML contains canonical fields and no legacy label fields;
6. technical canonical evidence sheets remain valid;
7. A01 topology, Louvain membership and candidate scores match Phase 4.5;
8. A01 analytical workbook tables match Phase 4.5;
9. the working tree contains only reviewed production, test and documentation changes.
