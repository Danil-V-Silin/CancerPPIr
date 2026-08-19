# Limitations

CancerPPIr is an exploratory network-prioritization workflow. It supports
hypothesis generation and structured evidence review; it is not a diagnostic
device, treatment recommendation system, or substitute for qualified clinical
interpretation.

## Input semantics

CancerPPIr now enforces raw differential-expression `pvalue` and base-2
`tumor specimen / reference condition` logFC semantics. Positional column
fallback, incomplete numeric rows and duplicate input symbols are rejected.
The selected headers and contract policies are written to output provenance.

This validation does not recover the biological composition of the reference
condition, the upstream normalization, design formula, covariates, filtering or
multiple-testing method. Those study-level details must remain with the source
differential-expression analysis. Comparisons across runs require the same
upstream model, contrast and selection procedure.

Raw differential-expression p-values are not adjusted within CancerPPIr.
Appropriate multiple-testing control and input-gene selection must therefore be
performed and documented upstream; enrichment FDR does not correct the input
differential-expression p-values.

HGNC normalization, alias correction and STRING mapping can still change row
counts. Input rows, mapped input rows, unique mapped proteins and final graph
nodes are distinct quantities.

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

The pinned human STRING v12 files are acquired from the official distribution
at `https://stringdb-downloads.org/download/` when missing or invalid and are
then reused locally. The network uses the full STRING association graph with
`combined_only` evidence and a default score threshold of `400/1000`. Individual
evidence-channel contributions are not exported, and an included edge is not
required to have direct experimental support. Louvain communities are
calculated without edge weights; interaction scores determine edge inclusion
but do not weight module detection. A deterministic seed improves
reproducibility, not biological validity.

## Candidate score

The candidate score combines five normalized base components across three
equally weighted evidence domains. Degree, betweenness, and log-transformed
stress centrality form the topology domain; absolute logFC and transformed
statistical evidence form the other two domains. It is a relative ranking
inside one reconstructed network.

It is not:

- a probability of response;
- an essentiality score;
- a druggability or ligandability score;
- a toxicity or therapeutic-index estimate;
- evidence of causal oncogenic dependency;
- evidence from clinical trials.

Cross-case numerical comparison requires additional normalization and a
separate study design; within-case ranks are the primary intended use.

The predefined candidate score is not externally calibrated or benchmarked
against independent reference targets, functional-dependency experiments,
treatment response, or patient outcomes. Its domain weights are heuristic,
and no sensitivity, specificity, predictive value, uncertainty interval, or
clinical accuracy is established. Absolute logFC prioritizes both increased
and decreased expression; the signed logFC must be reviewed separately.

## Module annotation

Canonical module interpretations are computational inferences from
statistically significant, non-generic local STRING terms. The primary
interpretation is the qualifying term with the lowest FDR; technical or
covariate signatures override biological priority. Curated marker-rule
evaluations remain auxiliary audit information and do not determine canonical
interpretation or automatic priority.

Supported biological modules currently receive `moderate` confidence. Marker,
lineage, state, process, and conflict fields retained for schema compatibility
must not be mistaken for independently resolved or validated classifications.
Technical/covariate and unresolved modules remain visible but are not
automatically promoted. An unresolved module is not a pipeline error and does
not imply absence of biological function.

Functional enrichment is evaluated only for the five largest Louvain modules
containing at least five proteins. Smaller or lower-ranked modules may remain
unresolved because they were not tested, not because their biological function
is absent. A qualifying term can be supported by as few as two proteins;
supporting genes, module size, term specificity, and pathology must therefore
be reviewed together.

## Enrichment

Offline enrichment depends on the content and release of locally cached STRING
v12 resources. Database categories may be redundant, unevenly annotated, or
biased toward well-studied processes. Generic terms are excluded from the
primary analytical evidence but retained in raw technical tables.

Statistical enrichment does not establish causal relevance, therapeutic
vulnerability, or sample-specific pathway activity.

Module enrichment uses a hypergeometric test against the case-network
background restricted to proteins represented in the STRING term map.
Terms require at least two supporting proteins and between three and 500
annotated background proteins. Benjamini-Hochberg adjustment is applied within
each enrichment query, not across modules or analyses. The resulting FDR is
not the probability that a module assignment is correct. Whole-network
enrichment instead uses the annotated human STRING background.

STRING network associations and STRING functional annotations are not
independent sources of evidence. Local enrichment is computed by CancerPPIr
from cached STRING annotations and its selected background; it is not an
independent external validation or a live STRING web-service result.

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
