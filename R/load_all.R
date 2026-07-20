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
      "00_utils.R",
      "01_input.R",
      "02_string_mapping.R",
      "03_enrichment.R",
      "04_module_labeling.R",
      "05_reporting.R",
      "06_network_analysis.R",
      "07_pipeline.R"
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

  invisible(normalized_paths)
}

