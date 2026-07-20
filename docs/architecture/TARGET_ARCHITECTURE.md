# CancerPPIr target architecture

## Scope

This document defines the architecture-preserving decomposition of the current monolithic CancerPPIr workflow.

The current source contains 3027 lines and 63 top-level function definitions.

All 63 current functions are assigned exactly once to a target module.

No analytical behavior is intentionally changed during this phase.

## Target source tree

```text
CancerPPIr/
|-- cancerppir.R
|-- R/
|   |-- 00_utils.R
|   |-- 01_input.R
|   |-- 02_string_mapping.R
|   |-- 03_enrichment.R
|   |-- 04_module_labeling.R
|   |-- 05_reporting.R
|   |-- 06_network_analysis.R
|   |-- 07_pipeline.R
|   `-- load_all.R
|-- legacy/
|   `-- cancerppir_legacy.R
|-- scripts/
|-- tests/
`-- docs/
```

## Module responsibilities

| Target file | Responsibility | Current functions | Legacy function lines | Order |
| --- | --- | --- | --- | --- |
| R/00_utils.R | Small dependency-light helpers, validation, numeric utilities, normalization helpers and shared text utilities. | 21 | 151 | 1 |
| R/01_input.R | Input delimiter detection, input-table reading and input-column normalization. | 2 | 75 | 2 |
| R/02_string_mapping.R | HGNC and STRING identifier handling, alias correction, mapping fallbacks and STRING interaction retrieval. | 7 | 166 | 3 |
| R/03_enrichment.R | Local STRING enrichment, optional online enrichment, enrichment filtering, ranking and term collapsing. | 15 | 491 | 4 |
| R/04_module_labeling.R | Marker-based labels, rulebook-based module interpretation, confidence scoring and supporting biological themes. | 14 | 317 | 5 |
| R/05_reporting.R | Output-table normalization, worksheet preparation and Excel workbook generation. | 4 | 83 | 6 |
| R/06_network_analysis.R | Graph construction, connected components, centrality metrics, candidate scoring, Louvain modules and graph-level summaries. | 0 | 0 | 7 |
| R/07_pipeline.R | End-to-end CancerPPIr orchestration with explicit inputs, configuration and returned analysis objects. | 0 | 0 | 8 |
| R/load_all.R | Explicit source loader defining the stable module-loading order for the script-based workflow. | 0 | 0 | 9 |

## Workflow ownership

| Workflow stage | Current source anchor | Target owner | Planned entry point |
| --- | --- | --- | --- |
| CLI and configuration | commandArgs at line 77 | cancerppir.R and R/07_pipeline.R | parse CLI arguments and call run_cancerppir() |
| Input-table ingestion | Reading input table at line 855 | R/01_input.R and R/07_pipeline.R | read_gene_table() |
| HGNC symbol normalization | Checking gene symbols at line 858 | R/02_string_mapping.R | normalize and audit gene symbols |
| STRING initialization and mapping | STRING initialization at line 881; mapping at line 905 | R/02_string_mapping.R and R/07_pipeline.R | prepare_string_mapping() |
| STRING subnetwork construction | Building STRING subnetwork at line 1042 | R/06_network_analysis.R | build_string_network() |
| Network metrics and candidate scoring | Calculating network metrics at line 1064 | R/06_network_analysis.R | calculate_network_metrics() |
| Functional enrichment | Functional enrichment at line 1365 | R/03_enrichment.R | run_enrichment_stage() |
| Module interpretation | Module labeling helpers and module-dependent top-level expressions | R/04_module_labeling.R | build_module_annotations() |
| Report assembly and export | Writing consolidated output files at line 1587 | R/05_reporting.R and R/07_pipeline.R | assemble_and_write_reports() |

## Planned orchestration functions

| Planned function | Target file | Purpose |
| --- | --- | --- |
| load_cancerppir_modules | R/load_all.R | Source project modules in an explicit deterministic order. |
| prepare_string_mapping | R/02_string_mapping.R | Perform HGNC normalization, STRING mapping and alias correction. |
| build_string_network | R/06_network_analysis.R | Construct and normalize the patient-specific STRING graph. |
| calculate_network_metrics | R/06_network_analysis.R | Calculate components, centralities and Louvain communities. |
| build_candidate_tables | R/06_network_analysis.R | Calculate candidate scores and candidate-ranking tables. |
| run_enrichment_stage | R/03_enrichment.R | Execute local and optional online functional enrichment. |
| build_module_annotations | R/04_module_labeling.R | Assign putative module labels, confidence and supporting themes. |
| assemble_and_write_reports | R/05_reporting.R | Create analytical, technical, GraphML and STRING-link outputs. |
| run_cancerppir | R/07_pipeline.R | Coordinate the complete patient-specific CancerPPIr workflow. |

## Safe extraction sequence

| Step | Checkpoint | Planned change | Regression gate |
| --- | --- | --- | --- |
| 1 | Architecture documentation | Commit inventory and target architecture documents without changing cancerppir.R. | No analytical execution required; source checksum must remain unchanged. |
| 2 | Module skeleton and loader | Create the R directory, empty target files and an explicit R/load_all.R source order. | Parse all R files; legacy workflow remains unchanged. |
| 3 | Shared utilities | Move only dependency-light utility function definitions into R/00_utils.R. | R01 pilot followed by strict comparison. |
| 4 | Input handling | Move delimiter detection and read_gene_table() into R/01_input.R. | R01 pilot followed by strict comparison. |
| 5 | STRING mapping | Move HGNC/STRING mapping helpers into R/02_string_mapping.R. | R01 pilot, then all seven cases. |
| 6 | Enrichment helpers | Move enrichment cache, local enrichment, optional online enrichment and term-ranking helpers into R/03_enrichment.R. | R01 pilot, then all seven cases. |
| 7 | Module-labeling helpers | Move marker and rulebook interpretation helpers into R/04_module_labeling.R. | R01 pilot plus structural module-output comparison. |
| 8 | Reporting helpers | Move workbook and output-table helpers into R/05_reporting.R. | All seven cases and workbook-schema comparison. |
| 9 | Network and pipeline orchestration | Wrap graph construction, metrics, scoring and the remaining top-level workflow in explicit functions. | All seven cases and complete Phase 0 strict regression core. |
| 10 | Slim CLI and final regression | Reduce cancerppir.R to an entry-point adapter and run the full seven-case regression comparison. | All seven cases, clean Git state and architecture-complete tag. |

## Architectural rules

1. `legacy/cancerppir_legacy.R` remains immutable and continues to represent the preserved pre-refactor workflow.
2. Function bodies are moved without semantic rewriting during their first extraction.
3. The source order is explicit in `R/load_all.R`; alphabetical filesystem ordering is not used implicitly.
4. `cancerppir.R` remains executable through the existing CLI contract throughout the refactor.
5. Each extraction checkpoint must pass the R01 pilot before a full seven-case run.
6. Strict deterministic outputs are compared exactly; Louvain-dependent outputs are compared structurally.
7. Input, result and STRING-cache directories remain outside the repository.

## Explicitly deferred behavior changes

- No Louvain random seed is introduced during architecture-only extraction.
- Candidate-score formulas and ranking rules are not changed.
- Functional-label rules and confidence thresholds are not changed.
- Input-column interpretation is not changed.
- STRING score thresholds and enrichment backgrounds are not changed.
- GraphML numerical sanitization is deferred to a separately documented behavior-correction phase.
- Output filenames and workbook sheet names are preserved.

## Generated planning artifacts

- `target_function_module_map.csv`
- `target_module_manifest.csv`
- `target_workflow_plan.csv`
- `architecture_extraction_sequence.csv`
- `planned_orchestration_functions.csv`
