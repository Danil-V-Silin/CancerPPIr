# Output interpretation guide

This guide explains the current CancerPPIr output contract and a defensible
order of interpretation. CancerPPIr produces exploratory network evidence from a
bulk RNA-seq-derived gene table. It does not directly measure protein
interactions, cell fractions, drug response, or clinical benefit.

## Output inventory

| File | Audience | Purpose |
|---|---|---|
| `CancerPPIr_Analytical_Report.xlsx` | biological and translational reviewers | concise priority and context tables |
| `CancerPPIr_Technical_Report.xlsx` | analysts and auditors | complete mapping, metrics, enrichment, canonical evidence, and session details |
| `Network_for_Cytoscape.graphml` | network analysts | canonical node attributes and network topology |
| `STRING_links.txt` | reviewers | browser links for STRING inspection |
| `CancerPPIr_Output_Manifest.json` | analysts and reproducibility reviewers | input identity, versions, configuration, summary, and output hashes |
| `CancerPPIr_Output_Checksums.sha256` | anyone receiving the run | byte-level file-integrity verification |

## Recommended reading order

1. Check network and mapping quality in `Executive summary`.
2. Review biological programs in `Module priorities`.
3. Inspect automatically eligible proteins in `Final priorities`.
4. Use `Candidate evidence` to understand score components and exclusions.
5. Use `Network overview` for graph structure and topological hubs.
6. Read `Methods and limitations` before reporting results.
7. Use the technical workbook, GraphML, manifest, and checksums for audit.

## Analytical workbook

The analytical workbook schema is version `2.0.0` and contains exactly six
sheets.

### `Executive summary`

This is the run-level quality gate. It reports input and mapping counts, mapping
rate, graph size, connected components, largest-component fraction, Louvain
modules, module interpretation classes, final-priority count, and pinned run
configuration.

A low mapping rate, small graph, or highly fragmented network does not
necessarily mean the run failed, but it limits the strength and scope of
interpretation.

### `Final priorities`

This sheet contains up to ten proteins that passed automatic entity and module
eligibility filters. Important fields are:

| Field | Interpretation |
|---|---|
| `priority_rank` | rank inside the automatically eligible subset |
| `network_candidate_rank` | rank inside the complete reconstructed network |
| `candidate_score` | exploratory composite within-network score |
| `biological_context` | canonical module-level interpretation |
| `candidate_eligibility` | entity-level review status |
| `module_confidence` | evidence confidence for the module context |
| topology ranks | degree, betweenness, and stress positions |
| `priority_rationale` | concise evidence-based explanation |
| `priority_warning` | limitation or review flag |

A protein can rank highly in the complete network but be absent from final
priorities because its entity class or module evidence does not support
automatic promotion.

### `Module priorities`

This sheet contains up to five biological modules that are priority eligible.
Technical/covariate or unresolved modules are not inserted merely to fill the
table.

Each row is directly traceable to statistically significant, non-generic
STRING/database enrichment evidence. The primary interpretation is the
qualifying term with the lowest FDR; up to two further qualifying terms provide
secondary context.

| Field | Interpretation |
|---|---|
| `module_priority_rank` | rank within the reported module subset |
| `module_id` | Louvain module identifier |
| `module_size` and `network_fraction` | module scale in the reconstructed network |
| `module_interpretation` | primary qualifying STRING/database term |
| `primary_term_source` | annotation source of the primary term |
| `primary_term_id` | database identifier of the primary term |
| `primary_term_fdr` | adjusted enrichment significance of the primary term |
| `primary_term_supporting_genes` | module proteins supporting the primary term |
| `secondary_terms` | up to two additional qualifying enrichment terms |
| `top_module_proteins` | representative proteins from the module |

The number of module rows may be less than five. That is a result, not a missing
value problem.

### `Candidate evidence`

This is the main protein-level audit table. It contains the top network
candidates plus any additional proteins needed to preserve final priorities.

The score components are reported separately:

- `degree_component`;
- `betweenness_component`;
- `log_stress_component`;
- `abs_logFC_component`;
- `statistical_component`.

`priority_status`, `candidate_eligibility`, `entity_class`, module evidence,
warning, and rationale explain why a protein is or is not automatically promoted.

### `Network overview`

This long-format sheet combines:

- graph-level metrics;
- a deduplicated union of top degree, betweenness, and stress hubs;
- degree distribution.

Use it to characterize topology. Do not treat a topological hub as a validated
drug target without independent evidence.

### `Methods and limitations`

This sheet records the candidate-score definition, offline annotation policy,
eligibility rules, bulk RNA-seq limitations, STRING limitations, and clinical
non-actionability statement. It is part of the result and should accompany any
formal interpretation.

## Technical workbook

The technical workbook schema is version `1.0.0`. It is the audit layer, not the
recommended first view.

### Mapping and input audit

- `Mapping summary`
- `Gene status`
- `Alias corrections`
- `Unmapped genes`
- `HGNC normalization`
- `Genes used table`

These sheets distinguish input rows, mapped input rows, unique mapped proteins,
and final graph nodes. These quantities are not interchangeable.

### Network and enrichment audit

- `Raw node metrics`
- `Raw all modules`
- `Raw major modules`
- `Top module enrichment`
- `Top network enrichment`
- `Top candidate enrichment`
- `Raw module enrichment`
- `Raw network enrichment`
- `Raw candidate enrichment`

Raw enrichment sheets may contain broad, redundant, or non-priority terms. They
are preserved for audit and are not all used in the analytical interpretation.

### Canonical biological evidence

- `Module annotations`
- `Rule evidence`
- `Significant terms`
- `Node annotations`
- `Validation`

The module and node annotation sheets are the canonical biological-evidence
source. `Significant terms` contains filtered statistically significant
support used by the engine. `Validation` must contain no failed checks in
a successful run.

### Runtime audit

`Session info` records the R session and loaded package versions.

## GraphML

The GraphML schema is version `1.0.0`. It contains:

- identifiers and expression values;
- topology metrics and ranks;
- the candidate score and five score components;
- `entity_class`, `candidate_eligibility`, and priority status;
- canonical module compartment, lineage, state, process, interpretation,
  confidence, conflict, warnings, and evidence rationale;
- Cytoscape convenience labels.

Zero or extremely small positive `pvalue` values may be floored only for safe GraphML numeric
serialization. The original statistical evidence remains represented by
`neg_log10_pvalue`, and the GraphML flag records whether flooring occurred.

## Manifest and checksums

The output manifest schema is version `1.0.0`. It records the input basename and
SHA-256, software/runtime metadata, public schema versions, analysis
configuration, the versioned scientific input contract, run summary, and hashes
of the four principal analysis outputs. It intentionally excludes absolute user
paths.

The checksum file schema is version `1.0.0`. It hashes the four principal
outputs and the manifest. It does not hash itself.

See the [reproducibility guide](reproducibility.md) for verification
commands.

## Evidence hierarchy for reporting

Report conclusions in this order:

1. input and mapping quality;
2. graph structure;
3. module evidence and confidence;
4. candidate topology and expression evidence;
5. entity and module eligibility;
6. external biological, pharmacological, and clinical validation.

A defensible protein-level statement links the network rank to its module and
limitations. Avoid statements that convert a network priority into a proven
therapeutic target.
