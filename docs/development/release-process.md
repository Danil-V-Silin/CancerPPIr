# Release process

## Release candidate

1. Merge only reviewed publication-readiness changes into `main`.
2. Confirm successful Windows and Ubuntu CI.
3. Run the complete seven-case release checkpoint from a new output directory.
4. Review all seven analytical and technical workbooks, including the
   workbook-duplication audit.
5. Perform clean-clone qualification outside the development working tree.
6. Confirm version, changelog, citation metadata, security guidance, and public
   contracts.
7. Insert the actual release date into `CITATION.cff`, `CHANGELOG.md`, and the
   release notes.
8. Create an annotated `v1.0.0-rc.N` tag.
9. Publish a GitHub pre-release from that immutable tag.
10. Preserve the release evidence and source archive.

## Stable release

1. Resolve release-candidate defects.
2. Repeat the seven-case regression only when analytical behavior or a public
   output contract changed after the accepted release-candidate qualification.
3. Update version metadata from the release candidate to `1.0.0`.
4. Repeat clean-clone qualification.
5. Create the annotated `v1.0.0` tag.
6. Publish the GitHub release and archive it for a DOI.

Release tags must never be moved or overwritten.
