# Biological evidence rulebook contract

## Scope

CancerPPIr separates the biological rulebook from the computational decision
engine. `R/biological_evidence_rules.R` contains rule definitions and their
scientific-provenance contract; `R/biological_evidence_engine.R` evaluates
those rules.

## Transition status

The current 36-rule rulebook is retained behavior-for-behavior from the
pre-provenance implementation. At this stage every rule is explicitly marked
`legacy_unverified`.

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
