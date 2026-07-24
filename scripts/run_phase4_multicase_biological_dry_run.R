#!/usr/bin/env Rscript

# CancerPPIr Phase 4: universal seven-case biological dry run
#
# This script applies one common biological evidence engine to:
#   A01, K01, L01, M01, P01, P02 and R01.
#
# It does not modify the production pipeline or any existing report.
# Its purpose is to identify universal rulebook gaps before production
# integration.
#
# Run from the repository root:
#
#   Rscript scripts/run_phase4_multicase_biological_dry_run.R
#
# Optional positional arguments:
#
#   1 results_root
#   2 output_directory
#
# Defaults:
#
#   results_root:
#     ../results/phase2_architecture_final
#
#   output_directory:
#     ../results/phase4_multicase_biological_dry_run

required_packages <- c(
  "openxlsx"
)

missing_packages <- required_packages[
  !vapply(
    required_packages,
    requireNamespace,
    FUN.VALUE = logical(1),
    quietly = TRUE
  )
]

if (length(missing_packages) > 0L) {
  stop(
    paste0(
      "Required package(s) are not installed: ",
      paste(
        missing_packages,
        collapse = ", "
      ),
      "."
    ),
    call. = FALSE
  )
}

project_root <- normalizePath(
  ".",
  winslash = "/",
  mustWork = TRUE
)

engine_file <- file.path(
  project_root,
  "R",
  "04a_biological_evidence_engine.R"
)

if (!file.exists(engine_file)) {
  stop(
    paste0(
      "Biological evidence engine not found: ",
      engine_file
    ),
    call. = FALSE
  )
}

source(
  engine_file,
  local = FALSE
)

arguments <- commandArgs(
  trailingOnly = TRUE
)

results_root <- if (length(arguments) >= 1L) {
  arguments[[1L]]
} else {
  file.path(
    "..",
    "results",
    "phase2_architecture_final"
  )
}

output_directory <- if (length(arguments) >= 2L) {
  arguments[[2L]]
} else {
  file.path(
    "..",
    "results",
    "phase4_multicase_biological_dry_run"
  )
}

case_map <- data.frame(
  sample_id = c(
    "A01",
    "K01",
    "L01",
    "M01",
    "P01",
    "P02",
    "R01"
  ),
  folder = c(
    "Genes_A",
    "Genes_K",
    "Genes_L",
    "Genes_M",
    "Genes_P01",
    "Genes_P02",
    "Genes_R"
  ),
  stringsAsFactors = FALSE
)

required_filenames <- c(
  analytical = "CancerPPIr_Analytical_Report.xlsx",
  technical = "CancerPPIr_Technical_Report.xlsx"
)

if (!dir.exists(results_root)) {
  stop(
    paste0(
      "Results root does not exist: ",
      results_root
    ),
    call. = FALSE
  )
}

if (dir.exists(output_directory)) {
  existing_files <- list.files(
    output_directory,
    all.files = TRUE,
    no.. = TRUE
  )

  if (length(existing_files) > 0L) {
    stop(
      paste0(
        "Output directory already exists and is not empty: ",
        output_directory,
        "\nRemove it or provide another second argument."
      ),
      call. = FALSE
    )
  }
}

dir.create(
  output_directory,
  recursive = TRUE,
  showWarnings = FALSE
)

normalize_header <- function(x) {
  x <- tolower(
    trimws(
      as.character(x)
    )
  )

  gsub(
    "[^a-z0-9]+",
    "",
    x
  )
}

find_column <- function(data, candidates) {
  if (
    is.null(data) ||
    !is.data.frame(data) ||
    ncol(data) == 0L
  ) {
    return(NA_character_)
  }

  observed <- normalize_header(
    names(data)
  )

  requested <- normalize_header(
    candidates
  )

  index <- match(
    requested,
    observed
  )

  index <- index[
    !is.na(index)
  ]

  if (!length(index)) {
    return(NA_character_)
  }

  names(data)[index[[1L]]]
}

safe_character <- function(x) {
  out <- as.character(x)
  out[is.na(out)] <- ""
  out
}

safe_numeric <- function(x) {
  suppressWarnings(
    as.numeric(
      gsub(
        ",",
        ".",
        as.character(x),
        fixed = TRUE
      )
    )
  )
}

safe_logical <- function(x) {
  if (is.logical(x)) {
    out <- x
    out[is.na(out)] <- FALSE
    return(out)
  }

  normalized <- tolower(
    trimws(
      as.character(x)
    )
  )

  normalized %in% c(
    "true",
    "t",
    "1",
    "yes",
    "y"
  )
}

join_nonempty <- function(
  values,
  separator = "; "
) {
  values <- unique(
    trimws(
      safe_character(values)
    )
  )

  values <- values[
    nzchar(values)
  ]

  paste(
    values,
    collapse = separator
  )
}

write_csv_safe <- function(data, path) {
  utils::write.csv(
    data,
    file = path,
    row.names = FALSE,
    na = ""
  )
}

read_required_sheet <- function(
  workbook,
  sheet_name
) {
  sheets <- openxlsx::getSheetNames(
    workbook
  )

  if (!sheet_name %in% sheets) {
    stop(
      paste0(
        "Required sheet not found in ",
        basename(workbook),
        ": ",
        sheet_name
      ),
      call. = FALSE
    )
  }

  openxlsx::read.xlsx(
    workbook,
    sheet = sheet_name,
    check.names = FALSE,
    detectDates = FALSE
  )
}

first_or_default <- function(
  data,
  column,
  default = NA
) {
  if (
    is.null(data) ||
    nrow(data) == 0L ||
    is.na(column) ||
    !column %in% names(data)
  ) {
    return(default)
  }

  value <- data[[column]][[1L]]

  if (
    length(value) == 0L ||
    is.na(value)
  ) {
    return(default)
  }

  value
}

classify_review_category <- function(
  interpretation_class,
  confidence,
  module_size,
  conflict_detected
) {
  if (identical(
    interpretation_class,
    "technical_or_covariate"
  )) {
    return("technical_or_covariate")
  }

  if (
    identical(
      interpretation_class,
      "mixed_biological"
    ) ||
    isTRUE(conflict_detected)
  ) {
    return("mixed_biological_requires_review")
  }

  if (identical(
    interpretation_class,
    "unresolved"
  )) {
    if (module_size >= 5L) {
      return("probable_rulebook_gap")
    }

    if (module_size >= 2L) {
      return("small_module_insufficient_evidence")
    }

    return("singleton_insufficient_evidence")
  }

  if (confidence %in% c(
    "low",
    "unresolved"
  )) {
    return("resolved_low_confidence")
  }

  "resolved_review_candidate"
}

review_priority_from_category <- function(category) {
  if (category %in% c(
    "probable_rulebook_gap",
    "mixed_biological_requires_review"
  )) {
    return("P1")
  }

  if (category %in% c(
    "resolved_low_confidence",
    "small_module_insufficient_evidence"
  )) {
    return("P2")
  }

  if (category %in% c(
    "singleton_insufficient_evidence",
    "technical_or_covariate"
  )) {
    return("P3")
  }

  "P2"
}

all_module_rows <- list()
all_rule_rows <- list()
all_term_rows <- list()
all_candidate_rows <- list()
all_validation_rows <- list()
all_case_summary_rows <- list()

for (case_index in seq_len(nrow(case_map))) {
  sample_id <- case_map$sample_id[[case_index]]
  case_folder <- file.path(
    results_root,
    case_map$folder[[case_index]]
  )

  analytical_workbook <- file.path(
    case_folder,
    required_filenames[["analytical"]]
  )

  technical_workbook <- file.path(
    case_folder,
    required_filenames[["technical"]]
  )

  missing_case_files <- c(
    analytical_workbook,
    technical_workbook
  )[
    !file.exists(
      c(
        analytical_workbook,
        technical_workbook
      )
    )
  ]

  if (length(missing_case_files) > 0L) {
    stop(
      paste0(
        "Missing workbook(s) for ",
        sample_id,
        ":\n",
        paste0(
          "- ",
          missing_case_files,
          collapse = "\n"
        )
      ),
      call. = FALSE
    )
  }

  message(
    "[phase 4 multicase] Processing ",
    sample_id,
    " from ",
    case_map$folder[[case_index]],
    "."
  )

  node_metrics <- read_required_sheet(
    technical_workbook,
    "Raw node metrics"
  )

  all_modules <- read_required_sheet(
    technical_workbook,
    "Raw all modules"
  )

  module_enrichment <- read_required_sheet(
    technical_workbook,
    "Raw module enrichment"
  )

  node_gene_column <- find_column(
    node_metrics,
    c(
      "gene",
      "gene_symbol"
    )
  )

  node_module_column <- find_column(
    node_metrics,
    c(
      "community_louvain",
      "module",
      "module_id"
    )
  )

  candidate_score_column <- find_column(
    node_metrics,
    c(
      "candidate_score"
    )
  )

  module_id_column <- find_column(
    all_modules,
    c(
      "community_louvain",
      "module",
      "module_id"
    )
  )

  enrichment_module_column <- find_column(
    module_enrichment,
    c(
      "community_louvain",
      "module",
      "module_id"
    )
  )

  enrichment_fdr_column <- find_column(
    module_enrichment,
    c(
      "fdr",
      "false_discovery_rate",
      "padj"
    )
  )

  required_resolved_columns <- c(
    node_gene_column,
    node_module_column,
    candidate_score_column,
    module_id_column,
    enrichment_module_column,
    enrichment_fdr_column
  )

  if (any(is.na(required_resolved_columns))) {
    stop(
      paste0(
        "Required schema could not be resolved for ",
        sample_id,
        "."
      ),
      call. = FALSE
    )
  }

  node_metrics[[node_module_column]] <- safe_numeric(
    node_metrics[[node_module_column]]
  )

  node_metrics[[candidate_score_column]] <- safe_numeric(
    node_metrics[[candidate_score_column]]
  )

  all_modules[[module_id_column]] <- safe_numeric(
    all_modules[[module_id_column]]
  )

  module_enrichment[[enrichment_module_column]] <- safe_numeric(
    module_enrichment[[enrichment_module_column]]
  )

  module_enrichment[[enrichment_fdr_column]] <- safe_numeric(
    module_enrichment[[enrichment_fdr_column]]
  )

  preferred_names_column <- find_column(
    module_enrichment,
    c(
      "preferred_names",
      "matching_genes",
      "genes"
    )
  )

  module_enrichment$matching_genes <- if (
    !is.na(preferred_names_column)
  ) {
    safe_character(
      module_enrichment[[preferred_names_column]]
    )
  } else {
    ""
  }

  old_label_column <- find_column(
    all_modules,
    c(
      "final_functional_label",
      "putative_biological_program",
      "clean_module_label",
      "module_direction"
    )
  )

  old_confidence_column <- find_column(
    all_modules,
    c(
      "label_confidence"
    )
  )

  old_warning_column <- find_column(
    all_modules,
    c(
      "label_warning"
    )
  )

  old_score_column <- find_column(
    all_modules,
    c(
      "label_evidence_score"
    )
  )

  old_themes_column <- find_column(
    all_modules,
    c(
      "supporting_biological_themes"
    )
  )

  module_ids <- sort(
    unique(
      node_metrics[[node_module_column]][
        is.finite(
          node_metrics[[node_module_column]]
        )
      ]
    )
  )

  case_module_rows <- list()
  case_rule_rows <- list()
  case_term_rows <- list()

  for (module_id in module_ids) {
    module_nodes <- node_metrics[
      node_metrics[[node_module_column]] == module_id,
      ,
      drop = FALSE
    ]

    module_nodes <- module_nodes[
      order(
        -module_nodes[[candidate_score_column]],
        safe_character(
          module_nodes[[node_gene_column]]
        )
      ),
      ,
      drop = FALSE
    ]

    module_genes <- phase4_normalize_genes(
      module_nodes[[node_gene_column]]
    )

    module_terms <- module_enrichment[
      module_enrichment[[enrichment_module_column]] ==
        module_id,
      ,
      drop = FALSE
    ]

    old_module_row <- all_modules[
      all_modules[[module_id_column]] == module_id,
      ,
      drop = FALSE
    ]

    evidence <- phase4_annotate_module_evidence(
      genes = module_genes,
      enrichment = module_terms,
      module_id = module_id,
      fdr_threshold = 0.05
    )

    new_summary <- evidence$summary

    review_category <- classify_review_category(
      interpretation_class =
        new_summary$interpretation_class[[1L]],
      confidence =
        new_summary$confidence[[1L]],
      module_size =
        length(module_genes),
      conflict_detected =
        new_summary$conflict_detected[[1L]]
    )

    case_module_rows[[length(case_module_rows) + 1L]] <-
      data.frame(
        sample_id = sample_id,
        source_folder =
          case_map$folder[[case_index]],
        module_id = as.integer(module_id),
        module_size = length(module_genes),
        representative_genes = paste(
          head(
            module_genes,
            15L
          ),
          collapse = ";"
        ),
        member_genes = paste(
          module_genes,
          collapse = ";"
        ),
        old_label = safe_character(
          first_or_default(
            old_module_row,
            old_label_column,
            "not_available"
          )
        ),
        old_confidence = safe_character(
          first_or_default(
            old_module_row,
            old_confidence_column,
            "not_available"
          )
        ),
        old_evidence_score = safe_numeric(
          first_or_default(
            old_module_row,
            old_score_column,
            NA_real_
          )
        ),
        old_supporting_themes = safe_character(
          first_or_default(
            old_module_row,
            old_themes_column,
            "not_available"
          )
        ),
        old_warning = safe_character(
          first_or_default(
            old_module_row,
            old_warning_column,
            "not_available"
          )
        ),
        new_interpretation_class =
          new_summary$interpretation_class[[1L]],
        new_compartment =
          new_summary$compartment[[1L]],
        new_lineage =
          new_summary$lineage[[1L]],
        new_state =
          new_summary$state[[1L]],
        new_process =
          new_summary$process[[1L]],
        new_primary_interpretation =
          new_summary$primary_interpretation[[1L]],
        new_confidence =
          new_summary$confidence[[1L]],
        new_priority_eligible =
          new_summary$priority_eligible[[1L]],
        positive_marker_genes =
          new_summary$positive_marker_genes[[1L]],
        supportive_marker_genes =
          new_summary$supportive_marker_genes[[1L]],
        term_supporting_genes =
          new_summary$term_supporting_genes[[1L]],
        significant_supporting_terms =
          new_summary$significant_supporting_terms[[1L]],
        best_supporting_fdr =
          new_summary$best_supporting_fdr[[1L]],
        conflict_detected =
          new_summary$conflict_detected[[1L]],
        new_warning =
          new_summary$warning[[1L]],
        evidence_rationale =
          new_summary$evidence_rationale[[1L]],
        review_category =
          review_category,
        review_priority =
          review_priority_from_category(
            review_category
          ),
        stringsAsFactors = FALSE
      )

    rule_table <- evidence$rule_evaluations
    rule_table$sample_id <- sample_id
    rule_table$module_id <- as.integer(module_id)
    rule_table$module_size <- length(module_genes)

    case_rule_rows[[length(case_rule_rows) + 1L]] <-
      rule_table[
        ,
        c(
          "sample_id",
          "module_id",
          "module_size",
          setdiff(
            names(rule_table),
            c(
              "sample_id",
              "module_id",
              "module_size"
            )
          )
        ),
        drop = FALSE
      ]

    term_table <- evidence$significant_terms

    if (nrow(term_table) > 0L) {
      term_table$sample_id <- sample_id
      term_table$module_id <- as.integer(module_id)
      term_table$module_size <- length(module_genes)

      case_term_rows[[length(case_term_rows) + 1L]] <-
        term_table[
          ,
          c(
            "sample_id",
            "module_id",
            "module_size",
            setdiff(
              names(term_table),
              c(
                "sample_id",
                "module_id",
                "module_size"
              )
            )
          ),
          drop = FALSE
        ]
    }
  }

  case_modules <- do.call(
    rbind,
    case_module_rows
  )

  case_rules <- do.call(
    rbind,
    case_rule_rows
  )

  case_terms <- if (length(case_term_rows) > 0L) {
    do.call(
      rbind,
      case_term_rows
    )
  } else {
    data.frame(
      sample_id = character(),
      module_id = integer(),
      module_size = integer(),
      source = character(),
      term_id = character(),
      description = character(),
      fdr = numeric(),
      supporting_genes = character(),
      is_significant = logical(),
      is_generic = logical(),
      stringsAsFactors = FALSE
    )
  }

  candidate_audit <- node_metrics

  candidate_audit$sample_id <- sample_id
  candidate_audit$gene <- safe_character(
    candidate_audit[[node_gene_column]]
  )

  candidate_audit$module_id <- safe_numeric(
    candidate_audit[[node_module_column]]
  )

  candidate_audit$candidate_score <- safe_numeric(
    candidate_audit[[candidate_score_column]]
  )

  candidate_audit$entity_class <- vapply(
    candidate_audit$gene,
    phase4_classify_entity,
    FUN.VALUE = character(1)
  )

  candidate_audit$candidate_eligibility <- vapply(
    candidate_audit$entity_class,
    phase4_candidate_eligibility,
    FUN.VALUE = character(1)
  )

  candidate_audit <- candidate_audit[
    order(
      -candidate_audit$candidate_score,
      candidate_audit$gene
    ),
    ,
    drop = FALSE
  ]

  candidate_audit$candidate_rank_within_case <-
    seq_len(
      nrow(candidate_audit)
    )

  candidate_audit <- merge(
    candidate_audit,
    case_modules[
      ,
      c(
        "sample_id",
        "module_id",
        "new_primary_interpretation",
        "new_confidence",
        "new_priority_eligible",
        "review_category",
        "review_priority",
        "new_warning"
      ),
      drop = FALSE
    ],
    by = c(
      "sample_id",
      "module_id"
    ),
    all.x = TRUE,
    sort = FALSE
  )

  candidate_audit <- candidate_audit[
    order(
      candidate_audit$candidate_rank_within_case
    ),
    ,
    drop = FALSE
  ]

  candidate_columns <- unique(
    c(
      "sample_id",
      "candidate_rank_within_case",
      "gene",
      "STRING_id",
      "entity_class",
      "candidate_eligibility",
      "candidate_score",
      "degree",
      "betweenness",
      "stress_centrality",
      "logFC",
      "pvalue",
      "module_id",
      "new_primary_interpretation",
      "new_confidence",
      "new_priority_eligible",
      "review_category",
      "review_priority",
      "new_warning"
    )
  )

  candidate_columns <- candidate_columns[
    candidate_columns %in%
      names(candidate_audit)
  ]

  candidate_audit <- candidate_audit[
    ,
    candidate_columns,
    drop = FALSE
  ]

  all_terms_significant <- (
    nrow(case_terms) == 0L ||
      all(
        is.finite(
          case_terms$fdr
        ) &
          case_terms$fdr <= 0.05
      )
  )

  technical_priority_contradiction <- any(
    case_modules$new_interpretation_class ==
      "technical_or_covariate" &
      safe_logical(
        case_modules$new_priority_eligible
      )
  )

  priority_confidence_invalid <- any(
    safe_logical(
      case_modules$new_priority_eligible
    ) &
      !case_modules$new_confidence %in% c(
        "high",
        "moderate"
      )
  )

  duplicate_modules <- any(
    duplicated(
      paste(
        case_modules$sample_id,
        case_modules$module_id,
        sep = "::"
      )
    )
  )

  forbidden_language_pattern <- paste(
    c(
      "cell fraction",
      "cellular fraction",
      "estimated proportion",
      "cell proportion",
      "deconvoluted cell",
      "deconvolved cell",
      "percentage of .* cells"
    ),
    collapse = "|"
  )

  forbidden_language_detected <- any(
    grepl(
      forbidden_language_pattern,
      case_modules$evidence_rationale,
      ignore.case = TRUE,
      perl = TRUE
    )
  )

  validation <- data.frame(
    sample_id = sample_id,
    check_id = c(
      "significant_terms_only",
      "technical_modules_not_priority",
      "priority_requires_moderate_or_high_confidence",
      "unique_module_rows",
      "no_cell_fraction_claims",
      "large_unresolved_modules"
    ),
    status = c(
      if (all_terms_significant) "PASS" else "FAIL",
      if (!technical_priority_contradiction) "PASS" else "FAIL",
      if (!priority_confidence_invalid) "PASS" else "FAIL",
      if (!duplicate_modules) "PASS" else "FAIL",
      if (!forbidden_language_detected) "PASS" else "FAIL",
      if (any(
        case_modules$review_category ==
          "probable_rulebook_gap"
      )) {
        "WARN"
      } else {
        "PASS"
      }
    ),
    evidence = c(
      if (nrow(case_terms) > 0L) {
        paste0(
          "Maximum admitted FDR: ",
          format(
            max(
              case_terms$fdr,
              na.rm = TRUE
            ),
            digits = 5
          )
        )
      } else {
        "No significant specific terms admitted."
      },
      paste0(
        sum(
          case_modules$new_interpretation_class ==
            "technical_or_covariate"
        ),
        " technical/covariate module(s)."
      ),
      paste0(
        sum(
          safe_logical(
            case_modules$new_priority_eligible
          )
        ),
        " priority-eligible module(s)."
      ),
      paste0(
        nrow(case_modules),
        " unique module row(s)."
      ),
      if (!forbidden_language_detected) {
        "No prohibited cell-fraction language detected."
      } else {
        "Prohibited deconvolution/cell-fraction language detected."
      },
      paste0(
        sum(
          case_modules$review_category ==
            "probable_rulebook_gap"
        ),
        " unresolved module(s) with size >= 5."
      )
    ),
    stringsAsFactors = FALSE
  )

  case_summary <- data.frame(
    sample_id = sample_id,
    source_folder =
      case_map$folder[[case_index]],
    module_count = nrow(case_modules),
    network_node_count = nrow(candidate_audit),
    priority_eligible_modules = sum(
      safe_logical(
        case_modules$new_priority_eligible
      )
    ),
    technical_or_covariate_modules = sum(
      case_modules$new_interpretation_class ==
        "technical_or_covariate"
    ),
    mixed_biological_modules = sum(
      case_modules$new_interpretation_class ==
        "mixed_biological"
    ),
    unresolved_modules = sum(
      case_modules$new_interpretation_class ==
        "unresolved"
    ),
    probable_rulebook_gaps = sum(
      case_modules$review_category ==
        "probable_rulebook_gap"
    ),
    singleton_unresolved = sum(
      case_modules$review_category ==
        "singleton_insufficient_evidence"
    ),
    small_unresolved = sum(
      case_modules$review_category ==
        "small_module_insufficient_evidence"
    ),
    significant_specific_term_rows =
      nrow(case_terms),
    noncanonical_or_special_candidates = sum(
      candidate_audit$candidate_eligibility !=
        "review_ready_canonical"
    ),
    validation_failures = sum(
      validation$status == "FAIL"
    ),
    validation_warnings = sum(
      validation$status == "WARN"
    ),
    stringsAsFactors = FALSE
  )

  all_module_rows[[sample_id]] <- case_modules
  all_rule_rows[[sample_id]] <- case_rules
  all_term_rows[[sample_id]] <- case_terms
  all_candidate_rows[[sample_id]] <- candidate_audit
  all_validation_rows[[sample_id]] <- validation
  all_case_summary_rows[[sample_id]] <- case_summary
}

module_comparison <- do.call(
  rbind,
  all_module_rows
)

rule_evidence <- do.call(
  rbind,
  all_rule_rows
)

significant_terms <- do.call(
  rbind,
  all_term_rows
)

candidate_audit <- do.call(
  rbind,
  all_candidate_rows
)

validation_table <- do.call(
  rbind,
  all_validation_rows
)

case_summary <- do.call(
  rbind,
  all_case_summary_rows
)

module_comparison <- module_comparison[
  order(
    module_comparison$sample_id,
    module_comparison$review_priority,
    -module_comparison$module_size,
    module_comparison$module_id
  ),
  ,
  drop = FALSE
]

rule_evidence <- rule_evidence[
  order(
    rule_evidence$sample_id,
    rule_evidence$module_id,
    rule_evidence$axis,
    -rule_evidence$evidence_score,
    rule_evidence$rule_id
  ),
  ,
  drop = FALSE
]

significant_terms <- significant_terms[
  order(
    significant_terms$sample_id,
    significant_terms$module_id,
    significant_terms$fdr,
    significant_terms$description
  ),
  ,
  drop = FALSE
]

candidate_audit <- candidate_audit[
  order(
    candidate_audit$sample_id,
    candidate_audit$candidate_rank_within_case
  ),
  ,
  drop = FALSE
]

validation_table <- validation_table[
  order(
    validation_table$sample_id,
    validation_table$check_id
  ),
  ,
  drop = FALSE
]

case_summary <- case_summary[
  match(
    case_map$sample_id,
    case_summary$sample_id
  ),
  ,
  drop = FALSE
]

overall_summary <- data.frame(
  case_count = nrow(case_summary),
  total_modules = sum(
    case_summary$module_count
  ),
  total_network_nodes = sum(
    case_summary$network_node_count
  ),
  total_priority_eligible_modules = sum(
    case_summary$priority_eligible_modules
  ),
  total_technical_modules = sum(
    case_summary$technical_or_covariate_modules
  ),
  total_mixed_modules = sum(
    case_summary$mixed_biological_modules
  ),
  total_unresolved_modules = sum(
    case_summary$unresolved_modules
  ),
  total_probable_rulebook_gaps = sum(
    case_summary$probable_rulebook_gaps
  ),
  total_special_candidates = sum(
    case_summary$noncanonical_or_special_candidates
  ),
  validation_failures = sum(
    validation_table$status == "FAIL"
  ),
  validation_warnings = sum(
    validation_table$status == "WARN"
  ),
  multicase_status = if (
    any(
      validation_table$status == "FAIL"
    )
  ) {
    "MULTICASE_DRY_RUN_HAS_TECHNICAL_FAILURES"
  } else if (
    any(
      validation_table$status == "WARN"
    )
  ) {
    "MULTICASE_DRY_RUN_READY_FOR_RULEBOOK_REVIEW"
  } else {
    "MULTICASE_DRY_RUN_PASSED_ALL_GATES"
  },
  stringsAsFactors = FALSE
)

write_csv_safe(
  overall_summary,
  file.path(
    output_directory,
    "phase_4_multicase_overall_summary.csv"
  )
)

write_csv_safe(
  case_summary,
  file.path(
    output_directory,
    "phase_4_multicase_case_summary.csv"
  )
)

write_csv_safe(
  module_comparison,
  file.path(
    output_directory,
    "phase_4_multicase_module_comparison.csv"
  )
)

write_csv_safe(
  rule_evidence,
  file.path(
    output_directory,
    "phase_4_multicase_rule_evidence.csv"
  )
)

write_csv_safe(
  significant_terms,
  file.path(
    output_directory,
    "phase_4_multicase_significant_terms.csv"
  )
)

write_csv_safe(
  candidate_audit,
  file.path(
    output_directory,
    "phase_4_multicase_candidate_entity_audit.csv"
  )
)

write_csv_safe(
  validation_table,
  file.path(
    output_directory,
    "phase_4_multicase_validation.csv"
  )
)

workbook <- openxlsx::createWorkbook(
  creator = "CancerPPIr Phase 4"
)

workbook_tables <- list(
  "Overall summary" = overall_summary,
  "Case summary" = case_summary,
  "Module comparison" = module_comparison,
  "Rule evidence" = rule_evidence,
  "Significant terms" = significant_terms,
  "Candidate entities" = candidate_audit,
  "Validation" = validation_table
)

header_style <- openxlsx::createStyle(
  textDecoration = "bold",
  halign = "center",
  valign = "center",
  wrapText = TRUE
)

body_style <- openxlsx::createStyle(
  valign = "top",
  wrapText = TRUE
)

for (sheet_name in names(workbook_tables)) {
  table <- workbook_tables[[sheet_name]]

  openxlsx::addWorksheet(
    workbook,
    sheet_name
  )

  openxlsx::writeDataTable(
    workbook,
    sheet = sheet_name,
    x = table,
    tableStyle = "TableStyleMedium2",
    withFilter = TRUE
  )

  if (ncol(table) > 0L) {
    openxlsx::addStyle(
      workbook,
      sheet = sheet_name,
      style = header_style,
      rows = 1L,
      cols = seq_len(ncol(table)),
      gridExpand = TRUE,
      stack = TRUE
    )

    if (nrow(table) > 0L) {
      openxlsx::addStyle(
        workbook,
        sheet = sheet_name,
        style = body_style,
        rows = seq.int(
          2L,
          nrow(table) + 1L
        ),
        cols = seq_len(ncol(table)),
        gridExpand = TRUE,
        stack = TRUE
      )
    }

    openxlsx::freezePane(
      workbook,
      sheet = sheet_name,
      firstActiveRow = 2L,
      firstActiveCol = if (
        sheet_name %in% c(
          "Module comparison",
          "Rule evidence",
          "Significant terms",
          "Candidate entities"
        )
      ) {
        3L
      } else {
        1L
      }
    )

    widths <- pmin(
      40,
      pmax(
        10,
        nchar(
          names(table)
        ) + 2L
      )
    )

    openxlsx::setColWidths(
      workbook,
      sheet = sheet_name,
      cols = seq_len(ncol(table)),
      widths = widths
    )
  }
}

workbook_file <- file.path(
  output_directory,
  "Phase4_Multicase_Biological_Dry_Run.xlsx"
)

openxlsx::saveWorkbook(
  workbook,
  workbook_file,
  overwrite = TRUE
)

readback_sheets <- openxlsx::getSheetNames(
  workbook_file
)

if (!identical(
  readback_sheets,
  names(workbook_tables)
)) {
  stop(
    "Dry-run workbook read-back failed: sheet order mismatch.",
    call. = FALSE
  )
}

report_lines <- c(
  "# CancerPPIr Phase 4 — universal seven-case biological dry run",
  "",
  paste0(
    "**Status:** ",
    overall_summary$multicase_status[[1L]]
  ),
  "",
  "## Scope",
  "",
  "One common evidence engine was applied to A01, K01, L01, M01, P01, P02 and R01. No sample-specific rule was used. Production labeling, reporting and pipeline files were not modified.",
  "",
  "The output describes marker- and enrichment-supported cell context. It does not estimate cell fractions and is not transcriptomic deconvolution.",
  "",
  "## Case summary",
  "",
  "| Case | Modules | Nodes | Priority modules | Technical | Mixed | Unresolved | Probable rulebook gaps | Special candidates | Failures | Warnings |",
  "|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|"
)

for (row_index in seq_len(nrow(case_summary))) {
  row <- case_summary[
    row_index,
    ,
    drop = FALSE
  ]

  report_lines <- c(
    report_lines,
    paste0(
      "| ",
      row$sample_id[[1L]],
      " | ",
      row$module_count[[1L]],
      " | ",
      row$network_node_count[[1L]],
      " | ",
      row$priority_eligible_modules[[1L]],
      " | ",
      row$technical_or_covariate_modules[[1L]],
      " | ",
      row$mixed_biological_modules[[1L]],
      " | ",
      row$unresolved_modules[[1L]],
      " | ",
      row$probable_rulebook_gaps[[1L]],
      " | ",
      row$noncanonical_or_special_candidates[[1L]],
      " | ",
      row$validation_failures[[1L]],
      " | ",
      row$validation_warnings[[1L]],
      " |"
    )
  )
}

report_lines <- c(
  report_lines,
  "",
  "## Universal rulebook review priorities",
  "",
  paste0(
    "- P1 probable rulebook gaps: ",
    sum(
      module_comparison$review_category ==
        "probable_rulebook_gap"
    )
  ),
  paste0(
    "- P1 mixed biological modules: ",
    sum(
      module_comparison$review_category ==
        "mixed_biological_requires_review"
    )
  ),
  paste0(
    "- P2 low-confidence resolved modules: ",
    sum(
      module_comparison$review_category ==
        "resolved_low_confidence"
    )
  ),
  paste0(
    "- Small unresolved modules: ",
    sum(
      module_comparison$review_category ==
        "small_module_insufficient_evidence"
    )
  ),
  paste0(
    "- Singleton unresolved modules: ",
    sum(
      module_comparison$review_category ==
        "singleton_insufficient_evidence"
    )
  ),
  "",
  "## Interpretation",
  "",
  "The primary purpose of this dry run is to identify recurring rulebook gaps across diseases. Corrections should be implemented as universal biological rules and tested across all seven cases before production integration.",
  ""
)

writeLines(
  report_lines,
  con = file.path(
    output_directory,
    "phase_4_multicase_biological_dry_run_report.md"
  ),
  useBytes = TRUE
)

cat(
  "\nPHASE 4 MULTICASE BIOLOGICAL DRY RUN COMPLETED\n"
)

print(
  overall_summary,
  row.names = FALSE
)

cat(
  "\nCase summary:\n"
)

print(
  case_summary,
  row.names = FALSE
)

cat(
  "\nReview files written to:\n  ",
  normalizePath(
    output_directory,
    winslash = "/",
    mustWork = TRUE
  ),
  "\n",
  sep = ""
)

cat(
  "\nProduction labeling, reporting and pipeline files were not modified.\n"
)