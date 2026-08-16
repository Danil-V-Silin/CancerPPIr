testthat::test_that(
  "local STRINGdb initialization uses pinned cached files",
  {
    testthat::skip_if_not_installed("STRINGdb")
    testthat::skip_if_not_installed("igraph")

    testthat::expect_identical(
      as.character(utils::packageVersion("STRINGdb")),
      "2.20.0"
    )

    cache_dir <- tempfile(
      pattern = "cancerppir_string_cache_"
    )

    dir.create(
      cache_dir,
      recursive = TRUE
    )

    on.exit(
      unlink(
        cache_dir,
        recursive = TRUE,
        force = TRUE
      ),
      add = TRUE
    )

    write_gzip_lines <- function(
      path,
      lines
    ) {
      connection <- gzfile(
        path,
        open = "wt",
        encoding = "UTF-8"
      )

      on.exit(
        close(connection),
        add = TRUE
      )

      writeLines(
        lines,
        con = connection,
        useBytes = TRUE
      )
    }

    write_gzip_lines(
      file.path(
        cache_dir,
        "9606.protein.info.v12.0.txt.gz"
      ),
      c(
        "#string_protein_id\tpreferred_name\tprotein_size\tannotation",
        "9606.ENSPTEST0001\tGENE1\t100\tTest protein 1",
        "9606.ENSPTEST0002\tGENE2\t120\tTest protein 2"
      )
    )

    write_gzip_lines(
      file.path(
        cache_dir,
        "9606.protein.aliases.v12.0.txt.gz"
      ),
      c(
        "#string_protein_id\talias\tsource",
        "9606.ENSPTEST0001\tGENE1\tEnsembl_HGNC_symbol",
        "9606.ENSPTEST0002\tGENE2\tEnsembl_HGNC_symbol"
      )
    )

    write_gzip_lines(
      file.path(
        cache_dir,
        "9606.protein.links.v12.0.txt.gz"
      ),
      c(
        "protein1 protein2 combined_score",
        "9606.ENSPTEST0001 9606.ENSPTEST0002 900"
      )
    )

    string_db <- create_offline_stringdb(
      cache_dir = cache_dir,
      score_threshold = 400L
    )

    testthat::expect_true(
      methods::is(
        string_db,
        "STRINGdb"
      )
    )

    testthat::expect_identical(
      string_db$protocol,
      "offline"
    )

    testthat::expect_identical(
      string_db$stable_url,
      "offline://string-v12.0"
    )

    proteins <- string_db$get_proteins()

    testthat::expect_equal(
      nrow(proteins),
      2L
    )

    aliases <- string_db$get_aliases()

    testthat::expect_true(
      all(
        c("GENE1", "GENE2") %in%
          aliases$alias
      )
    )

    mapped <- string_db$map(
      data.frame(
        gene = c("GENE1", "GENE2"),
        stringsAsFactors = FALSE
      ),
      "gene",
      removeUnmappedRows = FALSE,
      quiet = TRUE
    )

    testthat::expect_identical(
      mapped$STRING_id,
      c(
        "9606.ENSPTEST0001",
        "9606.ENSPTEST0002"
      )
    )

    local_graph <- string_db$get_graph()

    testthat::expect_equal(
      as.integer(igraph::vcount(local_graph)),
      2L
    )

    testthat::expect_equal(
      as.integer(igraph::ecount(local_graph)),
      1L
    )
  }
)

testthat::test_that(
  "STRING v12 resources are acquired once and then reused from cache",
  {
    cache_dir <- tempfile(
      pattern = "cancerppir_resource_cache_"
    )

    dir.create(cache_dir, recursive = TRUE)
    on.exit(
      unlink(cache_dir, recursive = TRUE, force = TRUE),
      add = TRUE
    )

    download_calls <- character()

    fake_download <- function(
      url,
      destfile,
      mode = "wb",
      quiet = FALSE,
      ...
    ) {
      download_calls <<- c(download_calls, url)

      connection <- gzfile(destfile, open = "wt", encoding = "UTF-8")
      on.exit(close(connection), add = TRUE)
      writeLines(c("header", "data"), connection)
      invisible(0L)
    }

    roles <- c(
      "protein_info",
      "protein_aliases",
      "protein_links",
      "enrichment_terms"
    )

    acquired <- cancerppir_ensure_string_v12_resources(
      cache_dir = cache_dir,
      roles = roles,
      download_fun = fake_download
    )

    testthat::expect_equal(length(download_calls), 4L)
    testthat::expect_identical(acquired$cache_role, roles)
    testthat::expect_true(all(acquired$valid))
    testthat::expect_true(all(file.exists(acquired$path)))

    reused <- cancerppir_ensure_string_v12_resources(
      cache_dir = cache_dir,
      roles = roles,
      download_fun = function(...) {
        stop("Downloader must not be called for valid cached resources.")
      }
    )

    testthat::expect_true(all(reused$valid))
    testthat::expect_equal(length(download_calls), 4L)
  }
)

testthat::test_that(
  "STRING resource acquisition fails clearly without leaving a partial file",
  {
    cache_dir <- tempfile(
      pattern = "cancerppir_failed_resource_cache_"
    )

    dir.create(cache_dir, recursive = TRUE)
    on.exit(
      unlink(cache_dir, recursive = TRUE, force = TRUE),
      add = TRUE
    )

    testthat::expect_error(
      cancerppir_ensure_string_v12_resources(
        cache_dir = cache_dir,
        roles = "protein_info",
        download_fun = function(...) {
          stop("simulated download failure")
        }
      ),
      regexp = "Could not acquire required STRING v12.0 resource"
    )

    partial_files <- list.files(
      cache_dir,
      pattern = "\\.part-",
      full.names = TRUE
    )

    testthat::expect_length(partial_files, 0L)
  }
)

testthat::test_that(
  "the production pipeline no longer constructs STRINGdb through online initialization",
  {
    candidate_roots <- c(
      ".",
      "..",
      file.path("..", "..")
    )

    pipeline_candidates <- file.path(
      candidate_roots,
      "R",
      "pipeline.R"
    )

    pipeline_path <- pipeline_candidates[
      file.exists(pipeline_candidates)
    ][1L]

    testthat::expect_false(
      is.na(pipeline_path)
    )

    pipeline_path <- normalizePath(
      pipeline_path,
      winslash = "/",
      mustWork = TRUE
    )

    pipeline_text <- paste(
      readLines(
        pipeline_path,
        warn = FALSE,
        encoding = "UTF-8"
      ),
      collapse = "\n"
    )

    testthat::expect_match(
      pipeline_text,
      "create_offline_stringdb\\("
    )

    testthat::expect_false(
      grepl(
        "STRINGdb\\$new\\(",
        pipeline_text
      )
    )

    testthat::expect_false(
      grepl(
        "wininet",
        pipeline_text,
        fixed = TRUE
      )
    )
  }
)
