# Limitations

CancerPPIr is an exploratory workflow for network-based prioritization of proteins and module-level biological programs from bulk RNA-seq-derived gene tables. Its output is intended to support hypothesis generation and downstream review, not to define treatment on its own.

## Scope of inference

CancerPPIr ranks proteins within a reconstructed STRING-derived PPI subnetwork. A high rank means that a protein is prominent in the analysed network and expression profile. It does not by itself establish therapeutic efficacy, clinical actionability, druggability, oncogenic dependency, or suitability for a specific treatment.

## Bulk RNA-seq input

Bulk tumor RNA-seq represents a mixture of malignant cells and non-malignant components of the specimen, including immune, stromal, endothelial and other microenvironmental cells. CancerPPIr does not deconvolve cell types and does not distinguish tumor-cell-intrinsic signals from microenvironment-derived signals.

The interpretation of immune, stromal, myeloid, antigen-presentation or extracellular-matrix modules should therefore be made in the context of histology, tumor purity, sampling site, pathology review and, when available, single-cell, spatial, immunohistochemical or flow-cytometry data.

## STRING-derived network

The network is derived from STRING protein associations. These edges represent known, curated or predicted functional associations compiled by STRING. They are not patient-specific physical interaction measurements and should not be interpreted as direct evidence that two proteins interact in the analysed tumor sample.

STRING coverage is affected by database content, literature bias, organism-specific annotation depth and prior biological knowledge. Well-studied proteins and pathways may therefore appear more connected than poorly annotated proteins.

## Candidate score

The `candidate_score` combines normalized degree, betweenness, log-transformed stress centrality, absolute logFC and `-log10(p-value)`. It is a ranking statistic for prioritizing proteins inside the reconstructed network.

The score should not be read as a probability of response, a measure of essentiality, or a drug-target confidence score. It does not include mutation status, copy-number alterations, protein abundance, post-translational regulation, ligandability, toxicity, survival association or evidence from clinical trials.

## Module annotation

Module labels are computational annotations assigned from curated marker-gene overlap and local STRING enrichment terms. They are reported as putative biological programs. A module label is strongest when marker evidence and specific enrichment terms agree; it is weaker when only one evidence layer is present.

Labels should be interpreted together with `label_source`, `label_evidence_score`, `label_confidence`, `label_warning`, marker support and top interpretable enrichment terms. Modules flagged as unassigned or low-confidence should not be used for strong biological conclusions.

## Enrichment terms

CancerPPIr uses locally cached STRING v12 enrichment terms in the current offline workflow. The term categories may include Gene Ontology, WikiPathways, UniProt keywords, STRING local network clusters and related STRING annotation categories available in the downloaded STRING enrichment file.

Broad terms such as generic signalling, cell communication or regulation terms are not used as primary evidence for module labels. They are kept in the technical workbook for audit.

## Appropriate use

CancerPPIr is appropriate for:

- prioritizing proteins for follow-up analysis;
- summarizing dominant biological programs in a patient-specific PPI subnetwork;
- comparing network-derived hypotheses across cases;
- preparing candidate lists for additional validation.

CancerPPIr output should be integrated with independent evidence, including pathology, molecular alterations, expression context, druggability, pathway knowledge, model-system data and clinical literature.

## Not a clinical decision system

CancerPPIr is not a diagnostic device, treatment recommendation system or substitute for clinical interpretation. Any clinical or translational use requires independent validation and review by qualified specialists.
