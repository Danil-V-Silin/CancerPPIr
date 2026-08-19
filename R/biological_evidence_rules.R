# CancerPPIr: biological evidence rulebook
#
# Biological rule definitions are maintained separately from the
# computational engine that evaluates them.
#
# BE-1A is behavior-preserving: marker sets, enrichment patterns,
# thresholds, priorities, and rule order are unchanged.

default_evidence_rules <- function() {
  list(
    list(
      rule_id = "plasma_cell_associated",
      axis = "lineage",
      display_label = "plasma-cell-associated",
      compartment = "immune",
      positive_markers = c(
        "MZB1", "JCHAIN", "TNFRSF17", "SDC1",
        "PRDM1", "XBP1", "DERL3"
      ),
      supportive_markers = c(
        "IRF4", "IGLL5", "IGKC", "CD79A",
        "CD79B", "CD37", "CD22"
      ),
      exclusion_markers = c(
        "TYROBP", "FCER1G", "LILRB1", "LILRB2",
        "CTSS", "AIF1", "CD163", "TREM2"
      ),
      term_patterns = c(
        "plasma cell",
        "plasmablast",
        "plasma-cell differentiation"
      ),
      required_term_patterns = c(
        "plasma cell",
        "plasmablast"
      ),
      min_positive = 2L,
      min_score = 0.45,
      priority = 10L
    ),
    list(
      rule_id = "B_cell_associated",
      axis = "lineage",
      display_label = "B-cell-associated",
      compartment = "immune",
      positive_markers = c(
        "CD19", "MS4A1", "CD79A", "CD79B",
        "CD22", "CD37", "CD83", "BANK1"
      ),
      supportive_markers = c(
        "CD74", "HLA-DRA", "HLA-DRB1", "IGKC",
        "IGLL5", "JCHAIN", "MZB1"
      ),
      exclusion_markers = c(
        "TYROBP", "FCER1G", "LILRB1", "LILRB2",
        "CD3D", "CD3E", "NKG7"
      ),
      term_patterns = c(
        "b cell",
        "b-cell",
        "b cell receptor",
        "humoral immune response",
        "immunoglobulin"
      ),
      required_term_patterns = c(
        "b cell",
        "b-cell",
        "b cell receptor",
        "immunoglobulin",
        "humoral"
      ),
      min_positive = 2L,
      min_score = 0.45,
      priority = 9L
    ),
    list(
      rule_id = "T_cell_associated",
      axis = "lineage",
      display_label = "T-cell-associated",
      compartment = "immune",
      positive_markers = c(
        "CD3D", "CD3E", "CD3G", "TRAC",
        "CD2", "CD247", "IL7R", "LCK",
        "GIMAP1", "GIMAP4", "GIMAP6", "GIMAP7",
        "GIMAP8", "SASH3", "RASAL3"
      ),
      supportive_markers = c(
        "CD4", "CD8A", "CD8B", "CTLA4",
        "ICOS", "MAL", "TRBC1", "TRBC2",
        "SNX20"
      ),
      exclusion_markers = c(
        "TYROBP", "FCER1G", "LILRB1", "LILRB2",
        "CD163", "TREM2"
      ),
      term_patterns = c(
        "t cell",
        "t-cell",
        "t cell receptor",
        "adaptive immune",
        "lymphocyte activation"
      ),
      required_term_patterns = c(
        "t cell",
        "t-cell",
        "t cell receptor"
      ),
      min_positive = 2L,
      min_score = 0.45,
      marker_only_min_positive = 5L,
      marker_only_min_supportive = 1L,
      marker_only_min_score = 0.34,
      priority = 8L
    ),
    list(
      rule_id = "myeloid_macrophage_associated",
      axis = "lineage",
      display_label = "myeloid/macrophage-associated",
      compartment = "immune",
      positive_markers = c(
        "TYROBP", "FCER1G", "AIF1", "CTSS",
        "LILRB1", "LILRB2", "SPI1", "IRF8",
        "CD163", "TREM2", "MRC1", "FCGR3A"
      ),
      supportive_markers = c(
        "LY86", "MS4A7", "MS4A6A", "CYBB",
        "FOLR2", "MARCO", "FCGR2A", "CSF1R"
      ),
      exclusion_markers = c(
        "MZB1", "JCHAIN", "TNFRSF17", "CD79A",
        "CD79B", "MS4A1", "CD3D", "CD3E"
      ),
      term_patterns = c(
        "myeloid",
        "macrophage",
        "monocyte",
        "innate immune",
        "fc receptor"
      ),
      required_term_patterns = c(
        "myeloid",
        "macrophage",
        "monocyte",
        "fc receptor"
      ),
      min_positive = 2L,
      min_score = 0.45,
      priority = 8L
    ),
    list(
      rule_id = "neutrophil_associated",
      axis = "lineage",
      display_label = "neutrophil-associated",
      compartment = "immune",
      positive_markers = c(
        "FCGR3B", "CSF3R", "FPR1", "FPR2",
        "S100A8", "S100A9", "CAMP", "MPO",
        "ELANE", "PGLYRP1", "CEBPE"
      ),
      supportive_markers = c(
        "CXCR2", "MNDA", "SELL", "CEACAM8",
        "CTSG"
      ),
      exclusion_markers = c(
        "MZB1", "JCHAIN", "TNFRSF17",
        "CD3D", "CD3E"
      ),
      term_patterns = c(
        "neutrophil",
        "granulocyte",
        "degranulation"
      ),
      required_term_patterns = c(
        "neutrophil",
        "granulocyte"
      ),
      min_positive = 2L,
      min_score = 0.45,
      marker_only_min_positive = 2L,
      marker_only_min_supportive = 1L,
      marker_only_min_score = 0.34,
      priority = 8L
    ),
    list(
      rule_id = "endothelial_associated",
      axis = "lineage",
      display_label = "endothelial-associated",
      compartment = "vascular/stromal",
      positive_markers = c(
        "PECAM1", "VWF", "KDR", "EMCN",
        "ENG", "ESAM", "RAMP2", "PLVAP",
        "CLDN5", "ACKR1", "APLNR", "CLEC14A",
        "SOX18", "RAMP3", "FLT1", "CA4"
      ),
      supportive_markers = c(
        "CD34", "SPARCL1", "KLF2", "KLF4",
        "EGFL7", "CCDC85B", "HS3ST2"
      ),
      exclusion_markers = c(
        "COL1A1", "COL1A2", "COL3A1",
        "MZB1", "JCHAIN"
      ),
      term_patterns = c(
        "endothelial",
        "blood vessel",
        "vasculature",
        "angiogenesis"
      ),
      required_term_patterns = c(
        "endothelial",
        "blood vessel",
        "vasculature"
      ),
      min_positive = 2L,
      min_score = 0.45,
      marker_only_min_positive = 4L,
      marker_only_min_supportive = 2L,
      marker_only_min_score = 0.34,
      priority = 8L
    ),
    list(
      rule_id = "fibroblast_stromal_associated",
      axis = "lineage",
      display_label = "fibroblast/stromal-associated",
      compartment = "stromal",
      positive_markers = c(
        "COL1A1", "COL1A2", "COL3A1", "DCN",
        "LUM", "COL5A1", "COL5A2", "PDGFRA",
        "PDGFRB", "FAP", "POSTN", "DPT",
        "OGN", "SFRP4", "PI16", "CLEC3B",
        "BGN", "PRELP", "COL22A1", "MGP"
      ),
      supportive_markers = c(
        "SPARC", "MMP2", "TIMP3", "VCAN",
        "THY1", "ASPN", "C7", "OMD",
        "ISLR", "CCN5", "TNFAIP6"
      ),
      exclusion_markers = c(
        "PECAM1", "VWF", "KDR",
        "MZB1", "JCHAIN"
      ),
      term_patterns = c(
        "fibroblast",
        "stromal",
        "extracellular matrix",
        "collagen"
      ),
      required_term_patterns = c(
        "fibroblast",
        "stromal",
        "extracellular matrix",
        "collagen"
      ),
      min_positive = 2L,
      min_score = 0.45,
      marker_only_min_positive = 4L,
      marker_only_min_supportive = 2L,
      marker_only_min_score = 0.34,
      priority = 8L
    ),
    list(
      rule_id = "mast_cell_associated",
      axis = "lineage",
      display_label = "mast-cell-associated",
      compartment = "immune",
      positive_markers = c(
        "TPSAB1", "TPSB2", "TPSD1", "CPA3",
        "KIT", "MS4A2", "HPGDS", "GATA2"
      ),
      supportive_markers = c(
        "CTSG", "FCER1A", "HDC", "SRGN",
        "LTC4S"
      ),
      exclusion_markers = character(),
      term_patterns = c(
        "mast cell",
        "mast-cell",
        "tryptase",
        "histamine",
        "mast cell degranulation"
      ),
      required_term_patterns = c(
        "mast cell",
        "mast-cell",
        "tryptase",
        "histamine"
      ),
      min_positive = 2L,
      min_score = 0.42,
      marker_only_min_positive = 3L,
      marker_only_min_supportive = 1L,
      marker_only_min_score = 0.34,
      priority = 8L
    ),
    list(
      rule_id = "perivascular_smooth_muscle_associated",
      axis = "lineage",
      display_label = "perivascular/smooth-muscle-associated",
      compartment = "vascular/stromal",
      positive_markers = c(
        "MYH11", "ACTA2", "TAGLN", "RGS5",
        "CSPG4", "MCAM", "KCNMB1", "MYLK",
        "DES", "CALD1", "NOTCH3"
      ),
      supportive_markers = c(
        "PDGFRB", "COL4A1", "COL4A2", "RBP1",
        "COX4I2", "ABCC9"
      ),
      exclusion_markers = character(),
      term_patterns = c(
        "smooth muscle",
        "pericyte",
        "perivascular",
        "vascular smooth muscle",
        "mural cell"
      ),
      required_term_patterns = c(
        "smooth muscle",
        "pericyte",
        "perivascular",
        "mural cell"
      ),
      min_positive = 2L,
      min_score = 0.42,
      marker_only_min_positive = 2L,
      marker_only_min_supportive = 2L,
      marker_only_min_score = 0.34,
      priority = 7L
    ),
    list(
      rule_id = "keratinizing_squamous_epithelial_associated",
      axis = "lineage",
      display_label = "keratinizing/squamous-epithelial-associated",
      compartment = "epithelial",
      positive_markers = c(
        "KRT1", "KRT10", "KRT14", "KRT15",
        "KRT71", "KRT73", "KRT77", "KRT79",
        "PKP1", "DMKN", "DSG1", "DSC1",
        "IVL", "LOR", "FLG"
      ),
      supportive_markers = c(
        "ABCB5", "KRT5", "KRT6A", "KRT6B",
        "KRT16", "KRT17"
      ),
      exclusion_markers = character(),
      term_patterns = c(
        "keratinization",
        "cornification",
        "epidermal",
        "squamous epithelial",
        "keratinocyte"
      ),
      required_term_patterns = c(
        "keratinization",
        "cornification",
        "epidermal",
        "squamous"
      ),
      min_positive = 3L,
      min_score = 0.40,
      marker_only_min_positive = 5L,
      marker_only_min_supportive = 1L,
      marker_only_min_score = 0.34,
      priority = 6L
    ),
    list(
      rule_id = "adipocyte_associated",
      axis = "lineage",
      display_label = "adipocyte-associated",
      compartment = "stromal/metabolic",
      positive_markers = c(
        "ADIPOQ", "LEP", "PLIN1", "FABP4",
        "LIPE", "LPL", "CIDEA", "CIDEC"
      ),
      supportive_markers = c(
        "AQP7", "DGAT2", "PCK1", "MLXIPL"
      ),
      exclusion_markers = character(),
      term_patterns = c(
        "adipocyte",
        "adipogenesis",
        "fat cell",
        "lipid storage"
      ),
      required_term_patterns = c(
        "adipocyte",
        "fat cell"
      ),
      min_positive = 2L,
      min_score = 0.45,
      priority = 8L
    ),
    list(
      rule_id = "neuroendocrine_associated",
      axis = "lineage",
      display_label = "neuroendocrine-associated",
      compartment = "neural/neuroendocrine",
      positive_markers = c(
        "CHGA", "CHGB", "SYP", "NCAM1",
        "INSM1", "ASCL1", "NEUROD1"
      ),
      supportive_markers = c(
        "PCSK1", "PCSK2", "SCG3", "SCG5",
        "POMC", "DLL3", "SOX2", "ELAVL4",
        "STMN2", "MYT1L", "FOXG1"
      ),
      exclusion_markers = character(),
      term_patterns = c(
        "neuroendocrine",
        "neuropeptide",
        "synaptic vesicle",
        "regulated secretion"
      ),
      required_term_patterns = c(
        "neuroendocrine",
        "neuropeptide",
        "synaptic"
      ),
      min_positive = 2L,
      min_score = 0.45,
      marker_only_min_positive = 2L,
      marker_only_min_supportive = 2L,
      marker_only_min_score = 0.30,
      priority = 8L
    ),
    list(
      rule_id = "immunoglobulin_secretion",
      axis = "state",
      display_label = "antibody-secretory-program",
      compartment = "immune",
      positive_markers = c(
        "DNAJB9", "EDEM1", "P4HB",
        "SEC61A1", "FKBP11", "PDIA4"
      ),
      supportive_markers = c(
        "XBP1", "MZB1", "DERL3",
        "HSPA5", "PRDX4"
      ),
      exclusion_markers = character(),
      term_patterns = c(
        "immunoglobulin secretion",
        "antibody secretion",
        "secretory pathway",
        "unfolded protein response",
        "endoplasmic reticulum"
      ),
      required_term_patterns = c(
        "immunoglobulin secretion",
        "antibody secretion",
        "secretory",
        "unfolded protein response"
      ),
      min_positive = 5L,
      min_score = 0.40,
      priority = 10L
    ),
    list(
      rule_id = "antigen_presentation",
      axis = "state",
      display_label = "antigen-presentation",
      compartment = "immune",
      positive_markers = c(
        "HLA-DRA", "HLA-DRB1", "HLA-DPA1",
        "HLA-DPB1", "HLA-DQA1", "HLA-DQB1",
        "CD74", "CIITA"
      ),
      supportive_markers = c(
        "B2M", "TAP1", "TAP2", "HLA-A",
        "HLA-B", "HLA-C"
      ),
      exclusion_markers = character(),
      term_patterns = c(
        "antigen processing",
        "antigen presentation",
        "major histocompatibility",
        "mhc class"
      ),
      required_term_patterns = c(
        "antigen processing",
        "antigen presentation",
        "major histocompatibility",
        "mhc"
      ),
      min_positive = 2L,
      min_score = 0.40,
      priority = 9L
    ),
    list(
      rule_id = "complement_associated",
      axis = "state",
      display_label = "complement-associated",
      compartment = "immune/stromal",
      positive_markers = c(
        "C1QA", "C1QB", "C1QC", "C1R",
        "C1S", "C2", "C3", "C4A", "C4B"
      ),
      supportive_markers = c(
        "SERPING1", "CFH", "CFI", "C7"
      ),
      exclusion_markers = character(),
      term_patterns = c(
        "complement activation",
        "classical complement",
        "complement cascade",
        "c1q"
      ),
      required_term_patterns = c(
        "complement",
        "c1q"
      ),
      min_positive = 2L,
      min_score = 0.40,
      priority = 9L
    ),
    list(
      rule_id = "phagolysosomal",
      axis = "state",
      display_label = "phagolysosomal",
      compartment = "immune",
      positive_markers = c(
        "CTSS", "CTSB", "CTSD", "LAMP1",
        "LAMP2", "CYBB", "FCER1G", "TYROBP"
      ),
      supportive_markers = c(
        "LYZ", "AIF1", "FCGR2A", "FCGR3A"
      ),
      exclusion_markers = character(),
      term_patterns = c(
        "phagosome",
        "lysosome",
        "phagocytosis",
        "phagocytic"
      ),
      required_term_patterns = c(
        "phagosome",
        "lysosome",
        "phagocyt"
      ),
      min_positive = 2L,
      min_score = 0.40,
      priority = 7L
    ),
    list(
      rule_id = "cytotoxic_effector",
      axis = "state",
      display_label = "cytotoxic-effector",
      compartment = "immune",
      positive_markers = c(
        "NKG7", "GNLY", "PRF1", "GZMB",
        "GZMH", "GZMK", "CTSW"
      ),
      supportive_markers = c(
        "CD8A", "CD8B", "TBX21", "IFNG"
      ),
      exclusion_markers = character(),
      term_patterns = c(
        "cytotoxic",
        "granzyme",
        "perforin",
        "natural killer",
        "lymphocyte mediated cytotoxicity"
      ),
      required_term_patterns = c(
        "cytotoxic",
        "granzyme",
        "perforin",
        "natural killer"
      ),
      min_positive = 2L,
      min_score = 0.40,
      priority = 8L
    ),
    list(
      rule_id = "interferon_response",
      axis = "state",
      display_label = "interferon-responsive",
      compartment = "multi-compartment",
      positive_markers = c(
        "IFIT1", "IFIT2", "IFIT3", "ISG15",
        "MX1", "MX2", "OAS1", "OAS2",
        "GBP1", "GBP4", "GBP5", "STAT1"
      ),
      supportive_markers = c(
        "CXCL9", "CXCL10", "CXCL11", "IRF1",
        "TRIM22", "EPSTI1"
      ),
      exclusion_markers = character(),
      term_patterns = c(
        "interferon",
        "antiviral",
        "response to virus",
        "viral defense"
      ),
      required_term_patterns = c(
        "interferon",
        "antiviral",
        "virus"
      ),
      min_positive = 2L,
      min_score = 0.40,
      priority = 8L
    ),
    list(
      rule_id = "mast_cell_degranulation",
      axis = "state",
      display_label = "mast-cell-degranulation-associated",
      compartment = "immune",
      positive_markers = c(
        "TPSAB1", "TPSB2", "TPSD1", "CPA3",
        "HDC", "HPGDS"
      ),
      supportive_markers = c(
        "CTSG", "MS4A2", "KIT", "FCER1A"
      ),
      exclusion_markers = character(),
      term_patterns = c(
        "mast cell degranulation",
        "mast-cell degranulation",
        "histamine secretion",
        "tryptase"
      ),
      required_term_patterns = c(
        "mast cell",
        "mast-cell",
        "histamine",
        "tryptase"
      ),
      min_positive = 2L,
      min_score = 0.40,
      marker_only_min_positive = 2L,
      marker_only_min_supportive = 1L,
      marker_only_min_score = 0.34,
      priority = 7L
    ),
    list(
      rule_id = "ECM_remodeling",
      axis = "process",
      display_label = "extracellular-matrix-remodelling",
      compartment = "stromal",
      positive_markers = c(
        "COL1A1", "COL1A2", "COL3A1", "POSTN",
        "MMP2", "MMP9", "TIMP3", "SPARC",
        "DPT", "OGN", "PRELP", "BGN",
        "COL22A1", "SFRP4"
      ),
      supportive_markers = c(
        "LUM", "DCN", "COL5A1", "COL5A2",
        "ASPN", "VCAN", "OMD", "CLEC3B",
        "PI16", "MGP"
      ),
      exclusion_markers = character(),
      term_patterns = c(
        "extracellular matrix",
        "matrix organization",
        "collagen",
        "matrix remodelling",
        "matrix remodeling"
      ),
      required_term_patterns = c(
        "extracellular matrix",
        "collagen",
        "matrix"
      ),
      min_positive = 2L,
      min_score = 0.40,
      priority = 8L
    ),
    list(
      rule_id = "immune_leukocyte_associated",
      axis = "lineage",
      display_label = "immune-leukocyte-associated",
      compartment = "immune",
      positive_markers = c(
        "PTPRC", "LCP1", "LCP2", "PLEK",
        "LAPTM5", "CD48", "CD53", "NCKAP1L",
        "INPP5D", "SYK", "FGR", "SRGN"
      ),
      supportive_markers = c(
        "FYB1", "RGS1", "IL10RA", "CORO1A",
        "FERMT3", "DOCK2", "ARHGDIB", "SLA"
      ),
      exclusion_markers = character(),
      term_patterns = c(
        "leukocyte activation",
        "immune receptor",
        "hematopoietic cell",
        "lymphocyte activation",
        "leukocyte migration"
      ),
      required_term_patterns = c(
        "leukocyte",
        "immune receptor",
        "hematopoietic"
      ),
      min_positive = 3L,
      min_score = 0.38,
      marker_only_min_positive = 5L,
      marker_only_min_supportive = 2L,
      marker_only_min_score = 0.35,
      priority = 5L
    ),
    list(
      rule_id = "erythroid_associated",
      axis = "lineage",
      display_label = "erythroid-associated",
      compartment = "hematopoietic",
      positive_markers = c(
        "HBB", "HBA1", "HBA2", "ALAS2",
        "SLC4A1", "EPB42", "AHSP", "GYPA",
        "GYPB", "KLF1", "BPGM", "CA1"
      ),
      supportive_markers = c(
        "HBD", "HBM", "HBG1", "HBG2",
        "TRIM10", "HBQ1", "PFKFB1", "ANK1"
      ),
      exclusion_markers = character(),
      term_patterns = c(
        "erythrocyte",
        "red blood cell",
        "hemoglobin",
        "heme biosynthetic",
        "oxygen transport"
      ),
      required_term_patterns = c(
        "erythrocyte",
        "red blood cell",
        "hemoglobin",
        "heme"
      ),
      min_positive = 3L,
      min_score = 0.40,
      marker_only_min_positive = 5L,
      marker_only_min_supportive = 2L,
      marker_only_min_score = 0.35,
      priority = 9L
    ),
    list(
      rule_id = "neural_glial_associated",
      axis = "lineage",
      display_label = "neural/glial-associated",
      compartment = "neural",
      positive_markers = c(
        "S100B", "SOX10", "GFAP", "ALDH1L1",
        "SLC1A3", "GJB6", "GRIA2", "PVALB",
        "SLC6A5", "GLRA1", "CALB2", "SCN2A",
        "NPTX1", "NPTX2", "NPTXR", "SLITRK2",
        "MAST1"
      ),
      supportive_markers = c(
        "GRIN1", "GAL", "SIM1", "FOXG1",
        "PAX6", "OLIG1", "OLIG2", "PLP1",
        "IGSF21", "RUNDC3A"
      ),
      exclusion_markers = character(),
      term_patterns = c(
        "neuron",
        "neuronal",
        "glial",
        "synaptic",
        "neurotransmitter",
        "axon"
      ),
      required_term_patterns = c(
        "neuron",
        "neuronal",
        "glial",
        "synaptic"
      ),
      min_positive = 3L,
      min_score = 0.40,
      marker_only_min_positive = 5L,
      marker_only_min_supportive = 2L,
      marker_only_min_score = 0.35,
      priority = 7L
    ),
    list(
      rule_id = "secretory_epithelial_associated",
      axis = "lineage",
      display_label = "secretory-epithelial-associated",
      compartment = "epithelial",
      positive_markers = c(
        "EPCAM", "KRT8", "KRT18", "KRT19",
        "KRT7", "MUC1", "AQP5", "PIP",
        "SCGB2A2", "DCD", "MUCL1", "MUC7"
      ),
      supportive_markers = c(
        "TMPRSS2", "CA6", "ZG16B", "AZGP1",
        "KRT17", "KRT5", "KRT14", "MSLN"
      ),
      exclusion_markers = character(),
      term_patterns = c(
        "epithelial",
        "glandular",
        "secretory",
        "mucin",
        "exocrine"
      ),
      required_term_patterns = c(
        "epithelial",
        "glandular",
        "secretory",
        "mucin"
      ),
      min_positive = 3L,
      min_score = 0.40,
      marker_only_min_positive = 4L,
      marker_only_min_supportive = 2L,
      marker_only_min_score = 0.34,
      priority = 7L
    ),
    list(
      rule_id = "chemokine_immune_organization",
      axis = "state",
      display_label = "chemokine-mediated immune organization",
      compartment = "immune/stromal",
      positive_markers = c(
        "CCL19", "CCL21", "CXCL9", "CXCL10",
        "CXCL11", "CCL8", "CCL18", "CCL11"
      ),
      supportive_markers = c(
        "CXCL14", "CD209", "FPR3", "SLAMF8",
        "ADAMDEC1", "SIGLEC8"
      ),
      exclusion_markers = character(),
      term_patterns = c(
        "chemokine",
        "leukocyte migration",
        "lymphocyte migration",
        "immune cell recruitment",
        "lymphoid organ"
      ),
      required_term_patterns = c(
        "chemokine",
        "leukocyte migration",
        "lymphocyte migration",
        "recruitment"
      ),
      min_positive = 2L,
      min_score = 0.38,
      marker_only_min_positive = 4L,
      marker_only_min_supportive = 1L,
      marker_only_min_score = 0.34,
      priority = 7L
    ),
    list(
      rule_id = "developmental_patterning",
      axis = "process",
      display_label = "developmental-patterning/HOX-associated",
      compartment = "multi-compartment",
      positive_markers = c(
        "HOXA7", "HOXA9", "HOXA10", "HOXA11",
        "HOXB13", "HOXD10", "HOXD11", "HOXD12",
        "PRRX1", "EMX2", "FZD10", "IRX1",
        "IRX2", "IRX4", "IRX5", "IRX6",
        "TBX5", "MESP1"
      ),
      supportive_markers = c(
        "TAFA5", "PRAC1", "PRAC2", "BARX1",
        "PROX1", "FOXA2", "NKX2-1"
      ),
      exclusion_markers = character(),
      term_patterns = c(
        "pattern specification",
        "regionalization",
        "anterior posterior",
        "homeobox",
        "embryonic development",
        "morphogenesis"
      ),
      required_term_patterns = c(
        "pattern",
        "regionalization",
        "homeobox",
        "embryonic",
        "morphogenesis"
      ),
      min_positive = 3L,
      min_score = 0.38,
      marker_only_min_positive = 5L,
      marker_only_min_supportive = 1L,
      marker_only_min_score = 0.34,
      priority = 6L
    ),
    list(
      rule_id = "xenobiotic_metabolism",
      axis = "process",
      display_label = "xenobiotic/drug-metabolic",
      compartment = "epithelial/metabolic",
      positive_markers = c(
        "CYP2C9", "CYP2B6", "UGT2A3", "GSTM4",
        "ALDH1A1", "ADH1C", "HNF4A", "LIPC",
        "ABCG8", "GCKR", "PLA2G7", "PLA2G2D"
      ),
      supportive_markers = c(
        "CREB3L3", "LPCAT2", "ADAMDEC1",
        "ALDH1A2", "CYP27B1"
      ),
      exclusion_markers = character(),
      term_patterns = c(
        "xenobiotic",
        "drug metabolism",
        "oxidation reduction",
        "retinoid metabolism",
        "fatty acid metabolism"
      ),
      required_term_patterns = c(
        "xenobiotic",
        "drug metabolism",
        "oxidation",
        "retinoid"
      ),
      min_positive = 3L,
      min_score = 0.38,
      marker_only_min_positive = 5L,
      marker_only_min_supportive = 1L,
      marker_only_min_score = 0.34,
      priority = 6L
    ),
    list(
      rule_id = "heme_oxygen_transport",
      axis = "process",
      display_label = "heme/oxygen-transport",
      compartment = "hematopoietic",
      positive_markers = c(
        "HBB", "HBA1", "HBA2", "ALAS2",
        "SLC4A1", "EPB42", "AHSP", "GYPA"
      ),
      supportive_markers = c(
        "HBD", "HBM", "HBG1", "HBG2",
        "CA1", "BPGM", "PFKFB1"
      ),
      exclusion_markers = character(),
      term_patterns = c(
        "oxygen transport",
        "heme biosynthetic",
        "hemoglobin",
        "gas transport"
      ),
      required_term_patterns = c(
        "oxygen transport",
        "heme",
        "hemoglobin"
      ),
      min_positive = 3L,
      min_score = 0.38,
      marker_only_min_positive = 5L,
      marker_only_min_supportive = 1L,
      marker_only_min_score = 0.34,
      priority = 8L
    ),
    list(
      rule_id = "cell_cycle_regulatory",
      axis = "process",
      display_label = "cell-cycle-regulatory/CDK-associated",
      compartment = "multi-compartment",
      positive_markers = c(
        "CDK4", "CDK6", "CCND1", "CCND2",
        "CCND3", "MDM2", "CDKN2A", "CDKN2B",
        "CDKN2C", "RB1", "E2F1", "E2F2",
        "E2F3"
      ),
      supportive_markers = c(
        "TSPAN31", "METTL1", "PROX1", "CYP27B1"
      ),
      exclusion_markers = character(),
      term_patterns = c(
        "cyclin-dependent protein serine/threonine kinase activity",
        "positive regulation of cyclin-dependent",
        "g1/s",
        "cell cycle regulator",
        "p53 signaling"
      ),
      required_term_patterns = c(
        "cyclin-dependent",
        "g1/s",
        "cell cycle",
        "p53"
      ),
      min_positive = 2L,
      min_score = 0.38,
      priority = 8L
    ),
    list(
      rule_id = "cancer_testis_antigen_expression",
      axis = "process",
      display_label = "cancer-testis-antigen-expression-associated",
      compartment = "tumour-associated",
      positive_markers = c(
        "MAGEA1", "MAGEA2", "MAGEA3", "MAGEA4",
        "MAGEA6", "MAGEA10", "MAGEA12", "CTAG1A",
        "CTAG1B", "CTAG2", "CSAG1", "CSAG2",
        "CSAG3", "XAGE1A", "XAGE1B", "GAGE1",
        "GAGE2A", "GAGE2B", "GAGE4", "SPANXB1",
        "SPANXC"
      ),
      supportive_markers = c(
        "BEX1", "TCEAL5", "NAP1L3"
      ),
      exclusion_markers = character(),
      term_patterns = c(
        "cancer.testis",
        "melanoma.associated antigen",
        "melanoma associated antigen",
        "ctag",
        "span-x",
        "gage",
        "xage"
      ),
      required_term_patterns = c(
        "cancer.testis",
        "melanoma.associated antigen",
        "melanoma associated antigen",
        "ctag"
      ),
      min_positive = 3L,
      min_score = 0.40,
      marker_only_min_positive = 5L,
      marker_only_min_supportive = 1L,
      marker_only_min_score = 0.34,
      priority = 8L
    ),
    list(
      rule_id = "microtubule_cytoskeleton",
      axis = "process",
      display_label = "microtubule/cytoskeletal-associated",
      compartment = "multi-compartment",
      positive_markers = c(
        "TUBA1A", "TUBA1B", "TUBA3C", "TUBB2A",
        "TUBB2B", "TUBB3", "TUBB8", "TUBB8B",
        "KIF1A", "KIF1B", "MNS1"
      ),
      supportive_markers = c(
        "REEP2", "RIBC2", "TRIB2", "ZNF367"
      ),
      exclusion_markers = character(),
      term_patterns = c(
        "microtubule",
        "tubulin",
        "cilium",
        "ciliary",
        "axon transport"
      ),
      required_term_patterns = c(
        "microtubule",
        "tubulin",
        "cilium",
        "axon"
      ),
      min_positive = 3L,
      min_score = 0.38,
      marker_only_min_positive = 5L,
      marker_only_min_supportive = 1L,
      marker_only_min_score = 0.34,
      priority = 5L
    ),
    list(
      rule_id = "imprinted_developmental_program",
      axis = "process",
      display_label = "imprinted-developmental-program-associated",
      compartment = "multi-compartment",
      positive_markers = c(
        "DLK1", "NNAT", "MEST", "RTL1",
        "PEG3", "PEG10", "IGF2", "H19",
        "MEG3", "PLAGL1"
      ),
      supportive_markers = c(
        "CPA4", "CPA5", "CEL"
      ),
      exclusion_markers = character(),
      term_patterns = c(
        "genomic imprinting",
        "imprinted gene",
        "parental imprinting",
        "embryonic development"
      ),
      required_term_patterns = c(
        "imprint",
        "embryonic"
      ),
      min_positive = 3L,
      min_score = 0.38,
      marker_only_min_positive = 4L,
      marker_only_min_supportive = 1L,
      marker_only_min_score = 0.34,
      priority = 5L
    ),
    list(
      rule_id = "axon_guidance_cell_adhesion",
      axis = "process",
      display_label = "axon-guidance/cell-adhesion-associated",
      compartment = "neural/developmental",
      positive_markers = c(
        "EPHA4", "EPHA5", "EPHA6", "EPHA7",
        "EPHA8", "EPHA10", "EPHB1", "EPHB2",
        "EPHB3", "EPHB4", "PCDH17", "ROBO1",
        "ROBO2", "SLIT1", "SLIT2", "SLIT3"
      ),
      supportive_markers = c(
        "CALY", "SAMD5", "NELL1", "NELL2",
        "SLITRK2", "THSD7A"
      ),
      exclusion_markers = character(),
      term_patterns = c(
        "axon guidance",
        "eph receptor",
        "neurite",
        "cell adhesion",
        "nervous system development"
      ),
      required_term_patterns = c(
        "axon",
        "eph receptor",
        "neurite",
        "nervous system"
      ),
      min_positive = 3L,
      min_score = 0.38,
      marker_only_min_positive = 3L,
      marker_only_min_supportive = 1L,
      marker_only_min_score = 0.34,
      priority = 5L
    ),
    list(
      rule_id = "mitotic_proliferation",
      axis = "process",
      display_label = "mitotic/proliferative",
      compartment = "multi-compartment",
      positive_markers = c(
        "CDK1", "TOP2A", "CDC20", "CCNB1",
        "CCNB2", "AURKB", "BIRC5", "MKI67",
        "UBE2C", "KIF11", "PLK1", "FOXM1"
      ),
      supportive_markers = c(
        "MCM2", "MCM5", "MCM7", "TYMS",
        "NDC80", "MAD2L1"
      ),
      exclusion_markers = character(),
      term_patterns = c(
        "cell cycle",
        "mitotic",
        "mitosis",
        "chromosome segregation",
        "dna replication",
        "spindle"
      ),
      required_term_patterns = c(
        "cell cycle",
        "mitotic",
        "mitosis",
        "chromosome",
        "dna replication",
        "spindle"
      ),
      min_positive = 2L,
      min_score = 0.40,
      priority = 9L
    ),
    list(
      rule_id = "lipid_metabolism",
      axis = "process",
      display_label = "lipid-metabolic",
      compartment = "multi-compartment",
      positive_markers = c(
        "FABP4", "LPL", "LIPE", "PLIN1",
        "DGAT2", "CIDEA", "CIDEC", "ADIPOQ",
        "APOD", "PON1", "PON3", "LIPC",
        "FABP6"
      ),
      supportive_markers = c(
        "LEP", "AQP7", "PCK1", "MLXIPL",
        "NR0B2", "LCN15", "ABCG8"
      ),
      exclusion_markers = character(),
      term_patterns = c(
        "lipid",
        "fatty acid",
        "triglyceride",
        "lipoprotein",
        "cholesterol",
        "sterol"
      ),
      required_term_patterns = c(
        "lipid",
        "fatty acid",
        "triglyceride",
        "lipoprotein",
        "cholesterol",
        "sterol"
      ),
      min_positive = 2L,
      min_score = 0.40,
      priority = 8L
    )
  )
}

# ---------------------------------------------------------------------------
# Scientific provenance contract
# ---------------------------------------------------------------------------

CANCERPPIR_EVIDENCE_RULE_SCHEMA_VERSION <- "1.0.0"
CANCERPPIR_EVIDENCE_RULEBOOK_VERSION <- "2.0.0-curation-1"

default_evidence_rule_provenance <- function(
  rules = default_evidence_rules()
) {
  if (!is.list(rules) || !length(rules)) {
    stop(
      "Evidence rulebook must be a non-empty list.",
      call. = FALSE
    )
  }

  rule_ids <- vapply(
    rules,
    function(rule) as.character(rule$rule_id),
    character(1)
  )

  provenance <- data.frame(
    rule_id = rule_ids,
    curation_status = rep(
      "legacy_unverified",
      length(rules)
    ),
    rule_version = rep(
      "legacy-1.0",
      length(rules)
    ),
    rule_schema_version = rep(
      CANCERPPIR_EVIDENCE_RULE_SCHEMA_VERSION,
      length(rules)
    ),
    evidence_basis = rep(
      "legacy_heuristic_pending_source_level_curation",
      length(rules)
    ),
    references = rep(
      "",
      length(rules)
    ),
    stringsAsFactors = FALSE
  )

  curated <- list(
    plasma_cell_associated = list(
      status = "provisional",
      version = "curated-2.0",
      basis = paste0(
        "primary_literature_plasma_cell_identity; ",
        "functional_secretion_terms_removed"
      ),
      references = paste(
        "PMID:11460154",
        "PMID:12612580",
        sep = ";"
      )
    ),
    immunoglobulin_secretion = list(
      status = "provisional",
      version = "curated-2.0",
      basis = paste0(
        "primary_literature_antibody_secretory_apparatus; ",
        "identity_marker_overlap_reduced"
      ),
      references = paste(
        "PMID:15345222",
        "PMID:19752183",
        "PMID:22925926",
        "PMID:35456020",
        sep = ";"
      )
    ),
    perivascular_smooth_muscle_associated = list(
      status = "provisional",
      version = "curated-2.0",
      basis = paste0(
        "primary_human_vascular_atlas_and_rat_brain_vsmc_pericyte_transcriptome; ",
        "exact_positive_supportive_marker_redundancy_removed"
      ),
      references = paste(
        "PMID:39566559",
        "PMID:30116021",
        sep = ";"
      )
    )
  )

  canonical_rules <- default_evidence_rules()
  canonical_rule_ids <- vapply(
    canonical_rules,
    function(rule) as.character(rule$rule_id),
    character(1)
  )

  for (rule_id in names(curated)) {
    index <- match(
      rule_id,
      provenance$rule_id
    )

    if (is.na(index)) {
      next
    }

    canonical_index <- match(
      rule_id,
      canonical_rule_ids
    )

    if (
      is.na(canonical_index) ||
      !identical(
        rules[[index]],
        canonical_rules[[canonical_index]]
      )
    ) {
      next
    }

    item <- curated[[rule_id]]

    provenance$curation_status[[index]] <-
      item$status

    provenance$rule_version[[index]] <-
      item$version

    provenance$evidence_basis[[index]] <-
      item$basis

    provenance$references[[index]] <-
      item$references
  }

  provenance
}

validate_evidence_rule_provenance <- function(
  rules = default_evidence_rules(),
  provenance = default_evidence_rule_provenance(rules)
) {
  if (!is.list(rules) || !length(rules)) {
    stop("Evidence rulebook must be a non-empty list.", call. = FALSE)
  }

  rule_ids <- vapply(
    rules,
    function(rule) as.character(rule$rule_id),
    character(1)
  )
  axes <- vapply(
    rules,
    function(rule) as.character(rule$axis),
    character(1)
  )

  if (anyNA(rule_ids) || any(!nzchar(trimws(rule_ids)))) {
    stop("Evidence rulebook contains an invalid rule_id.", call. = FALSE)
  }
  if (anyDuplicated(rule_ids)) {
    duplicated_ids <- unique(rule_ids[duplicated(rule_ids)])
    stop(
      "Evidence rulebook contains duplicate rule_id values: ",
      paste(duplicated_ids, collapse = ", "),
      call. = FALSE
    )
  }

  allowed_axes <- c("lineage", "state", "process")
  if (anyNA(axes) || any(!(axes %in% allowed_axes))) {
    stop("Evidence rulebook contains an invalid biological axis.", call. = FALSE)
  }

  if (!is.data.frame(provenance)) {
    stop("Evidence provenance must be a data.frame.", call. = FALSE)
  }

  required_fields <- c(
    "rule_id",
    "curation_status",
    "rule_version",
    "rule_schema_version",
    "evidence_basis",
    "references"
  )
  missing_fields <- setdiff(required_fields, names(provenance))
  if (length(missing_fields)) {
    stop(
      "Evidence provenance is missing required field(s): ",
      paste(missing_fields, collapse = ", "),
      call. = FALSE
    )
  }

  provenance_ids <- as.character(provenance$rule_id)
  if (
    nrow(provenance) != length(rules) ||
    !identical(provenance_ids, rule_ids)
  ) {
    stop(
      "Evidence provenance must correspond one-to-one and in order to the rulebook.",
      call. = FALSE
    )
  }

  allowed_status <- c(
    "legacy_unverified",
    "verified",
    "provisional",
    "deprecated"
  )
  statuses <- as.character(provenance$curation_status)
  if (anyNA(statuses) || any(!(statuses %in% allowed_status))) {
    stop("Evidence provenance contains an invalid curation_status.", call. = FALSE)
  }

  versions <- trimws(as.character(provenance$rule_version))
  bases <- trimws(as.character(provenance$evidence_basis))
  schema_versions <- trimws(as.character(provenance$rule_schema_version))

  if (anyNA(versions) || any(!nzchar(versions))) {
    stop("Evidence provenance contains an empty rule_version.", call. = FALSE)
  }
  if (anyNA(bases) || any(!nzchar(bases))) {
    stop("Evidence provenance contains an empty evidence_basis.", call. = FALSE)
  }
  if (
    anyNA(schema_versions) ||
    any(schema_versions != CANCERPPIR_EVIDENCE_RULE_SCHEMA_VERSION)
  ) {
    stop("Evidence provenance contains an invalid rule_schema_version.", call. = FALSE)
  }

  references <- trimws(as.character(provenance$references))
  missing_reference <- is.na(references) | !nzchar(references)
  verified <- statuses == "verified"

  if (any(verified & missing_reference)) {
    stop(
      "Every verified evidence rule must contain at least one scientific reference.",
      call. = FALSE
    )
  }

  invisible(TRUE)
}

evidence_rule_provenance_table <- function(
  rules = default_evidence_rules(),
  provenance = default_evidence_rule_provenance(rules)
) {
  validate_evidence_rule_provenance(rules, provenance)

  output <- provenance
  output$axis <- vapply(rules, function(rule) as.character(rule$axis), character(1))
  output$display_label <- vapply(
    rules,
    function(rule) as.character(rule$display_label),
    character(1)
  )
  output$reference_count <- vapply(
    output$references,
    function(x) {
      x <- trimws(as.character(x))
      if (length(x) != 1L || is.na(x) || !nzchar(x)) {
        return(0L)
      }
      refs <- strsplit(x, ";", fixed = TRUE)[[1L]]
      refs <- trimws(refs)
      sum(nzchar(refs))
    },
    integer(1)
  )

  output <- output[
    ,
    c(
      "rule_id",
      "axis",
      "display_label",
      "curation_status",
      "rule_version",
      "rule_schema_version",
      "evidence_basis",
      "reference_count",
      "references"
    ),
    drop = FALSE
  ]
  rownames(output) <- NULL
  output
}
