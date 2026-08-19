# Active scripts

The `scripts/` directory contains supported project-level commands. Run them
from the repository root.

## Scientific input preflight

```bash
Rscript scripts/validate_input_contract.R input1.csv [input2.csv ...]
```

This fast gate validates the strict scientific input contract without loading
STRING resources or running network analysis.

## Routine validation

Use the unified quality interface from the repository root:

```bash
Rscript scripts/run_quality_checks.R fast
Rscript scripts/run_quality_checks.R full
```

`fast` runs static, reproducibility, publication and CLI checks without
unit tests or production cases. `full` adds the complete unit-test suite but
still does not run the seven-case production regression.

Individual commands remain available for focused diagnosis:

- `run_unit_tests.R` — complete unit and CLI test suite.
- `run_smoke_test.R` — single-case smoke validation.
- `validate_documentation_contract.R` — documentation contract.
- `validate_reproducibility_contract.R` — pinned software-environment contract.
- `validate_release_contract.R` — static release contract.
- `validate_publication_readiness.R` — publication metadata and public-contract
  audit.
- `validate_repository_quality.R` — repository and CI hygiene gate.

## Release qualification

- `run_release_qualification.R` — final seven-case release gate.
- `validate_multicase_outputs.R` — multicase output validation.
- `validate_multicase_technical_exports.R` — technical-export validation.
- `validate_a01_technical_evidence_export.R` — focused A01 export validation.

The seven-case release qualification is intentionally not part of routine unit
testing. Non-routine audit and reproducibility utilities are under
[`tools/`](../tools/README.md).
