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
# Patient-specific PPI subnetwork analysis from tumor bulk RNA-seq profiles.
#
# Usage:
#   Rscript CancerPPIr_final_v8_offline.R input.csv results_dir string_cache [score_threshold] [top_n] [run_enrichment]
#
# Output policy:
#   The second argument is a results root directory. CancerPPIr automatically
#   creates/reuses a patient-specific subfolder named exactly like the input file
#   without extension. Example: input/Genes_R.csv -> results/Genes_R/.
#
# Enrichment policy:
#   Offline-only, reproducible mode. Functional annotation uses locally cached
#   STRING v12 enrichment terms plus curated marker-gene overlap. Online
#   g:Profiler/STRING validation is intentionally disabled in this version.
#
# Example:
#   Rscript CancerPPIr_final_v8_offline.R input/Genes_R.csv results string_cache 400 30 TRUE





args <- commandArgs(trailingOnly = TRUE)

if (length(args) < 3) {
  stop(
    paste(
      "Usage:",
      "Rscript CancerPPIr_final_v8_offline.R input.csv results_dir string_cache [score_threshold] [top_n] [run_enrichment]",
      "",
      "Output folder is derived automatically:",
      "  input/Genes_R.csv + results_dir=results -> results/Genes_R/",
      sep = "\n"
    ),
    call. = FALSE
  )
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
