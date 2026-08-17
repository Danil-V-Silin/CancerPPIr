# CancerPPIr 1.1.1

Release date: 2026-08-17.

CancerPPIr 1.1.1 is a patch release focused on scientific correctness, cache
integrity, output safety, privacy, command-line usability, and maintainability.

## Scientific correctness

Local enrichment now calculates query and background sizes only from proteins
represented in the local STRING term map. Impact audits confirmed that this
correction does not change the qualified seven-case regression set.

## Cache integrity

STRING v12 cache resources are validated against role-specific headers and
schemas. Newly downloaded gzip files receive complete validation before
publication, and malformed enrichment resources fail explicitly.

## Output safety and privacy

CancerPPIr refuses existing case-output targets and existing Excel reports.
Completed runs are published atomically from sibling staging directories.
Original input filenames are excluded from new manifests.

Manifest schema `2.1.0` records a validated pseudonymous case ID when explicitly
provided. Manifest schemas `1.0.0` and `2.0.0` remain readable for validation of
existing results.

## Usability

The CLI supports `--case-id` and `--version`, performs early path preflight,
and reports eight numbered stages with elapsed run time. Omitting `case_id`
retains legacy basename behavior with a privacy reminder.

## Maintainability

Public schema versions are defined in one central registry. Tests bootstrap the
supported modules automatically, and maintainers can use one documented quality
runner in `fast` or `full` mode.

## Compatibility

The product version advances from `1.1.0` to `1.1.1`. STRING mapping, network
construction, candidate scoring, deterministic Louvain membership, and canonical
biological interpretation are not intentionally changed. Analyses containing
proteins absent from the local STRING annotation map can receive corrected
enrichment universe sizes.

## Release qualification

Publication requires the complete seven-case qualification on the exact final
`main` commit. Clinical inputs, input fingerprints, case-level summaries, and
patient-level outputs are excluded from the public release evidence archive.

## Responsible use

CancerPPIr remains a hypothesis-generation workflow and is not a clinical
decision-support system.
