# Maintainer tools

The `tools/` directory contains non-routine maintenance, audit,
reproducibility, architecture-migration, and historical utilities.
These files are retained for provenance and repository maintenance;
they are not required for ordinary CancerPPIr use.

## Layout

- `audit/` — output and rulebook audits.
- `development/architecture/` — architecture extraction and comparison tools.
- `development/reproducibility/` — environment and reference-resource tools.
- `development/history/` — legacy baselines and historical checkpoints.
- `maintenance/` — focused repository maintenance scripts.

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
