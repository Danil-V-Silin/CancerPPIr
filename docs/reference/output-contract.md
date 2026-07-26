# Output contract

Every successful CancerPPIr run writes six principal files:

| File | Purpose |
|---|---|
| `CancerPPIr_Analytical_Report.xlsx` | Human-readable interpretation layer |
| `CancerPPIr_Technical_Report.xlsx` | Complete analytical and reproducibility audit |
| `Network_for_Cytoscape.graphml` | Canonical annotated network |
| `STRING_links.txt` | Current and version-pinned STRING links |
| `CancerPPIr_Output_Manifest.json` | Machine-readable provenance and inventory |
| `CancerPPIr_Output_Checksums.sha256` | SHA-256 integrity verification |

The analytical workbook contains exactly six sheets in this order:

1. `Executive summary`
2. `Final priorities`
3. `Module priorities`
4. `Candidate evidence`
5. `Network overview`
6. `Methods and limitations`

Versioned details are maintained under `docs/reference/contracts/`.
Changes to required filenames, sheets, columns, GraphML fields, manifest schemas, or checksum behavior are compatibility-sensitive.
