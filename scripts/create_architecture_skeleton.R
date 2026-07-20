#!/usr/bin/env Rscript

# Create the target CancerPPIr source-module skeleton.
#
# This checkpoint creates only empty module files and an explicit loader.
# It does not modify cancerppir.R and does not move legacy functions.
#
# Run from the repository root:
#   Rscript scripts/create_architecture_skeleton.R

project_root <- normalizePath(
  ".",
  winslash = "/",
  mustWork = TRUE
)

main_script <- file.path(
  project_root,
  "cancerppir.R"
)

architecture_plan <- file.path(
  project_root,
  "docs",
  "architecture",
  "TARGET_ARCHITECTURE.md"
)

required_files <- c(
  main_script,
  architecture_plan
)

missing_required_files <- required_files[
  !file.exists(required_files)
]

if (length(missing_required_files) > 0L) {
  stop(
    paste0(
      "Run this script from the CancerPPIr repository root.\n",
      "Missing files:\n",
      paste(
        paste0("- ", missing_required_files),
        collapse = "\n"
      )
    ),
    call. = FALSE
  )
}

r_directory <- file.path(
  project_root,
  "R"
)

module_specification <- data.frame(
  file_name = c(
    "00_utils.R",
    "01_input.R",
    "02_string_mapping.R",
    "03_enrichment.R",
    "04_module_labeling.R",
    "05_reporting.R",
    "06_network_analysis.R",
    "07_pipeline.R"
  ),
  module_title = c(
    "Shared utilities",
    "Input handling",
    "HGNC and STRING mapping",
    "Functional enrichment",
    "Module labeling",
    "Output and reporting",
    "Network analysis",
    "Pipeline orchestration"
  ),
  responsibility = c(
    paste0(
      "Dependency-light validation, normalization, numeric, ranking ",
      "and shared text helpers."
    ),
    paste0(
      "Input delimiter detection, gene-table reading and input-column ",
      "normalization."
    ),
    paste0(
      "HGNC symbol handling, STRING identifier mapping, alias correction ",
      "and interaction retrieval."
    ),
    paste0(
      "Local STRING enrichment, optional online enrichment, filtering, ",
      "ranking and term collapsing."
    ),
    paste0(
      "Marker-based and rulebook-based module interpretation, confidence ",
      "assignment and supporting themes."
    ),
    paste0(
      "Output-table normalization, workbook preparation and report ",
      "generation."
    ),
    paste0(
      "Graph construction, connected components, centrality metrics, ",
      "candidate scoring and Louvain communities."
    ),
    paste0(
      "End-to-end CancerPPIr workflow coordination with explicit inputs ",
      "and returned analysis objects."
    )
  ),
  stringsAsFactors = FALSE
)

module_paths <- file.path(
  r_directory,
  module_specification$file_name
)

loader_path <- file.path(
  r_directory,
  "load_all.R"
)

all_target_paths <- c(
  module_paths,
  loader_path
)

existing_targets <- all_target_paths[
  file.exists(all_target_paths)
]

if (length(existing_targets) > 0L) {
  stop(
    paste0(
      "Architecture skeleton creation stopped because target files ",
      "already exist:\n",
      paste(
        paste0("- ", existing_targets),
        collapse = "\n"
      ),
      "\nNo existing files were overwritten."
    ),
    call. = FALSE
  )
}

dir.create(
  r_directory,
  recursive = TRUE,
  showWarnings = FALSE
)

for (module_index in seq_len(nrow(module_specification))) {
  module_title <- module_specification$module_title[
    module_index
  ]

  responsibility <- module_specification$responsibility[
    module_index
  ]

  module_lines <- c(
    paste0(
      "# CancerPPIr: ",
      module_title
    ),
    "#",
    paste0(
      "# Responsibility: ",
      responsibility
    ),
    "#",
    "# Architecture checkpoint 2.3",
    "#",
    paste0(
      "# This module intentionally contains no extracted legacy functions ",
      "at this checkpoint."
    ),
    paste0(
      "# Function definitions will be moved here incrementally without ",
      "semantic rewriting."
    ),
    ""
  )

  writeLines(
    module_lines,
    module_paths[[module_index]],
    useBytes = TRUE
  )
}

loader_lines <- c(
  "# CancerPPIr explicit source-module loader",
  "#",
  "# This loader defines a deterministic module-loading order.",
  "# It does not execute the analytical pipeline.",
  "",
  "load_cancerppir_modules <- function(",
  "  project_root = \".\",",
  "  envir = parent.frame()",
  ") {",
  "  if (!is.environment(envir)) {",
  "    stop(",
  "      \"Argument 'envir' must be an environment.\",",
  "      call. = FALSE",
  "    )",
  "  }",
  "",
  "  module_files <- file.path(",
  "    \"R\",",
  "    c(",
  "      \"00_utils.R\",",
  "      \"01_input.R\",",
  "      \"02_string_mapping.R\",",
  "      \"03_enrichment.R\",",
  "      \"04_module_labeling.R\",",
  "      \"05_reporting.R\",",
  "      \"06_network_analysis.R\",",
  "      \"07_pipeline.R\"",
  "    )",
  "  )",
  "",
  "  module_paths <- file.path(",
  "    project_root,",
  "    module_files",
  "  )",
  "",
  "  missing_modules <- module_paths[",
  "    !file.exists(module_paths)",
  "  ]",
  "",
  "  if (length(missing_modules) > 0L) {",
  "    stop(",
  "      paste0(",
  "        \"CancerPPIr source modules are missing:\\n\",",
  "        paste(",
  "          paste0(\"- \", missing_modules),",
  "          collapse = \"\\n\"",
  "        )",
  "      ),",
  "      call. = FALSE",
  "    )",
  "  }",
  "",
  "  for (module_path in module_paths) {",
  "    sys.source(",
  "      module_path,",
  "      envir = envir,",
  "      keep.source = TRUE",
  "    )",
  "  }",
  "",
  "  normalized_paths <- normalizePath(",
  "    module_paths,",
  "    winslash = \"/\",",
  "    mustWork = TRUE",
  "  )",
  "",
  "  invisible(normalized_paths)",
  "}",
  ""
)

writeLines(
  loader_lines,
  loader_path,
  useBytes = TRUE
)

created_paths <- normalizePath(
  all_target_paths,
  winslash = "/",
  mustWork = TRUE
)

message(
  "[architecture] Created R source-module skeleton."
)

message(
  "[architecture] Module files created: ",
  nrow(module_specification),
  "."
)

message(
  "[architecture] Explicit loader created: R/load_all.R."
)

message(
  "[architecture] No changes were made to cancerppir.R."
)

message(
  "[architecture] Created files:"
)

for (created_path in created_paths) {
  message(
    "- ",
    created_path
  )
}