#!/usr/bin/env Rscript

# CancerPPIr Phase 4: summarize universal rulebook gaps
#
# This script reads the seven-case biological dry-run outputs and reduces the
# result to the large unresolved modules that most likely represent missing or
# overly strict universal biological rules.
#
# It does not modify production code or existing reports.
#
# Run from the repository root:
#
#   Rscript scripts/summarize_phase4_multicase_rulebook_gaps.R
#
# Optional positional arguments:
#
#   1 multicase_dry_run_directory
#   2 output_directory
#
# Defaults:
#
#   ../results/phase4_multicase_biological_dry_run
#   ../results/phase4_multicase_rulebook_gap_review

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

arguments <- commandArgs(
  trailingOnly = TRUE
)

input_directory <- if (length(arguments) >= 1L) {
  arguments[[1L]]
} else {
  file.path(
    "..",
    "results",
    "phase4_multicase_biological_dry_run"
  )
}

output_directory <- if (length(arguments) >= 2L) {
  arguments[[2L]]
} else {
  file.path(
    "..",
    "results",
    "phase4_multicase_rulebook_gap_review"
  )
}

required_files <- c(
  module_comparison = file.path(
    input_directory,
    "phase_4_multicase_module_comparison.csv"
  ),
  rule_evidence = file.path(
    input_directory,
    "phase_4_multicase_rule_evidence.csv"
  ),
  significant_terms = file.path(
    input_directory,
    "phase_4_multicase_significant_terms.csv"
  )
)

missing_files <- required_files[
  !file.exists(required_files)
]

if (length(missing_files) > 0L) {
  stop(
    paste0(
      "Required multicase dry-run file(s) are missing:\n",
      paste0(
        "- ",
        names(missing_files),
        ": ",
        missing_files,
        collapse = "\n"
      )
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
        "\nRemove it or provide a different second argument."
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

  tolower(
    trimws(
      as.character(x)
    )
  ) %in% c(
    "true",
    "t",
    "1",
    "yes",
    "y"
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

module_comparison <- utils::read.csv(
  required_files[["module_comparison"]],
  stringsAsFactors = FALSE,
  check.names = FALSE,
  fileEncoding = "UTF-8"
)

rule_evidence <- utils::read.csv(
  required_files[["rule_evidence"]],
  stringsAsFactors = FALSE,
  check.names = FALSE,
  fileEncoding = "UTF-8"
)

significant_terms <- utils::read.csv(
  required_files[["significant_terms"]],
  stringsAsFactors = FALSE,
  check.names = FALSE,
  fileEncoding = "UTF-8"
)

required_module_columns <- c(
  "sample_id",
  "module_id",
  "module_size",
  "representative_genes",
  "member_genes",
  "old_label",
  "new_primary_interpretation",
  "new_confidence",
  "positive_marker_genes",
  "supportive_marker_genes",
  "significant_supporting_terms",
  "new_warning",
  "review_category",
  "review_priority"
)

required_rule_columns <- c(
  "sample_id",
  "module_id",
  "rule_id",
  "axis",
  "display_label",
  "positive_marker_count",
  "supportive_marker_count",
  "exclusion_marker_count",
  "significant_term_count",
  "required_term_count",
  "positive_marker_genes",
  "supportive_marker_genes",
  "exclusion_marker_genes",
  "significant_terms",
  "best_fdr",
  "marker_component",
  "supportive_component",
  "term_component",
  "coverage_component",
  "exclusion_penalty",
  "evidence_score",
  "eligible"
)

required_term_columns <- c(
  "sample_id",
  "module_id",
  "source",
  "term_id",
  "description",
  "fdr",
  "supporting_genes"
)

missing_module_columns <- setdiff(
  required_module_columns,
  names(module_comparison)
)

missing_rule_columns <- setdiff(
  required_rule_columns,
  names(rule_evidence)
)

missing_term_columns <- setdiff(
  required_term_columns,
  names(significant_terms)
)

if (
  length(missing_module_columns) > 0L ||
  length(missing_rule_columns) > 0L ||
  length(missing_term_columns) > 0L
) {
  stop(
    paste0(
      "Unexpected multicase dry-run schema.\n",
      if (length(missing_module_columns) > 0L) {
        paste0(
          "Missing module columns: ",
          paste(
            missing_module_columns,
            collapse = ", "
          ),
          "\n"
        )
      } else {
        ""
      },
      if (length(missing_rule_columns) > 0L) {
        paste0(
          "Missing rule columns: ",
          paste(
            missing_rule_columns,
            collapse = ", "
          ),
          "\n"
        )
      } else {
        ""
      },
      if (length(missing_term_columns) > 0L) {
        paste0(
          "Missing term columns: ",
          paste(
            missing_term_columns,
            collapse = ", "
          )
        )
      } else {
        ""
      }
    ),
    call. = FALSE
  )
}

module_comparison$module_id <- safe_numeric(
  module_comparison$module_id
)

module_comparison$module_size <- safe_numeric(
  module_comparison$module_size
)

rule_evidence$module_id <- safe_numeric(
  rule_evidence$module_id
)

numeric_rule_columns <- c(
  "positive_marker_count",
  "supportive_marker_count",
  "exclusion_marker_count",
  "significant_term_count",
  "required_term_count",
  "best_fdr",
  "marker_component",
  "supportive_component",
  "term_component",
  "coverage_component",
  "exclusion_penalty",
  "evidence_score"
)

for (column_name in numeric_rule_columns) {
  rule_evidence[[column_name]] <- safe_numeric(
    rule_evidence[[column_name]]
  )
}

rule_evidence$eligible <- safe_logical(
  rule_evidence$eligible
)

significant_terms$module_id <- safe_numeric(
  significant_terms$module_id
)

significant_terms$fdr <- safe_numeric(
  significant_terms$fdr
)

gaps <- module_comparison[
  module_comparison$review_category ==
    "probable_rulebook_gap",
  ,
  drop = FALSE
]

if (nrow(gaps) == 0L) {
  stop(
    "No probable rulebook gaps were found.",
    call. = FALSE
  )
}

gaps <- gaps[
  order(
    -gaps$module_size,
    gaps$sample_id,
    gaps$module_id
  ),
  ,
  drop = FALSE
]

top_rule_for_axis <- function(
  sample_id,
  module_id,
  axis
) {
  candidates <- rule_evidence[
    rule_evidence$sample_id == sample_id &
      rule_evidence$module_id == module_id &
      rule_evidence$axis == axis,
    ,
    drop = FALSE
  ]

  if (nrow(candidates) == 0L) {
    return(
      data.frame(
        rule_id = "",
        display_label = "",
        evidence_score = NA_real_,
        eligible = FALSE,
        positive_marker_count = 0,
        supportive_marker_count = 0,
        exclusion_marker_count = 0,
        significant_term_count = 0,
        required_term_count = 0,
        positive_marker_genes = "",
        supportive_marker_genes = "",
        exclusion_marker_genes = "",
        significant_terms = "",
        best_fdr = NA_real_,
        marker_component = NA_real_,
        term_component = NA_real_,
        exclusion_penalty = NA_real_,
        stringsAsFactors = FALSE
      )
    )
  }

  candidates <- candidates[
    order(
      -candidates$evidence_score,
      -candidates$positive_marker_count,
      -candidates$significant_term_count,
      candidates$rule_id
    ),
    ,
    drop = FALSE
  ]

  candidates[
    1L,
    c(
      "rule_id",
      "display_label",
      "evidence_score",
      "eligible",
      "positive_marker_count",
      "supportive_marker_count",
      "exclusion_marker_count",
      "significant_term_count",
      "required_term_count",
      "positive_marker_genes",
      "supportive_marker_genes",
      "exclusion_marker_genes",
      "significant_terms",
      "best_fdr",
      "marker_component",
      "term_component",
      "exclusion_penalty"
    ),
    drop = FALSE
  ]
}

top_terms_for_module <- function(
  sample_id,
  module_id,
  limit = 12L
) {
  terms <- significant_terms[
    significant_terms$sample_id == sample_id &
      significant_terms$module_id == module_id,
    ,
    drop = FALSE
  ]

  if (nrow(terms) == 0L) {
    return(
      list(
        descriptions = "",
        ids = "",
        sources = "",
        genes = "",
        count = 0L,
        best_fdr = NA_real_
      )
    )
  }

  terms <- terms[
    order(
      terms$fdr,
      terms$description
    ),
    ,
    drop = FALSE
  ]

  terms <- head(
    terms,
    limit
  )

  list(
    descriptions = join_nonempty(
      paste0(
        terms$description,
        " [FDR=",
        format(
          terms$fdr,
          digits = 3,
          scientific = TRUE
        ),
        "]"
      ),
      separator = " | "
    ),
    ids = join_nonempty(
      terms$term_id
    ),
    sources = join_nonempty(
      terms$source
    ),
    genes = join_nonempty(
      terms$supporting_genes
    ),
    count = nrow(terms),
    best_fdr = min(
      terms$fdr,
      na.rm = TRUE
    )
  )
}

infer_gap_reason <- function(
  lineage,
  state,
  process
) {
  top_rows <- rbind(
    transform(
      lineage,
      axis_name = "lineage"
    ),
    transform(
      state,
      axis_name = "state"
    ),
    transform(
      process,
      axis_name = "process"
    )
  )

  top_rows <- top_rows[
    order(
      -top_rows$evidence_score,
      -top_rows$positive_marker_count,
      -top_rows$significant_term_count
    ),
    ,
    drop = FALSE
  ]

  best <- top_rows[
    1L,
    ,
    drop = FALSE
  ]

  if (
    best$positive_marker_count[[1L]] == 0L &&
    best$significant_term_count[[1L]] == 0L
  ) {
    return("no_current_rule_matches_markers_or_terms")
  }

  if (
    best$positive_marker_count[[1L]] >= 2L &&
    best$significant_term_count[[1L]] == 0L
  ) {
    return("marker_supported_but_no_matching_significant_term")
  }

  if (
    best$positive_marker_count[[1L]] == 0L &&
    best$significant_term_count[[1L]] >= 1L
  ) {
    return("term_supported_but_marker_rule_missing")
  }

  if (
    best$positive_marker_count[[1L]] >= 1L &&
    best$significant_term_count[[1L]] >= 1L &&
    best$exclusion_penalty[[1L]] > 0
  ) {
    return("support_present_but_exclusion_penalty_blocks_assignment")
  }

  if (
    best$positive_marker_count[[1L]] >= 1L &&
    best$significant_term_count[[1L]] >= 1L
  ) {
    return("support_present_but_score_or_minimum_threshold_too_strict")
  }

  if (
    best$positive_marker_count[[1L]] >= 1L
  ) {
    return("partial_marker_support_only")
  }

  if (
    best$significant_term_count[[1L]] >= 1L
  ) {
    return("partial_term_support_only")
  }

  "unclassified_rulebook_gap"
}

gap_rows <- list()

for (row_index in seq_len(nrow(gaps))) {
  gap <- gaps[
    row_index,
    ,
    drop = FALSE
  ]

  sample_id <- gap$sample_id[[1L]]
  module_id <- gap$module_id[[1L]]

  lineage <- top_rule_for_axis(
    sample_id,
    module_id,
    "lineage"
  )

  state <- top_rule_for_axis(
    sample_id,
    module_id,
    "state"
  )

  process <- top_rule_for_axis(
    sample_id,
    module_id,
    "process"
  )

  terms <- top_terms_for_module(
    sample_id,
    module_id
  )

  near_miss <- rbind(
    transform(
      lineage,
      axis = "lineage"
    ),
    transform(
      state,
      axis = "state"
    ),
    transform(
      process,
      axis = "process"
    )
  )

  near_miss <- near_miss[
    order(
      -near_miss$evidence_score,
      -near_miss$positive_marker_count,
      -near_miss$significant_term_count
    ),
    ,
    drop = FALSE
  ]

  best_near_miss <- near_miss[
    1L,
    ,
    drop = FALSE
  ]

  gap_rows[[length(gap_rows) + 1L]] <- data.frame(
    review_rank = row_index,
    sample_id = sample_id,
    module_id = module_id,
    module_size = gap$module_size[[1L]],
    representative_genes =
      gap$representative_genes[[1L]],
    member_genes =
      gap$member_genes[[1L]],
    previous_label =
      gap$old_label[[1L]],
    current_phase4_interpretation =
      gap$new_primary_interpretation[[1L]],
    current_warning =
      gap$new_warning[[1L]],
    inferred_gap_reason = infer_gap_reason(
      lineage,
      state,
      process
    ),
    best_near_miss_axis =
      best_near_miss$axis[[1L]],
    best_near_miss_rule =
      best_near_miss$rule_id[[1L]],
    best_near_miss_label =
      best_near_miss$display_label[[1L]],
    best_near_miss_score =
      best_near_miss$evidence_score[[1L]],
    best_positive_marker_count =
      best_near_miss$positive_marker_count[[1L]],
    best_supportive_marker_count =
      best_near_miss$supportive_marker_count[[1L]],
    best_exclusion_marker_count =
      best_near_miss$exclusion_marker_count[[1L]],
    best_significant_term_count =
      best_near_miss$significant_term_count[[1L]],
    best_positive_marker_genes =
      best_near_miss$positive_marker_genes[[1L]],
    best_supportive_marker_genes =
      best_near_miss$supportive_marker_genes[[1L]],
    best_exclusion_marker_genes =
      best_near_miss$exclusion_marker_genes[[1L]],
    best_matching_rule_terms =
      best_near_miss$significant_terms[[1L]],
    top_lineage_rule =
      lineage$rule_id[[1L]],
    top_lineage_score =
      lineage$evidence_score[[1L]],
    top_lineage_markers =
      lineage$positive_marker_genes[[1L]],
    top_lineage_terms =
      lineage$significant_terms[[1L]],
    top_state_rule =
      state$rule_id[[1L]],
    top_state_score =
      state$evidence_score[[1L]],
    top_state_markers =
      state$positive_marker_genes[[1L]],
    top_state_terms =
      state$significant_terms[[1L]],
    top_process_rule =
      process$rule_id[[1L]],
    top_process_score =
      process$evidence_score[[1L]],
    top_process_markers =
      process$positive_marker_genes[[1L]],
    top_process_terms =
      process$significant_terms[[1L]],
    top_significant_terms =
      terms$descriptions,
    top_term_ids =
      terms$ids,
    top_term_sources =
      terms$sources,
    top_term_supporting_genes =
      terms$genes,
    top_term_count =
      terms$count,
    best_module_term_fdr =
      terms$best_fdr,
    manual_review_decision = "",
    proposed_universal_rule_change = "",
    reviewer_notes = "",
    stringsAsFactors = FALSE
  )
}

gap_review <- do.call(
  rbind,
  gap_rows
)

gap_review <- gap_review[
  order(
    -gap_review$module_size,
    gap_review$sample_id,
    gap_review$module_id
  ),
  ,
  drop = FALSE
]

gap_review$review_rank <- seq_len(
  nrow(gap_review)
)

reason_summary <- as.data.frame(
  table(
    gap_review$inferred_gap_reason
  ),
  stringsAsFactors = FALSE
)

names(reason_summary) <- c(
  "inferred_gap_reason",
  "module_count"
)

reason_summary <- reason_summary[
  order(
    -reason_summary$module_count,
    reason_summary$inferred_gap_reason
  ),
  ,
  drop = FALSE
]

near_miss_summary <- aggregate(
  x = list(
    module_count = gap_review$best_near_miss_rule,
    mean_score = gap_review$best_near_miss_score,
    max_module_size = gap_review$module_size
  ),
  by = list(
    best_near_miss_axis =
      gap_review$best_near_miss_axis,
    best_near_miss_rule =
      gap_review$best_near_miss_rule,
    best_near_miss_label =
      gap_review$best_near_miss_label,
    inferred_gap_reason =
      gap_review$inferred_gap_reason
  ),
  FUN = function(x) {
    if (is.numeric(x)) {
      mean(
        x,
        na.rm = TRUE
      )
    } else {
      length(x)
    }
  }
)

# Recompute count and maximum explicitly to avoid aggregate type ambiguity.
near_miss_keys <- unique(
  gap_review[
    ,
    c(
      "best_near_miss_axis",
      "best_near_miss_rule",
      "best_near_miss_label",
      "inferred_gap_reason"
    ),
    drop = FALSE
  ]
)

near_miss_rows <- list()

for (row_index in seq_len(nrow(near_miss_keys))) {
  key <- near_miss_keys[
    row_index,
    ,
    drop = FALSE
  ]

  subset_rows <- gap_review[
    gap_review$best_near_miss_axis ==
      key$best_near_miss_axis[[1L]] &
      gap_review$best_near_miss_rule ==
        key$best_near_miss_rule[[1L]] &
      gap_review$best_near_miss_label ==
        key$best_near_miss_label[[1L]] &
      gap_review$inferred_gap_reason ==
        key$inferred_gap_reason[[1L]],
    ,
    drop = FALSE
  ]

  near_miss_rows[[length(near_miss_rows) + 1L]] <-
    data.frame(
      best_near_miss_axis =
        key$best_near_miss_axis[[1L]],
      best_near_miss_rule =
        key$best_near_miss_rule[[1L]],
      best_near_miss_label =
        key$best_near_miss_label[[1L]],
      inferred_gap_reason =
        key$inferred_gap_reason[[1L]],
      module_count =
        nrow(subset_rows),
      affected_cases =
        join_nonempty(
          subset_rows$sample_id
        ),
      mean_near_miss_score =
        mean(
          subset_rows$best_near_miss_score,
          na.rm = TRUE
        ),
      maximum_module_size =
        max(
          subset_rows$module_size,
          na.rm = TRUE
        ),
      representative_modules =
        join_nonempty(
          paste0(
            subset_rows$sample_id,
            ":M",
            subset_rows$module_id,
            " (n=",
            subset_rows$module_size,
            ")"
          )
        ),
      stringsAsFactors = FALSE
    )
}

near_miss_summary <- do.call(
  rbind,
  near_miss_rows
)

near_miss_summary <- near_miss_summary[
  order(
    -near_miss_summary$module_count,
    -near_miss_summary$maximum_module_size,
    near_miss_summary$best_near_miss_rule
  ),
  ,
  drop = FALSE
]

case_gap_summary <- aggregate(
  x = list(
    probable_rulebook_gaps =
      gap_review$module_id,
    total_gap_nodes =
      gap_review$module_size
  ),
  by = list(
    sample_id =
      gap_review$sample_id
  ),
  FUN = function(x) {
    if (all(x == floor(x))) {
      sum(x)
    } else {
      sum(x)
    }
  }
)

# Correct the first aggregate field to count modules rather than sum IDs.
case_gap_summary$probable_rulebook_gaps <- vapply(
  case_gap_summary$sample_id,
  function(sample_id) {
    sum(
      gap_review$sample_id == sample_id
    )
  },
  FUN.VALUE = integer(1)
)

case_gap_summary$largest_gap_module <- vapply(
  case_gap_summary$sample_id,
  function(sample_id) {
    max(
      gap_review$module_size[
        gap_review$sample_id == sample_id
      ],
      na.rm = TRUE
    )
  },
  FUN.VALUE = numeric(1)
)

case_gap_summary <- case_gap_summary[
  order(
    -case_gap_summary$probable_rulebook_gaps,
    case_gap_summary$sample_id
  ),
  ,
  drop = FALSE
]

overall_summary <- data.frame(
  probable_rulebook_gap_count =
    nrow(gap_review),
  affected_case_count =
    length(
      unique(
        gap_review$sample_id
      )
    ),
  total_nodes_in_gap_modules =
    sum(
      gap_review$module_size
    ),
  largest_gap_module_size =
    max(
      gap_review$module_size
    ),
  most_common_gap_reason =
    reason_summary$inferred_gap_reason[[1L]],
  most_common_gap_reason_count =
    reason_summary$module_count[[1L]],
  stringsAsFactors = FALSE
)

write_csv_safe(
  overall_summary,
  file.path(
    output_directory,
    "phase_4_rulebook_gap_overall_summary.csv"
  )
)

write_csv_safe(
  case_gap_summary,
  file.path(
    output_directory,
    "phase_4_rulebook_gap_case_summary.csv"
  )
)

write_csv_safe(
  reason_summary,
  file.path(
    output_directory,
    "phase_4_rulebook_gap_reason_summary.csv"
  )
)

write_csv_safe(
  near_miss_summary,
  file.path(
    output_directory,
    "phase_4_rulebook_gap_near_miss_summary.csv"
  )
)

write_csv_safe(
  gap_review,
  file.path(
    output_directory,
    "phase_4_priority_rulebook_gaps.csv"
  )
)

workbook <- openxlsx::createWorkbook(
  creator = "CancerPPIr Phase 4"
)

tables <- list(
  "Overall summary" = overall_summary,
  "Case summary" = case_gap_summary,
  "Gap reasons" = reason_summary,
  "Near-miss rules" = near_miss_summary,
  "Priority gaps" = gap_review
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

for (sheet_name in names(tables)) {
  table <- tables[[sheet_name]]

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
        sheet_name == "Priority gaps"
      ) {
        4L
      } else {
        1L
      }
    )

    widths <- pmin(
      42,
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

workbook_path <- file.path(
  output_directory,
  "Phase4_Multicase_Rulebook_Gap_Review.xlsx"
)

openxlsx::saveWorkbook(
  workbook,
  workbook_path,
  overwrite = TRUE
)

readback_sheets <- openxlsx::getSheetNames(
  workbook_path
)

if (!identical(
  readback_sheets,
  names(tables)
)) {
  stop(
    "Rulebook-gap workbook read-back validation failed.",
    call. = FALSE
  )
}

cat(
  "\nPHASE 4 MULTICASE RULEBOOK GAP SUMMARY COMPLETED\n"
)

print(
  overall_summary,
  row.names = FALSE
)

cat(
  "\nGap reasons:\n"
)

print(
  reason_summary,
  row.names = FALSE
)

cat(
  "\nHighest-priority modules:\n"
)

print(
  head(
    gap_review[
      ,
      c(
        "review_rank",
        "sample_id",
        "module_id",
        "module_size",
        "inferred_gap_reason",
        "best_near_miss_rule",
        "best_near_miss_score",
        "representative_genes"
      ),
      drop = FALSE
    ],
    15L
  ),
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
  "\nProduction code was not modified.\n"
)