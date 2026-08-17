# CancerPPIr

[![R tests](https://github.com/Danil-V-Silin/CancerPPIr/actions/workflows/r-tests.yml/badge.svg)](https://github.com/Danil-V-Silin/CancerPPIr/actions/workflows/r-tests.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
![Version](https://img.shields.io/badge/version-1.1.1-blue)

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
2. Normalizes HGNC symbols and audits identifier changes.
3. Maps genes to STRING v12 protein identifiers.
4. Reconstructs a thresholded STRING-derived PPI subnetwork.
5. Calculates node topology and a five-component exploratory candidate score.
6. Detects deterministic Louvain modules.
7. Performs local enrichment from version-pinned STRING v12 resources cached on disk.
8. Builds canonical module interpretation from statistically significant local
   STRING enrichment; curated marker-rule evidence is retained as an auxiliary
   audit layer.
9. Filters automatic priorities by entity and module eligibility.
10. Writes analytical, technical, network, manifest, and checksum outputs.

## Requirements and installation

The repository contains an `renv.lock` file. The reproducible installation path
is:

```r
install.packages("renv")
renv::restore()
```

The lockfile uses a date-pinned CRAN snapshot and CI rejects repository
overrides. See the [reproducible environment contract](docs/reference/contracts/reproducible-environment.md).

Run commands from the repository root. STRING resources are stored in a cache
folder supplied at run time and are not committed to the repository.

See the [installation guide](docs/user-guide/installation.md) for details.

## Input contract

CancerPPIr applies a strict scientific contract before network construction:

| Canonical variable | Required meaning |
|---|---|
| `gene` | HGNC gene symbol |
| `logFC` | Base-2 log fold change for tumor specimen / reference condition |
| `pvalue` | Raw differential-expression p-value for the same model and contrast |

Positive `logFC` means higher expression in the tumor specimen than in the
reference condition. Recognized aliases include `gene_symbol`, `symbol`,
`hgnc_symbol`, `log2FC`, `log2FoldChange`, `pval`, `raw_pvalue`, and
`raw_pval`. Positional fallback is disabled. Missing, non-finite, out-of-range
or duplicate values fail before HGNC normalization. Adjusted p-values, FDR and
q-values are not accepted as substitutes for the canonical raw `pvalue`.

Minimal example:

```csv
pvalue,logFC,gene
0.00012,2.31,PTPRC
0.00450,1.74,CXCL9
0.01800,-1.26,COL1A1
```

A synthetic, non-patient example is provided in
[`examples/minimal_input.csv`](examples/minimal_input.csv). See the
[scientific input contract](docs/reference/input-contract.md) for the complete
validation and provenance rules.

## Command-line use

Display the executable CLI contract:

```bash
Rscript cancerppir.R --help
Rscript cancerppir.R --version
```

Run an analysis:

```bash
Rscript cancerppir.R examples/minimal_input.csv results string_cache 400 30 TRUE --case-id DEMO01
```

| Position | Argument | Requirement |
|---:|---|---|
| 1 | `input.csv` | Delimited input gene table |
| 2 | `results_dir` | Root output directory |
| 3 | `string_cache` | Local STRING cache directory |
| 4 | `score_threshold` | Optional integer from `1` to `1000`; default `400` |
| 5 | `top_n` | Optional positive integer; default `30` |
| 6 | `run_enrichment` | Optional `TRUE` or `FALSE`; default `TRUE` |

Named option: `--case-id ID` sets a pseudonymous identifier and is recommended
for patient data. It can be supplied without positions 4-6.

With `--case-id DEMO01`, the example writes to `results/DEMO01/`.
CancerPPIr refuses to write if the selected case folder already exists. A
completed run is built in a sibling staging directory and published only after
output validation succeeds, so existing or partial results are never changed.
The original input filename is omitted from the output manifest. If `case_id`
is omitted, the legacy input-basename folder behavior remains available, with a
privacy reminder printed at startup.

See the complete [CLI contract](docs/reference/cli.md).

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
  run_enrichment = TRUE,
  case_id = "DEMO01"
)
```

`result` is a `cancerppir_result` object with separate network, biological
evidence, priorities, reports, provenance, file inventory, mapping, and
compatibility sections.

## Output files

Every successful run writes six principal files:

| File | Primary use |
|---|---|
| `CancerPPIr_Analytical_Report.xlsx` | Concise human-readable STRING-supported interpretation and prioritization layer |
| `CancerPPIr_Technical_Report.xlsx` | Complete mapping, metrics, enrichment, evidence, and session audit |
| `Network_for_Cytoscape.graphml` | Canonical annotated network for Cytoscape or Gephi |
| `STRING_links.txt` | Current and STRING v12-pinned inspection links |
| `CancerPPIr_Output_Manifest.json` | Machine-readable provenance and output inventory |
| `CancerPPIr_Output_Checksums.sha256` | SHA-256 integrity verification |

`STRING_links.txt` contains two convenience browser views of the mapped protein set.
The `current` link opens the proteins in the current STRING web interface and may
therefore change as STRING is updated. The `pinned_v12` link opens the proteins in
STRING v12.0, matching the database version pinned by CancerPPIr, and is preferred
for version-consistent STRING inspection. Because browser URL-length limits restrict
these links to the first up to 300 STRING protein IDs,
`Network_for_Cytoscape.graphml` remains the complete reconstructed network output.

The analytical workbook has exactly six sheets, in this order:

1. `Executive summary`
2. `Final priorities`
3. `Module priorities`
4. `Candidate evidence`
5. `Network overview`
6. `Methods and limitations`

The canonical biological-evidence sheets in the technical workbook are:

1. `Module annotations`
2. `Rule evidence`
3. `Significant terms`
4. `Node annotations`
5. `Validation`

Start with the analytical workbook. Use the technical workbook and manifest to
audit how a result was produced. See the
[output contract](docs/reference/output-contract.md).

## Candidate and module interpretation

`candidate_score` is an exploratory within-network ranking based on three
equally weighted evidence domains: network topology, absolute `logFC`, and
`-log10(pvalue)`. The topology domain is the mean of normalized degree,
betweenness, and log-transformed stress centrality. All five normalized base
components remain exposed in `Candidate evidence` and GraphML.

Automatic final priorities require both:

- a review-ready entity classification; and
- a biological module that passes confidence, conflict, and
  significant-evidence checks.

A high candidate rank is not proof of therapeutic actionability. Read protein
rank together with module context, eligibility, warning fields, pathology, and
independent molecular or clinical evidence.

## STRING v12 resources

CancerPPIr uses version-pinned STRING v12.0 resources for network construction
and enrichment. Resources already present in the user-supplied cache are reused.
When a required resource is absent or invalid, CancerPPIr downloads the exact
STRING v12.0 file into the cache before continuing with local computation.
Subsequent runs can reuse the cached resources without downloading them again.
Standard manifests record cache basenames and sizes without re-reading
multi-gigabyte resources solely to hash them.

## Reproducibility

The JSON manifest records public schema versions, the explicit pseudonymous
case ID when supplied, input SHA-256, Git metadata when available, R and package
versions, analysis parameters, run summary, and SHA-256 values for the four
principal analysis outputs. The checksum file also hashes the manifest.

Public output schemas are versioned independently; the current registry and
backward-compatibility rules are documented under
[schema versioning](docs/reference/schema-versioning.md).

Additional guidance:

- [Output interpretation](docs/user-guide/output-interpretation.md)
- [Annotation rules](docs/reference/annotation-rules.md)
- [Clinical interpretation](docs/user-guide/clinical-interpretation.md)
- [Clinical and analytical limitations](docs/reference/limitations.md)
- [Glossary](docs/reference/glossary.md)
- [Reproducibility](docs/user-guide/reproducibility.md)
- [Historical output-schema migration](docs/reference/schema-versioning.md)
- [Documentation index](docs/README.md)

## Citation

Citation metadata are provided in [`CITATION.cff`](CITATION.cff). GitHub renders
these metadata through **Cite this repository**. Cite the archived software
release used in the analysis and the associated article when available.

## Development and governance

Current stable version: `1.1.1`.

- [Quick start](docs/user-guide/quick-start.md)
- [Contributing](CONTRIBUTING.md)
- [Security policy](SECURITY.md)
- [Changelog](CHANGELOG.md)
- [Release process](docs/development/release-process.md)
- [Repository governance](docs/development/repository-governance.md)

CancerPPIr is distributed under the [MIT License](LICENSE).

## Responsible use

Bulk RNA-seq profiles combine malignant and non-malignant specimen components.
STRING edges are database-derived associations, not patient-specific physical
interaction measurements. CancerPPIr results must be integrated with pathology,
tumor purity, genomic alterations, protein-level evidence, druggability,
experimental models, and clinical literature before translational conclusions
are made.
