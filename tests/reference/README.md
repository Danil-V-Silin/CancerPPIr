# CancerPPIr reference data

This directory stores public aggregate regression metadata for the
pre-refactor reference implementation and the seven qualified cases A01, K01,
L01, M01, P01, P02, and R01. `Genes_Ar.csv` and `Genes_A2r.csv` are excluded.

Per-case directories contain only:

- `artifact_manifest.csv` — sizes and checksums of external artifacts;
- `network_summary.csv` — aggregate network properties and GraphML read-back
  status.

Detailed patient-specific inputs, workbook exports, XLSX files, GraphML files,
and STRING cache resources are stored outside the public repository. Current
resource manifests are under `resources/`.

See `BASELINE_SCOPE.md` and `KNOWN_BASELINE_LIMITATIONS.md`.
