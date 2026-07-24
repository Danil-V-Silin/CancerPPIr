# CancerPPIr legacy regression baseline

This directory records the behavior of the preserved CancerPPIr
implementation before architectural refactoring.

## Reference cases

The baseline includes A01, K01, L01, M01, P01, P02 and R01.

`Genes_Ar.csv` and `Genes_A2r.csv` are excluded.

## Strict deterministic invariants

Across two independent runs:

- all seven analyses completed successfully;
- all four expected artifacts were created for every case;
- normalized `STRING_links.txt` content was identical;
- GraphML node and edge counts were identical;
- input and STRING-resource checksums were unchanged.

The following workbook sheets were identical in all seven cases:

- `Degree distribution`;
- `Alias corrections`;
- `Gene status`;
- `Genes used table`;
- `HGNC normalization`;
- `Mapping summary`;
- `Raw candidate enrichment`;
- `Raw network enrichment`;
- `Session info`;
- `Top candidate enrichment`;
- `Top network enrichment`;
- `Unmapped genes`;

These outputs form the strict regression core.

## Partially stable outputs

The following sheets changed in some, but not all, cases:

- `Executive summary` — changed in 6 of 7 cases;
- `Top degree` — changed in 5 of 7 cases;

They must not be treated as strict checksum invariants.

## Stochastic or module-dependent outputs

Louvain community detection is not executed with an explicit random
seed in the preserved legacy implementation.

The following sheets changed in all seven cases:

- `All modules`;
- `Candidate rationale`;
- `Final priorities`;
- `Graph summary`;
- `Major module priorities`;
- `Top betweenness`;
- `Top candidates`;
- `Top stress`;
- `Raw all modules`;
- `Raw major modules`;
- `Raw module enrichment`;
- `Raw node metrics`;
- `Top module enrichment`;

Differences include module assignments, module counts, functional
labels and module-enrichment row counts.

## Regression criteria

The strict regression core requires:

- successful execution;
- identical input and STRING resources;
- identical STRING interaction content;
- identical network node and edge counts;
- identical strict deterministic sheets;
- presence of all required workbook sheets and columns.

Exact Louvain module identifiers and module-dependent labels are not
strict invariants of the legacy implementation.

## GraphML limitation

GraphML read-back fails for: K01, M01, P01.

The raw GraphML files are retained outside Git in the external
baseline output directory. Their checksums, sizes, structural counts
and read-back status are recorded in this repository.

The refactored exporter must sanitize `Inf`, `-Inf`, `NaN` and
unsupported numerical values and pass an igraph read-back test.

## Public repository contents

Detailed patient-specific workbook exports are not stored in Git.
The repository contains only aggregate summaries, schemas, dimensions,
checksums and determinism manifests.
