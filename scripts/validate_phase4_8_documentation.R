# Static documentation contract for CancerPPIr Phase 4.8.

phase4_8_validate_documentation <- function(
  project_root = normalizePath(
    ".",
    winslash = "/",
    mustWork = TRUE
  )
) {
  add_check <- local({
    checks <- list()
    function(check_id = NULL, condition = NULL, details = "", collect = FALSE) {
      if (isTRUE(collect)) {
        output <- if (length(checks)) do.call(rbind, checks) else data.frame()
        rownames(output) <- NULL
        return(output)
      }
      checks[[length(checks) + 1L]] <<- data.frame(
        check_id = as.character(check_id),
        status = if (isTRUE(condition)) "PASS" else "FAIL",
        details = as.character(details),
        stringsAsFactors = FALSE
      )
      invisible(NULL)
    }
  })

  required_files <- c(
    "README.md",
    "docs/README.md",
    "docs/output_interpretation_guide.md",
    "docs/annotation_rules.md",
    "docs/clinical_interpretation_guide.md",
    "docs/glossary.md",
    "docs/limitations.md",
    "docs/phase4_migration_guide.md",
    "docs/reproducibility_guide.md",
    "examples/minimal_input.csv",
    "examples/README.md",
    "scripts/validate_phase4_8_documentation.R",
    "scripts/run_phase4_8_documentation_checkpoint.R",
    "tests/testthat/test-documentation-contract.R"
  )

  required_paths <- file.path(project_root, required_files)
  missing_files <- required_files[!file.exists(required_paths)]
  add_check(
    "required_user_documentation_exists",
    length(missing_files) == 0L,
    paste(missing_files, collapse = " | ")
  )

  read_utf8 <- function(relative_path) {
    paste(
      readLines(
        file.path(project_root, relative_path),
        warn = FALSE,
        encoding = "UTF-8"
      ),
      collapse = "\n"
    )
  }

  readable_files <- required_files[grepl("\\.(md|R)$", required_files)]
  readable_files <- readable_files[file.exists(file.path(project_root, readable_files))]

  empty_files <- readable_files[vapply(
    readable_files,
    function(path) !nzchar(trimws(read_utf8(path))),
    FUN.VALUE = logical(1)
  )]
  add_check(
    "documentation_files_are_nonempty_utf8_text",
    length(empty_files) == 0L,
    paste(empty_files, collapse = " | ")
  )

  user_docs <- c(
    "README.md",
    "docs/README.md",
    "docs/output_interpretation_guide.md",
    "docs/annotation_rules.md",
    "docs/clinical_interpretation_guide.md",
    "docs/glossary.md",
    "docs/limitations.md",
    "docs/reproducibility_guide.md",
    "examples/README.md"
  )
  user_docs <- user_docs[file.exists(file.path(project_root, user_docs))]
  user_text <- vapply(user_docs, read_utf8, FUN.VALUE = character(1))

  required_output_files <- c(
    "CancerPPIr_Analytical_Report.xlsx",
    "CancerPPIr_Technical_Report.xlsx",
    "Network_for_Cytoscape.graphml",
    "STRING_links.txt",
    "CancerPPIr_Output_Manifest.json",
    "CancerPPIr_Output_Checksums.sha256"
  )
  readme_text <- read_utf8("README.md")
  add_check(
    "readme_documents_all_six_outputs",
    all(vapply(
      required_output_files,
      grepl,
      x = readme_text,
      fixed = TRUE,
      FUN.VALUE = logical(1)
    )),
    paste(required_output_files[!vapply(
      required_output_files,
      grepl,
      x = readme_text,
      fixed = TRUE,
      FUN.VALUE = logical(1)
    )], collapse = " | ")
  )

  expected_sheets <- c(
    "Executive summary",
    "Final priorities",
    "Module priorities",
    "Candidate evidence",
    "Network overview",
    "Methods and limitations"
  )
  output_guide <- read_utf8("docs/output_interpretation_guide.md")
  add_check(
    "current_analytical_sheet_contract_is_documented",
    all(vapply(
      expected_sheets,
      grepl,
      x = paste(readme_text, output_guide, sep = "\n"),
      fixed = TRUE,
      FUN.VALUE = logical(1)
    )),
    paste(expected_sheets, collapse = " | ")
  )

  expected_versions <- c(
    pipeline_result = "4.7.0",
    biological_evidence = "1.0.0",
    analytical_workbook = "4.5.0",
    technical_workbook = "4.4.0",
    graphml = "4.6.0",
    output_manifest = "1.0.0",
    output_checksums = "1.0.0"
  )
  reproducibility_text <- read_utf8("docs/reproducibility_guide.md")
  add_check(
    "schema_versions_are_documented",
    all(vapply(
      unname(expected_versions),
      grepl,
      x = reproducibility_text,
      fixed = TRUE,
      FUN.VALUE = logical(1)
    )),
    paste(names(expected_versions), expected_versions, sep = "=", collapse = "; ")
  )

  stale_patterns <- c(
    "CancerPPIr_final_v8_offline.R",
    "biological_evidence_shadow",
    "Major module priorities",
    "Candidate rationale",
    "Graph summary"
  )
  stale_hits <- character()
  for (path in user_docs) {
    text <- read_utf8(path)
    hits <- stale_patterns[vapply(
      stale_patterns,
      grepl,
      x = text,
      fixed = TRUE,
      FUN.VALUE = logical(1)
    )]
    if (length(hits)) {
      stale_hits <- c(stale_hits, paste0(path, ": ", hits))
    }
  }
  add_check(
    "stale_public_terms_are_absent",
    length(stale_hits) == 0L,
    paste(stale_hits, collapse = " | ")
  )

  actionability_statement <- paste(user_text, collapse = "\n")
  add_check(
    "clinical_non_actionability_is_explicit",
    grepl("not proof of therapeutic actionability", actionability_statement, fixed = TRUE) ||
      grepl("does not establish therapeutic efficacy", actionability_statement, fixed = TRUE),
    "Candidate ranking must be separated from therapeutic actionability."
  )

  # Validate local Markdown links in public user documentation.
  link_failures <- character()
  for (relative_path in user_docs) {
    lines <- readLines(
      file.path(project_root, relative_path),
      warn = FALSE,
      encoding = "UTF-8"
    )
    links <- unlist(regmatches(
      lines,
      gregexpr("\\[[^]]+\\]\\(([^)]+)\\)", lines, perl = TRUE)
    ))
    if (!length(links)) next
    targets <- sub("^.*\\(([^)]+)\\)$", "\\1", links, perl = TRUE)
    targets <- sub("#.*$", "", targets)
    targets <- targets[
      nzchar(targets) &
        !grepl("^(https?|mailto):", targets, ignore.case = TRUE)
    ]
    for (target in targets) {
      resolved <- normalizePath(
        file.path(dirname(file.path(project_root, relative_path)), target),
        winslash = "/",
        mustWork = FALSE
      )
      if (!file.exists(resolved)) {
        link_failures <- c(link_failures, paste0(relative_path, " -> ", target))
      }
    }
  }
  add_check(
    "internal_markdown_links_resolve",
    length(link_failures) == 0L,
    paste(link_failures, collapse = " | ")
  )

  example_path <- file.path(project_root, "examples", "minimal_input.csv")
  example_valid <- FALSE
  example_details <- "missing"
  if (file.exists(example_path)) {
    example <- tryCatch(
      utils::read.csv(example_path, stringsAsFactors = FALSE, check.names = FALSE),
      error = identity
    )
    if (!inherits(example, "error")) {
      example_valid <- identical(names(example), c("pvalue", "logFC", "gene")) &&
        nrow(example) >= 10L &&
        all(is.finite(as.numeric(example$pvalue))) &&
        all(as.numeric(example$pvalue) > 0 & as.numeric(example$pvalue) <= 1) &&
        all(is.finite(as.numeric(example$logFC))) &&
        all(!is.na(example$gene) & nzchar(trimws(as.character(example$gene)))) &&
        !anyDuplicated(as.character(example$gene))
      example_details <- paste0("rows=", nrow(example), "; columns=", paste(names(example), collapse = " | "))
    } else {
      example_details <- conditionMessage(example)
    }
  }
  add_check("synthetic_example_matches_input_contract", example_valid, example_details)

  stale_example_outputs <- c(
    "examples/output/CancerPPIr_Analytical_Report.xlsx",
    "examples/output/CancerPPIr_Technical_Report.xlsx",
    "examples/output/Network_for_Cytoscape.graphml",
    "examples/output/STRING_links.txt"
  )
  existing_stale_outputs <- stale_example_outputs[file.exists(file.path(project_root, stale_example_outputs))]
  add_check(
    "stale_generated_example_outputs_are_not_versioned",
    length(existing_stale_outputs) == 0L,
    paste(existing_stale_outputs, collapse = " | ")
  )

  cli_path <- file.path(project_root, "cancerppir.R")
  cli_text <- if (file.exists(cli_path)) read_utf8("cancerppir.R") else ""
  add_check(
    "cli_help_contract_is_present",
    grepl("--help", cli_text, fixed = TRUE) &&
      grepl("Rscript cancerppir.R", cli_text, fixed = TRUE) &&
      all(vapply(required_output_files, grepl, x = cli_text, fixed = TRUE, FUN.VALUE = logical(1))),
    "CLI must expose current invocation and output inventory."
  )

  add_check(collect = TRUE)
}
