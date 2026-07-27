# Active scripts

The `scripts/` directory contains supported project-level commands. Run them
from the repository root.

## Routine validation

- `run_unit_tests.R` — complete unit and CLI test suite.
- `run_smoke_test.R` — single-case smoke validation.
- `validate_documentation_contract.R` — documentation contract.
- `validate_release_contract.R` — static release contract.
- `validate_publication_readiness.R` — publication metadata and public-contract
  audit.

## Release qualification

- `run_release_checkpoint.R` — final seven-case release gate.
- `validate_multicase_outputs.R` — multicase output validation.
- `validate_multicase_annotation_adapter.R` — annotation-adapter validation.
- `validate_multicase_biological_evidence.R` — biological-evidence validation.
- `validate_multicase_technical_exports.R` — technical-export validation.
- `validate_a01_technical_evidence_export.R` — focused A01 export validation.

The seven-case release checkpoint is intentionally not part of routine unit
testing. Maintainer-only migration and historical utilities are under
[`tools/`](../tools/README.md).
