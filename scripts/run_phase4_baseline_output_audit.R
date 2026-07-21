#!/usr/bin/env Rscript

# CancerPPIr Phase 4: baseline audit of current A01 output files
#
# This script performs a read-only characterization audit of:
#   1. the analytical workbook;
#   2. the technical workbook;
#   3. the Cytoscape GraphML network;
#   4. the STRING-link text file.
#
# It does not modify analytical code or any input/output file.
#
# Default invocation from the repository root:
#
#   Rscript scripts/run_phase4_baseline_output_audit.R
#
# Optional positional arguments:
#
#   1 analytical_xlsx
#   2 technical_xlsx
#   3 graphml_file
#   4 string_link_file
#   5 audit_output_dir
#   6 sample_id
#
# Example:
#
#   Rscript scripts/run_phase4_baseline_output_audit.R ^
#     "..\results\phase2_architecture_final\Genes_A\CancerPPIr_Analytical_Report.xlsx" ^
#     "..\results\phase2_architecture_final\Genes_A\CancerPPIr_Technical_Report.xlsx" ^
#     "..\results\phase2_architecture_final\Genes_A\Network_for_Cytoscape.graphml" ^
#     "..\results\phase2_architecture_final\Genes_A\STRING_links.txt" ^
#     "..\results\phase4_a01_baseline_audit" ^
#     "A01"

required_packages <- c(
  "openxlsx",
  "igraph"
)

missing_packages <- required_packages[
  !vapply(
    required_packages,
    requireNamespace,
    FUN.VALUE = logical(1),
    quietly = TRUE
  )
]

if (length(missing_packages) > 0L) {
  stop(
    paste0(
      "Required package(s) are not installed: ",
      paste(missing_packages, collapse = ", "),
      "."
    ),
    call. = FALSE
  )
}

arguments <- commandArgs(
  trailingOnly = TRUE
)

default_case_dir <- file.path(
  "..",
  "results",
  "phase2_architecture_final",
  "Genes_A"
)

analytical_xlsx <- if (length(arguments) >= 1L) {
  arguments[[1L]]
} else {
  file.path(
    default_case_dir,
    "CancerPPIr_Analytical_Report.xlsx"
  )
}

technical_xlsx <- if (length(arguments) >= 2L) {
  arguments[[2L]]
} else {
  file.path(
    default_case_dir,
    "CancerPPIr_Technical_Report.xlsx"
  )
}

graphml_file <- if (length(arguments) >= 3L) {
  arguments[[3L]]
} else {
  file.path(
    default_case_dir,
    "Network_for_Cytoscape.graphml"
  )
}

string_link_file <- if (length(arguments) >= 4L) {
  arguments[[4L]]
} else {
  file.path(
    default_case_dir,
    "STRING_links.txt"
  )
}

audit_output_dir <- if (length(arguments) >= 5L) {
  arguments[[5L]]
} else {
  file.path(
    "..",
    "results",
    "phase4_a01_baseline_audit"
  )
}

sample_id <- if (length(arguments) >= 6L) {
  arguments[[6L]]
} else {
  "A01"
}

input_files <- c(
  analytical_xlsx = analytical_xlsx,
  technical_xlsx = technical_xlsx,
  graphml_file = graphml_file,
  string_link_file = string_link_file
)

missing_input_files <- input_files[
  !file.exists(input_files)
]

if (length(missing_input_files) > 0L) {
  stop(
    paste0(
      "The following required audit input files were not found:\n",
      paste0(
        "- ",
        names(missing_input_files),
        ": ",
        missing_input_files,
        collapse = "\n"
      ),
      "\n\nSupply explicit file paths as positional arguments."
    ),
    call. = FALSE
  )
}

if (dir.exists(audit_output_dir)) {
  existing_files <- list.files(
    audit_output_dir,
    all.files = TRUE,
    no.. = TRUE
  )

  if (length(existing_files) > 0L) {
    stop(
      paste0(
        "Audit output directory already exists and is not empty: ",
        audit_output_dir,
        "\nRemove it or provide a different fifth argument."
      ),
      call. = FALSE
    )
  }
}

dir.create(
  audit_output_dir,
  recursive = TRUE,
  showWarnings = FALSE
)

normalize_header <- function(x) {
  x <- enc2utf8(as.character(x))
  x <- tolower(trimws(x))
  gsub(
    "[^a-z0-9]+",
    "",
    x
  )
}

safe_character <- function(x) {
  out <- as.character(x)
  out[is.na(out)] <- ""
  out
}

safe_numeric <- function(x) {
  suppressWarnings(
    as.numeric(
      gsub(
        ",",
        ".",
        as.character(x),
        fixed = TRUE
      )
    )
  )
}

compact_text <- function(x, max_chars = 200L) {
  x <- paste(
    unique(
      trimws(
        safe_character(x)
      )
    ),
    collapse = "; "
  )

  if (!nzchar(x)) {
    return("")
  }

  if (nchar(x) <= max_chars) {
    return(x)
  }

  paste0(
    substr(
      x,
      1L,
      max_chars - 3L
    ),
    "..."
  )
}

write_csv_safe <- function(x, path) {
  utils::write.csv(
    x,
    file = path,
    row.names = FALSE,
    na = ""
  )
}

issues <- list()

add_issue <- function(
  severity,
  category,
  check_id,
  status,
  file_scope,
  location,
  finding,
  evidence,
  recommendation
) {
  issues[[length(issues) + 1L]] <<- data.frame(
    severity = severity,
    category = category,
    check_id = check_id,
    status = status,
    file_scope = file_scope,
    location = location,
    finding = finding,
    evidence = evidence,
    recommendation = recommendation,
    stringsAsFactors = FALSE
  )

  invisible(NULL)
}

read_workbook_safely <- function(path, workbook_name) {
  sheet_names <- tryCatch(
    openxlsx::getSheetNames(path),
    error = function(e) {
      add_issue(
        severity = "P0",
        category = "xlsx_integrity",
        check_id = paste0(
          workbook_name,
          "_get_sheet_names"
        ),
        status = "FAIL",
        file_scope = workbook_name,
        location = basename(path),
        finding = "The workbook could not be opened by openxlsx.",
        evidence = conditionMessage(e),
        recommendation = "Repair the OOXML package and add independent workbook-open tests."
      )
      character()
    }
  )

  sheets <- list()

  for (sheet_name in sheet_names) {
    sheets[[sheet_name]] <- tryCatch(
      openxlsx::read.xlsx(
        path,
        sheet = sheet_name,
        check.names = FALSE,
        detectDates = FALSE
      ),
      error = function(e) {
        add_issue(
          severity = "P0",
          category = "xlsx_integrity",
          check_id = paste0(
            workbook_name,
            "_read_",
            normalize_header(sheet_name)
          ),
          status = "FAIL",
          file_scope = workbook_name,
          location = sheet_name,
          finding = "A worksheet could not be read by openxlsx.",
          evidence = conditionMessage(e),
          recommendation = "Repair workbook relationships and worksheet metadata."
        )
        NULL
      }
    )
  }

  list(
    path = path,
    sheet_names = sheet_names,
    sheets = sheets
  )
}

resolve_relationship_target <- function(
  extracted_root,
  relationship_file,
  target
) {
  relative_relationship_file <- gsub(
    "\\\\",
    "/",
    substring(
      normalizePath(
        relationship_file,
        winslash = "/",
        mustWork = TRUE
      ),
      nchar(
        normalizePath(
          extracted_root,
          winslash = "/",
          mustWork = TRUE
        )
      ) + 2L
    )
  )

  source_directory <- sub(
    "/_rels/.*$",
    "",
    relative_relationship_file
  )

  if (startsWith(target, "/")) {
    candidate <- file.path(
      extracted_root,
      substring(target, 2L)
    )
  } else {
    candidate <- file.path(
      extracted_root,
      source_directory,
      target
    )
  }

  normalizePath(
    candidate,
    winslash = "/",
    mustWork = FALSE
  )
}

audit_xlsx_relationships <- function(path, workbook_name) {
  extraction_directory <- tempfile(
    pattern = paste0(
      "phase4_",
      workbook_name,
      "_"
    )
  )

  dir.create(
    extraction_directory,
    recursive = TRUE,
    showWarnings = FALSE
  )

  on.exit(
    unlink(
      extraction_directory,
      recursive = TRUE,
      force = TRUE
    ),
    add = TRUE
  )

  unzip_status <- tryCatch(
    {
      utils::unzip(
        path,
        exdir = extraction_directory
      )
      TRUE
    },
    error = function(e) {
      add_issue(
        severity = "P0",
        category = "xlsx_integrity",
        check_id = paste0(
          workbook_name,
          "_zip_extraction"
        ),
        status = "FAIL",
        file_scope = workbook_name,
        location = basename(path),
        finding = "The XLSX ZIP package could not be extracted.",
        evidence = conditionMessage(e),
        recommendation = "Regenerate the workbook as a valid OOXML ZIP package."
      )
      FALSE
    }
  )

  if (!isTRUE(unzip_status)) {
    return(
      data.frame(
        workbook = workbook_name,
        relationship_file = character(),
        relationship_id = character(),
        target = character(),
        resolved_target = character(),
        target_exists = logical(),
        stringsAsFactors = FALSE
      )
    )
  }

  relationship_files <- list.files(
    extraction_directory,
    pattern = "\\.rels$",
    recursive = TRUE,
    full.names = TRUE
  )

  relationship_rows <- list()

  for (relationship_file in relationship_files) {
    xml_text <- paste(
      readLines(
        relationship_file,
        warn = FALSE,
        encoding = "UTF-8"
      ),
      collapse = ""
    )

    relationship_tags <- regmatches(
      xml_text,
      gregexpr(
        "<Relationship\\b[^>]+>",
        xml_text,
        perl = TRUE
      )
    )[[1L]]

    if (
      length(relationship_tags) == 1L &&
      identical(
        relationship_tags,
        character(0)
      )
    ) {
      next
    }

    for (relationship_tag in relationship_tags) {
      get_attribute <- function(attribute_name) {
        pattern <- paste0(
          attribute_name,
          '="([^"]*)"'
        )

        match <- regexec(
          pattern,
          relationship_tag,
          perl = TRUE
        )

        values <- regmatches(
          relationship_tag,
          match
        )[[1L]]

        if (length(values) >= 2L) {
          values[[2L]]
        } else {
          ""
        }
      }

      relationship_id <- get_attribute("Id")
      target <- get_attribute("Target")
      target_mode <- get_attribute("TargetMode")

      if (
        !nzchar(target) ||
        identical(
          target_mode,
          "External"
        )
      ) {
        next
      }

      resolved_target <- resolve_relationship_target(
        extraction_directory,
        relationship_file,
        target
      )

      relationship_rows[[length(relationship_rows) + 1L]] <- data.frame(
        workbook = workbook_name,
        relationship_file = substring(
          normalizePath(
            relationship_file,
            winslash = "/",
            mustWork = TRUE
          ),
          nchar(
            normalizePath(
              extraction_directory,
              winslash = "/",
              mustWork = TRUE
            )
          ) + 2L
        ),
        relationship_id = relationship_id,
        target = target,
        resolved_target = substring(
          resolved_target,
          nchar(
            normalizePath(
              extraction_directory,
              winslash = "/",
              mustWork = TRUE
            )
          ) + 2L
        ),
        target_exists = file.exists(resolved_target),
        stringsAsFactors = FALSE
      )
    }
  }

  if (!length(relationship_rows)) {
    relationship_table <- data.frame(
      workbook = workbook_name,
      relationship_file = character(),
      relationship_id = character(),
      target = character(),
      resolved_target = character(),
      target_exists = logical(),
      stringsAsFactors = FALSE
    )
  } else {
    relationship_table <- do.call(
      rbind,
      relationship_rows
    )
  }

  missing_targets <- relationship_table[
    !relationship_table$target_exists,
    ,
    drop = FALSE
  ]

  if (nrow(missing_targets) > 0L) {
    add_issue(
      severity = "P0",
      category = "xlsx_integrity",
      check_id = paste0(
        workbook_name,
        "_missing_relationship_targets"
      ),
      status = "FAIL",
      file_scope = workbook_name,
      location = basename(path),
      finding = paste0(
        "The workbook contains ",
        nrow(missing_targets),
        " internal OOXML relationship target(s) that do not exist."
      ),
      evidence = compact_text(
        paste0(
          missing_targets$relationship_file,
          " -> ",
          missing_targets$target
        ),
        max_chars = 500L
      ),
      recommendation = "Regenerate worksheets without orphan drawing/VML relationships and add a package-integrity test."
    )
  } else {
    add_issue(
      severity = "INFO",
      category = "xlsx_integrity",
      check_id = paste0(
        workbook_name,
        "_missing_relationship_targets"
      ),
      status = "PASS",
      file_scope = workbook_name,
      location = basename(path),
      finding = "All internal OOXML relationship targets exist.",
      evidence = paste0(
        nrow(relationship_table),
        " internal relationships checked."
      ),
      recommendation = "Keep this check in the permanent output test suite."
    )
  }

  relationship_table
}

analytical <- read_workbook_safely(
  analytical_xlsx,
  "analytical_workbook"
)

technical <- read_workbook_safely(
  technical_xlsx,
  "technical_workbook"
)

analytical_relationships <- audit_xlsx_relationships(
  analytical_xlsx,
  "analytical_workbook"
)

technical_relationships <- audit_xlsx_relationships(
  technical_xlsx,
  "technical_workbook"
)

sheet_inventory_rows <- list()

inventory_workbook <- function(workbook, workbook_name) {
  for (sheet_name in workbook$sheet_names) {
    data <- workbook$sheets[[sheet_name]]

    if (is.null(data)) {
      next
    }

    headers <- names(data)
    normalized_headers <- normalize_header(headers)

    duplicate_headers <- headers[
      duplicated(normalized_headers) |
      duplicated(
        normalized_headers,
        fromLast = TRUE
      )
    ]

    sheet_inventory_rows[[length(sheet_inventory_rows) + 1L]] <<- data.frame(
      workbook = workbook_name,
      sheet = sheet_name,
      rows = nrow(data),
      columns = ncol(data),
      empty_sheet = nrow(data) == 0L || ncol(data) == 0L,
      duplicate_normalized_headers = compact_text(
        duplicate_headers
      ),
      stringsAsFactors = FALSE
    )

    if (length(duplicate_headers) > 0L) {
      add_issue(
        severity = "P1",
        category = "schema",
        check_id = paste0(
          workbook_name,
          "_",
          normalize_header(sheet_name),
          "_duplicate_headers"
        ),
        status = "FAIL",
        file_scope = workbook_name,
        location = sheet_name,
        finding = "The worksheet contains duplicate column names after normalization.",
        evidence = paste(
          duplicate_headers,
          collapse = "; "
        ),
        recommendation = "Use unique, documented field names in the rebuilt report."
      )
    }
  }
}

inventory_workbook(
  analytical,
  "analytical_workbook"
)

inventory_workbook(
  technical,
  "technical_workbook"
)

sheet_inventory <- if (length(sheet_inventory_rows)) {
  do.call(
    rbind,
    sheet_inventory_rows
  )
} else {
  data.frame(
    workbook = character(),
    sheet = character(),
    rows = integer(),
    columns = integer(),
    empty_sheet = logical(),
    duplicate_normalized_headers = character(),
    stringsAsFactors = FALSE
  )
}

canonicalize_table <- function(data) {
  if (is.null(data)) {
    return(NULL)
  }

  out <- as.data.frame(
    lapply(
      data,
      safe_character
    ),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )

  names(out) <- normalize_header(
    names(out)
  )

  out
}

compare_common_columns <- function(
  first_data,
  second_data,
  first_name,
  second_name
) {
  first <- canonicalize_table(first_data)
  second <- canonicalize_table(second_data)

  if (
    is.null(first) ||
    is.null(second)
  ) {
    return(
      data.frame(
        first_table = first_name,
        second_table = second_name,
        first_rows = NA_integer_,
        second_rows = NA_integer_,
        common_columns = NA_integer_,
        common_cells_compared = NA_integer_,
        identical_common_cells = NA_integer_,
        identical_fraction = NA_real_,
        exact_common_projection_match = FALSE,
        stringsAsFactors = FALSE
      )
    )
  }

  common_columns <- intersect(
    names(first),
    names(second)
  )

  row_count <- min(
    nrow(first),
    nrow(second)
  )

  if (
    length(common_columns) == 0L ||
    row_count == 0L
  ) {
    return(
      data.frame(
        first_table = first_name,
        second_table = second_name,
        first_rows = nrow(first),
        second_rows = nrow(second),
        common_columns = length(common_columns),
        common_cells_compared = 0L,
        identical_common_cells = 0L,
        identical_fraction = NA_real_,
        exact_common_projection_match = FALSE,
        stringsAsFactors = FALSE
      )
    )
  }

  first_projection <- first[
    seq_len(row_count),
    common_columns,
    drop = FALSE
  ]

  second_projection <- second[
    seq_len(row_count),
    common_columns,
    drop = FALSE
  ]

  comparison_matrix <- mapply(
    FUN = function(x, y) {
      x == y
    },
    first_projection,
    second_projection,
    SIMPLIFY = TRUE
  )

  comparison_matrix[is.na(comparison_matrix)] <- FALSE

  identical_cells <- sum(comparison_matrix)
  total_cells <- length(comparison_matrix)

  data.frame(
    first_table = first_name,
    second_table = second_name,
    first_rows = nrow(first),
    second_rows = nrow(second),
    common_columns = length(common_columns),
    common_cells_compared = total_cells,
    identical_common_cells = identical_cells,
    identical_fraction = if (total_cells > 0L) {
      identical_cells / total_cells
    } else {
      NA_real_
    },
    exact_common_projection_match =
      nrow(first) == nrow(second) &&
      identical_cells == total_cells,
    stringsAsFactors = FALSE
  )
}

duplicate_comparisons <- do.call(
  rbind,
  list(
    compare_common_columns(
      analytical$sheets[["All modules"]],
      technical$sheets[["Raw all modules"]],
      "Analytical: All modules",
      "Technical: Raw all modules"
    ),
    compare_common_columns(
      analytical$sheets[["Candidate rationale"]],
      technical$sheets[["Raw node metrics"]],
      "Analytical: Candidate rationale",
      "Technical: Raw node metrics"
    ),
    compare_common_columns(
      analytical$sheets[["Top candidates"]],
      analytical$sheets[["Candidate rationale"]],
      "Analytical: Top candidates",
      "Analytical: Candidate rationale"
    ),
    compare_common_columns(
      technical$sheets[["Raw major modules"]],
      technical$sheets[["Raw all modules"]],
      "Technical: Raw major modules",
      "Technical: Raw all modules"
    )
  )
)

for (row_index in seq_len(nrow(duplicate_comparisons))) {
  comparison <- duplicate_comparisons[
    row_index,
    ,
    drop = FALSE
  ]

  if (
    isTRUE(
      comparison$exact_common_projection_match[[1L]]
    ) ||
    (
      is.finite(
        comparison$identical_fraction[[1L]]
      ) &&
      comparison$identical_fraction[[1L]] >= 0.95
    )
  ) {
    add_issue(
      severity = "P1",
      category = "duplication",
      check_id = paste0(
        "duplicate_",
        row_index
      ),
      status = "FAIL",
      file_scope = "cross_workbook",
      location = paste0(
        comparison$first_table,
        " vs ",
        comparison$second_table
      ),
      finding = "The compared tables contain exact or near-exact duplicated information.",
      evidence = paste0(
        "Common-column cell identity: ",
        round(
          100 * comparison$identical_fraction[[1L]],
          1
        ),
        "%; common columns: ",
        comparison$common_columns[[1L]],
        "."
      ),
      recommendation = "Keep each analytical entity once and separate user-facing summaries from raw technical tables."
    )
  }
}

get_sheet <- function(workbook, name) {
  workbook$sheets[[name]]
}

find_column <- function(data, candidates) {
  if (is.null(data)) {
    return(NA_character_)
  }

  normalized_names <- normalize_header(
    names(data)
  )

  normalized_candidates <- normalize_header(
    candidates
  )

  match_index <- match(
    normalized_candidates,
    normalized_names
  )

  match_index <- match_index[
    !is.na(match_index)
  ]

  if (!length(match_index)) {
    return(NA_character_)
  }

  names(data)[match_index[[1L]]]
}

candidate_rationale <- get_sheet(
  analytical,
  "Candidate rationale"
)

top_candidates <- get_sheet(
  analytical,
  "Top candidates"
)

all_modules <- get_sheet(
  analytical,
  "All modules"
)

major_module_priorities <- get_sheet(
  analytical,
  "Major module priorities"
)

final_priorities <- get_sheet(
  analytical,
  "Final priorities"
)

top_module_enrichment <- get_sheet(
  technical,
  "Top module enrichment"
)

mapping_summary <- get_sheet(
  technical,
  "Mapping summary"
)

raw_node_metrics <- get_sheet(
  technical,
  "Raw node metrics"
)

gene_status <- get_sheet(
  technical,
  "Gene status"
)

if (!is.null(top_module_enrichment)) {
  fdr_column <- find_column(
    top_module_enrichment,
    "fdr"
  )

  if (!is.na(fdr_column)) {
    fdr_values <- safe_numeric(
      top_module_enrichment[[fdr_column]]
    )

    non_significant_rows <- which(
      is.finite(fdr_values) &
      fdr_values > 0.05
    )

    if (length(non_significant_rows) > 0L) {
      add_issue(
        severity = "P0",
        category = "enrichment",
        check_id = "user_facing_non_significant_module_terms",
        status = "FAIL",
        file_scope = "technical_workbook",
        location = "Top module enrichment",
        finding = paste0(
          length(non_significant_rows),
          " user-facing module enrichment row(s) have FDR > 0.05."
        ),
        evidence = paste0(
          "Maximum observed FDR: ",
          format(
            max(
              fdr_values[non_significant_rows],
              na.rm = TRUE
            ),
            digits = 4
          ),
          "."
        ),
        recommendation = "Require both interpretability and statistical significance for user-facing enrichment evidence."
      )
    }
  }
}

audit_pvalue_underflow <- function(data, table_name) {
  if (is.null(data)) {
    return(invisible(NULL))
  }

  pvalue_column <- find_column(
    data,
    c(
      "pvalue",
      "p_value",
      "p.value"
    )
  )

  if (is.na(pvalue_column)) {
    return(invisible(NULL))
  }

  pvalues <- safe_numeric(
    data[[pvalue_column]]
  )

  zero_count <- sum(
    is.finite(pvalues) &
    pvalues == 0
  )

  if (zero_count > 0L) {
    add_issue(
      severity = "P0",
      category = "statistics",
      check_id = paste0(
        normalize_header(table_name),
        "_literal_zero_pvalues"
      ),
      status = "FAIL",
      file_scope = "workbook",
      location = table_name,
      finding = paste0(
        zero_count,
        " p-value(s) are displayed as literal zero."
      ),
      evidence = "A literal zero is normally a numerical underflow or upstream rounding result, not an exact probability.",
      recommendation = "Add pvalue_underflow, a display lower bound, and a documented cap for the candidate-score statistical component."
    )
  }

  invisible(NULL)
}

audit_pvalue_underflow(
  candidate_rationale,
  "Candidate rationale"
)

audit_pvalue_underflow(
  raw_node_metrics,
  "Raw node metrics"
)

special_entity_pattern <- paste0(
  "^(",
  "LOC[0-9]+|",
  "IGH[A-Z0-9-]*|",
  "IGK[A-Z0-9-]*|",
  "IGL[A-Z0-9-]*|",
  "TR[ABDG][A-Z0-9-]*",
  ")$"
)

audit_special_candidates <- function(data, table_name) {
  if (is.null(data)) {
    return(invisible(NULL))
  }

  gene_column <- find_column(
    data,
    c(
      "gene",
      "gene_symbol"
    )
  )

  if (is.na(gene_column)) {
    return(invisible(NULL))
  }

  genes <- toupper(
    safe_character(
      data[[gene_column]]
    )
  )

  special_genes <- unique(
    genes[
      grepl(
        special_entity_pattern,
        genes,
        perl = TRUE
      )
    ]
  )

  special_genes <- special_genes[
    nzchar(special_genes)
  ]

  if (length(special_genes) > 0L) {
    add_issue(
      severity = "P0",
      category = "entity_classification",
      check_id = paste0(
        normalize_header(table_name),
        "_special_entities"
      ),
      status = "FAIL",
      file_scope = "analytical_workbook",
      location = table_name,
      finding = paste0(
        length(special_genes),
        " immunoglobulin, TCR, or LOC entity/entities appear in a candidate-facing table without a guaranteed independent eligibility class."
      ),
      evidence = compact_text(
        special_genes,
        max_chars = 500L
      ),
      recommendation = "Separate STRING mapping status, biological entity class, and candidate eligibility."
    )
  }

  invisible(NULL)
}

audit_special_candidates(
  top_candidates,
  "Top candidates"
)

audit_special_candidates(
  candidate_rationale,
  "Candidate rationale"
)

extract_row_text <- function(data) {
  if (is.null(data) || nrow(data) == 0L) {
    return(character())
  }

  apply(
    as.data.frame(
      lapply(
        data,
        safe_character
      ),
      stringsAsFactors = FALSE,
      check.names = FALSE
    ),
    1L,
    paste,
    collapse = " | "
  )
}

b_plasma_genes <- c(
  "MZB1",
  "JCHAIN",
  "TNFRSF17",
  "IRF4",
  "IGLL5"
)

y_linked_genes <- c(
  "RPS4Y1",
  "EIF1AY",
  "KDM5D",
  "ZFY",
  "DDX3Y",
  "UTY",
  "USP9Y"
)

audit_module_semantics <- function(data, table_name) {
  if (is.null(data)) {
    return(invisible(NULL))
  }

  row_text <- extract_row_text(data)
  lower_text <- tolower(row_text)

  b_plasma_gene_pattern <- paste(
    b_plasma_genes,
    collapse = "|"
  )

  b_plasma_rows <- which(
    grepl(
      b_plasma_gene_pattern,
      row_text,
      ignore.case = TRUE,
      perl = TRUE
    ) &
    grepl(
      "myeloid|phagocyt|macrophage",
      lower_text,
      perl = TRUE
    )
  )

  if (length(b_plasma_rows) > 0L) {
    add_issue(
      severity = "P0",
      category = "biological_interpretation",
      check_id = paste0(
        normalize_header(table_name),
        "_b_plasma_misclassification"
      ),
      status = "FAIL",
      file_scope = "analytical_workbook",
      location = table_name,
      finding = "A module containing strong B-cell/plasma-cell-associated genes is described with a myeloid/phagocytic label.",
      evidence = compact_text(
        row_text[b_plasma_rows],
        max_chars = 700L
      ),
      recommendation = "Add B-cell, plasma-cell, immunoglobulin-secretion and humoral-immunity rules with anti-marker/conflict logic."
    )
  }

  y_gene_pattern <- paste(
    y_linked_genes,
    collapse = "|"
  )

  y_rows <- which(
    grepl(
      y_gene_pattern,
      row_text,
      ignore.case = TRUE,
      perl = TRUE
    )
  )

  if (length(y_rows) > 0L) {
    promoted_or_unresolved <- y_rows[
      grepl(
        "unassigned|priority|major",
        lower_text[y_rows],
        perl = TRUE
      )
    ]

    if (length(promoted_or_unresolved) > 0L) {
      add_issue(
        severity = "P0",
        category = "biological_interpretation",
        check_id = paste0(
          normalize_header(table_name),
          "_y_chromosome_signature"
        ),
        status = "FAIL",
        file_scope = "analytical_workbook",
        location = table_name,
        finding = "A Y-chromosome-associated signature is unresolved or promoted without a technical/covariate classification.",
        evidence = compact_text(
          row_text[promoted_or_unresolved],
          max_chars = 700L
        ),
        recommendation = "Classify Y-linked signatures as technical/covariate and exclude them from automatic biological priority promotion."
      )
    }
  }

  invisible(NULL)
}

audit_module_semantics(
  all_modules,
  "All modules"
)

audit_module_semantics(
  major_module_priorities,
  "Major module priorities"
)

audit_module_semantics(
  final_priorities,
  "Final priorities"
)

if (!is.null(raw_node_metrics)) {
  logfc_column <- find_column(
    raw_node_metrics,
    c(
      "logFC",
      "log2FC",
      "log_fold_change"
    )
  )

  if (!is.na(logfc_column)) {
    logfc_values <- safe_numeric(
      raw_node_metrics[[logfc_column]]
    )

    finite_logfc <- logfc_values[
      is.finite(logfc_values)
    ]

    if (
      length(finite_logfc) > 0L &&
      all(finite_logfc > 0)
    ) {
      add_issue(
        severity = "P0",
        category = "interpretation_boundary",
        check_id = "one_direction_only_input",
        status = "FAIL",
        file_scope = "technical_workbook",
        location = "Raw node metrics",
        finding = "All finite network logFC values are positive.",
        evidence = paste0(
          "Observed logFC range: ",
          format(
            min(finite_logfc),
            digits = 5
          ),
          " to ",
          format(
            max(finite_logfc),
            digits = 5
          ),
          "."
        ),
        recommendation = "State that downregulated programmes cannot be evaluated and avoid unqualified activation language."
      )
    }
  }
}

if (!is.null(mapping_summary)) {
  metric_column <- find_column(
    mapping_summary,
    "metric"
  )

  value_column <- find_column(
    mapping_summary,
    "value"
  )

  if (
    !is.na(metric_column) &&
    !is.na(value_column)
  ) {
    metrics <- tolower(
      safe_character(
        mapping_summary[[metric_column]]
      )
    )

    values <- safe_numeric(
      mapping_summary[[value_column]]
    )

    input_index <- grep(
      "input",
      metrics
    )

    mapped_index <- grep(
      "mapped|network",
      metrics
    )

    if (
      length(input_index) > 0L &&
      length(mapped_index) > 0L
    ) {
      input_value <- values[
        input_index[[1L]]
      ]

      mapped_candidates <- values[
        mapped_index
      ]

      mapped_candidates <- mapped_candidates[
        is.finite(mapped_candidates) &
        mapped_candidates <= input_value
      ]

      if (
        is.finite(input_value) &&
        length(mapped_candidates) > 0L
      ) {
        mapped_value <- max(
          mapped_candidates,
          na.rm = TRUE
        )

        mapping_fraction <- mapped_value / input_value

        if (is.finite(mapping_fraction) && mapping_fraction < 0.7) {
          add_issue(
            severity = "P1",
            category = "mapping",
            check_id = "low_mapping_coverage",
            status = "WARN",
            file_scope = "technical_workbook",
            location = "Mapping summary",
            finding = "Mapping coverage is below 70%.",
            evidence = paste0(
              mapped_value,
              "/",
              input_value,
              " (",
              round(
                100 * mapping_fraction,
                1
              ),
              "%)."
            ),
            recommendation = "Report mapping limitations prominently and classify unmapped identifiers by reason and entity class."
          )
        }
      }
    }
  }
}

top_list_names <- c(
  "Top candidates",
  "Top degree",
  "Top betweenness",
  "Top stress"
)

top_gene_sets <- list()

for (sheet_name in top_list_names) {
  data <- get_sheet(
    analytical,
    sheet_name
  )

  gene_column <- find_column(
    data,
    "gene"
  )

  if (
    !is.null(data) &&
    !is.na(gene_column)
  ) {
    top_gene_sets[[sheet_name]] <- unique(
      safe_character(
        data[[gene_column]]
      )
    )
  }
}

if (length(top_gene_sets) >= 3L) {
  union_genes <- unique(
    unlist(
      top_gene_sets,
      use.names = FALSE
    )
  )

  universal_genes <- Reduce(
    intersect,
    top_gene_sets
  )

  add_issue(
    severity = "P1",
    category = "duplication",
    check_id = "overlapping_top_rank_lists",
    status = "FAIL",
    file_scope = "analytical_workbook",
    location = paste(
      names(top_gene_sets),
      collapse = "; "
    ),
    finding = "Separate top-degree, top-betweenness, top-stress and candidate sheets substantially overlap.",
    evidence = paste0(
      length(union_genes),
      " unique genes across ",
      length(top_gene_sets),
      " lists; ",
      length(universal_genes),
      " genes occur in every list."
    ),
    recommendation = "Replace the separate sheets with one candidate-priority table containing explicit score components and topology roles."
  )
}

graph <- tryCatch(
  igraph::read_graph(
    graphml_file,
    format = "graphml"
  ),
  error = function(e) {
    add_issue(
      severity = "P0",
      category = "graphml_integrity",
      check_id = "graphml_readback",
      status = "FAIL",
      file_scope = "graphml",
      location = basename(graphml_file),
      finding = "The GraphML file could not be read back by igraph.",
      evidence = conditionMessage(e),
      recommendation = "Regenerate a standards-compliant GraphML and keep a mandatory read-back test."
    )
    NULL
  }
)

graphml_attribute_table <- data.frame(
  attribute_scope = character(),
  attribute_name = character(),
  non_missing_values = integer(),
  unique_values = integer(),
  maximum_text_length = integer(),
  repeated_long_text = logical(),
  stringsAsFactors = FALSE
)

if (!is.null(graph)) {
  add_issue(
    severity = "INFO",
    category = "graphml_integrity",
    check_id = "graphml_readback",
    status = "PASS",
    file_scope = "graphml",
    location = basename(graphml_file),
    finding = "The GraphML file was read successfully by igraph.",
    evidence = paste0(
      igraph::vcount(graph),
      " nodes; ",
      igraph::ecount(graph),
      " edges."
    ),
    recommendation = "Keep read-back validation in the permanent test suite."
  )

  if (!igraph::is_simple(graph)) {
    add_issue(
      severity = "P0",
      category = "graphml_integrity",
      check_id = "graphml_simple_graph",
      status = "FAIL",
      file_scope = "graphml",
      location = basename(graphml_file),
      finding = "The GraphML contains loops or duplicate edges.",
      evidence = "igraph::is_simple returned FALSE.",
      recommendation = "Remove duplicated edges and self-loops before export."
    )
  }

  node_attributes <- igraph::vertex_attr_names(
    graph
  )

  edge_attributes <- igraph::edge_attr_names(
    graph
  )

  for (attribute_name in node_attributes) {
    values <- igraph::vertex_attr(
      graph,
      attribute_name
    )

    character_values <- safe_character(
      values
    )

    non_missing_values <- sum(
      nzchar(character_values)
    )

    unique_values <- length(
      unique(
        character_values[
          nzchar(character_values)
        ]
      )
    )

    maximum_text_length <- if (length(character_values)) {
      max(
        nchar(character_values),
        na.rm = TRUE
      )
    } else {
      0L
    }

    repeated_long_text <-
      maximum_text_length >= 120L &&
      non_missing_values >= 2L &&
      unique_values < non_missing_values

    graphml_attribute_table <- rbind(
      graphml_attribute_table,
      data.frame(
        attribute_scope = "node",
        attribute_name = attribute_name,
        non_missing_values = non_missing_values,
        unique_values = unique_values,
        maximum_text_length = maximum_text_length,
        repeated_long_text = repeated_long_text,
        stringsAsFactors = FALSE
      )
    )
  }

  for (attribute_name in edge_attributes) {
    values <- igraph::edge_attr(
      graph,
      attribute_name
    )

    character_values <- safe_character(
      values
    )

    graphml_attribute_table <- rbind(
      graphml_attribute_table,
      data.frame(
        attribute_scope = "edge",
        attribute_name = attribute_name,
        non_missing_values = sum(
          nzchar(character_values)
        ),
        unique_values = length(
          unique(
            character_values[
              nzchar(character_values)
            ]
          )
        ),
        maximum_text_length = if (length(character_values)) {
          max(
            nchar(character_values),
            na.rm = TRUE
          )
        } else {
          0L
        },
        repeated_long_text = FALSE,
        stringsAsFactors = FALSE
      )
    )
  }

  repeated_long_attributes <- graphml_attribute_table[
    graphml_attribute_table$attribute_scope == "node" &
    graphml_attribute_table$repeated_long_text,
    ,
    drop = FALSE
  ]

  if (
    length(node_attributes) > 25L ||
    nrow(repeated_long_attributes) > 0L
  ) {
    add_issue(
      severity = "P1",
      category = "graphml_architecture",
      check_id = "graphml_attribute_overload",
      status = "FAIL",
      file_scope = "graphml",
      location = basename(graphml_file),
      finding = "The GraphML node schema is overloaded and repeats long module-level text across nodes.",
      evidence = paste0(
        length(node_attributes),
        " node attributes; ",
        nrow(repeated_long_attributes),
        " repeated long-text attribute(s)."
      ),
      recommendation = "Keep visualization-relevant node attributes only and move detailed module rationale to one module-level technical table."
    )
  }
}

string_lines <- readLines(
  string_link_file,
  warn = FALSE,
  encoding = "UTF-8"
)

string_text <- paste(
  string_lines,
  collapse = "\n"
)

url_matches <- regmatches(
  string_text,
  gregexpr(
    "https?://[^[:space:]]+",
    string_text,
    perl = TRUE
  )
)[[1L]]

if (
  length(url_matches) == 1L &&
  identical(
    url_matches,
    character(0)
  )
) {
  url_matches <- character()
}

if (length(url_matches) != 1L) {
  add_issue(
    severity = "P1",
    category = "string_link",
    check_id = "string_link_count",
    status = "FAIL",
    file_scope = "string_link_file",
    location = basename(string_link_file),
    finding = paste0(
      "The STRING-link file contains ",
      length(url_matches),
      " URL(s); exactly one canonical URL is required."
    ),
    evidence = compact_text(
      url_matches,
      max_chars = 600L
    ),
    recommendation = "Output one tested canonical STRING URL plus explicit run metadata and a GraphML note."
  )
} else {
  add_issue(
    severity = "INFO",
    category = "string_link",
    check_id = "string_link_count",
    status = "PASS",
    file_scope = "string_link_file",
    location = basename(string_link_file),
    finding = "The STRING-link file contains one URL.",
    evidence = compact_text(
      url_matches,
      max_chars = 300L
    ),
    recommendation = "Add sample, species, score, identifier count, scope, and GraphML metadata."
  )
}

if (
  length(url_matches) == 1L &&
  !grepl(
    "^https://string-db\\.org/",
    url_matches[[1L]],
    perl = TRUE
  )
) {
  add_issue(
    severity = "P1",
    category = "string_link",
    check_id = "string_link_domain",
    status = "WARN",
    file_scope = "string_link_file",
    location = basename(string_link_file),
    finding = "The URL does not use the canonical string-db.org HTTPS domain.",
    evidence = url_matches[[1L]],
    recommendation = "Use the canonical STRING HTTPS domain."
  )
}

submitted_string_identifiers <- length(
  gregexpr(
    "9606\\.ENSP[0-9]+",
    string_text,
    perl = TRUE
  )[[1L]]
)

filename_sample_tokens <- regmatches(
  basename(input_files),
  regexpr(
    "A0?1",
    basename(input_files),
    ignore.case = TRUE,
    perl = TRUE
  )
)

filename_sample_tokens <- filename_sample_tokens[
  nzchar(filename_sample_tokens)
]

if (
  length(unique(toupper(filename_sample_tokens))) > 1L
) {
  add_issue(
    severity = "P1",
    category = "file_naming",
    check_id = "sample_id_inconsistent",
    status = "FAIL",
    file_scope = "all_outputs",
    location = paste(
      basename(input_files),
      collapse = "; "
    ),
    finding = "Output filenames use inconsistent sample identifiers.",
    evidence = paste(
      unique(filename_sample_tokens),
      collapse = "; "
    ),
    recommendation = "Use one normalized sample ID, such as A01, in every output filename and manifest."
  )
}

if (!is.null(gene_status)) {
  normalized_gene_status_names <- normalize_header(
    names(gene_status)
  )

  if (
    all(
      c(
        "aliascorrection",
        "unmapped"
      ) %in%
      c(
        analytical$sheet_names,
        technical$sheet_names
      )
    )
  ) {
    invisible(NULL)
  }
}

if (
  "Alias corrections" %in% technical$sheet_names &&
  "Unmapped genes" %in% technical$sheet_names &&
  "HGNC normalization" %in% technical$sheet_names
) {
  add_issue(
    severity = "P1",
    category = "mapping_architecture",
    check_id = "overlapping_mapping_audit_sheets",
    status = "FAIL",
    file_scope = "technical_workbook",
    location = "Alias corrections; Unmapped genes; HGNC normalization",
    finding = "Mapping and normalization evidence is split across overlapping sheets.",
    evidence = paste0(
      nrow(
        technical$sheets[["Alias corrections"]]
      ),
      " alias rows; ",
      nrow(
        technical$sheets[["Unmapped genes"]]
      ),
      " unmapped rows; ",
      nrow(
        technical$sheets[["HGNC normalization"]]
      ),
      " normalization rows."
    ),
    recommendation = "Replace the overlapping sheets with one row-per-input Mapping audit table containing status, reason, entity class and warning."
  )
}

issues_table <- if (length(issues)) {
  do.call(
    rbind,
    issues
  )
} else {
  data.frame(
    severity = character(),
    category = character(),
    check_id = character(),
    status = character(),
    file_scope = character(),
    location = character(),
    finding = character(),
    evidence = character(),
    recommendation = character(),
    stringsAsFactors = FALSE
  )
}

severity_order <- c(
  "P0",
  "P1",
  "P2",
  "INFO"
)

status_order <- c(
  "FAIL",
  "WARN",
  "PASS"
)

issues_table$severity <- factor(
  issues_table$severity,
  levels = severity_order
)

issues_table$status <- factor(
  issues_table$status,
  levels = status_order
)

issues_table <- issues_table[
  order(
    issues_table$severity,
    issues_table$status,
    issues_table$category,
    issues_table$check_id
  ),
  ,
  drop = FALSE
]

issues_table$severity <- as.character(
  issues_table$severity
)

issues_table$status <- as.character(
  issues_table$status
)

summary_table <- data.frame(
  sample_id = sample_id,
  audit_timestamp = format(
    Sys.time(),
    "%Y-%m-%d %H:%M:%S %z"
  ),
  analytical_sheet_count = length(
    analytical$sheet_names
  ),
  technical_sheet_count = length(
    technical$sheet_names
  ),
  graph_nodes = if (!is.null(graph)) {
    igraph::vcount(graph)
  } else {
    NA_integer_
  },
  graph_edges = if (!is.null(graph)) {
    igraph::ecount(graph)
  } else {
    NA_integer_
  },
  graph_node_attribute_count = if (!is.null(graph)) {
    length(
      igraph::vertex_attr_names(graph)
    )
  } else {
    NA_integer_
  },
  graph_edge_attribute_count = if (!is.null(graph)) {
    length(
      igraph::edge_attr_names(graph)
    )
  } else {
    NA_integer_
  },
  string_url_count = length(
    url_matches
  ),
  submitted_string_identifier_count =
    submitted_string_identifiers,
  p0_failures = sum(
    issues_table$severity == "P0" &
    issues_table$status == "FAIL"
  ),
  p1_failures = sum(
    issues_table$severity == "P1" &
    issues_table$status == "FAIL"
  ),
  warnings = sum(
    issues_table$status == "WARN"
  ),
  passed_checks = sum(
    issues_table$status == "PASS"
  ),
  overall_status = if (
    any(
      issues_table$severity == "P0" &
      issues_table$status == "FAIL"
    )
  ) {
    "BASELINE_HAS_CRITICAL_ISSUES"
  } else if (
    any(
      issues_table$status %in% c(
        "FAIL",
        "WARN"
      )
    )
  ) {
    "BASELINE_HAS_NONCRITICAL_ISSUES"
  } else {
    "BASELINE_PASSED"
  },
  stringsAsFactors = FALSE
)

write_csv_safe(
  summary_table,
  file.path(
    audit_output_dir,
    "phase_4_a01_baseline_audit_summary.csv"
  )
)

write_csv_safe(
  issues_table,
  file.path(
    audit_output_dir,
    "phase_4_a01_baseline_audit_issues.csv"
  )
)

write_csv_safe(
  sheet_inventory,
  file.path(
    audit_output_dir,
    "phase_4_a01_sheet_inventory.csv"
  )
)

write_csv_safe(
  duplicate_comparisons,
  file.path(
    audit_output_dir,
    "phase_4_a01_duplicate_comparisons.csv"
  )
)

write_csv_safe(
  rbind(
    analytical_relationships,
    technical_relationships
  ),
  file.path(
    audit_output_dir,
    "phase_4_a01_xlsx_relationship_audit.csv"
  )
)

write_csv_safe(
  graphml_attribute_table,
  file.path(
    audit_output_dir,
    "phase_4_a01_graphml_attribute_audit.csv"
  )
)

report_lines <- c(
  "# CancerPPIr Phase 4 — A01 baseline output audit",
  "",
  paste0(
    "**Sample:** ",
    sample_id
  ),
  "",
  paste0(
    "**Audit status:** ",
    summary_table$overall_status[[1L]]
  ),
  "",
  "## Inputs",
  "",
  paste0(
    "- Analytical workbook: `",
    analytical_xlsx,
    "`"
  ),
  paste0(
    "- Technical workbook: `",
    technical_xlsx,
    "`"
  ),
  paste0(
    "- GraphML: `",
    graphml_file,
    "`"
  ),
  paste0(
    "- STRING link file: `",
    string_link_file,
    "`"
  ),
  "",
  "## Summary",
  "",
  paste0(
    "- Analytical sheets: ",
    summary_table$analytical_sheet_count[[1L]]
  ),
  paste0(
    "- Technical sheets: ",
    summary_table$technical_sheet_count[[1L]]
  ),
  paste0(
    "- Graph: ",
    summary_table$graph_nodes[[1L]],
    " nodes, ",
    summary_table$graph_edges[[1L]],
    " edges"
  ),
  paste0(
    "- GraphML node attributes: ",
    summary_table$graph_node_attribute_count[[1L]]
  ),
  paste0(
    "- Critical P0 failures: ",
    summary_table$p0_failures[[1L]]
  ),
  paste0(
    "- P1 failures: ",
    summary_table$p1_failures[[1L]]
  ),
  paste0(
    "- Warnings: ",
    summary_table$warnings[[1L]]
  ),
  "",
  "## Findings",
  ""
)

if (nrow(issues_table) == 0L) {
  report_lines <- c(
    report_lines,
    "No findings were recorded."
  )
} else {
  for (row_index in seq_len(nrow(issues_table))) {
    issue <- issues_table[
      row_index,
      ,
      drop = FALSE
    ]

    report_lines <- c(
      report_lines,
      paste0(
        "### ",
        issue$severity[[1L]],
        " — ",
        issue$check_id[[1L]],
        " — ",
        issue$status[[1L]]
      ),
      "",
      paste0(
        "**Location:** ",
        issue$file_scope[[1L]],
        " / ",
        issue$location[[1L]]
      ),
      "",
      issue$finding[[1L]],
      "",
      paste0(
        "**Evidence:** ",
        issue$evidence[[1L]]
      ),
      "",
      paste0(
        "**Required correction:** ",
        issue$recommendation[[1L]]
      ),
      ""
    )
  }
}

report_lines <- c(
  report_lines,
  "## Interpretation",
  "",
  "This is a characterization baseline. The script intentionally records known defects without modifying output files or returning a non-zero exit code. After each Phase 4 checkpoint, the same audit should be rerun to demonstrate which findings were resolved and which remain.",
  ""
)

writeLines(
  report_lines,
  con = file.path(
    audit_output_dir,
    "phase_4_a01_baseline_audit_report.md"
  ),
  useBytes = TRUE
)

cat(
  "\nPHASE 4 BASELINE OUTPUT AUDIT COMPLETED\n"
)

print(
  summary_table,
  row.names = FALSE
)

cat(
  "\nAudit files written to:\n  ",
  normalizePath(
    audit_output_dir,
    winslash = "/",
    mustWork = TRUE
  ),
  "\n",
  sep = ""
)

cat(
  "\nImportant: this is a baseline characterization audit. Known findings do not produce a non-zero exit code.\n"
)