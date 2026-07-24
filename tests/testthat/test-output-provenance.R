testthat::test_that(
  "Phase 4.7 schema registry is complete and pinned",
  {
    testthat::expect_identical(
      cancerppir_schema_versions(),
      list(
        pipeline_result = "4.7.0",
        biological_evidence = "1.0.0",
        analytical_workbook = "4.5.0",
        technical_workbook = "4.4.0",
        graphml = "4.6.0",
        output_manifest = "1.0.0",
        output_checksums = "1.0.0"
      )
    )
  }
)

testthat::test_that(
  "output provenance records and verifies principal files without absolute paths",
  {
    fixture_dir <- tempfile(
      pattern = "cancerppir_phase47_fixture_"
    )

    dir.create(
      fixture_dir,
      recursive = TRUE,
      showWarnings = FALSE
    )

    on.exit(
      unlink(
        fixture_dir,
        recursive = TRUE,
        force = TRUE
      ),
      add = TRUE
    )

    input_file <- file.path(
      fixture_dir,
      "fixture_input.csv"
    )

    writeLines(
      c(
        "gene,pvalue,logFC",
        "TP53,0.001,2"
      ),
      input_file
    )

    output_files <- c(
      analytical_report = file.path(
        fixture_dir,
        "CancerPPIr_Analytical_Report.xlsx"
      ),
      technical_report = file.path(
        fixture_dir,
        "CancerPPIr_Technical_Report.xlsx"
      ),
      string_links = file.path(
        fixture_dir,
        "STRING_links.txt"
      ),
      graphml = file.path(
        fixture_dir,
        "Network_for_Cytoscape.graphml"
      )
    )

    writeLines("analytical fixture", output_files[["analytical_report"]])
    writeLines("technical fixture", output_files[["technical_report"]])
    writeLines("STRING fixture", output_files[["string_links"]])
    writeLines("<graphml></graphml>", output_files[["graphml"]])

    provenance <- cancerppir_write_output_provenance(
      input_file = input_file,
      output_dir = fixture_dir,
      output_files = output_files,
      output_roles = c(
        analytical_report = "analytical",
        technical_report = "technical",
        string_links = "links",
        graphml = "network"
      ),
      output_schema_versions = c(
        analytical_report = "4.5.0",
        technical_report = "4.4.0",
        string_links = "1.0.0",
        graphml = "4.6.0"
      ),
      input_summary = list(
        input_rows = 1L,
        normalized_unique_genes = 1L,
        mapped_input_rows = 1L,
        unmapped_input_rows = 0L,
        unique_mapped_proteins = 1L,
        successful_alias_corrections = 0L
      ),
      analysis_configuration = list(
        species_taxonomy_id = 9606L,
        STRING_version = "12.0",
        STRING_score_threshold = 400L,
        enrichment_mode = "offline",
        local_enrichment_enabled = TRUE,
        online_enrichment_enabled = FALSE,
        Louvain_seed = CANCERPPIR_LOUVAIN_SEED,
        FDR_threshold = 0.05,
        candidate_top_n = 30L
      ),
      run_summary = list(
        network_nodes = 1L,
        network_edges = 0L,
        connected_components = 1L,
        Louvain_modules = 1L,
        priority_eligible_modules = 0L,
        final_priority_candidates = 0L
      ),
      project_root = fixture_dir,
      forbidden_paths = fixture_dir
    )

    testthat::expect_true(
      file.exists(provenance$manifest_file)
    )

    testthat::expect_true(
      file.exists(provenance$checksums_file)
    )

    testthat::expect_true(
      all(provenance$validation$status == "PASS")
    )

    manifest <- jsonlite::read_json(
      provenance$manifest_file,
      simplifyVector = FALSE
    )

    testthat::expect_identical(
      manifest$input$file_name,
      "fixture_input.csv"
    )

    testthat::expect_identical(
      manifest$input$sha256,
      cancerppir_sha256_file(input_file)
    )

    testthat::expect_setequal(
      names(manifest$outputs),
      basename(output_files)
    )

    manifest_text <- paste(
      readLines(
        provenance$manifest_file,
        warn = FALSE,
        encoding = "UTF-8"
      ),
      collapse = "\n"
    )

    testthat::expect_false(
      grepl(
        fixture_dir,
        manifest_text,
        fixed = TRUE
      )
    )

    checksum_table <- cancerppir_parse_checksum_file(
      provenance$checksums_file
    )

    testthat::expect_setequal(
      checksum_table$file_name,
      c(
        basename(output_files),
        basename(provenance$manifest_file)
      )
    )

    testthat::expect_false(
      basename(provenance$checksums_file) %in%
        checksum_table$file_name
    )
  }
)

testthat::test_that(
  "provenance validation detects post-run output modification",
  {
    fixture_dir <- tempfile(
      pattern = "cancerppir_phase47_tamper_"
    )

    dir.create(
      fixture_dir,
      recursive = TRUE,
      showWarnings = FALSE
    )

    on.exit(
      unlink(
        fixture_dir,
        recursive = TRUE,
        force = TRUE
      ),
      add = TRUE
    )

    input_file <- file.path(fixture_dir, "input.csv")
    writeLines("gene,pvalue,logFC\nTP53,0.01,1", input_file)

    output_files <- c(
      analytical_report = file.path(fixture_dir, "analytical.xlsx"),
      technical_report = file.path(fixture_dir, "technical.xlsx"),
      string_links = file.path(fixture_dir, "links.txt"),
      graphml = file.path(fixture_dir, "network.graphml")
    )

    invisible(
      lapply(
        output_files,
        function(path) writeLines(basename(path), path)
      )
    )

    provenance <- cancerppir_write_output_provenance(
      input_file = input_file,
      output_dir = fixture_dir,
      output_files = output_files,
      output_roles = stats::setNames(
        rep("fixture", length(output_files)),
        names(output_files)
      ),
      output_schema_versions = stats::setNames(
        rep("fixture", length(output_files)),
        names(output_files)
      ),
      input_summary = list(input_rows = 1L),
      analysis_configuration = list(mode = "fixture"),
      run_summary = list(nodes = 1L),
      project_root = fixture_dir,
      forbidden_paths = fixture_dir
    )

    cat(
      "tampered",
      file = output_files[["graphml"]],
      append = TRUE
    )

    validation <- cancerppir_validate_output_provenance(
      manifest_file = provenance$manifest_file,
      checksums_file = provenance$checksums_file,
      output_dir = fixture_dir,
      forbidden_paths = fixture_dir
    )

    testthat::expect_identical(
      validation$status[
        validation$check_id ==
          "manifest_output_hashes_match_files"
      ],
      "FAIL"
    )

    testthat::expect_identical(
      validation$status[
        validation$check_id ==
          "checksum_hashes_match_files"
      ],
      "FAIL"
    )
  }
)

testthat::test_that(
  "production pipeline writes provenance before building the public result",
  {
    pipeline_body <- paste(
      deparse(
        body(run_cancerppir),
        width.cutoff = 500L
      ),
      collapse = "\n"
    )

    testthat::expect_true(
      grepl(
        "cancerppir_write_output_provenance(",
        pipeline_body,
        fixed = TRUE
      )
    )

    testthat::expect_true(
      grepl(
        "CancerPPIr_Output_Manifest.json",
        pipeline_body,
        fixed = TRUE
      )
    )

    testthat::expect_true(
      grepl(
        "CancerPPIr_Output_Checksums.sha256",
        pipeline_body,
        fixed = TRUE
      )
    )

    testthat::expect_true(
      grepl(
        "provenance = output_provenance",
        pipeline_body,
        fixed = TRUE
      )
    )
  }
)
