# Integration Test: OFT Real Data
#
# Tests the full analysis pipeline with real Open Field Test (OFT) data
# from DeepLabCut tracking output
#
# NOTE: Currently only Excel files are available for OFT.
#       This test will be activated when DLC CSV files are available.

library(testthat)

# Find package root
find_pkg_root <- function() {
  if (dir.exists("R") && dir.exists("tests")) {
    return(getwd())
  }
  current_dir <- getwd()
  for (i in 1:5) {
    parent_dir <- dirname(current_dir)
    if (dir.exists(file.path(parent_dir, "R")) &&
        dir.exists(file.path(parent_dir, "tests"))) {
      return(parent_dir)
    }
    if (parent_dir == current_dir) break
    current_dir <- parent_dir
  }
  return(getwd())
}

pkg_root <- find_pkg_root()

# Source required R files
source(file.path(pkg_root, "R/core/data_structures.R"))
source(file.path(pkg_root, "R/core/data_loading.R"))
source(file.path(pkg_root, "R/core/data_converters.R"))
source(file.path(pkg_root, "R/core/arena_config.R"))
source(file.path(pkg_root, "R/core/zone_geometry.R"))
source(file.path(pkg_root, "R/utils/config_utils.R"))
source(file.path(pkg_root, "R/metrics/zone_analysis.R"))
source(file.path(pkg_root, "R/metrics/time_in_zone.R"))

# Test OFT data loading
test_that("OFT data files exist and can be found", {
  oft_dir <- file.path(pkg_root, "data/OFT")

  skip_if(!dir.exists(oft_dir), "OFT data directory not found")

  # Look for DLC CSV files
  csv_files <- list.files(oft_dir, pattern = "\\.csv$", full.names = TRUE, recursive = TRUE)

  if (length(csv_files) == 0) {
    skip("No OFT DLC CSV files found - only Excel files available")
  }

  cat("\nFound", length(csv_files), "OFT CSV files\n")

  # If we get here, CSV files are available
  for (file_path in csv_files) {
    tracking_data <- convert_dlc_to_tracking_data(
      file_path,
      fps = 30,
      paradigm = "open_field"
    )

    expect_s3_class(tracking_data, "tracking_data")
    expect_gt(nrow(tracking_data$tracking), 0)
  }
})

# Test OFT arena configuration
test_that("OFT arena configuration exists and loads correctly", {
  # Check for arena config files
  arena_dir <- file.path(pkg_root, "config/arena_definitions/OF")

  skip_if(!dir.exists(arena_dir), "OF arena definition directory not found")

  arena_files <- list.files(arena_dir, pattern = "\\.yaml$", full.names = TRUE)

  skip_if(length(arena_files) == 0, "No OF arena configuration files found")

  cat("\nFound OF arena configurations:\n")
  for (arena_file in arena_files) {
    cat("  -", basename(arena_file), "\n")
    arena <- load_arena_configs(arena_file)
    expect_s3_class(arena, "arena_config")
  }
})

# Test OFT zone analysis (when data becomes available)
test_that("OFT zone analysis works with real data", {
  oft_csv_dir <- file.path(pkg_root, "data/OFT")
  arena_config_path <- file.path(pkg_root, "config/arena_definitions/OF")

  # Look for CSV files
  csv_files <- list.files(oft_csv_dir, pattern = "\\.csv$", full.names = TRUE, recursive = TRUE)

  skip_if(length(csv_files) == 0, "No OFT DLC CSV files available yet")

  # Look for arena config
  arena_files <- list.files(arena_config_path, pattern = "\\.yaml$", full.names = TRUE)

  skip_if(length(arena_files) == 0, "No OF arena configuration found")

  # Load and analyze
  tracking_data <- convert_dlc_to_tracking_data(csv_files[1], fps = 30)
  arena <- load_arena_configs(arena_files[1])

  # Expected OFT zones: center and periphery
  occupancy <- calculate_zone_occupancy(tracking_data, arena, body_part = "mouse_center")

  expect_true(is.data.frame(occupancy))
  expect_true("zone_id" %in% colnames(occupancy))

  # OFT typically has 'center' and 'periphery' zones
  zones <- unique(occupancy$zone_id)
  cat("\nOFT zones found:", paste(zones, collapse = ", "), "\n")
})

cat("\n")
cat("================================================================================\n")
cat("OFT Integration Tests Complete\n")
cat("Note: Most tests skipped - waiting for DLC CSV data\n")
cat("================================================================================\n")
