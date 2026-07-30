# Validate one or more CancerPPIr differential-expression input tables without
# initializing STRINGdb or running network analysis.

script_argument <- grep(
  "^--file=",
  commandArgs(trailingOnly = FALSE),
  value = TRUE
)

project_root <- if (length(script_argument) >= 1L) {
  dirname(
    normalizePath(
      sub("^--file=", "", script_argument[[1L]]),
      winslash = "/",
      mustWork = TRUE
    )
  )
} else {
  normalizePath(".", winslash = "/", mustWork = TRUE)
}

source(
  file.path(project_root, "R", "load_all.R"),
  local = TRUE
)

load_cancerppir_modules(
  project_root = project_root,
  envir = environment()
)

usage <- paste(
  "Usage:",
  "  Rscript scripts/validate_input_contract.R input1.csv [input2.csv ...]",
  "",
  "The command validates headers, scientific semantics, completeness, numeric",
  "ranges and duplicate genes. It does not run STRING mapping or network analysis.",
  sep = "\n"
)

arguments <- commandArgs(trailingOnly = TRUE)

if (
  length(arguments) == 1L &&
    arguments[[1L]] %in% c("--help", "-h")
) {
  cat(usage, "\n")
  quit(save = "no", status = 0L)
}

if (length(arguments) == 0L) {
  stop(usage, call. = FALSE)
}

validation_rows <- lapply(
  arguments,
  function(input_path) {
    tryCatch(
      {
        table <- read_gene_table(input_path)
        contract <- attr(
          table,
          "cancerppir_input_contract",
          exact = TRUE
        )

        data.frame(
          file_name = basename(input_path),
          status = "PASS",
          rows = nrow(table),
          gene_column = contract$source_columns$gene,
          logFC_column = contract$source_columns$logFC,
          pvalue_column = contract$source_columns$pvalue,
          zero_pvalue_rows = contract$zero_pvalue_rows,
          details = "strict scientific input contract satisfied",
          stringsAsFactors = FALSE
        )
      },
      error = function(error) {
        data.frame(
          file_name = basename(input_path),
          status = "FAIL",
          rows = NA_integer_,
          gene_column = NA_character_,
          logFC_column = NA_character_,
          pvalue_column = NA_character_,
          zero_pvalue_rows = NA_integer_,
          details = conditionMessage(error),
          stringsAsFactors = FALSE
        )
      }
    )
  }
)

validation <- do.call(rbind, validation_rows)
rownames(validation) <- NULL
print(validation, row.names = FALSE)

if (any(validation$status == "FAIL")) {
  stop("CANCERPPIR INPUT CONTRACT: FAILED", call. = FALSE)
}

cat("CANCERPPIR INPUT CONTRACT: PASSED\n")
