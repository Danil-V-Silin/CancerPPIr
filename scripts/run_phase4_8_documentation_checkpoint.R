#!/usr/bin/env Rscript

# One Phase 4.8 checkpoint: complete unit suite once, static documentation
# contract, and one CLI --help smoke test. No STRING initialization and no
# clinical-case network reconstruction are performed.

project_root <- normalizePath(".", winslash = "/", mustWork = TRUE)
output_root <- if (length(commandArgs(trailingOnly = TRUE)) >= 1L) {
  commandArgs(trailingOnly = TRUE)[[1L]]
} else {
  file.path("..", "results", "phase4_8_documentation_checkpoint_v1")
}

dir.create(output_root, recursive = TRUE, showWarnings = FALSE)
output_root <- normalizePath(output_root, winslash = "/", mustWork = TRUE)

rscript <- file.path(R.home("bin"), if (.Platform$OS.type == "windows") "Rscript.exe" else "Rscript")
unit_log <- file.path(output_root, "phase4_8_unit_tests.log")

message("[Phase 4.8 checkpoint] Running unit tests once.")
unit_status <- system2(
  rscript,
  shQuote(file.path(project_root, "scripts", "run_unit_tests.R")),
  stdout = unit_log,
  stderr = unit_log,
  wait = TRUE
)
if (is.null(unit_status) || is.na(unit_status) || unit_status != 0L) {
  log_lines <- if (file.exists(unit_log)) readLines(unit_log, warn = FALSE, encoding = "UTF-8") else "Log unavailable."
  stop(
    paste0(
      "Unit tests failed with exit status ", unit_status, ".\n\nLog tail:\n",
      paste(tail(log_lines, 100L), collapse = "\n")
    ),
    call. = FALSE
  )
}
message("[Phase 4.8 checkpoint] Unit tests: PASS.")

source(file.path(project_root, "scripts", "validate_phase4_8_documentation.R"), local = TRUE)
checks <- phase4_8_validate_documentation(project_root)

cli_output <- suppressWarnings(system2(
  rscript,
  c(shQuote(file.path(project_root, "cancerppir.R")), "--help"),
  stdout = TRUE,
  stderr = TRUE
))
cli_status <- attr(cli_output, "status")
if (is.null(cli_status)) cli_status <- 0L

cli_check <- data.frame(
  check_id = "cli_help_smoke_test",
  status = if (
    identical(as.integer(cli_status), 0L) &&
      any(grepl("Usage:", cli_output, fixed = TRUE)) &&
      any(grepl("CancerPPIr_Output_Manifest.json", cli_output, fixed = TRUE))
  ) "PASS" else "FAIL",
  details = paste(cli_output, collapse = " | "),
  stringsAsFactors = FALSE
)

checks <- rbind(checks, cli_check)
rownames(checks) <- NULL

summary <- data.frame(
  metric = c(
    "unit_tests",
    "documentation_checks",
    "failed_checks",
    "network_runs"
  ),
  value = c(
    "PASS",
    as.character(nrow(checks)),
    as.character(sum(checks$status == "FAIL")),
    "0"
  ),
  stringsAsFactors = FALSE
)

summary_file <- file.path(output_root, "phase4_8_checkpoint_summary.csv")
validation_file <- file.path(output_root, "phase4_8_checkpoint_validation.csv")
utils::write.csv(summary, summary_file, row.names = FALSE, na = "")
utils::write.csv(checks, validation_file, row.names = FALSE, na = "")

cat("\nPHASE 4.8 DOCUMENTATION CHECKPOINT\n\n")
print(summary, row.names = FALSE)

failures <- checks[checks$status == "FAIL", , drop = FALSE]
if (nrow(failures)) {
  cat("\nFailed checks:\n")
  print(failures, row.names = FALSE)
}

cat(
  "\nOutput files:\n",
  "- ", summary_file, "\n",
  "- ", validation_file, "\n",
  "- ", unit_log, "\n",
  sep = ""
)

if (nrow(failures)) {
  cat("\nPHASE 4.8 DOCUMENTATION CHECKPOINT: FAILED\n")
  quit(save = "no", status = 1L)
}

cat("\nPHASE 4.8 DOCUMENTATION CHECKPOINT: PASSED\n")
