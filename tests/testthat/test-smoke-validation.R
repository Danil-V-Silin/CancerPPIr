testthat::test_that(
  "supported smoke command uses a synthetic current-contract workflow",
  {
    project_root <- Sys.getenv("CANCERPPIR_PROJECT_ROOT")
    script <- file.path(project_root, "scripts", "run_smoke_test.R")
    output <- suppressWarnings(
      system2(
        command = Sys.which("Rscript"),
        args = c(shQuote(script), "--help"),
        stdout = TRUE,
        stderr = TRUE
      )
    )
    status <- attr(output, "status")

    if (is.null(status)) status <- 0L

    testthat::expect_identical(as.integer(status), 0L)
    testthat::expect_true(
      any(grepl("STRING_CACHE OUTPUT_ROOT", output, fixed = TRUE))
    )
    testthat::expect_true(
      any(grepl("never runs clinical cases", output, fixed = TRUE))
    )

    source_text <- paste(
      readLines(script, warn = FALSE, encoding = "UTF-8"),
      collapse = "\n"
    )

    testthat::expect_true(
      grepl(
        "cancerppir_log_has_completion_marker(log_lines)",
        source_text,
        fixed = TRUE
      )
    )
    testthat::expect_false(
      grepl("compare_reference_case.R", source_text, fixed = TRUE)
    )
    testthat::expect_false(
      grepl("Genes_R.csv", source_text, fixed = TRUE)
    )
  }
)

testthat::test_that(
  "historical reference comparison accepts current timed completion logs",
  {
    project_root <- Sys.getenv("CANCERPPIR_PROJECT_ROOT")
    script <- file.path(
      project_root,
      "tools",
      "development",
      "reproducibility",
      "compare_reference_case.R"
    )
    expressions <- parse(script, keep.source = FALSE)
    matches <- vapply(
      expressions,
      function(expression) {
        is.call(expression) &&
          identical(as.character(expression[[1L]]), "<-") &&
          identical(as.character(expression[[2L]]), "log_completed")
      },
      logical(1)
    )

    testthat::expect_equal(sum(matches), 1L)

    isolated <- new.env(parent = baseenv())
    eval(expressions[[which(matches)]], envir = isolated)

    log_path <- tempfile(fileext = ".log")
    on.exit(unlink(log_path), add = TRUE)

    writeLines("[CancerPPIr] [+00:00:03] Done.", log_path)
    testthat::expect_true(isolated$log_completed(log_path))

    writeLines("[CancerPPIr] Done.", log_path)
    testthat::expect_true(isolated$log_completed(log_path))

    writeLines("[CancerPPIr] [+00:00:03] Not done.", log_path)
    testthat::expect_false(isolated$log_completed(log_path))
  }
)
