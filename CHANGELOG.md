# Changelog

All notable changes to CancerPPIr are documented in this file.

CancerPPIr follows Semantic Versioning, including pre-release versions.

## [1.0.0-rc.1] - Unreleased

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

The publication-readiness changes do not intentionally alter STRING mapping,
network construction, Louvain membership, candidate scoring, biological
evidence, or priority eligibility. Technical-workbook sheet names and public
schema-version fields are compatibility-sensitive changes and therefore require
a fresh seven-case release qualification before publication.
