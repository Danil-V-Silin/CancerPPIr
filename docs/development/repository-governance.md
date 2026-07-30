# Repository governance

## Permanent branch

`main` is the only permanent release-bearing branch.

## Short-lived branches

Use semantic names with one of these prefixes:

```text
feat/
fix/
refactor/
test/
docs/
chore/
release/
```

Branches are deleted after merge. Historical states are preserved by commits,
product-version tags, releases, verified qualification records, and repository
archives.

## Tags

New tags are reserved for product versions:

```text
v1.0.0-rc.1
v1.0.0
v1.0.1
v1.1.0
```

Release tags are annotated and immutable. Superseded pre-release tags may be
retired only after a verified repository backup and confirmation that all
released tags remain immutable.

## Main protection

Recommended repository settings:

- require a pull request before merging;
- require successful Windows and Ubuntu R-test checks;
- require conversation resolution;
- prohibit force pushes;
- prohibit deletion of `main`;
- enable Private vulnerability reporting.

A second reviewer is not mandatory while the project has one maintainer.
