# CancerPPIr: Input handling
#
# Responsibility: delimiter detection, strict input validation and canonical
# normalization of differential-expression gene tables.

CANCERPPIR_INPUT_CONTRACT_SCHEMA_VERSION <- "1.0.0"

cancerppir_input_contract <- function(
  source_columns = list(
    gene = NA_character_,
    logFC = NA_character_,
    pvalue = NA_character_
  ),
  input_rows = NA_integer_,
  zero_pvalue_rows = NA_integer_
) {
  list(
    schema_version = CANCERPPIR_INPUT_CONTRACT_SCHEMA_VERSION,
    gene_identifier = "HGNC_gene_symbol",
    logFC_scale = "log2_fold_change",
    contrast_numerator = "tumor_specimen",
    contrast_denominator = "reference_condition",
    positive_logFC_interpretation =
      "higher_expression_in_tumor_specimen_relative_to_reference",
    pvalue_type = "raw_differential_expression_p_value",
    pvalue_range = "closed_interval_0_to_1",
    missing_value_policy = "error",
    non_finite_numeric_policy = "error",
    duplicate_gene_policy = "error_before_HGNC_normalization",
    positional_column_fallback = FALSE,
    zero_pvalue_policy = paste(
      "accepted_as_numerical_underflow_and_floored_to",
      ".Machine$double.xmin_for_negative_log10_transformation"
    ),
    source_columns = source_columns,
    input_rows = as.integer(input_rows),
    zero_pvalue_rows = as.integer(zero_pvalue_rows)
  )
}

input_contract_mapping_rows <- function(contract) {
  if (!is.list(contract)) {
    stop("input contract must be a list.", call. = FALSE)
  }

  source_columns <- contract$source_columns

  tibble(
    metric = c(
      "input_contract_schema_version",
      "input_gene_identifier",
      "input_logFC_scale",
      "input_contrast_numerator",
      "input_contrast_denominator",
      "input_positive_logFC_interpretation",
      "input_pvalue_type",
      "input_pvalue_range",
      "input_missing_value_policy",
      "input_duplicate_gene_policy",
      "input_positional_column_fallback",
      "input_gene_source_column",
      "input_logFC_source_column",
      "input_pvalue_source_column",
      "input_zero_pvalue_rows"
    ),
    value = c(
      contract$schema_version,
      contract$gene_identifier,
      contract$logFC_scale,
      contract$contrast_numerator,
      contract$contrast_denominator,
      contract$positive_logFC_interpretation,
      contract$pvalue_type,
      contract$pvalue_range,
      contract$missing_value_policy,
      contract$duplicate_gene_policy,
      as.character(contract$positional_column_fallback),
      source_columns$gene,
      source_columns$logFC,
      source_columns$pvalue,
      as.character(contract$zero_pvalue_rows)
    )
  )
}

guess_separator <- function(file) {
  x <- readLines(file, n = 1, warn = FALSE)
  if (!length(x)) stop("Input file is empty.", call. = FALSE)

  counts <- c(
    semicolon = lengths(regmatches(x, gregexpr(";", x, fixed = TRUE))),
    tab = lengths(regmatches(x, gregexpr("\t", x, fixed = TRUE))),
    comma = lengths(regmatches(x, gregexpr(",", x, fixed = TRUE)))
  )

  if (all(counts == 0L)) {
    stop(
      "Could not detect a supported delimiter. Use comma, semicolon or tab.",
      call. = FALSE
    )
  }

  sep <- names(which.max(counts))
  switch(sep, semicolon = ";", tab = "\t", comma = ",")
}

find_unique_input_column <- function(
  normalized_names,
  candidates,
  canonical_name
) {
  hits <- which(normalized_names %in% candidates)

  if (length(hits) > 1L) {
    stop(
      "Input table contains multiple columns matching '",
      canonical_name,
      "'. Keep exactly one canonical or recognized alias column.",
      call. = FALSE
    )
  }

  if (length(hits) == 1L) hits[[1L]] else NA_integer_
}

format_input_rows <- function(rows, maximum = 20L) {
  rows <- as.integer(rows)
  shown <- head(rows, maximum)
  suffix <- if (length(rows) > maximum) ", ..." else ""
  paste0(paste(shown, collapse = ", "), suffix)
}

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

  if (nrow(x) == 0L) {
    stop("Input table has no rows.", call. = FALSE)
  }

  original_names <- names(x)
  normalized_names <- clean_names(original_names)

  gene_col <- find_unique_input_column(
    normalized_names,
    c("gene", "genesymbol", "symbol", "hgncsymbol"),
    "gene"
  )

  logfc_col <- find_unique_input_column(
    normalized_names,
    c("logfc", "log2fc", "logfoldchange", "log2foldchange"),
    "logFC"
  )

  pvalue_col <- find_unique_input_column(
    normalized_names,
    c("pvalue", "pval", "rawpvalue", "rawpval"),
    "pvalue"
  )

  if (is.na(pvalue_col)) {
    adjusted_aliases <- c(
      "padj", "adjpvalue", "adjustedpvalue", "fdr", "qvalue"
    )

    if (any(normalized_names %in% adjusted_aliases)) {
      stop(
        paste(
          "The candidate-score contract requires a raw differential-expression",
          "p-value column named pvalue, pval, raw_pvalue or raw_pval.",
          "Adjusted p-values, FDR and q-values are not interchangeable with",
          "the canonical pvalue variable."
        ),
        call. = FALSE
      )
    }
  }

  if (anyNA(c(gene_col, logfc_col, pvalue_col))) {
    missing_columns <- c(
      gene = is.na(gene_col),
      logFC = is.na(logfc_col),
      pvalue = is.na(pvalue_col)
    )

    stop(
      "Could not identify required columns: ",
      paste(names(missing_columns)[missing_columns], collapse = ", "),
      ". Positional column fallback is disabled; use explicit recognized headers.",
      call. = FALSE
    )
  }

  gene <- trimws(as.character(x[[gene_col]]))
  logFC <- as_number(x[[logfc_col]])
  pvalue <- as_number(x[[pvalue_col]])

  invalid_gene_rows <- which(is.na(gene) | !nzchar(gene))
  if (length(invalid_gene_rows) > 0L) {
    stop(
      "Missing or empty gene symbols at input row(s): ",
      format_input_rows(invalid_gene_rows),
      ".",
      call. = FALSE
    )
  }

  invalid_logfc_rows <- which(is.na(logFC) | !is.finite(logFC))
  if (length(invalid_logfc_rows) > 0L) {
    stop(
      "logFC must be numeric and finite at every input row. Invalid row(s): ",
      format_input_rows(invalid_logfc_rows),
      ".",
      call. = FALSE
    )
  }

  invalid_pvalue_rows <- which(is.na(pvalue) | !is.finite(pvalue))
  if (length(invalid_pvalue_rows) > 0L) {
    stop(
      "pvalue must be numeric and finite at every input row. Invalid row(s): ",
      format_input_rows(invalid_pvalue_rows),
      ".",
      call. = FALSE
    )
  }

  out_of_range_rows <- which(pvalue < 0 | pvalue > 1)
  if (length(out_of_range_rows) > 0L) {
    stop(
      "pvalue must lie in the closed interval [0, 1]. Invalid row(s): ",
      format_input_rows(out_of_range_rows),
      ".",
      call. = FALSE
    )
  }

  duplicate_key <- toupper(gene)
  duplicate_rows <- which(
    duplicated(duplicate_key) |
      duplicated(duplicate_key, fromLast = TRUE)
  )

  if (length(duplicate_rows) > 0L) {
    duplicate_genes <- unique(gene[duplicate_rows])
    stop(
      "Duplicate gene symbols are not permitted before HGNC normalization. ",
      "Duplicate row(s): ",
      format_input_rows(duplicate_rows),
      "; symbol(s): ",
      paste(head(duplicate_genes, 20L), collapse = ", "),
      ".",
      call. = FALSE
    )
  }

  out <- tibble(
    input_row = seq_len(nrow(x)),
    gene = gene,
    logFC = logFC,
    pvalue = pvalue
  )

  attr(out, "cancerppir_input_contract") <- cancerppir_input_contract(
    source_columns = list(
      gene = original_names[[gene_col]],
      logFC = original_names[[logfc_col]],
      pvalue = original_names[[pvalue_col]]
    ),
    input_rows = nrow(out),
    zero_pvalue_rows = sum(out$pvalue == 0)
  )

  out
}
