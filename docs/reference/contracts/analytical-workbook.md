# Analytical workbook contract

Schema version: `2.0.0`

## Scope

This contract defines the stable human-readable CancerPPIr analytical workbook.
The complete mapping, node, module, enrichment, provenance, and validation audit
remains in `CancerPPIr_Technical_Report.xlsx`.

The analytical workbook is generated from the canonical biological-evidence
object. Deprecated compatibility fields are not analytical evidence.

## Exact sheet order

1. `Executive summary`
2. `Final priorities`
3. `Module priorities`
4. `Candidate evidence`
5. `Network overview`
6. `Methods and limitations`

## Selection rules

### Final priorities

At most ten proteins are reported. A protein is automatically eligible only
when all of the following are true:

- `candidate_eligibility == "review_ready_canonical"`
- `module_interpretation_class == "biological"`
- `module_priority_eligible == TRUE`
- `module_conflict_detected == FALSE`

The table may contain fewer than ten rows. Ineligible proteins are never added
merely to fill the table.

### Module priorities

At most five modules are reported. A module is eligible only when:

- `interpretation_class == "biological"`
- `priority_eligible == TRUE`

The analytical interpretation is derived directly from statistically
significant, non-generic STRING/database enrichment terms. The primary term is
the qualifying term with the lowest FDR; up to two additional qualifying terms
are retained as secondary context.

Benjamini-Hochberg adjustment is calculated within each query over all terms
meeting the background-size bounds before the minimum two-protein support
threshold is applied for reporting.

Ordering is deterministic: module size, primary-term FDR, and module
identifier.

The sheet exposes direct STRING/database traceability through
`primary_term_source`, `primary_term_id`, `primary_term_fdr`,
`primary_term_supporting_genes`, and `secondary_terms`.

### Candidate evidence

The sheet contains the top `top_n` proteins by the deterministic full-network
candidate order, plus Final priorities not already present. Special or
predicted loci remain visible with their eligibility status and warning.

## Candidate-score transparency

The workbook exposes the five normalized base score components:

- degree;
- betweenness;
- `log1p(stress_centrality)`;
- absolute `logFC`;
- `-log10(pvalue)`.

Degree, betweenness, and log-stress are first averaged into one topology
domain. `candidate_score` is then the arithmetic mean of the topology domain,
absolute `logFC`, and statistical evidence, giving equal aggregate weight to
the three evidence domains.

All five components must be finite. The exposed base components must
reconstruct `candidate_score` through this two-stage aggregation within
floating-point tolerance; variable-denominator scoring is not permitted.

## Biological-evidence policy

Only canonical biological-evidence fields are used for analytical biological
context. Supporting enrichment terms must be statistically significant,
non-generic, and satisfy `FDR <= 0.05`.

Technical/covariate and unresolved modules are not promoted to automatic
biological priorities. Auxiliary marker-rule scores and conflicts do not
determine the current canonical module decision.

## Interpretation boundaries

The output does not claim cell fractions, deconvolution, tumor-cell
specificity, patient-specific physical protein interactions, therapeutic
efficacy, or clinical actionability.

Ranks and module labels are exploratory, evidence-supported prioritization
outputs requiring independent validation.
