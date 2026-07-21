testthat::test_that("boolean and enrichment-mode parsing is stable", {
  testthat::expect_identical(
    parse_bool(c("1", "TRUE", "yes", "no", "0")),
    c(TRUE, TRUE, TRUE, FALSE, FALSE)
  )

  testthat::expect_identical(
    is_bool_like(c("true", "FALSE", "y", "n", "other")),
    c(TRUE, TRUE, TRUE, TRUE, FALSE)
  )

  testthat::expect_identical(normalize_enrichment_mode("local"), "offline")
  testthat::expect_identical(normalize_enrichment_mode("validation"), "online_validation")
  testthat::expect_error(
    normalize_enrichment_mode("unsupported"),
    "Invalid enrichment_mode"
  )
})

testthat::test_that("shared normalization and numeric helpers are deterministic", {
  testthat::expect_identical(
    normalize_path_for_compare("C:\\data\\Genes_R.csv"),
    "C:/data/Genes_R.csv"
  )

  testthat::expect_equal(
    as_number(c("1,5", "-2.0", "bad")),
    c(1.5, -2, NA_real_)
  )

  testthat::expect_identical(
    clean_names(c(" Gene Symbol ", "log2-FC", "P.Value")),
    c("genesymbol", "log2fc", "pvalue")
  )

  testthat::expect_equal(
    minmax(c(5, 10, 15, NA_real_)),
    c(0, 0.5, 1, NA_real_)
  )

  testthat::expect_equal(
    minmax(c(2, 2, NA_real_)),
    c(1, 1, NA_real_)
  )

  testthat::expect_true(
    all(is.na(minmax(c(NA_real_, Inf))))
  )
})

testthat::test_that("ranking and text helpers retain legacy behavior", {
  testthat::expect_identical(
    top_genes(c("B", "A", "A", "C"), c(1, 4, 3, 2), n = 3L),
    "A;C"
  )

  truncated <- truncate_text(
    "abcdefghijklmnopqrstuvwxyz",
    max_chars = 10L
  )

  testthat::expect_identical(truncated, "abcdefg...")
  testthat::expect_identical(NULL %||% "fallback", "fallback")
  testthat::expect_identical("value" %||% "fallback", "value")
})
