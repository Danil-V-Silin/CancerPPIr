# Schema versioning

CancerPPIr versions each public output contract independently.

## Initial public registry

| Contract | Version |
|---|---:|
| Pipeline result | `1.0.0` |
| Biological evidence | `1.0.0` |
| Analytical workbook | `1.0.0` |
| Technical workbook | `1.0.0` |
| GraphML | `1.0.0` |
| Output manifest | `1.0.0` |
| Output checksums | `1.0.0` |

The first public release line starts every public schema at `1.0.0`. Earlier
superseded development identifiers remain available only through Git history and
are not public schema versions.

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
