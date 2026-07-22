# CancerPPIr: reporting
#
# Architecture checkpoint 2.9.
#
# Functions below were extracted from cancerppir.R without semantic rewriting.

##############################################################################
# write_excel - extracted from cancerppir.R lines 237-249
##############################################################################
write_excel <- function(path, sheets) {
  wb <- createWorkbook()

  for (nm in names(sheets)) {
    addWorksheet(wb, nm)
    writeData(wb, nm, sheets[[nm]])
    if (ncol(sheets[[nm]]) > 0) {
      setColWidths(wb, nm, 1:ncol(sheets[[nm]]), "auto")
    }
  }

  saveWorkbook(wb, path, overwrite = TRUE)
}

##############################################################################
# sanitize_sheet_name - extracted from cancerppir.R lines 983-986
##############################################################################
sanitize_sheet_name <- function(x) {
  x <- gsub("[\\[\\]\\*\\?/\\\\:]", "_", x)
  substr(x, 1L, 31L)
}

##############################################################################
# as_output_table - extracted from cancerppir.R lines 988-997
##############################################################################
as_output_table <- function(x) {
  if (is.null(x)) {
    return(tibble(note = "No data available for this sheet."))
  }
  x <- as.data.frame(x, stringsAsFactors = FALSE)
  if (!nrow(x) || !ncol(x)) {
    return(tibble(note = "No data available for this sheet."))
  }
  as_tibble(x)
}

##############################################################################
##############################################################################
# prepare_graphml_pvalue_export
##############################################################################
CANCERPPIR_GRAPHML_PVALUE_FLOOR <- 1e-300

prepare_graphml_pvalue_export <- function(pvalue) {
  if (is.factor(pvalue)) {
    pvalue <- as.character(pvalue)
  }

  if (is.character(pvalue)) {
    raw_text <- trimws(pvalue)
    missing_text <- is.na(raw_text) | !nzchar(raw_text)
    numeric_pvalue <- suppressWarnings(as.numeric(raw_text))

    coercion_failed <- !missing_text & is.na(numeric_pvalue)
    if (any(coercion_failed)) {
      stop(
        "GraphML p-value export received non-numeric values.",
        call. = FALSE
      )
    }

    numeric_pvalue[missing_text] <- NA_real_
  } else {
    numeric_pvalue <- suppressWarnings(as.numeric(pvalue))
  }

  invalid <- !is.na(numeric_pvalue) & (
    !is.finite(numeric_pvalue) |
      numeric_pvalue < 0 |
      numeric_pvalue > 1
  )

  if (any(invalid)) {
    stop(
      "GraphML p-values must be finite numbers between 0 and 1.",
      call. = FALSE
    )
  }

  floor_applied <- !is.na(numeric_pvalue) &
    numeric_pvalue < CANCERPPIR_GRAPHML_PVALUE_FLOOR

  safe_pvalue <- numeric_pvalue
  safe_pvalue[floor_applied] <- CANCERPPIR_GRAPHML_PVALUE_FLOOR

  list(
    value = safe_pvalue,
    floor_applied = floor_applied,
    floor_value = CANCERPPIR_GRAPHML_PVALUE_FLOOR
  )
}

# write_readable_xlsx - extracted from cancerppir.R lines 1214-1269
##############################################################################
write_readable_xlsx <- function(path, sheets) {
  # Stable Excel writer for CancerPPIr.
  # IMPORTANT: no manual post-processing of the XLSX zip archive is performed here.
  # Earlier compatibility-repair code could introduce invalid relationships in Excel files.
  # openxlsx::saveWorkbook() is therefore used as the single source of truth.
  wb <- createWorkbook()
  header_style <- createStyle(textDecoration = "bold", fgFill = "#D9EAF7", border = "Bottom")
  wrap_style <- createStyle(wrapText = TRUE, valign = "top")

  used_names <- character(0)
  for (nm in names(sheets)) {
    sheet_name <- sanitize_sheet_name(nm)
    original_sheet_name <- sheet_name
    k <- 1L
    while (sheet_name %in% used_names) {
      suffix <- paste0("_", k)
      sheet_name <- paste0(substr(original_sheet_name, 1L, 31L - nchar(suffix)), suffix)
      k <- k + 1L
    }
    used_names <- c(used_names, sheet_name)

    x <- as_output_table(sheets[[nm]])
    x[] <- lapply(x, function(col) {
      if (is.list(col)) {
        vapply(col, function(v) paste(as.character(v), collapse = ";"), character(1))
      } else {
        col
      }
    })
    x <- as_tibble(x)

    addWorksheet(wb, sheet_name, gridLines = TRUE)
    writeData(wb, sheet_name, x)

    if (ncol(x) > 0L) {
      addStyle(wb, sheet_name, header_style, rows = 1, cols = seq_len(ncol(x)), gridExpand = TRUE, stack = TRUE)
      addStyle(wb, sheet_name, wrap_style, rows = seq_len(nrow(x) + 1L), cols = seq_len(ncol(x)), gridExpand = TRUE, stack = TRUE)
      freezePane(wb, sheet_name, firstActiveRow = 2, firstActiveCol = 1)
      addFilter(wb, sheet_name, row = 1, cols = seq_len(ncol(x)))
      setColWidths(wb, sheet_name, cols = seq_len(ncol(x)), widths = "auto")
    }
  }

  ok <- tryCatch({
    saveWorkbook(wb, path, overwrite = TRUE)
    TRUE
  }, error = function(e) {
    stop("Could not write Excel workbook: ", path, "\nReason: ", conditionMessage(e), call. = FALSE)
  })

  if (!ok || !file.exists(path) || file.info(path)$size <= 0) {
    stop("Excel workbook was not created correctly: ", path, call. = FALSE)
  }

  invisible(TRUE)
}

