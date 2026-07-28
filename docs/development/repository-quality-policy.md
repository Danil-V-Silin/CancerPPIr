# Repository quality policy

CancerPPIr applies repository-level controls in addition to scientific
validation.

## Pull-request controls

Changes to `main` are expected to pass:

- repository-quality validation;
- unit and CLI tests on Ubuntu and Windows;
- publication-readiness validation;
- Git whitespace validation.

GitHub Actions use read-only repository permissions and immutable full-length
commit SHAs. Checkout credentials are not persisted after checkout.

## Review scope

A pull request must identify whether it changes:

- documentation or metadata;
- tests or validation;
- internal implementation only;
- the public input or output contract;
- analytical behavior;
- dependencies or continuous integration.

Changes to public contracts or analytical behavior require explicit
documentation and release qualification.

## Data governance

Patient-identifiable information and restricted clinical data must not be
committed. Public examples must be synthetic, openly licensed, or accompanied
by explicit provenance and redistribution permission.

## Dependency maintenance

Dependabot monitors GitHub Actions references. Dependency updates are reviewed
through pull requests and must pass the same quality gates as other changes.
