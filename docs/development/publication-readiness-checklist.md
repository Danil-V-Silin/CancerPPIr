# Publication-readiness checklist

This checklist is enforced where possible by
`scripts/validate_publication_readiness.R`.

| Area | Requirement | Status source |
|---|---|---|
| Product version | `VERSION` and `CITATION.cff` agree and use stable semantic versioning | Automated |
| Release date | `CITATION.cff`, `CHANGELOG.md`, and current version-specific release notes agree | Automated |
| Historical metadata | Previously published release dates and version-specific notes remain preserved | Automated/manual |
| Public schemas | Output contracts remain independently versioned and match the central schema registry | Automated |
| CLI | Strict argument count, integer ranges, and Boolean parsing | Automated |
| Scientific input | Explicit headers, raw p-value semantics, log2 contrast direction, complete finite values, unique genes, and no positional fallback | Automated |
| Workbooks | Semantic sheet names and contract tests | Automated |
| Provenance | Manifest and checksum contracts remain valid | Automated |
| Documentation | Required files, active-version references, and local links resolve | Automated |
| Security | Current supported release and private vulnerability reporting are documented | Automated/manual |
| CI | Windows and Ubuntu jobs pass for the exact final commit | GitHub Actions |
| Seven cases | Complete release qualification passes once on final code | Release gate |
| Duplication | Fourteen workbooks are audited; structural `FAIL` findings are zero and every `REVIEW` finding is resolved or explicitly accepted | Audit tool/manual |
| Clean clone | Locked dependencies restore and all gates pass outside the development working tree | Release gate |
| Tag | The product-version tag is unused before publication and resolves to the qualified commit afterward | Release gate |
| Public evidence | The attached archive contains no clinical inputs, input fingerprints, case-level summaries, or patient-level outputs | Release gate |

A release tag is created only after every automated check passes and every
manual item is recorded as complete.

Historical manual review record:
[`workbook-duplication-review-v1.0.0.md`](workbook-duplication-review-v1.0.0.md).
