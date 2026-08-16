# Changelog

All notable changes to CancerPPIr are documented in this file.

CancerPPIr follows Semantic Versioning.

## [Unreleased]

### Changed

- Clarified the distinct roles of the current and STRING v12-pinned browser
  links in `STRING_links.txt`, including the version-consistent inspection
  purpose of the pinned link and the 300-protein browser-link limit.

- Replaced the contradictory STRING resource behavior with a unified
  cache-first model: required STRING v12.0 files are reused when present and
  downloaded into the cache when missing or invalid; network construction and
  enrichment then execute locally from the cached resources.
- Removed the unreachable online STRING/g:Profiler enrichment-validation path
  and its production dependency while preserving the public output schemas.

- Pruned the locked dependency graph after removal of the obsolete online
  enrichment path, reducing `renv.lock` from 114 to 80 packages without
  changing retained package versions or the qualified R/Bioconductor baseline.

## [1.0.1] - 2026-07-31

### Added

- Added explicit release-input provenance for historical qualification fixtures,
  including the compatibility policy, removal manifest, and original/canonical
  SHA-256 records retained outside the public source tree.
- Added product-version-aware publication validation and historical-release
  metadata protection.

### Fixed

- Corrected direct execution of `scripts/validate_input_contract.R` to resolve
  the repository root from its `scripts/` location.
- Namespace-qualified tibble construction used by standalone scientific-input
  validation.
- Restored the published v1.0.0 date and its version-specific release notes.
- Removed contradictory status metadata and duplicated wording from the
  output-quality specification.

### Changed

- Pinned the CRAN repository to the 2026-07-20 snapshot, removed the CI
  repository override, and enforced the reproducible-environment contract.
- Enforced explicit scientific-input headers, raw differential-expression
  p-values, base-2 tumor-versus-reference logFC, complete finite values,
  bounded p-values, unique gene symbols, and no positional fallback.
- Required every candidate-score component to be finite; incomplete rows now
  fail instead of being averaged with a variable denominator.
- Recorded input semantics, source headers, and validation policies in the
  technical mapping summary and JSON manifest.
- Replaced internal development-stage identifiers with semantic source names
  and consolidated the supported repository layout.
- Separated release preparation from clean-clone qualification, immutable
  tagging, and GitHub Release publication.

### Compatibility

- Product version advances to `1.0.1`; every public output-schema
  version remains `1.0.0`.
- The five-component score formula, STRING mapping, network construction,
  deterministic Louvain configuration, biological-evidence rules, workbook
  sheet names, GraphML fields, manifest schemas, and public output filenames
  remain unchanged.
- Input validation is stricter than in v1.0.0; invalid or ambiguous scientific
  inputs now fail before network construction.

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
