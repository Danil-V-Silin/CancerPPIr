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


# Phase 4.4B: strict offline STRINGdb initialization
# -----------------------------------------------------------------------------

.cancerppir_offline_stringdb_state <- new.env(
  parent = emptyenv()
)

cancerppir_stringdb_cache_manifest <- function(
  cache_dir,
  species = 9606,
  version = "12.0",
  network_type = "full",
  link_data = "combined_only"
) {
  cache_dir <- normalizePath(
    cache_dir,
    winslash = "/",
    mustWork = FALSE
  )

  species <- as.integer(species)
  version <- as.character(version)
  network_type <- tolower(as.character(network_type))
  link_data <- tolower(as.character(link_data))

  if (!identical(species, 9606L)) {
    stop(
      "CancerPPIr offline STRINGdb initialization supports only species 9606.",
      call. = FALSE
    )
  }

  if (!identical(version, "12.0")) {
    stop(
      "CancerPPIr offline STRINGdb initialization requires STRING version 12.0.",
      call. = FALSE
    )
  }

  if (!identical(network_type, "full")) {
    stop(
      "CancerPPIr offline STRINGdb initialization currently requires network_type='full'.",
      call. = FALSE
    )
  }

  if (!identical(link_data, "combined_only")) {
    stop(
      "CancerPPIr offline STRINGdb initialization currently requires link_data='combined_only'.",
      call. = FALSE
    )
  }

  filenames <- c(
    protein_info = paste0(
      species,
      ".protein.info.v",
      version,
      ".txt.gz"
    ),
    protein_aliases = paste0(
      species,
      ".protein.aliases.v",
      version,
      ".txt.gz"
    ),
    protein_links = paste0(
      species,
      ".protein.links.v",
      version,
      ".txt.gz"
    )
  )

  paths <- file.path(
    cache_dir,
    filenames
  )

  data.frame(
    cache_role = names(filenames),
    filename = unname(filenames),
    path = unname(paths),
    exists = file.exists(paths),
    size_bytes = ifelse(
      file.exists(paths),
      file.info(paths)$size,
      NA_real_
    ),
    stringsAsFactors = FALSE,
    row.names = NULL
  )
}

cancerppir_get_offline_stringdb_generator <- function() {
  if (!requireNamespace("STRINGdb", quietly = TRUE)) {
    stop(
      "Package STRINGdb is required.",
      call. = FALSE
    )
  }

  installed_version <- as.character(
    utils::packageVersion("STRINGdb")
  )

  supported_version <- "2.20.0"

  if (!identical(installed_version, supported_version)) {
    stop(
      paste0(
        "The strict offline initializer is validated for STRINGdb ",
        supported_version,
        ", but version ",
        installed_version,
        " is installed. Restore the pinned renv environment before running CancerPPIr."
      ),
      call. = FALSE
    )
  }

  if (!is.null(.cancerppir_offline_stringdb_state$generator)) {
    return(
      .cancerppir_offline_stringdb_state$generator
    )
  }

  class_name <- "CancerPPIrOfflineSTRINGdbV12"

  class_environment <- new.env(
    parent = asNamespace("STRINGdb")
  )

  generator <- methods::setRefClass(
    class_name,
    contains = "STRINGdb",
    methods = list(
      initialize = function(
        species = 9606,
        version = "12.0",
        score_threshold = 400,
        network_type = "full",
        input_directory = "",
        link_data = "combined_only",
        ...
      ) {
        .self$initFields(
          species = as.numeric(species),
          version = as.character(version),
          score_threshold = as.numeric(score_threshold),
          network_type = tolower(as.character(network_type)),
          input_directory = as.character(input_directory),
          link_data = tolower(as.character(link_data)),
          protocol = "offline",
          file_version = as.character(version),
          stable_url = "offline://string-v12.0",
          aliases_type = "take_first"
        )
      }
    ),
    where = class_environment
  )

  .cancerppir_offline_stringdb_state$class_environment <-
    class_environment

  .cancerppir_offline_stringdb_state$generator <- generator

  generator
}

create_offline_stringdb <- function(
  cache_dir,
  score_threshold = 400L,
  species = 9606L,
  version = "12.0",
  network_type = "full",
  link_data = "combined_only"
) {
  if (
    length(score_threshold) != 1L ||
      is.na(score_threshold) ||
      !is.finite(score_threshold) ||
      score_threshold < 1
  ) {
    stop(
      "score_threshold must be one finite value greater than or equal to 1.",
      call. = FALSE
    )
  }

  if (!dir.exists(cache_dir)) {
    stop(
      paste0(
        "Local STRING cache directory does not exist: ",
        cache_dir
      ),
      call. = FALSE
    )
  }

  cache_dir <- normalizePath(
    cache_dir,
    winslash = "/",
    mustWork = TRUE
  )

  manifest <- cancerppir_stringdb_cache_manifest(
    cache_dir = cache_dir,
    species = species,
    version = version,
    network_type = network_type,
    link_data = link_data
  )

  invalid_cache <- manifest[
    !manifest$exists |
      is.na(manifest$size_bytes) |
      manifest$size_bytes <= 0,
    ,
    drop = FALSE
  ]

  if (nrow(invalid_cache) > 0L) {
    stop(
      paste0(
        "Strict offline STRINGdb initialization requires the following non-empty local cache file(s):\n",
        paste0(
          "- ",
          invalid_cache$path,
          collapse = "\n"
        ),
        "\nNo online download fallback is permitted."
      ),
      call. = FALSE
    )
  }

  generator <- cancerppir_get_offline_stringdb_generator()

  string_db <- generator$new(
    species = as.integer(species),
    version = as.character(version),
    score_threshold = as.numeric(score_threshold),
    network_type = tolower(as.character(network_type)),
    input_directory = cache_dir,
    link_data = tolower(as.character(link_data))
  )

  expected_fields <- list(
    species = as.numeric(species),
    version = as.character(version),
    file_version = as.character(version),
    score_threshold = as.numeric(score_threshold),
    network_type = tolower(as.character(network_type)),
    link_data = tolower(as.character(link_data)),
    input_directory = cache_dir,
    protocol = "offline",
    stable_url = "offline://string-v12.0",
    aliases_type = "take_first"
  )

  mismatched_fields <- names(expected_fields)[
    !vapply(
      names(expected_fields),
      function(field_name) {
        identical(
          string_db[[field_name]],
          expected_fields[[field_name]]
        )
      },
      FUN.VALUE = logical(1)
    )
  ]

  if (length(mismatched_fields) > 0L) {
    stop(
      paste0(
        "Offline STRINGdb object initialization produced unexpected field values: ",
        paste(
          mismatched_fields,
          collapse = ", "
        ),
        "."
      ),
      call. = FALSE
    )
  }

  string_db
}
