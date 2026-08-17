# CancerPPIr: Shared utilities
#
# Dependency-light validation, normalization, numeric, ranking and shared text helpers.
#
#
# The function bodies below were extracted from cancerppir.R without semantic rewriting.

##############################################################################
check_package <- function(pkg) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    stop(
      "Package '", pkg, "' is not installed. ",
      "Install it before running CancerPPIr.",
      call. = FALSE
    )
  }
}

##############################################################################
parse_bool <- function(x) {
  tolower(trimws(x)) %in% c("1", "true", "t", "yes", "y")
}

##############################################################################
is_bool_like <- function(x) {
  tolower(trimws(x)) %in% c("1", "0", "true", "false", "t", "f", "yes", "no", "y", "n")
}

##############################################################################
normalize_enrichment_mode <- function(x) {
  x <- tolower(trimws(as.character(x)))
  if (!length(x) || is.na(x) || !nzchar(x)) {
    return("offline")
  }
  x <- gsub("-", "_", x, fixed = TRUE)
  x <- dplyr::case_when(
    x %in% c("offline", "local", "local_only", "reproducible") ~ "offline",
    x %in% c("online", "online_validation", "validation", "validate", "online_validate", "online_validation_mode") ~ "online_validation",
    TRUE ~ x
  )
  if (!x %in% c("offline", "online_validation")) {
    stop(
      "Invalid enrichment_mode: ", x,
      ". Use 'offline' or 'online_validation'.",
      call. = FALSE
    )
  }
  x
}

##############################################################################
normalize_path_for_compare <- function(x) {
  gsub("\\", "/", as.character(x), fixed = TRUE)
}

##############################################################################
cancerppir_elapsed_label <- function(
  started_at = getOption(
    "cancerppir.progress_started_at",
    default = NULL
  )
) {
  if (
    is.null(started_at) ||
      length(started_at) != 1L ||
      is.na(started_at) ||
      !inherits(started_at, "POSIXt")
  ) {
    return("")
  }

  elapsed_seconds <- max(
    0,
    floor(
      as.numeric(
        difftime(
          Sys.time(),
          started_at,
          units = "secs"
        )
      )
    )
  )

  hours <- elapsed_seconds %/% 3600L
  minutes <- (elapsed_seconds %% 3600L) %/% 60L
  seconds <- elapsed_seconds %% 60L

  sprintf(
    "[+%02d:%02d:%02d] ",
    hours,
    minutes,
    seconds
  )
}

##############################################################################
cancerppir_log_has_completion_marker <- function(log_lines) {
  log_lines <- as.character(log_lines)
  log_lines <- log_lines[!is.na(log_lines)]

  if (!length(log_lines)) {
    return(FALSE)
  }

  any(
    grepl(
      paste0(
        "^\\[CancerPPIr\\]",
        "(?: \\[\\+[0-9]+:[0-9]{2}:[0-9]{2}\\])?",
        " Done\\.$"
      ),
      log_lines,
      perl = TRUE
    )
  )
}

##############################################################################
msg <- function(...) {
  message(
    "[CancerPPIr] ",
    cancerppir_elapsed_label(),
    ...
  )
}

##############################################################################
cancerppir_validate_case_id <- function(case_id) {
  case_id <- as.character(case_id)

  valid <- length(case_id) == 1L &&
    !is.na(case_id) &&
    grepl(
      "^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$",
      case_id
    ) &&
    !grepl("\\.$", case_id)

  windows_device_name <- if (isTRUE(valid)) {
    toupper(sub("\\..*$", "", case_id)) %in%
      c(
        "CON",
        "PRN",
        "AUX",
        "NUL",
        paste0("COM", 1:9),
        paste0("LPT", 1:9)
      )
  } else {
    FALSE
  }

  valid <- isTRUE(valid) && !windows_device_name

  if (!isTRUE(valid)) {
    stop(
      paste(
        "case_id must contain 1-64 ASCII characters, start with a",
        "letter or digit, use only letters, digits, '.', '_' or '-',",
        "not end in '.', and not use a reserved Windows device name."
      ),
      call. = FALSE
    )
  }

  case_id
}

##############################################################################
cancerppir_resolve_case_id <- function(
  input_file,
  case_id = NULL
) {
  if (!is.null(case_id)) {
    return(
      list(
        value = cancerppir_validate_case_id(case_id),
        source = "explicit_case_id"
      )
    )
  }

  derived <- tools::file_path_sans_ext(
    basename(input_file)
  )
  derived <- gsub("[<>:\"/\\|?*]+", "_", derived)
  derived <- trimws(derived)

  if (!nzchar(derived) || derived %in% c(".", "..")) {
    stop(
      paste(
        "Could not derive a valid case ID from the input filename.",
        "Supply an explicit pseudonymous case_id."
      ),
      call. = FALSE
    )
  }

  list(
    value = derived,
    source = "legacy_input_basename"
  )
}

##############################################################################
cancerppir_resolve_output_directory <- function(
  results_root,
  case_id,
  preserve_legacy_variant_redirect = FALSE
) {
  results_root_cmp <- normalize_path_for_compare(
    results_root
  )
  results_root_base <- basename(results_root_cmp)
  results_root_parent <- dirname(results_root_cmp)

  if (identical(results_root_base, case_id)) {
    return(results_root)
  }

  if (
    isTRUE(preserve_legacy_variant_redirect) &&
      startsWith(results_root_base, paste0(case_id, "_")) &&
      basename(results_root_parent) %in%
        c("results", "result", "reults")
  ) {
    return(file.path(results_root_parent, case_id))
  }

  file.path(results_root, case_id)
}

##############################################################################
as_number <- function(x) {
  suppressWarnings(as.numeric(gsub(",", ".", as.character(x), fixed = TRUE)))
}

##############################################################################
clean_names <- function(x) {
  x <- enc2utf8(as.character(x))
  x <- gsub("\ufeff", "", x, fixed = TRUE)
  x <- gsub("^\xef\xbb\xbf", "", x)
  x <- tolower(trimws(x))
  gsub("[^a-z0-9]+", "", x)
}

##############################################################################
find_column <- function(nm, candidates) {
  hit <- which(nm %in% candidates)
  if (length(hit)) hit[[1]] else NA_integer_
}

##############################################################################
safe_min <- function(x) {
  x <- x[is.finite(x)]
  if (length(x)) min(x) else NA_real_
}

##############################################################################
safe_mean <- function(x) {
  x <- x[is.finite(x)]
  if (length(x)) mean(x) else NA_real_
}

##############################################################################
minmax <- function(x) {
  x <- as.numeric(x)
  ok <- is.finite(x)

  if (!any(ok)) {
    return(rep(NA_real_, length(x)))
  }

  rng <- range(x[ok], na.rm = TRUE)
  if (diff(rng) == 0) {
    out <- rep(0, length(x))
    out[ok] <- 1
    out[!ok] <- NA_real_
    return(out)
  }

  out <- (x - rng[[1]]) / diff(rng)
  out[!ok] <- NA_real_
  out
}

##############################################################################
top_genes <- function(genes, score, n = 10L) {
  keep <- !is.na(genes) & nzchar(genes)
  genes <- genes[keep]
  score <- score[keep]

  if (!length(genes)) {
    return(NA_character_)
  }

  genes <- genes[order(score, decreasing = TRUE, na.last = TRUE)]
  paste(unique(head(genes, n)), collapse = ";")
}

##############################################################################
collapse_terms <- function(x, n = 3L) {
  if (is.null(x) || !nrow(x) || !("term_name" %in% names(x))) {
    return(NA_character_)
  }

  x <- x %>% arrange(p_value)
  paste(head(unique(x$term_name), n), collapse = "; ")
}

##############################################################################
truncate_text <- function(x, max_chars = 500L) {
  x <- as.character(x)
  x[is.na(x)] <- ""
  too_long <- nchar(x, type = "chars", allowNA = FALSE, keepNA = FALSE) > max_chars
  x[too_long] <- paste0(substr(x[too_long], 1L, max_chars - 3L), "...")
  x
}

##############################################################################
normalize_label_text <- function(x) {
  x <- as.character(x)
  x[is.na(x) | !nzchar(x)] <- "unassigned_module"
  x
}

##############################################################################
humanize_label <- function(x) {
  x <- normalize_label_text(x)
  x <- gsub("_module$", "", x)
  x <- gsub("_", " ", x)
  x <- gsub("MHC class II antigen presentation", "MHC class II antigen presentation", x, fixed = TRUE)
  x
}

##############################################################################
rank_desc <- function(x) {
  dplyr::min_rank(dplyr::desc(x))
}

##############################################################################
evidence_level <- function(x) {
  out <- rep(NA_character_, length(x))
  ok <- is.finite(x)
  if (!any(ok)) {
    return(out)
  }
  vals <- x[ok]
  q50 <- as.numeric(stats::quantile(vals, 0.50, na.rm = TRUE, names = FALSE))
  q75 <- as.numeric(stats::quantile(vals, 0.75, na.rm = TRUE, names = FALSE))
  q90 <- as.numeric(stats::quantile(vals, 0.90, na.rm = TRUE, names = FALSE))
  out[ok] <- dplyr::case_when(
    vals >= q90 ~ "very_high_top_10_percent",
    vals >= q75 ~ "high_top_25_percent",
    vals >= q50 ~ "medium_above_median",
    TRUE ~ "low_below_median"
  )
  out
}

##############################################################################
`%||%` <- function(x, y) {
  if (is.null(x) || length(x) == 0L || all(is.na(x))) y else x
}

##############################################################################
metric_value <- function(tbl, metric_name) {
  idx <- match(metric_name, tbl$metric)
  if (is.na(idx)) {
    return(NA_character_)
  }
  as.character(tbl$value[[idx]])
}
