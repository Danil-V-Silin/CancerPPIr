# Installation

## Requirements

- R 4.5.0, the qualified runtime recorded in `renv.lock`
- Git
- Internet access for initial dependency restoration
- Sufficient storage for local STRING v12 resources

Other R 4.5.x patch releases may be compatible but have not been independently
qualified. R 4.6 has not been qualified and is not recommended for this release.

## Reproducible environment

From the repository root:

```r
install.packages("renv")
renv::restore()
renv::status()
```

Do not install ad hoc package versions into the project library after `renv::restore()` unless the lockfile is intentionally updated and reviewed.

## STRING v12.0 resources

CancerPPIr uses four version-pinned Homo sapiens STRING v12.0 resources:

- `9606.protein.info.v12.0.txt.gz`
- `9606.protein.aliases.v12.0.txt.gz`
- `9606.protein.links.v12.0.txt.gz`
- `9606.protein.enrichment.terms.v12.0.txt.gz`

The cache directory is supplied when CancerPPIr is run. Existing valid files
are reused. If a required file is missing or invalid, CancerPPIr downloads the
corresponding STRING v12.0 resource into the cache and then performs network
construction and enrichment locally from the cached files.

Internet access is therefore required only when dependencies or missing STRING
resources must be acquired. A populated cache can be reused for subsequent runs.

## Platform support

CancerPPIr continuous integration covers:

- Ubuntu 24.04
- Windows Server 2022

Release qualification also includes a clean-clone test on Windows.
