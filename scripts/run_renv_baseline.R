#!/usr/bin/env Rscript

# Run the preserved CancerPPIr implementation for all seven reference
# cases using the currently activated renv project environment.
#
# Usage:
#   Rscript scripts/run_renv_baseline.R
#
# Optional output root:
#   Rscript scripts/run_renv_baseline.R ../results/renv_phase1_full

arguments <- commandArgs(trailingOnly = TRUE)

output_root <- if (length(arguments) >= 1L) {
  arguments[[1]]
} else {
  "../results/renv_phase1_full"
}

repo_root <- normalizePath(
  getwd(),
  winslash = "/",
  mustWork = TRUE
)

legacy_script <- file.path(
  repo_root,
  "legacy",
  "cancerppir_legacy.R"
)

if (!file.exists(legacy_script)) {
  stop(
    "Run this script from the CancerPPIr repository root.",
    call. = FALSE
  )
}

if (!requireNamespace("renv", quietly = TRUE)) {
  stop(
    "The renv package is not available.",
    call. = FALSE
  )
}

active_project <- normalizePath(
  renv::project(),
  winslash = "/",
  mustWork = TRUE
)

if (!identical(active_project, repo_root)) {
  stop(
    paste0(
      "Unexpected active renv project: ",
      active_project,
      "\nExpected: ",
      repo_root
    ),
    call. = FALSE
  )
}

required_packages <- c(
  "HGNChelper",
  "STRINGdb",
  "igraph",
  "openxlsx",
  "dplyr",
  "tibble",
  "curl",
  "sna",
  "gprofiler2"
)

missing_packages <- required_packages[
  !vapply(
    required_packages,
    requireNamespace,
    quietly = TRUE,
    FUN.VALUE = logical(1)
  )
]

if (length(missing_packages) > 0L) {
  stop(
    paste0(
      "Packages missing from the active renv library: ",
      paste(missing_packages, collapse = ", ")
    ),
    call. = FALSE
  )
}

case_table <- data.frame(
  case_id = c(
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
  output_directory = c(
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

input_root <- normalizePath(
  file.path(repo_root, "..", "input"),
  winslash = "/",
  mustWork = TRUE
)

string_cache <- normalizePath(
  file.path(repo_root, "..", "string_cache"),
  winslash = "/",
  mustWork = TRUE
)

dir.create(
  output_root,
  recursive = TRUE,
  showWarnings = FALSE
)

output_root <- normalizePath(
  output_root,
  winslash = "/",
  mustWork = TRUE
)

log_root <- file.path(
  output_root,
  "logs"
)

dir.create(
  log_root,
  recursive = TRUE,
  showWarnings = FALSE
)

rscript_binary <- file.path(
  R.home("bin"),
  if (.Platform$OS.type == "windows") {
    "Rscript.exe"
  } else {
    "Rscript"
  }
)

expected_files <- c(
  "CancerPPIr_Analytical_Report.xlsx",
  "CancerPPIr_Technical_Report.xlsx",
  "Network_for_Cytoscape.graphml",
  "STRING_links.txt"
)

status_rows <- list()
overall_status <- 0L

for (case_index in seq_len(nrow(case_table))) {
  case_id <- case_table$case_id[[case_index]]

  input_path <- file.path(
    input_root,
    case_table$input_file[[case_index]]
  )

  output_directory <- file.path(
    output_root,
    case_table$output_directory[[case_index]]
  )

  log_path <- file.path(
    log_root,
    paste0(case_id, ".log")
  )

  if (!file.exists(input_path)) {
    stop(
      "Input file does not exist: ",
      input_path,
      call. = FALSE
    )
  }

  if (dir.exists(output_directory)) {
    unlink(
      output_directory,
      recursive = TRUE,
      force = TRUE
    )
  }

  start_time <- Sys.time()

  message("")
  message(
    paste(rep("=", 60L), collapse = "")
  )
  message("[renv baseline] Starting ", case_id)
  message("[renv baseline] Input: ", input_path)
  message(
    paste(rep("=", 60L), collapse = "")
  )

  command_arguments <- c(
    legacy_script,
    input_path,
    output_root,
    string_cache,
    "400",
    "30",
    "TRUE"
  )

  exit_code <- system2(
    command = rscript_binary,
    args = shQuote(command_arguments),
    stdout = log_path,
    stderr = log_path,
    wait = TRUE
  )

  end_time <- Sys.time()

  produced_files <- file.path(
    output_directory,
    expected_files
  )

  outputs_complete <- all(
    file.exists(produced_files)
  )

  if (exit_code == 0L && outputs_complete) {
    run_status <- "completed"
    message(
      "[renv baseline] ",
      case_id,
      ": completed successfully."
    )
  } else if (exit_code == 0L) {
    run_status <- "missing_outputs"
    overall_status <- 1L
    message(
      "[renv baseline] ",
      case_id,
      ": process finished, but expected outputs are missing."
    )
  } else {
    run_status <- "failed"
    overall_status <- 1L
    message(
      "[renv baseline] ",
      case_id,
      ": failed with exit code ",
      exit_code,
      "."
    )
  }

  status_rows[[case_index]] <- data.frame(
    case_id = case_id,
    input_file = input_path,
    output_directory = output_directory,
    start_time = format(
      start_time,
      "%Y-%m-%dT%H:%M:%S%z"
    ),
    end_time = format(
      end_time,
      "%Y-%m-%dT%H:%M:%S%z"
    ),
    elapsed_seconds = as.numeric(
      difftime(
        end_time,
        start_time,
        units = "secs"
      )
    ),
    exit_code = exit_code,
    outputs_complete = outputs_complete,
    status = run_status,
    stringsAsFactors = FALSE
  )

  utils::write.csv(
    do.call(rbind, status_rows),
    file.path(output_root, "run_status.csv"),
    row.names = FALSE,
    na = ""
  )
}

config_lines <- c(
  paste0("project=", repo_root),
  paste0("R=", R.version.string),
  paste0(
    "renv=",
    as.character(packageVersion("renv"))
  ),
  paste0(
    "bioconductor=",
    renv::settings$bioconductor.version()
  ),
  paste0(
    "renv_lock_md5=",
    unname(tools::md5sum("renv.lock"))
  ),
  "score_threshold=400",
  "top_n=30",
  "run_enrichment=TRUE"
)

writeLines(
  config_lines,
  file.path(output_root, "run_config.txt"),
  useBytes = TRUE
)

message("")
message(
  paste(rep("=", 60L), collapse = "")
)
message("[renv baseline] Full seven-case run finished.")
message(
  "[renv baseline] Status file: ",
  file.path(output_root, "run_status.csv")
)
message(
  paste(rep("=", 60L), collapse = "")
)

quit(
  save = "no",
  status = overall_status
)