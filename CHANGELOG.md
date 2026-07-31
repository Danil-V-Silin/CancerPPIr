# Changelog

All notable changes to CancerPPIr are documented in this file.

CancerPPIr follows Semantic Versioning.

## [Unreleased]

### Changed
- Corrected the executable scientific-input validator to resolve the
  repository root from its `scripts/` location, with subprocess regression
  coverage for direct command-line execution.
- Pinned the CRAN repository to the 2026-07-20 snapshot, removed the CI
  repository override, and added an executable reproducible-environment
  contract to routine and release validation.
- Enforced a versioned scientific input contract: explicit headers, raw
  differential-expression p-values, base-2 tumor-versus-reference logFC,
  complete finite values, bounded p-values, unique gene symbols and no
  positional fallback.
- Required all five candidate-score components to be finite; incomplete
  component rows now fail instead of being averaged with a variable
  denominator.
- Recorded input semantics, source headers and validation policies in the
  technical mapping summary and JSON manifest.
- Replaced internal development-stage identifiers with semantic source names.
- Renamed the release gate to `run_release_qualification.R`.
- Removed superseded architecture records, pre-refactor executable
  snapshots, and unverified clinical example data from the supported tree.
- Retained the public version and all qualified analytical output schemas at
  `1.0.0`.

### Compatibility
- The five-component candidate-score formula and equal weighting are unchanged,
  but incomplete component rows are no longer permitted.
- STRING mapping rules, Louvain configuration, biological-evidence rules,
  workbook sheet names, GraphML fields, manifest schema versions and public
  output filenames remain unchanged.

## [1.0.0] - 2026-07-27
### Added
- Reproducible `renv` environment.
- Modular R implementation with an explicit loader.
- Deterministic Louvain module detection.
- Canonical biological-evidence and priority-eligibility layers.
- Analytical and technical workbooks.
- GraphML, output manifest, provenance, and SHA-256 checksums.
- Windows and Ubuntu continuous integration.
- Unit, CLI, edge-case, static-contract, publication-readiness, and seven-case
  release validation.
- Public documentation, contribution guidance, citation metadata, and release
  governance.
- Workbook-duplication audit utility.

### Changed

- Consolidated repository layout and replaced roadmap-numbered public paths and
  user-visible labels with semantic names.
- Normalized first-public-release schema versions to `1.0.0`.
- Added strict command-line validation for integer, Boolean, and argument-count
  inputs.
- Renamed canonical technical-workbook evidence sheets to descriptive names.
- Separated user documentation, reference contracts, development records, and
  maintenance tools.

### Compatibility

The stable-release metadata changes do not alter STRING mapping, network
construction, Louvain membership, candidate scoring, biological evidence,
priority eligibility, or the qualified public output schemas.
