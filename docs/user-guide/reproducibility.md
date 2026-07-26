# Reproducibility guide

CancerPPIr separates file integrity, run provenance, and semantic regression.
All three are required for a defensible reproducible analysis.

## Files to preserve

For each run, preserve:

1. the original input table;
2. `CancerPPIr_Analytical_Report.xlsx`;
3. `CancerPPIr_Technical_Report.xlsx`;
4. `Network_for_Cytoscape.graphml`;
5. `STRING_links.txt`;
6. `CancerPPIr_Output_Manifest.json`;
7. `CancerPPIr_Output_Checksums.sha256`;
8. the compatible STRING cache release or a documented acquisition procedure.

## Verify checksums

### Windows PowerShell

From the case output directory:

```powershell
Get-Content CancerPPIr_Output_Checksums.sha256 | ForEach-Object {
  $parts = $_ -split "  ", 2
  $expected = $parts[0].Trim().ToLower()
  $file = $parts[1].Trim()
  $actual = (Get-FileHash -Algorithm SHA256 $file).Hash.ToLower()
  [pscustomobject]@{File=$file; Match=($actual -eq $expected)}
}
```

### Linux or macOS

```bash
sha256sum --check CancerPPIr_Output_Checksums.sha256
```

A checksum match proves that the received bytes equal the bytes listed when the
checksum file was created. It does not prove biological correctness.

## Read the manifest

The JSON manifest contains:

- software and Git metadata when available;
- R, platform, operating system, and package versions;
- public schema versions;
- input basename, size, SHA-256, and mapping summary;
- STRING version, threshold, enrichment mode, seed, FDR, and candidate limit;
- graph and module counts;
- output roles, sizes, schema versions, and SHA-256 values;
- privacy and cache-hashing policies.

Absolute input, cache, results, project, and output paths are excluded.

## Current schema registry

| Contract | Version |
|---|---:|
| Pipeline result | `4.7.0` |
| Biological evidence | `1.0.0` |
| Analytical workbook | `4.5.0` |
| Technical workbook | `4.4.0` |
| GraphML | `4.6.0` |
| Output manifest | `1.0.0` |
| Output checksums | `1.0.0` |

A schema version describes structure and interpretation. A Git commit identifies
source history. Record both when available.

## Byte identity versus semantic identity

Text and GraphML files are usually byte-stable when inputs, configuration, and
runtime are stable. XLSX files are ZIP containers and may differ at the byte
level because of timestamps or internal metadata.

For XLSX regression, compare:

- sheet names and order;
- column names and order;
- row counts;
- cell values with an explicit numeric tolerance.

Do not use a different XLSX SHA-256 alone as evidence that the analysis changed.

## Reproducing a run

1. Check out the recorded Git commit or use the archived source.
2. Restore dependencies from `renv.lock`.
3. Provide the same input file and verify its SHA-256.
4. Provide compatible STRING v12 cache resources.
5. use the manifest-recorded threshold, enrichment mode, seed, FDR, and top-N;
6. run CancerPPIr;
7. verify the new manifest and checksums;
8. compare semantic outputs when byte identity is not expected.

## Sharing a run

Share a case-specific archive containing the seven files listed above. Avoid
including absolute workstation paths, credentials, or unrelated clinical data.
The manifest is designed to identify the run without exposing local paths.

## Known provenance boundary

Standard runs do not hash multi-gigabyte STRING cache resources because that
would add substantial I/O to every execution. The manifest records cache
basenames and sizes and states this policy. A regulated or archival workflow may
create an external cache checksum inventory once and preserve it separately.
