# CancerPPIr: Input handling
#
# Input delimiter detection, gene-table reading and input-column normalization.
#
# Architecture checkpoint 2.5
#
# The function bodies below were extracted from cancerppir.R without semantic rewriting.

##############################################################################
# guess_separator - extracted from cancerppir.R lines 187-199
##############################################################################
guess_separator <- function(file) {
  x <- readLines(file, n = 1, warn = FALSE)
  if (!length(x)) stop("Input file is empty.", call. = FALSE)

  counts <- c(
    semicolon = lengths(regmatches(x, gregexpr(";", x, fixed = TRUE))),
    tab = lengths(regmatches(x, gregexpr("\t", x, fixed = TRUE))),
    comma = lengths(regmatches(x, gregexpr(",", x, fixed = TRUE)))
  )

  sep <- names(which.max(counts))
  switch(sep, semicolon = ";", tab = "\t", comma = ",")
}

##############################################################################
# read_gene_table - extracted from cancerppir.R lines 204-265
##############################################################################
read_gene_table <- function(file) {
  sep <- guess_separator(file)

  x <- utils::read.table(
    file,
    sep = sep,
    header = TRUE,
    fileEncoding = "UTF-8-BOM",
    stringsAsFactors = FALSE,
    check.names = FALSE,
    quote = "\"",
    comment.char = "",
    fill = TRUE
  )

  if (nrow(x) == 0) {
    stop("Input table has no rows.", call. = FALSE)
  }

  nm <- clean_names(names(x))

  gene_col <- find_column(nm, c("gene", "genesymbol", "symbol", "hgncsymbol"))
  logfc_col <- find_column(nm, c("logfc", "log2fc", "logfoldchange", "log2foldchange"))
  pval_col <- find_column(nm, c("pvalue", "pval", "padj", "adjpvalue", "adjustedpvalue", "fdr"))

  if (anyNA(c(gene_col, logfc_col, pval_col))) {
    if (ncol(x) >= 3) {
      msg("Column names were not fully recognized; assuming order: pvalue, logFC, gene.")
      pval_col <- 1L
      logfc_col <- 2L
      gene_col <- 3L
    } else {
      stop(
        "Could not identify required columns. ",
        "Use columns named gene, logFC and pvalue.",
        call. = FALSE
      )
    }
  }

  out <- tibble(
    input_row = seq_len(nrow(x)),
    gene = trimws(as.character(x[[gene_col]])),
    logFC = as_number(x[[logfc_col]]),
    pvalue = as_number(x[[pval_col]])
  ) %>%
    filter(!is.na(gene), nzchar(gene))

  if (!nrow(out)) {
    stop("No valid gene symbols were found in the input table.", call. = FALSE)
  }

  if (all(is.na(out$logFC))) {
    stop("logFC could not be converted to numeric values.", call. = FALSE)
  }

  if (all(is.na(out$pvalue))) {
    stop("pvalue could not be converted to numeric values.", call. = FALSE)
  }

  out
}

