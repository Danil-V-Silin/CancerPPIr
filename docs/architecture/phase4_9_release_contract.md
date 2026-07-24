# Phase 4.9 release-validation contract

## Purpose

Phase 4.9 is the final engineering gate for the Phase 4 output-quality branch.
It does not introduce a new biological scoring method or change network
reconstruction. Its purpose is to prove that the completed Phase 4 contracts
remain internally consistent, reproducible and portable.

## Release gate

The canonical command is:

```bash
Rscript scripts/run_phase4_release_checkpoint.R \
  ../input \
  ../results/phase4_release_checkpoint_v1 \
  ../string_cache \
  run-pipeline \
  run-tests
```

The release gate performs, in order:

1. one complete unit-test run;
2. one static repository audit;
3. documentation-contract and CLI-help validation;
4. one seven-case production regression;
5. technical and analytical workbook validation;
6. canonical GraphML validation;
7. manifest and SHA-256 verification;
8. fixed network, edge and Louvain-module count regression checks.

The seven clinical cases are executed only once in `run-pipeline` mode.

## Existing-output recovery mode

If production calculation finishes but a later release validator fails, the
same outputs can be reused:

```bash
Rscript scripts/run_phase4_release_checkpoint.R \
  ../input \
  ../results/phase4_release_checkpoint_v1 \
  ../string_cache \
  validate-existing \
  skip-tests
```

This mode performs no network reconstruction and skips the unit suite by
default. It revalidates the existing technical workbooks, analytical
workbooks, GraphML files, manifests and checksum files.

## Static release contract

`scripts/validate_phase4_release_static.R` checks that:

- all production and release R files parse;
- no active `biological_evidence_shadow` API remains;
- production code contains no hard-coded A01-R01 case identifiers;
- personal absolute paths are absent;
- `TODO`, `FIXME`, `DEBUG` and `TEMP` markers are absent from production code;
- production function names are unique;
- obsolete generated example outputs are absent;
- no nested Git repository exists in tracked project areas;
- exactly 13 production modules load;
- public schema versions remain pinned;
- runtime and test dependencies are recorded in `renv.lock`;
- CI covers both Ubuntu and Windows.

Historical architecture documents and migration tables are audit records and
are not treated as active public API.

## Synthetic edge cases

The final unit suite includes release-specific tests for:

- an empty automatic protein-priority result;
- an empty automatic module-priority result;
- zero and subnormal p-values in GraphML export;
- pinned public schema versions;
- canonical GraphML fields with legacy decision fields excluded.

These tests use in-memory fixtures and do not initialize STRINGdb.

## Seven-case regression invariants

The final regression uses the previously validated clinical inputs:

| Case | Nodes | Edges | Louvain modules |
|---|---:|---:|---:|
| A01 | 169 | 630 | 43 |
| K01 | 248 | 397 | 100 |
| L01 | 200 | 800 | 50 |
| M01 | 338 | 1630 | 82 |
| P01 | 311 | 1765 | 74 |
| P02 | 285 | 1005 | 76 |
| R01 | 358 | 4507 | 46 |

For every case the release gate additionally verifies:

- all six public output files exist;
- the six-sheet analytical contract passes;
- the five Phase 4 technical evidence tables match their in-memory sources;
- all canonical GraphML fields are present;
- legacy GraphML decision fields are absent;
- GraphML node identifiers match the technical node table;
- candidate scores and Louvain membership match the technical workbook;
- final-priority membership matches the analytical workbook;
- manifest summary values match the generated files;
- manifest hashes and the standalone SHA-256 list verify.

## Cross-platform CI

The GitHub Actions unit workflow runs on:

- `ubuntu-24.04`;
- `windows-2022`.

CI does not run the seven clinical cases because the clinical inputs and large
offline STRING cache are not repository fixtures. CI covers unit, CLI,
documentation, synthetic, provenance and static-release contracts.

## Completion criteria

Phase 4 is release-ready only when the final command ends with:

```text
PHASE 4 RELEASE CHECKPOINT: PASSED
```

A successful checkpoint is followed by a reviewed commit, a green CI run, a
clean working tree and the final Phase 4 tag. The checkpoint itself does not
commit, push, tag or merge the repository.
