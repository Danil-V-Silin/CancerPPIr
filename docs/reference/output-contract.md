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

## Analytical workbook

The analytical workbook contains exactly six sheets in this order:

1. `Executive summary`
2. `Final priorities`
3. `Module priorities`
4. `Candidate evidence`
5. `Network overview`
6. `Methods and limitations`

## Technical workbook

The technical workbook retains complete mapping, topology, enrichment,
biological-evidence, validation, and runtime audit tables. The `Mapping summary`
sheet also records the scientific input-contract schema, selected source
headers, logFC and p-value semantics, validation policies and zero-p-value
count. The same contract is serialized under `analysis.input_contract` in the
JSON manifest. The five canonical
biological-evidence sheets use these descriptive names:

1. `Module annotations`
2. `Rule evidence`
3. `Significant terms`
4. `Node annotations`
5. `Validation`

## Compatibility boundary

Changes to required filenames, workbook sheets or required columns, GraphML
fields, manifest structures, schema versions, or checksum behavior are
compatibility-sensitive. Versioned details are maintained under
`docs/reference/contracts/`.
