#!/usr/bin/env Rscript

# CancerPPIr Phase 4.4A:
# validate the A01 technical evidence export against the deterministic
# pre-export baseline.
#
# Run from repository root:
#
#   Rscript scripts/validate_phase4_a01_technical_evidence_export.R
#
# Optional positional arguments:
#   1. baseline results root
#   2. candidate results root
#
# Defaults:
#   ../results/phase4_a01_deterministic_run1
#   ../results/phase4_a01_technical_evidence_v1

if (!requireNamespace("openxlsx", quietly = TRUE)) {
  stop("The openxlsx package is required.", call. = FALSE)
}

args <- commandArgs(trailingOnly = TRUE)

baseline_root <- if (length(args) >= 1L) {
  args[[1L]]
} else {
  file.path(
    "..",
    "results",
    "phase4_a01_deterministic_run1"
  )
}

candidate_root <- if (length(args) >= 2L) {
  args[[2L]]
} else {
  file.path(
    "..",
    "results",
    "phase4_a01_technical_evidence_v1"
  )
}

case_folder <- "Genes_A"

baseline_case <- file.path(
  baseline_root,
  case_folder
)

candidate_case <- file.path(
  candidate_root,
  case_folder
)

files <- list(
  baseline_analytical = file.path(
    baseline_case,
    "CancerPPIr_Analytical_Report.xlsx"
  ),
  candidate_analytical = file.path(
    candidate_case,
    "CancerPPIr_Analytical_Report.xlsx"
  ),
  baseline_technical = file.path(
    baseline_case,
    "CancerPPIr_Technical_Report.xlsx"
  ),
  candidate_technical = file.path(
    candidate_case,
    "CancerPPIr_Technical_Report.xlsx"
  ),
  baseline_graphml = file.path(
    baseline_case,
    "Network_for_Cytoscape.graphml"
  ),
  candidate_graphml = file.path(
    candidate_case,
    "Network_for_Cytoscape.graphml"
  )
)

missing_files <- names(files)[
  !vapply(
    files,
    file.exists,
    FUN.VALUE = logical(1)
  )
]

if (length(missing_files) > 0L) {
  stop(
    paste0(
      "Required file(s) are missing:\n",
      paste0(
        "- ",
        missing_files,
        ": ",
        unlist(files[missing_files]),
        collapse = "\n"
      )
    ),
    call. = FALSE
  )
}

read_sheet <- function(
  workbook,
  sheet
) {
  openxlsx::read.xlsx(
    workbook,
    sheet = sheet,
    check.names = FALSE,
    detectDates = FALSE,
    skipEmptyRows = FALSE,
    skipEmptyCols = FALSE
  )
}

normalize_frame <- function(data) {
  data <- as.data.frame(
    data,
    stringsAsFactors = FALSE,
    check.names = FALSE
  )

  for (column in names(data)) {
    if (is.factor(data[[column]])) {
      data[[column]] <- as.character(
        data[[column]]
      )
    }
  }

  rownames(data) <- NULL
  data
}

compare_workbook_sheets <- function(
  baseline_workbook,
  candidate_workbook,
  sheets
) {
  rows <- vector(
    "list",
    length(sheets)
  )

  for (index in seq_along(sheets)) {
    sheet <- sheets[[index]]

    baseline_data <- normalize_frame(
      read_sheet(
        baseline_workbook,
        sheet
      )
    )

    candidate_data <- normalize_frame(
      read_sheet(
        candidate_workbook,
        sheet
      )
    )

    rows[[index]] <- data.frame(
      sheet = sheet,
      baseline_rows = nrow(baseline_data),
      candidate_rows = nrow(candidate_data),
      baseline_columns = ncol(baseline_data),
      candidate_columns = ncol(candidate_data),
      identical = identical(
        baseline_data,
        candidate_data
      ),
      stringsAsFactors = FALSE
    )
  }

  do.call(
    rbind,
    rows
  )
}

baseline_analytical_sheets <- openxlsx::getSheetNames(
  files$baseline_analytical
)

candidate_analytical_sheets <- openxlsx::getSheetNames(
  files$candidate_analytical
)

baseline_technical_sheets <- openxlsx::getSheetNames(
  files$baseline_technical
)

candidate_technical_sheets <- openxlsx::getSheetNames(
  files$candidate_technical
)

new_phase4_sheets <- c(
  "Phase4 module annotations",
  "Phase4 rule evidence",
  "Phase4 significant terms",
  "Phase4 node annotations",
  "Phase4 validation"
)

# The installer inserts before Session info, not after Raw network summary.
# Resolve the exact expected order from the baseline workbook.
session_index <- match(
  "Session info",
  baseline_technical_sheets
)

if (is.na(session_index)) {
  stop(
    "Baseline technical workbook has no Session info sheet.",
    call. = FALSE
  )
}

expected_candidate_technical_sheets <- c(
  baseline_technical_sheets[
    seq_len(
      session_index - 1L
    )
  ],
  new_phase4_sheets,
  baseline_technical_sheets[
    seq.int(
      session_index,
      length(baseline_technical_sheets)
    )
  ]
)

analytical_comparison <- compare_workbook_sheets(
  files$baseline_analytical,
  files$candidate_analytical,
  baseline_analytical_sheets
)

technical_legacy_comparison <- compare_workbook_sheets(
  files$baseline_technical,
  files$candidate_technical,
  baseline_technical_sheets
)

graphml_identical <- identical(
  readBin(
    files$baseline_graphml,
    what = "raw",
    n = file.info(
      files$baseline_graphml
    )$size
  ),
  readBin(
    files$candidate_graphml,
    what = "raw",
    n = file.info(
      files$candidate_graphml
    )$size
  )
)

module_annotations <- read_sheet(
  files$candidate_technical,
  "Phase4 module annotations"
)

rule_evidence <- read_sheet(
  files$candidate_technical,
  "Phase4 rule evidence"
)

significant_terms <- read_sheet(
  files$candidate_technical,
  "Phase4 significant terms"
)

node_annotations <- read_sheet(
  files$candidate_technical,
  "Phase4 node annotations"
)

validation <- read_sheet(
  files$candidate_technical,
  "Phase4 validation"
)

required_module_columns <- c(
  "community_louvain",
  "network_node_count",
  "interpretation_class",
  "primary_interpretation",
  "confidence",
  "priority_eligible",
  "evidence_rationale"
)

required_node_columns <- c(
  "gene",
  "community_louvain",
  "entity_class",
  "candidate_eligibility",
  "module_primary_interpretation",
  "module_priority_eligible"
)

required_term_columns <- c(
  "community_louvain",
  "module_id",
  "description",
  "fdr",
  "supporting_genes"
)

required_validation_columns <- c(
  "check_id",
  "status"
)

missing_module_columns <- setdiff(
  required_module_columns,
  names(module_annotations)
)

missing_node_columns <- setdiff(
  required_node_columns,
  names(node_annotations)
)

missing_term_columns <- setdiff(
  required_term_columns,
  names(significant_terms)
)

missing_validation_columns <- setdiff(
  required_validation_columns,
  names(validation)
)

significant_fdr <- suppressWarnings(
  as.numeric(
    significant_terms$fdr
  )
)

priority_values <- module_annotations$priority_eligible

if (!is.logical(priority_values)) {
  priority_values <- tolower(
    as.character(priority_values)
  ) %in% c(
    "true",
    "t",
    "1",
    "yes"
  )
}

interpretation_class <- as.character(
  module_annotations$interpretation_class
)

summary <- data.frame(
  check_id = c(
    "analytical_sheet_names_unchanged",
    "analytical_sheet_contents_unchanged",
    "technical_sheet_order_expected",
    "legacy_technical_sheet_contents_unchanged",
    "graphml_byte_identical",
    "phase4_module_annotations_present",
    "phase4_rule_evidence_present",
    "phase4_significant_terms_present",
    "phase4_node_annotations_present",
    "phase4_validation_present",
    "module_schema_complete",
    "node_schema_complete",
    "term_schema_complete",
    "validation_schema_complete",
    "module_count_is_43",
    "node_count_is_169",
    "priority_eligible_count_is_4",
    "technical_module_count_is_1",
    "mixed_module_count_is_0",
    "unresolved_module_count_is_35",
    "all_significant_terms_fdr_le_0_05",
    "all_validation_checks_pass"
  ),
  status = c(
    identical(
      baseline_analytical_sheets,
      candidate_analytical_sheets
    ),
    all(
      analytical_comparison$identical
    ),
    identical(
      candidate_technical_sheets,
      expected_candidate_technical_sheets
    ),
    all(
      technical_legacy_comparison$identical
    ),
    graphml_identical,
    "Phase4 module annotations" %in%
      candidate_technical_sheets,
    "Phase4 rule evidence" %in%
      candidate_technical_sheets,
    "Phase4 significant terms" %in%
      candidate_technical_sheets,
    "Phase4 node annotations" %in%
      candidate_technical_sheets,
    "Phase4 validation" %in%
      candidate_technical_sheets,
    length(missing_module_columns) == 0L,
    length(missing_node_columns) == 0L,
    length(missing_term_columns) == 0L,
    length(missing_validation_columns) == 0L,
    nrow(module_annotations) == 43L,
    nrow(node_annotations) == 169L,
    sum(
      priority_values,
      na.rm = TRUE
    ) == 4L,
    sum(
      interpretation_class ==
        "technical_or_covariate",
      na.rm = TRUE
    ) == 1L,
    sum(
      interpretation_class ==
        "mixed_biological",
      na.rm = TRUE
    ) == 0L,
    sum(
      interpretation_class ==
        "unresolved",
      na.rm = TRUE
    ) == 35L,
    nrow(significant_terms) == 0L ||
      all(
        is.finite(significant_fdr) &
          significant_fdr <= 0.05
      ),
    all(
      as.character(validation$status) ==
        "PASS"
    )
  ),
  stringsAsFactors = FALSE
)

summary$status <- ifelse(
  summary$status,
  "PASS",
  "FAIL"
)

cat(
  "\nPHASE 4.4A A01 TECHNICAL EVIDENCE EXPORT VALIDATION\n\n"
)

print(
  summary,
  row.names = FALSE
)

cat(
  "\nCandidate technical workbook sheets:\n"
)

cat(
  paste0(
    seq_along(candidate_technical_sheets),
    ". ",
    candidate_technical_sheets,
    collapse = "\n"
  ),
  "\n"
)

cat(
  "\nPhase 4 table dimensions:\n"
)

print(
  data.frame(
    table = c(
      "module_annotations",
      "rule_evidence",
      "significant_terms",
      "node_annotations",
      "validation"
    ),
    rows = c(
      nrow(module_annotations),
      nrow(rule_evidence),
      nrow(significant_terms),
      nrow(node_annotations),
      nrow(validation)
    ),
    columns = c(
      ncol(module_annotations),
      ncol(rule_evidence),
      ncol(significant_terms),
      ncol(node_annotations),
      ncol(validation)
    ),
    stringsAsFactors = FALSE
  ),
  row.names = FALSE
)

if (any(summary$status == "FAIL")) {
  cat(
    "\nVALIDATION STATUS: FAILED\n"
  )

  quit(
    save = "no",
    status = 1L
  )
}

cat(
  "\nVALIDATION STATUS: PASSED\n"
)
