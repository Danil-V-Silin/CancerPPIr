# CancerPPIr: enrichment
#
#

##############################################################################
string_enrichment_terms_candidates <- function(cache_dir) {
  file.path(
    cache_dir,
    c(
      "9606.protein.enrichment.terms.v12.0.txt.gz",
      "9606.protein.enrichment.terms.v12.0.txt"
    )
  )
}

##############################################################################
find_string_enrichment_terms <- function(cache_dir) {
  candidates <- string_enrichment_terms_candidates(cache_dir)
  candidates <- candidates[file.exists(candidates) & file.info(candidates)$size > 0]
  if (length(candidates)) {
    return(candidates[[1]])
  }
  NA_character_
}

##############################################################################
download_string_enrichment_terms <- function(cache_dir) {
  local_path <- find_string_enrichment_terms(cache_dir)

  if (!is.na(local_path)) {
    msg("Using cached STRING enrichment terms: ", basename(local_path))
    return(local_path)
  }

  resource <- cancerppir_ensure_string_v12_resources(
    cache_dir = cache_dir,
    roles = "enrichment_terms"
  )

  resource$path[[1L]]
}
##############################################################################
read_string_enrichment_terms <- function(cache_dir) {
  path <- download_string_enrichment_terms(cache_dir)
  if (is.na(path) || !file.exists(path)) {
    return(tibble())
  }

  msg("Reading local STRING enrichment terms from cache.")
  con <- if (grepl("\\.gz$", path, ignore.case = TRUE)) {
    gzfile(path, open = "rt")
  } else {
    file(path, open = "rt", encoding = "UTF-8")
  }
  on.exit(close(con), add = TRUE)

  x <- tryCatch(
    utils::read.table(
      con,
      sep = "\t",
      header = TRUE,
      quote = "",
      comment.char = "",
      stringsAsFactors = FALSE,
      check.names = FALSE,
      fill = TRUE
    ),
    error = function(e) {
      msg("Could not read local STRING enrichment terms: ", conditionMessage(e))
      NULL
    }
  )

  if (is.null(x) || !nrow(x)) {
    return(tibble())
  }

  names(x) <- gsub("^#", "", names(x))
  names(x) <- trimws(names(x))

  required <- c("string_protein_id", "category", "term", "description")
  if (!all(required %in% names(x))) {
    if (ncol(x) >= 4L) {
      msg("Local STRING enrichment file has no standard header; using first four columns as string_protein_id, category, term and description.")
      names(x)[1:4] <- required
    } else {
      msg("Local STRING enrichment file has unexpected columns; local enrichment skipped.")
      return(tibble())
    }
  }

  as_tibble(x) %>%
    select(all_of(required)) %>%
    mutate(
      string_protein_id = as.character(string_protein_id),
      category = as.character(category),
      term = as.character(term),
      description = as.character(description)
    ) %>%
    filter(grepl("^9606\\.", string_protein_id)) %>%
    distinct(string_protein_id, category, term, description)
}

##############################################################################
run_local_string_enrichment <- function(
  query_ids,
  background_ids,
  term_map,
  query_name,
  id_to_gene = NULL,
  min_query_hits = 2L,
  min_term_size = 3L,
  max_term_size = 500L
) {
  if (is.null(term_map) || !nrow(term_map)) {
    return(tibble())
  }

  query_ids <- unique(na.omit(as.character(query_ids)))
  background_ids <- unique(na.omit(as.character(background_ids)))
  query_ids <- intersect(query_ids, background_ids)

  if (length(query_ids) < min_query_hits || length(background_ids) < 10L) {
    return(tibble())
  }

  bg_terms <- term_map %>%
    filter(string_protein_id %in% background_ids)

  if (!nrow(bg_terms)) {
    return(tibble())
  }

  annotated_background_ids <- unique(
    as.character(bg_terms$string_protein_id)
  )
  query_ids <- intersect(
    query_ids,
    annotated_background_ids
  )

  background_n <- length(annotated_background_ids)
  query_n <- length(query_ids)

  if (query_n < min_query_hits || background_n < 10L) {
    return(tibble())
  }

  gene_name <- function(ids) {
    ids <- unique(ids)
    if (is.null(id_to_gene)) {
      return(paste(ids, collapse = ";"))
    }
    g <- unname(id_to_gene[ids])
    g[is.na(g) | !nzchar(g)] <- ids[is.na(g) | !nzchar(g)]
    paste(unique(g), collapse = ";")
  }

  out <- bg_terms %>%
    group_by(category, term, description) %>%
    summarise(
      number_of_genes_in_background = n_distinct(string_protein_id),
      number_of_genes = n_distinct(string_protein_id[string_protein_id %in% query_ids]),
      STRING_ids = paste(unique(string_protein_id[string_protein_id %in% query_ids]), collapse = ";"),
      .groups = "drop"
    ) %>%
    filter(
      number_of_genes >= min_query_hits,
      number_of_genes_in_background >= min_term_size,
      number_of_genes_in_background <= max_term_size
    )

  if (!nrow(out)) {
    return(tibble())
  }

  out <- out %>%
    mutate(
      query_name = query_name,
      query_size = query_n,
      background_size = background_n,
      pvalue = stats::phyper(
        number_of_genes - 1,
        number_of_genes_in_background,
        background_n - number_of_genes_in_background,
        query_n,
        lower.tail = FALSE
      ),
      fdr = stats::p.adjust(pvalue, method = "BH"),
      preferred_names = vapply(strsplit(STRING_ids, ";", fixed = TRUE), gene_name, character(1)),
      enrichment_source = "local_STRING_enrichment_terms",
      .before = 1
    ) %>%
    arrange(fdr, pvalue, desc(number_of_genes))

  out
}

##############################################################################
is_generic_enrichment_term <- function(description) {
  d <- tolower(trimws(as.character(description)))
  d[is.na(d)] <- ""
  exact_generic <- d %in% generic_exact_terms

  # Terms beginning with broad "regulation of" are often too general unless they
  # contain a domain-specific biological keyword, e.g. "regulation of leukocyte migration".
  broad_regulation <- grepl("^(positive |negative )?regulation of ", d) &
    !grepl(specific_biology_pattern, d, perl = TRUE)

  # "Response to ..." is useful only when it names a specific biological trigger.
  broad_response <- grepl("^response to ", d) &
    !grepl(specific_biology_pattern, d, perl = TRUE)

  exact_generic | broad_regulation | broad_response
}

##############################################################################
add_enrichment_priority <- function(tbl) {
  if (!nrow(tbl)) {
    return(tbl)
  }
  tbl %>%
    mutate(
      category_priority = match(category, preferred_enrichment_categories),
      category_priority = ifelse(is.na(category_priority), 99L, category_priority),
      description_lower = tolower(as.character(description)),
      is_preferred_category = category %in% preferred_enrichment_categories,
      is_secondary_category = category %in% secondary_enrichment_categories,
      is_generic_term = is_generic_enrichment_term(description),
      has_specific_keyword = grepl(specific_biology_pattern, description_lower, perl = TRUE),
      is_significant_fdr = is.finite(fdr) & fdr <= 0.05,
      is_specific_interpretable = is_preferred_category & !is_generic_term & has_specific_keyword
    )
}

##############################################################################
select_top_enrichment <- function(tbl, group_cols = character(0), n_per_group = 10L,
                                  specific_only = TRUE) {
  if (!nrow(tbl)) {
    return(tibble(note = "No enrichment results available."))
  }

  out <- tbl %>%
    add_enrichment_priority()

  if (specific_only) {
    specific <- out %>% filter(is_specific_interpretable)
    if (nrow(specific)) {
      out <- specific
    }
  }

  out <- out %>% arrange(category_priority, fdr, pvalue)

  if (length(group_cols)) {
    out <- out %>%
      group_by(across(all_of(group_cols))) %>%
      slice_head(n = n_per_group) %>%
      ungroup()
  } else {
    out <- out %>%
      slice_head(n = n_per_group)
  }

  out %>%
    mutate(
      preferred_names = truncate_text(preferred_names, 350L),
      STRING_ids = truncate_text(STRING_ids, 350L),
      description = truncate_text(description, 250L),
      term_filter_note = case_when(
        is_specific_interpretable ~ "specific_interpretable_term_used_in_report",
        is_generic_term ~ "generic_term_retained_for_audit_only",
        is_secondary_category ~ "secondary_category_retained_for_audit_only",
        TRUE ~ "not_primary_for_human_report"
      )
    ) %>%
    select(any_of(c(
      group_cols,
      "query_name", "query_size", "background_size",
      "category", "term", "description", "term_filter_note",
      "number_of_genes", "number_of_genes_in_background",
      "pvalue", "fdr", "preferred_names", "enrichment_source"
    )))
}

##############################################################################
collapse_module_enrichment <- function(tbl, n_terms = 6L) {
  if (!nrow(tbl) || !("community_louvain" %in% names(tbl))) {
    return(tibble(
      community_louvain = integer(),
      top_interpretable_terms = character(),
      top_interpretable_sources = character(),
      best_interpretable_fdr = numeric(),
      enrichment_support_genes = character(),
      top_raw_terms = character(),
      total_enrichment_terms = integer(),
      specific_interpretable_terms_n = integer()
    ))
  }

  annotated <- tbl %>% add_enrichment_priority()

  raw_collapsed <- annotated %>%
    arrange(community_louvain, category_priority, fdr, pvalue) %>%
    group_by(community_louvain) %>%
    summarise(
      top_raw_terms = paste(head(unique(description), n_terms), collapse = "; "),
      total_enrichment_terms = dplyr::n(),
      .groups = "drop"
    )

  specific <- annotated %>%
    filter(is_specific_interpretable, is_significant_fdr) %>%
    arrange(community_louvain, category_priority, fdr, pvalue)

  if (!nrow(specific)) {
    return(raw_collapsed %>%
      mutate(
        top_interpretable_terms = NA_character_,
        top_interpretable_sources = NA_character_,
        best_interpretable_fdr = NA_real_,
        enrichment_support_genes = NA_character_,
        specific_interpretable_terms_n = 0L
      ) %>%
      select(
        community_louvain, top_interpretable_terms, top_interpretable_sources,
        best_interpretable_fdr, enrichment_support_genes, top_raw_terms,
        total_enrichment_terms, specific_interpretable_terms_n
      ))
  }

  specific_collapsed <- specific %>%
    group_by(community_louvain) %>%
    summarise(
      top_interpretable_terms = paste(head(unique(description), n_terms), collapse = "; "),
      top_interpretable_sources = paste(head(unique(category), n_terms), collapse = "; "),
      best_interpretable_fdr = safe_min(fdr),
      enrichment_support_genes = truncate_text(paste(head(unique(preferred_names), 3L), collapse = " | "), 700L),
      specific_interpretable_terms_n = dplyr::n(),
      .groups = "drop"
    )

  raw_collapsed %>%
    left_join(specific_collapsed, by = "community_louvain") %>%
    mutate(
      specific_interpretable_terms_n = ifelse(is.na(specific_interpretable_terms_n), 0L, specific_interpretable_terms_n)
    ) %>%
    select(
      community_louvain, top_interpretable_terms, top_interpretable_sources,
      best_interpretable_fdr, enrichment_support_genes, top_raw_terms,
      total_enrichment_terms, specific_interpretable_terms_n
    )
}

##############################################################################
# Stable enrichment configuration moved from cancerppir.R
##############################################################################

# Configuration object: preferred_enrichment_categories
preferred_enrichment_categories <- c(
  "Biological Process (Gene Ontology)",
  "Reactome Pathways",
  "WikiPathways",
  "KEGG Pathways",
  "Local Network Cluster (STRING)",
  "Annotated Keywords (UniProt)",
  "Molecular Function (Gene Ontology)",
  "Cellular Component (Gene Ontology)"
)

# Configuration object: secondary_enrichment_categories
secondary_enrichment_categories <- c(
  "Human Phenotype (Monarch)",
  "Tissue expression (TISSUES)",
  "Disease-gene associations (DISEASES)",
  "Subcellular localization (COMPARTMENTS)",
  "Protein Domains and Features (InterPro)",
  "Protein Domains (SMART)",
  "Protein Domains (Pfam)"
)

# Configuration object: specific_biology_pattern
specific_biology_pattern <- paste(
  c(
    "immune", "immun", "leukocyte", "lymphocyte", "myeloid", "macrophage",
    "monocyte", "neutrophil", "t cell", "b cell", "natural killer", "cytotoxic",
    "antigen", "mhc", "major histocompatibility", "hla", "peptide presentation",
    "chemokine", "cytokine", "interferon", "interleukin", "tnf", "chemotaxis",
    "migration", "complement", "c1q", "fc receptor", "phagocyt",
    "extracellular matrix", "ecm", "collagen", "matrix organization", "stromal",
    "focal adhesion", "angiogenesis", "endothelial", "vascular",
    "cell cycle", "mitotic", "mitosis", "chromosome segregation", "dna replication",
    "lipid", "fatty acid", "cholesterol", "oxidative phosphorylation", "respiratory chain",
    "apoptosis", "inflammasome", "antiviral"
  ),
  collapse = "|"
)

# Configuration object: generic_exact_terms
generic_exact_terms <- c(
  "signaling",
  "signal transduction",
  "cell communication",
  "cellular response to stimulus",
  "response to stimulus",
  "response to stress",
  "biological regulation",
  "regulation of biological process",
  "regulation of molecular function",
  "regulation of cellular process",
  "cellular process",
  "metabolic process",
  "organic substance metabolic process",
  "primary metabolic process",
  "cellular metabolic process",
  "localization",
  "binding",
  "protein binding",
  "catalytic activity",
  "molecular function",
  "cellular anatomical entity",
  "intracellular anatomical structure",
  "cellular component",
  "anatomical structure development",
  "developmental process"
)

