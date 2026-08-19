# CancerPPIr: Pipeline orchestration
#
# Responsibility: End-to-end CancerPPIr workflow coordination with explicit inputs and returned analysis objects.
#
#


# -----------------------------------------------------------------------------
# End-to-end CancerPPIr workflow
# -----------------------------------------------------------------------------

cancerppir_assert_output_target_available <- function(
  final_output_dir
) {
  if (
    file.exists(final_output_dir) &&
      !dir.exists(final_output_dir)
  ) {
    stop(
      "Output path exists and is not a directory: ",
      final_output_dir,
      call. = FALSE
    )
  }

  if (dir.exists(final_output_dir)) {
    stop(
      paste0(
        "Output directory already exists: ",
        final_output_dir,
        "\nCancerPPIr does not overwrite or mix existing results. ",
        "Move the existing directory or choose a different results root."
      ),
      call. = FALSE
    )
  }

  invisible(final_output_dir)
}

cancerppir_prepare_output_staging <- function(
  final_output_dir
) {
  cancerppir_assert_output_target_available(
    final_output_dir
  )

  output_parent <- dirname(final_output_dir)

  if (!dir.exists(output_parent)) {
    created <- dir.create(
      output_parent,
      recursive = TRUE,
      showWarnings = FALSE
    )

    if (!isTRUE(created) && !dir.exists(output_parent)) {
      stop(
        "Could not create output parent directory: ",
        output_parent,
        call. = FALSE
      )
    }
  }

  staging_output_dir <- tempfile(
    pattern = paste0(
      ".",
      basename(final_output_dir),
      ".cancerppir-staging-"
    ),
    tmpdir = output_parent
  )

  created <- dir.create(
    staging_output_dir,
    recursive = FALSE,
    showWarnings = FALSE
  )

  if (!isTRUE(created) || !dir.exists(staging_output_dir)) {
    stop(
      "Could not create staging output directory: ",
      staging_output_dir,
      call. = FALSE
    )
  }

  list(
    final_output_dir = final_output_dir,
    staging_output_dir = staging_output_dir
  )
}

cancerppir_publish_output_staging <- function(
  staging_output_dir,
  final_output_dir
) {
  if (!dir.exists(staging_output_dir)) {
    stop(
      "Staging output directory does not exist: ",
      staging_output_dir,
      call. = FALSE
    )
  }

  if (dir.exists(final_output_dir)) {
    stop(
      "Final output directory appeared before publication: ",
      final_output_dir,
      call. = FALSE
    )
  }

  if (file.exists(final_output_dir)) {
    stop(
      "Final output path appeared before publication: ",
      final_output_dir,
      call. = FALSE
    )
  }

  published <- file.rename(
    staging_output_dir,
    final_output_dir
  )

  if (!isTRUE(published) || !dir.exists(final_output_dir)) {
    stop(
      "Could not atomically publish the completed output directory: ",
      final_output_dir,
      call. = FALSE
    )
  }

  invisible(final_output_dir)
}

run_cancerppir <- function(
  input_file,
  results_root,
  cache_dir,
  score_threshold = 400L,
  top_n = 30L,
  run_enrichment = TRUE,
  case_id = NULL
) {
  previous_progress_start <- getOption(
    "cancerppir.progress_started_at",
    default = NULL
  )

  options(
    cancerppir.progress_started_at = Sys.time()
  )

  on.exit(
    options(
      cancerppir.progress_started_at =
        previous_progress_start
    ),
    add = TRUE
  )

  if (!file.exists(input_file)) {
    stop("Input file not found: ", input_file, call. = FALSE)
  }

  if (dir.exists(input_file)) {
    stop("input_file is a directory: ", input_file, call. = FALSE)
  }

  if (file.exists(results_root) && !dir.exists(results_root)) {
    stop(
      "results_root exists and is not a directory: ",
      results_root,
      call. = FALSE
    )
  }

  if (file.exists(cache_dir) && !dir.exists(cache_dir)) {
    stop(
      "cache_dir exists and is not a directory: ",
      cache_dir,
      call. = FALSE
    )
  }

  case_identity <- cancerppir_resolve_case_id(
    input_file = input_file,
    case_id = case_id
  )

  case_id <- case_identity$value
  case_id_source <- case_identity$source

  final_output_dir <- cancerppir_resolve_output_directory(
    results_root = results_root,
    case_id = case_id,
    preserve_legacy_variant_redirect = identical(
      case_id_source,
      "legacy_input_basename"
    )
  )

  msg(
    "Case ID: ",
    case_id,
    " (",
    case_id_source,
    ")."
  )
  msg("Planned output directory: ", final_output_dir)

  if (identical(case_id_source, "legacy_input_basename")) {
    msg(
      paste(
        "No explicit case_id was supplied; the output folder is derived",
        "from the input basename. Use a pseudonymous case_id for patient data."
      )
    )
  }

  cancerppir_assert_output_target_available(
    final_output_dir
  )

  required_cran <- c(
    "HGNChelper", "igraph", "openxlsx", "dplyr", "tibble", "curl", "sna",
    "jsonlite", "digest"
  )
  required_bioc <- c("STRINGdb")


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

  enrichment_mode <- "local_STRING_cache"

  score_threshold_numeric <- suppressWarnings(as.numeric(score_threshold))
  if (
    length(score_threshold_numeric) != 1L ||
      is.na(score_threshold_numeric) ||
      !is.finite(score_threshold_numeric) ||
      score_threshold_numeric != floor(score_threshold_numeric) ||
      score_threshold_numeric < 1 ||
      score_threshold_numeric > 1000
  ) {
    stop(
      "score_threshold must be an integer from 1 to 1000.",
      call. = FALSE
    )
  }
  score_threshold <- as.integer(score_threshold_numeric)

  top_n_numeric <- suppressWarnings(as.numeric(top_n))
  if (
    length(top_n_numeric) != 1L ||
      is.na(top_n_numeric) ||
      !is.finite(top_n_numeric) ||
      top_n_numeric != floor(top_n_numeric) ||
      top_n_numeric < 1
  ) {
    stop("top_n must be a positive integer.", call. = FALSE)
  }
  top_n <- as.integer(top_n_numeric)

  if (
    length(run_enrichment) != 1L ||
      is.na(run_enrichment) ||
      !is.logical(run_enrichment)
  ) {
    stop("run_enrichment must be TRUE or FALSE.", call. = FALSE)
  }

  dir.create(cache_dir, showWarnings = FALSE, recursive = TRUE)

  output_paths <- cancerppir_prepare_output_staging(
    final_output_dir
  )

  output_dir <- output_paths$staging_output_dir
  output_published <- FALSE

  on.exit(
    {
      if (
        !isTRUE(output_published) &&
          dir.exists(output_dir)
      ) {
        unlink(
          output_dir,
          recursive = TRUE,
          force = TRUE
        )
      }
    },
    add = TRUE
  )

  options(timeout = max(600, getOption("timeout", 60)))
  Sys.setenv(R_DEFAULT_INTERNET_TIMEOUT = "600")

  ca_bundle <- tryCatch(curl::ca_bundle(), error = function(e) "")
  if (nzchar(ca_bundle)) {
    Sys.setenv(CURL_CA_BUNDLE = ca_bundle)
    Sys.setenv(SSL_CERT_FILE = ca_bundle)
  }


  msg("Stage 1/8: reading and validating the input table.")
  input_tbl <- read_gene_table(input_file)
  input_contract <- attr(
    input_tbl,
    "cancerppir_input_contract",
    exact = TRUE
  )

  if (!is.list(input_contract)) {
    stop(
      "Internal error: validated input contract metadata are missing.",
      call. = FALSE
    )
  }

  msg("Stage 2/8: normalizing HGNC gene symbols.")
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

  msg("Stage 3/8: preparing pinned STRING v12 resources.")
  string_db <- create_offline_stringdb(
    cache_dir = cache_dir,
    score_threshold = score_threshold,
    species = 9606L,
    version = "12.0",
    network_type = "full",
    link_data = "combined_only"
  )

  msg("Stage 4/8: mapping genes to STRING identifiers.")
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

  string_mapping_resolution <-
    resolve_string_mapping_collisions(mapped_final_raw)

  mapped_final <- string_mapping_resolution$mapped

  if (nrow(mapped_final) < 2) {
    stop("Fewer than two unique STRING identifiers were mapped.", call. = FALSE)
  }

  after_total <- nrow(mapped_final_raw)
  after_mapped <- sum(!is.na(mapped_final_raw$STRING_id))
  after_unmapped <- after_total - after_mapped
  after_pct <- round(100 * after_mapped / after_total, 1)

  msg("Stage 5/8: reconstructing and measuring the PPI network.")

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
    string_mapping_collision_proteins =
      string_mapping_resolution$collision_proteins,
    string_mapping_collision_rows_dropped =
      string_mapping_resolution$dropped_rows,
    string_mapping_collision_policy =
      string_mapping_resolution$policy,
    score_threshold = score_threshold,
    top_n = top_n
  )

  ppi <- network_analysis$ppi
  comp <- network_analysis$comp
  node_metrics <- network_analysis$node_metrics
  top_n <- network_analysis$top_n
  top_candidates <- network_analysis$top_candidates
  degree_distribution <- network_analysis$degree_distribution
  module_summary <- network_analysis$module_summary
  major_module_ids <- network_analysis$major_module_ids
  graph_summary <- network_analysis$graph_summary
  mapping_summary <- bind_rows(
    network_analysis$mapping_summary,
    input_contract_mapping_rows(input_contract)
  )
  gene_status <- network_analysis$gene_status
  still_unmapped <- network_analysis$still_unmapped

  rm(network_analysis)


  enrichment_string_local_all <- tibble()
  enrichment_string_local_top <- tibble()
  module_enrichment_string_local <- tibble()
  local_string_terms <- tibble()

  msg(
    "Stage 6/8: computing functional enrichment and biological evidence."
  )

  if (isTRUE(run_enrichment)) {
    msg("Running local functional enrichment.")
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

  msg("Constructing biological evidence tables.")

  # Canonical biological evidence layer -----------------------------------
  # Significant, non-generic local STRING terms drive canonical interpretation.
  # Marker-rule assignments remain auxiliary technical evidence.
  msg("Running canonical biological evidence annotation.")

  biological_evidence <- bind_pipeline_evidence(
    node_metrics = node_metrics,
    module_enrichment = module_enrichment_string_local,
    fdr_threshold = 0.05
  )

  biological_evidence_validation_failures <-
    biological_evidence$validation %>%
    filter(status == "FAIL")

  if (nrow(biological_evidence_validation_failures) > 0L) {
    failed_checks <- paste(
      biological_evidence_validation_failures$check_id,
      collapse = ", "
    )

    stop(
      paste0(
        "Canonical biological evidence validation failed: ",
        failed_checks,
        "."
      ),
      call. = FALSE
    )
  }

  msg(
    "Canonical biological annotation: ",
    nrow(biological_evidence$module_annotations),
    " modules; ",
    sum(
      biological_evidence$module_annotations$priority_eligible,
      na.rm = TRUE
    ),
    " priority-eligible; ",
    sum(
      biological_evidence$module_annotations$
        interpretation_class == "unresolved",
      na.rm = TRUE
    ),
    " unresolved."
  )

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

  # Main analytical workbook ------------------------------------------------------
  # The concise six-sheet workbook is built only from the deterministic CancerPPIr
  # evidence objects. Complete pre-canonical/raw tables remain in the technical workbook.
  msg("Stage 7/8: writing and validating reports and GraphML.")

  analytical_report <- build_analytical_workbook(
    input_rows = nrow(input_tbl),
    mapped_proteins = nrow(mapped_final),
    unmapped_input_rows = after_unmapped,
    mapping_rate_percent = after_pct,
    graph_summary = graph_summary,
    score_threshold = score_threshold,
    top_n = top_n,
    degree_distribution = degree_distribution,
    biological_evidence = biological_evidence,
    string_version = "12.0",
    louvain_seed = CANCERPPIR_LOUVAIN_SEED,
    fdr_threshold = 0.05,
    run_enrichment = run_enrichment
  )

  analytical_sheets <- analytical_report$sheets

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
    "Module annotations" = biological_evidence$module_annotations,
    "Rule evidence" = biological_evidence$module_rule_evidence,
    "Significant terms" = biological_evidence$significant_module_terms,
    "Node annotations" = biological_evidence$node_annotations,
    "Validation" = biological_evidence$validation,
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
      "These are convenience browser views; Network_for_Cytoscape.graphml contains the complete reconstructed network.",
      paste("current:", links[["current"]]),
      "  Opens the protein set in the current STRING web interface; displayed content may change when STRING is updated.",
      "",
      paste("pinned_v12:", links[["pinned_v12"]]),
      "  Opens the protein set in STRING v12.0, matching the database version pinned by CancerPPIr.",
      "  Prefer this link for version-consistent STRING inspection of the reported analysis."
    ),
    file.path(output_dir, "STRING_links.txt")
  )

  # Cytoscape/Gephi network -------------------------------------------------------
  # GraphML uses the explicit canonical CancerPPIr evidence schema. Deprecated label
  # fields remain available only in compatibility tables and are deliberately
  # excluded from the graph contract.
  canonical_graphml_attributes <-
    build_canonical_graphml_attributes(
      node_annotations = biological_evidence$node_annotations,
      final_priorities = analytical_sheets[[
        "Final priorities"
      ]],
      candidate_evidence = analytical_sheets[[
        "Candidate evidence"
      ]]
    )

  canonical_graphml_validation <-
    validate_canonical_graphml_attributes(
      canonical_graphml_attributes
    )

  stop_on_failed_validation(
    canonical_graphml_validation,
    "Canonical GraphML attributes"
  )

  ppi <- apply_canonical_graphml_attributes(
    graph = ppi,
    attributes = canonical_graphml_attributes
  )

  igraph::write_graph(
    ppi,
    file.path(output_dir, "Network_for_Cytoscape.graphml"),
    format = "graphml"
  )

  # Output provenance ------------------------------------------------------------
  # The manifest records only basenames and non-path metadata. It includes
  # checksums for the four principal outputs. The separate checksum file also
  # authenticates the manifest itself and deliberately omits its own hash.
  msg("Stage 8/8: writing provenance and publishing outputs.")

  primary_output_files <- c(
    analytical_report = file.path(
      output_dir,
      "CancerPPIr_Analytical_Report.xlsx"
    ),
    technical_report = file.path(
      output_dir,
      "CancerPPIr_Technical_Report.xlsx"
    ),
    string_links = file.path(
      output_dir,
      "STRING_links.txt"
    ),
    graphml = file.path(
      output_dir,
      "Network_for_Cytoscape.graphml"
    )
  )

  output_provenance <- cancerppir_write_output_provenance(
    input_file = input_file,
    output_dir = output_dir,
    output_files = primary_output_files,
    output_roles = c(
      analytical_report = "human_readable_analytical_report",
      technical_report = "technical_reproducibility_and_audit_report",
      string_links = "STRING_network_links",
      graphml = "canonical_annotated_network"
    ),
    output_schema_versions =
      cancerppir_output_file_schema_versions(),
    input_summary = list(
      case_id = if (
        identical(case_id_source, "explicit_case_id")
      ) {
        case_id
      } else {
        "not_recorded"
      },
      case_id_source = case_id_source,
      input_rows = nrow(input_tbl),
      normalized_unique_genes = length(unique(input_tbl$gene)),
      mapped_input_rows = after_mapped,
      unmapped_input_rows = after_unmapped,
      unique_mapped_proteins = nrow(mapped_final),
      STRING_mapping_collision_proteins =
        string_mapping_resolution$collision_proteins,
      STRING_mapping_collision_rows_dropped =
        string_mapping_resolution$dropped_rows,
      STRING_mapping_collision_policy =
        string_mapping_resolution$policy,
      successful_alias_corrections = sum(
        alias_corrections$mapped_after,
        na.rm = TRUE
      ),
      zero_pvalue_rows = input_contract$zero_pvalue_rows
    ),
    analysis_configuration = list(
      input_contract = input_contract,
      species_taxonomy_id = 9606L,
      STRING_version = "12.0",
      STRING_score_threshold = as.integer(score_threshold),
      enrichment_mode = enrichment_mode,
      local_enrichment_enabled = isTRUE(run_enrichment),
      online_enrichment_enabled = FALSE,
      Louvain_seed = as.integer(CANCERPPIR_LOUVAIN_SEED),
      FDR_threshold = 0.05,
      candidate_top_n = as.integer(top_n),
      offline_cache = cancerppir_cache_resource_summary(
        cache_dir
      )
    ),
    run_summary = list(
      network_nodes = igraph::gorder(ppi),
      network_edges = igraph::gsize(ppi),
      connected_components = comp$no,
      Louvain_modules = nrow(
        biological_evidence$module_annotations
      ),
      priority_eligible_modules = sum(
        biological_evidence$module_annotations$priority_eligible,
        na.rm = TRUE
      ),
      final_priority_candidates = nrow(
        analytical_sheets[["Final priorities"]]
      )
    ),
    project_root = getOption(
      "cancerppir.project_root",
      default = ""
    ),
    forbidden_paths = c(
      cache_dir,
      results_root
    )
  )

  all_output_files <- c(
    primary_output_files,
    output_manifest = output_provenance$manifest_file,
    output_checksums = output_provenance$checksums_file
  )

  cancerppir_publish_output_staging(
    staging_output_dir = output_dir,
    final_output_dir = final_output_dir
  )

  output_published <- TRUE
  output_dir <- final_output_dir

  all_output_files <- stats::setNames(
    file.path(
      output_dir,
      basename(all_output_files)
    ),
    names(all_output_files)
  )

  output_provenance$manifest_file <- file.path(
    output_dir,
    basename(output_provenance$manifest_file)
  )

  output_provenance$checksums_file <- file.path(
    output_dir,
    basename(output_provenance$checksums_file)
  )

  msg("Done.")
  msg("Case ID: ", case_id)
  msg("Output directory: ", normalizePath(output_dir))
  msg("Mapped genes: ", after_mapped, "/", after_total, " (", after_pct, "%)")
  msg("Network: ", igraph::gorder(ppi), " nodes, ", igraph::gsize(ppi), " edges, ", comp$no, " components")
  msg("Main files: CancerPPIr_Analytical_Report.xlsx, CancerPPIr_Technical_Report.xlsx, STRING_links.txt, Network_for_Cytoscape.graphml, CancerPPIr_Output_Manifest.json, CancerPPIr_Output_Checksums.sha256")

  compatibility_outputs <- list(
    status = "deprecated_compatibility_only",
    migration = build_deprecated_annotation_metadata(),
    legacy_module_summary = module_summary_readable,
    legacy_candidate_evidence_matrix = candidate_evidence_matrix,
    legacy_priority_directions = priority_directions,
    legacy_final_priorities = final_priorities
  )

  invisible(
    build_canonical_pipeline_result(
      output_dir = output_dir,
      graph = ppi,
      biological_evidence = biological_evidence,
      analytical_report_tables = analytical_sheets,
      analytical_report_validation =
        analytical_report$validation,
      graphml_validation = canonical_graphml_validation,
      graph_summary = graph_summary,
      mapping_summary = mapping_summary,
      files = all_output_files,
      compatibility = compatibility_outputs,
      provenance = output_provenance
    )
  )
}
