# Release-validation contract

## Purpose

The release qualification is the single production qualification gate for a
CancerPPIr release candidate. It runs repository preflight checks, one complete
unit-test suite, and one seven-case production regression.

## Command

```text
Rscript scripts/run_release_qualification.R INPUT_DIR OUTPUT_DIR STRING_CACHE run-pipeline run-tests
```

`OUTPUT_DIR` must be new or empty in `run-pipeline` mode. Existing validated
outputs can be checked with `validate-existing` and `skip-tests`.

## Clinical regression set

The fixed release set contains:

- A01 (`Genes_A.csv`)
- K01 (`Genes_K.csv`)
- L01 (`Genes_L.csv`)
- M01 (`Genes_M.csv`)
- P01 (`Genes_P01.csv`)
- P02 (`Genes_P02.csv`)
- R01 (`Genes_R.csv`)

Clinical regression inputs are maintained outside the public repository.

## Required case outputs

Each case must contain:

- `CancerPPIr_Analytical_Report.xlsx`
- `CancerPPIr_Technical_Report.xlsx`
- `Network_for_Cytoscape.graphml`
- `STRING_links.txt`
- `CancerPPIr_Output_Manifest.json`
- `CancerPPIr_Output_Checksums.sha256`

## Repository preflight

The qualification requires all static release, documentation, publication
readiness, reproducible-environment, repository-quality, and CLI checks to pass
before the seven-case run begins.

## Release evidence

The output root contains:

- `release_summary.csv`
- `release_case_summary.csv`
- `release_validation.csv`
- `release_preflight_validation.csv`
- `release_unit_tests.log`
- `release_multicase.log`

The successful terminal result is:

```text
CANCERPPIR RELEASE QUALIFICATION: PASSED
```

## Acceptance rule

Qualification passes only when all seven cases complete, every required output
and checksum validates, expected network/module regression counts match, and no
repository or case validation row has status `FAIL`.
