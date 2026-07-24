# CancerPPIr

CancerPPIr is an R workflow for patient-specific protein-protein interaction
(PPI) subnetwork profiling from bulk RNA-seq-derived gene tables. It maps gene
symbols to STRING protein identifiers, reconstructs a STRING-derived network,
calculates topology metrics, detects deterministic Louvain modules, builds a
canonical biological-evidence layer, and exports ranked protein and module
priorities with audit-ready provenance.

CancerPPIr is a hypothesis-generation workflow. It does not establish
therapeutic efficacy, druggability, tumor-cell dependency, or clinical
actionability by itself.

## What the workflow does

1. Reads a differential-expression table.
2. normalizes HGNC symbols and audits identifier changes;
3. maps genes to STRING v12 protein identifiers;
4. reconstructs a thresholded STRING-derived PPI subnetwork;
5. calculates node topology and a five-component exploratory candidate score;
6. detects deterministic Louvain modules;
7. performs offline enrichment from locally cached STRING v12 resources;
8. assigns canonical module evidence from marker and statistically significant
   enrichment support;
9. filters automatic priorities by entity and module eligibility;
10. writes analytical, technical, network, manifest, and checksum outputs.

## Requirements and installation

The repository contains an `renv.lock` file. The reproducible installation path
is:

```r
install.packages("renv")
renv::restore()
```

Run commands from the repository root. STRING resources are stored in a cache
folder supplied at run time and are not committed to the repository.

## Input contract

The input is a delimited text file with three required variables:

| Canonical variable | Meaning |
|---|---|
| `gene` | HGNC gene symbol |
| `logFC` | log-fold change |
| `pvalue` | p-value, adjusted p-value, or FDR supplied by the user |

Recognized alternatives include `gene_symbol`, `symbol`, `log2FC`,
`log2FoldChange`, `pval`, `padj`, `adj_pvalue`, and `fdr`. When no recognized
headers are found, CancerPPIr treats the first three columns as `pvalue`,
`logFC`, and `gene`, in that order.

Minimal example:

```csv
pvalue,logFC,gene
0.00012,2.31,PTPRC
0.00450,1.74,CXCL9
0.01800,-1.26,COL1A1
```

A synthetic, non-patient example is provided in
[`examples/minimal_input.csv`](examples/minimal_input.csv).

## Command-line use

Display the current CLI contract:

```bash
Rscript cancerppir.R --help
```

Run an analysis:

```bash
Rscript cancerppir.R examples/minimal_input.csv results string_cache 400 30 TRUE
```

Arguments:

| Position | Argument | Description |
|---:|---|---|
| 1 | `input.csv` | input gene table |
| 2 | `results_dir` | root results directory |
| 3 | `string_cache` | local STRING cache directory |
| 4 | `score_threshold` | optional STRING combined-score threshold; default `400` |
| 5 | `top_n` | optional number of candidates in the evidence table; default `30` |
| 6 | `run_enrichment` | optional local enrichment switch; default `TRUE` |

The case folder is derived from the input basename. For example,
`examples/minimal_input.csv` is written to `results/minimal_input/`.

## R use

```r
source("R/load_all.R")
load_cancerppir_modules(project_root = ".", envir = .GlobalEnv)

result <- run_cancerppir(
  input_file = "examples/minimal_input.csv",
  results_root = "results",
  cache_dir = "string_cache",
  score_threshold = 400L,
  top_n = 30L,
  run_enrichment = TRUE
)
```

`result` is a `cancerppir_result` object with separate network, biological
evidence, priorities, reports, provenance, file inventory, mapping, and
compatibility sections.

## Output files

Every successful run writes six principal files:

| File | Primary use |
|---|---|
| `CancerPPIr_Analytical_Report.xlsx` | concise human-readable interpretation layer |
| `CancerPPIr_Technical_Report.xlsx` | complete mapping, metrics, enrichment, evidence, and session audit |
| `Network_for_Cytoscape.graphml` | canonical annotated network for Cytoscape or Gephi |
| `STRING_links.txt` | current and STRING v12-pinned inspection links |
| `CancerPPIr_Output_Manifest.json` | machine-readable provenance and output inventory |
| `CancerPPIr_Output_Checksums.sha256` | SHA-256 integrity verification |

The analytical workbook has exactly six sheets, in this order:

1. `Executive summary`
2. `Final priorities`
3. `Module priorities`
4. `Candidate evidence`
5. `Network overview`
6. `Methods and limitations`

Start with the analytical workbook. Use the technical workbook and manifest to
audit how a result was produced.

## Candidate and module interpretation

`candidate_score` is an exploratory within-network ranking that combines
normalized degree, betweenness, log-transformed stress centrality, absolute
`logFC`, and `-log10(pvalue)`. Its five components are exposed in `Candidate
evidence` and GraphML.

Automatic final priorities require both:

- a review-ready entity classification; and
- a biological module that passes confidence, conflict, and significant-evidence
  checks.

A high candidate rank is not proof of therapeutic actionability. Read protein
rank together with module context, eligibility, warning fields, pathology, and
independent molecular or clinical evidence.

## Offline STRING resources

CancerPPIr uses pinned local STRING v12 resources for network construction and
enrichment. The first environment setup may require downloading large files;
subsequent runs reuse the cache. Standard manifests record cache basenames and
sizes without re-reading multi-gigabyte resources solely to hash them.

## Reproducibility

The JSON manifest records schema versions, input SHA-256, Git metadata when
available, R and package versions, analysis parameters, run summary, and SHA-256
values for the four principal analysis outputs. The checksum file also hashes
the manifest.

See:

- [Output interpretation guide](docs/output_interpretation_guide.md)
- [Annotation rules](docs/annotation_rules.md)
- [Clinical interpretation guide](docs/clinical_interpretation_guide.md)
- [Clinical and analytical limitations](docs/limitations.md)
- [Glossary](docs/glossary.md)
- [Reproducibility guide](docs/reproducibility_guide.md)
- [Phase 4 migration guide](docs/phase4_migration_guide.md)
- [Documentation index](docs/README.md)

## Responsible use

Bulk RNA-seq profiles combine malignant and non-malignant specimen components.
STRING edges are database-derived associations, not patient-specific physical
interaction measurements. CancerPPIr results must be integrated with pathology,
tumor purity, genomic alterations, protein-level evidence, druggability,
experimental models, and clinical literature before translational conclusions
are made.
