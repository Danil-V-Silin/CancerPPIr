# CancerPPIr Phase 4 — A01 baseline output audit

**Sample:** A01

**Audit status:** BASELINE_HAS_CRITICAL_ISSUES

## Inputs

- Analytical workbook: `../results/phase2_architecture_final/Genes_A/CancerPPIr_Analytical_Report.xlsx`
- Technical workbook: `../results/phase2_architecture_final/Genes_A/CancerPPIr_Technical_Report.xlsx`
- GraphML: `../results/phase2_architecture_final/Genes_A/Network_for_Cytoscape.graphml`
- STRING link file: `../results/phase2_architecture_final/Genes_A/STRING_links.txt`

## Summary

- Analytical sheets: 11
- Technical sheets: 16
- Graph: 169 nodes, 630 edges
- GraphML node attributes: 48
- Critical P0 failures: 14
- P1 failures: 8
- Warnings: 1

## Findings

### P0 — allmodules_b_plasma_misclassification — FAIL

**Location:** analytical_workbook / All modules

A module containing strong B-cell/plasma-cell-associated genes is described with a myeloid/phagocytic label.

**Evidence:** 2 | 20 | 20 | 12.2579591387396 | 11.9648419718152 | 0 | 1.76545152383513e-19 | LOC102723407 | LOC102723407;IGLL5;JCHAIN;IGHV3-11;IGHV3-15;IGHV1-3;MZB1;IRF4;IGKV2D-40;IGHV3-16;MSTN;TNFRSF17 | LOC102723407;IGLL5;JCHAIN;IGHV3-11;IGKV2D-40;IGHV3-16;IRF4;IGLL1;IGLV10-54;IGHV3-15;IGHV1-3;IGHV3-72 | LOC102723407;IGLL5;IGHV3-16;JCHAIN;IRF4;MSTN;IGHV3-11;IGKV2D-40;IGLV10-54;IGHV3-15;TNFRSF17;IGHV1-3 | no_marker_set_match | unassigned_module |  | Immunoglobulin complex; Immunoglobulin complex, and IgG-binding protein; Immunoglobulin complex, and DNA recombinase complex | Cellular Component (Gene Ontology);Local Network Cluster (STRING);Molecular Function (Gene Ontology) | 8.4477956787838e-15 | 9.25...

**Required correction:** Add B-cell, plasma-cell, immunoglobulin-secretion and humoral-immunity rules with anti-marker/conflict logic.

### P0 — allmodules_y_chromosome_signature — FAIL

**Location:** analytical_workbook / All modules

A Y-chromosome-associated signature is unresolved or promoted without a technical/covariate classification.

**Evidence:** 3 | 15 | 0 | 11.3325752934287 | 11.3676929748693 | 4.42371063730225e-22 | 1.16179023862173e-14 | RPS4Y1 | RPS4Y1;EIF1AY;KDM5D;ZFY;DDX3Y;TSPY1;UTY;USP9Y;KCNA5;GAGE12J;PRKY;TMSB4Y | RPS4Y1;EIF1AY;ZFY;KDM5D;DDX3Y;UTY;USP9Y;PRKY;TMSB4Y;TSPY1;NLGN4Y;TSPY2 | RPS4Y1;KCNA5;EIF1AY;ZFY;KDM5D;DDX3Y;UTY;USP9Y;PRKY;TMSB4Y;TSPY1;GAGE12J | no_marker_set_match | unassigned_module |  | Mixed, incl. NAP-like superfamily, and RNA recognition motif; Mostly uncharacterized, incl. Y-linked monogenic disease, and RBM1CTR (NUC064) family; Mixed, incl. RBM1CTR (NUC064) family, and Gonadal mesoderm development | Local Network Cluster (STRING);Biological Process (Gene Ontology);Disease-gene associations (DISEASES) ...

**Required correction:** Classify Y-linked signatures as technical/covariate and exclude them from automatic biological priority promotion.

### P0 — finalpriorities_b_plasma_misclassification — FAIL

**Location:** analytical_workbook / Final priorities

A module containing strong B-cell/plasma-cell-associated genes is described with a myeloid/phagocytic label.

**Evidence:** biological_direction | 3 | myeloid phagocytic immune signaling | 2 | LOC102723407;IGLL5;JCHAIN;IGHV3-11;IGHV3-15;IGHV1-3;MZB1;IRF4;IGKV2D-40;IGHV3-16;MSTN;TNFRSF17 | module_size=20; best_specific_enrichment_FDR=9.25e-13; label_source=specific_STRING_enrichment_only; label_evidence_score=5; label_confidence=medium_high_specific_STRING_evidence; label_warning=label_assigned_from_STRING_only_without_curated_marker_support; supporting_themes=myeloid/phagocytic immune signaling; phagocytic actin/cytoskeleton remodeling; marker_support=no_marker_set_match | Putative program: myeloid phagocytic immune signaling. Specific-label candidate: myeloid phagocytic immune signaling. Fallback label: myelo...

**Required correction:** Add B-cell, plasma-cell, immunoglobulin-secretion and humoral-immunity rules with anti-marker/conflict logic.

### P0 — finalpriorities_y_chromosome_signature — FAIL

**Location:** analytical_workbook / Final priorities

A Y-chromosome-associated signature is unresolved or promoted without a technical/covariate classification.

**Evidence:** biological_direction | 4 | unassigned | 3 | RPS4Y1;EIF1AY;KDM5D;ZFY;DDX3Y;TSPY1;UTY;USP9Y;KCNA5;GAGE12J;PRKY;TMSB4Y | module_size=15; best_specific_enrichment_FDR=not_available; label_source=not_assigned; label_evidence_score=1; label_confidence=low_unassigned_or_insufficient_evidence; label_warning=no_reliable_marker_or_specific_STRING_evidence_for_label; supporting_themes=not_available; marker_support=no_marker_set_match | Putative program: unassigned. Specific-label candidate: unassigned. Fallback label: unassigned. Label assignment mode: unassigned_insufficient_evidence. Label source: not_assigned. Evidence score: 1. Confidence: low_unassigned_or_insufficient_evidence. Warning: no_rel...

**Required correction:** Classify Y-linked signatures as technical/covariate and exclude them from automatic biological priority promotion.

### P0 — majormodulepriorities_b_plasma_misclassification — FAIL

**Location:** analytical_workbook / Major module priorities

A module containing strong B-cell/plasma-cell-associated genes is described with a myeloid/phagocytic label.

**Evidence:** 3 | 2 | myeloid phagocytic immune signaling | 20 | 0.1183 | predominantly_upregulated | LOC102723407 | LOC102723407;IGLL5;JCHAIN;IGHV3-11;IGHV3-15;IGHV1-3;MZB1;IRF4;IGKV2D-40;IGHV3-16;MSTN;TNFRSF17 | LOC102723407;IGLL5;JCHAIN;IGHV3-11;IGKV2D-40;IGHV3-16;IRF4;IGLL1;IGLV10-54;IGHV3-15;IGHV1-3;IGHV3-72 | LOC102723407;IGLL5;IGHV3-16;JCHAIN;IRF4;MSTN;IGHV3-11;IGKV2D-40;IGLV10-54;IGHV3-15;TNFRSF17;IGHV1-3 | no_marker_set_match |  | 0 | myeloid/phagocytic immune signaling; phagocytic actin/cytoskeleton remodeling | Phagocytosis, engulfment; Regulation of B cell activation; Adaptive immune response; B cell receptor signaling pathway; Positive regulation of B cell activation; Phagocytosis, recogni...

**Required correction:** Add B-cell, plasma-cell, immunoglobulin-secretion and humoral-immunity rules with anti-marker/conflict logic.

### P0 — majormodulepriorities_y_chromosome_signature — FAIL

**Location:** analytical_workbook / Major module priorities

A Y-chromosome-associated signature is unresolved or promoted without a technical/covariate classification.

**Evidence:** 4 | 3 | unassigned | 15 | 0.0888 | predominantly_upregulated | RPS4Y1 | RPS4Y1;EIF1AY;KDM5D;ZFY;DDX3Y;TSPY1;UTY;USP9Y;KCNA5;GAGE12J;PRKY;TMSB4Y | RPS4Y1;EIF1AY;ZFY;KDM5D;DDX3Y;UTY;USP9Y;PRKY;TMSB4Y;TSPY1;NLGN4Y;TSPY2 | RPS4Y1;KCNA5;EIF1AY;ZFY;KDM5D;DDX3Y;UTY;USP9Y;PRKY;TMSB4Y;TSPY1;GAGE12J | no_marker_set_match |  | 0 | not_available |  |  |  | Gamete generation; Multicellular organismal reproductive process; Chromatin organization; Chromosome organization; Multicellular organism reproduction; Sexual reproduction | unassigned | unassigned | unassigned_insufficient_evidence | not_assigned | 1 | low_unassigned_or_insufficient_evidence | no_reliable_marker_or_specific_STRING_evidence_for_lab...

**Required correction:** Classify Y-linked signatures as technical/covariate and exclude them from automatic biological priority promotion.

### P0 — user_facing_non_significant_module_terms — FAIL

**Location:** technical_workbook / Top module enrichment

4 user-facing module enrichment row(s) have FDR > 0.05.

**Evidence:** Maximum observed FDR: 0.261.

**Required correction:** Require both interpretability and statistical significance for user-facing enrichment evidence.

### P0 — candidaterationale_special_entities — FAIL

**Location:** analytical_workbook / Candidate rationale

14 immunoglobulin, TCR, or LOC entity/entities appear in a candidate-facing table without a guaranteed independent eligibility class.

**Evidence:** LOC102723407; IGLL5; IGHV3-11; IGHV3-15; IGHV1-3; IGKV2D-40; IGHV3-16; IGLL1; IGLV10-54; IGHV3-72; TRAT1; IGKV2D-29; IGHD; IGHV3OR16-9

**Required correction:** Separate STRING mapping status, biological entity class, and candidate eligibility.

### P0 — topcandidates_special_entities — FAIL

**Location:** analytical_workbook / Top candidates

5 immunoglobulin, TCR, or LOC entity/entities appear in a candidate-facing table without a guaranteed independent eligibility class.

**Evidence:** LOC102723407; IGLL5; IGHV3-11; IGHV3-15; IGHV1-3

**Required correction:** Separate STRING mapping status, biological entity class, and candidate eligibility.

### P0 — one_direction_only_input — FAIL

**Location:** technical_workbook / Raw node metrics

All finite network logFC values are positive.

**Evidence:** Observed logFC range: 8.4919 to 18.13.

**Required correction:** State that downregulated programmes cannot be evaluated and avoid unqualified activation language.

### P0 — candidaterationale_literal_zero_pvalues — FAIL

**Location:** workbook / Candidate rationale

8 p-value(s) are displayed as literal zero.

**Evidence:** A literal zero is normally a numerical underflow or upstream rounding result, not an exact probability.

**Required correction:** Add pvalue_underflow, a display lower bound, and a documented cap for the candidate-score statistical component.

### P0 — rawnodemetrics_literal_zero_pvalues — FAIL

**Location:** workbook / Raw node metrics

8 p-value(s) are displayed as literal zero.

**Evidence:** A literal zero is normally a numerical underflow or upstream rounding result, not an exact probability.

**Required correction:** Add pvalue_underflow, a display lower bound, and a documented cap for the candidate-score statistical component.

### P0 — analytical_workbook_missing_relationship_targets — FAIL

**Location:** analytical_workbook / CancerPPIr_Analytical_Report.xlsx

The workbook contains 22 internal OOXML relationship target(s) that do not exist.

**Evidence:** xl/worksheets/_rels/sheet1.xml.rels -> ../drawings/drawing1.xml; xl/worksheets/_rels/sheet1.xml.rels -> ../drawings/vmlDrawing1.vml; xl/worksheets/_rels/sheet10.xml.rels -> ../drawings/drawing10.xml; xl/worksheets/_rels/sheet10.xml.rels -> ../drawings/vmlDrawing10.vml; xl/worksheets/_rels/sheet11.xml.rels -> ../drawings/drawing11.xml; xl/worksheets/_rels/sheet11.xml.rels -> ../drawings/vmlDrawing11.vml; xl/worksheets/_rels/sheet2.xml.rels -> ../drawings/drawing2.xml; xl/worksheets/_rels/sheet...

**Required correction:** Regenerate worksheets without orphan drawing/VML relationships and add a package-integrity test.

### P0 — technical_workbook_missing_relationship_targets — FAIL

**Location:** technical_workbook / CancerPPIr_Technical_Report.xlsx

The workbook contains 32 internal OOXML relationship target(s) that do not exist.

**Evidence:** xl/worksheets/_rels/sheet1.xml.rels -> ../drawings/drawing1.xml; xl/worksheets/_rels/sheet1.xml.rels -> ../drawings/vmlDrawing1.vml; xl/worksheets/_rels/sheet10.xml.rels -> ../drawings/drawing10.xml; xl/worksheets/_rels/sheet10.xml.rels -> ../drawings/vmlDrawing10.vml; xl/worksheets/_rels/sheet11.xml.rels -> ../drawings/drawing11.xml; xl/worksheets/_rels/sheet11.xml.rels -> ../drawings/vmlDrawing11.vml; xl/worksheets/_rels/sheet12.xml.rels -> ../drawings/drawing12.xml; xl/worksheets/_rels/she...

**Required correction:** Regenerate worksheets without orphan drawing/VML relationships and add a package-integrity test.

### P1 — duplicate_1 — FAIL

**Location:** cross_workbook / Analytical: All modules vs Technical: Raw all modules

The compared tables contain exact or near-exact duplicated information.

**Evidence:** Common-column cell identity: 100%; common columns: 48.

**Required correction:** Keep each analytical entity once and separate user-facing summaries from raw technical tables.

### P1 — duplicate_2 — FAIL

**Location:** cross_workbook / Analytical: Candidate rationale vs Technical: Raw node metrics

The compared tables contain exact or near-exact duplicated information.

**Evidence:** Common-column cell identity: 100%; common columns: 31.

**Required correction:** Keep each analytical entity once and separate user-facing summaries from raw technical tables.

### P1 — duplicate_3 — FAIL

**Location:** cross_workbook / Analytical: Top candidates vs Analytical: Candidate rationale

The compared tables contain exact or near-exact duplicated information.

**Evidence:** Common-column cell identity: 100%; common columns: 27.

**Required correction:** Keep each analytical entity once and separate user-facing summaries from raw technical tables.

### P1 — duplicate_4 — FAIL

**Location:** cross_workbook / Technical: Raw major modules vs Technical: Raw all modules

The compared tables contain exact or near-exact duplicated information.

**Evidence:** Common-column cell identity: 100%; common columns: 48.

**Required correction:** Keep each analytical entity once and separate user-facing summaries from raw technical tables.

### P1 — overlapping_top_rank_lists — FAIL

**Location:** analytical_workbook / Top candidates; Top degree; Top betweenness; Top stress

Separate top-degree, top-betweenness, top-stress and candidate sheets substantially overlap.

**Evidence:** 47 unique genes across 4 lists; 17 genes occur in every list.

**Required correction:** Replace the separate sheets with one candidate-priority table containing explicit score components and topology roles.

### P1 — graphml_attribute_overload — FAIL

**Location:** graphml / Network_for_Cytoscape.graphml

The GraphML node schema is overloaded and repeats long module-level text across nodes.

**Evidence:** 48 node attributes; 6 repeated long-text attribute(s).

**Required correction:** Keep visualization-relevant node attributes only and move detailed module rationale to one module-level technical table.

### P1 — overlapping_mapping_audit_sheets — FAIL

**Location:** technical_workbook / Alias corrections; Unmapped genes; HGNC normalization

Mapping and normalization evidence is split across overlapping sheets.

**Evidence:** 231 alias rows; 231 unmapped rows; 400 normalization rows.

**Required correction:** Replace the overlapping sheets with one row-per-input Mapping audit table containing status, reason, entity class and warning.

### P1 — string_link_count — FAIL

**Location:** string_link_file / STRING_links.txt

The STRING-link file contains 2 URL(s); exactly one canonical URL is required.

**Evidence:** https://string-db.org/cgi/network?identifiers=9606.ENSP00000479675%0d9606.ENSP00000479119%0d9606.ENSP00000363770%0d9606.ENSP00000479745%0d9606.ENSP00000474135%0d9606.ENSP00000480035%0d9606.ENSP00000308815%0d9606.ENSP00000229030%0d9606.ENSP00000363773%0d9606.ENSP00000343619%0d9606.ENSP00000216341%0d9606.ENSP00000242159%0d9606.ENSP00000313967%0d9606.ENSP00000375622%0d9606.ENSP00000322408%0d9606.ENSP00000483567%0d9606.ENSP00000440066%0d9606.ENSP00000478289%0d9606.ENSP00000354722%0d9606.ENSP00000375616%0d9606.ENSP00000383933%0d9606.ENSP00000259607%0d9606.ENSP00000475344%0d9606.ENSP00000403304%0...

**Required correction:** Output one tested canonical STRING URL plus explicit run metadata and a GraphML note.

### P1 — low_mapping_coverage — WARN

**Location:** technical_workbook / Mapping summary

Mapping coverage is below 70%.

**Evidence:** 231/400 (57.8%).

**Required correction:** Report mapping limitations prominently and classify unmapped identifiers by reason and entity class.

### INFO — graphml_readback — PASS

**Location:** graphml / Network_for_Cytoscape.graphml

The GraphML file was read successfully by igraph.

**Evidence:** 169 nodes; 630 edges.

**Required correction:** Keep read-back validation in the permanent test suite.

## Interpretation

This is a characterization baseline. The script intentionally records known defects without modifying output files or returning a non-zero exit code. After each Phase 4 checkpoint, the same audit should be rerun to demonstrate which findings were resolved and which remain.

