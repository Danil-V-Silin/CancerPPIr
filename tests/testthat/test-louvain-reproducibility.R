testthat::test_that(
  "deterministic Louvain ignores the caller's ambient seed",
  {
    graph <- igraph::make_ring(16L)
    graph <- igraph::add_edges(
      graph,
      c(
        1L, 5L,
        5L, 9L,
        9L, 13L,
        13L, 1L,
        3L, 11L,
        7L, 15L
      )
    )

    set.seed(11L)
    first_result <- run_louvain_deterministic(
      graph,
      weights = NA
    )

    set.seed(991L)
    second_result <- run_louvain_deterministic(
      graph,
      weights = NA
    )

    testthat::expect_identical(
      as.integer(igraph::membership(first_result)),
      as.integer(igraph::membership(second_result))
    )

    testthat::expect_equal(
      igraph::modularity(first_result),
      igraph::modularity(second_result),
      tolerance = 0
    )
  }
)

testthat::test_that(
  "deterministic Louvain preserves the caller's random-number state",
  {
    graph <- igraph::make_ring(12L)

    set.seed(2026L)
    expected_random_values <- stats::runif(5L)

    set.seed(2026L)

    invisible(
      run_louvain_deterministic(
        graph,
        weights = NA
      )
    )

    observed_random_values <- stats::runif(5L)

    testthat::expect_identical(
      observed_random_values,
      expected_random_values
    )
  }
)

testthat::test_that(
  "network analysis uses the deterministic Louvain wrapper",
  {
    network_body <- paste(
      deparse(
        body(run_network_analysis),
        width.cutoff = 500L
      ),
      collapse = "\n"
    )

    testthat::expect_true(
      grepl(
        "run_louvain_deterministic(ppi, weights = NA)",
        network_body,
        fixed = TRUE
      )
    )

    testthat::expect_false(
      grepl(
        "louvain <- igraph::cluster_louvain(ppi, weights = NA)",
        network_body,
        fixed = TRUE
      )
    )
  }
)

testthat::test_that(
  "the Louvain seed is explicit and stable",
  {
    testthat::expect_identical(
      CANCERPPIR_LOUVAIN_SEED,
      1729L
    )
  }
)
