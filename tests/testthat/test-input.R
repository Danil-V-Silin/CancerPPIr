testthat::test_that("separator detection supports comma, semicolon and tab", {
  comma_file <- tempfile(fileext = ".csv")
  semicolon_file <- tempfile(fileext = ".csv")
  tab_file <- tempfile(fileext = ".tsv")

  writeLines(c("gene,logFC,pvalue", "TP53,1.5,0.01"), comma_file)
  writeLines(c("gene;logFC;pvalue", "TP53;1,5;0,01"), semicolon_file)
  writeLines(c("gene\tlogFC\tpvalue", "TP53\t1.5\t0.01"), tab_file)

  testthat::expect_identical(guess_separator(comma_file), ",")
  testthat::expect_identical(guess_separator(semicolon_file), ";")
  testthat::expect_identical(guess_separator(tab_file), "\t")

  unsupported_file <- tempfile(fileext = ".txt")
  writeLines(c("gene logFC pvalue", "TP53 1.5 0.01"), unsupported_file)
  testthat::expect_error(
    guess_separator(unsupported_file),
    "Could not detect a supported delimiter"
  )

  unlink(c(comma_file, semicolon_file, tab_file, unsupported_file))
})

testthat::test_that("gene tables are normalized under the strict scientific contract", {
  input_file <- tempfile(fileext = ".csv")

  writeLines(
    c(
      "Gene Symbol;log2-FC;P.Value",
      "TP53;1,5;0,01",
      " EGFR ;-2,0;0"
    ),
    input_file
  )

  result <- read_gene_table(input_file)
  contract <- attr(
    result,
    "cancerppir_input_contract",
    exact = TRUE
  )

  testthat::expect_s3_class(result, "tbl_df")
  testthat::expect_identical(
    names(result),
    c("input_row", "gene", "logFC", "pvalue")
  )
  testthat::expect_identical(result$gene, c("TP53", "EGFR"))
  testthat::expect_equal(result$logFC, c(1.5, -2))
  testthat::expect_equal(result$pvalue, c(0.01, 0))

  testthat::expect_identical(
    contract$schema_version,
    CANCERPPIR_INPUT_CONTRACT_SCHEMA_VERSION
  )
  testthat::expect_identical(contract$logFC_scale, "log2_fold_change")
  testthat::expect_identical(
    contract$pvalue_type,
    "raw_differential_expression_p_value"
  )
  testthat::expect_false(contract$positional_column_fallback)
  testthat::expect_identical(contract$zero_pvalue_rows, 1L)
  testthat::expect_identical(contract$source_columns$gene, "Gene Symbol")
  testthat::expect_identical(contract$source_columns$logFC, "log2-FC")
  testthat::expect_identical(contract$source_columns$pvalue, "P.Value")

  mapping_rows <- input_contract_mapping_rows(contract)
  testthat::expect_true(
    all(c("metric", "value") %in% names(mapping_rows))
  )
  testthat::expect_identical(
    mapping_rows$value[
      mapping_rows$metric == "input_positional_column_fallback"
    ],
    "FALSE"
  )

  unlink(input_file)
})

testthat::test_that("positional fallback and adjusted-only significance columns are rejected", {
  positional_file <- tempfile(fileext = ".csv")
  writeLines(
    c("first,second,third", "0.01,1.5,TP53"),
    positional_file
  )
  testthat::expect_error(
    read_gene_table(positional_file),
    "Positional column fallback is disabled"
  )

  adjusted_file <- tempfile(fileext = ".csv")
  writeLines(
    c("gene,logFC,padj", "TP53,1.5,0.01"),
    adjusted_file
  )
  testthat::expect_error(
    read_gene_table(adjusted_file),
    "requires a raw differential-expression"
  )

  duplicate_column_file <- tempfile(fileext = ".csv")
  writeLines(
    c("gene,symbol,logFC,pvalue", "TP53,TP53,1.5,0.01"),
    duplicate_column_file
  )
  testthat::expect_error(
    read_gene_table(duplicate_column_file),
    "multiple columns matching 'gene'"
  )

  unlink(c(positional_file, adjusted_file, duplicate_column_file))
})

testthat::test_that("every canonical input value must be complete and finite", {
  nonnumeric_file <- tempfile(fileext = ".csv")
  writeLines(
    c(
      "gene,logFC,pvalue",
      "TP53,1.5,0.01",
      "EGFR,not_numeric,0.02"
    ),
    nonnumeric_file
  )
  testthat::expect_error(
    read_gene_table(nonnumeric_file),
    "logFC must be numeric and finite.*2"
  )

  missing_pvalue_file <- tempfile(fileext = ".csv")
  writeLines(
    c(
      "gene,logFC,pvalue",
      "TP53,1.5,0.01",
      "EGFR,2.0,NA"
    ),
    missing_pvalue_file
  )
  testthat::expect_error(
    read_gene_table(missing_pvalue_file),
    "pvalue must be numeric and finite.*2"
  )

  empty_gene_file <- tempfile(fileext = ".csv")
  writeLines(
    c(
      "gene,logFC,pvalue",
      "TP53,1.5,0.01",
      ",2.0,0.02"
    ),
    empty_gene_file
  )
  testthat::expect_error(
    read_gene_table(empty_gene_file),
    "Missing or empty gene symbols.*2"
  )

  unlink(c(nonnumeric_file, missing_pvalue_file, empty_gene_file))
})

testthat::test_that("p-values are bounded and gene symbols are unique", {
  out_of_range_file <- tempfile(fileext = ".csv")
  writeLines(
    c(
      "gene,logFC,pvalue",
      "TP53,1.5,-0.01",
      "EGFR,2.0,1.01"
    ),
    out_of_range_file
  )
  testthat::expect_error(
    read_gene_table(out_of_range_file),
    "closed interval \\[0, 1\\].*1, 2"
  )

  duplicate_gene_file <- tempfile(fileext = ".csv")
  writeLines(
    c(
      "gene,logFC,pvalue",
      "TP53,1.5,0.01",
      "tp53,2.0,0.02"
    ),
    duplicate_gene_file
  )
  testthat::expect_error(
    read_gene_table(duplicate_gene_file),
    "Duplicate gene symbols.*1, 2"
  )

  unlink(c(out_of_range_file, duplicate_gene_file))
})

testthat::test_that("empty and incomplete input tables fail explicitly", {
  empty_file <- tempfile(fileext = ".csv")
  writeLines(character(), empty_file)
  testthat::expect_error(
    guess_separator(empty_file),
    "Input file is empty"
  )

  missing_columns_file <- tempfile(fileext = ".csv")
  writeLines(
    c("gene,logFC", "TP53,1.5"),
    missing_columns_file
  )
  testthat::expect_error(
    read_gene_table(missing_columns_file),
    "Could not identify required columns: pvalue"
  )

  unlink(c(empty_file, missing_columns_file))
})
