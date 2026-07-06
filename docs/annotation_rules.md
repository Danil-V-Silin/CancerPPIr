# Annotation rules

CancerPPIr annotates major Louvain modules using explicit rules. The rules are designed to make module labels reproducible and auditable, rather than relying on free-text interpretation of enrichment results.

## Evidence used for module labels

Module labels are assigned from three sources of evidence:

1. **Network structure**: proteins are first grouped into Louvain communities in the reconstructed STRING-derived PPI graph.
2. **Curated marker-gene overlap**: module genes are compared with marker sets defined in the workflow.
3. **Local STRING enrichment**: module proteins are tested against locally cached STRING v12 enrichment terms for *Homo sapiens*.

The current workflow runs in offline annotation mode. It does not query GO, WikiPathways, UniProt, g:Profiler or STRING web services during annotation. These resources may appear in the output because the downloaded STRING enrichment table already contains annotation categories such as Gene Ontology, WikiPathways, UniProt keywords, STRING local network clusters and related STRING term classes.

## Marker sets

CancerPPIr uses curated marker sets as a compact prior for common tumor-biopsy programs. The current marker groups are:

| Marker group | Biological context | Representative genes |
|---|---|---|
| `antigen_presentation` | MHC antigen presentation | `HLA-DRA`, `HLA-DRB1`, `HLA-DPA1`, `HLA-DPB1`, `CD74`, `B2M` |
| `T_cell_cytotoxic` | T-cell and cytotoxic lymphocyte biology | `CD3D`, `CD3E`, `CD4`, `CD8A`, `GZMB`, `PRF1`, `NKG7`, `IFNG` |
| `myeloid_macrophage` | Myeloid/macrophage-associated immune programs | `TYROBP`, `TREM2`, `CD163`, `MRC1`, `FCGR1A`, `FCGR2A`, `FCGR3A`, `SPI1` |
| `chemokine_cytokine` | Chemokine and cytokine signalling | `TNF`, `CCL2`, `CCL5`, `CCR5`, `CXCL9`, `CXCL10`, `CXCL13`, `CXCR4` |
| `complement_C1q` | Complement and C1q-associated biology | `C1QA`, `C1QB`, `C1QC`, `C1R`, `C1S`, `C2`, `C3`, `SERPING1` |
| `extracellular_matrix_stromal` | Stromal and extracellular-matrix remodeling | `COL1A1`, `COL1A2`, `COL3A1`, `POSTN`, `MMP2`, `MMP9`, `VWF`, `PECAM1` |
| `cell_cycle_mitotic` | Cell-cycle and mitotic proliferation | `CDK1`, `TOP2A`, `CDC20`, `CCNB1`, `AURKB`, `BIRC5`, `MKI67`, `PLK1` |
| `lipid_metabolic` | Lipid and fatty-acid metabolism | `FABP4`, `LEP`, `ADIPOQ`, `LPL`, `LIPE`, `PLIN1`, `DGAT2`, `PCK1` |
| `interferon_response` | Interferon and antiviral response | `IDO1`, `GBP4`, `GBP5`, `CXCL9`, `CXCL10`, `IFITM2`, `MX2`, `TRIM22` |

The full marker lists are defined in `cancerppir.R`.

## Rulebook labels

Each rule contains a specific label, a broader fallback label, admissible marker evidence and required term-level evidence. A precise label is used only when the evidence contains enough biological specificity. Otherwise, CancerPPIr uses the fallback label or leaves the module unassigned.

| Specific label | Fallback label | Main evidence expected |
|---|---|---|
| `MHC_class_II_antigen_presentation_module` | `immune_antigen_presentation_associated_module` | Antigen-presentation markers and specific terms related to MHC, HLA, peptide antigen processing or presentation. |
| `chemokine_cytokine_signaling_module` | `inflammatory_immune_signaling_module` | Chemokine/cytokine or interferon-response markers and terms related to chemokines, cytokines, interleukins, TNF or chemotaxis. |
| `C1q_complement_macrophage_module` | `phagocytic_immune_cell_signaling_module` | Complement/C1q or macrophage marker support and specific terms related to complement, C1q, macrophages or Fc receptors. Phagocytosis alone is not sufficient for the specific C1q/complement label. |
| `myeloid_phagocytic_immune_signaling_module` | `myeloid_innate_immune_signaling_module` | Myeloid/macrophage markers and terms related to myeloid cells, innate immunity, neutrophil degranulation, phagocytosis, CDC42 or actin/cytoskeleton organization. |
| `T_cell_adaptive_immune_module` | `adaptive_immune_cell_module` | T-cell/cytotoxic markers and terms related to T cells, adaptive immunity, lymphocyte activation, cytotoxicity, natural killer cells, granzymes or perforin. |
| `myeloid_leukocyte_signaling_module` | `leukocyte_immune_signaling_module` | Myeloid/macrophage markers and terms related to myeloid cells, leukocyte activation, immune receptors, hematopoietic cells or innate immunity. |
| `stromal_ECM_remodeling_module` | `stromal_matrix_associated_module` | ECM/stromal markers and terms related to extracellular matrix, collagen, matrix organization, stromal biology or adhesion. |
| `interferon_response_module` | `antiviral_inflammatory_response_module` | Interferon-response markers and terms related to interferon signalling, antiviral response or viral-response biology. |
| `cell_cycle_mitotic_module` | `proliferation_associated_module` | Cell-cycle markers and terms related to mitosis, chromosome segregation, DNA replication, spindle biology or cyclins. |
| `lipid_metabolic_module` | `metabolic_lipid_associated_module` | Lipid-metabolism markers and terms related to lipids, fatty acids, cholesterol, lipoproteins or triglycerides. |

## Label assignment procedure

For each major module, CancerPPIr evaluates all rulebook labels and assigns the best-supported label.

1. Count module overlap with marker sets.
2. Collect local STRING enrichment terms for the module.
3. Remove broad terms from the primary interpretive layer.
4. Score each label rule using marker evidence, term evidence, required specific evidence, enrichment FDR, module size and marker-term concordance.
5. Select the highest-scoring rule.
6. Use the specific label if required specific evidence is present or marker support is strong.
7. Use the fallback label when evidence supports the broad biological direction but lacks specificity for the precise label.
8. Leave the module unassigned if evidence is insufficient.

The final label is reported together with `label_source`, `label_evidence_score`, `label_confidence` and `label_warning`.

## Label evidence score

`label_evidence_score` is an interpretability score for module annotation. It is not a clinical score.

The score increases with:

- at least one matching marker gene;
- stronger marker overlap;
- at least one matching specific enrichment term;
- multiple matching enrichment terms;
- required specific evidence for the selected rule;
- significant enrichment after FDR correction;
- stronger FDR support;
- sufficient module size;
- concordance between marker evidence and enrichment evidence.

Higher scores support more reliable module labels, especially when both marker overlap and specific STRING enrichment point to the same biological program.

## Label source

| Value | Meaning |
|---|---|
| `curated_marker_overlap_plus_specific_STRING_enrichment` | Marker overlap and significant specific STRING enrichment both support the label. |
| `specific_STRING_enrichment_only` | Significant specific STRING enrichment supports the label, but curated marker support is absent. |
| `curated_marker_overlap_only` | Marker overlap supports the label, but significant specific STRING enrichment is absent. |
| `not_assigned` | The evidence is insufficient for a reliable label. |

## Label confidence

| Value | Meaning |
|---|---|
| `high_concordant_marker_and_specific_STRING_evidence` | Strongest label category. Marker overlap and significant specific STRING enrichment are concordant. |
| `medium_high_specific_STRING_evidence` | Specific STRING enrichment is strong, but marker support is weaker or absent. |
| `medium_marker_supported` | Marker support is present, but STRING enrichment evidence is weaker or not significant. |
| `medium_low_limited_support` | Some evidence is present, but it is limited. Treat the label as tentative. |
| `low_unassigned_or_insufficient_evidence` | The module is unassigned or lacks reliable evidence for interpretation. |

## Label warnings

| Warning | Meaning |
|---|---|
| `no_warning` | The label passed the rulebook checks without an audit warning. |
| `label_downgraded_to_fallback_due_to_missing_required_specific_evidence` | The module supports a broad biological direction, but lacks evidence required for the more specific label. |
| `label_assigned_from_STRING_only_without_curated_marker_support` | The label is based on enrichment terms without curated marker support. |
| `marker_supported_but_no_specific_STRING_terms` | The label is based on marker overlap without significant specific enrichment terms. |
| `limited_evidence_low_label_score` | The label was assigned with limited evidence. |
| `no_reliable_marker_or_specific_STRING_evidence_for_label` | The module should not be used for strong functional interpretation. |

## Supporting biological themes

`supporting_biological_themes` records secondary themes detected in the module. The field is intentionally conservative. It prioritizes the assigned label theme and adds secondary themes only when there is stronger marker or term evidence. It should not be treated as an additional set of final labels.

## Recommended reporting

A module label should be reported together with its evidence. For example:

> The module was annotated as a chemokine/cytokine signalling program based on chemokine/cytokine marker overlap and significant local STRING enrichment for chemokine-response and cytokine-response terms.

Avoid wording that implies direct experimental validation:

> The module proves cytokine-driven therapy response.

CancerPPIr module labels are computational annotations and should be validated in the biological and clinical context of the sample.
