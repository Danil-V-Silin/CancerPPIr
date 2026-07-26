#!/usr/bin/env Rscript

# Classify deterministic and stochastic legacy outputs and generate
# consistent public baseline documentation.

environment_dir <- "tests/reference/environment"
reference_root <- "tests/reference"

sheet_path <- file.path(
  environment_dir,
  "legacy_determinism_sheet_comparison.csv"
)

artifact_path <- file.path(
  environment_dir,
  "legacy_determinism_artifact_comparison.csv"
)

if (!file.exists(sheet_path) || !file.exists(artifact_path)) {
  stop(
    "Legacy comparison files are missing. Run finalize_legacy_baseline.R first.",
    call. = FALSE
  )
}

sheet_comparison <- utils::read.csv(
  sheet_path,
  stringsAsFactors = FALSE
)

artifact_comparison <- utils::read.csv(
  artifact_path,
  stringsAsFactors = FALSE
)

sheet_comparison$changed <- !sheet_comparison$identical_content

changed_sheets <- sheet_comparison[
  sheet_comparison$changed,
  c(
    "case_id",
    "workbook",
    "sheet_name",
    "primary_rows",
    "repeat_rows",
    "primary_columns",
    "repeat_columns",
    "same_dimensions"
  )
]

utils::write.csv(
  changed_sheets,
  file.path(environment_dir, "legacy_changed_sheets.csv"),
  row.names = FALSE,
  na = ""
)

sheet_frequency <- stats::aggregate(
  changed ~ workbook + sheet_name,
  data = sheet_comparison,
  FUN = sum
)

names(sheet_frequency)[3] <- "changed_cases"

sheet_frequency <- sheet_frequency[
  order(
    -sheet_frequency$changed_cases,
    sheet_frequency$workbook,
    sheet_frequency$sheet_name
  ),
]

utils::write.csv(
  sheet_frequency,
  file.path(
    environment_dir,
    "legacy_changed_sheet_frequency.csv"
  ),
  row.names = FALSE,
  na = ""
)

sheet_frequency$baseline_class <- ifelse(
  sheet_frequency$changed_cases == 0L,
  "strict_deterministic",
  ifelse(
    sheet_frequency$changed_cases == 7L,
    "stochastic_or_module_dependent",
    "partially_stable"
  )
)

utils::write.csv(
  sheet_frequency,
  file.path(
    environment_dir,
    "legacy_regression_scope.csv"
  ),
  row.names = FALSE,
  na = ""
)

sheet_key <- function(workbook, sheet_name) {
  paste(workbook, sheet_name, sep = "\r")
}

strict_scope <- sheet_frequency[
  sheet_frequency$baseline_class == "strict_deterministic",
]

partial_scope <- sheet_frequency[
  sheet_frequency$baseline_class == "partially_stable",
]

stochastic_scope <- sheet_frequency[
  sheet_frequency$baseline_class ==
    "stochastic_or_module_dependent",
]

strict_keys <- sheet_key(
  strict_scope$workbook,
  strict_scope$sheet_name
)

partial_keys <- sheet_key(
  partial_scope$workbook,
  partial_scope$sheet_name
)

stochastic_keys <- sheet_key(
  stochastic_scope$workbook,
  stochastic_scope$sheet_name
)

case_ids <- unique(sheet_comparison$case_id)

case_summary <- do.call(
  rbind,
  lapply(
    case_ids,
    function(case_id) {
      case_sheets <- sheet_comparison[
        sheet_comparison$case_id == case_id,
      ]

      case_artifacts <- artifact_comparison[
        artifact_comparison$case_id == case_id,
      ]

      case_keys <- sheet_key(
        case_sheets$workbook,
        case_sheets$sheet_name
      )

      strict_rows <- case_sheets[
        case_keys %in% strict_keys,
      ]

      partial_rows <- case_sheets[
        case_keys %in% partial_keys,
      ]

      stochastic_rows <- case_sheets[
        case_keys %in% stochastic_keys,
      ]

      string_row <- case_artifacts[
        case_artifacts$artifact == "string_links",
      ]

      graph_row <- case_artifacts[
        case_artifacts$artifact == "cytoscape_graph",
      ]

      all_expected_files_exist <- all(
        case_artifacts$primary_exists &
          case_artifacts$repeat_exists
      )

      string_links_identical <- (
        nrow(string_row) == 1L &&
          isTRUE(string_row$normalized_identical[[1]])
      )

      graph_counts_identical <- (
        nrow(graph_row) == 1L &&
          isTRUE(
            graph_row$graph_node_edge_counts_identical[[1]]
          )
      )

      strict_sheets_identical <- (
        nrow(strict_rows) == length(strict_keys) &&
          all(strict_rows$identical_content)
      )

      exact_full_report_match <- all(
        all_expected_files_exist,
        string_links_identical,
        graph_counts_identical,
        all(case_sheets$identical_content)
      )

      strict_regression_core_match <- all(
        all_expected_files_exist,
        string_links_identical,
        graph_counts_identical,
        strict_sheets_identical
      )

      data.frame(
        case_id = case_id,
        compared_sheets = nrow(case_sheets),
        identical_sheets = sum(
          case_sheets$identical_content
        ),
        changed_sheets = sum(
          !case_sheets$identical_content
        ),
        strict_sheets_compared = nrow(strict_rows),
        strict_sheets_identical = sum(
          strict_rows$identical_content
        ),
        strict_regression_core_match =
          strict_regression_core_match,
        exact_full_report_match =
          exact_full_report_match,
        partially_stable_variation_detected = (
          nrow(partial_rows) > 0L &&
            any(!partial_rows$identical_content)
        ),
        module_dependent_variation_detected = (
          nrow(stochastic_rows) > 0L &&
            any(!stochastic_rows$identical_content)
        ),
        string_links_identical =
          string_links_identical,
        graph_node_edge_counts_identical =
          graph_counts_identical,
        primary_graph_read_ok =
          graph_row$primary_graph_read_ok[[1]],
        repeat_graph_read_ok =
          graph_row$repeat_graph_read_ok[[1]],
        graphml_raw_identical =
          graph_row$raw_identical[[1]],
        all_expected_files_exist =
          all_expected_files_exist,
        stringsAsFactors = FALSE
      )
    }
  )
)

utils::write.csv(
  case_summary,
  file.path(
    environment_dir,
    "legacy_determinism_case_summary.csv"
  ),
  row.names = FALSE,
  na = ""
)

format_sheet_list <- function(data) {
  if (nrow(data) == 0L) {
    return("- None.")
  }

  paste0(
    "- `",
    data$sheet_name,
    "`",
    ifelse(
      data$baseline_class == "partially_stable",
      paste0(
        " — changed in ",
        data$changed_cases,
        " of 7 cases"
      ),
      ""
    ),
    ";"
  )
}

strict_lines <- format_sheet_list(strict_scope)
partial_lines <- format_sheet_list(partial_scope)
stochastic_lines <- format_sheet_list(stochastic_scope)

graph_failures <- unique(
  artifact_comparison$case_id[
    artifact_comparison$artifact == "cytoscape_graph" &
      !artifact_comparison$primary_graph_read_ok
  ]
)

baseline_scope <- c(
  "# CancerPPIr legacy regression baseline",
  "",
  "This directory records the behavior of the preserved CancerPPIr",
  "implementation before architectural refactoring.",
  "",
  "## Reference cases",
  "",
  "The baseline includes A01, K01, L01, M01, P01, P02 and R01.",
  "",
  "`Genes_Ar.csv` and `Genes_A2r.csv` are excluded.",
  "",
  "## Strict deterministic invariants",
  "",
  "Across two independent runs:",
  "",
  "- all seven analyses completed successfully;",
  "- all four expected artifacts were created for every case;",
  "- normalized `STRING_links.txt` content was identical;",
  "- GraphML node and edge counts were identical;",
  "- input and STRING-resource checksums were unchanged.",
  "",
  "The following workbook sheets were identical in all seven cases:",
  "",
  strict_lines,
  "",
  "These outputs form the strict regression core.",
  "",
  "## Partially stable outputs",
  "",
  "The following sheets changed in some, but not all, cases:",
  "",
  partial_lines,
  "",
  "They must not be treated as strict checksum invariants.",
  "",
  "## Stochastic or module-dependent outputs",
  "",
  "Louvain community detection is not executed with an explicit random",
  "seed in the preserved legacy implementation.",
  "",
  "The following sheets changed in all seven cases:",
  "",
  stochastic_lines,
  "",
  "Differences include module assignments, module counts, functional",
  "labels and module-enrichment row counts.",
  "",
  "## Regression criteria",
  "",
  "The strict regression core requires:",
  "",
  "- successful execution;",
  "- identical input and STRING resources;",
  "- identical STRING interaction content;",
  "- identical network node and edge counts;",
  "- identical strict deterministic sheets;",
  "- presence of all required workbook sheets and columns.",
  "",
  "Exact Louvain module identifiers and module-dependent labels are not",
  "strict invariants of the legacy implementation.",
  "",
  "## GraphML limitation",
  "",
  paste0(
    "GraphML read-back fails for: ",
    paste(graph_failures, collapse = ", "),
    "."
  ),
  "",
  "The raw GraphML files are retained outside Git in the external",
  "baseline output directory. Their checksums, sizes, structural counts",
  "and read-back status are recorded in this repository.",
  "",
  "The refactored exporter must sanitize `Inf`, `-Inf`, `NaN` and",
  "unsupported numerical values and pass an igraph read-back test.",
  "",
  "## Public repository contents",
  "",
  "Detailed patient-specific workbook exports are not stored in Git.",
  "The repository contains only aggregate summaries, schemas, dimensions,",
  "checksums and determinism manifests."
)

writeLines(
  baseline_scope,
  file.path(reference_root, "BASELINE_SCOPE.md"),
  useBytes = TRUE
)

known_issues <- c(
  "# Known legacy baseline issues",
  "",
  "The following limitations were observed before refactoring:",
  "",
  "1. Input headers may fall back to positional interpretation as",
  "   `pvalue`, `logFC` and `gene`.",
  "2. HGNChelper reports non-approved symbols, and STRING does not map",
  "   every supplied identifier.",
  "3. Several packages were built under later R 4.5.x patch versions",
  "   than the active R 4.5.0 installation.",
  paste0(
    "4. GraphML read-back fails for ",
    paste(graph_failures, collapse = ", "),
    " because a numeric attribute triggers an integer or double overflow."
  ),
  "5. The two runs were not exactly identical at the workbook-sheet",
  "   level. Differences are concentrated in Louvain assignments and",
  "   module-dependent outputs. The underlying STRING interaction",
  "   content and network node/edge counts remained stable.",
  "",
  "Raw XLSX and GraphML checksums are diagnostic only. Binary metadata",
  "or serialization order can differ even when analytical structures",
  "remain equivalent."
)

writeLines(
  known_issues,
  file.path(reference_root, "KNOWN_LEGACY_ISSUES.md"),
  useBytes = TRUE
)

reference_readme <- c(
  "# CancerPPIr reference data",
  "",
  "This directory stores the public regression metadata for the",
  "preserved CancerPPIr legacy implementation.",
  "",
  "The full baseline includes A01, K01, L01, M01, P01, P02 and R01.",
  "`Genes_Ar.csv` and `Genes_A2r.csv` are excluded.",
  "",
  "Per-case directories contain only:",
  "",
  "- `artifact_manifest.csv` — sizes and checksums of external artifacts;",
  "- `network_summary.csv` — aggregate network properties and GraphML",
  "  read-back status.",
  "",
  "Detailed patient-specific input data, workbook sheet exports, XLSX",
  "files, GraphML files and STRING cache resources are stored outside",
  "the public Git repository.",
  "",
  "See `BASELINE_SCOPE.md` and `KNOWN_LEGACY_ISSUES.md`."
)

writeLines(
  reference_readme,
  file.path(reference_root, "README.md"),
  useBytes = TRUE
)

message(
  "[postprocess] Legacy baseline scope and documentation updated."
)
