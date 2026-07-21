#!/usr/bin/env Rscript

# Create the compact Phase 3.1 automated test suite for CancerPPIr.
#
# Run from the repository root:
#   Rscript scripts/setup_phase3_unit_tests.R
#
# This script creates:
#   scripts/run_unit_tests.R
#   tests/testthat/test-loader.R
#   tests/testthat/test-utils.R
#   tests/testthat/test-input.R
#   tests/testthat/test-enrichment-labeling.R

project_root <- normalizePath(
  ".",
  winslash = "/",
  mustWork = TRUE
)

required_files <- c(
  "R/load_all.R",
  "R/00_utils.R",
  "R/01_input.R",
  "R/03_enrichment.R",
  "R/04_module_labeling.R",
  "R/06_network_analysis.R",
  "R/07_pipeline.R",
  "renv.lock"
)

missing_files <- required_files[
  !file.exists(file.path(project_root, required_files))
]

if (length(missing_files) > 0L) {
  stop(
    paste0(
      "Run this script from the CancerPPIr repository root.\n",
      "Missing files:\n",
      paste0("- ", missing_files, collapse = "\n")
    ),
    call. = FALSE
  )
}

output_files <- c(
  "scripts/run_unit_tests.R",
  "tests/testthat/test-loader.R",
  "tests/testthat/test-utils.R",
  "tests/testthat/test-input.R",
  "tests/testthat/test-enrichment-labeling.R"
)

existing_outputs <- output_files[
  file.exists(file.path(project_root, output_files))
]

if (length(existing_outputs) > 0L) {
  stop(
    paste0(
      "Test files already exist. Inspect them before rerunning setup:\n",
      paste0("- ", existing_outputs, collapse = "\n")
    ),
    call. = FALSE
  )
}

write_utf8 <- function(path, text) {
  dir.create(
    dirname(path),
    recursive = TRUE,
    showWarnings = FALSE
  )

  writeLines(
    enc2utf8(text),
    con = path,
    useBytes = TRUE
  )
}

runner <- c(
  "#!/usr/bin/env Rscript",
  "",
  "# Fast local unit-test runner for the modular CancerPPIr workflow.",
  "",
  "project_root <- normalizePath(",
  '  ".",',
  '  winslash = "/",',
  "  mustWork = TRUE",
  ")",
  "",
  "required_packages <- c(",
  '  "testthat",',
  '  "dplyr",',
  '  "tibble"',
  ")",
  "",
  "missing_packages <- required_packages[",
  "  !vapply(",
  "    required_packages,",
  "    requireNamespace,",
  "    quietly = TRUE,",
  "    FUN.VALUE = logical(1)",
  "  )",
  "]",
  "",
  "if (length(missing_packages) > 0L) {",
  "  stop(",
  "    paste0(",
  '      "Missing test dependencies: ",',
  "      paste(missing_packages, collapse = \", \"),",
  '      "\\nInstall them through renv before running the tests."',
  "    ),",
  "    call. = FALSE",
  "  )",
  "}",
  "",
  "suppressPackageStartupMessages({",
  "  library(dplyr)",
  "  library(tibble)",
  "})",
  "",
  "source(",
  '  file.path(project_root, "R", "load_all.R"),',
  "  local = .GlobalEnv",
  ")",
  "",
  "loaded_files <- load_cancerppir_modules(",
  "  project_root = project_root,",
  "  envir = .GlobalEnv",
  ")",
  "",
  "stopifnot(length(loaded_files) == 8L)",
  "",
  "Sys.setenv(",
  "  CANCERPPIR_PROJECT_ROOT = project_root",
  ")",
  "",
  "testthat::test_dir(",
  '  file.path(project_root, "tests", "testthat"),',
  '  reporter = "summary",',
  "  env = .GlobalEnv,",
  "  stop_on_failure = TRUE,",
  "  stop_on_warning = FALSE",
  ")",
  "",
  'cat("\\nPHASE 3.1 UNIT TESTS PASSED\\n")'
)

test_loader <- c(
  'testthat::test_that("module loader exposes the complete architecture", {',
  "  expected_functions <- c(",
  '    "parse_bool",',
  '    "read_gene_table",',
  '    "run_local_string_enrichment",',
  '    "label_module_by_markers",',
  '    "run_network_analysis",',
  '    "run_cancerppir"',
  "  )",
  "",
  "  testthat::expect_true(",
  "    all(vapply(",
  "      expected_functions,",
  "      exists,",
  "      envir = .GlobalEnv,",
  "      inherits = FALSE,",
  "      FUN.VALUE = logical(1)",
  "    ))",
  "  )",
  "",
  "  testthat::expect_identical(",
  "    names(formals(run_cancerppir)),",
  "    c(",
  '      "input_file",',
  '      "results_root",',
  '      "cache_dir",',
  '      "score_threshold",',
  '      "top_n",',
  '      "run_enrichment"',
  "    )",
  "  )",
  "})"
)

test_utils <- c(
  'testthat::test_that("boolean and enrichment-mode parsing is stable", {',
  "  testthat::expect_identical(",
  '    parse_bool(c("1", "TRUE", "yes", "no", "0")),',
  "    c(TRUE, TRUE, TRUE, FALSE, FALSE)",
  "  )",
  "",
  "  testthat::expect_identical(",
  '    is_bool_like(c("true", "FALSE", "y", "n", "other")),',
  "    c(TRUE, TRUE, TRUE, TRUE, FALSE)",
  "  )",
  "",
  '  testthat::expect_identical(normalize_enrichment_mode("local"), "offline")',
  '  testthat::expect_identical(normalize_enrichment_mode("validation"), "online_validation")',
  "  testthat::expect_error(",
  '    normalize_enrichment_mode("unsupported"),',
  '    "Invalid enrichment_mode"',
  "  )",
  "})",
  "",
  'testthat::test_that("shared normalization and numeric helpers are deterministic", {',
  "  testthat::expect_identical(",
  '    normalize_path_for_compare("C:\\\\data\\\\Genes_R.csv"),',
  '    "C:/data/Genes_R.csv"',
  "  )",
  "",
  "  testthat::expect_equal(",
  '    as_number(c("1,5", "-2.0", "bad")),',
  "    c(1.5, -2, NA_real_)",
  "  )",
  "",
  "  testthat::expect_identical(",
  '    clean_names(c(" Gene Symbol ", "log2-FC", "P.Value")),',
  '    c("genesymbol", "log2fc", "pvalue")',
  "  )",
  "",
  "  testthat::expect_equal(",
  "    minmax(c(5, 10, 15, NA_real_)),",
  "    c(0, 0.5, 1, NA_real_)",
  "  )",
  "",
  "  testthat::expect_equal(",
  "    minmax(c(2, 2, NA_real_)),",
  "    c(1, 1, NA_real_)",
  "  )",
  "",
  "  testthat::expect_true(",
  "    all(is.na(minmax(c(NA_real_, Inf))))",
  "  )",
  "})",
  "",
  'testthat::test_that("ranking and text helpers retain legacy behavior", {',
  "  testthat::expect_identical(",
  '    top_genes(c("B", "A", "A", "C"), c(1, 4, 3, 2), n = 3L),',
  '    "A;C"',
  "  )",
  "",
  "  truncated <- truncate_text(",
  '    "abcdefghijklmnopqrstuvwxyz",',
  "    max_chars = 10L",
  "  )",
  "",
  '  testthat::expect_identical(truncated, "abcdefg...")',
  '  testthat::expect_identical(NULL %||% "fallback", "fallback")',
  '  testthat::expect_identical("value" %||% "fallback", "value")',
  "})"
)

test_input <- c(
  'testthat::test_that("separator detection supports comma, semicolon and tab", {',
  "  comma_file <- tempfile(fileext = \".csv\")",
  "  semicolon_file <- tempfile(fileext = \".csv\")",
  "  tab_file <- tempfile(fileext = \".tsv\")",
  "",
  '  writeLines(c("gene,logFC,pvalue", "TP53,1.5,0.01"), comma_file)',
  '  writeLines(c("gene;logFC;pvalue", "TP53;1,5;0,01"), semicolon_file)',
  '  writeLines(c("gene\\tlogFC\\tpvalue", "TP53\\t1.5\\t0.01"), tab_file)',
  "",
  '  testthat::expect_identical(guess_separator(comma_file), ",")',
  '  testthat::expect_identical(guess_separator(semicolon_file), ";")',
  '  testthat::expect_identical(guess_separator(tab_file), "\\t")',
  "",
  "  unlink(c(comma_file, semicolon_file, tab_file))",
  "})",
  "",
  'testthat::test_that("gene tables are normalized to the analytical schema", {',
  "  input_file <- tempfile(fileext = \".csv\")",
  "",
  "  writeLines(",
  "    c(",
  '      "Gene Symbol;log2-FC;P.Value",',
  '      "TP53;1,5;0,01",',
  '      " EGFR ;-2,0;0,05"',
  "    ),",
  "    input_file",
  "  )",
  "",
  "  result <- read_gene_table(input_file)",
  "",
  '  testthat::expect_s3_class(result, "tbl_df")',
  "  testthat::expect_identical(",
  "    names(result),",
  '    c("input_row", "gene", "logFC", "pvalue")',
  "  )",
  '  testthat::expect_identical(result$gene, c("TP53", "EGFR"))',
  "  testthat::expect_equal(result$logFC, c(1.5, -2))",
  "  testthat::expect_equal(result$pvalue, c(0.01, 0.05))",
  "",
  "  unlink(input_file)",
  "})",
  "",
  'testthat::test_that("invalid input tables fail with explicit errors", {',
  "  empty_file <- tempfile(fileext = \".csv\")",
  "  writeLines(character(), empty_file)",
  "  testthat::expect_error(",
  "    guess_separator(empty_file),",
  '    "Input file is empty"',
  "  )",
  "",
  "  missing_columns_file <- tempfile(fileext = \".csv\")",
  "  writeLines(",
  '    c("gene,logFC", "TP53,1.5"),',
  "    missing_columns_file",
  "  )",
  "  testthat::expect_error(",
  "    read_gene_table(missing_columns_file),",
  '    "Could not identify required columns"',
  "  )",
  "",
  "  nonnumeric_file <- tempfile(fileext = \".csv\")",
  "  writeLines(",
  '    c("gene,logFC,pvalue", "TP53,not_numeric,0.01"),',
  "    nonnumeric_file",
  "  )",
  "  testthat::expect_error(",
  "    read_gene_table(nonnumeric_file),",
  '    "logFC could not be converted"',
  "  )",
  "",
  "  unlink(c(empty_file, missing_columns_file, nonnumeric_file))",
  "})"
)

test_enrichment_labeling <- c(
  'testthat::test_that("generic enrichment filtering distinguishes specific biology", {',
  "  result <- is_generic_enrichment_term(",
  "    c(",
  '      "Signaling",',
  '      "regulation of leukocyte migration",',
  '      "regulation of cellular process"',
  "    )",
  "  )",
  "",
  "  testthat::expect_identical(",
  "    result,",
  "    c(TRUE, FALSE, TRUE)",
  "  )",
  "})",
  "",
  'testthat::test_that("enrichment priority columns are generated deterministically", {',
  "  input <- tibble::tibble(",
  "    category = c(",
  '      "Biological Process (Gene Ontology)",',
  '      "Protein Domains (Pfam)"',
  "    ),",
  "    description = c(",
  '      "leukocyte migration",',
  '      "protein binding"',
  "    ),",
  "    fdr = c(0.01, 0.20),",
  "    pvalue = c(0.001, 0.10)",
  "  )",
  "",
  "  result <- add_enrichment_priority(input)",
  "",
  "  testthat::expect_true(",
  "    all(c(",
  '      "category_priority",',
  '      "is_preferred_category",',
  '      "is_secondary_category",',
  '      "is_generic_term",',
  '      "is_specific_interpretable"',
  "    ) %in% names(result))",
  "  )",
  "",
  "  testthat::expect_true(result$is_preferred_category[[1]])",
  "  testthat::expect_true(result$is_specific_interpretable[[1]])",
  "  testthat::expect_true(result$is_secondary_category[[2]])",
  "  testthat::expect_true(result$is_generic_term[[2]])",
  "})",
  "",
  'testthat::test_that("local STRING enrichment works on a synthetic fixture", {',
  '  background_ids <- paste0("9606.P", seq_len(10L))',
  '  query_ids <- paste0("9606.P", 1:3)',
  "",
  "  term_map <- tibble::tibble(",
  "    string_protein_id = c(",
  '      paste0("9606.P", 1:5),',
  '      paste0("9606.P", 6:10)',
  "    ),",
  "    category = rep(",
  '      "Biological Process (Gene Ontology)",',
  "      10L",
  "    ),",
  "    term = c(",
  '      rep("GO:IMMUNE", 5L),',
  '      rep("GO:OTHER", 5L)',
  "    ),",
  "    description = c(",
  '      rep("leukocyte migration", 5L),',
  '      rep("unrelated process", 5L)',
  "    )",
  "  )",
  "",
  "  id_to_gene <- stats::setNames(",
  '    paste0("GENE", seq_len(10L)),',
  "    background_ids",
  "  )",
  "",
  "  result <- run_local_string_enrichment(",
  "    query_ids = query_ids,",
  "    background_ids = background_ids,",
  "    term_map = term_map,",
  '    query_name = "synthetic_query",',
  "    id_to_gene = id_to_gene",
  "  )",
  "",
  "  testthat::expect_equal(nrow(result), 1L)",
  '  testthat::expect_identical(result$term[[1]], "GO:IMMUNE")',
  "  testthat::expect_equal(result$number_of_genes[[1]], 3L)",
  "  testthat::expect_true(is.finite(result$pvalue[[1]]))",
  "  testthat::expect_true(is.finite(result$fdr[[1]]))",
  "})",
  "",
  'testthat::test_that("module labeling recognizes curated biological programs", {',
  "  cell_cycle <- label_module_by_markers(",
  '    c("CDK1", "TOP2A", "CDC20", "CCNB1")',
  "  )",
  "",
  "  testthat::expect_identical(",
  "    cell_cycle$clean_label,",
  '    "cell_cycle_mitotic_module"',
  "  )",
  "",
  "  testthat::expect_identical(",
  '    clean_module_label_from_terms("collagen extracellular matrix organization"),',
  '    "stromal_ECM_remodeling_module"',
  "  )",
  "",
  "  counts <- extract_marker_counts(",
  '    "cell_cycle_mitotic(5); antigen_presentation(2)"',
  "  )",
  "",
  "  testthat::expect_identical(",
  '    unname(counts[c("cell_cycle_mitotic", "antigen_presentation")]),',
  "    c(5L, 2L)",
  "  )",
  "",
  "  testthat::expect_identical(",
  "    label_evidence_score(",
  "      marker_count = 3L,",
  "      term_hit_count = 1L,",
  "      required_hit_count = 1L,",
  "      best_fdr = 0.01,",
  "      module_size = 20L",
  "    ),",
  "    9L",
  "  )",
  "})"
)

files <- list(
  "scripts/run_unit_tests.R" = runner,
  "tests/testthat/test-loader.R" = test_loader,
  "tests/testthat/test-utils.R" = test_utils,
  "tests/testthat/test-input.R" = test_input,
  "tests/testthat/test-enrichment-labeling.R" = test_enrichment_labeling
)

for (relative_path in names(files)) {
  write_utf8(
    file.path(project_root, relative_path),
    files[[relative_path]]
  )
}

message("[phase 3.1 setup] Test scaffold created.")
message("[phase 3.1 setup] Files created: ", length(files), ".")
message("[phase 3.1 setup] No analytical source files were modified.")
message("[phase 3.1 setup] Install/record testthat, then run:")
message("  Rscript scripts/run_unit_tests.R")