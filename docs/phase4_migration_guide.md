# Phase 4 migration guide

This guide maps retired Phase 4 development outputs to the current canonical
contracts. Compatibility structures may remain available for historical audit,
but new analyses must use canonical fields.

## Analytical workbook migration

The current analytical workbook contains six sheets. Older compact or ranked
views were consolidated as follows:

| Retired view | Current source |
|---|---|
| `Top candidates` | `Candidate evidence` |
| `Candidate rationale` | `Candidate evidence` |
| `Major module priorities` | `Module priorities` |
| `Graph summary` | `Executive summary` and `Network overview` |
| `Top degree` | `Network overview` (`topological_hub`) |
| `Top betweenness` | `Network overview` (`topological_hub`) |
| `Top stress` | `Network overview` (`topological_hub`) |
| `Degree distribution` | `Network overview` (`degree_distribution`) |
| `All modules` | technical workbook module sheets |

Current order:

1. `Executive summary`
2. `Final priorities`
3. `Module priorities`
4. `Candidate evidence`
5. `Network overview`
6. `Methods and limitations`

## Legacy annotation-field migration

| Legacy field | Canonical replacement |
|---|---|
| `module_direction` | `module_primary_interpretation` |
| `clean_module_label` | `module_primary_interpretation` |
| `marker_clean_label` | compartment/lineage/state/process fields |
| `marker_based_direction` | lineage/state/process evidence fields |
| `marker_evidence_genes` | positive and supportive marker fields |
| `enrichment_evidence_terms` | `module_significant_supporting_terms` |
| `final_functional_label` | `module_primary_interpretation` |
| `putative_biological_program` | `module_primary_interpretation` |
| `specific_label_candidate` | primary interpretation plus interpretation scope |
| `fallback_label` | `module_interpretation_scope` |
| `label_assignment_mode` | `module_interpretation_scope` |
| `label_source` | explicit marker and significant-term evidence fields |
| `label_evidence_score` | confidence plus explicit evidence components |
| `label_confidence` | `module_confidence` |
| `label_warning` | `module_warning` |
| `biological_direction_rationale` | `module_evidence_rationale` |

## Pipeline object migration

| Retired public location | Current location |
|---|---|
| shadow biological-evidence object | `result$biological_evidence` |
| mixed top-level report tables | `result$reports` and `result$priorities` |
| unversioned file inventory | `result$files` plus `result$provenance` |
| legacy readable tables | `result$compatibility` |

`result$compatibility` is marked `deprecated_compatibility_only`. Its values are
not permitted to drive current final priorities or canonical GraphML.

## Output inventory migration

Two provenance files were added in Phase 4.7:

- `CancerPPIr_Output_Manifest.json`;
- `CancerPPIr_Output_Checksums.sha256`.

Pipelines that copy, archive, or publish CancerPPIr results should include both.

## Migration rule

Do not mix a canonical candidate table with a legacy module label. Migrate the
whole interpretive chain—module evidence, candidate eligibility, warnings,
rationale, schema version, and provenance—before comparing or reporting a run.
