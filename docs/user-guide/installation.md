# Installation

## Requirements

- R 4.5.x
- Git
- Internet access for initial dependency restoration
- Sufficient storage for local STRING v12 resources

## Reproducible environment

From the repository root:

```r
install.packages("renv")
renv::restore()
renv::status()
```

Do not install ad hoc package versions into the project library after `renv::restore()` unless the lockfile is intentionally updated and reviewed.

## Platform support

CancerPPIr continuous integration covers:

- Ubuntu 24.04
- Windows Server 2022

Release qualification also includes a clean-clone test on Windows.
