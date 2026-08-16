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
- `conflict_detected == FALSE`

Ordering is deterministic: confidence, module size, best supporting FDR, and
module identifier.

### Candidate evidence

The sheet contains the top `top_n` proteins by the deterministic full-network
candidate order, plus Final priorities not already present. Special or
predicted loci remain visible with their eligibility status and warning.

## Candidate-score transparency

The workbook exposes the five normalized score components:

- degree;
- betweenness;
- `log1p(stress_centrality)`;
- absolute `logFC`;
- `-log10(pvalue)`.

All five components must be finite. Their equal-weight row mean must reconstruct
`candidate_score` within floating-point tolerance; variable-denominator scoring
is not permitted.

## Biological-evidence policy

Only canonical biological-evidence fields are used for analytical biological
context. Supporting enrichment terms must be statistically significant,
non-generic, and satisfy `FDR <= 0.05`.

Technical/covariate, mixed-conflict, and unresolved modules are not promoted to
automatic biological priorities.

## Interpretation boundaries

The output does not claim cell fractions, deconvolution, tumor-cell
specificity, patient-specific physical protein interactions, therapeutic
efficacy, or clinical actionability.

Ranks and module labels are exploratory, evidence-supported prioritization
outputs requiring independent validation.
