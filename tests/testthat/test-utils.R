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

testthat::test_that("case IDs are safe, explicit and path-free", {
  testthat::expect_identical(
    cancerppir_validate_case_id("A01_case-2.1"),
    "A01_case-2.1"
  )

  invalid_ids <- c(
    "",
    ".hidden",
    "Patient Ivanov",
    "../A01",
    "A01/second",
    "A01.",
    "CON",
    "LPT1.txt",
    paste(rep("A", 65L), collapse = "")
  )

  for (case_id in invalid_ids) {
    testthat::expect_error(
      cancerppir_validate_case_id(case_id),
      regexp = "case_id must contain 1-64 ASCII characters"
    )
  }

  explicit <- cancerppir_resolve_case_id(
    input_file = "Patient_Ivanov.csv",
    case_id = "A01"
  )

  testthat::expect_identical(
    explicit,
    list(
      value = "A01",
      source = "explicit_case_id"
    )
  )

  legacy <- cancerppir_resolve_case_id(
    input_file = "Genes_A.csv"
  )

  testthat::expect_identical(
    legacy,
    list(
      value = "Genes_A",
      source = "legacy_input_basename"
    )
  )

  testthat::expect_identical(
    cancerppir_resolve_output_directory(
      results_root = "results",
      case_id = "A01"
    ),
    file.path("results", "A01")
  )

  testthat::expect_identical(
    cancerppir_resolve_output_directory(
      results_root = file.path(
        "results",
        "Genes_A_variant"
      ),
      case_id = "Genes_A",
      preserve_legacy_variant_redirect = TRUE
    ),
    file.path("results", "Genes_A")
  )
})

testthat::test_that("progress messages include elapsed time", {
  old_option <- getOption(
    "cancerppir.progress_started_at",
    default = NULL
  )

  on.exit(
    options(
      cancerppir.progress_started_at = old_option
    ),
    add = TRUE
  )

  options(
    cancerppir.progress_started_at = Sys.time() - 65
  )

  testthat::expect_message(
    msg("Stage 1/8: fixture."),
    regexp = paste0(
      "^\\[CancerPPIr\\] ",
      "\\[\\+00:01:[0-9]{2}\\] ",
      "Stage 1/8: fixture\\.\n?$"
    )
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

testthat::test_that("ranking and text helpers retain qualified behavior", {
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

testthat::test_that("candidate score requires five complete finite components", {
  degree <- c(1, 2, 4)
  betweenness <- c(0.1, 0.2, 0.5)
  stress <- c(0, 3, 8)
  abs_logFC <- c(0.5, 1.0, 2.0)
  neg_log10_pvalue <- c(1, 2, 4)

  topology_component <- rowMeans(
    cbind(
      minmax(degree),
      minmax(betweenness),
      minmax(log1p(stress))
    )
  )

  expected <- rowMeans(
    cbind(
      topology_component,
      minmax(abs_logFC),
      minmax(neg_log10_pvalue)
    )
  )

  testthat::expect_equal(
    calculate_candidate_score(
      degree = degree,
      betweenness = betweenness,
      stress_centrality = stress,
      abs_logFC = abs_logFC,
      neg_log10_pvalue = neg_log10_pvalue
    ),
    expected
  )

  testthat::expect_error(
    calculate_candidate_score(
      degree = degree,
      betweenness = betweenness,
      stress_centrality = c(0, NA_real_, 8),
      abs_logFC = abs_logFC,
      neg_log10_pvalue = neg_log10_pvalue
    ),
    "requires all five finite components.*2"
  )

  testthat::expect_error(
    calculate_candidate_score(
      degree = degree,
      betweenness = betweenness[-1],
      stress_centrality = stress,
      abs_logFC = abs_logFC,
      neg_log10_pvalue = neg_log10_pvalue
    ),
    "identical lengths"
  )
})
