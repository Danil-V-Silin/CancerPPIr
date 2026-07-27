# Changelog

All notable changes to CancerPPIr are documented in this file.

CancerPPIr follows Semantic Versioning.

## [Unreleased]

No unreleased changes.

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
