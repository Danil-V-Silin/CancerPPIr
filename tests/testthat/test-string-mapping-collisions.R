testthat::test_that(
  "STRING mapping collisions use the declared deterministic policy",
  {
    mapped <- tibble::tibble(
      input_row = c(7L, 3L, 5L, 9L),
      input_gene = c("ALIAS_A", "GENE_B", "GENE_C", "GENE_D"),
      gene = c("GENE_A", "GENE_B", "GENE_C", "GENE_D"),
      logFC = c(1.5, -3, 2, 1),
      pvalue = c(0.01, 0.01, 0.20, 0.50),
      STRING_id = c("9606.P1", "9606.P1", "9606.P2", NA_character_)
    )

    forward <- resolve_string_mapping_collisions(mapped)
    reversed <- resolve_string_mapping_collisions(mapped[nrow(mapped):1L, ])

    testthat::expect_identical(
      forward$mapped$input_row,
      c(3L, 5L)
    )
    testthat::expect_identical(
      forward$mapped,
      reversed$mapped
    )
    testthat::expect_identical(forward$collision_proteins, 1L)
    testthat::expect_identical(forward$dropped_rows, 1L)
    testthat::expect_identical(
      forward$collision_audit$selected,
      c(TRUE, FALSE)
    )
    testthat::expect_match(
      forward$policy,
      "minimum raw pvalue",
      fixed = TRUE
    )
  }
)

testthat::test_that(
  "STRING mapping collision ties use the earliest validated input row",
  {
    mapped <- tibble::tibble(
      input_row = c(8L, 2L),
      gene = c("GENE_A", "GENE_B"),
      logFC = c(2, -2),
      pvalue = c(0.01, 0.01),
      STRING_id = c("9606.P1", "9606.P1")
    )

    result <- resolve_string_mapping_collisions(mapped)

    testthat::expect_identical(result$mapped$input_row, 2L)
  }
)
