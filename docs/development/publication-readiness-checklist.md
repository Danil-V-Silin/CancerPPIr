# Publication-readiness checklist

This checklist is enforced where possible by
`scripts/validate_publication_readiness.R`.

| Area | Requirement | Status source |
|---|---|---|
| Version | `VERSION` and `CITATION.cff` agree | Automated |
| Release date | Absent before tag; exact date added immediately before release | Automated/manual |
| Public schemas | All initial public schemas are `1.0.0` | Automated |
| CLI | Strict argument count, integer ranges, and Boolean parsing | Automated |
| Workbooks | Semantic sheet names and contract tests | Automated |
| Provenance | Manifest and checksum contracts remain valid | Automated |
| Documentation | Required files and local links resolve | Automated |
| Security | Private vulnerability reporting is documented and enabled | Automated/manual |
| CI | Windows and Ubuntu jobs pass | GitHub Actions |
| Seven cases | Complete release checkpoint passes once on final code | Release gate |
| Duplication | Seven analytical and technical workbooks are audited | Audit tool/manual |
| Clean clone | Dependencies restore and smoke run passes outside the working tree | Manual |
| Metadata | Actual release date, tag, and pre-release are consistent | Manual |

A release tag is created only after every automated check passes and every
manual item is recorded as complete.
