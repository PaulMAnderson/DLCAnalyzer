# Tests for EPM Pipeline
# Phase 4: Elevated Plus Maze Analysis

library(testthat)

# Test data setup
test_csv <- "data/EPM/Example DLC Data/EPM 20250930/ID7687_superanimal_topviewmouse_snapshot-hrnet_w32-004_snapshot-fasterrcnn_resnet50_fpn_v2-004_.csv"

# ==============================================================================
# EPM Data Loading Tests
# ==============================================================================

test_that("load_epm_data loads DLC CSV correctly", {
  skip_if_not(file.exists(test_csv), "Test CSV file not found")

  epm_data <- load_epm_data(
    test_csv,
    fps = 25,
    pixels_per_cm = 5.3,
    body_part = "mouse_center",
    likelihood_threshold = 0.9
  )

  # Check structure
  expect_type(epm_data, "list")
  expect_true("data" %in% names(epm_data))
  expect_true("subject_id" %in% names(epm_data))
  expect_true("fps" %in% names(epm_data))

  # Check data frame columns
  df <- epm_data$data
  expect_true("frame" %in% names(df))
  expect_true("time" %in% names(df))
  expect_true("x" %in% names(df))
  expect_true("y" %in% names(df))
  expect_true("zone_open_arms" %in% names(df))
  expect_true("zone_closed_arms" %in% names(df))
  expect_true("zone_center" %in% names(df))
  expect_true("arm_id" %in% names(df))

  # Check data types
  expect_type(df$frame, "integer")
  expect_type(df$x, "double")
  expect_type(df$y, "double")
  expect_type(df$zone_open_arms, "double")
})


test_that("define_epm_zones calculates zones correctly", {
  # Create test coordinates
  # Center at origin
  x <- c(0, 0, 0, 20, -20, 0, 0)
  y <- c(0, 20, -20, 0, 0, 30, -30)

  arena_config <- list(
    arm_length = 40,
    arm_width = 5,
    center_size = 10,
    open_arms = c("north", "south"),
    closed_arms = c("east", "west")
  )

  zones <- define_epm_zones(x, y, arena_config)

  # Check structure
  expect_type(zones, "list")
  expect_true("zone_open_arms" %in% names(zones))
  expect_true("zone_closed_arms" %in% names(zones))
  expect_true("zone_center" %in% names(zones))
  expect_true("arm_id" %in% names(zones))

  # Check zone assignments
  expect_equal(zones$zone_center[1], 1)      # Origin is in center
  expect_equal(zones$zone_open_arms[2], 1)   # North (positive y)
  expect_equal(zones$zone_open_arms[3], 1)   # South (negative y)
  expect_equal(zones$zone_closed_arms[4], 1) # East (positive x)
  expect_equal(zones$zone_closed_arms[5], 1) # West (negative x)

  # Check no overlaps
  for (i in 1:length(x)) {
    zones_sum <- zones$zone_open_arms[i] +
                 zones$zone_closed_arms[i] +
                 zones$zone_center[i]
    expect_lte(zones_sum, 1)  # At most one zone active
  }
})


test_that("extract_subject_id parses filenames correctly", {
  # Test different filename patterns
  expect_match(extract_subject_id("ID7687_model_config.csv"), "ID7687")
  expect_match(extract_subject_id("Subject_1_tracking.csv"), "Subject")
  expect_match(extract_subject_id("Mouse_A_behavior.csv"), "Mouse")
})


test_that("validate_epm_data catches invalid data", {
  # Create invalid data (overlapping zones)
  invalid_data <- list(
    data = data.frame(
      frame = 1:10,
      time = (1:10) / 25,
      x = rnorm(10),
      y = rnorm(10),
      zone_open_arms = c(1, 1, 0, 0, 0, 0, 0, 0, 0, 0),
      zone_closed_arms = c(1, 0, 1, 0, 0, 0, 0, 0, 0, 0),  # Overlaps with open!
      zone_center = c(0, 0, 0, 1, 0, 0, 0, 0, 0, 0),
      arm_id = c("north", "north", "east", "center", rep("none", 6))
    ),
    subject_id = "test",
    fps = 25
  )

  # Should throw error due to overlap
  expect_error(validate_epm_data(invalid_data), "overlap")
})


# ==============================================================================
# EPM Analysis Tests
# ==============================================================================

test_that("calculate_open_arm_ratio computes correctly", {
  # Test cases
  expect_equal(calculate_open_arm_ratio(50, 150), 0.25)
  expect_equal(calculate_open_arm_ratio(100, 100), 0.50)
  expect_equal(calculate_open_arm_ratio(120, 60), 2/3, tolerance = 0.001)

  # Edge case: never entered arms
  expect_true(is.na(calculate_open_arm_ratio(0, 0)))

  # Error handling
  expect_error(calculate_open_arm_ratio(-10, 50), "negative")
})


test_that("calculate_entries_ratio computes correctly", {
  # Test cases
  expect_equal(calculate_entries_ratio(3, 12), 0.20)
  expect_equal(calculate_entries_ratio(6, 6), 0.50)
  expect_equal(calculate_entries_ratio(10, 5), 2/3, tolerance = 0.001)

  # Edge case: no entries
  expect_true(is.na(calculate_entries_ratio(0, 0)))

  # Error handling
  expect_error(calculate_entries_ratio(-1, 10), "negative")
})


test_that("analyze_epm returns all required metrics", {
  skip_if_not(file.exists(test_csv), "Test CSV file not found")

  epm_data <- load_epm_data(test_csv, fps = 25, pixels_per_cm = 5.3)
  results <- analyze_epm(epm_data)

  # Check structure
  expect_type(results, "list")

  # Check required metrics exist
  required_metrics <- c(
    "time_in_open_arms_sec", "time_in_closed_arms_sec", "time_in_center_sec",
    "pct_time_in_open", "pct_time_in_closed", "pct_time_in_center",
    "open_arm_ratio", "entries_ratio",
    "entries_to_open", "entries_to_closed", "entries_to_center",
    "total_arm_entries", "latency_to_open_sec",
    "total_distance_cm", "avg_velocity_cm_s",
    "distance_in_open_cm", "distance_in_closed_cm",
    "total_duration_sec", "sufficient_exploration"
  )

  for (metric in required_metrics) {
    expect_true(metric %in% names(results),
                info = paste("Missing metric:", metric))
  }

  # Check value ranges
  expect_gte(results$open_arm_ratio, 0)
  expect_lte(results$open_arm_ratio, 1)
  expect_gte(results$entries_ratio, 0)
  expect_lte(results$entries_ratio, 1)
  expect_gte(results$total_arm_entries, 0)
  expect_gte(results$total_distance_cm, 0)

  # Check percentages sum reasonably (allowing for rounding and "outside" time)
  pct_sum <- results$pct_time_in_open +
             results$pct_time_in_closed +
             results$pct_time_in_center
  expect_gte(pct_sum, 0)
  expect_lte(pct_sum, 100)
})


test_that("interpret_epm_anxiety categorizes correctly", {
  # High anxiety
  expect_match(interpret_epm_anxiety(0.10, total_entries = 10), "High")

  # Moderate
  expect_match(interpret_epm_anxiety(0.30, total_entries = 10), "Moderate")

  # Low anxiety
  expect_match(interpret_epm_anxiety(0.60, total_entries = 10), "Low")

  # Insufficient exploration
  expect_match(interpret_epm_anxiety(0.40, total_entries = 3), "Insufficient")

  # No exploration
  expect_match(interpret_epm_anxiety(NA, total_entries = 0), "No arm")
})


# ==============================================================================
# EPM Batch Processing Tests
# ==============================================================================

test_that("analyze_epm_batch processes multiple subjects", {
  skip_if_not(file.exists(test_csv), "Test CSV file not found")

  # Create a small batch (just duplicate the same file for testing)
  epm_data1 <- load_epm_data(test_csv, fps = 25, pixels_per_cm = 5.3)
  epm_data2 <- load_epm_data(test_csv, fps = 25, pixels_per_cm = 5.3)
  epm_data2$subject_id <- "test_subject_2"  # Change ID

  epm_list <- list(epm_data1, epm_data2)

  batch_results <- analyze_epm_batch(epm_list)

  # Check structure
  expect_s3_class(batch_results, "data.frame")
  expect_equal(nrow(batch_results), 2)
  expect_true("subject_id" %in% names(batch_results))
  expect_true("open_arm_ratio" %in% names(batch_results))
})


# ==============================================================================
# EPM Reporting Tests
# ==============================================================================

test_that("generate_epm_report creates output files", {
  skip_if_not(file.exists(test_csv), "Test CSV file not found")
  skip_if_not(requireNamespace("ggplot2", quietly = TRUE), "ggplot2 not available")

  epm_data <- load_epm_data(test_csv, fps = 25, pixels_per_cm = 5.3)

  # Create temporary output directory
  temp_dir <- tempdir()
  output_dir <- file.path(temp_dir, "epm_test_report")

  # Generate report
  report_files <- generate_epm_report(
    epm_data,
    output_dir = output_dir,
    subject_id = "test_subject"
  )

  # Check that files were created
  expect_true(file.exists(report_files$trajectory))
  expect_true(file.exists(report_files$heatmap))
  expect_true(file.exists(report_files$zone_time))
  expect_true(file.exists(report_files$metrics_csv))
  expect_true(file.exists(report_files$summary_txt))

  # Clean up
  unlink(output_dir, recursive = TRUE)
})


# ==============================================================================
# Integration Tests
# ==============================================================================

test_that("Full EPM pipeline runs without errors", {
  skip_if_not(file.exists(test_csv), "Test CSV file not found")
  skip_if_not(requireNamespace("ggplot2", quietly = TRUE), "ggplot2 not available")

  # Full pipeline: load → analyze → report
  expect_no_error({
    # Load
    epm_data <- load_epm_data(test_csv, fps = 25, pixels_per_cm = 5.3)

    # Validate
    validate_epm_data(epm_data)

    # Summarize
    summary <- summarize_epm_data(epm_data)

    # Analyze
    results <- analyze_epm(epm_data)

    # Print results (should not error)
    print_epm_results(results, subject_id = "test")

    # Interpret
    anxiety <- interpret_epm_anxiety(results$open_arm_ratio,
                                     results$entries_ratio,
                                     results$total_arm_entries)

    # Export
    temp_csv <- tempfile(fileext = ".csv")
    export_epm_results(results, temp_csv)
    expect_true(file.exists(temp_csv))
    unlink(temp_csv)
  })
})


test_that("EPM pipeline matches output format of other paradigms", {
  skip_if_not(file.exists(test_csv), "Test CSV file not found")

  epm_data <- load_epm_data(test_csv, fps = 25, pixels_per_cm = 5.3)
  results <- analyze_epm(epm_data)

  # Check that results have similar structure to LD/OFT/NORT
  # Should have time metrics, entry metrics, locomotor metrics
  expect_true(all(c("time_in_open_arms_sec", "time_in_closed_arms_sec") %in% names(results)))
  expect_true(all(c("entries_to_open", "entries_to_closed") %in% names(results)))
  expect_true(all(c("total_distance_cm", "avg_velocity_cm_s") %in% names(results)))
  expect_true("total_duration_sec" %in% names(results))
})
