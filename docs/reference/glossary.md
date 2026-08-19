# Glossary

| Term | Definition |
|---|---|
| PPI subnetwork | The subset of STRING associations reconstructed from proteins mapped from the input table at the selected threshold. |
| Node | A mapped protein retained in the reconstructed network. |
| Edge | A retained STRING association. It is not a patient-specific physical interaction measurement. |
| `logFC` | Base-2 log fold change for tumor specimen relative to the upstream reference condition. Positive values indicate higher expression in tumor. The absolute value contributes to candidate scoring. |
| `pvalue` | Raw differential-expression p-value from the same upstream model and contrast as `logFC`. Adjusted p-values, FDR and q-values are not accepted as substitutes. |
| `neg_log10_pvalue` | Transformed statistical-evidence value used in the candidate score and safe serialization. |
| `degree` | Number of retained edges incident to a node. |
| `betweenness` | Fraction or count-based shortest-path centrality used to identify bridge-like nodes. |
| `stress_centrality` | Number of shortest paths passing through a node; log-transformed for candidate scoring. |
| `harmonic_closeness` | Closeness variant suitable for disconnected graphs. |
| `local_clustering` | Connectivity among a node's neighbours. |
| `candidate_score` | Exploratory within-network composite of three equally weighted evidence domains: topology, absolute logFC, and statistical evidence. |
| Candidate-score component | One of five normalized base inputs. Degree, betweenness, and log-stress are averaged into the topology domain; absolute logFC and statistical evidence define the other two domains. All five base components must be finite for every ranked network node. |
| Louvain module | Deterministically detected community of densely connected nodes. |
| `module_id` | Stable identifier used to refer to a Louvain module within a run. |
| `interpretation_class` | Current canonical module category: biological, technical/covariate, or unresolved. |
| `interpretation_scope` | Current canonical decision scope: database-enrichment-supported, technical/covariate, or unresolved. |
| `compartment` | Compatibility field; the current database-primary adapter does not independently resolve a broad cellular compartment. |
| `lineage` | Compatibility field; the current database-primary adapter does not assign marker-derived lineage identity. |
| `state` | Compatibility field; the current database-primary adapter does not independently assign a cellular state. |
| `process` | Compatibility field; the current database-primary adapter does not independently assign a biological process axis. |
| `primary_interpretation` | Qualifying non-generic STRING enrichment term with the lowest FDR, or a technical/unresolved label. |
| `secondary_themes` | Up to two additional qualifying enrichment terms retained as supplementary context. |
| `confidence` | Compatibility confidence state: moderate for a supported biological module, unresolved otherwise, or not applicable for a technical signature. |
| `priority_eligible` | Module-level Boolean indicating that automatic priority criteria are satisfied. |
| `conflict_detected` | Compatibility field; auxiliary marker-rule disagreement does not determine the current canonical module decision. |
| `positive_marker_genes` | Auxiliary marker-rule field; canonical module annotations intentionally leave it empty. |
| `supportive_marker_genes` | Auxiliary marker-rule field; canonical module annotations intentionally leave it empty. |
| `significant_supporting_terms` | Non-generic terms retained after FDR filtering for canonical interpretation. |
| `best_supporting_fdr` | Lowest FDR among retained supporting terms. |
| `evidence_rationale` | Human-readable trace of the evidence and its limitations. |
| `entity_class` | Classification used to separate canonical proteins from loci, non-coding, mitochondrial, ribosomal, Y-associated, and other special entities. |
| `candidate_eligibility` | Entity-level review status controlling automatic promotion. |
| `priority_status` | Candidate-level status showing whether the protein reached final automatic priority or remains network evidence. |
| Analytical workbook | Six-sheet human-readable report for first-pass interpretation. |
| Technical workbook | Audit report containing mapping, raw metrics, enrichment, canonical evidence, validation, and session information. |
| GraphML | Versioned annotated network for Cytoscape, Gephi, or another GraphML reader. |
| Output manifest | JSON file containing provenance, configuration, schemas, run summary, and output hashes. |
| Checksum | SHA-256 digest used to verify exact file bytes. |
| Schema version | Version of a public structure or interpretation contract; separate from Git commit identity. |
| Canonical output | Current source of truth used for decisions and public interpretation; biological priorities are derived from qualifying STRING enrichment. |
| Compatibility output | Deprecated historical structure retained only for migration or audit. |
| Offline enrichment | Enrichment performed from locally cached STRING v12 annotation resources without online service calls. |
| Generic term | Broad annotation term that is insufficient as primary interpretive evidence by itself. |
| Exploratory priority | Hypothesis-generating rank requiring independent biological and clinical validation. |
