# CancerPPIr: HGNC and STRING mapping
#
# HGNC symbol handling, STRING identifier mapping, alias correction and STRING interaction retrieval.
#
# Architecture checkpoint 2.6
#
# The function bodies below were extracted from cancerppir.R without semantic rewriting.

##############################################################################
# classify_symbol_pattern - extracted from cancerppir.R lines 195-227
##############################################################################
classify_symbol_pattern <- function(sym) {
  s <- toupper(trimws(sym))

  if (!nzchar(s) || is.na(s)) {
    return("empty_symbol")
  }

  if (grepl("^(IGH|IGK|IGL)", s)) {
    return("immunoglobulin_locus")
  }

  if (grepl("^(TRA|TRB|TRG|TRD)", s)) {
    return("t_cell_receptor_locus")
  }

  if (grepl("^HLA-", s)) {
    return("HLA_gene")
  }

  if (grepl("^(LINC|MIR|MIRLET|SNORD|SNORA|SCARNA|RNU|RNA|LOC|AC[0-9]|AL[0-9])", s)) {
    return("non_coding_or_predicted_locus")
  }

  if (grepl("(^|[-.])AS[0-9]*$", s) || grepl("ANTISENSE", s)) {
    return("antisense_locus")
  }

  if (grepl("P[0-9]+$", s) && !grepl("^HLA-", s)) {
    return("pseudogene_like_symbol")
  }

  "standard_gene_symbol"
}

##############################################################################
# status_from_mapping - extracted from cancerppir.R lines 229-249
##############################################################################
status_from_mapping <- function(mapped_initially, mapped_after_alias, symbol_class) {
  if (isTRUE(mapped_initially)) {
    return("mapped_to_STRING")
  }

  if (isTRUE(mapped_after_alias)) {
    return("mapped_after_unambiguous_STRING_alias")
  }

  switch(
    symbol_class,
    immunoglobulin_locus = "not_mapped_immunoglobulin_locus",
    t_cell_receptor_locus = "not_mapped_T_cell_receptor_locus",
    non_coding_or_predicted_locus = "not_mapped_non_coding_or_predicted_locus",
    antisense_locus = "not_mapped_antisense_locus",
    pseudogene_like_symbol = "not_mapped_pseudogene_like_symbol",
    HLA_gene = "not_mapped_HLA_gene",
    empty_symbol = "not_mapped_empty_symbol",
    "not_mapped_no_unique_STRING_protein_identifier"
  )
}

##############################################################################
# pick_string_id_col - extracted from cancerppir.R lines 597-613
##############################################################################
pick_string_id_col <- function(x) {
  nm <- names(x)
  hit <- nm[grepl("STRING_id|string.*id|protein.*id|external.*id", nm, ignore.case = TRUE)]

  if (length(hit)) {
    return(hit[[1]])
  }

  for (col in nm) {
    v <- x[[col]]
    if (is.character(v) && any(grepl("^9606\\.|ENSP", head(v[!is.na(v)], 200)))) {
      return(col)
    }
  }

  stop("Could not identify a STRING identifier column.", call. = FALSE)
}

##############################################################################
# pick_alias_col - extracted from cancerppir.R lines 615-629
##############################################################################
pick_alias_col <- function(x, id_col) {
  nm <- setdiff(names(x), id_col)
  hit <- nm[grepl("alias|synonym", nm, ignore.case = TRUE)]

  if (length(hit)) {
    return(hit[[1]])
  }

  char_cols <- nm[vapply(x[nm], is.character, logical(1))]
  if (length(char_cols)) {
    return(char_cols[[1]])
  }

  stop("Could not identify an alias column.", call. = FALSE)
}

##############################################################################
# pick_preferred_name_col - extracted from cancerppir.R lines 631-640
##############################################################################
pick_preferred_name_col <- function(x) {
  nm <- names(x)
  hit <- nm[grepl("preferred_name|^gene$|symbol", nm, ignore.case = TRUE)]

  if (length(hit)) {
    return(hit[[1]])
  }

  stop("Could not identify a preferred gene/protein name column.", call. = FALSE)
}

##############################################################################
# make_string_links - extracted from cancerppir.R lines 642-657
##############################################################################
make_string_links <- function(string_ids, score_threshold) {
  ids <- head(unique(string_ids), 300L)
  id_param <- paste(ids, collapse = "%0d")

  query <- paste0(
    "?identifiers=", id_param,
    "&species=9606",
    "&required_score=", score_threshold,
    "&network_flavor=evidence"
  )

  c(
    current = paste0("https://string-db.org/cgi/network", query),
    pinned_v12 = paste0("https://version-12-0.stringdb.org/cgi/network", query)
  )
}

##############################################################################
# map_to_string - extracted from cancerppir.R lines 673-726
##############################################################################
map_to_string <- function(db, data, gene_col = "gene", removeUnmappedRows = FALSE) {
  df <- as.data.frame(data, stringsAsFactors = FALSE)
  df[[gene_col]] <- trimws(as.character(df[[gene_col]]))

  out <- tryCatch(
    as_tibble(db$map(df, gene_col, removeUnmappedRows = removeUnmappedRows)),
    error = function(e) {
      msg("STRINGdb mapping failed; using local alias fallback: ", conditionMessage(e))

      aliases <- db$get_aliases()
      proteins <- db$get_proteins()

      id_alias_col <- pick_string_id_col(aliases)
      alias_col <- pick_alias_col(aliases, id_alias_col)
      id_protein_col <- pick_string_id_col(proteins)
      name_col <- pick_preferred_name_col(proteins)

      alias_map <- aliases %>%
        transmute(
          gene_key = toupper(trimws(as.character(.data[[alias_col]]))),
          STRING_id = as.character(.data[[id_alias_col]])
        ) %>%
        filter(nzchar(gene_key), grepl("^9606\\.", STRING_id)) %>%
        distinct()

      protein_map <- proteins %>%
        transmute(
          gene_key = toupper(trimws(as.character(.data[[name_col]]))),
          STRING_id = as.character(.data[[id_protein_col]])
        ) %>%
        filter(nzchar(gene_key), grepl("^9606\\.", STRING_id)) %>%
        distinct()

      map_tbl <- bind_rows(protein_map, alias_map) %>%
        group_by(gene_key) %>%
        filter(n_distinct(STRING_id) == 1L) %>%
        slice(1) %>%
        ungroup()

      out <- as_tibble(df) %>%
        mutate(gene_key = toupper(trimws(.data[[gene_col]]))) %>%
        left_join(map_tbl, by = "gene_key") %>%
        select(-gene_key)

      if (isTRUE(removeUnmappedRows)) {
        out <- out %>% filter(!is.na(STRING_id))
      }

      out
    }
  )

  out
}

