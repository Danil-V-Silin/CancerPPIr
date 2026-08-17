#!/usr/bin/env Rscript

arguments <- commandArgs(trailingOnly = TRUE)

usage <- paste(
  "CancerPPIr quality checks",
  "",
  "Usage:",
  "  Rscript scripts/run_quality_checks.R [fast|full]",
  "  Rscript scripts/run_quality_checks.R --help",
  "",
  "Modes:",
  "  fast  Static, reproducibility, publication and CLI checks.",
  "        Does not run unit tests or production cases.",
  "  full  Fast checks plus the complete unit-test suite.",
  "        Does not run production cases.",
  "",
  "Default mode: fast",
  sep = "\n"
)

if (length(arguments) == 1L && arguments[[1L]] %in% c("--help", "-h")) {
  cat(usage, "\n")
  quit(save = "no", status = 0L)
}

if (length(arguments) > 1L) {
  stop(usage, call. = FALSE)
}

mode <- if (length(arguments)) arguments[[1L]] else "fast"

if (!mode %in% c("fast", "full")) {
  stop(
    "Mode must be one of: fast, full.\n\n",
    usage,
    call. = FALSE
  )
}

file_argument <- grep(
  "^--file=",
  commandArgs(trailingOnly = FALSE),
  value = TRUE
)

project_root <- if (length(file_argument)) {
  normalizePath(
    file.path(
      dirname(sub("^--file=", "", file_argument[[1L]])),
      ".."
    ),
    winslash = "/",
    mustWork = TRUE
  )
} else {
  normalizePath(".", winslash = "/", mustWork = TRUE)
}

setwd(project_root)

rscript <- Sys.which("Rscript")

if (!nzchar(rscript)) {
  stop("Rscript executable was not found.", call. = FALSE)
}

run_check <- function(label, command_arguments) {
  message("[CancerPPIr quality] START: ", label)
  started_at <- Sys.time()

  status <- system2(
    command = rscript,
    args = command_arguments
  )

  if (is.null(status)) {
    status <- 0L
  }

  if (!identical(as.integer(status), 0L)) {
    stop(
      label,
      " failed with exit status ",
      status,
      ".",
      call. = FALSE
    )
  }

  elapsed <- round(
    as.numeric(
      difftime(Sys.time(), started_at, units = "secs")
    ),
    digits = 1L
  )

  message(
    "[CancerPPIr quality] PASS: ",
    label,
    " (",
    elapsed,
    " s)."
  )

  invisible(TRUE)
}

checks <- list(
  list(
    label = "Repository quality",
    arguments = "scripts/validate_repository_quality.R"
  ),
  list(
    label = "Reproducibility contract",
    arguments = "scripts/validate_reproducibility_contract.R"
  )
)

if (identical(mode, "full")) {
  checks <- append(
    checks,
    list(
      list(
        label = "Complete unit-test suite",
        arguments = "scripts/run_unit_tests.R"
      )
    ),
    after = 2L
  )
}

checks <- c(
  checks,
  list(
    list(
      label = "Publication readiness",
      arguments = "scripts/validate_publication_readiness.R"
    ),
    list(
      label = "CLI help",
      arguments = c("cancerppir.R", "--help")
    ),
    list(
      label = "CLI version",
      arguments = c("cancerppir.R", "--version")
    )
  )
)

for (check in checks) {
  run_check(
    label = check$label,
    command_arguments = check$arguments
  )
}

cat(
  "\nCANCERPPIR ",
  toupper(mode),
  " QUALITY CHECKS: PASSED\n",
  sep = ""
)
