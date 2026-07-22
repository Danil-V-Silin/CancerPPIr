#!/usr/bin/env Rscript

# CancerPPIr Phase 4.3C:
# seven-case shadow validation of the production biological-evidence adapter.
#
# Purpose:
#   1. Read the existing Phase 2 technical workbooks for all seven cases.
#   2. Pass their node metrics and local STRING module enrichment through
#      phase4_bind_pipeline_evidence().
#   3. Compare the adapter output against the frozen Phase 4 v5 dry-run result.
#   4. Fail on any module-level biological interpretation mismatch.
#
# This script does not modify production code or existing reports.
#
# Run from the repository root:
#
#   Rscript scripts/run_phase4_multicase_adapter_shadow.R
#
# Optional positional arguments:
#
#   1. Phase 2 results root
#   2. Frozen v5 dry-run directory
#   3. New shadow-validation output directory
#
# Defaults:
#
#   ../results/phase2_architecture_final
#   ../results/phase4_multicase_biological_dry_run_v5
#   ../results/phase4_multicase_adapter_shadow_v1

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
      paste(missing_packages, collapse = ", "),
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

loader_file <- file.path(
  project_root,
  "R",
  "load_all.R"
)

if (!file.exists(loader_file)) {
  stop(
    paste0(
      "Module loader not found: ",
      loader_file
    ),
    call. = FALSE
  )
}

source(
  loader_file,
  local = FALSE
)

loaded_files <- load_cancerppir_modules(
  project_root = project_root,
  envir = .GlobalEnv
)

expected_adapter_file <- "04b_biological_evidence_adapter.R"

if (!expected_adapter_file %in% basename(loaded_files)) {
  stop(
    paste0(
      "The standard loader did not load ",
      expected_adapter_file,
      "."
    ),
    call. = FALSE
  )
}

if (!exists(
  "phase4_bind_pipeline_evidence",
  envir = .GlobalEnv,
  inherits = FALSE
)) {
  stop(
    "phase4_bind_pipeline_evidence is unavailable after standard loading.",
    call. = FALSE
  )
}

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

reference_directory <- if (length(arguments) >= 2L) {
  arguments[[2L]]
} else {
  file.path(
    "..",
    "results",
    "phase4_multicase_biological_dry_run_v5"
  )
}

output_directory <- if (length(arguments) >= 3L) {
  arguments[[3L]]
} else {
  file.path(
    "..",
    "results",
    "phase4_multicase_adapter_shadow_v1"
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

technical_filename <- "CancerPPIr_Technical_Report.xlsx"

reference_module_file <- file.path(
  reference_directory,
  "phase_4_multicase_module_comparison.csv"
)

reference_overall_file <- file.path(
  reference_directory,
  "phase_4_multicase_overall_summary.csv"
)

required_paths <- c(
  results_root = results_root,
  reference_directory = reference_directory,
  reference_module_file = reference_module_file,
  reference_overall_file = reference_overall_file
)

missing_paths <- required_paths[
  !file.exists(required_paths) &
    !dir.exists(required_paths)
]

if (length(missing_paths) > 0L) {
  stop(
    paste0(
      "Required input path(s) are missing:\n",
      paste0(
        "- ",
        names(missing_paths),
        ": ",
        missing_paths,
        collapse = "\n"
      )
    ),
    call. = FALSE
  )
}

if (dir.exists(output_directory)) {
  existing_output <- list.files(
    output_directory,
    all.files = TRUE,
    no.. = TRUE
  )

  if (length(existing_output) > 0L) {
    stop(
      paste0(
        "Output directory already exists and is not empty: ",
        output_directory,
        "\nRemove it or provide a different third argument."
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

find_column <- function(
  data,
  candidates
) {
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

  names(data)[
    index[[1L]]
  ]
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

safe_character <- function(x) {
  output <- as.character(x)
  output[is.na(output)] <- ""
  trimws(output)
}

safe_logical <- function(x) {
  if (is.logical(x)) {
    output <- x
    output[is.na(output)] <- FALSE
    return(output)
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

write_csv_safe <- function(
  data,
  path
) {
  utils::write.csv(
    data,
    file = path,
    row.names = FALSE,
    na = ""
  )
}

normalize_comparison_text <- function(x) {
  x <- safe_character(x)

  x[x %in% c(
    "NA",
    "N/A",
    "na",
    "n/a",
    "not_available"
  )] <- ""

  x
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

all_module_rows <- list()
all_validation_rows <- list()
all_case_summary_rows <- list()

for (case_index in seq_len(nrow(case_map))) {
  sample_id <- case_map$sample_id[[case_index]]

  case_folder <- file.path(
    results_root,
    case_map$folder[[case_index]]
  )

  technical_workbook <- file.path(
    case_folder,
    technical_filename
  )

  if (!file.exists(technical_workbook)) {
    stop(
      paste0(
        "Technical workbook is missing for ",
        sample_id,
        ": ",
        technical_workbook
      ),
      call. = FALSE
    )
  }

  message(
    "[phase 4 adapter shadow] Processing ",
    sample_id,
    " from ",
    case_map$folder[[case_index]],
    "."
  )

  raw_node_metrics <- read_required_sheet(
    technical_workbook,
    "Raw node metrics"
  )

  raw_module_enrichment <- read_required_sheet(
    technical_workbook,
    "Raw module enrichment"
  )

  node_gene_column <- find_column(
    raw_node_metrics,
    c(
      "gene",
      "gene_symbol"
    )
  )

  node_module_column <- find_column(
    raw_node_metrics,
    c(
      "community_louvain",
      "module",
      "module_id"
    )
  )

  candidate_score_column <- find_column(
    raw_node_metrics,
    "candidate_score"
  )

  enrichment_module_column <- find_column(
    raw_module_enrichment,
    c(
      "community_louvain",
      "module",
      "module_id"
    )
  )

  enrichment_fdr_column <- find_column(
    raw_module_enrichment,
    c(
      "fdr",
      "false_discovery_rate",
      "padj"
    )
  )

  unresolved_columns <- c(
    node_gene_column,
    node_module_column,
    candidate_score_column,
    enrichment_module_column,
    enrichment_fdr_column
  )

  if (any(is.na(unresolved_columns))) {
    stop(
      paste0(
        "Required workbook schema could not be resolved for ",
        sample_id,
        "."
      ),
      call. = FALSE
    )
  }

  node_metrics <- as.data.frame(
    raw_node_metrics,
    stringsAsFactors = FALSE
  )

  names(node_metrics)[
    names(node_metrics) == node_gene_column
  ] <- "gene"

  names(node_metrics)[
    names(node_metrics) == node_module_column
  ] <- "community_louvain"

  names(node_metrics)[
    names(node_metrics) == candidate_score_column
  ] <- "candidate_score"

  node_metrics$gene <- safe_character(
    node_metrics$gene
  )

  node_metrics$community_louvain <- safe_numeric(
    node_metrics$community_louvain
  )

  node_metrics$candidate_score <- safe_numeric(
    node_metrics$candidate_score
  )

  module_enrichment <- as.data.frame(
    raw_module_enrichment,
    stringsAsFactors = FALSE
  )

  names(module_enrichment)[
    names(module_enrichment) == enrichment_module_column
  ] <- "community_louvain"

  names(module_enrichment)[
    names(module_enrichment) == enrichment_fdr_column
  ] <- "fdr"

  module_enrichment$community_louvain <- safe_numeric(
    module_enrichment$community_louvain
  )

  module_enrichment$fdr <- safe_numeric(
    module_enrichment$fdr
  )

  adapter_result <- phase4_bind_pipeline_evidence(
    node_metrics = node_metrics,
    module_enrichment = module_enrichment,
    fdr_threshold = 0.05
  )

  module_annotations <- adapter_result$module_annotations
  module_annotations$sample_id <- sample_id
  module_annotations$module_id <- safe_numeric(
    module_annotations$community_louvain
  )

  module_annotations$review_category <- mapply(
    classify_review_category,
    interpretation_class =
      module_annotations$interpretation_class,
    confidence =
      module_annotations$confidence,
    module_size =
      module_annotations$network_node_count,
    conflict_detected =
      module_annotations$conflict_detected,
    USE.NAMES = FALSE
  )

  module_annotations <- module_annotations[
    ,
    c(
      "sample_id",
      "module_id",
      setdiff(
        names(module_annotations),
        c(
          "sample_id",
          "module_id"
        )
      )
    ),
    drop = FALSE
  ]

  adapter_validation <- adapter_result$validation
  adapter_validation$sample_id <- sample_id
  adapter_validation$evidence <- ""

  large_unresolved_count <- sum(
    module_annotations$review_category ==
      "probable_rulebook_gap"
  )

  gap_validation <- data.frame(
    check_id = "large_unresolved_modules",
    status = if (
      large_unresolved_count > 0L
    ) {
      "WARN"
    } else {
      "PASS"
    },
    sample_id = sample_id,
    evidence = paste0(
      large_unresolved_count,
      " unresolved module(s) with size >= 5."
    ),
    stringsAsFactors = FALSE
  )

  validation <- rbind(
    adapter_validation[
      ,
      c(
        "sample_id",
        "check_id",
        "status",
        "evidence"
      ),
      drop = FALSE
    ],
    gap_validation[
      ,
      c(
        "sample_id",
        "check_id",
        "status",
        "evidence"
      ),
      drop = FALSE
    ]
  )

  case_summary <- data.frame(
    sample_id = sample_id,
    source_folder =
      case_map$folder[[case_index]],
    module_count =
      nrow(module_annotations),
    network_node_count =
      nrow(adapter_result$node_annotations),
    priority_eligible_modules =
      sum(
        safe_logical(
          module_annotations$priority_eligible
        )
      ),
    technical_or_covariate_modules =
      sum(
        module_annotations$interpretation_class ==
          "technical_or_covariate"
      ),
    mixed_biological_modules =
      sum(
        module_annotations$interpretation_class ==
          "mixed_biological"
      ),
    unresolved_modules =
      sum(
        module_annotations$interpretation_class ==
          "unresolved"
      ),
    probable_rulebook_gaps =
      large_unresolved_count,
    noncanonical_or_special_candidates =
      sum(
        adapter_result$node_annotations$
          candidate_eligibility !=
          "review_ready_canonical"
      ),
    validation_failures =
      sum(validation$status == "FAIL"),
    validation_warnings =
      sum(validation$status == "WARN"),
    stringsAsFactors = FALSE
  )

  all_module_rows[[sample_id]] <- module_annotations
  all_validation_rows[[sample_id]] <- validation
  all_case_summary_rows[[sample_id]] <- case_summary
}

adapter_modules <- do.call(
  rbind,
  all_module_rows
)

adapter_validation <- do.call(
  rbind,
  all_validation_rows
)

case_summary <- do.call(
  rbind,
  all_case_summary_rows
)

rownames(adapter_modules) <- NULL
rownames(adapter_validation) <- NULL
rownames(case_summary) <- NULL

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
  total_modules =
    sum(case_summary$module_count),
  total_network_nodes =
    sum(case_summary$network_node_count),
  total_priority_eligible_modules =
    sum(case_summary$priority_eligible_modules),
  total_technical_modules =
    sum(case_summary$technical_or_covariate_modules),
  total_mixed_modules =
    sum(case_summary$mixed_biological_modules),
  total_unresolved_modules =
    sum(case_summary$unresolved_modules),
  total_probable_rulebook_gaps =
    sum(case_summary$probable_rulebook_gaps),
  total_special_candidates =
    sum(
      case_summary$
        noncanonical_or_special_candidates
    ),
  validation_failures =
    sum(adapter_validation$status == "FAIL"),
  validation_warnings =
    sum(adapter_validation$status == "WARN"),
  stringsAsFactors = FALSE
)

reference_modules <- utils::read.csv(
  reference_module_file,
  stringsAsFactors = FALSE,
  check.names = FALSE
)

reference_overall <- utils::read.csv(
  reference_overall_file,
  stringsAsFactors = FALSE,
  check.names = FALSE
)

required_reference_module_columns <- c(
  "sample_id",
  "module_id",
  "new_interpretation_class",
  "new_primary_interpretation",
  "new_confidence",
  "new_priority_eligible",
  "conflict_detected",
  "new_warning"
)

missing_reference_columns <- setdiff(
  required_reference_module_columns,
  names(reference_modules)
)

if (length(missing_reference_columns) > 0L) {
  stop(
    paste0(
      "Frozen v5 module comparison is missing column(s): ",
      paste(
        missing_reference_columns,
        collapse = ", "
      ),
      "."
    ),
    call. = FALSE
  )
}

reference_modules$module_id <- safe_numeric(
  reference_modules$module_id
)

adapter_comparison <- adapter_modules[
  ,
  c(
    "sample_id",
    "module_id",
    "network_node_count",
    "interpretation_class",
    "primary_interpretation",
    "confidence",
    "priority_eligible",
    "conflict_detected",
    "warning",
    "best_supporting_fdr"
  ),
  drop = FALSE
]

reference_comparison <- reference_modules[
  ,
  c(
    "sample_id",
    "module_id",
    "module_size",
    "new_interpretation_class",
    "new_primary_interpretation",
    "new_confidence",
    "new_priority_eligible",
    "conflict_detected",
    "new_warning",
    "best_supporting_fdr"
  ),
  drop = FALSE
]

names(reference_comparison) <- c(
  "sample_id",
  "module_id",
  "reference_module_size",
  "reference_interpretation_class",
  "reference_primary_interpretation",
  "reference_confidence",
  "reference_priority_eligible",
  "reference_conflict_detected",
  "reference_warning",
  "reference_best_supporting_fdr"
)

names(adapter_comparison) <- c(
  "sample_id",
  "module_id",
  "adapter_module_size",
  "adapter_interpretation_class",
  "adapter_primary_interpretation",
  "adapter_confidence",
  "adapter_priority_eligible",
  "adapter_conflict_detected",
  "adapter_warning",
  "adapter_best_supporting_fdr"
)

module_concordance <- merge(
  reference_comparison,
  adapter_comparison,
  by = c(
    "sample_id",
    "module_id"
  ),
  all = TRUE,
  sort = FALSE
)

module_concordance$module_size_match <-
  module_concordance$reference_module_size ==
  module_concordance$adapter_module_size

module_concordance$interpretation_class_match <-
  normalize_comparison_text(
    module_concordance$
      reference_interpretation_class
  ) ==
  normalize_comparison_text(
    module_concordance$
      adapter_interpretation_class
  )

module_concordance$primary_interpretation_match <-
  normalize_comparison_text(
    module_concordance$
      reference_primary_interpretation
  ) ==
  normalize_comparison_text(
    module_concordance$
      adapter_primary_interpretation
  )

module_concordance$confidence_match <-
  normalize_comparison_text(
    module_concordance$
      reference_confidence
  ) ==
  normalize_comparison_text(
    module_concordance$
      adapter_confidence
  )

module_concordance$priority_eligible_match <-
  safe_logical(
    module_concordance$
      reference_priority_eligible
  ) ==
  safe_logical(
    module_concordance$
      adapter_priority_eligible
  )

module_concordance$conflict_detected_match <-
  safe_logical(
    module_concordance$
      reference_conflict_detected
  ) ==
  safe_logical(
    module_concordance$
      adapter_conflict_detected
  )

module_concordance$warning_match <-
  normalize_comparison_text(
    module_concordance$
      reference_warning
  ) ==
  normalize_comparison_text(
    module_concordance$
      adapter_warning
  )

reference_fdr <- safe_numeric(
  module_concordance$
    reference_best_supporting_fdr
)

adapter_fdr <- safe_numeric(
  module_concordance$
    adapter_best_supporting_fdr
)

module_concordance$best_supporting_fdr_match <-
  (
    is.na(reference_fdr) &
      is.na(adapter_fdr)
  ) |
  (
    is.finite(reference_fdr) &
      is.finite(adapter_fdr) &
      abs(reference_fdr - adapter_fdr) <= 1e-12
  )

match_columns <- c(
  "module_size_match",
  "interpretation_class_match",
  "primary_interpretation_match",
  "confidence_match",
  "priority_eligible_match",
  "conflict_detected_match",
  "warning_match",
  "best_supporting_fdr_match"
)

module_concordance$all_fields_match <- apply(
  module_concordance[
    ,
    match_columns,
    drop = FALSE
  ],
  1L,
  function(values) {
    all(
      !is.na(values) &
        values
    )
  }
)

module_concordance <- module_concordance[
  order(
    match(
      module_concordance$sample_id,
      case_map$sample_id
    ),
    module_concordance$module_id
  ),
  ,
  drop = FALSE
]

overall_fields <- intersect(
  names(overall_summary),
  names(reference_overall)
)

overall_comparison <- data.frame(
  metric = overall_fields,
  reference_value = vapply(
    overall_fields,
    function(field) {
      as.character(
        reference_overall[[field]][[1L]]
      )
    },
    FUN.VALUE = character(1)
  ),
  adapter_value = vapply(
    overall_fields,
    function(field) {
      as.character(
        overall_summary[[field]][[1L]]
      )
    },
    FUN.VALUE = character(1)
  ),
  stringsAsFactors = FALSE
)

overall_comparison$match <-
  overall_comparison$reference_value ==
  overall_comparison$adapter_value

shadow_validation <- data.frame(
  check_id = c(
    "all_reference_modules_present",
    "all_adapter_modules_present",
    "all_module_fields_match_frozen_v5",
    "all_overall_totals_match_frozen_v5",
    "adapter_internal_validation_has_no_failures"
  ),
  status = c(
    if (
      nrow(module_concordance) ==
        nrow(reference_modules)
    ) {
      "PASS"
    } else {
      "FAIL"
    },
    if (
      nrow(module_concordance) ==
        nrow(adapter_modules)
    ) {
      "PASS"
    } else {
      "FAIL"
    },
    if (all(module_concordance$all_fields_match)) {
      "PASS"
    } else {
      "FAIL"
    },
    if (all(overall_comparison$match)) {
      "PASS"
    } else {
      "FAIL"
    },
    if (!any(adapter_validation$status == "FAIL")) {
      "PASS"
    } else {
      "FAIL"
    }
  ),
  evidence = c(
    paste0(
      nrow(reference_modules),
      " frozen v5 module row(s); ",
      nrow(module_concordance),
      " comparison row(s)."
    ),
    paste0(
      nrow(adapter_modules),
      " adapter module row(s); ",
      nrow(module_concordance),
      " comparison row(s)."
    ),
    paste0(
      sum(module_concordance$all_fields_match),
      "/",
      nrow(module_concordance),
      " module row(s) match all audited fields."
    ),
    paste0(
      sum(overall_comparison$match),
      "/",
      nrow(overall_comparison),
      " overall metric(s) match."
    ),
    paste0(
      sum(adapter_validation$status == "FAIL"),
      " adapter validation failure(s)."
    )
  ),
  stringsAsFactors = FALSE
)

shadow_status <- if (
  any(shadow_validation$status == "FAIL")
) {
  "ADAPTER_SHADOW_VALIDATION_FAILED"
} else {
  "ADAPTER_SHADOW_VALIDATION_PASSED"
}

overall_summary$shadow_status <- shadow_status

write_csv_safe(
  overall_summary,
  file.path(
    output_directory,
    "phase_4_adapter_shadow_overall_summary.csv"
  )
)

write_csv_safe(
  case_summary,
  file.path(
    output_directory,
    "phase_4_adapter_shadow_case_summary.csv"
  )
)

write_csv_safe(
  module_concordance,
  file.path(
    output_directory,
    "phase_4_adapter_shadow_module_concordance.csv"
  )
)

write_csv_safe(
  overall_comparison,
  file.path(
    output_directory,
    "phase_4_adapter_shadow_overall_concordance.csv"
  )
)

write_csv_safe(
  adapter_validation,
  file.path(
    output_directory,
    "phase_4_adapter_shadow_internal_validation.csv"
  )
)

write_csv_safe(
  shadow_validation,
  file.path(
    output_directory,
    "phase_4_adapter_shadow_validation_gates.csv"
  )
)

workbook <- openxlsx::createWorkbook(
  creator = "CancerPPIr Phase 4"
)

workbook_tables <- list(
  "Overall summary" = overall_summary,
  "Case summary" = case_summary,
  "Validation gates" = shadow_validation,
  "Overall concordance" = overall_comparison,
  "Module concordance" = module_concordance,
  "Internal validation" = adapter_validation
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
          "Module concordance",
          "Internal validation"
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
        nchar(names(table)) + 2L
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
  "Phase4_Multicase_Adapter_Shadow_Validation.xlsx"
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
    "Shadow-validation workbook read-back failed: sheet order mismatch.",
    call. = FALSE
  )
}

cat(
  "\nPHASE 4 MULTICASE ADAPTER SHADOW VALIDATION COMPLETED\n"
)

print(
  overall_summary,
  row.names = FALSE
)

cat(
  "\nValidation gates:\n"
)

print(
  shadow_validation,
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

if (identical(
  shadow_status,
  "ADAPTER_SHADOW_VALIDATION_FAILED"
)) {
  quit(
    save = "no",
    status = 1L
  )
}