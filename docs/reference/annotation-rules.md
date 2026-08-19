# Canonical biological annotation rules

CancerPPIr assigns module interpretation from statistically significant,
non-generic local STRING v12 enrichment. Curated marker-rule evaluations are
retained as an auxiliary audit layer; they do not determine canonical module
interpretation or automatic module or protein priority.

## Canonical decision inputs

For each deterministic Louvain module, the production adapter evaluates:

1. module membership and size;
2. local STRING/database enrichment terms passing the configured FDR threshold;
3. the generic-term filter and term-supporting genes;
4. independent technical or covariate signatures.

The default FDR threshold is `0.05`. Raw, non-significant, and generic terms
remain available in the technical workbook but cannot establish canonical
biological priority.

## Enrichment coverage and statistical scope

Local functional enrichment is computed only for the five largest Louvain
modules containing at least five proteins. Other modules remain available in
the network and audit outputs but can remain unresolved without having been
tested for enrichment.

Module terms are tested against the annotated case-network background using a
hypergeometric test. Benjamini-Hochberg adjustment covers all terms containing
between three and 500 annotated background proteins within each enrichment
query. A reported term requires at least two supporting proteins. The minimum
two-supporting-protein threshold is applied only after adjustment for reporting
and interpretation. Adjustment is not performed across modules or analyses.
The STRING-derived network and STRING-derived annotations are not independent
sources of evidence.

## Module decision

| Module evidence | `interpretation_class` | `confidence` | Automatic priority |
|---|---|---|---|
| Technical or covariate signature | `technical_or_covariate` | `not_applicable` | No |
| At least one qualifying non-generic enrichment term and no technical signature | `biological` | `moderate` | Yes |
| No qualifying non-generic enrichment term | `unresolved` | `unresolved` | No |

For a supported biological module, the qualifying term with the lowest FDR is
the `primary_interpretation`. Up to two additional qualifying terms are recorded
as `secondary_themes`. The rationale records term descriptions, sources, FDR
values, and interpretive limits.

`interpretation_scope` is `database_enrichment_supported`,
`technical_or_covariate`, or `unresolved`. A module without qualifying STRING
evidence remains unresolved even if an auxiliary marker rule matches.

## Compatibility fields

The biological-evidence schema retains `compartment`, `lineage`, `state`,
`process`, `positive_marker_genes`, `supportive_marker_genes`, and
`conflict_detected` for compatibility. The current database-primary adapter
does not assign marker-derived cellular compartments or lineages, resolve
independent state/process axes, or use marker-rule conflicts as canonical
decision variables.

Consequently, schema presence must not be confused with a validated cellular
classification, conflict-aware lineage assignment, or a confidence scale beyond
the states documented above.

## Auxiliary marker-rule evidence

The technical `Rule evidence` sheet preserves per-rule marker overlap,
supporting terms, heuristic evidence scores, rule-specific eligibility, and
available provenance for independent review.

These rule scores are auxiliary, are not clinically calibrated, and do not
define `primary_interpretation`, `priority_eligible`, or final protein
priorities. `legacy_unverified` and `provisional` provenance states must not be
represented as independently validated classifiers.

See the
[biological evidence rulebook contract](contracts/biological-evidence-rulebook.md)
for curation states and provenance requirements.

## Entity classification and candidate eligibility

Nodes are independently classified before automatic protein priority.

| `candidate_eligibility` | Meaning |
|---|---|
| `review_ready_canonical` | Canonical or unclassified protein-coding entity eligible for review when its module is also eligible |
| `network_evidence_only` | Locus, predicted, pseudogene-like, or non-coding entity retained for network evidence only |
| `excluded_from_automatic_priority` | Mitochondrial, ribosomal, Y-associated, or related entity excluded from automatic promotion |
| `manual_review_required` | Entity requiring explicit review before a priority claim |

Final protein priorities require a `review_ready_canonical` entity, membership
in a priority-eligible biological module, and a valid exploratory candidate
score. Network inclusion does not by itself imply automatic priority or
clinical actionability.

## Canonical and compatibility outputs

Canonical evidence is exposed through `result$biological_evidence`, the
analytical workbook, the corresponding technical evidence sheets, and GraphML.
Auxiliary rule evaluations remain separately identifiable, while retired
readable annotation tables are available only under `result$compatibility`.

See the [schema-versioning contract](schema-versioning.md) for public output
versions and compatibility rules.
