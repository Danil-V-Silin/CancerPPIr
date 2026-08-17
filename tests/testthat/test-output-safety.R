testthat::test_that(
  "Excel output writers refuse to overwrite existing files",
  {
    output_dir <- tempfile(
      pattern = "cancerppir_writer_safety_"
    )

    dir.create(output_dir, recursive = TRUE)
    on.exit(
      unlink(output_dir, recursive = TRUE, force = TRUE),
      add = TRUE
    )

    path <- file.path(output_dir, "report.xlsx")
    sheets <- list(
      Result = data.frame(
        value = "original",
        stringsAsFactors = FALSE
      )
    )

    write_readable_xlsx(path, sheets)

    original_sha <- digest::digest(
      path,
      algo = "sha256",
      file = TRUE,
      serialize = FALSE
    )

    testthat::expect_error(
      write_readable_xlsx(path, sheets),
      regexp = "Refusing to overwrite"
    )

    testthat::expect_identical(
      digest::digest(
        path,
        algo = "sha256",
        file = TRUE,
        serialize = FALSE
      ),
      original_sha
    )
  }
)

testthat::test_that(
  "completed outputs are staged and atomically published",
  {
    output_parent <- tempfile(
      pattern = "cancerppir_staging_safety_"
    )

    dir.create(output_parent, recursive = TRUE)
    on.exit(
      unlink(output_parent, recursive = TRUE, force = TRUE),
      add = TRUE
    )

    final_output_dir <- file.path(
      output_parent,
      "sample_A01"
    )

    paths <- cancerppir_prepare_output_staging(
      final_output_dir
    )

    testthat::expect_true(
      dir.exists(paths$staging_output_dir)
    )
    testthat::expect_false(dir.exists(final_output_dir))

    writeLines(
      "completed output",
      file.path(paths$staging_output_dir, "result.txt")
    )

    cancerppir_publish_output_staging(
      staging_output_dir = paths$staging_output_dir,
      final_output_dir = final_output_dir
    )

    testthat::expect_false(
      dir.exists(paths$staging_output_dir)
    )
    testthat::expect_true(
      file.exists(
        file.path(final_output_dir, "result.txt")
      )
    )

    testthat::expect_error(
      cancerppir_prepare_output_staging(
        final_output_dir
      ),
      regexp = "already exists"
    )

    testthat::expect_identical(
      readLines(
        file.path(final_output_dir, "result.txt"),
        warn = FALSE
      ),
      "completed output"
    )

    competing_output_dir <- file.path(
      output_parent,
      "sample_race"
    )

    competing_paths <- cancerppir_prepare_output_staging(
      competing_output_dir
    )

    dir.create(competing_output_dir)
    writeLines(
      "do not delete",
      file.path(competing_output_dir, "foreign.txt")
    )

    testthat::expect_error(
      cancerppir_publish_output_staging(
        staging_output_dir =
          competing_paths$staging_output_dir,
        final_output_dir = competing_output_dir
      ),
      regexp = "appeared before publication"
    )

    testthat::expect_identical(
      readLines(
        file.path(competing_output_dir, "foreign.txt"),
        warn = FALSE
      ),
      "do not delete"
    )

    testthat::expect_true(
      dir.exists(competing_paths$staging_output_dir)
    )
  }
)
