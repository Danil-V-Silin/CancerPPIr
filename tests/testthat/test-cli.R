project_root <- Sys.getenv(
  "CANCERPPIR_PROJECT_ROOT",
  unset = normalizePath(
    file.path("..", ".."),
    winslash = "/",
    mustWork = TRUE
  )
)

cli_script <- file.path(
  project_root,
  "cancerppir.R"
)

rscript <- Sys.which(
  "Rscript"
)

run_cli <- function(arguments = character()) {
  output <- suppressWarnings(
    system2(
      command = rscript,
      args = c(
        shQuote(cli_script),
        vapply(
          arguments,
          shQuote,
          FUN.VALUE = character(1)
        )
      ),
      stdout = TRUE,
      stderr = TRUE
    )
  )

  status <- attr(
    output,
    "status"
  )

  if (is.null(status)) {
    status <- 0L
  }

  list(
    status = as.integer(status),
    output = output
  )
}

testthat::test_that("CLI prints usage and fails when required arguments are absent", {
  result <- run_cli()

  testthat::expect_false(
    identical(result$status, 0L)
  )

  testthat::expect_true(
    any(grepl(
      "Usage:",
      result$output,
      fixed = TRUE
    ))
  )
})

testthat::test_that("CLI rejects a missing input file before analysis", {
  missing_input <- file.path(
    tempdir(),
    "cancerppir_missing_input.csv"
  )

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

  testthat::expect_false(
    identical(result$status, 0L)
  )

  testthat::expect_true(
    any(grepl(
      "Input file not found:",
      result$output,
      fixed = TRUE
    ))
  )
})

testthat::test_that("CLI rejects a non-positive score threshold", {
  input_file <- tempfile(
    fileext = ".csv"
  )

  writeLines(
    c(
      "gene,logFC,pvalue",
      "TP53,1.5,0.01"
    ),
    input_file
  )

  result <- run_cli(
    c(
      input_file,
      tempdir(),
      tempdir(),
      "0",
      "30",
      "TRUE"
    )
  )

  testthat::expect_false(
    identical(result$status, 0L)
  )

  testthat::expect_true(
    any(grepl(
      "score_threshold must be a positive integer.",
      result$output,
      fixed = TRUE
    ))
  )

  unlink(input_file)
})
