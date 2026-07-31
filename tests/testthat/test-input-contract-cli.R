project_root <- Sys.getenv(
  "CANCERPPIR_PROJECT_ROOT",
  unset = normalizePath(
    file.path("..", ".."),
    winslash = "/",
    mustWork = TRUE
  )
)

testthat::test_that("input-contract CLI resolves the repository root", {
  input_file <- tempfile(fileext = ".csv")
  on.exit(unlink(input_file), add = TRUE)

  writeLines(
    c(
      "gene,logFC,pvalue",
      "TP53,1.5,0.01",
      "EGFR,-2.0,0.02"
    ),
    input_file
  )

  rscript <- file.path(
    R.home("bin"),
    if (.Platform$OS.type == "windows") "Rscript.exe" else "Rscript"
  )

  output <- suppressWarnings(
    system2(
      command = rscript,
      args = c(
        shQuote(
          file.path(
            project_root,
            "scripts",
            "validate_input_contract.R"
          )
        ),
        shQuote(input_file)
      ),
      stdout = TRUE,
      stderr = TRUE
    )
  )

  status <- attr(output, "status")
  if (is.null(status)) status <- 0L

  testthat::expect_identical(
    as.integer(status),
    0L,
    info = paste(output, collapse = "\n")
  )
  testthat::expect_true(
    any(
      grepl(
        "CANCERPPIR INPUT CONTRACT: PASSED",
        output,
        fixed = TRUE
      )
    ),
    info = paste(output, collapse = "\n")
  )
})
