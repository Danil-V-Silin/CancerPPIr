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
msg <- function(...) message("[CancerPPIr] ", ...)

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

