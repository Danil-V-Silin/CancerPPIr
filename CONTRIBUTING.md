# Contributing to CancerPPIr

## Development model

CancerPPIr uses a lightweight GitHub Flow model:

1. Start from an up-to-date `main`.
2. Create one short-lived descriptive branch.
3. Keep one logical change per pull request.
4. Add or update tests for behavior-affecting changes.
5. Merge only after required checks pass.
6. Delete the branch after merge.

Allowed branch prefixes:

```text
feat/
fix/
refactor/
test/
docs/
chore/
release/
```

Do not use internal roadmap numbers, personal initials, or labels such as
`complete`, `final-final`, or `latest`.

## Commit and pull-request titles

Use:

```text
type(scope): imperative summary
```

Examples:

```text
fix(graphml): preserve finite p-value exports
docs(installation): clarify reproducible setup
refactor(reporting): simplify workbook assembly
test(regression): cover empty-priority outputs
```

## Compatibility-sensitive changes

Explicitly document changes to:

- CLI arguments;
- input-column recognition;
- output filenames;
- workbook sheets or required columns;
- GraphML attributes;
- manifest or checksum schemas;
- scoring, evidence, confidence, or eligibility semantics.

Do not combine a path-only refactor with an analytical behavior change.

## Validation

Run from the repository root:

```bash
Rscript scripts/run_unit_tests.R
Rscript scripts/validate_publication_readiness.R
Rscript cancerppir.R --help
```

A full seven-case regression is required when analytical behavior or a public
output contract can change. Routine documentation and path-only changes do not
require recomputing the seven clinical networks.
