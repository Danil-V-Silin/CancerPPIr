#!/usr/bin/env Rscript

# CancerPPIr Phase 4.4B
# Run all seven clinical cases through the production pipeline and validate
# that the five Phase 4 biological-evidence tables are exported faithfully
# to every technical workbook.
#
# Run from the repository root:
#   Rscript scripts/run_phase4_multicase_technical_export_validation.R
#
# Optional positional arguments:
#   1. input directory
#   2. output directory
#   3. STRING cache directory
#   4. execution mode: run-pipeline or validate-existing
#
# Defaults:
#   ../input
#   ../results/phase4_multicase_technical_evidence_v2
#   ../string_cache
#
# This script does not modify repository files.

required_packages <- c(
  "openxlsx",
  "igraph"
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

arguments <- commandArgs(
  trailingOnly = TRUE
)

input_root <- if (length(arguments) >= 1L) {
  arguments[[1L]]
} else {
  file.path(
    "..",
    "input"
  )
}

output_root <- if (length(arguments) >= 2L) {
  arguments[[2L]]
} else {
  file.path(
    "..",
    "results",
    "phase4_multicase_technical_evidence_v2"
  )
}

cache_root <- if (length(arguments) >= 3L) {
  arguments[[3L]]
} else {
  file.path(
    "..",
    "string_cache"
  )
}


# Phase 4.4B existing-output validation mode
execution_mode <- if (length(arguments) >= 4L) {
  tolower(
    trimws(
      as.character(
        arguments[[4L]]
      )
    )
  )
} else {
  "run-pipeline"
}

valid_execution_modes <- c(
  "run-pipeline",
  "validate-existing"
)

if (!(execution_mode %in% valid_execution_modes)) {
  stop(
    paste0(
      "Unsupported execution mode: ",
      execution_mode,
      ". Use run-pipeline or validate-existing."
    ),
    call. = FALSE
  )
}

validate_existing_outputs <- identical(
  execution_mode,
  "validate-existing"
)

pipeline_entry <- file.path(
  project_root,
  "cancerppir.R"
)

loader_file <- file.path(
  project_root,
  "R",
  "load_all.R"
)

required_project_files <- c(
  pipeline_entry,
  loader_file
)

missing_project_files <- required_project_files[
  !file.exists(required_project_files)
]

if (length(missing_project_files) > 0L) {
  stop(
    paste0(
      "Required project file(s) are missing:\n",
      paste0(
        "- ",
        missing_project_files,
        collapse = "\n"
      )
    ),
    call. = FALSE
  )
}

if (!dir.exists(input_root)) {
  stop(
    paste0(
      "Input directory does not exist: ",
      input_root
    ),
    call. = FALSE
  )
}

if (!dir.exists(cache_root)) {
  stop(
    paste0(
      "STRING cache directory does not exist: ",
      cache_root
    ),
    call. = FALSE
  )
}

if (dir.exists(output_root)) {
  existing_output_entries <- list.files(
    output_root,
    all.files = TRUE,
    no.. = TRUE
  )

  if (
    length(existing_output_entries) > 0L &&
      !validate_existing_outputs
  ) {
    stop(
      paste0(
        "Output directory already exists and is not empty: ",
        output_root,
        "\nRemove it, pass a different second argument, or use validate-existing mode."
      ),
      call. = FALSE
    )
  }

  if (
    length(existing_output_entries) == 0L &&
      validate_existing_outputs
  ) {
    stop(
      paste0(
        "validate-existing mode requires a non-empty output directory: ",
        output_root
      ),
      call. = FALSE
    )
  }
} else {
  if (validate_existing_outputs) {
    stop(
      paste0(
        "validate-existing mode requires an existing output directory: ",
        output_root
      ),
      call. = FALSE
    )
  }

  dir.create(
    output_root,
    recursive = TRUE,
    showWarnings = FALSE
  )
}

logs_directory <- file.path(
  output_root,
  "logs"
)

dir.create(
  logs_directory,
  recursive = TRUE,
  showWarnings = FALSE
)

source(
  loader_file,
  local = FALSE
)

loaded_files <- load_cancerppir_modules(
  project_root = project_root,
  envir = .GlobalEnv
)

required_loaded_files <- c(
  "04a_biological_evidence_engine.R",
  "04b_biological_evidence_adapter.R",
  "07_pipeline.R"
)

missing_loaded_files <- setdiff(
  required_loaded_files,
  basename(
    loaded_files
  )
)

if (length(missing_loaded_files) > 0L) {
  stop(
    paste0(
      "The standard loader did not load:\n",
      paste0(
        "- ",
        missing_loaded_files,
        collapse = "\n"
      )
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
    "phase4_bind_pipeline_evidence() is unavailable after module loading.",
    call. = FALSE
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
  input_file = c(
    "Genes_A.csv",
    "Genes_K.csv",
    "Genes_L.csv",
    "Genes_M.csv",
    "Genes_P01.csv",
    "Genes_P02.csv",
    "Genes_R.csv"
  ),
  output_folder = c(
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

input_paths <- file.path(
  input_root,
  case_map$input_file
)

missing_inputs <- case_map$sample_id[
  !file.exists(
    input_paths
  )
]

if (length(missing_inputs) > 0L) {
  missing_rows <- case_map[
    case_map$sample_id %in% missing_inputs,
    ,
    drop = FALSE
  ]

  stop(
    paste0(
      "Input file(s) are missing:\n",
      paste0(
        "- ",
        missing_rows$sample_id,
        ": ",
        file.path(
          input_root,
          missing_rows$input_file
        ),
        collapse = "\n"
      )
    ),
    call. = FALSE
  )
}

legacy_technical_sheets <- c(
  "Mapping summary",
  "Gene status",
  "Alias corrections",
  "Unmapped genes",
  "HGNC normalization",
  "Genes used table",
  "Raw node metrics",
  "Raw all modules",
  "Raw major modules",
  "Top module enrichment",
  "Top network enrichment",
  "Top candidate enrichment",
  "Raw module enrichment",
  "Raw network enrichment",
  "Raw candidate enrichment"
)

phase4_sheet_map <- c(
  "Phase4 module annotations" =
    "module_annotations",
  "Phase4 rule evidence" =
    "module_rule_evidence",
  "Phase4 significant terms" =
    "significant_module_terms",
  "Phase4 node annotations" =
    "node_annotations",
  "Phase4 validation" =
    "validation"
)

expected_technical_sheets <- c(
  legacy_technical_sheets,
  names(
    phase4_sheet_map
  ),
  "Session info"
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
    return(
      NA_character_
    )
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
    return(
      NA_character_
    )
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
  output
}

safe_logical <- function(x) {
  if (is.logical(x)) {
    return(x)
  }

  normalized <- tolower(
    trimws(
      as.character(x)
    )
  )

  output <- rep(
    NA,
    length(normalized)
  )

  output[
    normalized %in% c(
      "true",
      "t",
      "1",
      "yes",
      "y"
    )
  ] <- TRUE

  output[
    normalized %in% c(
      "false",
      "f",
      "0",
      "no",
      "n"
    )
  ] <- FALSE

  output
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

  rownames(data) <- NULL
  data
}

compare_columns <- function(
  expected,
  observed
) {
  if (
    is.numeric(expected) ||
      is.integer(expected)
  ) {
    observed_numeric <- safe_numeric(
      observed
    )

    expected_numeric <- as.numeric(
      expected
    )

    same_missingness <- identical(
      is.na(expected_numeric),
      is.na(observed_numeric)
    )

    if (!same_missingness) {
      return(FALSE)
    }

    comparable <- !is.na(
      expected_numeric
    )

    if (!any(comparable)) {
      return(TRUE)
    }

    return(
      isTRUE(
        all.equal(
          expected_numeric[comparable],
          observed_numeric[comparable],
          tolerance = 1e-12,
          check.attributes = FALSE
        )
      )
    )
  }

  if (is.logical(expected)) {
    observed_logical <- safe_logical(
      observed
    )

    return(
      identical(
        expected,
        observed_logical
      )
    )
  }

  expected_character <- safe_character(
    expected
  )

  observed_character <- safe_character(
    observed
  )

  identical(
    expected_character,
    observed_character
  )
}

compare_frames <- function(
  expected,
  observed,
  allow_observed_extra_columns = FALSE
) {
  expected <- normalize_frame(
    expected
  )

  observed <- normalize_frame(
    observed
  )

  expected_columns <- names(expected)
  observed_columns <- names(observed)

  missing_expected_columns <- setdiff(
    expected_columns,
    observed_columns
  )

  extra_observed_columns <- setdiff(
    observed_columns,
    expected_columns
  )

  schema_identical <- if (allow_observed_extra_columns) {
    length(missing_expected_columns) == 0L
  } else {
    identical(
      expected_columns,
      observed_columns
    )
  }

  if (
    allow_observed_extra_columns &&
      length(missing_expected_columns) == 0L
  ) {
    observed_for_comparison <- observed[
      ,
      expected_columns,
      drop = FALSE
    ]
  } else {
    observed_for_comparison <- observed
  }

  dimensions_identical <- (
    nrow(expected) == nrow(observed_for_comparison) &&
      ncol(expected) == ncol(observed_for_comparison)
  )

  if (
    !schema_identical ||
      !dimensions_identical
  ) {
    differing_schema <- union(
      missing_expected_columns,
      if (allow_observed_extra_columns) {
        character()
      } else {
        extra_observed_columns
      }
    )

    return(
      list(
        schema_identical = schema_identical,
        dimensions_identical = dimensions_identical,
        values_identical = FALSE,
        differing_columns = paste(
          differing_schema,
          collapse = "; "
        )
      )
    )
  }

  column_matches <- vapply(
    expected_columns,
    function(column) {
      compare_columns(
        expected[[column]],
        observed_for_comparison[[column]]
      )
    },
    FUN.VALUE = logical(1)
  )

  list(
    schema_identical = TRUE,
    dimensions_identical = TRUE,
    values_identical = all(column_matches),
    differing_columns = paste(
      names(column_matches)[!column_matches],
      collapse = "; "
    )
  )
}

run_case <- function(
  input_path,
  log_path
) {
  rscript_command <- file.path(
    R.home("bin"),
    if (.Platform$OS.type == "windows") {
      "Rscript.exe"
    } else {
      "Rscript"
    }
  )

  command_arguments <- c(
    shQuote(
      pipeline_entry
    ),
    shQuote(
      input_path
    ),
    shQuote(
      output_root
    ),
    shQuote(
      cache_root
    ),
    "400",
    "30",
    "TRUE"
  )

  system2(
    command = rscript_command,
    args = command_arguments,
    stdout = log_path,
    stderr = log_path,
    wait = TRUE
  )
}

all_case_summary <- list()
all_table_validation <- list()
all_internal_validation <- list()

for (case_index in seq_len(
  nrow(case_map)
)) {
  sample_id <- case_map$sample_id[[case_index]]

  input_path <- file.path(
    input_root,
    case_map$input_file[[case_index]]
  )

  output_case_directory <- file.path(
    output_root,
    case_map$output_folder[[case_index]]
  )

  log_path <- file.path(
    logs_directory,
    paste0(
      sample_id,
      ".log"
    )
  )

  message(
    "[phase 4.4B] ",
    if (validate_existing_outputs) {
      "Validating existing outputs for "
    } else {
      "Running "
    },
    sample_id,
    " from ",
    basename(
      input_path
    ),
    "."
  )

  exit_status <- if (validate_existing_outputs) {
    0L
  } else {
    run_case(
      input_path = input_path,
      log_path = log_path
    )
  }

  if (
    is.null(exit_status) ||
      is.na(exit_status) ||
      exit_status != 0L
  ) {
    log_tail <- if (file.exists(log_path)) {
      tail(
        readLines(
          log_path,
          warn = FALSE,
          encoding = "UTF-8"
        ),
        40L
      )
    } else {
      "Log file was not created."
    }

    stop(
      paste0(
        "Pipeline failed for ",
        sample_id,
        " with exit status ",
        exit_status,
        ".\n\nLog tail:\n",
        paste(
          log_tail,
          collapse = "\n"
        )
      ),
      call. = FALSE
    )
  }

  analytical_workbook <- file.path(
    output_case_directory,
    "CancerPPIr_Analytical_Report.xlsx"
  )

  technical_workbook <- file.path(
    output_case_directory,
    "CancerPPIr_Technical_Report.xlsx"
  )

  graphml_file <- file.path(
    output_case_directory,
    "Network_for_Cytoscape.graphml"
  )

  string_links_file <- file.path(
    output_case_directory,
    "STRING_links.txt"
  )

  required_outputs <- c(
    analytical_workbook,
    technical_workbook,
    graphml_file,
    string_links_file
  )

  if (!all(
    file.exists(
      required_outputs
    )
  )) {
    stop(
      paste0(
        "One or more expected output files are missing for ",
        sample_id,
        "."
      ),
      call. = FALSE
    )
  }

  technical_sheets <- openxlsx::getSheetNames(
    technical_workbook
  )

  technical_sheet_order_valid <- identical(
    technical_sheets,
    expected_technical_sheets
  )

  raw_node_metrics <- read_sheet(
    technical_workbook,
    "Raw node metrics"
  )

  raw_module_enrichment <- read_sheet(
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

  if (any(
    is.na(
      unresolved_columns
    )
  )) {
    stop(
      paste0(
        "Required raw workbook columns could not be resolved for ",
        sample_id,
        "."
      ),
      call. = FALSE
    )
  }

  node_metrics <- as.data.frame(
    raw_node_metrics,
    stringsAsFactors = FALSE,
    check.names = FALSE
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

  node_metrics$gene <- trimws(
    safe_character(
      node_metrics$gene
    )
  )

  node_metrics$community_louvain <- safe_numeric(
    node_metrics$community_louvain
  )

  node_metrics$candidate_score <- safe_numeric(
    node_metrics$candidate_score
  )

  module_enrichment <- as.data.frame(
    raw_module_enrichment,
    stringsAsFactors = FALSE,
    check.names = FALSE
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

  expected_evidence <- phase4_bind_pipeline_evidence(
    node_metrics = node_metrics,
    module_enrichment = module_enrichment,
    fdr_threshold = 0.05
  )

  table_rows <- list()

  for (sheet_name in names(
    phase4_sheet_map
  )) {
    result_name <- unname(
      phase4_sheet_map[[sheet_name]]
    )

    observed_table <- read_sheet(
      technical_workbook,
      sheet_name
    )

    expected_table <- expected_evidence[[result_name]]

    # Phase4 node-annotation recomputation-only columns
    #
    # These columns are already present in Raw node metrics because the
    # legacy labeling layer is joined after the Phase4 adapter runs in
    # production. Recomputing the adapter from Raw node metrics therefore
    # carries them into expected_evidence, although they are intentionally
    # absent from the exported Phase4 node-annotation sheet.
    if (identical(
      sheet_name,
      "Phase4 node annotations"
    )) {
      recomputation_only_columns <- c(
        "module_rank",
        "final_functional_label",
        "putative_biological_program",
        "specific_label_candidate",
        "fallback_label",
        "label_assignment_mode",
        "label_source",
        "label_evidence_score",
        "label_confidence",
        "label_warning",
        "supporting_biological_themes",
        "marker_label_evidence_count",
        "term_label_evidence_count",
        "required_specific_evidence_detected",
        "marker_max_overlap_count",
        "top_interpretable_terms",
        "top_interpretable_sources",
        "best_interpretable_fdr",
        "top_raw_terms",
        "database_evidence_summary",
        "biological_direction_rationale"
      )

      expected_table <- expected_table[
        ,
        setdiff(
          names(expected_table),
          recomputation_only_columns
        ),
        drop = FALSE
      ]
    }

    comparison <- compare_frames(
      expected = expected_table,
      observed = observed_table,
      allow_observed_extra_columns = FALSE
    )

    table_rows[[sheet_name]] <- data.frame(
      sample_id = sample_id,
      sheet_name = sheet_name,
      expected_rows = nrow(
        expected_table
      ),
      observed_rows = nrow(
        observed_table
      ),
      expected_columns = ncol(
        expected_table
      ),
      observed_columns = ncol(
        observed_table
      ),
      schema_identical =
        comparison$schema_identical,
      dimensions_identical =
        comparison$dimensions_identical,
      values_identical =
        comparison$values_identical,
      differing_columns =
        comparison$differing_columns,
      stringsAsFactors = FALSE
    )
  }

  case_table_validation <- do.call(
    rbind,
    table_rows
  )

  rownames(
    case_table_validation
  ) <- NULL

  graph <- igraph::read_graph(
    graphml_file,
    format = "graphml"
  )

  log_lines <- readLines(
    log_path,
    warn = FALSE,
    encoding = "UTF-8"
  )

  pipeline_done <- any(
    grepl(
      "[CancerPPIr] Done.",
      log_lines,
      fixed = TRUE
    )
  )

  internal_validation <- expected_evidence$validation

  internal_validation$sample_id <- sample_id

  internal_validation <- internal_validation[
    ,
    c(
      "sample_id",
      setdiff(
        names(
          internal_validation
        ),
        "sample_id"
      )
    ),
    drop = FALSE
  ]

  module_annotations <- expected_evidence$module_annotations
  node_annotations <- expected_evidence$node_annotations

  case_pass <- (
    technical_sheet_order_valid &&
      all(
        case_table_validation$schema_identical
      ) &&
      all(
        case_table_validation$dimensions_identical
      ) &&
      all(
        case_table_validation$values_identical
      ) &&
      all(
        as.character(
          internal_validation$status
        ) == "PASS"
      ) &&
      igraph::vcount(graph) == nrow(
        node_annotations
      ) &&
      pipeline_done
  )

  all_case_summary[[sample_id]] <- data.frame(
    sample_id = sample_id,
    input_file = basename(
      input_path
    ),
    output_folder = basename(
      output_case_directory
    ),
    pipeline_exit_status = exit_status,
    pipeline_done = pipeline_done,
    technical_sheet_order_valid =
      technical_sheet_order_valid,
    module_count = nrow(
      module_annotations
    ),
    node_count = nrow(
      node_annotations
    ),
    graph_nodes = igraph::vcount(
      graph
    ),
    graph_edges = igraph::ecount(
      graph
    ),
    priority_eligible_modules = sum(
      safe_logical(
        module_annotations$priority_eligible
      ),
      na.rm = TRUE
    ),
    technical_or_covariate_modules = sum(
      module_annotations$interpretation_class ==
        "technical_or_covariate",
      na.rm = TRUE
    ),
    mixed_biological_modules = sum(
      module_annotations$interpretation_class ==
        "mixed_biological",
      na.rm = TRUE
    ),
    unresolved_modules = sum(
      module_annotations$interpretation_class ==
        "unresolved",
      na.rm = TRUE
    ),
    significant_term_count = nrow(
      expected_evidence$significant_module_terms
    ),
    rule_evidence_rows = nrow(
      expected_evidence$module_rule_evidence
    ),
    internal_validation_failures = sum(
      as.character(
        internal_validation$status
      ) == "FAIL"
    ),
    exported_table_failures = sum(
      !case_table_validation$values_identical
    ),
    case_pass = case_pass,
    stringsAsFactors = FALSE
  )

  all_table_validation[[sample_id]] <- case_table_validation

  all_internal_validation[[sample_id]] <- internal_validation

  message(
    "[phase 4.4B] ",
    sample_id,
    ": ",
    if (case_pass) {
      "PASS"
    } else {
      "FAIL"
    },
    "; ",
    nrow(
      module_annotations
    ),
    " modules; ",
    nrow(
      node_annotations
    ),
    " nodes."
  )
}

case_summary <- do.call(
  rbind,
  all_case_summary
)

table_validation <- do.call(
  rbind,
  all_table_validation
)

internal_validation <- do.call(
  rbind,
  all_internal_validation
)

rownames(case_summary) <- NULL
rownames(table_validation) <- NULL
rownames(internal_validation) <- NULL

summary_file <- file.path(
  output_root,
  "phase_4_multicase_technical_export_summary.csv"
)

table_validation_file <- file.path(
  output_root,
  "phase_4_multicase_technical_export_table_validation.csv"
)

internal_validation_file <- file.path(
  output_root,
  "phase_4_multicase_technical_export_internal_validation.csv"
)

utils::write.csv(
  case_summary,
  file = summary_file,
  row.names = FALSE,
  na = ""
)

utils::write.csv(
  table_validation,
  file = table_validation_file,
  row.names = FALSE,
  na = ""
)

utils::write.csv(
  internal_validation,
  file = internal_validation_file,
  row.names = FALSE,
  na = ""
)

cat(
  "\nPHASE 4.4B MULTICASE TECHNICAL EVIDENCE EXPORT VALIDATION\n\n"
)

print(
  case_summary,
  row.names = FALSE
)

cat(
  "\nExported table validation:\n"
)

print(
  table_validation[
    ,
    c(
      "sample_id",
      "sheet_name",
      "schema_identical",
      "dimensions_identical",
      "values_identical",
      "differing_columns"
    ),
    drop = FALSE
  ],
  row.names = FALSE
)

overall_pass <- (
  nrow(case_summary) == 7L &&
    all(
      case_summary$case_pass
    ) &&
    all(
      table_validation$schema_identical
    ) &&
    all(
      table_validation$dimensions_identical
    ) &&
    all(
      table_validation$values_identical
    ) &&
    !any(
      as.character(
        internal_validation$status
      ) == "FAIL"
    )
)

cat(
  "\nOutput files:\n",
  "- ",
  summary_file,
  "\n- ",
  table_validation_file,
  "\n- ",
  internal_validation_file,
  "\n",
  sep = ""
)

if (!overall_pass) {
  cat(
    "\nMULTICASE TECHNICAL EXPORT VALIDATION: FAILED\n"
  )

  quit(
    save = "no",
    status = 1L
  )
}

cat(
  "\nMULTICASE TECHNICAL EXPORT VALIDATION: PASSED\n"
)
