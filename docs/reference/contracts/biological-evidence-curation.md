# Biological evidence curation record

## BE-2C1: exact cross-axis marker-set redundancy correction

This change addresses the two exact positive-marker duplications identified
by the BE-2A pairwise audit before broader rulebook curation.

### Perivascular / smooth-muscle identity

`perivascular_contractile` was removed from the active rulebook because its
positive and supportive marker sets were identical to
`perivascular_smooth_muscle_associated`. The retained lineage rule now uses
identity-oriented vascular terms and no longer uses `contractile` as an
enrichment requirement.

Primary evidence:
- Barnett et al., Nature Medicine (2024), PMID:39566559,
  DOI:10.1038/s41591-024-03376-x.
- Chasseigneaux et al., Scientific Reports (2018), PMID:30116021,
  DOI:10.1038/s41598-018-30739-5.

### Plasma-cell identity versus antibody-secretory state

`plasma_cell_associated` retains plasma-cell identity markers but its
functional secretion / humoral enrichment terms were removed.

`immunoglobulin_secretion` was redefined around ER / secretory-apparatus
genes associated with high antibody-production capacity. Plasma-lineage
markers that previously made the state rule's positive-marker set identical
to that of the lineage rule were removed from the positive-marker set. The rule
remains `provisional` pending formal review of its complete marker selection,
thresholds, and intended interpretive use.

Primary evidence:
- Reimold et al., Nature (2001), PMID:11460154.
- Iwakoshi et al., Nature Immunology (2003), PMID:12612580,
  DOI:10.1038/ni907.
- Shaffer et al., Immunity (2004), PMID:15345222,
  DOI:10.1016/j.immuni.2004.06.010.
- Todd et al., Journal of Experimental Medicine (2009), PMID:19752183.
- Taubenheim et al., Journal of Immunology (2012), PMID:22925926.
- Preisendörfer et al., Cells (2022), PMID:35456020.

## Interpretation

`provisional` means that the rule has a primary-literature basis and has passed
structural curation, but has not been independently validated as a classifier.
Seven-case regression qualification verifies software behavior; it does not by
itself establish biological sensitivity, specificity, or calibrated weights.
