testthat::test_that("quality runner exposes safe fast and full modes", {
  project_root <- Sys.getenv(
    "CANCERPPIR_PROJECT_ROOT",
    unset = "."
  )

  script_path <- file.path(
    project_root,
    "scripts",
    "run_quality_checks.R"
  )

  testthat::expect_true(file.exists(script_path))
  testthat::expect_silent(parse(file = script_path))

  run_cli <- function(arguments) {
    output <- suppressWarnings(
      system2(
        command = Sys.which("Rscript"),
        args = c(
          shQuote(script_path),
          arguments
        ),
        stdout = TRUE,
        stderr = TRUE
      )
    )

    status <- attr(output, "status")

    if (is.null(status)) {
      status <- 0L
    }

    list(status = as.integer(status), output = output)
  }

  help <- run_cli("--help")
  invalid <- run_cli("production")

  testthat::expect_identical(help$status, 0L)
  testthat::expect_true(
    any(grepl("[fast|full]", help$output, fixed = TRUE))
  )
  testthat::expect_true(
    any(grepl("Does not run production cases.", help$output, fixed = TRUE))
  )

  testthat::expect_true(invalid$status != 0L)
  testthat::expect_true(
    any(grepl("Mode must be one of: fast, full.", invalid$output, fixed = TRUE))
  )

  source_text <- paste(
    readLines(script_path, warn = FALSE, encoding = "UTF-8"),
    collapse = "\n"
  )

  testthat::expect_false(
    grepl("run_release_qualification.R", source_text, fixed = TRUE)
  )
  testthat::expect_false(
    grepl("run_smoke_test.R", source_text, fixed = TRUE)
  )
})
