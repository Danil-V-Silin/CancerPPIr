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

## STRING inspection links

`STRING_links.txt` provides two convenience views of the mapped protein set.
The `current` link opens the current STRING web interface and can change after
database updates. The `pinned_v12` link opens STRING v12.0, matching the database
version pinned by CancerPPIr, and is the preferred link for version-consistent
STRING inspection. Both browser links are limited to the first up to 300 STRING
protein IDs to avoid URL-length limits; `Network_for_Cytoscape.graphml` contains
the complete reconstructed network.

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
headers, logFC and p-value semantics, validation policies, zero-p-value count,
and post-mapping STRING collision counts and selection policy. The scientific
input contract is serialized under `analysis.input_contract`; collision
metadata are serialized under `input` in the JSON manifest. The five canonical
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
