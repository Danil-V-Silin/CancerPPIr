# CancerPPIr Phase 4 Specification
## Output quality, biological interpretation, and evidence transparency

**Status:** Proposed implementation contract  
**Target branch:** `refactor/phase-4-output-quality`  
**Scope:** Biological interpretation, reporting architecture, output integrity, GraphML metadata, and STRING-link output  
**Out of scope:** Estimation of cell-type proportions from bulk RNA-seq unless a full expression matrix and a validated deconvolution reference are supplied

---

## 1. Purpose

Phase 4 converts CancerPPIr outputs from a technically complete exploratory export into a concise, auditable, biologically defensible report for researchers.

The implementation must satisfy four principles:

1. **Every biological label must be traceable to exact genes and exact enrichment terms.**
2. **The software must not claim more resolution than the input data support.**
3. **Analytical and technical outputs must have distinct purposes and minimal duplication.**
4. **Every output file must be machine-readable, internally valid, and reproducible.**

---

## 2. Methodological boundary

CancerPPIr currently receives a differential-expression table containing, at minimum:

- gene identifier;
- log fold change;
- p-value.

It does not receive:

- a complete sample-by-gene bulk expression matrix;
- a single-cell or single-nucleus reference matrix;
- matched bulk and single-cell benchmark samples;
- ground-truth cell fractions.

Therefore, the current workflow **cannot estimate cell-type fractions** and must not describe its module labels as transcriptomic deconvolution.

Permitted language:

- putative cell-context-associated program;
- marker-supported lineage context;
- module enriched for genes associated with a cell lineage or state;
- cell-type-associated transcriptional evidence;
- mixed lineage/state evidence;
- unresolved biological program.

Prohibited language in the current workflow:

- estimated cell fraction;
- percentage of macrophages/T cells/etc.;
- deconvolved cell composition;
- module represents a pure cell population;
- gene expression originates exclusively from a stated cell type;
- therapeutic target confirmed by the analysis.

A future optional deconvolution module may be designed separately. It must require a full expression matrix and an appropriate reference/benchmark design.

---

## 3. Lessons adopted from cancer transcriptomic deconvolution literature

The Phase 4 interpretation model adopts the following general principles:

1. **Match the inference to the data type and study question.**
2. **Separate cell identity from cell state and biological process.**
3. **Use tissue-appropriate and platform-aware references whenever cell composition is estimated.**
4. **Treat tumour-cell plasticity and mixed states as expected, not exceptional.**
5. **Do not force a single label when evidence is conflicting or incomplete.**
6. **Benchmark methods using realistic tumour data and independent ground truth.**
7. **Report uncertainty, missing references, and technological mismatch explicitly.**
8. **Prefer exact evidence tables over opaque narrative labels.**

DeMixSC is an instructive example of this discipline. It uses matched bulk and single-cell/single-nucleus benchmark data, identifies genes affected by inter-platform discrepancy, aligns data sets, and estimates proportions using weighted non-negative least squares. CancerPPIr does not currently have the required inputs for this type of inference; Phase 4 therefore borrows the transparency and benchmarking principles, not the cell-fraction output claim.

---

## 4. Interpretation ontology

Module annotation must be hierarchical.

### Level 0 — Technical or covariate signature

Examples:

- Y-chromosome-associated;
- mitochondrial;
- ribosomal/translation-dominant;
- immunoglobulin-locus-dominant;
- T-cell-receptor-locus-dominant;
- haemoglobin/erythroid contamination;
- generic cell-cycle;
- low-information or singleton module.

These modules are reported but are not automatically promoted as biological priorities.

### Level 1 — Broad compartment

Examples:

- immune;
- stromal;
- endothelial/vascular;
- epithelial;
- neural/neuroendocrine;
- proliferative;
- extracellular matrix.

### Level 2 — Lineage context

Examples:

- T-cell-associated;
- B-cell-associated;
- plasma-cell-associated;
- myeloid-associated;
- macrophage-associated;
- dendritic-cell-associated;
- neutrophil-associated;
- endothelial-associated;
- fibroblast-associated.

### Level 3 — Cell state or functional program

Examples:

- cytotoxic effector;
- interferon-responsive;
- antigen presentation;
- complement-associated;
- phagolysosomal;
- immunoglobulin secretion;
- B-cell receptor signalling;
- extracellular-matrix remodelling;
- mitotic/proliferative;
- angiogenic.

### Level 4 — Specific mechanistic interpretation

A Level 4 label is permitted only when supported by:

- multiple specific marker genes;
- statistically significant enrichment;
- sufficient module size;
- low conflict;
- gene-level coherence;
- no technical-signature override.

The software must select the highest level supported by the evidence. It must never force a more specific label merely because a keyword is present.

---

## 5. Evidence model

Each module receives independent evidence dimensions.

### 5.1. Identity-marker evidence

For every marker set:

- marker-set identifier;
- biological label;
- marker genes present;
- marker genes absent;
- marker overlap count;
- weighted marker score;
- module coverage;
- marker specificity;
- evidence source;
- source version;
- evidence date.

Markers must be divided into:

- positive identity markers;
- supportive markers;
- exclusion/anti-markers;
- state markers;
- technical/covariate markers.

### 5.2. Enrichment evidence

Only terms satisfying the user-facing significance threshold may support a final label.

Required fields:

- database/source;
- term identifier;
- term description;
- observed gene count;
- background gene count where available;
- FDR;
- supporting genes;
- term specificity class;
- generic-term flag;
- significance flag;
- interpretation role: primary / secondary / contextual / excluded.

A specific but non-significant term may remain in the technical report but must not support the final user-facing label.

### 5.3. Topological evidence

Required fields:

- module size;
- number of edges;
- module density;
- mean and median degree;
- representative hub genes;
- bridge genes;
- proportion in largest connected component;
- singleton/low-information status.

Topology supports structural importance; it does not prove biological activity or therapeutic efficacy.

### 5.4. Expression evidence

Required fields:

- number and proportion of positive logFC genes;
- number and proportion of negative logFC genes;
- median logFC;
- interquartile range;
- direction status;
- input-direction warning.

When the supplied input contains only one expression direction, the report must state that the opposite direction cannot be evaluated.

### 5.5. Conflict evidence

Examples:

- two strong but incompatible lineage signatures;
- lineage label supported only by generic terms;
- marker evidence contradicts enrichment;
- technical signature dominates a module;
- module contains too few informative genes;
- candidate is a special locus rather than a canonical protein;
- module label derives from one high-degree gene only.

Conflict evidence reduces confidence and may force a broader or mixed label.

---

## 6. Proposed module confidence model

The final confidence must be computed from explicit components, not assigned only by ad hoc rules.

Suggested normalized components:

- `identity_marker_support`
- `state_marker_support`
- `significant_term_support`
- `term_specificity`
- `module_gene_coverage`
- `topological_coherence`
- `directional_coherence`
- `reference_quality`
- `conflict_penalty`
- `technical_signature_penalty`

The score must be accompanied by the raw components.

Suggested output classes:

- **High:** multiple gene-level markers plus significant, specific enrichment; low conflict.
- **Moderate:** convincing marker or enrichment evidence, but incomplete support or moderate conflict.
- **Low:** limited evidence; label retained only as a broad putative context.
- **Unresolved:** evidence insufficient or contradictory.
- **Technical/covariate:** interpretable as a technical or sample-associated signature, not a biological priority.

The exact thresholds must be defined in code and documented in `docs/annotation_rules.md`.

---

## 7. Gene-specific interpretation

Every priority candidate must have a compact evidence record answering:

1. Why is this gene in the network?
2. Why is it ranked highly?
3. Which score components drive the rank?
4. What is its topological role?
5. Which module contains it?
6. Which exact genes and terms support the module interpretation?
7. Is the gene itself a marker, hub, bridge, or merely a module member?
8. Is it a canonical protein or a special locus?
9. What limits interpretation?
10. What conclusion is permitted?

### Required candidate fields

- candidate rank;
- gene symbol;
- STRING preferred name;
- entity class;
- mapping status;
- degree;
- betweenness;
- stress;
- candidate score;
- topology contribution;
- expression contribution;
- statistical contribution;
- logFC;
- p-value display;
- p-value underflow flag;
- module ID;
- module primary label;
- module secondary themes;
- candidate role in module;
- direct marker roles;
- representative neighbours;
- supporting significant terms;
- evidence summary;
- interpretation warning;
- review eligibility.

### Example evidence-based wording

Preferred:

> `MZB1` is located in a 20-gene module supported by `JCHAIN`, `TNFRSF17`, `IRF4`, `IGLL5` and multiple immunoglobulin variable genes. Significant enrichment supports immunoglobulin production, humoral immune response and B-cell/plasma-cell differentiation. The module is therefore annotated as a B-cell/plasma-cell immunoglobulin-secretion program. This is marker-supported cell-context evidence, not an estimate of plasma-cell abundance.

Avoid:

> `MZB1` belongs to a myeloid phagocytic programme.

---

## 8. Entity classification

Mapping and biological entity class must be independent.

### Mapping status

- mapped_unique;
- mapped_ambiguous;
- unmapped;
- alias_corrected;
- unsupported_identifier.

### Entity class

- canonical_protein_coding;
- immunoglobulin_locus;
- T_cell_receptor_locus;
- predicted_LOC;
- pseudogene;
- lncRNA_or_antisense;
- mitochondrial;
- ribosomal;
- Y_chromosome_associated;
- other_special_entity;
- unknown.

### Candidate eligibility

- review_ready_canonical;
- network_evidence_only;
- excluded_from_priority;
- manual_review_required.

A STRING mapping must not automatically convert a special entity into a canonical protein.

---

## 9. p-value handling

Exact numeric zeros must not be displayed as literal probabilities of zero.

Required behaviour:

- preserve the original parsed value;
- add `pvalue_underflow`;
- use a documented lower bound for scoring;
- display underflow values as below numerical precision;
- prevent a single underflowed p-value from dominating the complete candidate score;
- record the capping or transformation method in the run manifest.

The score remains exploratory and analysis-local.

---

## 10. Deterministic module detection

Required:

- explicit `module_seed`;
- seed written to the manifest;
- seed written to GraphML graph metadata;
- repeatability test using the same input and environment;
- statement that module IDs are local to one analysis and are not comparable across patients.

---

## 11. Analytical workbook contract

Target: five principal sheets, with one optional detailed sheet.

### 11.1. `Overview`

Purpose: one-screen summary.

Content:

- sample ID;
- CancerPPIr version/commit;
- date;
- input gene count;
- mapped gene count and percentage;
- network nodes and edges;
- connected components;
- isolates;
- multi-node modules;
- interpreted modules;
- technical/covariate modules;
- STRING version and score threshold;
- module seed;
- input-direction warning;
- mapping warning;
- interpretation boundary;
- one canonical STRING link;
- reading order.

### 11.2. `Network and mapping`

Purpose: concise quality-control summary.

Content:

- mapping-status counts;
- entity-class counts;
- largest-component statistics;
- module-size distribution;
- major causes of unmapped identifiers;
- compact warnings.

No full raw node table.

### 11.3. `Module priorities`

One row per promoted module.

Required fields:

- module ID;
- size;
- primary label;
- secondary themes;
- confidence;
- exact marker genes;
- exact significant terms;
- representative genes;
- topological summary;
- expression-direction summary;
- technical/conflict warnings;
- evidence rationale.

Unresolved, singleton, and technical/covariate modules must not be silently promoted.

### 11.4. `Candidate priorities`

One row per reported candidate.

Required fields are defined in Section 7.

The sheet must distinguish:

- review-ready canonical candidates;
- special-locus network leaders.

### 11.5. `Interpretation limits`

Run-specific limitations, not generic boilerplate only.

Examples:

- input contains only positively directed genes;
- mapping coverage is low;
- immunoglobulin/TCR loci dominate the input;
- many nodes are isolated;
- score is not comparable across patients;
- cell fractions cannot be inferred;
- labels are putative and evidence-weighted;
- target prioritization is exploratory.

### 11.6. `Detailed modules` — optional

One row per module. No repeated node-level metrics.

---

## 12. Technical workbook contract

Target sheets:

1. `Run manifest`
2. `Mapping audit`
3. `Node metrics`
4. `Module annotations`
5. `Module evidence`
6. `Network enrichment raw`
7. `Module enrichment raw`
8. `Candidate enrichment raw`
9. `Data dictionary`
10. `Session information`

Rules:

- no empty audit sheets;
- no repeated module rationale on every node;
- no `Raw major modules` subset duplicating `Module annotations`;
- raw terms remain available for audit;
- all fields documented;
- significant and non-significant terms explicitly distinguished.

---

## 13. Mapping audit contract

One row per input record.

Required fields:

- input row;
- input symbol;
- normalized symbol;
- normalization changed;
- STRING ID;
- STRING preferred name;
- mapping status;
- mapping reason;
- entity class;
- candidate eligibility;
- logFC;
- p-value raw;
- p-value display;
- p-value underflow;
- warning.

This replaces overlapping alias, normalization and unmapped sheets.

---

## 14. GraphML contract

### Node attributes

Keep only visualization- and filtering-relevant attributes:

- STRING ID;
- gene;
- preferred name;
- entity class;
- logFC;
- p-value display;
- p-value underflow;
- degree;
- betweenness;
- stress;
- candidate score;
- candidate rank;
- component ID;
- largest-component flag;
- module ID;
- module primary label;
- module confidence;
- priority class;
- interpretation warning.

### Edge attributes

- combined STRING score.

### Graph attributes

- sample ID;
- species;
- STRING version;
- interaction threshold;
- module seed;
- CancerPPIr version/commit;
- run date;
- input file hash;
- node count;
- edge count.

Long module rationale must not be repeated on every node.

---

## 15. STRING-link contract

Create one file with one canonical interactive link.

Required metadata:

- sample ID;
- species;
- STRING version;
- required score;
- number of submitted identifiers;
- identifier scope: full network / largest component / candidate subset;
- canonical URL;
- note pointing to the GraphML file.

Do not generate a second unreliable version-pinned URL unless it passes an automated availability test and has a clear purpose.

---

## 16. File naming

Use one normalized sample ID everywhere.

Example:

- `A01_CancerPPIr_Analytical_Report.xlsx`
- `A01_CancerPPIr_Technical_Report.xlsx`
- `A01_CancerPPIr_Network.graphml`
- `A01_CancerPPIr_STRING_Link.txt`

---

## 17. XLSX integrity requirements

Automated checks must verify:

- workbook can be opened by `openxlsx`;
- workbook can be opened by an independent OOXML parser;
- all relationship targets exist;
- worksheet dimensions match real content;
- no orphan Drawing or VML relationships;
- expected sheets are present in expected order;
- no duplicate column names;
- no duplicated user-facing tables;
- hyperlinks are valid OOXML hyperlinks;
- freeze panes and filters are valid;
- numeric fields have explicit number formats.

---

## 18. Acceptance tests

### Biological interpretation

- B-cell/plasma-cell modules are not classified as myeloid solely because of phagocytosis-related immunoglobulin terms.
- Y-chromosome modules are classified as technical/covariate and are not automatically promoted.
- Mixed modules receive mixed or broader labels.
- Final labels cite exact supporting genes and significant terms.
- Non-significant enrichment terms cannot support a user-facing label.
- Special loci cannot silently appear as review-ready canonical targets.
- Cell-fraction language is absent from standard CancerPPIr output.

### Numerical correctness

- p-value underflow is never displayed as literal zero.
- candidate-score components are output.
- score transformation and caps are documented.
- module detection is repeatable with a fixed seed.
- node and edge counts are unchanged unless a documented correction requires otherwise.

### Output architecture

- analytical workbook has no raw technical duplicates;
- technical workbook has no redundant subset sheets;
- GraphML read-back succeeds;
- one canonical STRING link is produced;
- sample naming is consistent.

### Regression

- A01 is the first development case.
- After A01 acceptance, run all seven cases.
- Record expected biological changes separately from unintended numerical changes.

---

## 19. Implementation checkpoints

### 4.1 — Freeze the output and interpretation contract

- commit this specification;
- define exact schemas;
- define prohibited claims;
- define acceptance tests.

### 4.2 — Correct the biological evidence engine

- hierarchical labels;
- positive/supportive/exclusion markers;
- significant enrichment only;
- conflict detection;
- technical-signature detection;
- entity classification;
- confidence components;
- exact gene-level rationale.

### 4.3 — Correct numerical and reproducibility behaviour

- p-value underflow;
- score components;
- deterministic Louvain;
- run manifest.

### 4.4 — Rebuild analytical workbook

- concise sheet architecture;
- human-readable columns;
- controlled widths and number formats;
- run-specific limitations.

### 4.5 — Rebuild technical workbook

- normalized node/module/evidence/mapping tables;
- remove duplicate and empty sheets;
- add data dictionary.

### 4.6 — Simplify GraphML and STRING link

- compact attributes;
- graph metadata;
- one canonical link;
- consistent file names.

### 4.7 — Validate A01

- biological review;
- output integrity;
- regression;
- manual readability review.

### 4.8 — Validate all seven cases

- automated run;
- cross-case label audit;
- regression summary;
- final documentation.

---

## 20. References guiding the specification

1. Dai Y, Guo S, Pan Y, et al. A guide to transcriptomic deconvolution in cancer. *Nature Reviews Cancer*. 2026;26:84–103. doi:10.1038/s41568-025-00886-9.
2. Guo S, Liu X, Cheng X, et al. A deconvolution framework that uses single-cell sequencing plus a small benchmark data set for accurate analysis of cell type ratios in complex tissue samples. *Genome Research*. 2025;35:147–161. doi:10.1101/gr.278822.123.

---

## 21. Decision record

Phase 4 will not convert CancerPPIr into a cell-fraction deconvolution method.

It will make CancerPPIr substantially more biologically specific by producing:

- exact gene-supported module labels;
- explicit lineage, state, process and technical-signature layers;
- transparent confidence components;
- conflict-aware interpretation;
- concise and valid user-facing reports.

A separate deconvolution extension may be considered later only with suitable input matrices, references, benchmarking and validation.