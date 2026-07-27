# Canonical biological annotation contract

Biological-evidence schema version: `1.0.0`
GraphML schema version: `1.0.0`
Pipeline-result schema version: `1.0.0`

## Purpose

The canonical biological-evidence object is the single source of biological
interpretation for the analytical workbook, GraphML, and public R result. It
does not change STRING mapping, network construction, Louvain detection, or
candidate-score calculation.

## Canonical evidence object

`cancerppir_bind_pipeline_evidence()` returns the object exposed as
`result$biological_evidence` with these public components:

1. `module_annotations`
2. `module_rule_evidence`
3. `significant_module_terms`
4. `node_annotations`
5. `validation`

A production run stops when any validation row has status `FAIL`.

## Module interpretation

Canonical module fields include interpretation class and scope, compartment,
lineage, state, process, primary interpretation, secondary themes, confidence,
priority eligibility, marker and term support, best supporting FDR, conflict
status, warning, and evidence rationale.

The primary interpretation is a conservative synthesis of supported evidence.
It is not a cell-fraction estimate, deconvolution result, proof of tumor-cell
origin, or therapeutic recommendation.

## GraphML contract

`Network_for_Cytoscape.graphml` exports an explicit allowlist covering:

- protein identity and expression;
- network topology and deterministic module membership;
- candidate score, ranks, and score components;
- entity class and priority status;
- canonical module interpretation and supporting evidence;
- Cytoscape convenience labels;
- biological-evidence and GraphML schema versions.

Legacy labeling fields are excluded. `cytoscape_module_label` equals
`module_primary_interpretation`.

## Public pipeline result

`run_cancerppir()` returns an object of class `cancerppir_result` with separate
schema registry, network, biological evidence, priorities, reports, provenance,
mapping, file inventory, and compatibility sections.

Legacy readable tables are isolated under `result$compatibility`, marked as
deprecated compatibility objects, and must not drive analytical priorities,
GraphML interpretation, eligibility, or the public evidence object.

## Regression boundary

A schema-label cleanup must not change the STRING node set, STRING edge set,
Louvain membership, candidate scores, expression values, analytical workbook
content, or canonical technical evidence values. Compatibility-sensitive name
and schema changes require the full seven-case release checkpoint before
publication.
