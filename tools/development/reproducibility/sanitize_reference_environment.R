#!/usr/bin/env Rscript

# Replace machine-specific absolute paths in reference environment files
# with portable placeholders before the files are committed to Git.

environment_dir <- "tests/reference/environment"

if (!dir.exists(environment_dir)) {
  stop(
    "Reference environment directory does not exist: ",
    environment_dir,
    call. = FALSE
  )
}

project_root <- normalizePath(
  ".",
  winslash = "/",
  mustWork = TRUE
)

r_home <- normalizePath(
  R.home(),
  winslash = "/",
  mustWork = TRUE
)

user_home_forward <- normalizePath(
  "~",
  winslash = "/",
  mustWork = TRUE
)

user_home_native <- Sys.getenv(
  "USERPROFILE",
  unset = ""
)

replacement_sources <- c(
  project_root,
  r_home,
  user_home_forward,
  user_home_native
)

replacement_targets <- c(
  "<PROJECT_ROOT>",
  "<R_HOME>",
  "<USER_HOME>",
  "<USER_HOME>"
)

valid <- nzchar(replacement_sources)

replacement_sources <- replacement_sources[valid]
replacement_targets <- replacement_targets[valid]

# Replace longer paths first so that PROJECT_ROOT and R_HOME are not
# partially replaced by the shorter USER_HOME path.
replacement_order <- order(
  nchar(replacement_sources),
  decreasing = TRUE
)

replacement_sources <- replacement_sources[replacement_order]
replacement_targets <- replacement_targets[replacement_order]

target_files <- list.files(
  environment_dir,
  pattern = "\\.(csv|txt)$",
  full.names = TRUE
)

for (path in target_files) {
  lines <- readLines(
    path,
    warn = FALSE,
    encoding = "UTF-8"
  )

  for (index in seq_along(replacement_sources)) {
    lines <- gsub(
      replacement_sources[[index]],
      replacement_targets[[index]],
      lines,
      fixed = TRUE
    )
  }

  writeLines(
    lines,
    con = path,
    useBytes = TRUE
  )
}

message(
  "Sanitized ",
  length(target_files),
  " reference environment files."
)

# Additional Windows sanitization pass.
# USERPROFILE may appear with either forward or backward slashes.

user_profile_native <- Sys.getenv(
  "USERPROFILE",
  unset = ""
)

if (nzchar(user_profile_native)) {
  user_profile_variants <- unique(
    c(
      user_profile_native,
      gsub(
        "\\",
        "/",
        user_profile_native,
        fixed = TRUE
      )
    )
  )

  target_files <- list.files(
    environment_dir,
    pattern = "\\.(csv|txt)$",
    full.names = TRUE
  )

  for (path in target_files) {
    lines <- readLines(
      path,
      warn = FALSE,
      encoding = "UTF-8"
    )

    for (user_profile in user_profile_variants) {
      lines <- gsub(
        user_profile,
        "<USER_HOME>",
        lines,
        fixed = TRUE
      )
    }

    writeLines(
      lines,
      con = path,
      useBytes = TRUE
    )
  }
}

message(
  "Windows USERPROFILE paths sanitized."
)
