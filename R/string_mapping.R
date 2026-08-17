# CancerPPIr: HGNC and STRING mapping
#
# HGNC symbol handling, STRING identifier mapping, alias correction and STRING interaction retrieval.
#
#
# The function bodies below were extracted from cancerppir.R without semantic rewriting.

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
pick_preferred_name_col <- function(x) {
  nm <- names(x)
  hit <- nm[grepl("preferred_name|^gene$|symbol", nm, ignore.case = TRUE)]

  if (length(hit)) {
    return(hit[[1]])
  }

  stop("Could not identify a preferred gene/protein name column.", call. = FALSE)
}

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


# CancerPPIr technical export validation: strict offline STRINGdb initialization
# -----------------------------------------------------------------------------

.cancerppir_offline_stringdb_state <- new.env(
  parent = emptyenv()
)

cancerppir_string_resource_expected_header <- function(role) {
  headers <- c(
    protein_info =
      "#string_protein_id\tpreferred_name\tprotein_size\tannotation",
    protein_aliases =
      "#string_protein_id\talias\tsource",
    protein_links =
      "protein1 protein2 combined_score",
    enrichment_terms =
      "#string_protein_id\tcategory\tterm\tdescription"
  )

  role <- as.character(role)

  if (
    length(role) != 1L ||
      is.na(role) ||
      !(role %in% names(headers))
  ) {
    return(NA_character_)
  }

  unname(headers[[role]])
}

cancerppir_string_resource_role_from_path <- function(path) {
  filename <- basename(as.character(path))
  patterns <- c(
    protein_info = ".protein.info.v12.0.txt.gz",
    protein_aliases = ".protein.aliases.v12.0.txt.gz",
    protein_links = ".protein.links.v12.0.txt.gz",
    enrichment_terms = ".protein.enrichment.terms.v12.0.txt.gz"
  )

  matches <- names(patterns)[
    vapply(
      patterns,
      grepl,
      logical(1),
      x = filename,
      fixed = TRUE
    )
  ]

  if (length(matches) != 1L) {
    return(NA_character_)
  }

  matches[[1L]]
}

cancerppir_read_gzip_header <- function(path) {
  connection <- gzfile(
    path,
    open = "rt",
    encoding = "UTF-8"
  )
  on.exit(close(connection), add = TRUE)

  tryCatch(
    withCallingHandlers(
      readLines(
        connection,
        n = 1L,
        warn = TRUE
      ),
      warning = function(warning) {
        stop(
          conditionMessage(warning),
          call. = FALSE
        )
      }
    ),
    error = function(error) character()
  )
}

cancerppir_gzip_file_complete <- function(path) {
  connection <- gzfile(path, open = "rb")

  tryCatch(
    withCallingHandlers(
      {
        repeat {
          chunk <- readBin(
            connection,
            what = "raw",
            n = 1024L * 1024L
          )

          if (!length(chunk)) {
            break
          }
        }

        TRUE
      },
      warning = function(warning) {
        stop(
          conditionMessage(warning),
          call. = FALSE
        )
      }
    ),
    error = function(error) FALSE,
    finally = close(connection)
  )
}

cancerppir_string_resource_file_valid <- function(
  path,
  role = NULL,
  verify_complete = FALSE
) {
  if (
    length(path) != 1L ||
      is.na(path) ||
      !nzchar(path) ||
      !file.exists(path)
  ) {
    return(FALSE)
  }

  info <- file.info(path)
  if (is.na(info$size[[1L]]) || info$size[[1L]] <= 0) {
    return(FALSE)
  }

  connection <- file(path, open = "rb")
  on.exit(close(connection), add = TRUE)

  magic <- tryCatch(
    readBin(connection, what = "raw", n = 2L),
    error = function(error) raw()
  )

  if (!identical(magic, as.raw(c(0x1f, 0x8b)))) {
    return(FALSE)
  }

  if (is.null(role)) {
    role <- cancerppir_string_resource_role_from_path(path)
  }

  expected_header <- cancerppir_string_resource_expected_header(
    role
  )

  if (is.na(expected_header)) {
    return(FALSE)
  }

  observed_header <- cancerppir_read_gzip_header(path)

  if (
    length(observed_header) != 1L ||
      !identical(observed_header, expected_header)
  ) {
    return(FALSE)
  }

  if (
    isTRUE(verify_complete) &&
      !cancerppir_gzip_file_complete(path)
  ) {
    return(FALSE)
  }

  TRUE
}

cancerppir_string_v12_resource_manifest <- function(
  cache_dir,
  species = 9606L,
  version = "12.0"
) {
  species <- as.integer(species)
  version <- as.character(version)

  if (!identical(species, 9606L)) {
    stop(
      "CancerPPIr STRING resource management supports only species 9606.",
      call. = FALSE
    )
  }

  if (!identical(version, "12.0")) {
    stop(
      "CancerPPIr STRING resource management requires STRING version 12.0.",
      call. = FALSE
    )
  }

  cache_dir <- normalizePath(
    cache_dir,
    winslash = "/",
    mustWork = FALSE
  )

  resource_groups <- c(
    protein_info = "protein.info",
    protein_aliases = "protein.aliases",
    protein_links = "protein.links",
    enrichment_terms = "protein.enrichment.terms"
  )

  filenames <- paste0(
    species,
    ".",
    unname(resource_groups),
    ".v",
    version,
    ".txt.gz"
  )

  urls <- paste0(
    "https://stringdb-downloads.org/download/",
    unname(resource_groups),
    ".v",
    version,
    "/",
    filenames
  )

  paths <- file.path(cache_dir, filenames)
  exists <- file.exists(paths)
  sizes <- ifelse(exists, file.info(paths)$size, NA_real_)
  valid <- vapply(
    seq_along(paths),
    function(index) {
      cancerppir_string_resource_file_valid(
        path = paths[[index]],
        role = names(resource_groups)[[index]]
      )
    },
    logical(1)
  )

  data.frame(
    cache_role = names(resource_groups),
    filename = filenames,
    url = urls,
    path = paths,
    exists = exists,
    size_bytes = sizes,
    valid = valid,
    stringsAsFactors = FALSE,
    row.names = NULL
  )
}

cancerppir_ensure_string_v12_resources <- function(
  cache_dir,
  roles,
  download_fun = utils::download.file
) {
  if (!is.function(download_fun)) {
    stop("download_fun must be a function.", call. = FALSE)
  }

  if (!dir.exists(cache_dir)) {
    created <- dir.create(
      cache_dir,
      recursive = TRUE,
      showWarnings = FALSE
    )

    if (!isTRUE(created) && !dir.exists(cache_dir)) {
      stop(
        "Could not create STRING cache directory: ",
        cache_dir,
        call. = FALSE
      )
    }
  }

  manifest <- cancerppir_string_v12_resource_manifest(cache_dir)
  roles <- unique(as.character(roles))

  unknown_roles <- setdiff(roles, manifest$cache_role)
  if (length(unknown_roles)) {
    stop(
      "Unknown STRING resource role(s): ",
      paste(unknown_roles, collapse = ", "),
      call. = FALSE
    )
  }

  for (role in roles) {
    row_index <- match(role, manifest$cache_role)
    resource <- manifest[row_index, , drop = FALSE]

    if (isTRUE(resource$valid[[1L]])) {
      msg(
        "Using cached STRING v12.0 resource: ",
        resource$filename[[1L]]
      )
      next
    }

    destination <- resource$path[[1L]]
    partial <- tempfile(
      pattern = paste0(resource$filename[[1L]], ".part-"),
      tmpdir = cache_dir
    )

    msg(
      "STRING v12.0 resource is missing or invalid; downloading: ",
      resource$filename[[1L]]
    )

    download_error <- tryCatch({
      download_fun(
        resource$url[[1L]],
        destfile = partial,
        mode = "wb",
        quiet = FALSE
      )
      NULL
    }, error = function(error) error)

    if (!is.null(download_error)) {
      unlink(partial, force = TRUE)
      stop(
        "Could not acquire required STRING v12.0 resource ",
        resource$filename[[1L]],
        ": ",
        conditionMessage(download_error),
        call. = FALSE
      )
    }

    msg(
      paste(
        "Validating the complete downloaded STRING resource;",
        "large files can take several minutes:"
      ),
      " ",
      resource$filename[[1L]]
    )

    if (!cancerppir_string_resource_file_valid(
      path = partial,
      role = role,
      verify_complete = TRUE
    )) {
      unlink(partial, force = TRUE)
      stop(
        "Downloaded STRING v12.0 resource failed gzip or schema validation: ",
        resource$filename[[1L]],
        call. = FALSE
      )
    }

    if (file.exists(destination)) {
      unlink(destination, force = TRUE)
    }

    moved <- file.rename(partial, destination)

    if (!isTRUE(moved)) {
      copied <- file.copy(
        partial,
        destination,
        overwrite = TRUE
      )
      unlink(partial, force = TRUE)

      if (!isTRUE(copied)) {
        stop(
          "Could not move downloaded STRING resource into cache: ",
          resource$filename[[1L]],
          call. = FALSE
        )
      }
    }

    if (!cancerppir_string_resource_file_valid(
      path = destination,
      role = role
    )) {
      stop(
        "Cached STRING resource failed validation after download: ",
        resource$filename[[1L]],
        call. = FALSE
      )
    }

    msg("Cached STRING v12.0 resource: ", resource$filename[[1L]])
  }

  refreshed <- cancerppir_string_v12_resource_manifest(cache_dir)
  refreshed[
    match(roles, refreshed$cache_role),
    ,
    drop = FALSE
  ]
}

cancerppir_stringdb_cache_manifest <- function(
  cache_dir,
  species = 9606,
  version = "12.0",
  network_type = "full",
  link_data = "combined_only"
) {
  network_type <- tolower(as.character(network_type))
  link_data <- tolower(as.character(link_data))

  if (!identical(network_type, "full")) {
    stop(
      "CancerPPIr local STRINGdb initialization currently requires network_type='full'.",
      call. = FALSE
    )
  }

  if (!identical(link_data, "combined_only")) {
    stop(
      "CancerPPIr local STRINGdb initialization currently requires link_data='combined_only'.",
      call. = FALSE
    )
  }

  manifest <- cancerppir_string_v12_resource_manifest(
    cache_dir = cache_dir,
    species = species,
    version = version
  )

  roles <- c(
    "protein_info",
    "protein_aliases",
    "protein_links"
  )

  manifest <- manifest[
    match(roles, manifest$cache_role),
    c("cache_role", "filename", "path", "exists", "size_bytes"),
    drop = FALSE
  ]

  rownames(manifest) <- NULL
  manifest
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
        "The local pinned initializer is validated for STRINGdb ",
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
  link_data = "combined_only",
  download_fun = utils::download.file
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
    created <- dir.create(
      cache_dir,
      recursive = TRUE,
      showWarnings = FALSE
    )

    if (!isTRUE(created) && !dir.exists(cache_dir)) {
      stop(
        "Could not create STRING cache directory: ",
        cache_dir,
        call. = FALSE
      )
    }
  }

  cache_dir <- normalizePath(
    cache_dir,
    winslash = "/",
    mustWork = TRUE
  )

  cancerppir_ensure_string_v12_resources(
    cache_dir = cache_dir,
    roles = c(
      "protein_info",
      "protein_aliases",
      "protein_links"
    ),
    download_fun = download_fun
  )

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
