# CancerPPIr 1.2.0

Release date: 2026-08-19.

CancerPPIr 1.2.0 is the publication-hardening release for scientific,
provenance, schema, and release-integrity contracts.

## Scientific correctness

Local STRING enrichment calculates hypergeometric p-values for all terms that
meet the background-size bounds and applies Benjamini-Hochberg adjustment to
that complete query-level family. The minimum two-protein support threshold is
applied only after adjustment for reporting and automatic interpretation.

When multiple validated input rows map to the same STRING protein, CancerPPIr
selects one row deterministically by minimum raw p-value, maximum absolute
logFC, and earliest validated input row. Collision counts and the policy are
recorded in the technical workbook and output manifest.

## Provenance and release integrity

Output-manifest schema `2.2.0` records the CancerPPIr product version. Final
release qualification requires every manifest to match the current product
version, exact 40-character Git commit, clean source tree, and SHA-256 of the
corresponding current input file.

## Public schemas

- Pipeline result: `1.0.0`
- Biological evidence: `2.0.0`
- Analytical workbook: `2.0.0`
- Technical workbook: `2.1.0`
- GraphML: `1.0.0`
- Output manifest: `2.2.0`
- Output checksums: `1.0.0`

Manifest schemas `1.0.0`, `2.0.0`, and `2.1.0` remain readable for historical
validation. Only schema `2.2.0` can satisfy the CancerPPIr 1.2.0 release gate.

## Compatibility

Corrected FDR values can change automatic module labels, module eligibility,
and final candidate eligibility. Network nodes, edges, STRING combined-score
thresholding, deterministic unweighted Louvain membership, and the candidate-
score formula are not intentionally changed.

## Release qualification

Publication requires one complete seven-case qualification on the exact final
clean commit, followed by review of all 14 workbooks. Clinical inputs, input
fingerprints, case-level summaries, and patient-level outputs remain excluded
from the public release archive.

## Responsible use

CancerPPIr remains a hypothesis-generation workflow and is not a clinical
decision-support system.
