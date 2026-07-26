# Release process

## Release candidate

1. Merge only reviewed changes into `main`.
2. Confirm Windows and Ubuntu CI.
3. Confirm version, changelog, citation, and public contracts.
4. Create an annotated `v1.0.0-rc.N` tag.
5. Publish a GitHub pre-release.
6. Perform clean-clone qualification.

## Stable release

1. Resolve release-candidate defects.
2. Run one final seven-case regression only if analytical behavior or a public output contract changed after the previous accepted regression.
3. Update version metadata from the release candidate to `1.0.0`.
4. Create annotated tag `v1.0.0`.
5. Publish the GitHub release and archive it for a DOI.

Release tags must never be moved or overwritten.
