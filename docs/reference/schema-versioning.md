# Schema versioning

CancerPPIr versions each public output contract independently.

## Current public registry

| Contract | Version |
|---|---:|
| Pipeline result | `1.0.0` |
| Biological evidence | `2.0.0` |
| Analytical workbook | `2.0.0` |
| Technical workbook | `2.1.0` |
| GraphML | `1.0.0` |
| Output manifest | `2.2.0` |
| Output checksums | `1.0.0` |

Most public contracts began at `1.0.0`. Biological-evidence and technical-
workbook schema `2.0.0` require explicit scientific provenance for auxiliary
rule evidence and exclude deprecated labels from canonical node annotations.
Technical-workbook schema `2.1.0` adds post-mapping STRING collision counts and
the deterministic selection policy to `Mapping summary`.
Output manifest `2.0.0` removed original input filenames for privacy; `2.1.0`
adds an optional pseudonymous case ID and its source; `2.2.0` adds the product
version and STRING collision metadata. Manifest versions `1.0.0`, `2.0.0`, and
`2.1.0` remain supported when validating existing results.

## Change rules

- **Patch**: compatible clarification or correction that does not alter required
  fields, names, ordering, or interpretation.
- **Minor**: backward-compatible addition of optional fields or documented
  capabilities.
- **Major**: incompatible change to required fields, names, ordering, types,
  semantics, or validation behavior.

A software version identifies a CancerPPIr release. A schema version identifies
one public structure or interpretation contract. A Git commit records source
history. Reproducible work should preserve all three when available.
