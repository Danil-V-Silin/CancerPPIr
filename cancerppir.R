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
  paste(
    "  Rscript cancerppir.R input.csv results_dir string_cache",
    "[score_threshold] [top_n] [run_enrichment] [--case-id ID]"
  ),
  "  Rscript cancerppir.R --help",
  "  Rscript cancerppir.R --version",
  "",
  "Defaults:",
  "  score_threshold = 400 (integer, 1-1000)",
  "  top_n = 30 (positive integer)",
  "  run_enrichment = TRUE or FALSE (offline local STRING enrichment)",
  "  case_id = optional pseudonymous ID (1-64 safe ASCII characters)",
  "",
  "Output folder:",
  "  case_id=DEMO01 + results_dir=results -> results/DEMO01/",
  "  Existing output folders are never overwritten.",
  "  If case_id is omitted, the legacy input-basename behavior is used.",
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
  paste(
    "  Rscript cancerppir.R examples/minimal_input.csv results string_cache",
    "400 30 TRUE --case-id DEMO01"
  ),
  sep = "\n"
)

args <- commandArgs(trailingOnly = TRUE)

if (length(args) == 1L && args[[1L]] %in% c("--help", "-h")) {
  cat(.cancerppir_usage_text, "\n")
  quit(save = "no", status = 0L)
}

if (length(args) == 1L && args[[1L]] %in% c("--version", "-V")) {
  project_root <- getOption(
    "cancerppir.project_root",
    default = "."
  )
  version_file <- file.path(project_root, "VERSION")

  version <- if (file.exists(version_file)) {
    trimws(
      readLines(
        version_file,
        n = 1L,
        warn = FALSE,
        encoding = "UTF-8"
      )
    )
  } else {
    "unknown"
  }

  cat("CancerPPIr ", version, "\n", sep = "")
  quit(save = "no", status = 0L)
}

.cancerppir_extract_case_id <- function(arguments) {
  equals_indices <- grep(
    "^--case-id=",
    arguments
  )
  separate_indices <- which(
    arguments == "--case-id"
  )

  if (length(c(equals_indices, separate_indices)) > 1L) {
    stop("--case-id may be supplied only once.", call. = FALSE)
  }

  if (!length(c(equals_indices, separate_indices))) {
    return(
      list(
        arguments = arguments,
        case_id = NULL
      )
    )
  }

  if (length(equals_indices) == 1L) {
    index <- equals_indices[[1L]]
    case_id <- sub(
      "^--case-id=",
      "",
      arguments[[index]]
    )
    arguments <- arguments[-index]
  } else {
    index <- separate_indices[[1L]]

    if (index == length(arguments)) {
      stop("--case-id requires a value.", call. = FALSE)
    }

    case_id <- arguments[[index + 1L]]
    arguments <- arguments[-c(index, index + 1L)]
  }

  list(
    arguments = arguments,
    case_id = cancerppir_validate_case_id(case_id)
  )
}

case_id_option <- .cancerppir_extract_case_id(args)
args <- case_id_option$arguments
case_id <- case_id_option$case_id

if (length(args) < 3L) {
  stop(.cancerppir_usage_text, call. = FALSE)
}

if (length(args) > 6L) {
  stop(
    paste(
      "Too many arguments. Expected at most 6 positional arguments.",
      .cancerppir_usage_text,
      sep = "\n\n"
    ),
    call. = FALSE
  )
}

parse_integer_argument <- function(
  value,
  argument_name,
  minimum,
  maximum = Inf,
  error_message
) {
  value <- trimws(as.character(value))

  if (!grepl("^[0-9]+$", value)) {
    stop(error_message, call. = FALSE)
  }

  numeric_value <- suppressWarnings(as.numeric(value))

  if (
    length(numeric_value) != 1L ||
      is.na(numeric_value) ||
      !is.finite(numeric_value) ||
      numeric_value != floor(numeric_value) ||
      numeric_value < minimum ||
      numeric_value > maximum ||
      numeric_value > .Machine$integer.max
  ) {
    stop(error_message, call. = FALSE)
  }

  as.integer(numeric_value)
}

parse_cli_boolean <- function(value) {
  normalized <- toupper(trimws(as.character(value)))

  if (identical(normalized, "TRUE")) return(TRUE)
  if (identical(normalized, "FALSE")) return(FALSE)

  stop("run_enrichment must be TRUE or FALSE.", call. = FALSE)
}

input_file <- args[[1L]]
results_root <- args[[2L]]
cache_dir <- args[[3L]]

score_threshold <- if (length(args) >= 4L) {
  parse_integer_argument(
    args[[4L]],
    argument_name = "score_threshold",
    minimum = 1,
    maximum = 1000,
    error_message = "score_threshold must be an integer from 1 to 1000."
  )
} else {
  400L
}

top_n <- if (length(args) >= 5L) {
  parse_integer_argument(
    args[[5L]],
    argument_name = "top_n",
    minimum = 1,
    error_message = "top_n must be a positive integer."
  )
} else {
  30L
}

run_enrichment <- if (length(args) >= 6L) {
  parse_cli_boolean(args[[6L]])
} else {
  TRUE
}

invisible(
  run_cancerppir(
    input_file = input_file,
    results_root = results_root,
    cache_dir = cache_dir,
    score_threshold = score_threshold,
    top_n = top_n,
    run_enrichment = run_enrichment,
    case_id = case_id
  )
)
