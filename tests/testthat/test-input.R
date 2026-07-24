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

  unlink(c(comma_file, semicolon_file, tab_file))
})

testthat::test_that("gene tables are normalized to the analytical schema", {
  input_file <- tempfile(fileext = ".csv")

  writeLines(
    c(
      "Gene Symbol;log2-FC;P.Value",
      "TP53;1,5;0,01",
      " EGFR ;-2,0;0,05"
    ),
    input_file
  )

  result <- read_gene_table(input_file)

  testthat::expect_s3_class(result, "tbl_df")
  testthat::expect_identical(
    names(result),
    c("input_row", "gene", "logFC", "pvalue")
  )
  testthat::expect_identical(result$gene, c("TP53", "EGFR"))
  testthat::expect_equal(result$logFC, c(1.5, -2))
  testthat::expect_equal(result$pvalue, c(0.01, 0.05))

  unlink(input_file)
})

testthat::test_that("invalid input tables fail with explicit errors", {
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
    "Could not identify required columns"
  )

  nonnumeric_file <- tempfile(fileext = ".csv")
  writeLines(
    c("gene,logFC,pvalue", "TP53,not_numeric,0.01"),
    nonnumeric_file
  )
  testthat::expect_error(
    read_gene_table(nonnumeric_file),
    "logFC could not be converted"
  )

  unlink(c(empty_file, missing_columns_file, nonnumeric_file))
})
