# CancerPPIr: Pipeline orchestration
#
# Responsibility: End-to-end CancerPPIr workflow coordination with explicit inputs and returned analysis objects.
#
# Architecture checkpoint 2.3
#
# This module intentionally contains no extracted legacy functions at this checkpoint.
# Function definitions will be moved here incrementally without semantic rewriting.


# -----------------------------------------------------------------------------
# End-to-end CancerPPIr workflow
# Architecture checkpoint 2.12
# -----------------------------------------------------------------------------

run_cancerppir <- function(
  input_file,
  results_root,
  cache_dir,
  score_threshold = 400L,
  top_n = 30L,
  run_enrichment = TRUE
) {
  required_cran <- c("HGNChelper", "igraph", "openxlsx", "dplyr", "tibble", "curl", "sna")
  required_bioc <- c("STRINGdb")
  optional_cran <- c("gprofiler2")


  invisible(lapply(c(required_cran, required_bioc), check_package))

  suppressPackageStartupMessages({
    library(HGNChelper)
    library(STRINGdb)
    library(igraph)
    library(openxlsx)
    library(dplyr)
    library(tibble)
    library(curl)
  })

  # Derive output directory from the input filename. This prevents accidental creation
  # of many variant folders such as Genes_R_CancerPPIr_offline_v7. The target folder is
  # always <results_root>/<input_basename_without_extension>, unless the user already
  # passes exactly that folder as the second argument.
  sample_name <- tools::file_path_sans_ext(basename(input_file))
  sample_name <- gsub("[<>:\"/\\|?*]+", "_", sample_name)
  sample_name <- trimws(sample_name)
  if (!nzchar(sample_name)) {
    stop("Could not derive a valid sample name from input file: ", input_file, call. = FALSE)
  }


  results_root_cmp <- normalize_path_for_compare(results_root)
  results_root_base <- basename(results_root_cmp)
  results_root_parent <- dirname(results_root_cmp)

  if (identical(results_root_base, sample_name)) {
    output_dir <- results_root
  } else if (startsWith(results_root_base, paste0(sample_name, "_")) &&
             basename(results_root_parent) %in% c("results", "result", "reults")) {
    # Backward-safety: if a previous command used results/Genes_R_variant as output,
    # redirect to the canonical patient folder results/Genes_R.
    output_dir <- file.path(results_root_parent, sample_name)
  } else {
    output_dir <- file.path(results_root, sample_name)
  }

  # Online enrichment is deliberately disabled in this offline-only release.
  enrichment_mode <- "offline"
  run_online_enrichment <- FALSE

  if (!file.exists(input_file)) {
    stop("Input file not found: ", input_file, call. = FALSE)
  }

  if (is.na(score_threshold) || score_threshold <= 0) {
    stop("score_threshold must be a positive integer.", call. = FALSE)
  }

  if (is.na(top_n) || top_n <= 0) {
    stop("top_n must be a positive integer.", call. = FALSE)
  }

  if (!dir.exists(output_dir)) dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)
  dir.create(cache_dir, showWarnings = FALSE, recursive = TRUE)

  options(timeout = max(600, getOption("timeout", 60)))
  Sys.setenv(R_DEFAULT_INTERNET_TIMEOUT = "600")

  ca_bundle <- tryCatch(curl::ca_bundle(), error = function(e) "")
  if (nzchar(ca_bundle)) {
    Sys.setenv(CURL_CA_BUNDLE = ca_bundle)
    Sys.setenv(SSL_CERT_FILE = ca_bundle)
  }
































  msg("Reading input table.")
  input_tbl <- read_gene_table(input_file)

  msg("Checking gene symbols.")
  hgnc_map <- HGNChelper::checkGeneSymbols(
    unique(input_tbl$gene),
    species = "human",
    map = HGNChelper::hgnc.table
  ) %>%
    mutate(
      suggested_symbol = coalesce(Suggested.Symbol, x),
      changed_by_hgnc = x != suggested_symbol
    ) %>%
    select(original_gene = x, suggested_symbol, changed_by_hgnc)

  input_tbl <- input_tbl %>%
    mutate(
      input_gene = gene,
      gene = hgnc_map$suggested_symbol[match(gene, hgnc_map$original_gene)]
    ) %>%
    filter(!is.na(gene), nzchar(gene))

  if (!nrow(input_tbl)) {
    stop("No rows remained after gene-symbol normalization.", call. = FALSE)
  }

  msg("Initializing STRINGdb.")
  string_db <- tryCatch(
    STRINGdb$new(
      species = 9606,
      version = "12.0",
      score_threshold = score_threshold,
      network_type = "full",
      input_directory = cache_dir
    ),
    error = function(e) {
      if (.Platform$OS.type == "windows") {
        options(download.file.method = "wininet", url.method = "wininet")
      }

      STRINGdb$new(
        species = 9606,
        version = "12.0",
        score_threshold = score_threshold,
        network_type = "full",
        input_directory = cache_dir
      )
    }
  )

  msg("Mapping genes to STRING identifiers.")
  mapped_initial <- map_to_string(string_db, input_tbl, "gene", removeUnmappedRows = FALSE)

  initial_total <- nrow(mapped_initial)
  initial_mapped <- sum(!is.na(mapped_initial$STRING_id))
  initial_unmapped <- initial_total - initial_mapped
  initial_pct <- round(100 * initial_mapped / initial_total, 1)

  unmapped_genes <- sort(unique(mapped_initial$gene[is.na(mapped_initial$STRING_id)]))

  alias_corrections <- tibble(
    original_gene = unmapped_genes,
    corrected_gene = NA_character_,
    method = NA_character_,
    mapped_after = FALSE
  )

  if (length(unmapped_genes)) {
    msg("Trying unambiguous STRING alias correction for unmapped symbols.")

    string_tables <- tryCatch(
      list(
        aliases = string_db$get_aliases(),
        proteins = string_db$get_proteins()
      ),
      error = function(e) {
        msg("Alias correction skipped: ", conditionMessage(e))
        NULL
      }
    )

    if (!is.null(string_tables)) {
      aliases <- string_tables$aliases
      proteins <- string_tables$proteins

      id_alias_col <- pick_string_id_col(aliases)
      alias_col <- pick_alias_col(aliases, id_alias_col)
      id_protein_col <- pick_string_id_col(proteins)
      name_col <- pick_preferred_name_col(proteins)

      aliases_std <- aliases %>%
        transmute(
          protein_id = .data[[id_alias_col]],
          alias_uc = toupper(trimws(.data[[alias_col]]))
        ) %>%
        distinct()

      proteins_std <- proteins %>%
        transmute(
          protein_id = .data[[id_protein_col]],
          preferred_name = .data[[name_col]]
        ) %>%
        distinct()

      alias_hits <- tibble(
        original_gene = unmapped_genes,
        alias_uc = toupper(unmapped_genes)
      ) %>%
        inner_join(aliases_std, by = "alias_uc") %>%
        group_by(original_gene) %>%
        filter(n_distinct(protein_id) == 1L) %>%
        slice(1) %>%
        ungroup() %>%
        left_join(proteins_std, by = "protein_id")

      if (nrow(alias_hits)) {
        alias_hgnc <- HGNChelper::checkGeneSymbols(
          unique(alias_hits$preferred_name),
          species = "human",
          map = HGNChelper::hgnc.table
        ) %>%
          mutate(suggested_symbol = coalesce(Suggested.Symbol, x)) %>%
          select(preferred_name = x, suggested_symbol)

        alias_corrections <- alias_corrections %>%
          left_join(
            alias_hits %>%
              left_join(alias_hgnc, by = "preferred_name") %>%
              transmute(
                original_gene,
                corrected_gene_new = suggested_symbol,
                method_new = "STRING_alias"
              ),
            by = "original_gene"
          ) %>%
          mutate(
            corrected_gene = coalesce(corrected_gene, corrected_gene_new),
            method = coalesce(method, method_new)
          ) %>%
          select(original_gene, corrected_gene, method, mapped_after)
      }
    }
  }

  valid_alias_corrections <- alias_corrections %>%
    filter(!is.na(corrected_gene), nzchar(corrected_gene)) %>%
    distinct(original_gene, corrected_gene)

  input_final <- input_tbl

  if (nrow(valid_alias_corrections)) {
    input_final <- input_final %>%
      mutate(
        gene = ifelse(
          gene %in% valid_alias_corrections$original_gene,
          valid_alias_corrections$corrected_gene[match(gene, valid_alias_corrections$original_gene)],
          gene
        )
      )
  }

  mapped_final_raw <- map_to_string(string_db, input_final, "gene", removeUnmappedRows = FALSE)

  if (nrow(alias_corrections)) {
    alias_status <- mapped_final_raw %>%
      distinct(gene, STRING_id)

    alias_corrections <- alias_corrections %>%
      mutate(
        mapped_after = !is.na(corrected_gene) &
          !is.na(alias_status$STRING_id[match(corrected_gene, alias_status$gene)])
      )
  }

  mapped_final <- mapped_final_raw %>%
    filter(!is.na(STRING_id), grepl("^9606\\.", STRING_id)) %>%
    distinct(STRING_id, .keep_all = TRUE)

  if (nrow(mapped_final) < 2) {
    stop("Fewer than two unique STRING identifiers were mapped.", call. = FALSE)
  }

  after_total <- nrow(mapped_final_raw)
  after_mapped <- sum(!is.na(mapped_final_raw$STRING_id))
  after_unmapped <- after_total - after_mapped
  after_pct <- round(100 * after_mapped / after_total, 1)

  network_analysis <- run_network_analysis(
    string_db = string_db,
    mapped_final = mapped_final,
    input_tbl = input_tbl,
    mapped_initial = mapped_initial,
    mapped_final_raw = mapped_final_raw,
    valid_alias_corrections = valid_alias_corrections,
    initial_mapped = initial_mapped,
    initial_unmapped = initial_unmapped,
    initial_pct = initial_pct,
    after_mapped = after_mapped,
    after_unmapped = after_unmapped,
    after_pct = after_pct,
    score_threshold = score_threshold,
    top_n = top_n
  )

  ppi <- network_analysis$ppi
  comp <- network_analysis$comp
  node_metrics <- network_analysis$node_metrics
  top_n <- network_analysis$top_n
  top_candidates <- network_analysis$top_candidates
  top_by_degree <- network_analysis$top_by_degree
  top_by_betweenness <- network_analysis$top_by_betweenness
  top_by_stress <- network_analysis$top_by_stress
  degree_distribution <- network_analysis$degree_distribution
  module_summary <- network_analysis$module_summary
  major_module_ids <- network_analysis$major_module_ids
  graph_summary <- network_analysis$graph_summary
  mapping_summary <- network_analysis$mapping_summary
  gene_status <- network_analysis$gene_status
  still_unmapped <- network_analysis$still_unmapped

  rm(network_analysis)


  enrichment_string_online_all <- tibble()
  enrichment_string_online_top <- tibble()
  module_enrichment_string_online <- tibble()
  online_enrichment_status <- tibble()
  enrichment_string_local_all <- tibble()
  enrichment_string_local_top <- tibble()
  module_enrichment_string_local <- tibble()
  local_string_terms <- tibble()
  enrichment_gprofiler_all <- tibble()
  enrichment_gprofiler_top <- tibble()
  module_enrichment_gprofiler <- tibble()

  if (isTRUE(run_enrichment)) {
    msg("Running functional enrichment analysis.")
    if (!requireNamespace("gprofiler2", quietly = TRUE)) {
      msg("Optional package gprofiler2 is not installed; g:Profiler enrichment will be skipped.")
    }

    id_to_gene <- setNames(node_metrics$gene, node_metrics$STRING_id)
    local_string_terms <- read_string_enrichment_terms(cache_dir)
    if (nrow(local_string_terms)) {
      msg("Local STRING enrichment terms loaded: ", nrow(local_string_terms), " protein-term links.")
    } else {
      msg("Local STRING enrichment terms unavailable; module_summary will use marker-based labels only.")
    }
    full_string_background <- if (nrow(local_string_terms)) {
      unique(local_string_terms$string_protein_id)
    } else {
      mapped_final$STRING_id
    }

    enrichment_string_local_all <- run_local_string_enrichment(
      query_ids = mapped_final$STRING_id,
      background_ids = full_string_background,
      term_map = local_string_terms,
      query_name = "all_network_genes_vs_STRING_human_background",
      id_to_gene = id_to_gene,
      min_query_hits = 2L
    )

    enrichment_string_local_top <- run_local_string_enrichment(
      query_ids = top_candidates$STRING_id,
      background_ids = mapped_final$STRING_id,
      term_map = local_string_terms,
      query_name = "top_candidates_vs_network_background",
      id_to_gene = id_to_gene,
      min_query_hits = 2L
    )

    module_enrichment_string_local <- bind_rows(lapply(
      split(node_metrics %>% filter(community_louvain %in% major_module_ids),
            node_metrics$community_louvain[node_metrics$community_louvain %in% major_module_ids]),
      function(m) {
        if (nrow(m) < 5L) {
          return(tibble())
        }
        run_local_string_enrichment(
          query_ids = m$STRING_id,
          background_ids = mapped_final$STRING_id,
          term_map = local_string_terms,
          query_name = paste0("module_", unique(m$community_louvain), "_vs_network_background"),
          id_to_gene = id_to_gene,
          min_query_hits = 2L
        ) %>%
          mutate(community_louvain = unique(m$community_louvain), .after = query_name)
      }
    ))

    if (isTRUE(run_online_enrichment)) {
      msg("Online enrichment validation mode enabled. Local STRING remains the primary fallback annotation layer.")

      enrichment_string_online_all <- run_string_enrichment_online(string_db, 
        mapped_final$STRING_id,
        query_name = "all_network_genes_STRING_online"
      )
      enrichment_string_online_top <- run_string_enrichment_online(string_db, 
        top_candidates$STRING_id,
        query_name = "top_candidates_STRING_online"
      )

      module_enrichment_string_online <- bind_rows(lapply(
        split(node_metrics %>% filter(community_louvain %in% major_module_ids),
              node_metrics$community_louvain[node_metrics$community_louvain %in% major_module_ids]),
        function(m) {
          if (nrow(m) < 5L) {
            return(tibble())
          }
          qn <- paste0("module_", unique(m$community_louvain), "_STRING_online")
          st <- run_string_enrichment_online(string_db, m$STRING_id, query_name = qn)
          if (!nrow(st)) {
            return(tibble())
          }
          st %>% mutate(community_louvain = unique(m$community_louvain), .after = query_name)
        }
      ))

      enrichment_gprofiler_all <- run_gprofiler(node_metrics$gene, "all_network_genes_gProfiler")
      enrichment_gprofiler_top <- run_gprofiler(top_candidates$gene, "top_candidates_gProfiler")

      module_enrichment_gprofiler <- bind_rows(lapply(
        split(node_metrics %>% filter(community_louvain %in% major_module_ids),
              node_metrics$community_louvain[node_metrics$community_louvain %in% major_module_ids]),
        function(m) {
          if (nrow(m) < 5L) {
            return(tibble())
          }
          qn <- paste0("module_", unique(m$community_louvain), "_gProfiler")
          gp <- run_gprofiler(m$gene, qn)
          if (!nrow(gp)) {
            return(tibble())
          }
          gp %>% mutate(community_louvain = unique(m$community_louvain), .after = query_name)
        }
      ))

      if (!nrow(enrichment_string_online_all) && !nrow(enrichment_string_online_top) &&
          !nrow(module_enrichment_string_online) && !nrow(enrichment_gprofiler_all) &&
          !nrow(enrichment_gprofiler_top) && !nrow(module_enrichment_gprofiler)) {
        msg("Online enrichment returned no usable results; continuing with local STRING enrichment only.")
      }
    } else {
      msg("Online enrichment is disabled; using local STRING enrichment and marker-based module labels.")
    }

    online_enrichment_status <- tibble(
      setting = c(
        "run_enrichment", "enrichment_mode", "online_validation_requested",
        "gprofiler2_installed", "local_STRING_terms_loaded",
        "STRING_online_network_rows", "STRING_online_candidate_rows", "STRING_online_module_rows",
        "gProfiler_network_rows", "gProfiler_candidate_rows", "gProfiler_module_rows"
      ),
      value = c(
        as.character(run_enrichment), enrichment_mode, as.character(run_online_enrichment),
        as.character(requireNamespace("gprofiler2", quietly = TRUE)), as.character(nrow(local_string_terms)),
        as.character(nrow(enrichment_string_online_all)), as.character(nrow(enrichment_string_online_top)), as.character(nrow(module_enrichment_string_online)),
        as.character(nrow(enrichment_gprofiler_all)), as.character(nrow(enrichment_gprofiler_top)), as.character(nrow(module_enrichment_gprofiler))
      )
    )

    if (nrow(module_enrichment_string_local)) {
      top_terms <- module_enrichment_string_local %>%
        filter(is.finite(fdr)) %>%
        group_by(community_louvain) %>%
        arrange(fdr, pvalue, .by_group = TRUE) %>%
        summarise(
          enrichment_evidence_terms = paste(head(unique(description), 3L), collapse = "; "),
          top_enrichment_sources = paste(head(unique(category), 3L), collapse = ";"),
          min_enrichment_pvalue = min(pvalue, na.rm = TRUE),
          min_enrichment_fdr = min(fdr, na.rm = TRUE),
          .groups = "drop"
        )

      module_summary <- module_summary %>%
        left_join(top_terms, by = "community_louvain")
    } else if (nrow(module_enrichment_gprofiler)) {
      top_terms <- module_enrichment_gprofiler %>%
        group_by(community_louvain) %>%
        arrange(p_value, .by_group = TRUE) %>%
        summarise(
          enrichment_evidence_terms = paste(head(unique(term_name), 3L), collapse = "; "),
          top_enrichment_sources = paste(head(unique(source), 3L), collapse = ";"),
          min_enrichment_pvalue = min(p_value, na.rm = TRUE),
          min_enrichment_fdr = min(p_value, na.rm = TRUE),
          .groups = "drop"
        )

      module_summary <- module_summary %>%
        left_join(top_terms, by = "community_louvain")
    }

    if (!("enrichment_evidence_terms" %in% names(module_summary))) {
      module_summary <- module_summary %>%
        mutate(
          enrichment_evidence_terms = NA_character_,
          top_enrichment_sources = NA_character_,
          min_enrichment_pvalue = NA_real_,
          min_enrichment_fdr = NA_real_
        )
    }

    module_summary <- module_summary %>%
      mutate(
        clean_module_label = mapply(
          clean_module_label_from_terms,
          enrichment_evidence_terms,
          marker_clean_label,
          USE.NAMES = FALSE
        ),
        module_direction = clean_module_label
      )
  } else {
    module_summary <- module_summary %>%
      mutate(
        enrichment_evidence_terms = NA_character_,
        top_enrichment_sources = NA_character_,
        min_enrichment_pvalue = NA_real_,
        min_enrichment_fdr = NA_real_,
        clean_module_label = marker_clean_label,
        module_direction = clean_module_label
      )
  }

  # The standalone major modules table is intentionally limited to the five largest modules.
  major_module_summary <- module_summary %>%
    filter(community_louvain %in% major_module_ids) %>%
    arrange(match(community_louvain, major_module_ids)) %>%
    mutate(major_module_rank = row_number(), .before = 1)

  node_metrics <- node_metrics %>%
    left_join(
      module_summary %>%
        select(
          community_louvain, module_direction, clean_module_label,
          marker_based_direction, marker_clean_label, marker_evidence_genes,
          enrichment_evidence_terms
        ),
      by = "community_louvain"
    )

  # Rebuild ranked tables after module annotations have been attached.
  top_candidates <- node_metrics %>%
    arrange(desc(candidate_score), desc(degree), desc(betweenness)) %>%
    slice_head(n = top_n)

  top_by_degree <- node_metrics %>%
    arrange(desc(degree), desc(candidate_score), desc(betweenness)) %>%
    slice_head(n = top_n)

  top_by_betweenness <- node_metrics %>%
    arrange(desc(betweenness), desc(candidate_score), desc(degree)) %>%
    slice_head(n = top_n)

  top_by_stress <- node_metrics %>%
    arrange(desc(stress_centrality), desc(candidate_score), desc(degree)) %>%
    slice_head(n = top_n)
  msg("Writing consolidated output files.")

  # -----------------------------------------------------------------------------
  # Human-readable output layer
  # -----------------------------------------------------------------------------
  # The workflow writes a small number of consolidated files:
  #   1) CancerPPIr_Analytical_Report.xlsx  - main human-readable analytical report
  #   2) CancerPPIr_Technical_Report.xlsx   - raw/technical audit workbook
  #   3) STRING_links.txt                  - current and version-pinned STRING links
  #   4) Network_for_Cytoscape.graphml     - annotated network for Cytoscape/Gephi
  #
  # Design principle:
  #   Biological directions are not invented by the export layer. They are reported as
  #   putative module-level programs and must be traceable to two evidence sources:
  #     a) curated marker-gene overlap defined in the workflow, and/or
  #     b) statistically enriched local STRING terms derived from open annotation resources.
  #   Generic enrichment terms are retained in the technical workbook but filtered out of
  #   the main biological rationale so that the analytical report does not overinterpret
  #   broad terms such as "Signaling" or "Cell communication".
  # -----------------------------------------------------------------------------








  # ---- Enrichment term filtering and evidence scoring --------------------------


  # Categories below are useful for technical audit, but should not drive the main
  # biological direction label in the human-readable report.














  # ---- Rule-based module label assignment --------------------------------------
  # Biological labels are assigned through an explicit evidence rulebook rather than
  # by unconstrained free-text interpretation. Each label has admissible marker-set
  # evidence, admissible STRING/database term evidence, and a conservative fallback
  # label that is used when the evidence is real but not specific enough for the
  # more precise biological label.














  # Module-level readable evidence ------------------------------------------------
  module_enrichment_collapsed <- collapse_module_enrichment(module_enrichment_string_local, n_terms = 6L)

  module_summary_base <- module_summary %>%
    left_join(module_enrichment_collapsed, by = "community_louvain")

  module_label_decisions <- mapply(
    assign_module_label_with_rules,
    marker_label = module_summary_base$marker_clean_label,
    marker_summary = module_summary_base$marker_based_direction,
    term_text = module_summary_base$top_interpretable_terms,
    best_fdr = module_summary_base$best_interpretable_fdr,
    module_size = module_summary_base$module_size,
    SIMPLIFY = FALSE
  )

  module_label_decisions <- bind_rows(lapply(module_label_decisions, tibble::as_tibble_row))

  module_summary_readable <- bind_cols(module_summary_base, module_label_decisions) %>%
    mutate(
      module_rank = dplyr::min_rank(dplyr::desc(module_size)),
      final_label_raw = normalize_label_text(final_label_raw),
      specific_label_candidate_raw = normalize_label_text(specific_label_candidate),
      fallback_label_raw = normalize_label_text(fallback_label),
      final_functional_label = humanize_label(final_label_raw),
      specific_label_candidate = humanize_label(specific_label_candidate_raw),
      fallback_label = humanize_label(fallback_label_raw),
      putative_biological_program = final_functional_label,
      marker_max_overlap_count = max_marker_overlap_count(marker_based_direction),
      dominant_expression_direction = case_when(
        is.finite(median_logFC) & median_logFC > 0 ~ "predominantly_upregulated",
        is.finite(median_logFC) & median_logFC < 0 ~ "predominantly_downregulated",
        TRUE ~ "mixed_or_not_available"
      ),
      database_evidence_summary = case_when(
        !is.na(top_interpretable_terms) & nzchar(top_interpretable_terms) ~ paste0(
          "Specific STRING/database enrichment terms used for interpretation: ",
          top_interpretable_terms,
          "; best FDR=", signif(best_interpretable_fdr, 4L), "."
        ),
        !is.na(top_raw_terms) & nzchar(top_raw_terms) ~ paste0(
          "Only generic/secondary enrichment terms were available for this module in the main filter; raw top terms retained for audit: ",
          top_raw_terms, "."
        ),
        TRUE ~ "No local STRING enrichment evidence available for this module."
      ),
      biological_direction_rationale = paste0(
        "Putative program: ", final_functional_label,
        ". Specific-label candidate: ", specific_label_candidate,
        ". Fallback label: ", fallback_label,
        ". Label assignment mode: ", label_assignment_mode,
        ". Label source: ", label_source,
        ". Evidence score: ", label_evidence_score,
        ". Confidence: ", label_confidence,
        ". Warning: ", label_warning,
        ". Supporting biological themes: ", supporting_biological_themes,
        ". Marker evidence: ", ifelse(is.na(marker_based_direction) | !nzchar(marker_based_direction), "not detected", marker_based_direction),
        ". Database evidence: ", database_evidence_summary,
        " Lead proteins by candidate score: ", top_genes_by_candidate_score, "."
      ),
      biological_direction_rationale = truncate_text(biological_direction_rationale, 1800L)
    ) %>%
    arrange(module_rank, community_louvain)

  major_module_summary_readable <- module_summary_readable %>%
    filter(community_louvain %in% major_module_ids) %>%
    arrange(match(community_louvain, major_module_ids)) %>%
    mutate(major_module_rank = row_number(), .before = 1)

  # Optional online validation is kept separate from primary label assignment.
  # Local STRING enrichment + marker overlap remain the primary reproducible layer.
  online_gprofiler_collapsed <- collapse_gprofiler_module_enrichment(module_enrichment_gprofiler, n_terms = 6L)
  online_string_collapsed <- collapse_string_online_module_enrichment(module_enrichment_string_online, n_terms = 6L)

  online_validation_summary <- major_module_summary_readable %>%
    select(
      major_module_rank, community_louvain, final_functional_label,
      final_label_raw, specific_label_candidate_raw, label_source,
      label_evidence_score, label_confidence, label_warning,
      top_interpretable_terms, best_interpretable_fdr
    ) %>%
    left_join(online_string_collapsed, by = "community_louvain") %>%
    left_join(online_gprofiler_collapsed, by = "community_louvain") %>%
    mutate(
      online_validation_mode = enrichment_mode,
      online_validation_requested = run_online_enrichment,
      online_validation_terms = mapply(
        function(a, b) {
          vals <- c(a, b)
          vals <- vals[!is.na(vals) & nzchar(vals)]
          if (!length(vals)) "not_available" else paste(unique(vals), collapse = " | ")
        },
        online_STRING_terms,
        online_gprofiler_terms,
        USE.NAMES = FALSE
      ),
      online_validation_status = mapply(
        online_concordance_status,
        specific_label_candidate_raw,
        online_validation_terms,
        USE.NAMES = FALSE
      ),
      online_validation_interpretation = case_when(
        !isTRUE(run_online_enrichment) ~
          "Online validation was not requested. Primary annotation uses local STRING enrichment and curated marker overlap.",
        online_validation_status == "online_not_run_or_no_terms" ~
          "Online validation was requested but did not return usable module-level terms. Primary local STRING/marker annotation remains in use.",
        online_validation_status == "online_terms_concordant_with_assigned_label" ~
          "Online enrichment terms are concordant with the assigned label rule and can be used as an independent validation layer.",
        TRUE ~
          "Online enrichment terms were retrieved but did not clearly match the assigned label rule; keep the local evidence-based label and review raw online terms manually."
      )
    ) %>%
    select(
      major_module_rank, community_louvain, final_functional_label,
      label_source, label_evidence_score, label_confidence, label_warning,
      top_interpretable_terms, best_interpretable_fdr,
      online_validation_mode, online_validation_requested,
      online_validation_status, online_validation_interpretation,
      online_STRING_terms, online_STRING_sources, online_STRING_best_fdr,
      online_gprofiler_terms, online_gprofiler_sources, online_gprofiler_best_p,
      online_validation_terms
    )

  # Node-level readable evidence --------------------------------------------------
  node_metrics_readable <- node_metrics %>%
    left_join(
      module_summary_readable %>%
        select(
          community_louvain,
          module_rank,
          final_functional_label,
          putative_biological_program,
          specific_label_candidate,
          fallback_label,
          label_assignment_mode,
          label_source,
          label_evidence_score,
          label_confidence,
          label_warning,
          supporting_biological_themes,
          marker_label_evidence_count,
          term_label_evidence_count,
          required_specific_evidence_detected,
          marker_max_overlap_count,
          top_interpretable_terms,
          top_interpretable_sources,
          best_interpretable_fdr,
          top_raw_terms,
          database_evidence_summary,
          biological_direction_rationale
        ),
      by = "community_louvain"
    )

  candidate_evidence_matrix <- node_metrics_readable %>%
    mutate(
      candidate_rank = rank_desc(candidate_score),
      degree_rank = rank_desc(degree),
      betweenness_rank = rank_desc(betweenness),
      stress_rank = rank_desc(stress_centrality),
      abs_logFC_rank = rank_desc(abs_logFC),
      statistical_evidence_rank = rank_desc(neg_log10_pvalue),
      in_top10_candidate_score = candidate_rank <= 10L,
      in_top10_degree = degree_rank <= 10L,
      in_top10_betweenness = betweenness_rank <= 10L,
      in_top10_stress = stress_rank <= 10L,
      degree_level = evidence_level(degree),
      betweenness_level = evidence_level(betweenness),
      stress_level = evidence_level(log1p(stress_centrality)),
      expression_change_level = evidence_level(abs_logFC),
      statistical_evidence_level = evidence_level(neg_log10_pvalue),
      priority_class = case_when(
        candidate_rank <= 10L ~ "priority_candidate_top10_by_composite_score",
        candidate_rank <= top_n ~ "extended_candidate_topN_by_composite_score",
        in_top10_degree | in_top10_betweenness | in_top10_stress ~ "topological_support_candidate",
        TRUE ~ "network_background_protein"
      ),
      topology_support_summary = paste0(
        "degree rank ", degree_rank, " (", degree_level, "); ",
        "betweenness rank ", betweenness_rank, " (", betweenness_level, "); ",
        "stress rank ", stress_rank, " (", stress_level, ")"
      ),
      expression_support_summary = paste0(
        "logFC=", signif(logFC, 4L),
        "; |logFC| rank ", abs_logFC_rank, " (", expression_change_level, "); ",
        "p=", signif(pvalue, 4L),
        "; -log10(p) rank ", statistical_evidence_rank, " (", statistical_evidence_level, ")"
      ),
      protein_to_direction_basis = paste0(
        "The protein is assigned to this biological context through Louvain module membership. ",
        "The module label is supported by: ", label_source,
        "; evidence_score=", label_evidence_score,
        "; confidence: ", label_confidence,
        "; warning: ", label_warning, "."
      ),
      candidate_rationale = paste0(
        gene, " belongs to the ", final_functional_label,
        " putative program. Composite candidate rank: ", candidate_rank,
        "; topology evidence: ", topology_support_summary,
        "; expression/statistical evidence: ", expression_support_summary,
        ". ", protein_to_direction_basis,
        " Specific module terms: ", ifelse(is.na(top_interpretable_terms) | !nzchar(top_interpretable_terms), "not available", top_interpretable_terms),
        ". Supporting biological themes: ", supporting_biological_themes,
        ". Marker support: ", ifelse(is.na(marker_based_direction) | !nzchar(marker_based_direction), "not detected", marker_based_direction), "."
      ),
      candidate_rationale = truncate_text(candidate_rationale, 1400L)
    ) %>%
    arrange(candidate_rank, degree_rank, betweenness_rank) %>%
    select(
      candidate_rank,
      gene,
      STRING_id,
      priority_class,
      candidate_score,
      in_top10_candidate_score,
      in_top10_degree,
      in_top10_betweenness,
      in_top10_stress,
      degree, degree_rank, degree_level,
      betweenness, betweenness_rank, betweenness_level,
      stress_centrality, stress_rank, stress_level,
      logFC, abs_logFC, abs_logFC_rank, expression_change_level,
      pvalue, neg_log10_pvalue, statistical_evidence_rank, statistical_evidence_level,
      component, in_largest_component,
      community_louvain, module_rank,
      final_functional_label, specific_label_candidate, fallback_label, label_assignment_mode,
      label_source, label_evidence_score, label_confidence, label_warning,
      supporting_biological_themes,
      marker_label_evidence_count, term_label_evidence_count, required_specific_evidence_detected,
      top_interpretable_terms, best_interpretable_fdr, top_raw_terms,
      marker_based_direction, marker_evidence_genes,
      protein_to_direction_basis,
      topology_support_summary, expression_support_summary, candidate_rationale
    )

  top_candidates_readable <- candidate_evidence_matrix %>%
    filter(candidate_rank <= top_n) %>%
    select(
      candidate_rank, gene, STRING_id, candidate_score, priority_class,
      final_functional_label, specific_label_candidate, fallback_label, label_assignment_mode,
      label_source, label_evidence_score, label_confidence, label_warning,
      supporting_biological_themes,
      degree, degree_rank, betweenness, betweenness_rank, stress_centrality, stress_rank,
      logFC, pvalue, topology_support_summary, expression_support_summary,
      top_interpretable_terms, marker_based_direction, candidate_rationale
    )

  # Direction-level summary -------------------------------------------------------
  priority_directions <- major_module_summary_readable %>%
    transmute(
      direction_rank = major_module_rank,
      louvain_module_id = community_louvain,
      putative_biological_program = final_functional_label,
      module_size,
      module_fraction_of_network = round(module_size / igraph::gorder(ppi), 4L),
      dominant_expression_direction,
      top_candidate,
      top_genes_by_candidate_score,
      top_genes_by_degree,
      top_genes_by_betweenness,
      marker_overlap_summary = marker_based_direction,
      marker_support_genes = marker_evidence_genes,
      marker_max_overlap_count,
      supporting_biological_themes,
      top_interpretable_terms,
      top_interpretable_sources,
      best_interpretable_fdr,
      top_raw_terms,
      specific_label_candidate,
      fallback_label,
      label_assignment_mode,
      label_source,
      label_evidence_score,
      label_confidence,
      label_warning,
      marker_label_evidence_count,
      term_label_evidence_count,
      required_specific_evidence_detected,
      biological_direction_rationale
    )

  final_priorities <- bind_rows(
    priority_directions %>%
      transmute(
        priority_type = "biological_direction",
        priority_rank = direction_rank,
        priority_name = putative_biological_program,
        associated_module = as.character(louvain_module_id),
        lead_proteins = top_genes_by_candidate_score,
        evidence_basis = paste0(
          "module_size=", module_size,
          "; best_specific_enrichment_FDR=", ifelse(is.finite(best_interpretable_fdr), signif(best_interpretable_fdr, 4L), "not_available"),
          "; label_source=", label_source,
          "; label_evidence_score=", label_evidence_score,
          "; label_confidence=", label_confidence,
          "; label_warning=", label_warning,
          "; supporting_themes=", supporting_biological_themes,
          "; marker_support=", marker_overlap_summary
        ),
        interpretation = biological_direction_rationale
      ),
    top_candidates_readable %>%
      filter(candidate_rank <= min(10L, top_n)) %>%
      transmute(
        priority_type = "protein_candidate",
        priority_rank = candidate_rank,
        priority_name = gene,
        associated_module = as.character(final_functional_label),
        lead_proteins = gene,
        evidence_basis = paste0(
          "candidate_score=", signif(candidate_score, 4L),
          "; degree_rank=", degree_rank,
          "; betweenness_rank=", betweenness_rank,
          "; stress_rank=", stress_rank,
          "; label_source=", label_source,
          "; label_evidence_score=", label_evidence_score,
          "; label_confidence=", label_confidence,
          "; label_warning=", label_warning
        ),
        interpretation = candidate_rationale
      )
  ) %>%
    mutate(
      evidence_basis = truncate_text(evidence_basis, 800L),
      interpretation = truncate_text(interpretation, 1400L)
    )

  # Analytical overview sheets ----------------------------------------------------

  report_readme <- tibble(
    section = c(
      "Purpose",
      "How to read this workbook",
      "Candidate selection logic",
      "Functional direction logic",
      "Generic-term filtering",
      "Enrichment mode",
      "Important limitation",
      "Recommended first sheets"
    ),
    description = c(
      "This workbook is the main human-readable CancerPPIr analytical report. It summarizes the reconstructed patient-specific STRING-derived PPI subnetwork, candidate proteins, Louvain modules and putative biological programs.",
      "Start with Executive summary, Final priorities, Major module priorities and Candidate rationale. Raw enrichment, mapping audit and all unfiltered database terms are kept in the technical workbook.",
      "Candidate proteins are prioritized by a composite exploratory score integrating normalized degree, betweenness, log-transformed stress centrality, absolute logFC and -log10(p-value). Topology alone is not interpreted as therapeutic efficacy.",
      "Biological directions are assigned as putative module labels using curated marker-gene overlap and statistically enriched local STRING/database terms. The label_source, label_confidence, marker_support and top_interpretable_terms columns show why a label was assigned.",
      "Broad terms such as Signaling, Signal transduction and Cell communication are not used as primary biological evidence in the analytical report. They remain available in the technical workbook for audit.",
      "CancerPPIr is running in offline-only reproducible mode. Functional annotation uses locally cached STRING enrichment terms and curated marker-gene overlap; online STRING/g:Profiler validation is not used in this version.",
      "STRING-derived PPI subnetworks are not tumor-cell-specific physical interaction measurements. Bulk RNA-seq may include tumor cells, immune infiltrate, stroma and other microenvironmental components.",
      "Executive summary; Final priorities; Major module priorities; Candidate rationale; Top candidates; Graph summary."
    )
  )

  annotation_evidence_rules <- tibble(
    rule = c(
      "Module structure",
      "Curated marker evidence",
      "STRING/database evidence",
      "Explicit label rulebook",
      "Specific label versus fallback label",
      "Label evidence score",
      "Label warning",
      "Supporting biological themes",
      "Offline enrichment policy",
      "Generic-term filter",
      "High confidence label",
      "Medium confidence label",
      "Low confidence label",
      "Protein-to-direction link"
    ),
    meaning = c(
      "Proteins are first grouped by Louvain community detection on the STRING-derived PPI graph.",
      "A module gains marker support when its genes overlap with curated marker sets defined in the workflow, such as antigen presentation, chemokine/cytokine, myeloid/macrophage, complement/C1q, T-cell cytotoxicity, ECM/stromal remodeling, cell-cycle or interferon response sets.",
      "A module gains database support when its proteins are significantly enriched for local STRING annotation terms derived from open resources such as GO, Reactome, KEGG, WikiPathways, UniProt keywords and STRING local clusters.",
      "Each functional label is assigned only if it matches an explicit rule containing allowed marker patterns, allowed STRING/database term patterns and required specific evidence patterns.",
      "A precise label is used only when required specific evidence is present or marker support is strong. Otherwise CancerPPIr downgrades to a broader fallback label and records this in label_warning.",
      "The score integrates marker support, specific term support, required specific evidence, FDR strength, module size and marker-term concordance. It is an interpretability score for the module label, not a clinical efficacy score.",
      "Warnings flag cases such as STRING-only label assignment, marker-only assignment, weak score or fallback-label downgrading due to missing required specific evidence.",
      "supporting_biological_themes is intentionally conservative: it always prioritizes the assigned label theme and adds only secondary themes with stronger marker/term evidence, reducing broad cross-label spillover.",
      "Online enrichment is not used in this offline-only version. All reported functional annotations come from local STRING enrichment terms and curated marker-gene overlap.",
      "Generic terms are excluded from the main rationale unless they contain specific biological context. Raw terms are preserved in the technical workbook.",
      "Assigned when a sufficiently large module has strong marker overlap, significant specific STRING/database enrichment and high label evidence score.",
      "Assigned when one evidence layer is strong, or when evidence is useful but not fully concordant.",
      "Assigned when the module is small, unassigned, or lacks specific marker/enrichment support.",
      "An individual protein inherits biological context through its Louvain module membership; this does not prove that the protein causally drives that program."
    )
  )

  executive_summary <- tibble(
    item = c(
      "input_rows",
      "final_mapped_genes",
      "final_unmapped_genes",
      "network_nodes",
      "network_edges",
      "annotation_mode",
      "connected_components",
      "largest_component_nodes",
      "louvain_modules",
      "STRING_score_threshold",
      "top_10_candidate_proteins",
      "major_putative_biological_programs"
    ),
    value = c(
      as.character(nrow(input_tbl)),
      as.character(after_mapped),
      as.character(after_unmapped),
      metric_value(graph_summary, "nodes"),
      metric_value(graph_summary, "edges"),
      "offline_only_local_STRING_plus_curated_marker_overlap",
      metric_value(graph_summary, "components"),
      metric_value(graph_summary, "largest_component_nodes"),
      metric_value(graph_summary, "louvain_communities"),
      as.character(score_threshold),
      paste(head(top_candidates$gene, 10L), collapse = "; "),
      paste(priority_directions$putative_biological_program, collapse = "; ")
    ),
    interpretation = c(
      "Number of input rows in the RNA-seq-derived gene table.",
      "Genes/proteins successfully mapped to STRING before final graph construction.",
      "Input genes not represented in the final STRING-derived protein network.",
      "Number of proteins in the reconstructed PPI subnetwork.",
      "Number of STRING associations retained after thresholding and graph simplification.",
      "CancerPPIr was run in offline-only mode using locally cached STRING enrichment terms and curated marker-gene overlap.",
      "Number of disconnected graph components.",
      "Size of the largest connected component; many topology metrics are most stable inside this component.",
      "Number of Louvain communities/modules detected in the graph.",
      "Minimum STRING confidence score used for network construction.",
      "Highest-ranked proteins by the composite exploratory candidate score.",
      "Major module-level functional directions supported by marker overlap and/or specific STRING/database enrichment."
    )
  )

  network_overview <- graph_summary %>%
    mutate(
      explanation = case_when(
        metric == "nodes" ~ "Proteins represented as graph nodes.",
        metric == "edges" ~ "STRING associations represented as graph edges.",
        metric == "components" ~ "Disconnected parts of the graph.",
        metric == "largest_component_nodes" ~ "Number of nodes in the largest connected component.",
        metric == "largest_component_fraction" ~ "Fraction of all nodes located in the largest connected component.",
        metric == "density" ~ "Fraction of possible edges that are present.",
        metric == "average_degree" ~ "Average number of interactions per protein.",
        metric == "global_clustering" ~ "Overall tendency of neighboring proteins to form triangles.",
        metric == "average_shortest_path_lcc" ~ "Mean shortest-path length inside the largest connected component.",
        metric == "diameter_lcc" ~ "Longest shortest path inside the largest connected component.",
        metric == "radius_lcc" ~ "Minimum eccentricity inside the largest connected component.",
        metric == "louvain_communities" ~ "Number of modules detected by Louvain community detection.",
        metric == "louvain_modularity" ~ "Modularity score of Louvain partition.",
        metric == "string_score_threshold" ~ "STRING confidence threshold used to keep edges.",
        TRUE ~ "Network-level summary metric."
      )
    )

  glossary <- tibble(
    term = c(
      "candidate_score",
      "degree",
      "betweenness",
      "stress_centrality",
      "Louvain module",
      "functional enrichment",
      "FDR",
      "marker_overlap",
      "specific_interpretable_term",
      "label_rulebook",
      "specific_label_candidate",
      "fallback_label",
      "final_functional_label",
      "supporting_biological_themes",
      "label_source",
      "label_evidence_score",
      "label_confidence",
      "label_warning",
      "putative_biological_program"
    ),
    meaning = c(
      "Exploratory composite score averaging normalized topology and expression/statistical evidence.",
      "Number of network edges connected to a protein; high values indicate hub-like topology.",
      "Fraction of shortest paths passing through a protein; high values indicate bridge-like topology.",
      "Absolute number of shortest paths passing through a protein; log-transformed before scoring.",
      "Community of densely connected proteins detected by Louvain modularity optimization.",
      "Statistical test for biological terms over-represented in a gene/protein set compared with a background.",
      "False discovery rate after multiple-testing correction.",
      "Overlap between module genes and curated marker sets defined in the workflow.",
      "A database/enrichment term that is sufficiently specific for human-readable biological interpretation; generic terms are retained only in the technical workbook.",
      "Explicit rule set that constrains which labels may be assigned from marker and STRING/database evidence.",
      "Most specific label suggested by the rulebook before fallback checks.",
      "Broader label used when the evidence is real but insufficient for the more specific label.",
      "Final conservative module label after rulebook scoring and fallback checks.",
      "Additional biological themes detected from markers and STRING/database terms; these themes support interpretation but do not automatically become the final label.",
      "Evidence source used to assign a module label: marker overlap, specific STRING enrichment, both, or none.",
      "Rule-based score integrating marker support, specific terms, required evidence, FDR strength, module size and marker-term concordance for label assignment.",
      "Qualitative confidence level derived from label_evidence_score and evidence type.",
      "Audit flag for potentially weak, STRING-only, marker-only, or fallback-downgraded label assignments.",
      "Human-readable computational label for the biological context of a module; not a direct experimental proof."
    )
  )

  caveats <- tibble(
    caveat = c(
      "Exploratory prioritization",
      "Bulk RNA-seq composition",
      "STRING database bias",
      "Module labels are putative",
      "Generic enrichment terms",
      "Therapeutic interpretation requires validation"
    ),
    explanation = c(
      "Candidate ranking is designed to prioritize proteins for follow-up, not to prove clinical actionability.",
      "Bulk tumor profiles can represent malignant cells, immune cells, stromal cells, endothelial cells and other components.",
      "STRING integrates known and predicted associations and is affected by literature and database coverage biases.",
      "Functional labels are assigned from marker overlap and enrichment terms and should be read as computational annotations.",
      "Very broad database terms are not used as primary biological evidence in the analytical report; they are preserved in the technical workbook for audit.",
      "Drug target selection requires independent biological, clinical and pharmacological validation."
    )
  )

  # Main analytical workbook ------------------------------------------------------
  analytical_sheets <- list( 
  "Executive summary" = executive_summary,
    "Final priorities" = final_priorities,
    "Major module priorities" = priority_directions,
    "Candidate rationale" = candidate_evidence_matrix,
    "Top candidates" = top_candidates_readable,
    "Graph summary" = network_overview,
    "All modules" = module_summary_readable,
    "Top degree" = top_by_degree,
    "Top betweenness" = top_by_betweenness,
    "Top stress" = top_by_stress,
    "Degree distribution" = degree_distribution
  )

  write_readable_xlsx(
    file.path(output_dir, "CancerPPIr_Analytical_Report.xlsx"),
    analytical_sheets
  )

  # Technical workbook: raw tables for reproducibility and audit ------------------
  # Raw enrichment tables are intentionally unfiltered here.
  technical_sheets <- list(
    "Mapping summary" = mapping_summary,
    "Gene status" = gene_status,
    "Alias corrections" = alias_corrections,
    "Unmapped genes" = still_unmapped,
    "HGNC normalization" = hgnc_map,
    "Genes used table" = mapped_final,
    "Raw node metrics" = node_metrics_readable,
    "Raw all modules" = module_summary_readable,
    "Raw major modules" = major_module_summary_readable,
    "Top module enrichment" = select_top_enrichment(module_enrichment_string_local, group_cols = "community_louvain", n_per_group = 10L, specific_only = TRUE),
    "Top network enrichment" = select_top_enrichment(enrichment_string_local_all, n_per_group = 25L, specific_only = TRUE),
    "Top candidate enrichment" = select_top_enrichment(enrichment_string_local_top, n_per_group = 25L, specific_only = TRUE),
    "Raw module enrichment" = module_enrichment_string_local,
    "Raw network enrichment" = enrichment_string_local_all,
    "Raw candidate enrichment" = enrichment_string_local_top,
    "Session info" = tibble(line = capture.output(sessionInfo()))
  )

  write_readable_xlsx(
    file.path(output_dir, "CancerPPIr_Technical_Report.xlsx"),
    technical_sheets
  )

  # STRING links ------------------------------------------------------------------
  links <- make_string_links(mapped_final$STRING_id, score_threshold)
  writeLines(
    c(
      "STRING network links",
      "These links use the first up to 300 STRING protein IDs to avoid browser URL-length limits.",
      paste("current:", links[["current"]]),
      paste("pinned_v12:", links[["pinned_v12"]])
    ),
    file.path(output_dir, "STRING_links.txt")
  )

  # Cytoscape/Gephi network -------------------------------------------------------
  # Attach readable node attributes before writing GraphML. Cytoscape can use
  # final_functional_label / community_louvain for module coloring and
  # candidate_score / degree / betweenness for node sizing or ranking.
  cytoscape_node_attributes <- node_metrics_readable %>%
    mutate(
      louvain_module_id = community_louvain,
      cytoscape_label = gene,
      cytoscape_module_label = final_functional_label,
      cytoscape_priority_class = candidate_evidence_matrix$priority_class[
        match(STRING_id, candidate_evidence_matrix$STRING_id)
      ]
    )

  for (col in setdiff(names(cytoscape_node_attributes), "STRING_id")) {
    values <- cytoscape_node_attributes[[col]][match(igraph::V(ppi)$name, cytoscape_node_attributes$STRING_id)]
    ppi <- igraph::set_vertex_attr(ppi, col, value = values)
  }

  igraph::write_graph(
    ppi,
    file.path(output_dir, "Network_for_Cytoscape.graphml"),
    format = "graphml"
  )

  msg("Done.")
  msg("Output directory: ", normalizePath(output_dir))
  msg("Mapped genes: ", after_mapped, "/", after_total, " (", after_pct, "%)")
  msg("Network: ", igraph::gorder(ppi), " nodes, ", igraph::gsize(ppi), " edges, ", comp$no, " components")
  msg("Main files: CancerPPIr_Analytical_Report.xlsx, CancerPPIr_Technical_Report.xlsx, STRING_links.txt, Network_for_Cytoscape.graphml")

  invisible(list(
    output_dir = output_dir,
    graph = ppi,
    node_metrics = node_metrics_readable,
    module_summary = module_summary_readable,
    candidate_evidence_matrix = candidate_evidence_matrix,
    priority_directions = priority_directions,
    final_priorities = final_priorities,
    graph_summary = graph_summary,
    mapping_summary = mapping_summary,
    files = c(
      analytical_report = file.path(output_dir, "CancerPPIr_Analytical_Report.xlsx"),
      technical_report = file.path(output_dir, "CancerPPIr_Technical_Report.xlsx"),
      string_links = file.path(output_dir, "STRING_links.txt"),
      graphml = file.path(output_dir, "Network_for_Cytoscape.graphml")
    )
  ))
}
