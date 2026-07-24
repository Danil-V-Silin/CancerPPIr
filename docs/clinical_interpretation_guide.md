# Clinical interpretation guide

CancerPPIr organizes exploratory network evidence; it does not make a clinical
decision. This guide separates what the workflow computes from what requires
independent translational validation.

## Evidence ladder

Interpret results from lower to higher evidentiary levels:

1. **Input evidence** — the supplied gene, logFC, and statistical values.
2. **Mapping evidence** — successful, corrected, and failed gene-to-STRING
   mappings.
3. **Network evidence** — retained nodes, edges, topology, components, and
   deterministic Louvain modules.
4. **Module evidence** — canonical marker and significant-term support,
   confidence, conflict, warning, and rationale.
5. **Candidate priority** — within-network score, topology ranks, expression
   evidence, entity eligibility, and eligible module context.
6. **External biological evidence** — mutation, copy number, protein abundance,
   localization, pathway dependency, and model-system validation.
7. **Pharmacological evidence** — ligandability, selectivity, exposure, toxicity,
   resistance, and target-engagement evidence.
8. **Clinical evidence** — disease-specific trials, guidelines, biomarkers,
   patient eligibility, safety, and multidisciplinary review.

CancerPPIr directly covers levels 1–5 only.

## Candidate interpretation

A candidate should be described using all of the following:

- network candidate rank and candidate score;
- topology ranks and the five score components;
- logFC and the supplied statistical value;
- entity class and candidate eligibility;
- module interpretation, confidence, conflict, warning, and rationale;
- evidence that remains absent from the workflow.

Acceptable formulation:

> The protein was prioritized within the reconstructed STRING-derived network
> because of combined topology and expression evidence and membership in a
> priority-eligible biological module. This ranking is hypothesis generating and
> requires independent molecular and clinical validation.

Unsupported formulation:

> The protein is a validated treatment target for this patient.

## Module interpretation

A module interpretation is strongest when:

- marker and significant-term evidence are concordant;
- confidence is high or moderate;
- conflict is absent;
- the evidence rationale names the supporting genes and terms;
- the interpretation agrees with pathology and specimen context.

Technical/covariate, mixed-biological, and unresolved modules must remain
visible. They should not be relabelled manually as biological priorities merely
to produce a complete-looking table.

## Bulk specimen context

Immune, stromal, endothelial, extracellular-matrix, antigen-presentation, or
other microenvironment-associated evidence can originate from non-malignant
cells. CancerPPIr does not infer cell fractions or prove cellular origin.

Review these interpretations together with:

- histological diagnosis and sampling site;
- tumor purity and necrosis;
- immunohistochemistry or flow cytometry;
- single-cell or spatial data when available;
- treatment history and inflammatory context.

## Cross-case comparison

Candidate scores are normalized within each reconstructed network. Cross-case
comparison of raw scores is not automatically valid. A comparative study should
predefine consistent input generation, STRING threshold, cache version,
filtering, score components, and statistical analysis.

Prefer comparing:

- rank categories;
- recurring eligible modules;
- repeated canonical biological contexts;
- candidate membership under a predefined cohort-level method.

## Minimum reporting set

A formal result section should report:

1. input and mapping counts;
2. network nodes, edges, components, and largest-component fraction;
3. deterministic Louvain module count;
4. eligible and unresolved module counts;
5. candidate-score definition;
6. selected candidate and module evidence with warnings;
7. STRING version and threshold;
8. manifest/checksum availability;
9. bulk RNA-seq, STRING, and clinical non-actionability limitations.

## Independent validation checklist

Before a translational conclusion, assess:

- sample identity and pathology;
- genomic alterations and clonality;
- protein-level expression and localization;
- tumor-cell versus microenvironment origin;
- functional dependency in a relevant model;
- druggability and available agents;
- off-target and toxicity risks;
- disease-specific clinical evidence;
- consistency across independent data and methods.
