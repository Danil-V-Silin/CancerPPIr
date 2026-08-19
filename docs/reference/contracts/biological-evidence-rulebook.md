# Biological evidence rulebook contract

## Scope

CancerPPIr separates the biological rulebook from the computational decision
engine. `R/biological_evidence_rules.R` contains rule definitions and their
scientific-provenance contract; `R/biological_evidence_engine.R` evaluates
those rules.

## Transition status

The active rulebook currently contains 35 rules. BE-2 curation removed the
`perivascular_contractile` process rule whose positive and supportive marker
sets exactly duplicated those of the retained lineage rule, and began source-level
curation of the highest-risk cross-axis redundancies. Rules not yet reviewed
remain `legacy_unverified`; reviewed rules remain `provisional` until their
source evidence, marker selection, thresholds, and intended use are formally
approved. Successful seven-case execution alone does not verify a biological
rule or calibrate its weights.

This status means that a rule remains available for regression compatibility,
but its marker selection, thresholds, term patterns and heuristic weights must
not be interpreted as source-verified solely because they are present in the
code.

## Provenance states

- `legacy_unverified`: inherited rule awaiting source-level curation.
- `verified`: source-level curation completed and references recorded.
- `provisional`: plausible rule retained for explicit scientific review.
- `deprecated`: retained only for compatibility, migration or audit.

A rule cannot be marked `verified` unless at least one scientific reference is
recorded.

## Scope of BE-1B validation

BE-1B validates provenance structure, unique rule identifiers, biological-axis
values, one-to-one mapping between rules and provenance records, allowed
curation states, schema versions, and the reference requirement for verified
rules.

It does not claim that the legacy marker sets, thresholds, term patterns or
scoring weights have been scientifically validated. Source-level scientific
curation is performed separately in BE-2.

The auxiliary `evidence_score` combines heuristic marker, term, coverage, and
exclusion components. Its weights are not clinically calibrated or validated
against an independent reference standard, and its auxiliary eligibility flags
must not be interpreted as canonical module or protein priorities.

## Canonical decision role

The biological-evidence rulebook is an auxiliary interpretation and audit
resource. It does not define the canonical biological interpretation of a
Louvain module and does not determine automatic module or protein priority.

Canonical module interpretation is derived from statistically significant,
non-generic local STRING enrichment evidence. The complete rule-evidence table
is retained in technical outputs so that marker-based contextual evidence can
still be inspected independently.

A module without qualifying STRING/database enrichment remains unresolved
rather than receiving a marker-rule-derived canonical label.
