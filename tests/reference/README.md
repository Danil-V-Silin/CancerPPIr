# CancerPPIr reference data

This directory stores the public regression metadata for the
preserved CancerPPIr legacy implementation.

The full baseline includes A01, K01, L01, M01, P01, P02 and R01.
`Genes_Ar.csv` and `Genes_A2r.csv` are excluded.

Per-case directories contain only:

- `artifact_manifest.csv` — sizes and checksums of external artifacts;
- `network_summary.csv` — aggregate network properties and GraphML
  read-back status.

Detailed patient-specific input data, workbook sheet exports, XLSX
files, GraphML files and STRING cache resources are stored outside
the public Git repository.

See `BASELINE_SCOPE.md` and `KNOWN_LEGACY_ISSUES.md`.
