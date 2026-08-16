# Scientific input contract

CancerPPIr accepts a delimited differential-expression table only after it
passes a strict, auditable input contract. The workflow does not estimate
differential expression itself; the three canonical variables must be produced
upstream from one internally consistent statistical contrast.

## Canonical variables

| Variable | Required scientific meaning |
|---|---|
| `gene` | HGNC gene symbol |
| `logFC` | Base-2 log fold change for **tumor specimen / reference condition** |
| `pvalue` | Raw differential-expression p-value for the same model and contrast |

Positive `logFC` therefore means higher expression in the tumor specimen than
in the reference condition. Input generated with the opposite contrast must be
reoriented before CancerPPIr is run. The exact biological definition of the
reference condition remains part of the upstream study metadata and must be
reported with the analysis.

## Recognized headers

| Canonical variable | Accepted normalized aliases |
|---|---|
| `gene` | `gene`, `gene_symbol`, `symbol`, `hgnc_symbol` |
| `logFC` | `logFC`, `log2FC`, `logFoldChange`, `log2FoldChange` |
| `pvalue` | `pvalue`, `pval`, `raw_pvalue`, `raw_pval` |

Header matching is case-insensitive and ignores punctuation. Exactly one
recognized column must be present for each canonical variable.

Adjusted p-values, FDR and q-values are not accepted as substitutes for the
canonical `pvalue` variable. A table containing only `padj`, `adj_pvalue`,
`adjusted_pvalue`, `fdr` or `qvalue` fails before network construction. This
prevents candidate scores from silently mixing different statistical
quantities across runs.

## Fast preflight command

Validate one or more tables without STRING initialization or network analysis:

```bash
Rscript scripts/validate_input_contract.R input1.csv [input2.csv ...]
```

A successful run ends with `CANCERPPIR INPUT CONTRACT: PASSED`.

## Validation rules

The following conditions are enforced before HGNC normalization or STRING
mapping:

1. comma, semicolon or tab delimiter is detected explicitly;
2. all three required columns are identified by header name;
3. positional column fallback is disabled;
4. every gene symbol is present and non-empty;
5. every `logFC` and `pvalue` is numeric and finite;
6. every `pvalue` lies in the closed interval `[0, 1]`;
7. duplicate gene symbols, compared case-insensitively, are rejected;
8. invalid rows are reported by their input row numbers.

A numeric p-value of zero is accepted because differential-expression software
may emit zero after floating-point underflow. For the candidate score,
CancerPPIr floors zero to `.Machine$double.xmin` before applying `-log10` and
records the number of zero-valued rows in provenance.

## Candidate-score completeness

The exploratory candidate score retains the qualified five equal-weight
components:

1. normalized degree;
2. normalized betweenness;
3. normalized `log1p(stress centrality)`;
4. normalized absolute `logFC`;
5. normalized `-log10(pvalue)`.

All five components must be finite for every network node. CancerPPIr no longer
uses a variable-denominator mean when one component is missing; incomplete
component rows stop the run with an explicit error.

## Audit trail

The selected source headers, semantic definitions, validation policies and
zero-p-value count are recorded in:

- the `Mapping summary` sheet of `CancerPPIr_Technical_Report.xlsx`;
- `analysis.input_contract` in `CancerPPIr_Output_Manifest.json`.

No absolute input path is written to the manifest.

## Upstream reporting requirement

A publication or clinical research report must still identify the upstream
method, reference cohort or condition, normalization, statistical model,
contrast, filtering rules and multiple-testing procedure. The CancerPPIr input
contract verifies the table presented to the workflow; it cannot reconstruct
metadata that were never supplied by the upstream analysis.


## Scientific input semantics and candidate-score definition

The canonical input columns have the following scientific meanings:

- `gene` is a gene-level identifier expected to represent an approved HGNC gene symbol or a recognized alias that can be normalized to an approved HGNC symbol.
- `logFC` is the Base-2 log fold change obtained from the upstream differential-expression contrast. It is a signed effect-size estimate, not an expression-abundance value.
- `pvalue` is the raw differential-expression p-value supplied by the upstream statistical analysis. It must be finite and satisfy `0 < pvalue <= 1`.

Canonical column names are required, and positional column fallback is disabled. This prevents CancerPPIr from silently interpreting unrelated columns as `gene`, `logFC`, or `pvalue`.

The complete `candidate_score` is derived from five min-max-normalized base components within the analyzed network:

1. degree;
2. betweenness centrality;
3. `log1p(stress_centrality)`;
4. `abs(logFC)`;
5. `-log10(pvalue)`.

The first three components are aggregated into one topology domain as their arithmetic mean. The final `candidate_score` is the arithmetic mean of three equally weighted evidence domains: topology, absolute `logFC`, and `-log10(pvalue)`.

All five components must be finite before normalization and aggregation. The score therefore gives equal aggregate weight to network topology, differential-expression magnitude, and statistical evidence. It is an exploratory within-network ranking and is not a calibrated probability, clinical recommendation, or proof of therapeutic actionability.
