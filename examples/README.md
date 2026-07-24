# CancerPPIr examples

## Synthetic minimal input

`minimal_input.csv` is a small synthetic table used to demonstrate the input
contract. It contains no patient identifiers and is not intended to represent a
real tumor profile or to produce a publication-ready biological interpretation.

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
the current code and cache instead.

## Existing larger input

`input/Genes_R.csv` is retained as an existing repository example/reference
input. Use the synthetic minimal input for schema demonstrations and quick user
orientation. Neither file should be interpreted as clinical evidence without
its original study context.
