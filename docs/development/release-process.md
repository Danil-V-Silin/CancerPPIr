# Release process

Release preparation and immutable publication are separate operations.

## Release preparation

1. Create a short-lived `release/<version>` branch from synchronized `main`.
2. Set the product version in `VERSION` and `CITATION.cff`.
3. Set the same actual release date in `CITATION.cff`, `CHANGELOG.md`, and
   `docs/development/release-notes-v<version>.md`.
4. Preserve every previously published tag, changelog section, date, and
   version-specific release-note file.
5. Keep product versions independent from public output-schema versions.
6. Run the publication, documentation, unit/CLI, repository-quality, and Git
   whitespace gates.
7. Review and squash-merge the release-preparation Pull Request.
8. Confirm successful Windows and Ubuntu CI for the exact final `main` commit.

## Qualified publication

1. Confirm that `v<version>` is unused locally, remotely, and in GitHub
   Releases.
2. Verify the canonical release-input provenance and checksums.
3. Restore the locked environment in a clean detached clone of the exact final
   `main` commit.
4. Run the complete seven-case release qualification once.
5. Audit all seven analytical and technical workbooks and explicitly resolve or
   accept every non-blocking `REVIEW` finding.
6. Preserve private source, environment, input-provenance, validation, and
   workbook-audit evidence.
7. Create a compact public evidence archive that excludes clinical inputs,
   input fingerprints, case-level summaries, and patient-level outputs.
8. Reconfirm that local `main`, `origin/main`, the clean clone, and the
   qualified commit are identical.
9. Create and push an annotated `v<version>` tag only after every gate passes.
10. Publish the GitHub Release from that exact tag and verify its attached
    evidence asset.

If the tag is pushed but GitHub Release publication fails, do not move or
recreate the tag. Resume only the GitHub Release publication step using the
preserved release notes and evidence archive.

Release tags must never be moved, overwritten, deleted for reuse, or repointed.
