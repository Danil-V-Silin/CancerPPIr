# Canonical biological annotation rules

CancerPPIr assigns module context through a deterministic evidence engine. The
purpose is to expose why an interpretation was assigned, when evidence is
conflicting, and when automatic prioritization is not justified.

## Evidence inputs

The engine evaluates each Louvain module using:

1. module membership and size;
2. curated positive and supportive marker genes;
3. statistically significant local STRING v12 enrichment terms;
4. term-supporting genes;
5. agreement or conflict across compartment, lineage, state, and process axes;
6. technical or covariate signatures that must not be promoted as biological
   priorities.

Offline STRING enrichment is the primary term layer. Generic terms are not used
as sufficient primary evidence, although raw terms remain available in the
technical workbook.

## Interpretation hierarchy

The canonical module table separates:

| Axis | Question answered |
|---|---|
| `compartment` | broad tissue or cellular context supported by evidence |
| `lineage` | lineage-associated evidence, when resolved |
| `state` | activation, response, differentiation, or other state evidence |
| `process` | biological process evidence |
| `primary_interpretation` | conservative synthesis of supported axes |
| `secondary_themes` | additional supported themes that do not replace the primary interpretation |

These fields are computational interpretations. They are not cell-fraction
estimates and do not prove tumor-cell origin.

## Interpretation classes

| Value | Meaning |
|---|---|
| `biological` | specific biological evidence is sufficient for a resolved interpretation |
| `mixed_biological` | biological evidence is present but conflicting lineage/context evidence limits automatic priority |
| `technical_or_covariate` | technical, sex-linked, ribosomal, mitochondrial, or related covariate signature; reported but not automatically prioritized |
| `unresolved` | available evidence is insufficiently specific |

## Interpretation scope

`interpretation_scope` records the strongest supported resolution. Current
values may indicate lineage support, state/process support with unresolved
lineage, mixed lineage, technical/covariate status, or unresolved evidence.

## Confidence and conflict

Confidence is derived from marker and significant-term support, specificity,
and evidence agreement. Automatic module priority requires:

- interpretation class `biological`;
- confidence `high` or `moderate`;
- at least one significant supporting term;
- no detected conflict;
- non-technical status.

`conflict_detected`, `warning`, and `evidence_rationale` must be read together.
A conflict is not silently resolved by choosing the highest-scoring label.

## Marker and enrichment fields

| Field | Meaning |
|---|---|
| `positive_marker_genes` | genes providing direct positive support for selected evidence rules |
| `supportive_marker_genes` | genes that strengthen but do not independently establish the interpretation |
| `term_supporting_genes` | module genes contributing to significant supporting terms |
| `significant_supporting_terms` | filtered significant terms retained for interpretation |
| `best_supporting_fdr` | strongest supporting FDR among retained evidence |
| `evidence_rationale` | concise trace of evidence and interpretive limits |

## Entity classification and candidate eligibility

Nodes are independently classified before automatic protein priority.

| `candidate_eligibility` | Meaning |
|---|---|
| `review_ready_canonical` | canonical or unclassified protein-coding entity eligible for automatic review when its module is also eligible |
| `network_evidence_only` | locus, predicted, pseudogene-like, or non-coding entity retained for network evidence but not automatic final priority |
| `excluded_from_automatic_priority` | mitochondrial, ribosomal, Y-associated, or related class excluded from automatic promotion |
| `manual_review_required` | entity requires explicit review before any priority claim |

Network inclusion and automatic priority are deliberately separate decisions.

## Significant-term policy

The analytical evidence layer retains only terms passing the configured FDR
threshold, currently `0.05`, and the generic-term filter. Raw enrichment is kept
in the technical workbook for reproducibility.

Absence of a resolved annotation can reflect limited marker coverage, limited
term specificity, small module size, or database coverage. It does not prove
absence of biological function.

## Priority decision boundary

Final protein priorities require:

1. a `review_ready_canonical` entity;
2. membership in a priority-eligible module;
3. no module conflict that blocks automatic promotion;
4. a valid candidate score and network rank.

The candidate score does not contribute clinical evidence. It ranks prominence
within the reconstructed network and supplied expression profile.

## Canonical and compatibility outputs

Canonical evidence is exposed through `result$biological_evidence`, the Phase 4
technical sheets, the analytical workbook, and GraphML. Retired annotation
fields are available only under `result$compatibility` for migration and audit.
They must not drive new priority decisions.

See the [Phase 4 migration guide](phase4_migration_guide.md) for the legacy-to-
canonical field map.
