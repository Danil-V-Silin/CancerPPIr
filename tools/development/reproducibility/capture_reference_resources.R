#!/usr/bin/env Rscript

# Record the input files and local STRING resources used for
# CancerPPIr legacy regression testing.
#
# Run this script from the root of the CancerPPIr repository.

required_project_files <- c(
  "cancerppir.R",
  "legacy/cancerppir_legacy.R"
)

missing_project_files <- required_project_files[
  !file.exists(required_project_files)
]

if (length(missing_project_files) > 0L) {
  stop(
    paste0(
      "Run this script from the CancerPPIr project root. Missing files: ",
      paste(missing_project_files, collapse = ", ")
    ),
    call. = FALSE
  )
}

output_dir <- "tests/reference/environment"

dir.create(
  output_dir,
  recursive = TRUE,
  showWarnings = FALSE
)

# -------------------------------------------------------------------------
# 1. Reference input files
# -------------------------------------------------------------------------

reference_inputs <- c(
  A01 = "../input/Genes_A.csv",
  K01 = "../input/Genes_K.csv",
  L01 = "../input/Genes_L.csv",
  M01 = "../input/Genes_M.csv",
  P01 = "../input/Genes_P01.csv",
  P02 = "../input/Genes_P02.csv",
  R01 = "../input/Genes_R.csv"
)

selection_reason <- c(
  A01 = "Full clinical baseline: colorectal cancer case A01",
  K01 = "Full clinical baseline: colorectal cancer case K01",
  L01 = "Full clinical baseline: colorectal cancer case L01",
  M01 = "Full clinical baseline: lung cancer case M01",
  P01 = "Full clinical baseline: small-cell lung cancer case P01",
  P02 = "Full clinical baseline: metastatic ovarian cancer case P02",
  R01 = "Full clinical baseline: collecting duct carcinoma case R01"
)

missing_inputs <- reference_inputs[
  !file.exists(reference_inputs)
]

if (length(missing_inputs) > 0L) {
  stop(
    paste0(
      "Missing reference input files: ",
      paste(missing_inputs, collapse = ", ")
    ),
    call. = FALSE
  )
}

input_information <- file.info(reference_inputs)

input_manifest <- data.frame(
  sample_id = names(reference_inputs),
  file_name = basename(reference_inputs),
  relative_path = unname(reference_inputs),
  selection_reason = unname(
    selection_reason[names(reference_inputs)]
  ),
  size_bytes = input_information$size,
  line_count = vapply(
    reference_inputs,
    function(path) {
      length(readLines(path, warn = FALSE))
    },
    FUN.VALUE = integer(1)
  ),
  md5 = unname(
    tools::md5sum(reference_inputs)
  ),
  stringsAsFactors = FALSE
)

utils::write.csv(
  input_manifest,
  file.path(
    output_dir,
    "reference_inputs.csv"
  ),
  row.names = FALSE,
  na = ""
)

# -------------------------------------------------------------------------
# 2. Local STRING resources
# -------------------------------------------------------------------------

string_resources <- file.path(
  "../string_cache",
  c(
    "9606.protein.aliases.v12.0.txt.gz",
    "9606.protein.enrichment.terms.v12.0.txt.gz",
    "9606.protein.info.v12.0.txt.gz",
    "9606.protein.links.full.v12.0.txt.gz",
    "9606.protein.links.v12.0.txt.gz"
  )
)

missing_string_resources <- string_resources[
  !file.exists(string_resources)
]

if (length(missing_string_resources) > 0L) {
  stop(
    paste0(
      "Missing STRING resources: ",
      paste(missing_string_resources, collapse = ", ")
    ),
    call. = FALSE
  )
}

string_information <- file.info(string_resources)

message("Calculating checksums for local STRING resources.")

string_manifest <- data.frame(
  file_name = basename(string_resources),
  relative_path = unname(string_resources),
  size_bytes = string_information$size,
  modified_time = format(
    string_information$mtime,
    "%Y-%m-%d %H:%M:%S %z"
  ),
  md5 = unname(
    tools::md5sum(string_resources)
  ),
  stringsAsFactors = FALSE
)

utils::write.csv(
  string_manifest,
  file.path(
    output_dir,
    "string_cache_manifest.csv"
  ),
  row.names = FALSE,
  na = ""
)

# -------------------------------------------------------------------------
# 3. Summary validation
# -------------------------------------------------------------------------

if (anyDuplicated(input_manifest$md5)) {
  warning(
    "Two or more reference input files have identical MD5 checksums.",
    call. = FALSE
  )
}

if (anyDuplicated(string_manifest$md5)) {
  warning(
    "Two or more STRING resources have identical MD5 checksums.",
    call. = FALSE
  )
}

message(
  "Reference resource manifests written to: ",
  normalizePath(
    output_dir,
    winslash = "/",
    mustWork = TRUE
  )
)
