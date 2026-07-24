# Known legacy baseline issues

The following limitations were observed before refactoring:

1. Input headers may fall back to positional interpretation as
   `pvalue`, `logFC` and `gene`.
2. HGNChelper reports non-approved symbols, and STRING does not map
   every supplied identifier.
3. Several packages were built under later R 4.5.x patch versions
   than the active R 4.5.0 installation.
4. GraphML read-back fails for K01, M01, P01 because a numeric attribute triggers an integer or double overflow.
5. The two runs were not exactly identical at the workbook-sheet
   level. Differences are concentrated in Louvain assignments and
   module-dependent outputs. The underlying STRING interaction
   content and network node/edge counts remained stable.

Raw XLSX and GraphML checksums are diagnostic only. Binary metadata
or serialization order can differ even when analytical structures
remain equivalent.
