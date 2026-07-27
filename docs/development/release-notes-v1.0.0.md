# CancerPPIr 1.0.0

Release date: 2026-07-27.

CancerPPIr 1.0.0 is the first stable public release of the workflow.

## Included

- patient-specific STRING-derived PPI subnetwork reconstruction;
- deterministic Louvain modules;
- five-component exploratory candidate ranking;
- canonical biological-evidence and eligibility layers;
- analytical and technical Excel reports;
- GraphML, manifest, provenance, and SHA-256 checksums;
- reproducible `renv` environment;
- Windows and Ubuntu continuous integration;
- strict CLI and publication-readiness validation;
- semantic repository layout and research-software citation metadata.

## Release qualification

- the final seven-case release checkpoint passed on the accepted code;
- all fourteen analytical and technical workbooks were audited for exact
  duplication, with zero `FAIL` findings;
- dependency restoration, the unit and CLI suite, and a minimal smoke run
  passed in a clean clone outside the development working tree;
- no analytical behavior or public output schema was changed after the
  accepted seven-case qualification.

Clinical input data and patient-specific output files are not included in the
public software release.

## Responsible use

CancerPPIr is a hypothesis-generation workflow. Its output does not establish
therapeutic efficacy, druggability, tumor-cell dependency, or clinical
actionability.
