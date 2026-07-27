project_root <- Sys.getenv(
  "CANCERPPIR_PROJECT_ROOT",
  unset = normalizePath(
    file.path("..", ".."),
    winslash = "/",
    mustWork = TRUE
  )
)

cli_script <- file.path(project_root, "cancerppir.R")
rscript <- Sys.which("Rscript")

run_cli <- function(arguments = character()) {
  output <- suppressWarnings(
    system2(
      command = rscript,
      args = c(
        shQuote(cli_script),
        vapply(arguments, shQuote, FUN.VALUE = character(1))
      ),
      stdout = TRUE,
      stderr = TRUE
    )
  )

  status <- attr(output, "status")
  if (is.null(status)) status <- 0L

  list(
    status = as.integer(status),
    output = output
  )
}

expect_cli_failure <- function(arguments, message) {
  result <- run_cli(arguments)

  testthat::expect_false(identical(result$status, 0L))
  testthat::expect_true(
    any(grepl(message, result$output, fixed = TRUE)),
    info = paste(result$output, collapse = "\n")
  )
}

testthat::test_that("CLI --help reports the public contract", {
  result <- run_cli("--help")

  testthat::expect_identical(result$status, 0L)
  testthat::expect_true(any(grepl("Rscript cancerppir.R", result$output, fixed = TRUE)))
  testthat::expect_true(any(grepl("integer, 1-1000", result$output, fixed = TRUE)))
  testthat::expect_true(any(grepl("CancerPPIr_Output_Manifest.json", result$output, fixed = TRUE)))
  testthat::expect_true(any(grepl("CancerPPIr_Output_Checksums.sha256", result$output, fixed = TRUE)))
})

testthat::test_that("CLI rejects missing and extra arguments", {
  expect_cli_failure(character(), "Usage:")
  expect_cli_failure(
    c("a", "b", "c", "400", "30", "TRUE", "extra"),
    "Too many arguments."
  )
})

testthat::test_that("CLI validates score_threshold strictly", {
  common <- c("missing.csv", tempdir(), tempdir())

  expect_cli_failure(c(common, "abc"), "score_threshold must be an integer from 1 to 1000.")
  expect_cli_failure(c(common, "400.5"), "score_threshold must be an integer from 1 to 1000.")
  expect_cli_failure(c(common, "0"), "score_threshold must be an integer from 1 to 1000.")
  expect_cli_failure(c(common, "1001"), "score_threshold must be an integer from 1 to 1000.")

  lower <- run_cli(c(common, "1", "30", "TRUE"))
  upper <- run_cli(c(common, "1000", "30", "TRUE"))

  testthat::expect_true(any(grepl("Input file not found:", lower$output, fixed = TRUE)))
  testthat::expect_true(any(grepl("Input file not found:", upper$output, fixed = TRUE)))
})

testthat::test_that("CLI validates top_n strictly", {
  common <- c("missing.csv", tempdir(), tempdir(), "400")

  expect_cli_failure(c(common, "0"), "top_n must be a positive integer.")
  expect_cli_failure(c(common, "-1"), "top_n must be a positive integer.")
  expect_cli_failure(c(common, "2.5"), "top_n must be a positive integer.")
  expect_cli_failure(c(common, "abc"), "top_n must be a positive integer.")
})

testthat::test_that("CLI validates run_enrichment strictly", {
  common <- c("missing.csv", tempdir(), tempdir(), "400", "30")

  expect_cli_failure(
    c(common, "offline"),
    "run_enrichment must be TRUE or FALSE."
  )

  result <- run_cli(c(common, "FALSE"))
  testthat::expect_true(
    any(grepl("Input file not found:", result$output, fixed = TRUE))
  )
})

testthat::test_that("CLI rejects a missing input file after valid parsing", {
  missing_input <- file.path(tempdir(), "cancerppir_missing_input.csv")

  result <- run_cli(
    c(
      missing_input,
      tempdir(),
      tempdir(),
      "400",
      "30",
      "TRUE"
    )
  )

  testthat::expect_false(identical(result$status, 0L))
  testthat::expect_true(
    any(grepl("Input file not found:", result$output, fixed = TRUE))
  )
})
