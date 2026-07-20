# CancerPPIr: enrichment
#
# Architecture checkpoint 2.7.
#
# Functions below were extracted from cancerppir.R without semantic rewriting.

##############################################################################
# clean_enrichment_table - extracted from cancerppir.R lines 301-319
##############################################################################
clean_enrichment_table <- function(x) {
  if (is.null(x) || !nrow(x)) {
    return(tibble())
  }

  x <- as_tibble(x)

  for (nm in names(x)) {
    if (is.list(x[[nm]])) {
      x[[nm]] <- vapply(
        x[[nm]],
        function(v) paste(as.character(v), collapse = ";"),
        character(1)
      )
    }
  }

  x
}

##############################################################################
# run_gprofiler - extracted from cancerppir.R lines 321-353
##############################################################################
run_gprofiler <- function(genes, query_name, organism = "hsapiens") {
  genes <- unique(na.omit(as.character(genes)))
  genes <- genes[nzchar(genes)]

  if (length(genes) < 3L) {
    return(tibble())
  }

  if (!requireNamespace("gprofiler2", quietly = TRUE)) {
    return(tibble())
  }

  res <- tryCatch(
    gprofiler2::gost(
      query = genes,
      organism = organism,
      ordered_query = FALSE,
      correction_method = "fdr",
      sources = c("GO:BP", "GO:MF", "GO:CC", "REAC", "KEGG", "WP")
    ),
    error = function(e) {
      msg("g:Profiler enrichment skipped for ", query_name, ": ", conditionMessage(e))
      NULL
    }
  )

  if (is.null(res) || is.null(res$result) || !nrow(res$result)) {
    return(tibble())
  }

  clean_enrichment_table(res$result) %>%
    mutate(query_name = query_name, .before = 1)
}

##############################################################################
# string_enrichment_terms_candidates - extracted from cancerppir.R lines 356-364
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
# find_string_enrichment_terms - extracted from cancerppir.R lines 366-373
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
# download_string_enrichment_terms - extracted from cancerppir.R lines 375-398
##############################################################################
download_string_enrichment_terms <- function(cache_dir) {
  local_path <- find_string_enrichment_terms(cache_dir)
  if (!is.na(local_path)) {
    msg("Using cached STRING enrichment terms: ", basename(local_path))
    return(local_path)
  }

  dest <- file.path(cache_dir, "9606.protein.enrichment.terms.v12.0.txt.gz")
  url <- "https://stringdb-downloads.org/download/protein.enrichment.terms.v12.0/9606.protein.enrichment.terms.v12.0.txt.gz"
  msg("Cached STRING enrichment terms were not found; trying to download them.")
  ok <- tryCatch({
    utils::download.file(url, destfile = dest, mode = "wb", quiet = FALSE)
    TRUE
  }, error = function(e) {
    msg("Local STRING enrichment file was not downloaded: ", conditionMessage(e))
    FALSE
  })

  if (isTRUE(ok) && file.exists(dest) && file.info(dest)$size > 0) {
    dest
  } else {
    NA_character_
  }
}

##############################################################################
# read_string_enrichment_terms - extracted from cancerppir.R lines 400-459
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
# run_local_string_enrichment - extracted from cancerppir.R lines 461-541
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

  background_n <- length(unique(bg_terms$string_protein_id))
  query_n <- length(query_ids)

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
# run_string_enrichment_online - extracted from cancerppir.R lines 1036-1057
##############################################################################
run_string_enrichment_online <- function(ids, query_name = "STRING_online_query") {
  ids <- unique(na.omit(as.character(ids)))
  ids <- ids[nzchar(ids)]
  if (length(ids) < 3L) {
    return(tibble())
  }

  out <- tryCatch(
    string_db$get_enrichment(ids),
    error = function(e) {
      msg("Online STRING enrichment skipped for ", query_name, ": ", conditionMessage(e))
      NULL
    }
  )

  if (is.null(out) || !nrow(out)) {
    return(tibble())
  }

  clean_enrichment_table(as_tibble(out)) %>%
    mutate(query_name = query_name, .before = 1)
}

##############################################################################
# is_generic_enrichment_term - extracted from cancerppir.R lines 1405-1420
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
# add_enrichment_priority - extracted from cancerppir.R lines 1422-1438
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
# select_top_enrichment - extracted from cancerppir.R lines 1440-1487
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
# collapse_module_enrichment - extracted from cancerppir.R lines 1489-1555
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
# collapse_gprofiler_module_enrichment - extracted from cancerppir.R lines 1558-1584
##############################################################################
collapse_gprofiler_module_enrichment <- function(tbl, n_terms = 6L) {
  if (!nrow(tbl) || !("community_louvain" %in% names(tbl))) {
    return(tibble(
      community_louvain = integer(),
      online_gprofiler_terms = character(),
      online_gprofiler_sources = character(),
      online_gprofiler_best_p = numeric(),
      online_gprofiler_terms_n = integer()
    ))
  }
  tbl %>%
    mutate(
      term_name = as.character(term_name),
      source = as.character(source),
      p_value = suppressWarnings(as.numeric(p_value))
    ) %>%
    filter(!is.na(term_name), nzchar(term_name)) %>%
    group_by(community_louvain) %>%
    arrange(p_value, .by_group = TRUE) %>%
    summarise(
      online_gprofiler_terms = paste(head(unique(term_name), n_terms), collapse = "; "),
      online_gprofiler_sources = paste(head(unique(source), n_terms), collapse = "; "),
      online_gprofiler_best_p = safe_min(p_value),
      online_gprofiler_terms_n = dplyr::n(),
      .groups = "drop"
    )
}

##############################################################################
# collapse_string_online_module_enrichment - extracted from cancerppir.R lines 1586-1630
##############################################################################
collapse_string_online_module_enrichment <- function(tbl, n_terms = 6L) {
  if (!nrow(tbl) || !("community_louvain" %in% names(tbl))) {
    return(tibble(
      community_louvain = integer(),
      online_STRING_terms = character(),
      online_STRING_sources = character(),
      online_STRING_best_fdr = numeric(),
      online_STRING_terms_n = integer()
    ))
  }
  desc_col <- if ("description" %in% names(tbl)) "description" else if ("term_description" %in% names(tbl)) "term_description" else NA_character_
  if (is.na(desc_col)) {
    return(tibble(
      community_louvain = integer(),
      online_STRING_terms = character(),
      online_STRING_sources = character(),
      online_STRING_best_fdr = numeric(),
      online_STRING_terms_n = integer()
    ))
  }
  fdr_col <- if ("fdr" %in% names(tbl)) "fdr" else if ("p_value" %in% names(tbl)) "p_value" else if ("pvalue" %in% names(tbl)) "pvalue" else NA_character_
  if (is.na(fdr_col)) {
    tbl$fdr_for_sort <- NA_real_
  } else {
    tbl$fdr_for_sort <- suppressWarnings(as.numeric(tbl[[fdr_col]]))
  }
  if (!("category" %in% names(tbl))) {
    tbl$category <- "STRING_online"
  }
  tbl %>%
    mutate(
      online_description = as.character(.data[[desc_col]]),
      category = as.character(category)
    ) %>%
    filter(!is.na(online_description), nzchar(online_description)) %>%
    group_by(community_louvain) %>%
    arrange(fdr_for_sort, .by_group = TRUE) %>%
    summarise(
      online_STRING_terms = paste(head(unique(online_description), n_terms), collapse = "; "),
      online_STRING_sources = paste(head(unique(category), n_terms), collapse = "; "),
      online_STRING_best_fdr = safe_min(fdr_for_sort),
      online_STRING_terms_n = dplyr::n(),
      .groups = "drop"
    )
}

##############################################################################
# online_concordance_status - extracted from cancerppir.R lines 1632-1646
##############################################################################
online_concordance_status <- function(specific_label_candidate, online_text) {
  if (is.na(online_text) || !nzchar(online_text) || online_text == "not_available") {
    return("online_not_run_or_no_terms")
  }
  label_raw <- normalize_label_text(specific_label_candidate)
  idx <- which(vapply(label_rulebook, function(r) identical(r$label_id, label_raw), logical(1)))
  if (!length(idx)) {
    return("online_terms_available_no_matching_rule")
  }
  rule <- label_rulebook[[idx[[1]]]]
  if (matches_any_pattern(online_text, rule$core_term_patterns) || matches_any_pattern(online_text, rule$required_specific_patterns)) {
    return("online_terms_concordant_with_assigned_label")
  }
  "online_terms_available_not_rule_concordant"
}

