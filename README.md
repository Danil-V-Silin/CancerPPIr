# CancerPPIr

CancerPPIr is an R workflow for patient-specific protein-protein interaction (PPI) subnetwork profiling from bulk RNA-seq-derived gene tables. It maps gene symbols to STRING protein identifiers, reconstructs a STRING-derived PPI subnetwork, ranks candidate proteins by network and expression-level evidence, detects Louvain modules, and annotates major module-level biological programs.

CancerPPIr is intended for exploratory network prioritization. It does not establish therapeutic efficacy, clinical actionability, or tumor-cell-intrinsic dependency by itself.

## Workflow

CancerPPIr performs the following steps:

1. reads a gene-level table containing gene symbols, log-fold changes, and p-values;
2. normalizes gene symbols using HGNChelper;
3. maps genes to STRING v12 protein identifiers for *Homo sapiens*;
4. reconstructs a STRING-derived PPI subnetwork using a user-defined confidence threshold;
5. calculates node-level network metrics, including degree, betweenness, closeness, stress centrality, and local clustering;
6. ranks proteins using a composite candidate score based on topology, absolute logFC, and statistical evidence;
7. detects Louvain communities;
8. annotates major modules using locally cached STRING enrichment terms and curated marker-gene overlap;
9. exports analytical and technical reports, STRING network links, and an annotated GraphML network.

## Input

The input file must be a delimited text table with the following information:

| Column | Description |
|---|---|
| `gene` | HGNC gene symbol |
| `logFC` | log-fold change |
| `pvalue` | p-value, adjusted p-value, or FDR |

Common column-name variants are accepted, including `gene_symbol`, `symbol`, `log2FC`, `log2FoldChange`, `pval`, `padj`, `adj_pvalue`, and `fdr`. If column names are not recognized, CancerPPIr assumes that the first three columns are ordered as `pvalue`, `logFC`, and `gene`.

Example:

```text
pvalue,logFC,gene
0.00012,2.31,PTPRC
0.00450,1.74,CXCL9
0.01800,-1.26,COL1A1
```

## Installation

CancerPPIr requires R and the following packages:

```r
install.packages(c("HGNChelper", "igraph", "openxlsx", "dplyr", "tibble", "curl", "sna"))

if (!requireNamespace("BiocManager", quietly = TRUE)) {
  install.packages("BiocManager")
}
BiocManager::install("STRINGdb")
```

## Quick start

```bash
Rscript cancerppir.R input/Genes_R.csv results string_cache 400 30 TRUE
```

Arguments:

| Argument | Description |
|---|---|
| `input/Genes_R.csv` | input gene table |
| `results` | root output directory |
| `string_cache` | local STRING cache directory |
| `400` | STRING confidence threshold |
| `30` | number of top candidates reported in ranked tables |
| `TRUE` | run local enrichment analysis |

The output directory is created from the input filename. For example:

```text
input/Genes_R.csv -> results/Genes_R/
```

The first run may download STRING v12 files into the cache directory. Subsequent runs reuse the cached files.

## Output

CancerPPIr writes four main output files:

| File | Description |
|---|---|
| `CancerPPIr_Analytical_Report.xlsx` | main human-readable report with candidate rankings, major module priorities, and network summaries |
| `CancerPPIr_Technical_Report.xlsx` | mapping audit, raw node metrics, enrichment tables, and session information |
| `Network_for_Cytoscape.graphml` | annotated network for Cytoscape or Gephi |
| `STRING_links.txt` | current and version-pinned STRING network links |

Recommended reading order for the analytical report:

1. `Executive summary`
2. `Final priorities`
3. `Major module priorities`
4. `Candidate rationale`
5. `Graph summary`

The technical workbook is intended for reproducibility checks and audit rather than first-pass interpretation.

## Candidate score

The candidate score is an exploratory composite score calculated from normalized node degree, betweenness, log-transformed stress centrality, absolute logFC, and -log10(p-value). It is used to rank proteins within the reconstructed PPI subnetwork.

A high candidate score indicates that a protein is prominent within the patient-specific network and expression profile. It should not be interpreted as evidence of druggability or clinical response without additional validation.

## Module annotation

Major Louvain modules are annotated using two evidence layers:

- curated marker-gene overlap defined in the workflow;
- local STRING v12 enrichment terms for *Homo sapiens*.

Broad enrichment terms are not used as primary biological evidence in the analytical report. Raw enrichment results are retained in the technical workbook.

## Interpretation

CancerPPIr reports should be interpreted as hypothesis-generating network analyses. Candidate proteins and module labels should be evaluated together with histology, tumor purity, mutation status, pathway context, druggability, clinical evidence, and independent experimental or computational validation.

For bulk RNA-seq data, module-level signals may reflect malignant cells, immune cells, stromal cells, endothelial cells, or other components of the tumor specimen.

## Reproducibility

The current workflow uses STRING v12 for *Homo sapiens* and performs functional annotation in offline mode from locally cached STRING enrichment terms. The technical report records mapping, enrichment, raw node metrics, and R session information for audit.
