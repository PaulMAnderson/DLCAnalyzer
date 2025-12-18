# Integration Test: LD Real Data
#
# Tests the full analysis pipeline with real Light/Dark Box (LD) data
# from DeepLabCut tracking output
#
# NOTE: Currently only Excel files are available for LD.
#       This test will be activated when DLC CSV files are available.

library(testthat)

# Find package root
find_pkg_root <- function() {
  if (dir.exists("R") && dir.exists("tests")) return(getwd())
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

# Source required files
source(file.path(pkg_root, "R/core/data_structures.R"))
source(file.path(pkg_root, "R/core/data_loading.R"))
source(file.path(pkg_root, "R/core/data_converters.R"))
source(file.path(pkg_root, "R/core/arena_config.R"))
source(file.path(pkg_root, "R/core/zone_geometry.R"))
source(file.path(pkg_root, "R/utils/config_utils.R"))
source(file.path(pkg_root, "R/metrics/zone_analysis.R"))

test_that("LD data directory exists", {
  ld_dir <- file.path(pkg_root, "data/LD")
  skip_if(!dir.exists(ld_dir), "LD data directory not found")

  csv_files <- list.files(ld_dir, pattern = "\\.csv$", full.names = TRUE, recursive = TRUE)

  if (length(csv_files) == 0) {
    skip("No LD DLC CSV files found - only Excel files available")
  }

  cat("\nFound", length(csv_files), "LD CSV files\n")
})

test_that("LD arena configuration exists", {
  arena_dir <- file.path(pkg_root, "config/arena_definitions/LD")
  skip_if(!dir.exists(arena_dir), "LD arena definition directory not found")

  arena_files <- list.files(arena_dir, pattern = "\\.yaml$", full.names = TRUE)
  skip_if(length(arena_files) == 0, "No LD arena configuration files found")

  cat("\nFound LD arena configurations:\n")
  for (arena_file in arena_files) {
    cat("  -", basename(arena_file), "\n")
    arena <- load_arena_configs(arena_file)
    expect_s3_class(arena, "arena_config")
  }
})

cat("\n")
cat("================================================================================\n")
cat("LD Integration Tests Complete\n")
cat("Note: Tests skipped - waiting for DLC CSV data\n")
cat("================================================================================\n")
