# Glossary

| Term | Definition |
|---|---|
| PPI subnetwork | The subset of STRING associations reconstructed from proteins mapped from the input table at the selected threshold. |
| Node | A mapped protein retained in the reconstructed network. |
| Edge | A retained STRING association. It is not a patient-specific physical interaction measurement. |
| `logFC` | User-supplied log-fold change. The absolute value contributes to candidate scoring. |
| `pvalue` | User-supplied p-value, adjusted p-value, or FDR. CancerPPIr does not infer which statistical definition was supplied. |
| `neg_log10_pvalue` | Transformed statistical-evidence value used in the candidate score and safe serialization. |
| `degree` | Number of retained edges incident to a node. |
| `betweenness` | Fraction or count-based shortest-path centrality used to identify bridge-like nodes. |
| `stress_centrality` | Number of shortest paths passing through a node; log-transformed for candidate scoring. |
| `harmonic_closeness` | Closeness variant suitable for disconnected graphs. |
| `local_clustering` | Connectivity among a node's neighbours. |
| `candidate_score` | Exploratory within-network composite of normalized degree, betweenness, log-stress, absolute logFC, and statistical evidence. |
| Candidate-score component | One of the five normalized inputs reported separately for audit. |
| Louvain module | Deterministically detected community of densely connected nodes. |
| `module_id` | Stable identifier used to refer to a Louvain module within a run. |
| `interpretation_class` | Module category: biological, mixed biological, technical/covariate, or unresolved. |
| `interpretation_scope` | Strongest evidence resolution across lineage, state, and process axes. |
| `compartment` | Broad context supported by module evidence. It is not a cell-fraction estimate. |
| `lineage` | Lineage-associated evidence supported by markers and significant terms. |
| `state` | Supported cellular or biological state. |
| `process` | Supported biological process. |
| `primary_interpretation` | Conservative synthesis of supported module evidence. |
| `secondary_themes` | Additional supported themes that do not replace the primary interpretation. |
| `confidence` | Qualitative evidence confidence used with conflict and warning fields. |
| `priority_eligible` | Module-level Boolean indicating that automatic priority criteria are satisfied. |
| `conflict_detected` | Evidence disagreement that prevents or constrains automatic interpretation. |
| `positive_marker_genes` | Marker genes providing direct positive support for a selected rule. |
| `supportive_marker_genes` | Genes that strengthen an interpretation but do not independently establish it. |
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
| Canonical output | Current source of truth used for decisions and public interpretation. |
| Compatibility output | Deprecated historical structure retained only for migration or audit. |
| Offline enrichment | Enrichment performed from locally cached STRING v12 annotation resources without online service calls. |
| Generic term | Broad annotation term that is insufficient as primary interpretive evidence by itself. |
| Exploratory priority | Hypothesis-generating rank requiring independent biological and clinical validation. |
