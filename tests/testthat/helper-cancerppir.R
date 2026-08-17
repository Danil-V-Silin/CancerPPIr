# Shared CancerPPIr test bootstrap.
# Enables both full-suite and standalone test-file execution.

cancerppir_test_project_root <- Sys.getenv(
  "CANCERPPIR_PROJECT_ROOT",
  unset = ""
)

if (!nzchar(cancerppir_test_project_root)) {
  candidate_roots <- c(
    ".",
    file.path("..", "..")
  )

  root_matches <- candidate_roots[
    file.exists(
      file.path(candidate_roots, "R", "load_all.R")
    )
  ]

  if (!length(root_matches)) {
    stop("Could not locate the CancerPPIr project root.", call. = FALSE)
  }

  cancerppir_test_project_root <- root_matches[[1L]]
}

cancerppir_test_project_root <- normalizePath(
  cancerppir_test_project_root,
  winslash = "/",
  mustWork = TRUE
)

Sys.setenv(
  CANCERPPIR_PROJECT_ROOT = cancerppir_test_project_root
)

cancerppir_test_sentinels <- c(
  "run_cancerppir",
  "prepare_candidate_table",
  "build_module_priorities",
  "prepare_graphml_pvalue_export",
  "cancerppir_schema_versions"
)

modules_loaded <- all(
  vapply(
    cancerppir_test_sentinels,
    exists,
    logical(1),
    envir = .GlobalEnv,
    inherits = FALSE
  )
)

if (!modules_loaded) {
  source(
    file.path(
      cancerppir_test_project_root,
      "R",
      "load_all.R"
    ),
    local = .GlobalEnv
  )

  load_cancerppir_modules(
    project_root = cancerppir_test_project_root,
    envir = .GlobalEnv
  )
}

rm(
  cancerppir_test_project_root,
  cancerppir_test_sentinels,
  modules_loaded
)
