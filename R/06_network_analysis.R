# CancerPPIr: Network analysis
#
# Responsibility: Graph construction, connected components, centrality metrics, candidate scoring and Louvain communities.
#
# Architecture checkpoint 2.3
#
# This module intentionally contains no extracted legacy functions at this checkpoint.
# Function definitions will be moved here incrementally without semantic rewriting.


# -----------------------------------------------------------------------------
# Network construction, metrics, Louvain modules and candidate prioritization
# Architecture checkpoint 2.11
# -----------------------------------------------------------------------------


# Fixed seed for reproducible Louvain community detection.
#
# igraph processes vertices in a random order during Louvain optimization.
# The seed is therefore part of the analytical method. The wrapper below
# restores the caller's .Random.seed so CancerPPIr does not alter unrelated
# random-number generation in an interactive R session.
CANCERPPIR_LOUVAIN_SEED <- 1729L

with_preserved_random_seed <- function(
  seed,
  code
) {
  if (
    length(seed) != 1L ||
    is.na(seed) ||
    !is.finite(seed) ||
    seed < 0 ||
    seed > .Machine$integer.max
  ) {
    stop(
      paste0(
        "seed must be one finite integer in [0, ",
        .Machine$integer.max,
        "]."
      ),
      call. = FALSE
    )
  }

  seed <- as.integer(seed)

  had_random_seed <- exists(
    ".Random.seed",
    envir = .GlobalEnv,
    inherits = FALSE
  )

  if (had_random_seed) {
    previous_random_seed <- get(
      ".Random.seed",
      envir = .GlobalEnv,
      inherits = FALSE
    )
  }

  on.exit(
    {
      if (had_random_seed) {
        assign(
          ".Random.seed",
          previous_random_seed,
          envir = .GlobalEnv
        )
      } else if (exists(
        ".Random.seed",
        envir = .GlobalEnv,
        inherits = FALSE
      )) {
        rm(
          ".Random.seed",
          envir = .GlobalEnv
        )
      }
    },
    add = TRUE
  )

  set.seed(seed)
  force(code)
}

run_louvain_deterministic <- function(
  graph,
  weights = NA,
  seed = CANCERPPIR_LOUVAIN_SEED
) {
  if (!inherits(graph, "igraph")) {
    stop(
      "graph must be an igraph object.",
      call. = FALSE
    )
  }

  with_preserved_random_seed(
    seed = seed,
    code = igraph::cluster_louvain(
      graph,
      weights = weights
    )
  )
}

run_network_analysis <- function(
  string_db,
  mapped_final,
  input_tbl,
  mapped_initial,
  mapped_final_raw,
  valid_alias_corrections,
  initial_mapped,
  initial_unmapped,
  initial_pct,
  after_mapped,
  after_unmapped,
  after_pct,
  score_threshold,
  top_n
) {
  msg("Building STRING subnetwork.")
  ppi_raw <- string_db$get_subnetwork(unique(mapped_final$STRING_id))

  if (is.null(ppi_raw) || igraph::gorder(ppi_raw) == 0 || igraph::gsize(ppi_raw) == 0) {
    stop("The STRING subnetwork is empty at the selected score threshold.", call. = FALSE)
  }

  ppi <- ppi_raw %>%
    igraph::as_undirected(mode = "collapse") %>%
    igraph::simplify(remove.multiple = TRUE, remove.loops = TRUE, edge.attr.comb = "first")

  node_ids <- igraph::V(ppi)$name

  annotation <- mapped_final %>%
    group_by(STRING_id) %>%
    summarise(
      gene = first(gene[order(pvalue, na.last = TRUE)]),
      pvalue = safe_min(pvalue),
      logFC = safe_mean(logFC),
      .groups = "drop"
    )

  msg("Calculating network metrics.")
  comp <- igraph::components(ppi)
  largest_component <- which.max(comp$csize)
  lcc_nodes <- node_ids[comp$membership == largest_component]
  ppi_lcc <- igraph::induced_subgraph(ppi, vids = igraph::V(ppi)[name %in% lcc_nodes])

  louvain <- run_louvain_deterministic(ppi, weights = NA)

  degree_all <- igraph::degree(ppi, mode = "all", loops = FALSE)
  betweenness_all <- igraph::betweenness(ppi, directed = FALSE, normalized = TRUE)
  closeness_all <- suppressWarnings(igraph::closeness(ppi, mode = "all", normalized = TRUE))
  closeness_all[is.nan(closeness_all)] <- NA_real_

  harmonic_all <- if ("harmonic_centrality" %in% getNamespaceExports("igraph")) {
    igraph::harmonic_centrality(ppi, mode = "all", normalized = TRUE)
  } else {
    rep(NA_real_, igraph::gorder(ppi))
  }

  local_clustering_all <- igraph::transitivity(ppi, type = "local", isolates = "zero")
  local_clustering_all[is.nan(local_clustering_all)] <- NA_real_

  stress_all <- tryCatch(
    {
      adj <- as.matrix(igraph::as_adjacency_matrix(ppi, sparse = FALSE, attr = NULL))
      rownames(adj) <- node_ids
      colnames(adj) <- node_ids
      sna::stresscent(
        adj,
        gmode = "graph",
        diag = FALSE,
        cmode = "undirected",
        rescale = FALSE
      )
    },
    error = function(e) {
      msg("Stress centrality was not calculated: ", conditionMessage(e))
      rep(NA_real_, igraph::gorder(ppi))
    }
  )

  global_clustering <- igraph::transitivity(ppi, type = "global")
  if (is.nan(global_clustering)) global_clustering <- NA_real_

  average_path_lcc <- if (igraph::gorder(ppi_lcc) > 1) {
    igraph::mean_distance(ppi_lcc, directed = FALSE, unconnected = FALSE)
  } else {
    NA_real_
  }

  diameter_lcc <- if (igraph::gorder(ppi_lcc) > 1) {
    igraph::diameter(ppi_lcc, directed = FALSE, unconnected = FALSE)
  } else {
    0
  }

  radius_lcc <- if (igraph::gorder(ppi_lcc) > 1) {
    igraph::radius(ppi_lcc, mode = "all")
  } else {
    0
  }

  node_metrics <- tibble(
    STRING_id = node_ids,
    gene = annotation$gene[match(node_ids, annotation$STRING_id)],
    pvalue = annotation$pvalue[match(node_ids, annotation$STRING_id)],
    logFC = annotation$logFC[match(node_ids, annotation$STRING_id)],
    abs_logFC = abs(logFC),
    neg_log10_pvalue = -log10(pmax(pvalue, .Machine$double.xmin)),
    degree = as.numeric(degree_all),
    betweenness = as.numeric(betweenness_all),
    closeness = as.numeric(closeness_all),
    harmonic_closeness = as.numeric(harmonic_all),
    stress_centrality = as.numeric(stress_all),
    local_clustering = as.numeric(local_clustering_all),
    component = as.integer(comp$membership),
    in_largest_component = node_ids %in% lcc_nodes,
    community_louvain = as.integer(membership(louvain))
  ) %>%
    mutate(
      candidate_score = rowMeans(
        cbind(
          minmax(degree),
          minmax(betweenness),
          minmax(log1p(stress_centrality)),
          minmax(abs_logFC),
          minmax(neg_log10_pvalue)
        ),
        na.rm = TRUE
      )
    ) %>%
    arrange(desc(candidate_score), desc(degree), desc(betweenness))

  top_n <- min(top_n, nrow(node_metrics))

  top_candidates <- node_metrics %>%
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

  degree_distribution <- tibble(degree = as.integer(degree_all)) %>%
    count(degree, name = "n_nodes") %>%
    filter(degree > 0) %>%
    mutate(
      log10_degree = log10(degree),
      log10_n_nodes = log10(n_nodes)
    )

  module_labels <- lapply(
    split(node_metrics$gene, node_metrics$community_louvain),
    label_module_by_markers
  )

  module_summary <- node_metrics %>%
    group_by(community_louvain) %>%
    summarise(
      module_size = n(),
      nodes_in_largest_component = sum(in_largest_component, na.rm = TRUE),
      mean_logFC = safe_mean(logFC),
      median_logFC = median(logFC[is.finite(logFC)], na.rm = TRUE),
      min_pvalue = safe_min(pvalue),
      median_pvalue = median(pvalue[is.finite(pvalue)], na.rm = TRUE),
      top_candidate = gene[order(candidate_score, decreasing = TRUE, na.last = TRUE)][1],
      top_genes_by_candidate_score = top_genes(gene, candidate_score, 12L),
      top_genes_by_degree = top_genes(gene, degree, 12L),
      top_genes_by_betweenness = top_genes(gene, betweenness, 12L),
      .groups = "drop"
    ) %>%
    mutate(
      marker_based_direction = vapply(
        as.character(community_louvain),
        function(x) module_labels[[x]]$marker_summary,
        character(1)
      ),
      marker_clean_label = vapply(
        as.character(community_louvain),
        function(x) module_labels[[x]]$clean_label,
        character(1)
      ),
      marker_evidence_genes = vapply(
        as.character(community_louvain),
        function(x) module_labels[[x]]$evidence,
        character(1)
      )
    ) %>%
    arrange(desc(module_size), community_louvain)

  # The main report focuses on the five largest Louvain modules.
  # Smaller modules remain annotated in node-level outputs and GraphML.
  major_module_ids <- head(module_summary$community_louvain, min(5L, nrow(module_summary)))

  graph_summary <- tibble(
    metric = c(
      "nodes",
      "edges",
      "components",
      "largest_component_nodes",
      "largest_component_fraction",
      "density",
      "average_degree",
      "global_clustering",
      "average_shortest_path_lcc",
      "diameter_lcc",
      "radius_lcc",
      "louvain_communities",
      "louvain_modularity",
      "string_score_threshold"
    ),
    value = c(
      igraph::gorder(ppi),
      igraph::gsize(ppi),
      comp$no,
      max(comp$csize),
      round(max(comp$csize) / igraph::gorder(ppi), 4),
      igraph::edge_density(ppi, loops = FALSE),
      mean(degree_all),
      global_clustering,
      average_path_lcc,
      diameter_lcc,
      radius_lcc,
      length(unique(membership(louvain))),
      igraph::modularity(louvain),
      score_threshold
    )
  )

  mapping_summary <- tibble(
    metric = c(
      "input_rows",
      "initial_mapped",
      "initial_unmapped",
      "initial_mapped_percent",
      "final_mapped",
      "final_unmapped",
      "final_mapped_percent",
      "nodes_in_network"
    ),
    value = c(
      nrow(input_tbl),
      initial_mapped,
      initial_unmapped,
      initial_pct,
      after_mapped,
      after_unmapped,
      after_pct,
      nrow(mapped_final)
    )
  )

  gene_status <- input_tbl %>%
    distinct(input_gene, gene) %>%
    mutate(
      symbol_category_raw = vapply(gene, classify_symbol_pattern, FUN.VALUE = character(1)),
      hgnc_status = ifelse(input_gene != gene, "updated_by_HGNChelper", "unchanged_after_HGNChelper"),
      mapped_initially = gene %in% mapped_initial$gene[!is.na(mapped_initial$STRING_id)],
      corrected_to = valid_alias_corrections$corrected_gene[
        match(gene, valid_alias_corrections$original_gene)
      ],
      mapped_after_alias = !is.na(corrected_to) &
        corrected_to %in% mapped_final_raw$gene[!is.na(mapped_final_raw$STRING_id)],
      final_in_network = mapped_initially | mapped_after_alias,
      gene_status = mapply(
        status_from_mapping,
        mapped_initially,
        mapped_after_alias,
        symbol_category_raw,
        USE.NAMES = FALSE
      ),
      symbol_category = case_when(
        final_in_network & gene_status == "mapped_after_unambiguous_STRING_alias" ~ "STRING_mapped_after_unambiguous_alias_correction",
        final_in_network & symbol_category_raw == "HLA_gene" ~ "STRING_mapped_HLA_protein",
        final_in_network & symbol_category_raw == "immunoglobulin_locus" ~ "STRING_mapped_immunoglobulin_locus",
        final_in_network & symbol_category_raw == "t_cell_receptor_locus" ~ "STRING_mapped_T_cell_receptor_locus",
        final_in_network ~ "STRING_mapped_standard_protein",
        gene_status == "not_mapped_immunoglobulin_locus" ~ "not_mapped_immunoglobulin_locus",
        gene_status == "not_mapped_T_cell_receptor_locus" ~ "not_mapped_T_cell_receptor_locus",
        gene_status == "not_mapped_non_coding_or_predicted_locus" ~ "not_mapped_non_coding_or_predicted_locus",
        gene_status == "not_mapped_antisense_locus" ~ "not_mapped_antisense_or_lncRNA_like_symbol",
        gene_status == "not_mapped_pseudogene_like_symbol" ~ "not_mapped_pseudogene_like_symbol",
        gene_status == "not_mapped_HLA_gene" ~ "not_mapped_HLA_gene",
        gene_status == "not_mapped_empty_symbol" ~ "not_mapped_empty_symbol",
        TRUE ~ "not_mapped_no_unique_STRING_protein_identifier"
      )
    ) %>%
    select(
      input_gene, gene, hgnc_status, symbol_category, symbol_category_raw,
      mapped_initially, corrected_to, mapped_after_alias, final_in_network, gene_status
    ) %>%
    arrange(desc(final_in_network), symbol_category, gene_status, gene)

  still_unmapped <- mapped_final_raw %>%
    filter(is.na(STRING_id)) %>%
    distinct(gene) %>%
    arrange(gene)

  list(
    ppi = ppi,
    comp = comp,
    node_metrics = node_metrics,
    top_n = top_n,
    top_candidates = top_candidates,
    top_by_degree = top_by_degree,
    top_by_betweenness = top_by_betweenness,
    top_by_stress = top_by_stress,
    degree_distribution = degree_distribution,
    module_summary = module_summary,
    major_module_ids = major_module_ids,
    graph_summary = graph_summary,
    mapping_summary = mapping_summary,
    gene_status = gene_status,
    still_unmapped = still_unmapped
  )
}
