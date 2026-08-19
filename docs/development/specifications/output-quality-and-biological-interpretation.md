# Output quality and biological interpretation specification

**Status:** Current implemented contract for the supported 1.2.x release line.
**Scope:** Input semantics, biological interpretation, output architecture,
provenance, reproducibility, and publication safeguards.

Detailed normative definitions are maintained in the
[input contract](../../reference/input-contract.md),
[output contract](../../reference/output-contract.md),
[annotation rules](../../reference/annotation-rules.md), and
[schema registry documentation](../../reference/schema-versioning.md).

## Scientific and methodological boundary

CancerPPIr receives a differential-expression table containing an HGNC gene
symbol or normalizable alias, signed base-2 tumor-versus-reference `logFC`,
and a raw `pvalue` in the closed interval `[0, 1]`. Exact zero is accepted as
floating-point underflow and is floored only for a safe negative-logarithm
transformation.

The workflow does not estimate differential expression, cell fractions, cell
composition, patient-specific physical interactions, drug response, or
clinical benefit. Bulk RNA-seq evidence may originate from malignant, immune,
stromal, endothelial, or other specimen components.

## Network and candidate ranking

The workflow normalizes HGNC identifiers, maps genes to version-pinned STRING
v12 proteins, constructs a score-thresholded association network, calculates
network topology, and detects Louvain modules using a fixed seed.

Five min-max-normalized base components contribute to `candidate_score`:

1. degree;
2. betweenness;
3. `log1p(stress_centrality)`;
4. absolute `logFC`;
5. transformed raw `pvalue`.

The first three components form the topology domain. The final score is the
mean of three equally weighted evidence domains: topology, expression
magnitude, and statistical evidence. All five base components must be finite.
Scores are exploratory and comparable only within the reconstructed network.

## Canonical biological interpretation

Canonical module interpretation is derived from statistically significant,
non-generic local STRING enrichment. The default FDR threshold is `0.05`.
The qualifying term with the lowest FDR provides the primary interpretation;
up to two additional qualifying terms provide secondary context.
Benjamini-Hochberg adjustment covers all background-size-eligible terms in the
query before the minimum two-protein reporting threshold is applied.

A technical/covariate signature overrides biological priority. Modules without
qualifying enrichment remain unresolved. Supported biological modules receive
`moderate` confidence in the current database-primary adapter.

Curated marker-rule evaluations, heuristic scores, and rule-specific eligibility
remain auxiliary technical audit information. They do not determine canonical
module interpretation or automatic protein priority. Schema compatibility
fields do not imply independently resolved cellular lineages or validated
marker-based classification.

## Output architecture

Every successful case produces exactly six principal files:

- `CancerPPIr_Analytical_Report.xlsx`;
- `CancerPPIr_Technical_Report.xlsx`;
- `Network_for_Cytoscape.graphml`;
- `STRING_links.txt`;
- `CancerPPIr_Output_Manifest.json`;
- `CancerPPIr_Output_Checksums.sha256`.

The analytical workbook has exactly six ordered sheets:

1. `Executive summary`;
2. `Final priorities`;
3. `Module priorities`;
4. `Candidate evidence`;
5. `Network overview`;
6. `Methods and limitations`.

The technical workbook has 21 sheets spanning mapping, node and module
metrics, raw enrichment, canonical annotations, auxiliary rule evidence,
validation, and session information. `Raw major modules` is retained as a
documented compatibility table; it must not replace canonical module
annotations or drive analytical priorities.

`STRING_links.txt` provides a current convenience view and a version-pinned
STRING v12 view. Both are limited to the first 300 protein identifiers for
browser compatibility. GraphML remains the complete network representation.

## Provenance and compatibility

Public schemas are versioned independently in `R/schema_registry.R`. The
biological-evidence and analytical-workbook schemas are `2.0.0`; the technical-
workbook schema is `2.1.0`; the output-manifest schema is `2.2.0`; the pipeline-
result, GraphML, and output-checksum schemas remain `1.0.0`.

The manifest records run configuration, software and schema versions, input and
output hashes, and a pseudonymous case ID when explicitly supplied. Original
input filenames and absolute user paths are excluded. Existing case directories
and reports must never be overwritten; successful output is published from a
sibling staging directory after validation.

## Acceptance and publication gates

A releasable change must preserve or explicitly version its public contracts,
pass unit and CLI tests on Windows and Ubuntu, and pass documentation,
repository-quality, reproducibility, publication, and whitespace checks.

The exact final release commit requires one complete seven-case qualification,
an audit of all 14 analytical and technical workbooks, documented resolution of
material duplication findings, and privacy-safe public release evidence.
Previously published product-version tags remain immutable unless a confirmed
data-governance incident requires a separately approved remediation process.

## Methodological references

1. Dai Y, Guo S, Pan Y, et al. A guide to transcriptomic deconvolution in
   cancer. *Nature Reviews Cancer*. 2026;26:84-103.
   doi:10.1038/s41568-025-00886-9.
2. Guo S, Liu X, Cheng X, et al. A deconvolution framework that uses
   single-cell sequencing plus a small benchmark data set for accurate analysis
   of cell type ratios in complex tissue samples. *Genome Research*.
   2025;35:147-161. doi:10.1101/gr.278822.123.
