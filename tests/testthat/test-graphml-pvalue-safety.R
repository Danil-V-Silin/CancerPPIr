testthat::test_that(
  "the GraphML p-value floor stays safely inside the normal range",
  {
    testthat::expect_identical(
      CANCERPPIR_GRAPHML_PVALUE_FLOOR,
      1e-300
    )

    testthat::expect_gt(
      CANCERPPIR_GRAPHML_PVALUE_FLOOR,
      .Machine$double.xmin
    )
  }
)

testthat::test_that(
  "GraphML p-value export floors zero and subnormal values",
  {
    result <- prepare_graphml_pvalue_export(
      c(
        0,
        1e-320,
        CANCERPPIR_GRAPHML_PVALUE_FLOOR,
        0.05,
        NA_real_
      )
    )

    testthat::expect_identical(
      result$floor_applied,
      c(TRUE, TRUE, FALSE, FALSE, FALSE)
    )

    testthat::expect_identical(
      result$value[1:2],
      rep(CANCERPPIR_GRAPHML_PVALUE_FLOOR, 2L)
    )

    testthat::expect_identical(
      result$value[[3L]],
      CANCERPPIR_GRAPHML_PVALUE_FLOOR
    )

    testthat::expect_identical(
      result$value[[4L]],
      0.05
    )

    testthat::expect_true(
      is.na(result$value[[5L]])
    )
  }
)

testthat::test_that(
  "GraphML p-value export rejects invalid values",
  {
    testthat::expect_error(
      prepare_graphml_pvalue_export(-0.1),
      "between 0 and 1",
      fixed = TRUE
    )

    testthat::expect_error(
      prepare_graphml_pvalue_export(1.1),
      "between 0 and 1",
      fixed = TRUE
    )

    testthat::expect_error(
      prepare_graphml_pvalue_export(Inf),
      "between 0 and 1",
      fixed = TRUE
    )

    testthat::expect_error(
      prepare_graphml_pvalue_export("not-a-number"),
      "non-numeric",
      fixed = TRUE
    )
  }
)

testthat::test_that(
  "sanitized p-values survive an igraph GraphML round trip",
  {
    graph <- igraph::make_ring(4L)

    result <- prepare_graphml_pvalue_export(
      c(
        0,
        1e-320,
        CANCERPPIR_GRAPHML_PVALUE_FLOOR,
        0.05
      )
    )

    graph <- igraph::set_vertex_attr(
      graph,
      "pvalue",
      value = result$value
    )

    graph <- igraph::set_vertex_attr(
      graph,
      "pvalue_was_floored_for_graphml",
      value = result$floor_applied
    )

    graphml_file <- tempfile(
      fileext = ".graphml"
    )

    on.exit(
      unlink(graphml_file),
      add = TRUE
    )

    igraph::write_graph(
      graph,
      graphml_file,
      format = "graphml"
    )

    imported <- igraph::read_graph(
      graphml_file,
      format = "graphml"
    )

    testthat::expect_equal(
      as.integer(igraph::vcount(imported)),
      4L
    )

    imported_pvalues <- igraph::vertex_attr(
      imported,
      "pvalue"
    )

    testthat::expect_true(
      all(
        is.na(imported_pvalues) |
          imported_pvalues >= CANCERPPIR_GRAPHML_PVALUE_FLOOR
      )
    )
  }
)

testthat::test_that(
  "the canonical GraphML path uses the sanitized p-value export",
  {
    project_root <- Sys.getenv(
      "CANCERPPIR_PROJECT_ROOT",
      unset = ""
    )

    testthat::expect_true(nzchar(project_root))

    graphml_source <- paste(
      readLines(
        file.path(
          project_root,
          "R",
          "05b_canonical_annotation_output.R"
        ),
        warn = FALSE,
        encoding = "UTF-8"
      ),
      collapse = "\n"
    )

    testthat::expect_true(
      grepl(
        "pvalue_export <- prepare_graphml_pvalue_export(",
        graphml_source,
        fixed = TRUE
      )
    )

    testthat::expect_true(
      grepl(
        "pvalue = as.numeric(pvalue_export$value)",
        graphml_source,
        fixed = TRUE
      )
    )

    testthat::expect_true(
      grepl(
        "pvalue_was_floored_for_graphml =",
        graphml_source,
        fixed = TRUE
      )
    )
  }
)
