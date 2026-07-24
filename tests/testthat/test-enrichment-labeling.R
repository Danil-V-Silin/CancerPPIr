testthat::test_that("generic enrichment filtering distinguishes specific biology", {
  result <- is_generic_enrichment_term(
    c(
      "Signaling",
      "regulation of leukocyte migration",
      "regulation of cellular process"
    )
  )

  testthat::expect_identical(
    result,
    c(TRUE, FALSE, TRUE)
  )
})

testthat::test_that("enrichment priority columns are generated deterministically", {
  input <- tibble::tibble(
    category = c(
      "Biological Process (Gene Ontology)",
      "Protein Domains (Pfam)"
    ),
    description = c(
      "leukocyte migration",
      "protein binding"
    ),
    fdr = c(0.01, 0.20),
    pvalue = c(0.001, 0.10)
  )

  result <- add_enrichment_priority(input)

  testthat::expect_true(
    all(c(
      "category_priority",
      "is_preferred_category",
      "is_secondary_category",
      "is_generic_term",
      "is_specific_interpretable"
    ) %in% names(result))
  )

  testthat::expect_true(result$is_preferred_category[[1]])
  testthat::expect_true(result$is_specific_interpretable[[1]])
  testthat::expect_true(result$is_secondary_category[[2]])
  testthat::expect_true(result$is_generic_term[[2]])
})

testthat::test_that("local STRING enrichment works on a synthetic fixture", {
  background_ids <- paste0("9606.P", seq_len(10L))
  query_ids <- paste0("9606.P", 1:3)

  term_map <- tibble::tibble(
    string_protein_id = c(
      paste0("9606.P", 1:5),
      paste0("9606.P", 6:10)
    ),
    category = rep(
      "Biological Process (Gene Ontology)",
      10L
    ),
    term = c(
      rep("GO:IMMUNE", 5L),
      rep("GO:OTHER", 5L)
    ),
    description = c(
      rep("leukocyte migration", 5L),
      rep("unrelated process", 5L)
    )
  )

  id_to_gene <- stats::setNames(
    paste0("GENE", seq_len(10L)),
    background_ids
  )

  result <- run_local_string_enrichment(
    query_ids = query_ids,
    background_ids = background_ids,
    term_map = term_map,
    query_name = "synthetic_query",
    id_to_gene = id_to_gene
  )

  testthat::expect_equal(nrow(result), 1L)
  testthat::expect_identical(result$term[[1]], "GO:IMMUNE")
  testthat::expect_equal(result$number_of_genes[[1]], 3L)
  testthat::expect_true(is.finite(result$pvalue[[1]]))
  testthat::expect_true(is.finite(result$fdr[[1]]))
})

testthat::test_that("module labeling recognizes curated biological programs", {
  cell_cycle <- label_module_by_markers(
    c("CDK1", "TOP2A", "CDC20", "CCNB1")
  )

  testthat::expect_identical(
    cell_cycle$clean_label,
    "cell_cycle_mitotic_module"
  )

  testthat::expect_identical(
    clean_module_label_from_terms("collagen extracellular matrix organization"),
    "stromal_ECM_remodeling_module"
  )

  counts <- extract_marker_counts(
    "cell_cycle_mitotic(5); antigen_presentation(2)"
  )

  testthat::expect_identical(
    unname(counts[c("cell_cycle_mitotic", "antigen_presentation")]),
    c(5L, 2L)
  )

  testthat::expect_identical(
    label_evidence_score(
      marker_count = 3L,
      term_hit_count = 1L,
      required_hit_count = 1L,
      best_fdr = 0.01,
      module_size = 20L
    ),
    9L
  )
})
