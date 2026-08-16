# Changelog

All notable changes to CancerPPIr are documented in this file.

CancerPPIr follows Semantic Versioning.

## [Unreleased]

## [1.1.0] - 2026-08-16

### Added

- Added a STRING-traceable analytical module summary with module size, primary
  STRING source and term identifier, FDR, supporting genes, secondary terms,
  and representative module proteins.
- Added an explicit biological-evidence curation contract and strengthened
  provenance reporting for rule-based auxiliary evidence.

### Changed

- Made significant non-generic local STRING v12 enrichment the canonical
  biological evidence for automatic module interpretation while retaining
  curated marker rules as an auxiliary audit layer.
- Curated cross-axis rule redundancies without converting the rulebook into an
  independent expert oncology system.
- Rebalanced `candidate_score` across three equally weighted evidence domains:
  network topology, differential-expression magnitude, and statistical
  evidence. The topology domain is the mean of normalized degree,
  betweenness, and log-transformed stress centrality.
- Preserved the five normalized base candidate-score components as separately
  auditable output fields.
- Advanced the Analytical Workbook schema to `2.0.0` and made module
  interpretation directly traceable to STRING evidence.
- Clarified the distinct roles of the current and STRING v12-pinned browser
  links in `STRING_links.txt`, including the version-consistent inspection
  purpose of the pinned link and the 300-protein browser-link limit.
- Replaced contradictory STRING resource behavior with a unified cache-first
  model: required STRING v12.0 resources are reused when valid and downloaded
  into the cache when missing or invalid; network construction and enrichment
  then execute locally from the cached resources.
- Removed the obsolete online STRING/g:Profiler enrichment-validation path and
  its production dependency.
- Pruned the locked dependency graph after removal of the obsolete online
  enrichment path, reducing `renv.lock` without changing the retained
  qualified R/Bioconductor baseline.

### Compatibility

- CancerPPIr product version advances from `1.0.1` to `1.1.0`.
- Product versioning remains independent from public output-schema versioning.
- The Analytical Workbook schema advances to `2.0.0`; the other public
  output-schema versions remain at their existing versions.
- Candidate rankings can differ from v1.0.1 because the candidate-score
  aggregation semantics changed from five equally weighted base components to
  three equally weighted evidence domains.
- STRING mapping, STRING v12 network construction, and deterministic Louvain
  community detection are not changed by the candidate-score rebalancing.
- Automatic module interpretation can differ from v1.0.1 because qualifying
  STRING enrichment is now the canonical biological evidence source.

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
