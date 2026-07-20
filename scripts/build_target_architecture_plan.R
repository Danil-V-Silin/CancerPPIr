#!/usr/bin/env Rscript

# Build the target architecture plan for CancerPPIr from the structural
# inventory of the preserved monolithic implementation.
#
# This script does not modify cancerppir.R and does not execute the
# analytical workflow.
#
# Run from the repository root:
#   Rscript scripts/build_target_architecture_plan.R

inventory_path <- file.path(
  "docs",
  "architecture",
  "legacy_function_inventory.csv"
)

markers_path <- file.path(
  "docs",
  "architecture",
  "legacy_workflow_markers.csv"
)

output_dir <- file.path(
  "docs",
  "architecture"
)

required_files <- c(
  "cancerppir.R",
  inventory_path,
  markers_path
)

missing_files <- required_files[
  !file.exists(required_files)
]

if (length(missing_files) > 0L) {
  stop(
    paste0(
      "Required files are missing:\n",
      paste(
        paste0("- ", missing_files),
        collapse = "\n"
      )
    ),
    call. = FALSE
  )
}

dir.create(
  output_dir,
  recursive = TRUE,
  showWarnings = FALSE
)

function_inventory <- utils::read.csv(
  inventory_path,
  stringsAsFactors = FALSE,
  check.names = FALSE
)

workflow_markers <- utils::read.csv(
  markers_path,
  stringsAsFactors = FALSE,
  check.names = FALSE
)

required_inventory_columns <- c(
  "function_name",
  "arguments",
  "start_line",
  "end_line",
  "line_span"
)

missing_inventory_columns <- setdiff(
  required_inventory_columns,
  names(function_inventory)
)

if (length(missing_inventory_columns) > 0L) {
  stop(
    paste0(
      "Function inventory is missing required columns: ",
      paste(
        missing_inventory_columns,
        collapse = ", "
      )
    ),
    call. = FALSE
  )
}

if (anyDuplicated(function_inventory$function_name)) {
  duplicated_functions <- unique(
    function_inventory$function_name[
      duplicated(function_inventory$function_name)
    ]
  )

  stop(
    paste0(
      "Duplicated functions in the inventory: ",
      paste(
        duplicated_functions,
        collapse = ", "
      )
    ),
    call. = FALSE
  )
}

if (
  anyNA(function_inventory$start_line) ||
    anyNA(function_inventory$end_line) ||
    anyNA(function_inventory$line_span)
) {
  stop(
    paste0(
      "The function inventory contains missing source ranges. ",
      "Run scripts/inventory_legacy_architecture.R again."
    ),
    call. = FALSE
  )
}

source_lines <- readLines(
  "cancerppir.R",
  warn = FALSE,
  encoding = "UTF-8"
)

marker_line <- function(marker_name) {
  matched <- workflow_markers[
    workflow_markers$marker == marker_name,
    "line_numbers",
    drop = TRUE
  ]

  if (length(matched) != 1L) {
    return(NA_character_)
  }

  as.character(matched[[1]])
}

markdown_escape <- function(x) {
  x <- as.character(x)
  x[is.na(x)] <- ""
  x <- gsub("\r|\n", " ", x)
  gsub("\\|", "\\\\|", x)
}

markdown_table <- function(data) {
  if (nrow(data) == 0L) {
    return("_No records._")
  }

  formatted <- as.data.frame(
    lapply(
      data,
      markdown_escape
    ),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )

  header <- paste0(
    "| ",
    paste(
      names(formatted),
      collapse = " | "
    ),
    " |"
  )

  separator <- paste0(
    "| ",
    paste(
      rep("---", ncol(formatted)),
      collapse = " | "
    ),
    " |"
  )

  rows <- apply(
    formatted,
    1L,
    function(row) {
      paste0(
        "| ",
        paste(
          row,
          collapse = " | "
        ),
        " |"
      )
    }
  )

  c(
    header,
    separator,
    rows
  )
}

# -------------------------------------------------------------------------
# 1. Target source modules
# -------------------------------------------------------------------------

target_modules <- data.frame(
  module_id = c(
    "00_utils",
    "01_input",
    "02_string_mapping",
    "03_enrichment",
    "04_module_labeling",
    "05_reporting",
    "06_network_analysis",
    "07_pipeline",
    "load_all"
  ),
  target_file = c(
    "R/00_utils.R",
    "R/01_input.R",
    "R/02_string_mapping.R",
    "R/03_enrichment.R",
    "R/04_module_labeling.R",
    "R/05_reporting.R",
    "R/06_network_analysis.R",
    "R/07_pipeline.R",
    "R/load_all.R"
  ),
  responsibility = c(
    paste0(
      "Small dependency-light helpers, validation, numeric utilities, ",
      "normalization helpers and shared text utilities."
    ),
    paste0(
      "Input delimiter detection, input-table reading and input-column ",
      "normalization."
    ),
    paste0(
      "HGNC and STRING identifier handling, alias correction, mapping ",
      "fallbacks and STRING interaction retrieval."
    ),
    paste0(
      "Local STRING enrichment, optional online enrichment, enrichment ",
      "filtering, ranking and term collapsing."
    ),
    paste0(
      "Marker-based labels, rulebook-based module interpretation, ",
      "confidence scoring and supporting biological themes."
    ),
    paste0(
      "Output-table normalization, worksheet preparation and Excel ",
      "workbook generation."
    ),
    paste0(
      "Graph construction, connected components, centrality metrics, ",
      "candidate scoring, Louvain modules and graph-level summaries."
    ),
    paste0(
      "End-to-end CancerPPIr orchestration with explicit inputs, ",
      "configuration and returned analysis objects."
    ),
    paste0(
      "Explicit source loader defining the stable module-loading order ",
      "for the script-based workflow."
    )
  ),
  extraction_order = seq_len(9L),
  contains_existing_functions = c(
    TRUE,
    TRUE,
    TRUE,
    TRUE,
    TRUE,
    TRUE,
    FALSE,
    FALSE,
    FALSE
  ),
  stringsAsFactors = FALSE
)

# -------------------------------------------------------------------------
# 2. Complete mapping of all current functions
# -------------------------------------------------------------------------

function_groups <- list(
  "00_utils" = c(
    "%||%",
    "check_package",
    "parse_bool",
    "is_bool_like",
    "normalize_enrichment_mode",
    "normalize_path_for_compare",
    "msg",
    "as_number",
    "clean_names",
    "find_column",
    "safe_min",
    "safe_mean",
    "minmax",
    "top_genes",
    "collapse_terms",
    "truncate_text",
    "normalize_label_text",
    "humanize_label",
    "rank_desc",
    "evidence_level",
    "metric_value"
  ),
  "01_input" = c(
    "guess_separator",
    "read_gene_table"
  ),
  "02_string_mapping" = c(
    "classify_symbol_pattern",
    "status_from_mapping",
    "pick_string_id_col",
    "pick_alias_col",
    "pick_preferred_name_col",
    "make_string_links",
    "map_to_string"
  ),
  "03_enrichment" = c(
    "clean_enrichment_table",
    "run_gprofiler",
    "string_enrichment_terms_candidates",
    "find_string_enrichment_terms",
    "download_string_enrichment_terms",
    "read_string_enrichment_terms",
    "run_local_string_enrichment",
    "run_string_enrichment_online",
    "is_generic_enrichment_term",
    "add_enrichment_priority",
    "select_top_enrichment",
    "collapse_module_enrichment",
    "collapse_gprofiler_module_enrichment",
    "collapse_string_online_module_enrichment",
    "online_concordance_status"
  ),
  "04_module_labeling" = c(
    "label_module_by_markers",
    "clean_module_label_from_terms",
    "max_marker_overlap_count",
    "has_assigned_label",
    "label_rulebook_table",
    "matches_any_pattern",
    "count_matching_patterns",
    "extract_marker_counts",
    "marker_count_for_rule",
    "label_evidence_score",
    "assign_label_confidence",
    "label_source_from_counts",
    "supporting_themes_from_evidence",
    "assign_module_label_with_rules"
  ),
  "05_reporting" = c(
    "write_excel",
    "sanitize_sheet_name",
    "as_output_table",
    "write_readable_xlsx"
  )
)

function_map_rows <- lapply(
  names(function_groups),
  function(module_id) {
    data.frame(
      function_name = function_groups[[module_id]],
      module_id = module_id,
      stringsAsFactors = FALSE
    )
  }
)

function_map <- do.call(
  rbind,
  function_map_rows
)

if (anyDuplicated(function_map$function_name)) {
  duplicated_mapping <- unique(
    function_map$function_name[
      duplicated(function_map$function_name)
    ]
  )

  stop(
    paste0(
      "Functions assigned to more than one target module: ",
      paste(
        duplicated_mapping,
        collapse = ", "
      )
    ),
    call. = FALSE
  )
}

inventory_functions <- sort(
  function_inventory$function_name
)

mapped_functions <- sort(
  function_map$function_name
)

missing_from_plan <- setdiff(
  inventory_functions,
  mapped_functions
)

unknown_in_plan <- setdiff(
  mapped_functions,
  inventory_functions
)

if (length(missing_from_plan) > 0L) {
  stop(
    paste0(
      "Functions missing from the target architecture plan: ",
      paste(
        missing_from_plan,
        collapse = ", "
      )
    ),
    call. = FALSE
  )
}

if (length(unknown_in_plan) > 0L) {
  stop(
    paste0(
      "Architecture plan references functions not present in the inventory: ",
      paste(
        unknown_in_plan,
        collapse = ", "
      )
    ),
    call. = FALSE
  )
}

if (!identical(inventory_functions, mapped_functions)) {
  stop(
    "Function mapping does not exactly cover the legacy inventory.",
    call. = FALSE
  )
}

module_match <- match(
  function_map$module_id,
  target_modules$module_id
)

inventory_match <- match(
  function_map$function_name,
  function_inventory$function_name
)

function_map$target_file <- target_modules$target_file[
  module_match
]

function_map$extraction_order <- target_modules$extraction_order[
  module_match
]

function_map$arguments <- function_inventory$arguments[
  inventory_match
]

function_map$start_line <- function_inventory$start_line[
  inventory_match
]

function_map$end_line <- function_inventory$end_line[
  inventory_match
]

function_map$line_span <- function_inventory$line_span[
  inventory_match
]

function_map <- function_map[
  order(
    function_map$extraction_order,
    function_map$start_line,
    function_map$function_name
  ),
  c(
    "function_name",
    "arguments",
    "start_line",
    "end_line",
    "line_span",
    "module_id",
    "target_file",
    "extraction_order"
  ),
  drop = FALSE
]

# -------------------------------------------------------------------------
# 3. Module-level summary
# -------------------------------------------------------------------------

target_modules$function_count <- vapply(
  target_modules$module_id,
  function(module_id) {
    sum(
      function_map$module_id == module_id
    )
  },
  FUN.VALUE = integer(1)
)

target_modules$legacy_source_lines <- vapply(
  target_modules$module_id,
  function(module_id) {
    sum(
      function_map$line_span[
        function_map$module_id == module_id
      ],
      na.rm = TRUE
    )
  },
  FUN.VALUE = numeric(1)
)

target_modules <- target_modules[
  order(target_modules$extraction_order),
  ,
  drop = FALSE
]

# -------------------------------------------------------------------------
# 4. Current workflow anchors and target ownership
# -------------------------------------------------------------------------

workflow_plan <- data.frame(
  workflow_stage = c(
    "CLI and configuration",
    "Input-table ingestion",
    "HGNC symbol normalization",
    "STRING initialization and mapping",
    "STRING subnetwork construction",
    "Network metrics and candidate scoring",
    "Functional enrichment",
    "Module interpretation",
    "Report assembly and export"
  ),
  current_anchor = c(
    paste0(
      "commandArgs at line ",
      marker_line("commandArgs")
    ),
    paste0(
      "Reading input table at line ",
      marker_line("Reading input table")
    ),
    paste0(
      "Checking gene symbols at line ",
      marker_line("Checking gene symbols")
    ),
    paste0(
      "STRING initialization at line ",
      marker_line("Initializing STRINGdb"),
      "; mapping at line ",
      marker_line("Mapping genes to STRING identifiers")
    ),
    paste0(
      "Building STRING subnetwork at line ",
      marker_line("Building STRING subnetwork")
    ),
    paste0(
      "Calculating network metrics at line ",
      marker_line("Calculating network metrics")
    ),
    paste0(
      "Functional enrichment at line ",
      marker_line("Running functional enrichment analysis")
    ),
    "Module labeling helpers and module-dependent top-level expressions",
    paste0(
      "Writing consolidated output files at line ",
      marker_line("Writing consolidated output files")
    )
  ),
  target_owner = c(
    "cancerppir.R and R/07_pipeline.R",
    "R/01_input.R and R/07_pipeline.R",
    "R/02_string_mapping.R",
    "R/02_string_mapping.R and R/07_pipeline.R",
    "R/06_network_analysis.R",
    "R/06_network_analysis.R",
    "R/03_enrichment.R",
    "R/04_module_labeling.R",
    "R/05_reporting.R and R/07_pipeline.R"
  ),
  planned_entry_point = c(
    "parse CLI arguments and call run_cancerppir()",
    "read_gene_table()",
    "normalize and audit gene symbols",
    "prepare_string_mapping()",
    "build_string_network()",
    "calculate_network_metrics()",
    "run_enrichment_stage()",
    "build_module_annotations()",
    "assemble_and_write_reports()"
  ),
  stringsAsFactors = FALSE
)

# -------------------------------------------------------------------------
# 5. Safe extraction sequence
# -------------------------------------------------------------------------

extraction_sequence <- data.frame(
  step = seq_len(10L),
  checkpoint = c(
    "Architecture documentation",
    "Module skeleton and loader",
    "Shared utilities",
    "Input handling",
    "STRING mapping",
    "Enrichment helpers",
    "Module-labeling helpers",
    "Reporting helpers",
    "Network and pipeline orchestration",
    "Slim CLI and final regression"
  ),
  planned_change = c(
    paste0(
      "Commit inventory and target architecture documents without ",
      "changing cancerppir.R."
    ),
    paste0(
      "Create the R directory, empty target files and an explicit ",
      "R/load_all.R source order."
    ),
    paste0(
      "Move only dependency-light utility function definitions into ",
      "R/00_utils.R."
    ),
    paste0(
      "Move delimiter detection and read_gene_table() into ",
      "R/01_input.R."
    ),
    paste0(
      "Move HGNC/STRING mapping helpers into R/02_string_mapping.R."
    ),
    paste0(
      "Move enrichment cache, local enrichment, optional online ",
      "enrichment and term-ranking helpers into R/03_enrichment.R."
    ),
    paste0(
      "Move marker and rulebook interpretation helpers into ",
      "R/04_module_labeling.R."
    ),
    paste0(
      "Move workbook and output-table helpers into R/05_reporting.R."
    ),
    paste0(
      "Wrap graph construction, metrics, scoring and the remaining ",
      "top-level workflow in explicit functions."
    ),
    paste0(
      "Reduce cancerppir.R to an entry-point adapter and run the full ",
      "seven-case regression comparison."
    )
  ),
  regression_gate = c(
    "No analytical execution required; source checksum must remain unchanged.",
    "Parse all R files; legacy workflow remains unchanged.",
    "R01 pilot followed by strict comparison.",
    "R01 pilot followed by strict comparison.",
    "R01 pilot, then all seven cases.",
    "R01 pilot, then all seven cases.",
    "R01 pilot plus structural module-output comparison.",
    "All seven cases and workbook-schema comparison.",
    "All seven cases and complete Phase 0 strict regression core.",
    "All seven cases, clean Git state and architecture-complete tag."
  ),
  stringsAsFactors = FALSE
)

# -------------------------------------------------------------------------
# 6. Planned orchestration functions
# -------------------------------------------------------------------------

planned_functions <- data.frame(
  function_name = c(
    "load_cancerppir_modules",
    "prepare_string_mapping",
    "build_string_network",
    "calculate_network_metrics",
    "build_candidate_tables",
    "run_enrichment_stage",
    "build_module_annotations",
    "assemble_and_write_reports",
    "run_cancerppir"
  ),
  target_file = c(
    "R/load_all.R",
    "R/02_string_mapping.R",
    "R/06_network_analysis.R",
    "R/06_network_analysis.R",
    "R/06_network_analysis.R",
    "R/03_enrichment.R",
    "R/04_module_labeling.R",
    "R/05_reporting.R",
    "R/07_pipeline.R"
  ),
  purpose = c(
    "Source project modules in an explicit deterministic order.",
    "Perform HGNC normalization, STRING mapping and alias correction.",
    "Construct and normalize the patient-specific STRING graph.",
    "Calculate components, centralities and Louvain communities.",
    "Calculate candidate scores and candidate-ranking tables.",
    "Execute local and optional online functional enrichment.",
    "Assign putative module labels, confidence and supporting themes.",
    "Create analytical, technical, GraphML and STRING-link outputs.",
    "Coordinate the complete patient-specific CancerPPIr workflow."
  ),
  status = "planned_new_function",
  stringsAsFactors = FALSE
)

# -------------------------------------------------------------------------
# 7. Write machine-readable planning artifacts
# -------------------------------------------------------------------------

utils::write.csv(
  function_map,
  file.path(
    output_dir,
    "target_function_module_map.csv"
  ),
  row.names = FALSE,
  na = ""
)

utils::write.csv(
  target_modules,
  file.path(
    output_dir,
    "target_module_manifest.csv"
  ),
  row.names = FALSE,
  na = ""
)

utils::write.csv(
  workflow_plan,
  file.path(
    output_dir,
    "target_workflow_plan.csv"
  ),
  row.names = FALSE,
  na = ""
)

utils::write.csv(
  extraction_sequence,
  file.path(
    output_dir,
    "architecture_extraction_sequence.csv"
  ),
  row.names = FALSE,
  na = ""
)

utils::write.csv(
  planned_functions,
  file.path(
    output_dir,
    "planned_orchestration_functions.csv"
  ),
  row.names = FALSE,
  na = ""
)

# -------------------------------------------------------------------------
# 8. Build the human-readable target architecture document
# -------------------------------------------------------------------------

tree_lines <- c(
  "```text",
  "CancerPPIr/",
  "|-- cancerppir.R",
  "|-- R/",
  "|   |-- 00_utils.R",
  "|   |-- 01_input.R",
  "|   |-- 02_string_mapping.R",
  "|   |-- 03_enrichment.R",
  "|   |-- 04_module_labeling.R",
  "|   |-- 05_reporting.R",
  "|   |-- 06_network_analysis.R",
  "|   |-- 07_pipeline.R",
  "|   `-- load_all.R",
  "|-- legacy/",
  "|   `-- cancerppir_legacy.R",
  "|-- scripts/",
  "|-- tests/",
  "`-- docs/",
  "```"
)

module_table <- target_modules[
  ,
  c(
    "target_file",
    "responsibility",
    "function_count",
    "legacy_source_lines",
    "extraction_order"
  ),
  drop = FALSE
]

names(module_table) <- c(
  "Target file",
  "Responsibility",
  "Current functions",
  "Legacy function lines",
  "Order"
)

workflow_table <- workflow_plan
names(workflow_table) <- c(
  "Workflow stage",
  "Current source anchor",
  "Target owner",
  "Planned entry point"
)

sequence_table <- extraction_sequence
names(sequence_table) <- c(
  "Step",
  "Checkpoint",
  "Planned change",
  "Regression gate"
)

planned_table <- planned_functions[
  ,
  c(
    "function_name",
    "target_file",
    "purpose"
  ),
  drop = FALSE
]

names(planned_table) <- c(
  "Planned function",
  "Target file",
  "Purpose"
)

architecture_document <- c(
  "# CancerPPIr target architecture",
  "",
  "## Scope",
  "",
  paste0(
    "This document defines the architecture-preserving decomposition of ",
    "the current monolithic CancerPPIr workflow."
  ),
  "",
  paste0(
    "The current source contains ",
    length(source_lines),
    " lines and ",
    nrow(function_inventory),
    " top-level function definitions."
  ),
  "",
  paste0(
    "All ",
    nrow(function_inventory),
    " current functions are assigned exactly once to a target module."
  ),
  "",
  "No analytical behavior is intentionally changed during this phase.",
  "",
  "## Target source tree",
  "",
  tree_lines,
  "",
  "## Module responsibilities",
  "",
  markdown_table(module_table),
  "",
  "## Workflow ownership",
  "",
  markdown_table(workflow_table),
  "",
  "## Planned orchestration functions",
  "",
  markdown_table(planned_table),
  "",
  "## Safe extraction sequence",
  "",
  markdown_table(sequence_table),
  "",
  "## Architectural rules",
  "",
  paste0(
    "1. `legacy/cancerppir_legacy.R` remains immutable and continues to ",
    "represent the preserved pre-refactor workflow."
  ),
  paste0(
    "2. Function bodies are moved without semantic rewriting during their ",
    "first extraction."
  ),
  paste0(
    "3. The source order is explicit in `R/load_all.R`; alphabetical ",
    "filesystem ordering is not used implicitly."
  ),
  paste0(
    "4. `cancerppir.R` remains executable through the existing CLI contract ",
    "throughout the refactor."
  ),
  paste0(
    "5. Each extraction checkpoint must pass the R01 pilot before a full ",
    "seven-case run."
  ),
  paste0(
    "6. Strict deterministic outputs are compared exactly; Louvain-dependent ",
    "outputs are compared structurally."
  ),
  paste0(
    "7. Input, result and STRING-cache directories remain outside the ",
    "repository."
  ),
  "",
  "## Explicitly deferred behavior changes",
  "",
  paste0(
    "- No Louvain random seed is introduced during architecture-only ",
    "extraction."
  ),
  "- Candidate-score formulas and ranking rules are not changed.",
  "- Functional-label rules and confidence thresholds are not changed.",
  "- Input-column interpretation is not changed.",
  "- STRING score thresholds and enrichment backgrounds are not changed.",
  paste0(
    "- GraphML numerical sanitization is deferred to a separately documented ",
    "behavior-correction phase."
  ),
  "- Output filenames and workbook sheet names are preserved.",
  "",
  "## Generated planning artifacts",
  "",
  "- `target_function_module_map.csv`",
  "- `target_module_manifest.csv`",
  "- `target_workflow_plan.csv`",
  "- `architecture_extraction_sequence.csv`",
  "- `planned_orchestration_functions.csv`"
)

writeLines(
  architecture_document,
  file.path(
    output_dir,
    "TARGET_ARCHITECTURE.md"
  ),
  useBytes = TRUE
)

# -------------------------------------------------------------------------
# 9. Final validation
# -------------------------------------------------------------------------

mapped_count <- nrow(function_map)
inventory_count <- nrow(function_inventory)

if (mapped_count != inventory_count) {
  stop(
    paste0(
      "Function coverage validation failed: mapped ",
      mapped_count,
      " of ",
      inventory_count,
      " functions."
    ),
    call. = FALSE
  )
}

if (anyNA(function_map$target_file)) {
  stop(
    "One or more functions have no target file.",
    call. = FALSE
  )
}

message(
  "[architecture] Target architecture written to ",
  output_dir,
  "."
)

message(
  "[architecture] Legacy functions mapped: ",
  mapped_count,
  "/",
  inventory_count,
  "."
)

message(
  "[architecture] Target modules: ",
  nrow(target_modules),
  "."
)

message(
  "[architecture] No changes were made to cancerppir.R."
)