# CancerPPIr Phase 4.7 output provenance contract

## Purpose

Phase 4.7 adds a machine-readable provenance layer to every successful
CancerPPIr run. The layer records the software and schema versions, input
identity, analysis configuration, run-level summary and cryptographic hashes of
the principal output files.

The provenance layer is an audit mechanism. It does not change network
reconstruction, Louvain membership, candidate scoring, biological evidence or
the analytical workbook.

## Output files

Each successful run writes two additional files to the case output directory:

- `CancerPPIr_Output_Manifest.json`
- `CancerPPIr_Output_Checksums.sha256`

The JSON manifest contains hashes for the four principal analysis outputs:

- `CancerPPIr_Analytical_Report.xlsx`
- `CancerPPIr_Technical_Report.xlsx`
- `STRING_links.txt`
- `Network_for_Cytoscape.graphml`

The checksum file contains hashes for those four outputs and for the JSON
manifest. The checksum file deliberately omits its own hash because a file
cannot contain a stable checksum of itself without a separate external
signature mechanism.

## Schema registry

The function `cancerppir_schema_versions()` is the canonical registry for
public output contracts. Phase 4.7 pins the following versions:

| Contract | Version |
|---|---:|
| Pipeline result | 4.7.0 |
| Biological evidence | 1.0.0 |
| Analytical workbook | 4.5.0 |
| Technical workbook | 4.4.0 |
| GraphML | 4.6.0 |
| Output manifest | 1.0.0 |
| Output checksums | 1.0.0 |

A schema version changes only when a public structure or interpretation
contract changes. A Git commit is recorded separately and is not used as a
schema version.

## Manifest sections

### `software`

Records CancerPPIr identity and Git metadata when the run occurs in a Git
working tree. Git metadata is best-effort: source archives and installed copies
may legitimately report it as unavailable.

### `runtime`

Records the R version, platform, operating system and versions of core runtime
packages.

### `schemas`

Records all public schema versions from the canonical registry.

### `input`

Records only the input basename, file size, SHA-256 checksum and non-path
summary statistics. The original absolute path is excluded.

### `analysis`

Records the configuration that can influence the analysis, including STRING
version, species, score threshold, offline enrichment state, Louvain seed, FDR
threshold and candidate reporting limit. The manifest also records the basenames
and sizes of the pinned STRING cache resources. Standard runs do not re-read the
multi-gigabyte cache solely to calculate cache hashes; that performance trade-off
is stated explicitly in the manifest.

### `summary`

Records compact run-level counts, including network nodes and edges, connected
components, Louvain modules, priority-eligible modules and final priority
candidates.

### `outputs`

Records the basename, role, schema version, size and SHA-256 checksum of each
principal output.

### `privacy`

States the path-handling policy. Absolute input, project, cache, results and
output paths are not written to the manifest.

## Checksum semantics

SHA-256 is calculated from the exact bytes written to disk. It therefore
verifies file integrity, not semantic equivalence.

Binary XLSX files may receive different byte-level hashes across independent
runs because ZIP container metadata or workbook timestamps can differ even when
the visible tables are equivalent. Semantic regression testing of workbook
contents remains a separate responsibility of checkpoint scripts.

## Validation

`cancerppir_validate_output_provenance()` verifies:

1. that the manifest and checksum files exist;
2. that the JSON is readable and contains all mandatory sections;
3. that schema versions match the canonical registry;
4. that all manifest output hashes match the files on disk;
5. that the checksum file lists the principal outputs and manifest only;
6. that every checksum entry matches the corresponding file;
7. that absolute user paths are absent;
8. that the input is represented by a basename rather than a path.

Any failed provenance check stops the production pipeline before a successful
result object is returned.

## Public pipeline result

The canonical `cancerppir_result` gains:

- `result$provenance`
- `result$files$output_manifest`
- `result$files$output_checksums`

The previous canonical evidence, priorities, reports, mapping and compatibility
boundaries remain unchanged.

## Non-goals

Phase 4.7 does not:

- sign outputs with a private cryptographic key;
- guarantee that Git metadata is available outside a repository;
- compare all seven clinical cases;
- alter network topology or candidate priorities;
- replace semantic workbook or GraphML regression tests.
