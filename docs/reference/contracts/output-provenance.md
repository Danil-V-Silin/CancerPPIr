# Output provenance contract

Output-manifest schema version: `1.0.0`
Output-checksums schema version: `1.0.0`

## Purpose

Every successful CancerPPIr run records software and schema versions, input
identity, analysis configuration, run-level summary, output inventory, and
cryptographic hashes. Provenance is an audit mechanism and does not change the
analysis.

## Provenance files

Each case output directory contains:

- `CancerPPIr_Output_Manifest.json`
- `CancerPPIr_Output_Checksums.sha256`

The manifest hashes the four principal analysis outputs:

- `CancerPPIr_Analytical_Report.xlsx`
- `CancerPPIr_Technical_Report.xlsx`
- `STRING_links.txt`
- `Network_for_Cytoscape.graphml`

The checksum file lists those four outputs and the manifest. It does not list
its own hash.

## Schema registry

`cancerppir_schema_versions()` is the canonical registry. Every public schema
starts at `1.0.0` for the first public release line. A schema version changes
only when its public structure or interpretation contract changes; Git commit
identity is recorded separately.

## Manifest sections

- `software`: software version and best-effort Git metadata.
- `runtime`: R, platform, operating system, and package versions.
- `schemas`: all public schema versions.
- `input`: input basename, size, SHA-256, validated-row summary, and zero-p-value count.
- `analysis`: versioned scientific input contract, selected source headers,
  STRING version, threshold, offline enrichment, seed, FDR, top-N, and cache
  basenames and sizes.
- `summary`: network, module, and priority counts.
- `outputs`: role, schema version, size, and SHA-256 for each principal output.
- `privacy`: path-handling and cache-hashing policies.

Absolute input, project, cache, results, and output paths are excluded.

## Checksum semantics

SHA-256 verifies exact file bytes, not biological correctness. XLSX files are
ZIP containers and can differ at byte level because of internal metadata even
when visible tables are equivalent. Workbook regression therefore compares
sheet names, columns, row counts, and values separately.

## Validation

`cancerppir_validate_output_provenance()` verifies required files and sections,
schema registry equality, all recorded hashes, checksum membership, path
privacy, and basename-only input identity. A failed provenance check stops the
pipeline before a successful result is returned.
