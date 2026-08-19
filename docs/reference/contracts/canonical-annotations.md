# Canonical biological annotation contract

Biological-evidence schema version: `2.0.0`
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

Canonical biological interpretation is derived from statistically significant,
non-generic local STRING enrichment. The qualifying term with the lowest FDR
provides the primary interpretation; up to two additional qualifying terms
provide secondary context. A technical/covariate signature overrides automatic
biological priority, and a module without a qualifying term remains unresolved.
Benjamini-Hochberg adjustment is calculated over every term meeting the
query-independent background-size bounds before the minimum support threshold
is applied for reporting.

Supported biological modules receive `moderate` confidence. Compartment,
lineage, state, process, marker, and conflict fields remain in the schema for
compatibility but do not provide independently resolved marker-derived
classifications in the current adapter. The `module_rule_evidence` table is an
auxiliary audit layer and does not determine canonical interpretation or
automatic module or protein priority.

Every `module_rule_evidence` row exposes `curation_status`, `rule_version`,
`rule_schema_version`, `evidence_basis`, `reference_count`, and `references`.
The shipped rulebook currently contains only `legacy_unverified` and
`provisional` rules; none is represented as validated biological evidence.
These statuses remain auxiliary regardless of marker overlap or heuristic
`evidence_score`.

A canonical interpretation is not a cell-fraction estimate, deconvolution
result, proof of tumor-cell origin, or therapeutic recommendation.

## GraphML contract

`Network_for_Cytoscape.graphml` exports an explicit allowlist covering:

- protein identity and expression;
- network topology and deterministic module membership;
- candidate score, ranks, and score components;
- entity class and priority status;
- canonical module interpretation and supporting evidence;
- Cytoscape convenience labels;
- biological-evidence and GraphML schema versions.

Deprecated compatibility fields are excluded. `cytoscape_module_label` equals
`module_primary_interpretation`.

## Public pipeline result

`run_cancerppir()` returns an object of class `cancerppir_result` with separate
schema registry, network, biological evidence, priorities, reports, provenance,
mapping, file inventory, and compatibility sections.

Deprecated readable tables are isolated under `result$compatibility`, marked as
deprecated compatibility objects, and must not drive analytical priorities,
GraphML interpretation, eligibility, or the public evidence object.

## Regression boundary

A schema-label cleanup must not change the STRING node set, STRING edge set,
Louvain membership, candidate scores, expression values, analytical workbook
content, or canonical technical evidence values. Compatibility-sensitive name
and schema changes require the full seven-case release qualification before
publication.
