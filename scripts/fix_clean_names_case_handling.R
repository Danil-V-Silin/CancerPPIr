#!/usr/bin/env Rscript

# Fix case handling in clean_names().
#
# The previous implementation removed uppercase ASCII letters before applying
# tolower(), so headers such as "Gene Symbol", "log2-FC" and "P.Value" became
# "eneymbol", "log2" and "alue". This script lowercases first, then removes
# punctuation and whitespace.
#
# Run from the repository root:
#   Rscript scripts/fix_clean_names_case_handling.R

target_file <- file.path("R", "00_utils.R")

if (!file.exists(target_file)) {
  stop(
    "R/00_utils.R was not found. Run this script from the repository root.",
    call. = FALSE
  )
}

git_status <- system2(
  command = "git",
  args = c("diff", "--quiet", "HEAD", "--", target_file),
  stdout = FALSE,
  stderr = FALSE
)

if (!identical(git_status, 0L)) {
  stop(
    paste0(
      target_file,
      " already differs from HEAD. Inspect or restore it before applying the fix."
    ),
    call. = FALSE
  )
}

read_raw_file <- function(path) {
  connection <- file(path, open = "rb")
  on.exit(close(connection), add = TRUE)

  readBin(
    connection,
    what = "raw",
    n = as.integer(file.info(path)$size)
  )
}

write_raw_file <- function(path, contents) {
  connection <- file(path, open = "wb")
  on.exit(close(connection), add = TRUE)
  writeBin(contents, connection)
  invisible(path)
}

detect_line_ending <- function(raw_contents) {
  text <- rawToChar(raw_contents)

  if (grepl("\r\n", text, fixed = TRUE)) {
    "\r\n"
  } else {
    "\n"
  }
}

get_assignment_name <- function(expression) {
  if (
    !is.call(expression) ||
      length(expression) < 3L ||
      !identical(as.character(expression[[1L]]), "<-")
  ) {
    return(NA_character_)
  }

  target <- expression[[2L]]

  if (!is.symbol(target)) {
    return(NA_character_)
  }

  as.character(target)
}

raw_before <- read_raw_file(target_file)
line_ending <- detect_line_ending(raw_before)
lines <- readLines(
  target_file,
  warn = FALSE,
  encoding = "UTF-8"
)

parsed <- parse(
  file = target_file,
  keep.source = TRUE
)

source_references <- attr(parsed, "srcref")

function_names <- vapply(
  parsed,
  get_assignment_name,
  FUN.VALUE = character(1)
)

matches <- which(function_names == "clean_names")

if (length(matches) != 1L) {
  stop(
    paste0(
      "Expected exactly one clean_names() definition, observed ",
      length(matches),
      "."
    ),
    call. = FALSE
  )
}

source_reference <- source_references[[matches[[1L]]]]
start_line <- as.integer(source_reference[[1L]])
end_line <- as.integer(source_reference[[3L]])

old_block <- lines[start_line:end_line]

expected_fragments <- c(
  'x <- trimws(x)',
  'tolower(gsub("[^a-z0-9]+", "", x))'
)

if (!all(vapply(
  expected_fragments,
  function(fragment) any(grepl(fragment, old_block, fixed = TRUE)),
  FUN.VALUE = logical(1)
))) {
  stop(
    "The current clean_names() body does not match the expected pre-fix implementation.",
    call. = FALSE
  )
}

new_block <- c(
  "clean_names <- function(x) {",
  "  x <- enc2utf8(as.character(x))",
  '  x <- gsub("\\ufeff", "", x, fixed = TRUE)',
  '  x <- gsub("^\\xef\\xbb\\xbf", "", x)',
  "  x <- tolower(trimws(x))",
  '  gsub("[^a-z0-9]+", "", x)',
  "}"
)

new_lines <- c(
  if (start_line > 1L) lines[seq_len(start_line - 1L)] else character(),
  new_block,
  if (end_line < length(lines)) {
    lines[seq.int(end_line + 1L, length(lines))]
  } else {
    character()
  }
)

new_text <- paste0(
  paste(new_lines, collapse = line_ending),
  line_ending
)

temporary_file <- tempfile(fileext = ".R")
write_raw_file(
  temporary_file,
  charToRaw(enc2utf8(new_text))
)

invisible(parse(file = temporary_file))

test_environment <- new.env(parent = baseenv())
sys.source(
  temporary_file,
  envir = test_environment,
  keep.source = TRUE
)

observed <- test_environment$clean_names(
  c(" Gene Symbol ", "log2-FC", "P.Value")
)

expected <- c(
  "genesymbol",
  "log2fc",
  "pvalue"
)

if (!identical(observed, expected)) {
  stop(
    paste0(
      "Post-fix clean_names() validation failed.\n",
      "Observed: ",
      paste(observed, collapse = ", "),
      "\nExpected: ",
      paste(expected, collapse = ", ")
    ),
    call. = FALSE
  )
}

if (!isTRUE(file.copy(
  temporary_file,
  target_file,
  overwrite = TRUE
))) {
  stop(
    "Failed to update R/00_utils.R.",
    call. = FALSE
  )
}

unlink(temporary_file, force = TRUE)

message("[clean_names fix] Fix applied.")
message(
  "[clean_names fix] Updated source lines: ",
  start_line,
  "-",
  end_line,
  "."
)
message(
  "[clean_names fix] Validation: Gene Symbol -> genesymbol; ",
  "log2-FC -> log2fc; P.Value -> pvalue."
)
message("[clean_names fix] No other analytical source files were modified.")