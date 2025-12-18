# Integration Test: EPM Real Data
#
# Tests the full analysis pipeline with real Elevated Plus Maze (EPM) data
# from DeepLabCut tracking output

library(testthat)

# Find package root
find_pkg_root <- function() {
  if (dir.exists("R") && dir.exists("tests")) {
    return(getwd())
  }
  # Walk up to find package root
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
source(file.path(pkg_root, "R/core/coordinate_transforms.R"))
source(file.path(pkg_root, "R/core/preprocessing.R"))
source(file.path(pkg_root, "R/core/quality_checks.R"))
source(file.path(pkg_root, "R/metrics/zone_analysis.R"))
source(file.path(pkg_root, "R/metrics/time_in_zone.R"))
source(file.path(pkg_root, "R/utils/config_utils.R"))

# Test EPM data loading
test_that("EPM real data files load correctly", {
  epm_dir <- file.path(pkg_root, "data/EPM/Example DLC Data")

  skip_if(!dir.exists(epm_dir), "EPM data directory not found")

  epm_files <- list.files(epm_dir, pattern = "\\.csv$", full.names = TRUE)

  skip_if(length(epm_files) == 0, "No EPM CSV files found")

  cat("\nTesting", length(epm_files), "EPM data files\n")

  for (file_path in epm_files) {
    cat("  Loading:", basename(file_path), "\n")

    tracking_data <- convert_dlc_to_tracking_data(
      file_path,
      fps = 30,
      paradigm = "epm"
    )

    # Basic validation
    expect_s3_class(tracking_data, "tracking_data")
    expect_gt(nrow(tracking_data$tracking), 0)
    expect_true("mouse_center" %in% unique(tracking_data$tracking$body_part))

    cat("    - Frames:", nrow(tracking_data$tracking) / length(unique(tracking_data$tracking$body_part)), "\n")
    cat("    - Body parts:", length(unique(tracking_data$tracking$body_part)), "\n")
  }
})

# Test EPM data quality
test_that("EPM real data quality checks work", {
  epm_dir <- file.path(pkg_root, "data/EPM/Example DLC Data")
  skip_if(!dir.exists(epm_dir), "EPM data directory not found")

  epm_files <- list.files(epm_dir, pattern = "\\.csv$", full.names = TRUE)
  skip_if(length(epm_files) == 0, "No EPM CSV files found")

  # Test with first file
  tracking_data <- convert_dlc_to_tracking_data(
    epm_files[1],
    fps = 30,
    paradigm = "epm"
  )

  cat("\nQuality check for:", basename(epm_files[1]), "\n")

  # Run quality checks
  quality <- check_tracking_quality(tracking_data, body_parts = "mouse_center")

  expect_true(is.list(quality))
  expect_true("overall" %in% names(quality))
  expect_true("likelihood" %in% names(quality))
  expect_true("missing_data" %in% names(quality))

  # Extract metrics for mouse_center
  mouse_quality <- quality$likelihood[quality$likelihood$body_part == "mouse_center", ]

  cat("  - Mean likelihood:", round(mouse_quality$mean_likelihood, 3), "\n")
  cat("  - Missing data:", quality$missing_data$n_missing[quality$missing_data$body_part == "mouse_center"], "frames\n")
  if (length(quality$recommendations) > 0) {
    cat("  - Recommendations:", quality$recommendations[1], "\n")
  }
})

# Test EPM zone analysis with arena configuration
test_that("EPM zone analysis works with real data and arena config", {
  epm_dir <- file.path(pkg_root, "data/EPM/Example DLC Data")
  arena_config_path <- file.path(pkg_root, "config/arena_definitions/EPM/EPM.yaml")

  skip_if(!dir.exists(epm_dir), "EPM data directory not found")
  skip_if(!file.exists(arena_config_path), "EPM arena config not found")

  epm_files <- list.files(epm_dir, pattern = "\\.csv$", full.names = TRUE)
  skip_if(length(epm_files) == 0, "No EPM CSV files found")

  # Load arena configuration
  arena <- load_arena_configs(arena_config_path, arena_id = "arena1")
  expect_s3_class(arena, "arena_config")

  # Load tracking data
  tracking_data <- convert_dlc_to_tracking_data(
    epm_files[1],
    fps = 30,
    paradigm = "epm"
  )

  cat("\nZone analysis for:", basename(epm_files[1]), "\n")

  # Calculate zone occupancy
  occupancy <- calculate_zone_occupancy(
    tracking_data,
    arena,
    body_part = "mouse_center"
  )

  expect_true(is.data.frame(occupancy))
  expect_true("zone_id" %in% colnames(occupancy))
  expect_true("time_seconds" %in% colnames(occupancy))
  expect_true("percentage" %in% colnames(occupancy))

  # Check that we have expected EPM zones
  zones <- unique(occupancy$zone_id)
  cat("  - Zones found:", paste(zones, collapse = ", "), "\n")

  # Print occupancy summary
  for (i in 1:nrow(occupancy)) {
    cat(sprintf("    %s: %.1f%% (%.1fs)\n",
                occupancy$zone_id[i],
                occupancy$percentage[i],
                occupancy$time_seconds[i]))
  }
})

# Test EPM time in zone metrics
test_that("EPM time in zone metrics work with real data", {
  epm_dir <- file.path(pkg_root, "data/EPM/Example DLC Data")
  arena_config_path <- file.path(pkg_root, "config/arena_definitions/EPM/EPM.yaml")

  skip_if(!dir.exists(epm_dir), "EPM data directory not found")
  skip_if(!file.exists(arena_config_path), "EPM arena config not found")

  epm_files <- list.files(epm_dir, pattern = "\\.csv$", full.names = TRUE)
  skip_if(length(epm_files) == 0, "No EPM CSV files found")

  # Load data and config
  arena <- load_arena_configs(arena_config_path, arena_id = "arena1")
  tracking_data <- convert_dlc_to_tracking_data(epm_files[1], fps = 30)

  cat("\nTime in zone metrics for:", basename(epm_files[1]), "\n")

  # Test entries
  entries <- calculate_zone_entries(tracking_data, arena, body_part = "mouse_center")
  expect_true(is.data.frame(entries))
  expect_true("zone_id" %in% colnames(entries))
  expect_true("n_entries" %in% colnames(entries))

  cat("  Entries per zone:\n")
  for (i in 1:nrow(entries)) {
    cat(sprintf("    %s: %d entries (mean duration: %.1fs)\n",
                entries$zone_id[i],
                entries$n_entries[i],
                entries$mean_duration[i]))
  }

  # Test latency
  latency <- calculate_zone_latency(tracking_data, arena, body_part = "mouse_center")
  expect_true(is.data.frame(latency))
  expect_true("zone_id" %in% colnames(latency))
  expect_true("latency_seconds" %in% colnames(latency))

  cat("  Latency to first entry:\n")
  for (i in 1:nrow(latency)) {
    cat(sprintf("    %s: %.1fs\n",
                latency$zone_id[i],
                latency$latency_seconds[i]))
  }

  # Test transitions
  transitions <- calculate_zone_transitions(tracking_data, arena, body_part = "mouse_center")
  expect_true(is.data.frame(transitions))
  expect_true("from_zone" %in% colnames(transitions))
  expect_true("to_zone" %in% colnames(transitions))
  expect_true("n_transitions" %in% colnames(transitions))

  total_transitions <- sum(transitions$n_transitions)
  cat(sprintf("  Total transitions: %d\n", total_transitions))
})

# Test full EPM analysis pipeline
test_that("Full EPM analysis pipeline works end-to-end", {
  epm_dir <- file.path(pkg_root, "data/EPM/Example DLC Data")
  arena_config_path <- file.path(pkg_root, "config/arena_definitions/EPM/EPM.yaml")

  skip_if(!dir.exists(epm_dir), "EPM data directory not found")
  skip_if(!file.exists(arena_config_path), "EPM arena config not found")

  epm_files <- list.files(epm_dir, pattern = "\\.csv$", full.names = TRUE)
  skip_if(length(epm_files) == 0, "No EPM CSV files found")

  cat("\n=== FULL EPM ANALYSIS PIPELINE ===\n")
  cat("Subject:", basename(epm_files[1]), "\n\n")

  # Step 1: Load data
  cat("1. Loading DLC tracking data...\n")
  tracking_data <- convert_dlc_to_tracking_data(
    epm_files[1],
    fps = 30,
    subject_id = "TEST_EPM",
    paradigm = "epm"
  )
  expect_s3_class(tracking_data, "tracking_data")
  cat("   ✓ Loaded", nrow(tracking_data$tracking) / length(unique(tracking_data$tracking$body_part)), "frames\n\n")

  # Step 2: Quality checks
  cat("2. Running quality checks...\n")
  quality <- check_tracking_quality(tracking_data, body_parts = "mouse_center")
  mouse_quality <- quality$likelihood[quality$likelihood$body_part == "mouse_center", ]
  mouse_missing <- quality$missing_data[quality$missing_data$body_part == "mouse_center", ]
  cat(sprintf("   ✓ Mean likelihood: %.2f\n", mouse_quality$mean_likelihood))
  cat(sprintf("   ✓ Missing frames: %d (%.1f%%)\n",
              mouse_missing$n_missing,
              mouse_missing$percent_missing))
  cat("\n")

  # Step 3: Load arena configuration
  cat("3. Loading arena configuration...\n")
  arena <- load_arena_configs(arena_config_path, arena_id = "arena1")
  expect_s3_class(arena, "arena_config")
  cat(sprintf("   ✓ Loaded %d zones\n", length(arena$zones)))
  cat("\n")

  # Step 4: Calculate metrics
  cat("4. Calculating zone metrics...\n")
  occupancy <- calculate_zone_occupancy(tracking_data, arena, body_part = "mouse_center")
  entries <- calculate_zone_entries(tracking_data, arena, body_part = "mouse_center")
  latency <- calculate_zone_latency(tracking_data, arena, body_part = "mouse_center")
  transitions <- calculate_zone_transitions(tracking_data, arena, body_part = "mouse_center")

  cat("   ✓ Zone occupancy calculated\n")
  cat("   ✓ Zone entries calculated\n")
  cat("   ✓ Zone latencies calculated\n")
  cat("   ✓ Zone transitions calculated\n\n")

  # Step 5: Summary
  cat("5. Analysis summary:\n")
  cat(sprintf("   - Zones analyzed: %d\n", nrow(occupancy)))
  cat(sprintf("   - Total transitions: %d\n", sum(transitions$n_transitions)))
  cat(sprintf("   - Session duration: %.1fs\n",
              max(tracking_data$tracking$time)))

  # Validate all metrics
  expect_true(all(!is.na(occupancy$percentage)))
  expect_true(all(!is.na(entries$n_entries)))
  expect_true(sum(occupancy$percentage) >= 95)  # Should account for ~100% of time

  cat("\n=== PIPELINE COMPLETE ===\n")
})

cat("\n")
cat("================================================================================\n")
cat("EPM Integration Tests Complete\n")
cat("================================================================================\n")
