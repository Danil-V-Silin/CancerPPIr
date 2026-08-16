# Reproducible software-environment contract

## Purpose

This contract defines the software environment used to qualify CancerPPIr.
It complements input, output, provenance, and release-validation contracts.
It does not claim that different operating systems produce byte-identical XLSX
archives; semantic output equivalence remains the release criterion.

## Pinned environment

The qualified environment is:

- R 4.5.x, with R 4.5.0 used by continuous integration;
- Bioconductor 3.21;
- package versions and package sources recorded in `renv.lock`;
- CRAN snapshot
  `https://packagemanager.posit.co/cran/2026-07-20`;
- STRING v12.0 resources acquired when missing and reused from the user-supplied local cache.

The R patch release may differ within the R 4.5.x series for local development.
Continuous integration remains fixed to R 4.5.0.

## Restoration

From the repository root:

```r
install.packages("renv")
renv::restore()
renv::status()
```

`renv::restore()` must use the repositories recorded in `renv.lock`.
A repository override such as `RENV_CONFIG_REPOS_OVERRIDE` is not permitted in
the qualification workflow because it can bypass the recorded snapshot.

## Automated validation

Run:

```bash
Rscript scripts/validate_reproducibility_contract.R
```

The validator checks the lockfile structure, R and Bioconductor versions,
date-pinned CRAN repository, CI integration, absence of repository overrides,
and the presence of this public contract. It does not install packages, access
clinical data, or execute network analysis.

## Change control

Do not run `renv::snapshot()` as a routine repair step. Dependency changes must
be deliberate, reviewed, tested, and recorded separately. A repository URL
change must not silently modify package records. The full seven-case production
qualification is performed later by the release gate.
