#!/usr/bin/env Rscript

# Load extracted CancerPPIr source modules.
.cancerppir_file_argument <- grep(
  "^--file=",
  commandArgs(trailingOnly = FALSE),
  value = TRUE
)

.cancerppir_project_root <- if (
  length(.cancerppir_file_argument) >= 1L
) {
  dirname(
    normalizePath(
      sub(
        "^--file=",
        "",
        .cancerppir_file_argument[[1L]]
      ),
      winslash = "/",
      mustWork = TRUE
    )
  )
} else {
  normalizePath(
    ".",
    winslash = "/",
    mustWork = TRUE
  )
}

source(
  file.path(
    .cancerppir_project_root,
    "R",
    "load_all.R"
  ),
  local = TRUE
)

load_cancerppir_modules(
  project_root = .cancerppir_project_root,
  envir = environment()
)

rm(
  .cancerppir_file_argument,
  .cancerppir_project_root
)


# CancerPPIr
# Patient-specific PPI subnetwork analysis from bulk RNA-seq-derived gene tables.

.cancerppir_usage_text <- paste(
  "CancerPPIr",
  "",
  "Usage:",
  "  Rscript cancerppir.R input.csv results_dir string_cache [score_threshold] [top_n] [run_enrichment]",
  "  Rscript cancerppir.R --help",
  "",
  "Defaults:",
  "  score_threshold = 400",
  "  top_n = 30",
  "  run_enrichment = TRUE (offline local STRING enrichment)",
  "",
  "Output folder:",
  "  input.csv + results_dir=results -> results/input/",
  "",
  "Principal output files:",
  "  CancerPPIr_Analytical_Report.xlsx",
  "  CancerPPIr_Technical_Report.xlsx",
  "  Network_for_Cytoscape.graphml",
  "  STRING_links.txt",
  "  CancerPPIr_Output_Manifest.json",
  "  CancerPPIr_Output_Checksums.sha256",
  "",
  "Example:",
  "  Rscript cancerppir.R examples/minimal_input.csv results string_cache 400 30 TRUE",
  sep = "\n"
)

args <- commandArgs(trailingOnly = TRUE)

if (length(args) == 1L && args[[1L]] %in% c("--help", "-h")) {
  cat(.cancerppir_usage_text, "\n")
  quit(save = "no", status = 0L)
}

if (length(args) < 3L) {
  stop(.cancerppir_usage_text, call. = FALSE)
}

input_file <- args[[1]]
results_root <- args[[2]]
cache_dir <- args[[3]]
score_threshold <- if (length(args) >= 4) as.integer(args[[4]]) else 400L
top_n <- if (length(args) >= 5) as.integer(args[[5]]) else 30L

# Offline-only version. Argument 6 controls whether local enrichment tables are
# calculated. If a legacy value such as "offline" is passed here, enrichment is
# kept enabled to avoid accidental loss of annotation.
if (length(args) >= 6) {
  arg6 <- tolower(trimws(as.character(args[[6]])))
  run_enrichment <- if (arg6 %in% c("offline", "local", "local_only", "reproducible")) {
    TRUE
  } else {
    parse_bool(args[[6]])
  }
} else {
  run_enrichment <- TRUE
}

if (length(args) >= 7) {
  message("[CancerPPIr] Extra command-line arguments after run_enrichment are ignored in the offline-only version.")
}


invisible(
  run_cancerppir(
    input_file = input_file,
    results_root = results_root,
    cache_dir = cache_dir,
    score_threshold = score_threshold,
    top_n = top_n,
    run_enrichment = run_enrichment
  )
)
