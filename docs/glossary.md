# Glossary

This glossary defines the main terms used in CancerPPIr reports and documentation.

| Term | Meaning |
|---|---|
| `Analytical_Report.xlsx` | Main human-readable workbook. It contains summary statistics, candidate rankings, major module priorities and network-level summaries. |
| `Technical_Report.xlsx` | Audit workbook. It contains mapping results, raw node metrics, raw enrichment tables and R session information. |
| `STRING protein identifier` | Protein identifier used by STRING, typically in the form `9606.ENSP...` for human proteins. |
| PPI subnetwork | The subset of STRING protein associations reconstructed from proteins mapped from the input gene table. |
| Node | A protein in the reconstructed PPI network. |
| Edge | A STRING association retained after applying the selected confidence threshold. |
| `logFC` | Log-fold change supplied in the input table. CancerPPIr uses its absolute value in the candidate score. |
| `pvalue` | P-value, adjusted p-value or FDR supplied in the input table. CancerPPIr uses `-log10(pvalue)` in the candidate score. |
| `degree` | Number of edges connected to a protein. High degree indicates hub-like topology. |
| `betweenness` | Centrality metric based on the fraction of shortest paths passing through a node. High betweenness indicates bridge-like topology. |
| `stress_centrality` | Number of shortest paths passing through a node. CancerPPIr uses a log-transformed version for candidate scoring. |
| `closeness` | Centrality metric reflecting how close a node is to other nodes by shortest paths. |
| `harmonic_closeness` | Variant of closeness that is more stable in disconnected graphs. |
| `local_clustering` | Tendency of a node's neighbours to connect with each other. |
| `candidate_score` | Exploratory composite score based on normalized degree, betweenness, log-transformed stress centrality, absolute logFC and `-log10(pvalue)`. |
| Top candidate | A protein ranked highly by `candidate_score` or by an individual topology metric. |
| Louvain module | Community of densely connected proteins detected by Louvain modularity optimization. |
| Major module | A larger Louvain module selected for module-level interpretation and prioritization. |
| Functional enrichment | Statistical test for annotation terms that occur more often in a gene or protein set than expected from the background. |
| FDR | False discovery rate after multiple-testing correction. Lower FDR indicates stronger enrichment evidence. |
| Local STRING enrichment terms | Downloaded STRING v12 annotation table mapping STRING proteins to functional terms used for offline enrichment. |
| Marker-gene overlap | Overlap between genes in a module and curated marker sets defined in the workflow. |
| `top_interpretable_terms` | Selected enrichment terms used to support a readable biological interpretation of a module. |
| Generic enrichment term | Broad database term that is not specific enough to support a module label by itself, for example generic signalling or cell-communication terms. |
| `label_rulebook` | Explicit set of rules used to assign module labels from marker evidence and local STRING enrichment terms. |
| `specific_label_candidate` | Most specific rulebook label suggested by the evidence before fallback checks. |
| `fallback_label` | Broader label used when evidence supports a biological direction but lacks the specificity needed for the precise label. |
| `final_functional_label` | Conservative final module label after rulebook scoring and fallback checks. |
| `putative_biological_program` | Human-readable biological interpretation of the module. It is computationally inferred, not experimentally proven. |
| `label_source` | Evidence source supporting a label: marker overlap, specific STRING enrichment, both, or neither. |
| `label_evidence_score` | Rule-based interpretability score for module labeling. It is not a clinical score and not a candidate efficacy score. |
| `label_confidence` | Qualitative confidence category derived from label evidence, marker support and enrichment support. |
| `label_warning` | Audit flag indicating weak evidence, fallback assignment, marker-only support, STRING-only support or no reliable label evidence. |
| `supporting_biological_themes` | Additional biological themes detected from markers and enrichment terms. They support interpretation but do not automatically define the final label. |
| GraphML | Graph file format exported for visualization in Cytoscape, Gephi or other network tools. |
| `STRING_links.txt` | Text file containing current and STRING v12-pinned links for inspecting the reconstructed network in STRING. |
