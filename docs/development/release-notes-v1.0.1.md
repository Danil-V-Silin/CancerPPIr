# CancerPPIr 1.0.1

Release date: 2026-07-31.

CancerPPIr 1.0.1 is a patch release that hardens scientific-input
validation, reproducibility controls, release metadata, and the
qualification-before-tagging process. Public analytical schemas remain unchanged.

## Fixed

- direct execution of `scripts/validate_input_contract.R` resolves the
  repository root from the script location;
- standalone input validation uses namespace-qualified tibble construction;
- publication-readiness validation derives the active product version and
  version-specific notes from repository metadata;
- the published v1.0.0 date and release notes are preserved as historical
  metadata;
- contradictory status metadata and duplicated wording in the output-quality
  specification were corrected.

## Changed

- scientific inputs require explicit semantic headers, raw differential-
  expression p-values, finite values, bounded p-values, unique gene symbols,
  and no positional fallback;
- the reproducible environment uses a date-pinned CRAN snapshot and is enforced
  by routine and release gates;
- supported source paths use semantic names rather than development-stage
  identifiers;
- metadata preparation is separated from clean-clone qualification, immutable
  tagging, and GitHub Release publication;
- historical qualification fixtures preserve the original clinical CSV files
  while recording every compatibility transformation and checksum privately.

## Compatibility

- CancerPPIr product version is `1.0.1`;
- all public output-schema versions remain `1.0.0`;
- the five-component score formula, STRING mapping, network construction,
  deterministic Louvain configuration, biological-evidence rules, workbook
  sheet names, GraphML fields, manifest schemas, and public output filenames
  are unchanged;
- clinical inputs, input fingerprints, case-level summaries, and patient-level
  output workbooks are excluded from the public release evidence archive.

## Responsible use

CancerPPIr is a hypothesis-generation workflow. Its output does not establish
therapeutic efficacy, druggability, tumor-cell dependency, or clinical
actionability.
