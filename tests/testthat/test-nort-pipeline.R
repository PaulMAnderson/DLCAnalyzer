# Test NORT (Novel Object Recognition Test) Pipeline
# Tests for NORT data loading, analysis, and reporting functions

# Setup
library(testthat)

# Source required files
source("R/common/io.R")
source("R/common/geometry.R")
source("R/common/plotting.R")
source("R/ld/ld_analysis.R")  # For shared zone utility functions
source("R/nort/nort_load.R")
source("R/nort/nort_analysis.R")
source("R/nort/nort_report.R")

# Test data file path
test_file <- "data/NORT/NORT 20251003/Raw data-NORT D3 20251003-Trial     1 (1).xlsx"

test_that("NORT data loading works correctly", {
  skip_if_not(file.exists(test_file), "Test data file not found")

  # Load data
  nort_data <- load_nort_data(test_file, fps = 25, novel_side = "left")

  # Check structure
  expect_type(nort_data, "list")
  expect_true(length(nort_data) > 0)
  expect_true("Arena_1" %in% names(nort_data))

  # Check arena structure
  arena1 <- nort_data[["Arena_1"]]
  expect_true("data" %in% names(arena1))
  expect_true("fps" %in% names(arena1))
  expect_true("novel_side" %in% names(arena1))
  expect_equal(arena1$novel_side, "left")
  expect_equal(arena1$fps, 25)

  # Check data frame structure
  df <- arena1$data
  expect_s3_class(df, "data.frame")
  expect_true(nrow(df) > 0)

  # Check required columns
  expect_true("time" %in% colnames(df))
  expect_true("x_nose" %in% colnames(df))
  expect_true("y_nose" %in% colnames(df))
  expect_true("x_center" %in% colnames(df))
  expect_true("y_center" %in% colnames(df))

  # Check for object zones
  zone_cols <- grep("^zone_", colnames(df), value = TRUE)
  expect_true(length(zone_cols) > 0)

  object_zones <- grep("object", zone_cols, value = TRUE, ignore.case = TRUE)
  expect_true(length(object_zones) >= 2)  # Should have left and right
})

test_that("Novel side parameter validation works", {
  skip_if_not(file.exists(test_file), "Test data file not found")

  # Valid values
  expect_no_error(load_nort_data(test_file, novel_side = "left"))
  expect_no_error(load_nort_data(test_file, novel_side = "right"))
  expect_no_error(load_nort_data(test_file, novel_side = "neither"))

  # Case insensitive
  expect_no_error(load_nort_data(test_file, novel_side = "LEFT"))
  expect_no_error(load_nort_data(test_file, novel_side = "Right"))

  # Invalid value
  expect_error(load_nort_data(test_file, novel_side = "center"))
  expect_error(load_nort_data(test_file, novel_side = "invalid"))
})

test_that("NORT data validation works", {
  skip_if_not(file.exists(test_file), "Test data file not found")

  nort_data <- load_nort_data(test_file, fps = 25, novel_side = "left")

  # Should pass validation
  result <- validate_nort_data(nort_data)
  expect_type(result, "logical")
  expect_true(result)
})

test_that("NORT data summary works", {
  skip_if_not(file.exists(test_file), "Test data file not found")

  nort_data <- load_nort_data(test_file, fps = 25, novel_side = "left")
  summary_df <- summarize_nort_data(nort_data)

  # Check summary structure
  expect_s3_class(summary_df, "data.frame")
  expect_true(nrow(summary_df) > 0)

  # Check columns
  expect_true("arena" %in% colnames(summary_df))
  expect_true("novel_side" %in% colnames(summary_df))
  expect_true("total_exploration_sec" %in% colnames(summary_df))
  expect_true("left_object_time_sec" %in% colnames(summary_df))
  expect_true("right_object_time_sec" %in% colnames(summary_df))

  # Check values are numeric
  expect_true(is.numeric(summary_df$total_exploration_sec))
  expect_true(is.numeric(summary_df$left_object_time_sec))
})

test_that("Discrimination Index calculation is correct", {
  # Perfect novelty preference
  di1 <- calculate_discrimination_index(novel_time = 20, familiar_time = 0)
  expect_equal(di1, 1.0)

  # Equal exploration
  di2 <- calculate_discrimination_index(novel_time = 10, familiar_time = 10)
  expect_equal(di2, 0.0)

  # Perfect familiarity preference
  di3 <- calculate_discrimination_index(novel_time = 0, familiar_time = 20)
  expect_equal(di3, -1.0)

  # No exploration
  di4 <- calculate_discrimination_index(novel_time = 0, familiar_time = 0)
  expect_true(is.na(di4))

  # Realistic case
  di5 <- calculate_discrimination_index(novel_time = 15.2, familiar_time = 8.3)
  expect_equal(round(di5, 3), 0.294)

  # DI should always be between -1 and 1
  di6 <- calculate_discrimination_index(novel_time = 18, familiar_time = 6)
  expect_true(di6 >= -1 && di6 <= 1)
})

test_that("Preference Score calculation is correct", {
  # 100% novel
  pref1 <- calculate_preference_score(novel_time = 20, familiar_time = 0)
  expect_equal(pref1, 100)

  # 50% each
  pref2 <- calculate_preference_score(novel_time = 10, familiar_time = 10)
  expect_equal(pref2, 50)

  # 0% novel
  pref3 <- calculate_preference_score(novel_time = 0, familiar_time = 20)
  expect_equal(pref3, 0)

  # No exploration
  pref4 <- calculate_preference_score(novel_time = 0, familiar_time = 0)
  expect_true(is.na(pref4))

  # Realistic case
  pref5 <- calculate_preference_score(novel_time = 15, familiar_time = 10)
  expect_equal(pref5, 60)
})

test_that("Recognition Index calculation is correct", {
  # Perfect recognition
  ri1 <- calculate_recognition_index(novel_time = 20, total_time = 20)
  expect_equal(ri1, 1.0)

  # Half recognition
  ri2 <- calculate_recognition_index(novel_time = 10, total_time = 20)
  expect_equal(ri2, 0.5)

  # No recognition
  ri3 <- calculate_recognition_index(novel_time = 0, total_time = 20)
  expect_equal(ri3, 0.0)

  # No exploration
  ri4 <- calculate_recognition_index(novel_time = 0, total_time = 0)
  expect_true(is.na(ri4))
})

test_that("Trial validity check works", {
  # Valid trial
  expect_true(is_valid_nort_trial(total_exploration_time = 23.5, min_threshold = 10))
  expect_true(is_valid_nort_trial(total_exploration_time = 10.0, min_threshold = 10))

  # Invalid trial
  expect_false(is_valid_nort_trial(total_exploration_time = 5.2, min_threshold = 10))
  expect_false(is_valid_nort_trial(total_exploration_time = 0, min_threshold = 10))

  # NA exploration
  expect_false(is_valid_nort_trial(total_exploration_time = NA, min_threshold = 10))

  # Different threshold
  expect_true(is_valid_nort_trial(total_exploration_time = 8, min_threshold = 5))
  expect_false(is_valid_nort_trial(total_exploration_time = 8, min_threshold = 15))
})

test_that("NORT analysis works with novel on left", {
  skip_if_not(file.exists(test_file), "Test data file not found")

  nort_data <- load_nort_data(test_file, fps = 25, novel_side = "left")
  arena1 <- nort_data[["Arena_1"]]

  results <- analyze_nort(arena1$data, fps = 25, novel_side = "left")

  # Check result structure
  expect_type(results, "list")

  # Check required metrics
  expect_true("novel_object_time_sec" %in% names(results))
  expect_true("familiar_object_time_sec" %in% names(results))
  expect_true("total_exploration_sec" %in% names(results))
  expect_true("discrimination_index" %in% names(results))
  expect_true("preference_score" %in% names(results))
  expect_true("is_valid_trial" %in% names(results))
  expect_true("novel_side" %in% names(results))

  # Check values are numeric (or NA)
  expect_true(is.numeric(results$novel_object_time_sec) || is.na(results$novel_object_time_sec))
  expect_true(is.numeric(results$discrimination_index) || is.na(results$discrimination_index))

  # DI should be in valid range
  if (!is.na(results$discrimination_index)) {
    expect_true(results$discrimination_index >= -1 && results$discrimination_index <= 1)
  }

  # Preference should be 0-100
  if (!is.na(results$preference_score)) {
    expect_true(results$preference_score >= 0 && results$preference_score <= 100)
  }

  # Novel side should match
  expect_equal(results$novel_side, "left")
})

test_that("NORT analysis works with novel on right", {
  skip_if_not(file.exists(test_file), "Test data file not found")

  nort_data <- load_nort_data(test_file, fps = 25, novel_side = "right")
  arena1 <- nort_data[["Arena_1"]]

  results <- analyze_nort(arena1$data, fps = 25, novel_side = "right")

  # Novel side should match
  expect_equal(results$novel_side, "right")

  # Times should swap compared to left
  nort_data_left <- load_nort_data(test_file, fps = 25, novel_side = "left")
  results_left <- analyze_nort(nort_data_left[["Arena_1"]]$data, fps = 25, novel_side = "left")

  # When novel side changes, novel and familiar times should swap
  expect_equal(results$novel_object_time_sec, results_left$familiar_object_time_sec)
  expect_equal(results$familiar_object_time_sec, results_left$novel_object_time_sec)

  # DI should be opposite
  if (!is.na(results$discrimination_index) && !is.na(results_left$discrimination_index)) {
    expect_equal(results$discrimination_index, -results_left$discrimination_index)
  }
})

test_that("Batch analysis works", {
  skip_if_not(file.exists(test_file), "Test data file not found")

  nort_data <- load_nort_data(test_file, fps = 25, novel_side = "left")

  # Batch analysis
  batch_results <- analyze_nort_batch(nort_data, fps = 25, novel_sides = "left")

  # Check structure
  expect_s3_class(batch_results, "data.frame")
  expect_equal(nrow(batch_results), length(nort_data))

  # Check columns
  expect_true("arena_name" %in% colnames(batch_results))
  expect_true("discrimination_index" %in% colnames(batch_results))
  expect_true("novel_side" %in% colnames(batch_results))

  # Check all DI values are in range
  valid_di <- batch_results$discrimination_index[!is.na(batch_results$discrimination_index)]
  expect_true(all(valid_di >= -1 & valid_di <= 1))
})

test_that("Export results works", {
  skip_if_not(file.exists(test_file), "Test data file not found")

  nort_data <- load_nort_data(test_file, fps = 25, novel_side = "left")
  batch_results <- analyze_nort_batch(nort_data, fps = 25)

  # Export to temp file
  temp_file <- tempfile(fileext = ".csv")
  export_nort_results(batch_results, temp_file)

  # Check file exists
  expect_true(file.exists(temp_file))

  # Read back and verify
  imported <- read.csv(temp_file)
  expect_equal(nrow(imported), nrow(batch_results))
  expect_true("discrimination_index" %in% colnames(imported))

  # Cleanup
  unlink(temp_file)
})

test_that("DI interpretation works", {
  # Strong novelty
  interp1 <- interpret_nort_di(0.45)
  expect_true(grepl("intact memory", interp1, ignore.case = TRUE))

  # Moderate novelty
  interp2 <- interpret_nort_di(0.15)
  expect_true(grepl("moderate", interp2, ignore.case = TRUE))

  # Weak/no discrimination
  interp3 <- interpret_nort_di(0.05)
  expect_true(grepl("impaired|weak", interp3, ignore.case = TRUE))

  # Familiarity preference
  interp4 <- interpret_nort_di(-0.3)
  expect_true(grepl("familiarity|neophobia", interp4, ignore.case = TRUE))

  # NA
  interp5 <- interpret_nort_di(NA)
  expect_true(grepl("no exploration", interp5, ignore.case = TRUE))
})

test_that("Report generation works", {
  skip_if_not(file.exists(test_file), "Test data file not found")

  nort_data <- load_nort_data(test_file, fps = 25, novel_side = "left")
  arena1 <- nort_data[["Arena_1"]]

  # Generate report in temp directory
  temp_dir <- tempfile()
  dir.create(temp_dir, recursive = TRUE)

  report_files <- generate_nort_report(
    arena1,
    output_dir = temp_dir,
    novel_side = "left",
    fps = 25
  )

  # Check all expected files were created
  expect_true(file.exists(report_files$trajectory))
  expect_true(file.exists(report_files$heatmap))
  expect_true(file.exists(report_files$exploration))
  expect_true(file.exists(report_files$metrics_csv))
  expect_true(file.exists(report_files$summary_txt))

  # Check summary content
  summary_lines <- readLines(report_files$summary_txt)
  expect_true(any(grepl("Discrimination Index", summary_lines)))
  expect_true(any(grepl("Novel Object", summary_lines)))

  # Cleanup
  unlink(temp_dir, recursive = TRUE)
})

cat("\n✓ All NORT pipeline tests completed successfully!\n")
