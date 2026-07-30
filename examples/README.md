# CancerPPIr examples

## Synthetic minimal input

`minimal_input.csv` is a small synthetic table used to demonstrate the input
contract. It contains no patient identifiers, does not reproduce any clinical
case, and is not intended to produce a publication-ready biological
interpretation. It follows the strict scientific input contract: `pvalue` is
a raw differential-expression p-value, `logFC` is a base-2 tumor-versus-
reference fold change, all values are complete and finite, and each gene symbol
is unique.

Run from the repository root:

```bash
Rscript cancerppir.R examples/minimal_input.csv results string_cache 400 30 TRUE
```

Expected case directory:

```text
results/minimal_input/
```

Expected files:

```text
CancerPPIr_Analytical_Report.xlsx
CancerPPIr_Technical_Report.xlsx
Network_for_Cytoscape.graphml
STRING_links.txt
CancerPPIr_Output_Manifest.json
CancerPPIr_Output_Checksums.sha256
```

The repository does not version generated example outputs. Binary workbooks and
GraphML can become stale when public schemas change and should be generated from
the current code and local STRING resources. Clinical regression inputs are
maintained outside the public repository.
