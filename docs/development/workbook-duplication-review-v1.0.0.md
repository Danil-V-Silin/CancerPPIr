# Workbook-duplication review for CancerPPIr 1.0.0

Review date: 2026-07-27.

## Scope

The duplication audit covered fourteen workbooks generated for seven qualified
clinical cases:

- A01
- K01
- L01
- M01
- P01
- P02
- R01

The audit did not modify any workbook or recalculate any clinical case.

## Result

- Structural FAIL findings: 0
- REVIEW findings: 40
- INFO findings: 193

No duplicate column names or identical sheets within the same workbook were
detected.

## Accepted REVIEW categories

The remaining REVIEW findings were inspected and accepted for release because
they represent one of the following:

1. case-specific equality between semantically distinct fields, including:
   - `logFC` and `abs_logFC`;
   - `module_size` and `nodes_in_largest_component`;
   - `marker_label_evidence_count` and `marker_max_overlap_count`;
   - `priority_rank` and `network_candidate_rank`;
   - `in_largest_component` and `required_specific_evidence_detected`;

2. exact repeated rows restricted to the non-analytical `Session info` sheet;

3. identical non-patient-specific sheets across workbooks, including:
   - `Methods and limitations`;
   - `Session info`;
   - `Validation`.

These findings do not indicate duplicated analytical columns, loss of patient
specificity, altered network calculations, or inconsistent candidate
prioritization.

## Release decision

The REVIEW findings are accepted for CancerPPIr 1.0.0. The corrected audit
retains them as visible review records while reserving FAIL severity for
structural duplication that is invalid independently of patient data.
