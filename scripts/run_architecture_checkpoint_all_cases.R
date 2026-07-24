#!/usr/bin/env Rscript

# Run the current refactored CancerPPIr workflow for all seven reference cases.
#
# The script uses the active renv environment and executes cancerppir.R,
# not the preserved legacy implementation.
#
# Usage:
#   Rscript scripts/run_architecture_checkpoint_all_cases.R <output_root>
#
# Example:
#   Rscript scripts/run_architecture_checkpoint_all_cases.R \
#     ../results/phase2_string_mapping_full

arguments <- commandArgs(
  trailingOnly = TRUE
)

if (length(arguments) != 1L) {
  stop(
    paste0(
      "Expected one argument: output root.\n",
      "Example:\n",
      "Rscript scripts/run_architecture_checkpoint_all_cases.R ",
      "../results/phase2_string_mapping_full"
    ),
    call. = FALSE
  )
}

output_root_argument <- arguments[[1L]]

repo_root <- normalizePath(
  ".",
  winslash = "/",
  mustWork = TRUE
)

workflow_script <- file.path(
  repo_root,
  "cancerppir.R"
)

if (!file.exists(workflow_script)) {
  stop(
    "cancerppir.R was not found. Run this script from the repository root.",
    call. = FALSE
  )
}

if (!requireNamespace("renv", quietly = TRUE)) {
  stop(
    "Package 'renv' is not available.",
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
      "Unexpected active renv project:\n",
      active_project,
      "\nExpected:\n",
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
      paste(
        missing_packages,
        collapse = ", "
      )
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
  file.path(
    repo_root,
    "..",
    "input"
  ),
  winslash = "/",
  mustWork = TRUE
)

string_cache <- normalizePath(
  file.path(
    repo_root,
    "..",
    "string_cache"
  ),
  winslash = "/",
  mustWork = TRUE
)

missing_inputs <- file.path(
  input_root,
  case_table$input_file
)

missing_inputs <- missing_inputs[
  !file.exists(missing_inputs)
]

if (length(missing_inputs) > 0L) {
  stop(
    paste0(
      "Required input files are missing:\n",
      paste(
        paste0("- ", missing_inputs),
        collapse = "\n"
      )
    ),
    call. = FALSE
  )
}

if (dir.exists(output_root_argument)) {
  stop(
    paste0(
      "Output directory already exists:\n",
      output_root_argument,
      "\nDelete it or choose a new output directory."
    ),
    call. = FALSE
  )
}

dir.create(
  output_root_argument,
  recursive = TRUE,
  showWarnings = FALSE
)

output_root <- normalizePath(
  output_root_argument,
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
overall_exit_code <- 0L

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
    paste0(
      case_id,
      ".log"
    )
  )

  start_time <- Sys.time()

  message("")
  message(
    paste(
      rep("=", 60L),
      collapse = ""
    )
  )

  message(
    "[architecture run] Starting ",
    case_id
  )

  message(
    "[architecture run] Input: ",
    input_path
  )

  message(
    paste(
      rep("=", 60L),
      collapse = ""
    )
  )

  command_arguments <- c(
    workflow_script,
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

  log_lines <- if (file.exists(log_path)) {
    readLines(
      log_path,
      warn = FALSE,
      encoding = "UTF-8"
    )
  } else {
    character()
  }

  log_completed <- any(
    grepl(
      "[CancerPPIr] Done.",
      log_lines,
      fixed = TRUE
    )
  )

  log_has_error <- any(
    grepl(
      "error|execution halted|failed",
      log_lines,
      ignore.case = TRUE,
      perl = TRUE
    )
  )

  if (
    exit_code == 0L &&
      outputs_complete &&
      log_completed &&
      !log_has_error
  ) {
    run_status <- "completed"

    message(
      "[architecture run] ",
      case_id,
      ": completed successfully."
    )
  } else {
    run_status <- "failed"
    overall_exit_code <- 1L

    message(
      "[architecture run] ",
      case_id,
      ": failed."
    )

    message(
      "[architecture run] Exit code: ",
      exit_code
    )

    message(
      "[architecture run] Outputs complete: ",
      outputs_complete
    )

    message(
      "[architecture run] Completion marker: ",
      log_completed
    )

    message(
      "[architecture run] Error text detected: ",
      log_has_error
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
    log_completed = log_completed,
    log_has_error = log_has_error,
    status = run_status,
    stringsAsFactors = FALSE
  )

  utils::write.csv(
    do.call(
      rbind,
      status_rows
    ),
    file.path(
      output_root,
      "run_status.csv"
    ),
    row.names = FALSE,
    na = ""
  )
}

run_configuration <- c(
  paste0(
    "project=",
    repo_root
  ),
  paste0(
    "workflow_script=",
    workflow_script
  ),
  paste0(
    "workflow_md5=",
    unname(
      tools::md5sum(workflow_script)
    )
  ),
  paste0(
    "R=",
    R.version.string
  ),
  paste0(
    "renv=",
    as.character(
      packageVersion("renv")
    )
  ),
  paste0(
    "bioconductor=",
    renv::settings$bioconductor.version()
  ),
  paste0(
    "renv_lock_md5=",
    unname(
      tools::md5sum("renv.lock")
    )
  ),
  "score_threshold=400",
  "top_n=30",
  "run_enrichment=TRUE"
)

writeLines(
  run_configuration,
  file.path(
    output_root,
    "run_config.txt"
  ),
  useBytes = TRUE
)

message("")
message(
  paste(
    rep("=", 60L),
    collapse = ""
  )
)

message(
  "[architecture run] Full seven-case run finished."
)

message(
  "[architecture run] Status file: ",
  file.path(
    output_root,
    "run_status.csv"
  )
)

message(
  paste(
    rep("=", 60L),
    collapse = ""
  )
)

quit(
  save = "no",
  status = overall_exit_code
)