cancerppir_write_synthetic_gzip <- function(path, lines) {
  connection <- gzfile(path, open = "wt", encoding = "UTF-8")
  on.exit(close(connection), add = TRUE)
  writeLines(lines, connection, useBytes = TRUE)
}

testthat::test_that(
  "synthetic STRING resources exercise the complete production pipeline",
  {
    required_packages <- c(
      "HGNChelper", "STRINGdb", "igraph", "openxlsx", "dplyr",
      "tibble", "curl", "sna", "jsonlite", "digest"
    )

    for (package in required_packages) {
      testthat::skip_if_not_installed(package)
    }

    fixture_root <- tempfile(pattern = "cancerppir_pipeline_integration_")
    cache_dir <- file.path(fixture_root, "string_cache")
    results_root <- file.path(fixture_root, "results")
    dir.create(cache_dir, recursive = TRUE)

    on.exit(unlink(fixture_root, recursive = TRUE, force = TRUE), add = TRUE)

    genes <- c(
      "CDK1", "CCNB1", "TOP2A", "CDC20", "BIRC5", "AURKB",
      "PTPRC", "TYROBP", "HLA-DRA", "CD74", "C1QA", "C1QB"
    )
    protein_ids <- paste0("9606.ENSPTEST", sprintf("%04d", seq_along(genes)))

    cancerppir_write_synthetic_gzip(
      file.path(cache_dir, "9606.protein.info.v12.0.txt.gz"),
      c(
        "#string_protein_id\tpreferred_name\tprotein_size\tannotation",
        paste(protein_ids, genes, "100", "Synthetic protein", sep = "\t")
      )
    )

    alias_ids <- c(protein_ids, protein_ids[[6L]])
    alias_genes <- c(genes, "AURKA")

    cancerppir_write_synthetic_gzip(
      file.path(cache_dir, "9606.protein.aliases.v12.0.txt.gz"),
      c(
        "#string_protein_id\talias\tsource",
        paste(alias_ids, alias_genes, "Ensembl_HGNC_symbol", sep = "\t")
      )
    )

    first_clique <- utils::combn(protein_ids[1:6], 2L)
    second_clique <- utils::combn(protein_ids[7:12], 2L)
    edges <- cbind(
      first_clique,
      second_clique,
      c(protein_ids[[1L]], protein_ids[[7L]])
    )

    cancerppir_write_synthetic_gzip(
      file.path(cache_dir, "9606.protein.links.v12.0.txt.gz"),
      c(
        "protein1 protein2 combined_score",
        paste(edges[1L, ], edges[2L, ], "900")
      )
    )

    term_ids <- rep(c("GO:SYNTHETIC_CELL", "GO:SYNTHETIC_IMMUNE"), each = 6L)
    term_names <- rep(c("mitotic cell cycle", "immune response"), each = 6L)

    cancerppir_write_synthetic_gzip(
      file.path(cache_dir, "9606.protein.enrichment.terms.v12.0.txt.gz"),
      c(
        "#string_protein_id\tcategory\tterm\tdescription",
        paste(
          protein_ids,
          "Biological Process (Gene Ontology)",
          term_ids,
          term_names,
          sep = "\t"
        )
      )
    )

    input_file <- file.path(fixture_root, "synthetic_input.csv")
    utils::write.csv(
      data.frame(
        gene = alias_genes,
        logFC = c(seq(2.4, 1.3, length.out = 12L), 3),
        pvalue = c(seq(0.001, 0.012, length.out = 12L), 1e-8),
        stringsAsFactors = FALSE
      ),
      input_file,
      row.names = FALSE,
      quote = TRUE
    )

    result <- suppressMessages(
      run_cancerppir(
        input_file = input_file,
        results_root = results_root,
        cache_dir = cache_dir,
        score_threshold = 400L,
        top_n = 12L,
        run_enrichment = TRUE,
        case_id = "SYNTHETIC01"
      )
    )

    expected_files <- c(
      "CancerPPIr_Analytical_Report.xlsx",
      "CancerPPIr_Technical_Report.xlsx",
      "Network_for_Cytoscape.graphml",
      "STRING_links.txt",
      "CancerPPIr_Output_Manifest.json",
      "CancerPPIr_Output_Checksums.sha256"
    )

    testthat::expect_s3_class(result, "cancerppir_result")
    testthat::expect_true(all(file.exists(file.path(result$output_dir, expected_files))))

    graph <- igraph::read_graph(
      file.path(result$output_dir, "Network_for_Cytoscape.graphml"),
      format = "graphml"
    )
    manifest <- jsonlite::read_json(
      file.path(result$output_dir, "CancerPPIr_Output_Manifest.json"),
      simplifyVector = FALSE
    )

    testthat::expect_identical(as.integer(igraph::vcount(graph)), 12L)
    testthat::expect_identical(as.integer(manifest$input$input_rows), 13L)
    testthat::expect_identical(as.integer(manifest$input$unique_mapped_proteins), 12L)
    testthat::expect_identical(
      as.integer(manifest$input$STRING_mapping_collision_proteins),
      1L
    )
    testthat::expect_identical(
      as.integer(manifest$input$STRING_mapping_collision_rows_dropped),
      1L
    )
    testthat::expect_identical(as.character(manifest$input$case_id), "SYNTHETIC01")
    testthat::expect_identical(
      as.character(manifest$software$version),
      cancerppir_product_version()
    )

    provenance <- cancerppir_validate_output_provenance(
      manifest_file = file.path(result$output_dir, expected_files[[5L]]),
      checksums_file = file.path(result$output_dir, expected_files[[6L]]),
      output_dir = result$output_dir,
      forbidden_paths = c(cache_dir, results_root)
    )

    testthat::expect_true(all(provenance$status == "PASS"))
    testthat::expect_true(any(result$biological_evidence$validation$status == "PASS"))
  }
)
