# Scientific input contract

CancerPPIr accepts a delimited differential-expression table only after it
passes a strict, auditable input contract. The workflow does not estimate
differential expression itself; the three canonical variables must be produced
upstream from one internally consistent statistical contrast.

## Canonical variables

| Variable | Required scientific meaning |
|---|---|
| `gene` | Approved HGNC gene symbol or an alias eligible for HGNC normalization |
| `logFC` | Base-2 log fold change for **tumor specimen / reference condition** |
| `pvalue` | Raw differential-expression p-value for the same model and contrast |

The canonical `pvalue` must be a raw differential-expression p-value from the
same upstream statistical model and contrast as `logFC`.

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

## Candidate-score definition and completeness

The exploratory candidate score uses five min-max-normalized base components:

1. normalized degree;
2. normalized betweenness;
3. normalized `log1p(stress centrality)`;
4. normalized absolute `logFC`;
5. normalized `-log10(pvalue)` after zero-valued inputs are floored to
   `.Machine$double.xmin`.

The first three components are averaged into one topology domain. The final
`candidate_score` is the arithmetic mean of three equally weighted evidence
domains: topology, absolute `logFC`, and transformed statistical evidence.
The five base components therefore do not each receive the same final weight.

If a base component is constant across the network, the existing min-max
policy assigns the same normalized value of `1` to every finite node. This
uniform contribution does not change within-network ordering, but absolute
scores remain unsuitable for direct comparison across independently analyzed
networks.

All five components must be finite for every network node. Incomplete
component rows stop the run with an explicit error. The score is an exploratory
within-network ranking, not a probability, clinical recommendation, or proof of
therapeutic actionability.

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
