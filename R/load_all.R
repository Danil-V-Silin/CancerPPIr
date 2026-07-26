# CancerPPIr explicit source-module loader
#
# This loader defines a deterministic module-loading order.
# It does not execute the analytical pipeline.

load_cancerppir_modules <- function(
  project_root = ".",
  envir = parent.frame()
) {
  if (!is.environment(envir)) {
    stop(
      "Argument 'envir' must be an environment.",
      call. = FALSE
    )
  }

  module_files <- file.path(
    "R",
    c(
      "utils.R",
      "input.R",
      "string_mapping.R",
      "enrichment.R",
      "module_labeling.R",
      "biological_evidence_engine.R",
      "biological_evidence_adapter.R",
      "reporting.R",
      "analytical_workbook.R",
      "canonical_annotation_output.R",
      "output_provenance.R",
      "network_analysis.R",
      "pipeline.R"
    )
  )

  module_paths <- file.path(
    project_root,
    module_files
  )

  missing_modules <- module_paths[
    !file.exists(module_paths)
  ]

  if (length(missing_modules) > 0L) {
    stop(
      paste0(
        "CancerPPIr source modules are missing:\n",
        paste(
          paste0("- ", missing_modules),
          collapse = "\n"
        )
      ),
      call. = FALSE
    )
  }

  for (module_path in module_paths) {
    sys.source(
      module_path,
      envir = envir,
      keep.source = TRUE
    )
  }

  normalized_paths <- normalizePath(
    module_paths,
    winslash = "/",
    mustWork = TRUE
  )

  options(
    cancerppir.project_root = normalizePath(
      project_root,
      winslash = "/",
      mustWork = TRUE
    )
  )

  invisible(normalized_paths)
}

