# Maintainer tools

The `tools/` directory contains non-routine audit and reproducibility utilities.
These files are not required for ordinary CancerPPIr use. Superseded
architecture-extraction scripts and pre-refactor execution snapshots are kept
in Git history rather than the supported source tree.

## Layout

- `audit/` — output and biological-rulebook audits.
- `development/reproducibility/` — reference-resource capture and comparison tools.
- `maintenance/` — focused repository maintenance scripts, when present.

Supported run and validation commands remain in
[`scripts/`](../scripts/README.md).

## Workbook-duplication audit

Run:

```text
Rscript tools/audit/audit_workbook_duplication.R OUTPUT_ROOT
```

The audit does not modify workbooks. Its severities have distinct meanings:

- `FAIL` — structural duplication that is invalid independently of a clinical
  case, such as duplicate column names or two identical sheets inside one
  workbook;
- `REVIEW` — exact value equality that may be case-specific and requires human
  interpretation, including duplicate rows and identical sheets across patient
  workbooks;
- `INFO` — documented equivalence between provenance/stage fields or equality
  caused only by both columns being empty.

Different columns are not treated as structural duplicates solely because their
values happen to be equal in one clinical case.

## Reference comparison

`development/reproducibility/compare_reference_case.R` compares one candidate
case directory with a qualified external reference using the public regression
scope in `tests/reference/resources/regression_scope.csv`.
