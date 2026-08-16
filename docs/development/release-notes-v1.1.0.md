# CancerPPIr 1.1.0

Release date: 2026-08-16.

CancerPPIr 1.1.0 is a minor release that refines biological module
interpretation, candidate prioritization, and STRING resource handling while
preserving the workflow's role as a reproducible hypothesis-generation layer.

## Added

- STRING-traceable module summaries in the Analytical Workbook, including the
  primary STRING source, term identifier, FDR, supporting genes, secondary
  terms, and representative proteins;
- an explicit biological-evidence curation contract and strengthened evidence
  provenance.

## Changed

- significant non-generic local STRING v12 enrichment is now the canonical
  evidence source for automatic module interpretation;
- curated marker rules remain available as an auxiliary evidence and audit
  layer rather than overriding qualifying STRING evidence;
- cross-axis redundancies in the biological-evidence rulebook were curated;
- `candidate_score` now gives equal aggregate weight to three evidence
  domains: network topology, differential-expression magnitude, and
  statistical evidence;
- the topology domain summarizes normalized degree, betweenness, and
  log-transformed stress centrality;
- all five normalized base scoring components remain separately exposed for
  transparency and reconstruction;
- STRING v12 resource acquisition follows a consistent cache-first model;
- the obsolete online STRING/g:Profiler enrichment-validation path and its
  unused dependencies were removed;
- STRING browser-link documentation now distinguishes current and v12-pinned
  inspection links.

## Analytical Workbook schema

The Analytical Workbook schema advances to `2.0.0`.

Module summaries are now explicitly traceable to the underlying STRING
evidence through source/category, term identifier, FDR, supporting genes,
secondary terms, and representative proteins.

Product versioning remains independent from public output-schema versioning.

## Candidate-score compatibility

The v1.1.0 candidate score is not numerically backward-equivalent to v1.0.1.

The five normalized base components remain:

1. degree;
2. betweenness;
3. log-transformed stress centrality;
4. absolute `logFC`;
5. statistical evidence derived from `-log10(pvalue)`.

Degree, betweenness, and log-stress are first averaged into the topology
domain. The final score is the arithmetic mean of topology,
differential-expression magnitude, and statistical evidence.

Consequently, candidate ranks may change relative to v1.0.1 even when the
underlying STRING network is unchanged.

## Biological interpretation compatibility

Automatic module interpretation may differ from v1.0.1 because qualifying
STRING enrichment is now the canonical evidence source. Curated marker rules
remain auxiliary and auditable.

This change does not make CancerPPIr an independent expert biological or
clinical decision system. An unresolved module remains a valid result when
database evidence is insufficient for a specific interpretation.

## Network compatibility

The candidate-score rebalancing does not alter:

- STRING identifier mapping;
- STRING v12 PPI network construction;
- retained network topology;
- deterministic Louvain community detection.

## Release qualification

Qualified publication follows the documented clean-clone release process,
including the complete seven-case release qualification on the exact final
`main` commit before the immutable release tag is created.

Clinical inputs, input fingerprints, case-level summaries, and patient-level
outputs are not included in the public release evidence archive.

## Responsible use

CancerPPIr is a hypothesis-generation workflow. Its output does not establish
therapeutic efficacy, druggability, tumor-cell dependency, or clinical
actionability.
