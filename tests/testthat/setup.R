# tests/testthat/setup.R
# This file is automatically sourced by testthat before running tests

# Get the package root directory
# Find it by looking for the DESCRIPTION file or R/ directory
find_package_root <- function() {
  # Start from current directory and walk up
  current_dir <- getwd()

  # Check if we're already in package root
  if (dir.exists(file.path(current_dir, "R")) &&
      dir.exists(file.path(current_dir, "tests"))) {
    return(current_dir)
  }

  # Walk up directories looking for package root
  max_levels <- 5
  for (i in 1:max_levels) {
    parent_dir <- dirname(current_dir)
    if (dir.exists(file.path(parent_dir, "R")) &&
        dir.exists(file.path(parent_dir, "tests"))) {
      return(parent_dir)
    }
    if (parent_dir == current_dir) break  # Reached root
    current_dir <- parent_dir
  }

  # Fallback: assume standard layout
  return(normalizePath(file.path(getwd(), "../..")))
}

pkg_root <- find_package_root()

# Source all R files needed for tests
source_files <- c(
  # Core data structures and I/O
  "R/core/data_structures.R",
  "R/core/data_loading.R",
  "R/core/data_converters.R",

  # Arena and geometry
  "R/core/arena_config.R",
  "R/core/zone_geometry.R",
  "R/core/coordinate_transforms.R",

  # Analysis functions
  "R/core/preprocessing.R",
  "R/core/quality_checks.R",

  # Metrics
  "R/metrics/zone_analysis.R",
  "R/metrics/time_in_zone.R",
  "R/metrics/movement_metrics.R",

  # Reporting and Visualization
  "R/reporting/generate_report.R",
  "R/visualization/plot_tracking.R",

  # Utilities
  "R/utils/config_utils.R"
)

# Source each file with full path from package root
files_loaded <- 0
for (file in source_files) {
  full_path <- file.path(pkg_root, file)
  if (file.exists(full_path)) {
    source(full_path)
    files_loaded <- files_loaded + 1
  } else {
    warning(sprintf("File not found: %s", full_path))
  }
}

# Inform user
message("DLCAnalyzer test environment loaded successfully")
message(sprintf("  - %d/%d R source files loaded", files_loaded, length(source_files)))
message(sprintf("  - Package root: %s", pkg_root))
