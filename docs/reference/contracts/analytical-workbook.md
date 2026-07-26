# Phase 4.5 analytical workbook contract

Schema version: `4.5.0`

## Scope

This contract defines the stable human-readable CancerPPIr analytical workbook.
The complete mapping, node, module, enrichment and validation audit remains in
`CancerPPIr_Technical_Report.xlsx`.

The analytical workbook is generated from the deterministic Phase 4 biological
evidence engine. Legacy module-label fields are not analytical evidence.

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

Ordering is deterministic: confidence, module size, best supporting FDR and
module identifier.

### Candidate evidence

The sheet contains the top `top_n` proteins by the deterministic full-network
candidate order, plus any Final priorities not already present. Special or
predicted loci remain visible with their eligibility status and warning.

## Candidate score transparency

The workbook exposes the five normalized score components:

- degree
- betweenness
- `log1p(stress_centrality)`
- absolute `logFC`
- `-log10(pvalue)`

Their row mean must reconstruct `candidate_score` within floating-point
tolerance.

## Biological evidence policy

Only the Phase 4 evidence-engine fields are used for analytical biological
context. Supporting enrichment terms must be:

- statistically significant;
- non-generic;
- `FDR <= 0.05`.

Technical/covariate, mixed-conflict and unresolved modules are not promoted to
automatic biological priorities.

## Interpretation boundaries

The output does not claim:

- cell fractions or deconvolution;
- tumor-cell specificity;
- patient-specific physical protein interactions;
- therapeutic efficacy;
- clinical actionability.

Ranks and module labels are exploratory, evidence-supported prioritization
outputs requiring independent validation.

## Compatibility boundary

During Phase 4.5:

- the technical workbook remains complete;
- GraphML generation remains unchanged;
- STRING links remain unchanged;
- legacy in-memory reporting objects remain available for compatibility;
- the new six-sheet tables are returned as `analytical_report_tables`;
- validation results are returned as `analytical_report_validation`.
