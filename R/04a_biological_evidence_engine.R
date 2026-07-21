# CancerPPIr Phase 4: biological evidence engine
#
# This module is intentionally isolated from the current production labeling
# functions. It provides a transparent, hierarchical evidence model that will
# be integrated into the pipeline only after its unit tests and A01 biological
# review pass.
#
# The engine does not estimate cell fractions and must not be described as
# transcriptomic deconvolution.

phase4_normalize_genes <- function(genes) {
  genes <- toupper(trimws(as.character(genes)))
  genes <- genes[!is.na(genes) & nzchar(genes)]
  unique(genes)
}

phase4_find_column <- function(data, candidates) {
  if (is.null(data) || !ncol(data)) {
    return(NA_character_)
  }

  normalize <- function(x) {
    x <- tolower(trimws(as.character(x)))
    gsub("[^a-z0-9]+", "", x)
  }

  observed <- normalize(names(data))
  wanted <- normalize(candidates)
  index <- match(wanted, observed)
  index <- index[!is.na(index)]

  if (!length(index)) {
    return(NA_character_)
  }

  names(data)[index[[1L]]]
}

phase4_split_gene_text <- function(x) {
  if (is.null(x) || !length(x)) {
    return(character())
  }

  tokens <- unlist(
    strsplit(
      paste(as.character(x), collapse = ";"),
      "[,;|/[:space:]]+",
      perl = TRUE
    ),
    use.names = FALSE
  )

  phase4_normalize_genes(tokens)
}

phase4_is_generic_term <- function(term) {
  term <- tolower(trimws(as.character(term)))

  if (!nzchar(term)) {
    return(TRUE)
  }

  generic_patterns <- c(
    "^signaling$",
    "^signal transduction$",
    "^cell communication$",
    "^biological process$",
    "^cellular process$",
    "^immune system process$",
    "^immune response$",
    "^metabolic process$",
    "^regulation of biological process$",
    "^response to stimulus$"
  )

  any(vapply(
    generic_patterns,
    function(pattern) {
      grepl(pattern, term, perl = TRUE)
    },
    FUN.VALUE = logical(1)
  ))
}

phase4_prepare_enrichment_evidence <- function(
  enrichment,
  fdr_threshold = 0.05
) {
  empty <- data.frame(
    source = character(),
    term_id = character(),
    description = character(),
    fdr = numeric(),
    supporting_genes = character(),
    is_significant = logical(),
    is_generic = logical(),
    stringsAsFactors = FALSE
  )

  if (
    is.null(enrichment) ||
    !is.data.frame(enrichment) ||
    nrow(enrichment) == 0L
  ) {
    return(empty)
  }

  description_column <- phase4_find_column(
    enrichment,
    c(
      "description",
      "term",
      "term_name",
      "name"
    )
  )

  fdr_column <- phase4_find_column(
    enrichment,
    c(
      "fdr",
      "false_discovery_rate",
      "padj",
      "adjusted_pvalue",
      "p_adjust"
    )
  )

  source_column <- phase4_find_column(
    enrichment,
    c(
      "category",
      "source",
      "database"
    )
  )

  term_id_column <- phase4_find_column(
    enrichment,
    c(
      "term_id",
      "termid",
      "id"
    )
  )

  genes_column <- phase4_find_column(
    enrichment,
    c(
      "inputGenes",
      "input_genes",
      "genes",
      "gene_symbols",
      "matching_genes"
    )
  )

  if (is.na(description_column)) {
    return(empty)
  }

  description <- trimws(
    as.character(
      enrichment[[description_column]]
    )
  )

  fdr <- if (!is.na(fdr_column)) {
    suppressWarnings(
      as.numeric(
        gsub(
          ",",
          ".",
          as.character(enrichment[[fdr_column]]),
          fixed = TRUE
        )
      )
    )
  } else {
    rep(NA_real_, nrow(enrichment))
  }

  source <- if (!is.na(source_column)) {
    as.character(
      enrichment[[source_column]]
    )
  } else {
    rep("not_available", nrow(enrichment))
  }

  term_id <- if (!is.na(term_id_column)) {
    as.character(
      enrichment[[term_id_column]]
    )
  } else {
    rep("", nrow(enrichment))
  }

  supporting_genes <- if (!is.na(genes_column)) {
    vapply(
      enrichment[[genes_column]],
      function(value) {
        paste(
          phase4_split_gene_text(value),
          collapse = ";"
        )
      },
      FUN.VALUE = character(1)
    )
  } else {
    rep("", nrow(enrichment))
  }

  is_significant <- is.finite(fdr) & fdr <= fdr_threshold

  data.frame(
    source = source,
    term_id = term_id,
    description = description,
    fdr = fdr,
    supporting_genes = supporting_genes,
    is_significant = is_significant,
    is_generic = vapply(
      description,
      phase4_is_generic_term,
      FUN.VALUE = logical(1)
    ),
    stringsAsFactors = FALSE
  )
}

phase4_significant_specific_terms <- function(
  enrichment,
  fdr_threshold = 0.05
) {
  prepared <- phase4_prepare_enrichment_evidence(
    enrichment = enrichment,
    fdr_threshold = fdr_threshold
  )

  prepared[
    prepared$is_significant &
      !prepared$is_generic &
      nzchar(prepared$description),
    ,
    drop = FALSE
  ]
}

phase4_default_evidence_rules <- function() {
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
        "immunoglobulin production",
        "immunoglobulin secretion",
        "humoral immune response",
        "antibody production"
      ),
      required_term_patterns = c(
        "plasma cell",
        "immunoglobulin",
        "humoral",
        "antibody"
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
        "CD2", "CD247", "IL7R", "LCK"
      ),
      supportive_markers = c(
        "CD4", "CD8A", "CD8B", "CTLA4",
        "ICOS", "MAL", "TRBC1", "TRBC2"
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
        "ELANE", "PGLYRP1"
      ),
      supportive_markers = c(
        "CXCR2", "MNDA", "SELL", "CEACAM8"
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
      priority = 8L
    ),
    list(
      rule_id = "endothelial_associated",
      axis = "lineage",
      display_label = "endothelial-associated",
      compartment = "vascular/stromal",
      positive_markers = c(
        "PECAM1", "VWF", "KDR", "EMCN",
        "ENG", "ESAM", "RAMP2", "PLVAP"
      ),
      supportive_markers = c(
        "CD34", "SPARCL1", "KLF2", "KLF4",
        "EGFL7", "CA4", "FLT1"
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
        "PDGFRB", "FAP", "POSTN"
      ),
      supportive_markers = c(
        "SPARC", "MMP2", "TIMP3", "VCAN",
        "THY1", "ASPN", "C7"
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
      priority = 8L
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
      display_label = "immunoglobulin-secretion",
      compartment = "immune",
      positive_markers = c(
        "MZB1", "JCHAIN", "TNFRSF17", "SDC1",
        "PRDM1", "XBP1", "DERL3"
      ),
      supportive_markers = c(
        "IRF4", "IGLL5", "IGKC"
      ),
      exclusion_markers = character(),
      term_patterns = c(
        "immunoglobulin production",
        "immunoglobulin secretion",
        "humoral immune response",
        "antibody production"
      ),
      required_term_patterns = c(
        "immunoglobulin",
        "humoral",
        "antibody"
      ),
      min_positive = 1L,
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
      rule_id = "ECM_remodeling",
      axis = "process",
      display_label = "extracellular-matrix-remodelling",
      compartment = "stromal",
      positive_markers = c(
        "COL1A1", "COL1A2", "COL3A1", "POSTN",
        "MMP2", "MMP9", "TIMP3", "SPARC"
      ),
      supportive_markers = c(
        "LUM", "DCN", "COL5A1", "COL5A2",
        "ASPN", "VCAN"
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
        "SLC6A5", "GLRA1", "CALB2", "SCN2A"
      ),
      supportive_markers = c(
        "GRIN1", "GAL", "SIM1", "FOXG1",
        "PAX6", "OLIG1", "OLIG2", "PLP1"
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
        "PRRX1", "EMX2", "FZD10"
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
        "DGAT2", "CIDEA", "CIDEC", "ADIPOQ"
      ),
      supportive_markers = c(
        "LEP", "AQP7", "PCK1", "MLXIPL"
      ),
      exclusion_markers = character(),
      term_patterns = c(
        "lipid",
        "fatty acid",
        "triglyceride",
        "lipoprotein",
        "cholesterol"
      ),
      required_term_patterns = c(
        "lipid",
        "fatty acid",
        "triglyceride",
        "lipoprotein",
        "cholesterol"
      ),
      min_positive = 2L,
      min_score = 0.40,
      priority = 8L
    )
  )
}

phase4_match_terms <- function(terms, patterns) {
  if (
    is.null(terms) ||
    !nrow(terms) ||
    is.null(patterns) ||
    !length(patterns)
  ) {
    return(logical(0))
  }

  descriptions <- tolower(
    as.character(
      terms$description
    )
  )

  vapply(
    descriptions,
    function(description) {
      any(vapply(
        patterns,
        function(pattern) {
          grepl(
            pattern,
            description,
            ignore.case = TRUE,
            perl = TRUE
          )
        },
        FUN.VALUE = logical(1)
      ))
    },
    FUN.VALUE = logical(1)
  )
}

phase4_evaluate_evidence_rule <- function(
  genes,
  significant_terms,
  rule
) {
  genes <- phase4_normalize_genes(genes)

  positive_hits <- intersect(
    genes,
    phase4_normalize_genes(
      rule$positive_markers
    )
  )

  supportive_hits <- intersect(
    genes,
    phase4_normalize_genes(
      rule$supportive_markers
    )
  )

  exclusion_hits <- intersect(
    genes,
    phase4_normalize_genes(
      rule$exclusion_markers
    )
  )

  term_matches <- phase4_match_terms(
    significant_terms,
    rule$term_patterns
  )

  required_matches <- phase4_match_terms(
    significant_terms,
    rule$required_term_patterns
  )

  matched_terms <- if (length(term_matches)) {
    significant_terms[
      term_matches,
      ,
      drop = FALSE
    ]
  } else {
    significant_terms[
      FALSE,
      ,
      drop = FALSE
    ]
  }

  positive_count <- length(positive_hits)
  supportive_count <- length(supportive_hits)
  exclusion_count <- length(exclusion_hits)
  term_count <- nrow(matched_terms)
  required_term_count <- if (length(required_matches)) {
    sum(required_matches)
  } else {
    0L
  }

  marker_component <- min(
    1,
    positive_count / max(
      1,
      as.numeric(rule$min_positive) + 1
    )
  )

  supportive_component <- min(
    1,
    supportive_count / 4
  )

  term_component <- min(
    1,
    term_count / 2
  )

  coverage_denominator <- max(
    3,
    min(
      8,
      sqrt(
        max(
          1,
          length(genes)
        )
      ) + 1
    )
  )

  coverage_component <- min(
    1,
    (positive_count + supportive_count) /
      coverage_denominator
  )

  exclusion_penalty <- min(
    1,
    exclusion_count / 2
  )

  evidence_score <- (
    0.45 * marker_component +
      0.15 * supportive_component +
      0.25 * term_component +
      0.15 * coverage_component -
      0.30 * exclusion_penalty
  )

  evidence_score <- max(
    0,
    min(
      1,
      evidence_score
    )
  )

  standard_eligible <- (
    positive_count >= as.integer(rule$min_positive)
  ) || (
    positive_count >= 1L &&
      required_term_count >= 1L &&
      term_count >= 1L
  )

  marker_only_min_positive <- if (
    is.null(rule$marker_only_min_positive)
  ) {
    Inf
  } else {
    as.numeric(
      rule$marker_only_min_positive
    )
  }

  marker_only_min_supportive <- if (
    is.null(rule$marker_only_min_supportive)
  ) {
    Inf
  } else {
    as.numeric(
      rule$marker_only_min_supportive
    )
  }

  marker_only_min_score <- if (
    is.null(rule$marker_only_min_score)
  ) {
    as.numeric(
      rule$min_score
    )
  } else {
    as.numeric(
      rule$marker_only_min_score
    )
  }

  marker_only_eligible <- term_count == 0L &&
    (
      positive_count >= marker_only_min_positive ||
        (
          positive_count >= as.integer(rule$min_positive) &&
            supportive_count >= marker_only_min_supportive
        )
    ) &&
    evidence_score >= marker_only_min_score

  eligible <- (
    isTRUE(standard_eligible) &&
      evidence_score >= as.numeric(rule$min_score)
  ) || isTRUE(marker_only_eligible)

  term_supporting_genes <- phase4_normalize_genes(
    unlist(
      lapply(
        matched_terms$supporting_genes,
        phase4_split_gene_text
      ),
      use.names = FALSE
    )
  )

  data.frame(
    rule_id = rule$rule_id,
    axis = rule$axis,
    display_label = rule$display_label,
    compartment = rule$compartment,
    positive_marker_count = positive_count,
    supportive_marker_count = supportive_count,
    exclusion_marker_count = exclusion_count,
    significant_term_count = term_count,
    required_term_count = required_term_count,
    positive_marker_genes = paste(
      positive_hits,
      collapse = ";"
    ),
    supportive_marker_genes = paste(
      supportive_hits,
      collapse = ";"
    ),
    exclusion_marker_genes = paste(
      exclusion_hits,
      collapse = ";"
    ),
    significant_terms = paste(
      matched_terms$description,
      collapse = " | "
    ),
    significant_term_ids = paste(
      matched_terms$term_id[
        nzchar(matched_terms$term_id)
      ],
      collapse = ";"
    ),
    term_supporting_genes = paste(
      term_supporting_genes,
      collapse = ";"
    ),
    best_fdr = if (nrow(matched_terms)) {
      min(
        matched_terms$fdr,
        na.rm = TRUE
      )
    } else {
      NA_real_
    },
    marker_component = marker_component,
    supportive_component = supportive_component,
    term_component = term_component,
    coverage_component = coverage_component,
    coverage_denominator = coverage_denominator,
    exclusion_penalty = exclusion_penalty,
    evidence_score = evidence_score,
    standard_eligible = isTRUE(standard_eligible),
    marker_only_eligible = isTRUE(marker_only_eligible),
    eligible = eligible,
    priority = as.integer(rule$priority),
    stringsAsFactors = FALSE
  )
}

phase4_detect_technical_signature <- function(genes) {
  genes <- phase4_normalize_genes(genes)
  module_size <- length(genes)

  if (!module_size) {
    return(list(
      detected = FALSE,
      signature_id = NA_character_,
      display_label = NA_character_,
      supporting_genes = character(),
      evidence_fraction = 0
    ))
  }

  y_markers <- c(
    "RPS4Y1", "EIF1AY", "KDM5D", "ZFY",
    "DDX3Y", "UTY", "USP9Y", "TMSB4Y",
    "NLGN4Y", "PRKY"
  )

  y_hits <- intersect(
    genes,
    y_markers
  )

  if (
    length(y_hits) >= 3L &&
    length(y_hits) / module_size >= 0.30
  ) {
    return(list(
      detected = TRUE,
      signature_id = "Y_chromosome_associated_signature",
      display_label = "Y-chromosome-associated technical/covariate signature",
      supporting_genes = y_hits,
      evidence_fraction = length(y_hits) / module_size
    ))
  }

  mitochondrial_hits <- genes[
    grepl(
      "^MT-",
      genes
    )
  ]

  if (
    length(mitochondrial_hits) >= 5L &&
    length(mitochondrial_hits) / module_size >= 0.50
  ) {
    return(list(
      detected = TRUE,
      signature_id = "mitochondrial_dominant_signature",
      display_label = "mitochondrial-dominant technical signature",
      supporting_genes = mitochondrial_hits,
      evidence_fraction = length(mitochondrial_hits) / module_size
    ))
  }

  ribosomal_hits <- genes[
    grepl(
      "^RP[SL][0-9]",
      genes
    )
  ]

  if (
    length(ribosomal_hits) >= 8L &&
    length(ribosomal_hits) / module_size >= 0.50
  ) {
    return(list(
      detected = TRUE,
      signature_id = "ribosomal_translation_dominant_signature",
      display_label = "ribosomal/translation-dominant technical signature",
      supporting_genes = ribosomal_hits,
      evidence_fraction = length(ribosomal_hits) / module_size
    ))
  }

  immunoglobulin_hits <- genes[
    grepl(
      "^(IGH|IGK|IGL)",
      genes
    )
  ]

  plasma_core <- intersect(
    genes,
    c(
      "MZB1", "JCHAIN", "TNFRSF17", "SDC1",
      "PRDM1", "XBP1", "DERL3"
    )
  )

  if (
    length(immunoglobulin_hits) >= 5L &&
    length(immunoglobulin_hits) / module_size >= 0.60 &&
    length(plasma_core) < 2L
  ) {
    return(list(
      detected = TRUE,
      signature_id = "immunoglobulin_locus_dominant_signature",
      display_label = "immunoglobulin-locus-dominant technical/covariate signature",
      supporting_genes = immunoglobulin_hits,
      evidence_fraction = length(immunoglobulin_hits) / module_size
    ))
  }

  tcr_hits <- genes[
    grepl(
      "^TR[ABDG][CVJ]",
      genes
    )
  ]

  t_cell_core <- intersect(
    genes,
    c(
      "CD3D", "CD3E", "CD3G", "TRAC",
      "CD2", "CD247", "LCK"
    )
  )

  if (
    length(tcr_hits) >= 5L &&
    length(tcr_hits) / module_size >= 0.60 &&
    length(t_cell_core) < 2L
  ) {
    return(list(
      detected = TRUE,
      signature_id = "TCR_locus_dominant_signature",
      display_label = "T-cell-receptor-locus-dominant technical/covariate signature",
      supporting_genes = tcr_hits,
      evidence_fraction = length(tcr_hits) / module_size
    ))
  }

  list(
    detected = FALSE,
    signature_id = NA_character_,
    display_label = NA_character_,
    supporting_genes = character(),
    evidence_fraction = 0
  )
}

phase4_select_axis_evidence <- function(
  evidence_table,
  axis,
  conflict_delta = 0.08
) {
  all_axis_table <- evidence_table[
    evidence_table$axis == axis,
    ,
    drop = FALSE
  ]

  axis_table <- all_axis_table[
    all_axis_table$eligible,
    ,
    drop = FALSE
  ]

  if (!nrow(axis_table)) {
    return(list(
      selected = axis_table,
      alternatives = axis_table,
      conflict = FALSE,
      conflict_evidence = all_axis_table[
        FALSE,
        ,
        drop = FALSE
      ]
    ))
  }

  axis_table <- axis_table[
    order(
      -axis_table$evidence_score,
      -axis_table$positive_marker_count,
      -axis_table$significant_term_count,
      -axis_table$priority,
      axis_table$rule_id
    ),
    ,
    drop = FALSE
  ]

  selected <- axis_table[
    1L,
    ,
    drop = FALSE
  ]

  alternatives <- if (nrow(axis_table) > 1L) {
    axis_table[
      -1L,
      ,
      drop = FALSE
    ]
  } else {
    axis_table[
      FALSE,
      ,
      drop = FALSE
    ]
  }

  conflict <- FALSE
  conflict_evidence <- all_axis_table[
    FALSE,
    ,
    drop = FALSE
  ]

  # Exclusion markers reduce confidence in a single-lineage assignment, but
  # they must not hide a genuine mixed-lineage module. Therefore lineage
  # conflict detection evaluates independently supported competing rules
  # before the exclusion penalty is applied.
  #
  # States and processes are not treated this way because compatible states
  # such as antigen presentation and complement activity can coexist.
  if (identical(axis, "lineage")) {
    competing <- all_axis_table[
      all_axis_table$rule_id != selected$rule_id[[1L]] &
        all_axis_table$positive_marker_count >= 2L &
        all_axis_table$significant_term_count >= 1L,
      ,
      drop = FALSE
    ]

    if (nrow(competing)) {
      selected_support_score <- min(
        1,
        selected$evidence_score[[1L]] +
          0.30 * selected$exclusion_penalty[[1L]]
      )

      competing$conflict_support_score <- pmin(
        1,
        competing$evidence_score +
          0.30 * competing$exclusion_penalty
      )

      competing <- competing[
        order(
          -competing$conflict_support_score,
          -competing$positive_marker_count,
          -competing$significant_term_count,
          -competing$priority,
          competing$rule_id
        ),
        ,
        drop = FALSE
      ]

      second <- competing[
        1L,
        ,
        drop = FALSE
      ]

      score_difference <- abs(
        selected_support_score -
          second$conflict_support_score[[1L]]
      )

      conflict <- (
        second$conflict_support_score[[1L]] >= 0.45 &&
          score_difference <= conflict_delta
      )

      if (isTRUE(conflict)) {
        conflict_evidence <- second
      }
    }
  }

  list(
    selected = selected,
    alternatives = alternatives,
    conflict = conflict,
    conflict_evidence = conflict_evidence
  )
}

phase4_secondary_axis_evidence <- function(
  axis_selection,
  minimum_score = 0.40,
  maximum_rows = 3L
) {
  alternatives <- axis_selection$alternatives

  if (
    is.null(alternatives) ||
    !is.data.frame(alternatives) ||
    nrow(alternatives) == 0L
  ) {
    return(
      alternatives[
        FALSE,
        ,
        drop = FALSE
      ]
    )
  }

  keep <- alternatives$evidence_score >= minimum_score &
    (
      alternatives$positive_marker_count >= 2L |
        alternatives$significant_term_count >= 1L
    )

  retained <- alternatives[
    keep,
    ,
    drop = FALSE
  ]

  if (nrow(retained) > maximum_rows) {
    retained <- retained[
      seq_len(maximum_rows),
      ,
      drop = FALSE
    ]
  }

  retained
}

phase4_confidence_from_evidence <- function(
  selected_rows,
  has_conflict,
  technical_override
) {
  if (isTRUE(technical_override)) {
    return("technical_or_covariate")
  }

  if (!nrow(selected_rows)) {
    return("unresolved")
  }

  best_score <- max(
    selected_rows$evidence_score,
    na.rm = TRUE
  )

  marker_supported <- any(
    selected_rows$positive_marker_count >= 2L
  )

  term_supported <- any(
    selected_rows$significant_term_count >= 1L
  )

  if (
    best_score >= 0.72 &&
    marker_supported &&
    term_supported &&
    !isTRUE(has_conflict)
  ) {
    return("high")
  }

  if (
    best_score >= 0.50 &&
    (marker_supported || term_supported) &&
    !isTRUE(has_conflict)
  ) {
    return("moderate")
  }

  if (best_score >= 0.35) {
    return("low")
  }

  "unresolved"
}

phase4_join_nonempty <- function(values, separator = "; ") {
  values <- unique(
    trimws(
      as.character(values)
    )
  )

  values <- values[
    !is.na(values) &
      nzchar(values)
  ]

  paste(
    values,
    collapse = separator
  )
}

phase4_infer_selected_compartment <- function(
  selected_rows,
  lineage_selection
) {
  if (
    is.data.frame(lineage_selection) &&
    nrow(lineage_selection) > 0L
  ) {
    return(
      lineage_selection$compartment[[1L]]
    )
  }

  if (
    is.null(selected_rows) ||
    !is.data.frame(selected_rows) ||
    nrow(selected_rows) == 0L
  ) {
    return("unresolved")
  }

  compartments <- unique(
    trimws(
      as.character(
        selected_rows$compartment
      )
    )
  )

  compartments <- compartments[
    !is.na(compartments) &
      nzchar(compartments) &
      compartments != "multi-compartment"
  ]

  if (length(compartments) == 1L) {
    return(compartments[[1L]])
  }

  if (length(compartments) > 1L) {
    return("multi-compartment")
  }

  "multi-compartment"
}

phase4_annotate_module_evidence <- function(
  genes,
  enrichment = NULL,
  module_id = NA,
  fdr_threshold = 0.05,
  rules = phase4_default_evidence_rules(),
  conflict_delta = 0.08
) {
  genes <- phase4_normalize_genes(genes)

  significant_terms <- phase4_significant_specific_terms(
    enrichment = enrichment,
    fdr_threshold = fdr_threshold
  )

  rule_evaluations <- do.call(
    rbind,
    lapply(
      rules,
      function(rule) {
        phase4_evaluate_evidence_rule(
          genes = genes,
          significant_terms = significant_terms,
          rule = rule
        )
      }
    )
  )

  technical <- phase4_detect_technical_signature(
    genes
  )

  lineage <- phase4_select_axis_evidence(
    rule_evaluations,
    axis = "lineage",
    conflict_delta = conflict_delta
  )

  state <- phase4_select_axis_evidence(
    rule_evaluations,
    axis = "state",
    conflict_delta = conflict_delta
  )

  process <- phase4_select_axis_evidence(
    rule_evaluations,
    axis = "process",
    conflict_delta = conflict_delta
  )

  # Lineage is represented by one primary assignment (or a mixed-lineage
  # result). States and processes are multi-label evidence dimensions: several
  # compatible, well-supported themes may coexist and must remain visible.
  secondary_state_rows <- phase4_secondary_axis_evidence(
    state
  )

  secondary_process_rows <- phase4_secondary_axis_evidence(
    process
  )

  state_evidence_rows <- do.call(
    rbind,
    Filter(
      function(x) {
        is.data.frame(x) && nrow(x) > 0L
      },
      list(
        state$selected,
        secondary_state_rows
      )
    )
  )

  process_evidence_rows <- do.call(
    rbind,
    Filter(
      function(x) {
        is.data.frame(x) && nrow(x) > 0L
      },
      list(
        process$selected,
        secondary_process_rows
      )
    )
  )

  if (is.null(state_evidence_rows)) {
    state_evidence_rows <- rule_evaluations[
      FALSE,
      ,
      drop = FALSE
    ]
  }

  if (is.null(process_evidence_rows)) {
    process_evidence_rows <- rule_evaluations[
      FALSE,
      ,
      drop = FALSE
    ]
  }

  selected_rows <- do.call(
    rbind,
    Filter(
      function(x) {
        is.data.frame(x) && nrow(x) > 0L
      },
      list(
        lineage$selected,
        state_evidence_rows,
        process_evidence_rows
      )
    )
  )

  if (is.null(selected_rows)) {
    selected_rows <- rule_evaluations[
      FALSE,
      ,
      drop = FALSE
    ]
  }

  secondary_theme_rows <- do.call(
    rbind,
    Filter(
      function(x) {
        is.data.frame(x) && nrow(x) > 0L
      },
      list(
        secondary_state_rows,
        secondary_process_rows
      )
    )
  )

  if (is.null(secondary_theme_rows)) {
    secondary_theme_rows <- rule_evaluations[
      FALSE,
      ,
      drop = FALSE
    ]
  }

  lineage_label <- if (isTRUE(technical$detected)) {
    "not_applicable"
  } else if (isTRUE(lineage$conflict)) {
    "mixed_lineage_associated"
  } else if (nrow(lineage$selected)) {
    lineage$selected$rule_id[[1L]]
  } else {
    "unresolved_lineage"
  }

  state_label <- if (
    !isTRUE(technical$detected) &&
    nrow(state$selected)
  ) {
    state$selected$rule_id[[1L]]
  } else {
    "not_assigned"
  }

  process_label <- if (
    !isTRUE(technical$detected) &&
    nrow(process$selected)
  ) {
    process$selected$rule_id[[1L]]
  } else {
    "not_assigned"
  }

  selected_labels <- if (isTRUE(technical$detected)) {
    technical$display_label
  } else if (nrow(selected_rows) > 0L) {
    phase4_join_nonempty(
      c(
        if (isTRUE(lineage$conflict)) {
          "mixed-lineage-associated"
        } else if (nrow(lineage$selected)) {
          lineage$selected$display_label[[1L]]
        },
        state_evidence_rows$display_label,
        process_evidence_rows$display_label
      ),
      separator = " / "
    )
  } else {
    "unresolved biological context"
  }

  has_conflict <- isTRUE(lineage$conflict) ||
    isTRUE(state$conflict) ||
    isTRUE(process$conflict)

  confidence <- phase4_confidence_from_evidence(
    selected_rows = selected_rows,
    has_conflict = has_conflict,
    technical_override = technical$detected
  )

  selected_positive_genes <- phase4_normalize_genes(
    unlist(
      lapply(
        selected_rows$positive_marker_genes,
        phase4_split_gene_text
      ),
      use.names = FALSE
    )
  )

  selected_supportive_genes <- phase4_normalize_genes(
    unlist(
      lapply(
        selected_rows$supportive_marker_genes,
        phase4_split_gene_text
      ),
      use.names = FALSE
    )
  )

  selected_term_genes <- phase4_normalize_genes(
    unlist(
      lapply(
        selected_rows$term_supporting_genes,
        phase4_split_gene_text
      ),
      use.names = FALSE
    )
  )

  warning_text <- phase4_join_nonempty(
    c(
      if (isTRUE(technical$detected)) {
        "technical_or_covariate_signature_not_eligible_for_automatic_biological_priority"
      },
      if (isTRUE(lineage$conflict)) {
        "conflicting_lineage_evidence_label_broadened_to_mixed_lineage"
      },
      if (isTRUE(state$conflict)) {
        "conflicting_state_evidence"
      },
      if (isTRUE(process$conflict)) {
        "conflicting_process_evidence"
      },
      if (
        !isTRUE(technical$detected) &&
        !nrow(lineage$selected) &&
        nrow(selected_rows) > 0L
      ) {
        "lineage_not_resolved_state_or_process_evidence_only"
      },
      if (
        !isTRUE(technical$detected) &&
        nrow(selected_rows) > 0L &&
        any(selected_rows$marker_only_eligible) &&
        !any(selected_rows$significant_term_count >= 1L)
      ) {
        "marker_only_interpretation_not_eligible_for_automatic_priority"
      },
      if (
        !isTRUE(technical$detected) &&
        !nrow(selected_rows)
      ) {
        "insufficient_specific_marker_and_significant_enrichment_evidence"
      },
      if (!nrow(significant_terms)) {
        "no_significant_specific_enrichment_terms_available"
      }
    )
  )

  rationale <- if (isTRUE(technical$detected)) {
    paste0(
      technical$display_label,
      ". Supporting genes: ",
      phase4_join_nonempty(
        technical$supporting_genes
      ),
      ". This module is reported as a technical/covariate signature and is not automatically promoted as a biological priority."
    )
  } else if (nrow(selected_rows)) {
    paste0(
      "Primary interpretation: ",
      selected_labels,
      ". Positive marker genes: ",
      phase4_join_nonempty(
        selected_positive_genes
      ),
      ". Supportive genes: ",
      phase4_join_nonempty(
        selected_supportive_genes
      ),
      ". Significant supporting terms: ",
      phase4_join_nonempty(
        selected_rows$significant_terms,
        separator = " | "
      ),
      ". This is marker- and enrichment-supported cell-context evidence, not an estimate of cell abundance."
    )
  } else {
    paste0(
      "No sufficiently specific marker and statistically significant enrichment evidence was available. ",
      "The module remains unresolved."
    )
  }

  summary <- data.frame(
    module_id = as.character(module_id),
    module_size = length(genes),
    interpretation_class = if (isTRUE(technical$detected)) {
      "technical_or_covariate"
    } else if (lineage_label == "mixed_lineage_associated") {
      "mixed_biological"
    } else if (nrow(selected_rows) > 0L) {
      "biological"
    } else {
      "unresolved"
    },
    interpretation_scope = if (isTRUE(technical$detected)) {
      "technical_or_covariate"
    } else if (lineage_label == "mixed_lineage_associated") {
      "mixed_lineage"
    } else if (nrow(lineage$selected) > 0L) {
      "lineage_supported"
    } else if (
      nrow(state_evidence_rows) > 0L &&
        nrow(process_evidence_rows) > 0L
    ) {
      "state_and_process_supported_lineage_unresolved"
    } else if (nrow(state_evidence_rows) > 0L) {
      "state_supported_lineage_unresolved"
    } else if (nrow(process_evidence_rows) > 0L) {
      "process_supported_lineage_unresolved"
    } else {
      "unresolved"
    },
    compartment = if (isTRUE(technical$detected)) {
      "not_applicable"
    } else {
      phase4_infer_selected_compartment(
        selected_rows = selected_rows,
        lineage_selection = lineage$selected
      )
    },
    lineage = lineage_label,
    state = state_label,
    process = process_label,
    primary_interpretation = selected_labels,
    secondary_themes = phase4_join_nonempty(
      secondary_theme_rows$display_label
    ),
    confidence = confidence,
    priority_eligible = !isTRUE(technical$detected) &&
      confidence %in% c("high", "moderate") &&
      !isTRUE(has_conflict) &&
      nrow(selected_rows) > 0L &&
      any(selected_rows$significant_term_count >= 1L),
    positive_marker_genes = phase4_join_nonempty(
      selected_positive_genes
    ),
    supportive_marker_genes = phase4_join_nonempty(
      selected_supportive_genes
    ),
    term_supporting_genes = phase4_join_nonempty(
      selected_term_genes
    ),
    significant_supporting_terms = phase4_join_nonempty(
      selected_rows$significant_terms,
      separator = " | "
    ),
    best_supporting_fdr = if (nrow(selected_rows)) {
      suppressWarnings(
        min(
          selected_rows$best_fdr,
          na.rm = TRUE
        )
      )
    } else {
      NA_real_
    },
    conflict_detected = has_conflict,
    warning = warning_text,
    evidence_rationale = rationale,
    stringsAsFactors = FALSE
  )

  if (
    is.infinite(
      summary$best_supporting_fdr[[1L]]
    )
  ) {
    summary$best_supporting_fdr[[1L]] <- NA_real_
  }

  list(
    summary = summary,
    rule_evaluations = rule_evaluations,
    significant_terms = significant_terms,
    technical_signature = technical
  )
}

phase4_classify_entity <- function(gene) {
  gene <- phase4_normalize_genes(gene)

  if (!length(gene)) {
    return("unknown")
  }

  gene <- gene[[1L]]

  if (grepl("^LOC[0-9]+$", gene)) {
    return("predicted_LOC")
  }

  if (grepl("^(IGH|IGK|IGL)", gene)) {
    return("immunoglobulin_locus")
  }

  if (grepl("^TR[ABDG][CVJ]", gene)) {
    return("T_cell_receptor_locus")
  }

  if (grepl("^MT-", gene)) {
    return("mitochondrial")
  }

  # Y-linked symbols such as RPS4Y1 can also match a broad ribosomal prefix.
  # Test the curated Y-chromosome set before generic ribosomal classification.
  if (
    gene %in% c(
      "RPS4Y1", "EIF1AY", "KDM5D", "ZFY",
      "DDX3Y", "UTY", "USP9Y", "TMSB4Y",
      "NLGN4Y", "PRKY"
    )
  ) {
    return("Y_chromosome_associated")
  }

  if (grepl("^RP[SL][0-9]", gene)) {
    return("ribosomal")
  }

  if (
    grepl("P[0-9]+$", gene) ||
    grepl("PSEUDOGENE", gene)
  ) {
    return("pseudogene_or_pseudogene_like")
  }

  if (
    grepl("-AS[0-9]*$", gene) ||
    grepl("^LINC[0-9]+$", gene)
  ) {
    return("lncRNA_or_antisense")
  }

  "canonical_or_unclassified_protein_coding"
}

phase4_candidate_eligibility <- function(entity_class) {
  entity_class <- as.character(entity_class)

  if (
    entity_class == "canonical_or_unclassified_protein_coding"
  ) {
    return("review_ready_canonical")
  }

  if (
    entity_class %in% c(
      "immunoglobulin_locus",
      "T_cell_receptor_locus",
      "predicted_LOC",
      "pseudogene_or_pseudogene_like",
      "lncRNA_or_antisense"
    )
  ) {
    return("network_evidence_only")
  }

  if (
    entity_class %in% c(
      "mitochondrial",
      "ribosomal",
      "Y_chromosome_associated"
    )
  ) {
    return("excluded_from_automatic_priority")
  }

  "manual_review_required"
}
