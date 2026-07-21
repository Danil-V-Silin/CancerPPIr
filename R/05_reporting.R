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

