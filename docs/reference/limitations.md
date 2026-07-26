# Limitations

CancerPPIr is an exploratory network-prioritization workflow. It supports
hypothesis generation and structured evidence review; it is not a diagnostic
device, treatment recommendation system, or substitute for qualified clinical
interpretation.

## Input semantics

The workflow accepts a column named `pvalue`, but that column may contain a raw
p-value, adjusted p-value, or FDR supplied by the user. CancerPPIr preserves and
uses the supplied values but cannot recover the upstream statistical definition.
Comparisons across runs require consistent upstream differential-expression
methods and column semantics.

Duplicate identifiers, HGNC normalization, alias correction, and STRING mapping
can change row counts. Input rows, mapped input rows, unique mapped proteins, and
final graph nodes are distinct quantities.

## Bulk RNA-seq mixture

Bulk tumor RNA-seq combines malignant cells with immune, stromal, endothelial,
and other specimen components. CancerPPIr does not deconvolve cell types, infer
cell fractions, or prove tumor-cell-intrinsic origin. Module compartment and
lineage fields are evidence-based contexts, not abundance estimates.

Histology, tumor purity, sampling site, and—when available—single-cell, spatial,
immunohistochemical, or flow-cytometry data remain necessary for cell-origin
claims.

## STRING-derived network

STRING edges are curated, experimental, predicted, co-expression, text-mined,
or otherwise integrated associations. They are not patient-specific physical
interaction measurements. Network structure is influenced by STRING coverage,
literature bias, organism annotation depth, the input gene set, mapping, and the
selected score threshold.

Highly studied proteins may appear more connected than poorly characterized
proteins. A node absent from the final network may still be biologically
important.

## Candidate score

The candidate score combines normalized degree, betweenness, log-transformed
stress centrality, absolute logFC, and transformed statistical evidence. It is a
relative ranking inside one reconstructed network.

It is not:

- a probability of response;
- an essentiality score;
- a druggability or ligandability score;
- a toxicity or therapeutic-index estimate;
- evidence of causal oncogenic dependency;
- evidence from clinical trials.

Cross-case numerical comparison requires additional normalization and a
separate study design; within-case ranks are the primary intended use.

## Module annotation

Canonical module interpretations are computational inferences from curated
marker evidence and statistically significant local STRING terms. Confidence,
conflict, warnings, and evidence rationale must accompany the interpretation.

Technical/covariate, mixed-conflict, and unresolved modules remain visible but
are not automatically promoted. An unresolved module is not a pipeline error and
does not imply absence of biological function.

## Enrichment

Offline enrichment depends on the content and release of locally cached STRING
v12 resources. Database categories may be redundant, unevenly annotated, or
biased toward well-studied processes. Generic terms are excluded from the
primary analytical evidence but retained in raw technical tables.

Statistical enrichment does not establish causal relevance, therapeutic
vulnerability, or sample-specific pathway activity.

## Entity classification and eligibility

Entity classification uses gene-symbol rules to prevent automatic promotion of
special entities such as immunoglobulin/T-cell receptor loci, predicted loci,
pseudogene-like, non-coding, mitochondrial, ribosomal, or Y-associated genes.
These entities remain in network evidence where appropriate. Classification is
conservative and may require manual review.

## Provenance and checksums

SHA-256 verifies exact bytes, not biological or semantic equivalence. XLSX files
may receive different byte-level hashes across independent runs because of ZIP
metadata or workbook timestamps even when visible tables are equivalent.
Semantic comparison must inspect workbook tables and network attributes.

The standard manifest records STRING cache basenames and sizes but does not
re-read multi-gigabyte cache files solely to hash them. Git metadata may be
unavailable when CancerPPIr is run from a source archive rather than a Git
working tree.

## Appropriate use

CancerPPIr is appropriate for:

- prioritizing proteins for follow-up analysis;
- summarizing network-associated biological programs;
- generating auditable candidate rationales;
- comparing hypotheses under a predefined study design;
- selecting candidates for experimental, pharmacological, or literature review.

Any translational claim requires independent pathology, molecular, protein-
level, model-system, pharmacological, safety, and clinical evidence.
