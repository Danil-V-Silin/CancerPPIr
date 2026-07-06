# Output interpretation guide

This document explains how to read CancerPPIr output files and how to report the main results. It is intended for users who need to move from the exported tables to defensible biological interpretation.

CancerPPIr performs network-based prioritization from bulk RNA-seq-derived gene tables. Its outputs should be read as exploratory evidence for protein and module prioritization, not as direct evidence of treatment response or clinical actionability.

## Output files

CancerPPIr writes four main files for each input dataset.

| File | Use |
|---|---|
| `CancerPPIr_Analytical_Report.xlsx` | Main report for interpretation. Contains summary statistics, candidate rankings, major module priorities and network summaries. |
| `CancerPPIr_Technical_Report.xlsx` | Audit report. Contains mapping results, raw node metrics, raw enrichment tables and R session information. |
| `Network_for_Cytoscape.graphml` | Annotated network for Cytoscape, Gephi or other graph visualization tools. |
| `STRING_links.txt` | Current and STRING v12-pinned links for inspecting the reconstructed network in STRING. |

## Recommended reading order

Start with the analytical workbook:

1. `Executive summary`
2. `Final priorities`
3. `Major module priorities`
4. `Candidate rationale`
5. `Graph summary`

Use the technical workbook when checking mapping, raw enrichment results, node-level metrics or reproducibility details.

## Analytical report

### `Executive summary`

Use this sheet to check whether the run is suitable for interpretation. Review the input size, number of mapped genes, number of final graph nodes, number of edges, connected components, largest component size, number of Louvain modules and STRING score threshold.

A low mapping rate, very small network or highly fragmented graph should be reported as a limitation of that run.

### `Final priorities`

This sheet gives a compact summary of the highest-priority proteins and their module context. It is useful for first-pass review, but it should not be used alone for biological conclusions.

Use it to identify:

- top-ranked proteins by composite candidate score;
- the module or biological program in which each candidate appears;
- the main evidence supporting prioritization;
- warnings or low-confidence annotations.

### `Major module priorities`

This sheet summarizes the major Louvain modules selected for module-level interpretation. It is the best starting point for understanding the dominant biological signals in the reconstructed network.

Key fields include:

| Field | How to read it |
|---|---|
| `community_louvain` | Louvain community identifier. |
| `module_size` | Number of proteins in the module. |
| `final_functional_label` | Conservative module label assigned by the rulebook. |
| `label_source` | Evidence layer supporting the label: marker overlap, local STRING enrichment, both or neither. |
| `label_evidence_score` | Rule-based score for label support. It is not a clinical score. |
| `label_confidence` | Qualitative confidence level for the module label. |
| `label_warning` | Audit flag for weak, incomplete or missing label evidence. |
| `top_interpretable_terms` | Selected local STRING enrichment terms used for interpretation. |
| `supporting_biological_themes` | Secondary themes detected in the module. These are not additional final labels. |

A strong module-level interpretation requires concordant marker evidence and specific enrichment terms, preferably with `label_warning = no_warning`.

### `Candidate rationale`

This is the main candidate-level evidence table. It should be used when writing or reviewing a conclusion about a specific protein.

Interpret candidates using several evidence layers together:

| Evidence layer | Relevant fields |
|---|---|
| Network topology | `degree`, `betweenness`, `stress_centrality`, `closeness`, `local_clustering` |
| Expression-level evidence | `logFC`, `abs_logFC`, `pvalue`, `neg_log10_pvalue` |
| Composite prioritization | `candidate_score`, `candidate_rank`, `priority_class` |
| Module context | `community_louvain`, `final_functional_label`, `putative_biological_program` |
| Annotation support | `label_source`, `label_evidence_score`, `label_confidence`, `label_warning`, `top_interpretable_terms` |

A high `candidate_score` means that the protein is prominent in the reconstructed network and expression profile. It does not establish druggability, dependency or treatment sensitivity.

### `Top candidates`, `Top degree`, `Top betweenness`, `Top stress`

These sheets are short ranked views of the candidate table. They are useful for quick inspection and for identifying proteins with different topological roles:

- high `degree`: hub-like proteins;
- high `betweenness`: bridge-like proteins;
- high `stress_centrality`: proteins traversed by many shortest paths.

Use these sheets for screening. Use `Candidate rationale` for final reporting.

### `All modules`

This sheet lists all Louvain modules, including smaller or weakly annotated communities. It is useful for checking whether relevant proteins belong to small modules that were not included among major module priorities.

### `Graph summary`

This sheet reports network-level properties. Use it to describe the size and structure of the reconstructed PPI subnetwork and to identify runs where the graph is too small or fragmented for strong interpretation.

### `Degree distribution`

This sheet gives a compact view of node-degree distribution. It is mainly descriptive and can be used to check whether the network contains hub-like structure.

## Technical report

The technical workbook is not intended as the main interpretation layer. It supports audit and reproducibility.

| Sheet | Use |
|---|---|
| `Mapping summary` | Summary of gene-to-STRING mapping. |
| `Gene status` | Gene-level mapping and filtering status. |
| `Alias corrections` | Symbols corrected through STRING alias matching. |
| `Unmapped genes` | Input genes not mapped to STRING identifiers. |
| `HGNC normalization` | Gene-symbol normalization performed by HGNChelper. |
| `Genes used table` | Final mapped genes/proteins used for network construction. |
| `Raw node metrics` | Full node-level metric table. |
| `Raw all modules` | All Louvain modules before analytical filtering. |
| `Raw major modules` | Major modules selected for interpretation. |
| `Top module enrichment` | Compact enrichment terms for each module. |
| `Top network enrichment` | Compact enrichment terms for the full reconstructed network. |
| `Top candidate enrichment` | Compact enrichment terms for top-ranked candidate proteins. |
| `Raw module enrichment` | Unfiltered module-level enrichment results. |
| `Raw network enrichment` | Unfiltered network-level enrichment results. |
| `Raw candidate enrichment` | Unfiltered candidate-level enrichment results. |
| `Session info` | R session information for reproducibility. |

## Enrichment tables

The enrichment tables are audit layers. They should not be read as independent validation of clinical relevance.

`Top module enrichment` is the most useful enrichment table for interpretation. It shows which annotation terms support the module labels. These results are already condensed in the analytical workbook through `top_interpretable_terms`, `label_source`, `label_evidence_score` and `label_confidence`.

`Top network enrichment` summarizes the reconstructed network as a whole. It is useful for describing the global biological composition of the network, but it does not explain individual candidates.

`Top candidate enrichment` summarizes the top-ranked candidate set. It can show whether top candidates are concentrated in a shared biological program, but it should not be interpreted as evidence that the candidates are therapeutic targets.

Raw enrichment sheets are kept for audit. They include broad and redundant database terms that are not used as primary evidence for module labels.

## Minimum evidence for reporting a candidate

When reporting a candidate protein, include the following information:

1. Its rank or `candidate_score`;
2. The main topology metric supporting prioritization;
3. The expression-level evidence supplied in the input table;
4. The Louvain module and final module label;
5. The label confidence and warning status;
6. The most relevant interpretable enrichment terms or marker support.

A concise reporting sentence should link the candidate to its evidence:

> `PTPRC` was prioritized as a high-ranking network candidate because it had high network centrality, strong candidate-score support and belonged to a major immune/myeloid module supported by marker overlap and local STRING enrichment.

Avoid unsupported wording such as:

> `PTPRC` is a validated therapeutic target for this patient.

## Minimum evidence for reporting a module

When reporting a module, include:

1. Louvain module identifier;
2. Module size;
3. Final functional label;
4. Label source;
5. Label confidence;
6. Warning status;
7. Representative genes or candidates;
8. Top interpretable enrichment terms.

A conservative formulation is:

> The module was annotated as a chemokine/cytokine signalling program based on chemokine/cytokine marker overlap and local STRING enrichment for chemokine- and cytokine-response terms.

## Practical interpretation rule

Interpret the results in this order: network quality first, module context second, candidate-level evidence third. Do not interpret a high-ranking candidate outside its module context, and do not treat a module label as strong if it has low confidence or an unresolved warning.
