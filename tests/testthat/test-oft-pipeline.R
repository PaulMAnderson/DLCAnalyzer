#' Tests for OFT Pipeline
#'
#' Comprehensive tests for the Open Field Test analysis pipeline.

library(testthat)

# Test data path
test_data_path <- "../../data/OFT/OF 20250929/Raw data-OF RebeccaAndersonWagner-Trial     1 (3).xlsx"

# Skip tests if test data not available
skip_if_no_test_data <- function() {
  if (!file.exists(test_data_path)) {
    skip("Test data file not found")
  }
}

# ===== OFT Loading Functions Tests =====

test_that("standardize_oft_columns renames columns correctly", {
  df <- data.frame(
    Trial.time = c(0, 0.04, 0.08),
    X.center = c(10, 11, 12),
    Y.center = c(20, 21, 22),
    zone_center = c(1, 1, 0),
    zone_floor = c(1, 1, 1)
  )

  df_std <- standardize_oft_columns(df)

  expect_true("time" %in% colnames(df_std))
  expect_true("x_center" %in% colnames(df_std))
  expect_true("y_center" %in% colnames(df_std))
})

test_that("standardize_oft_columns creates periphery zone", {
  df <- data.frame(
    time = c(0, 0.04, 0.08),
    x_center = c(10, 11, 12),
    y_center = c(20, 21, 22),
    zone_center = c(1, 0, 0),
    zone_floor = c(1, 1, 1)
  )

  df_std <- standardize_oft_columns(df)

  expect_true("zone_periphery" %in% colnames(df_std))
  # Periphery = floor AND NOT center
  expect_equal(df_std$zone_periphery, c(0, 1, 1))
})

test_that("validate_oft_data checks structure", {
  # Valid data
  valid_data <- list(
    Arena_1 = list(
      data = data.frame(
        time = c(0, 0.04, 0.08),
        x_center = c(10, 11, 12),
        y_center = c(20, 21, 22),
        zone_center = c(1, 1, 0)
      ),
      arena_id = 1,
      fps = 25
    )
  )

  expect_true(validate_oft_data(valid_data))

  # Invalid data - missing required columns
  invalid_data <- list(
    Arena_1 = list(
      data = data.frame(
        time = c(0, 0.04, 0.08)
      ),
      arena_id = 1
    )
  )

  expect_error(validate_oft_data(invalid_data), "missing required columns")
})

test_that("summarize_oft_data generates summary", {
  skip_if_no_test_data()

  oft_data <- load_oft_data(test_data_path, fps = 25)
  summary <- summarize_oft_data(oft_data)

  expect_true(is.data.frame(summary))
  expect_true("arena_name" %in% colnames(summary))
  expect_true("duration_sec" %in% colnames(summary))
  expect_true("n_zones" %in% colnames(summary))
  expect_true("pct_missing_coords" %in% colnames(summary))
  expect_equal(nrow(summary), length(oft_data))
})

test_that("get_oft_zone_names returns zone columns", {
  arena_data <- list(
    data = data.frame(
      time = c(0, 0.04),
      x_center = c(10, 11),
      y_center = c(20, 21),
      zone_center = c(1, 0),
      zone_periphery = c(0, 1)
    )
  )

  zones <- get_oft_zone_names(arena_data)

  expect_equal(length(zones), 2)
  expect_true("zone_center" %in% zones)
  expect_true("zone_periphery" %in% zones)
})

# ===== OFT Analysis Functions Tests =====

test_that("analyze_oft calculates center time correctly", {
  df <- data.frame(
    time = seq(0, by = 0.04, length.out = 100),
    x_center = rep(50, 100),
    y_center = rep(50, 100),
    zone_center = c(rep(1, 25), rep(0, 75))  # 25% in center
  )

  results <- analyze_oft(df, fps = 25)

  expect_equal(results$time_in_center_sec, 1)  # 25 frames at 25 fps
  expect_equal(round(results$pct_time_in_center, 1), 25.3)  # ~25%
})

test_that("analyze_oft calculates entries correctly", {
  df <- data.frame(
    time = seq(0, by = 0.04, length.out = 20),
    x_center = rep(50, 20),
    y_center = rep(50, 20),
    zone_center = c(0, 0, 1, 1, 1, 0, 0, 1, 1, 0,
                    1, 1, 1, 0, 0, 0, 1, 1, 0, 0)
  )

  results <- analyze_oft(df, fps = 25)

  # Count 0->1 transitions: positions 3, 8, 11, 17 = 4 entries
  expect_equal(results$entries_to_center, 4)
})

test_that("analyze_oft calculates latency correctly", {
  df <- data.frame(
    time = seq(0, by = 0.04, length.out = 100),
    x_center = rep(50, 100),
    y_center = rep(50, 100),
    zone_center = c(rep(0, 50), rep(1, 50))  # First entry at frame 51
  )

  results <- analyze_oft(df, fps = 25)

  # Frame 51 (index 51) - 1 = 50 frames = 2 seconds at 25 fps
  expect_equal(results$latency_to_center_sec, 50 / 25)
})

test_that("analyze_oft handles never entering center", {
  df <- data.frame(
    time = seq(0, by = 0.04, length.out = 100),
    x_center = rep(50, 100),
    y_center = rep(50, 100),
    zone_center = rep(0, 100)  # Never in center
  )

  results <- analyze_oft(df, fps = 25)

  expect_true(is.na(results$latency_to_center_sec))
  expect_equal(results$entries_to_center, 0)
  expect_equal(results$time_in_center_sec, 0)
})

test_that("analyze_oft calculates distance correctly", {
  # Simple horizontal movement
  df <- data.frame(
    time = seq(0, by = 0.04, length.out = 5),
    x_center = c(0, 1, 2, 3, 4),
    y_center = c(0, 0, 0, 0, 0),
    zone_center = c(1, 1, 1, 0, 0),
    zone_periphery = c(0, 0, 0, 1, 1)
  )

  results <- analyze_oft(df, fps = 25)

  expect_equal(results$distance_in_center_cm, 2)  # 2 cm in center
  expect_equal(results$distance_in_periphery_cm, 1)  # 1 cm in periphery
  expect_equal(results$total_distance_cm, 4)  # 4 cm total
})

test_that("analyze_oft uses Ethovision velocity if available", {
  df <- data.frame(
    time = seq(0, by = 0.04, length.out = 100),
    x_center = rep(50, 100),
    y_center = rep(50, 100),
    zone_center = rep(0, 100),
    distance = rep(10, 100),
    velocity = rep(250, 100)  # 250 cm/s
  )

  results <- analyze_oft(df, fps = 25)

  expect_equal(results$avg_velocity_cm_s, 250)
})

test_that("calculate_thigmotaxis_index computes correctly", {
  df <- data.frame(
    time = seq(0, by = 0.04, length.out = 100),
    x_center = rep(50, 100),
    y_center = rep(50, 100),
    zone_wall = c(rep(1, 80), rep(0, 20))  # 80% near wall
  )

  thigmo <- calculate_thigmotaxis_index(df, fps = 25)

  expect_equal(thigmo, 0.8)
})

test_that("calculate_thigmotaxis_index handles multiple wall zones", {
  df <- data.frame(
    time = seq(0, by = 0.04, length.out = 100),
    x_center = rep(50, 100),
    y_center = rep(50, 100),
    zone_wall1 = c(rep(1, 30), rep(0, 70)),
    zone_wall2 = c(rep(0, 50), rep(1, 50))
  )

  wall_cols <- c("zone_wall1", "zone_wall2")
  thigmo <- calculate_thigmotaxis_index(df, wall_zone_cols = wall_cols, fps = 25)

  # 30 frames in wall1, 50 frames in wall2 = 80 frames total
  expect_equal(thigmo, 0.8)
})

test_that("analyze_oft_batch processes multiple arenas", {
  skip_if_no_test_data()

  oft_data <- load_oft_data(test_data_path, fps = 25)
  batch_results <- analyze_oft_batch(oft_data, fps = 25)

  expect_true(is.data.frame(batch_results))
  expect_equal(nrow(batch_results), length(oft_data))

  # Check required columns
  expect_true("arena_name" %in% colnames(batch_results))
  expect_true("pct_time_in_center" %in% colnames(batch_results))
  expect_true("entries_to_center" %in% colnames(batch_results))
  expect_true("total_distance_cm" %in% colnames(batch_results))
  expect_true("avg_velocity_cm_s" %in% colnames(batch_results))
})

test_that("export_oft_results creates CSV file", {
  results <- data.frame(
    arena_name = c("Arena_1", "Arena_2"),
    pct_time_in_center = c(10.5, 15.3),
    total_distance_cm = c(1234.56, 2345.67)
  )

  temp_file <- tempfile(fileext = ".csv")
  export_oft_results(results, temp_file)

  expect_true(file.exists(temp_file))

  # Read back and verify
  imported <- read.csv(temp_file)
  expect_equal(nrow(imported), 2)
  expect_true("arena_name" %in% colnames(imported))

  # Clean up
  unlink(temp_file)
})

# ===== OFT Report Functions Tests =====

test_that("generate_oft_summary_text creates text file", {
  results <- list(
    time_in_center_sec = 10.5,
    time_in_periphery_sec = 200.5,
    pct_time_in_center = 5.0,
    pct_time_in_periphery = 95.0,
    entries_to_center = 8,
    latency_to_center_sec = 5.5,
    distance_in_center_cm = 150.0,
    distance_in_periphery_cm = 2000.0,
    total_distance_cm = 2150.0,
    avg_velocity_cm_s = 300.0,
    time_near_wall_sec = NA,
    thigmotaxis_index = NA,
    total_duration_sec = 211.0,
    fps = 25
  )

  temp_file <- tempfile(fileext = ".txt")
  generate_oft_summary_text(results, temp_file, subject_id = "TestSubject")

  expect_true(file.exists(temp_file))

  # Read and verify content
  content <- readLines(temp_file)
  expect_true(any(grepl("Open Field Test Analysis", content)))
  expect_true(any(grepl("TestSubject", content)))
  expect_true(any(grepl("Time in Center", content)))

  # Clean up
  unlink(temp_file)
})

test_that("interpret_oft_results provides interpretation", {
  # High anxiety case (low center time)
  results_high_anxiety <- list(
    pct_time_in_center = 2.0,
    entries_to_center = 3,
    latency_to_center_sec = 80.0,
    total_distance_cm = 1000,
    total_duration_sec = 300,
    thigmotaxis_index = 0.85
  )

  interpretation <- interpret_oft_results(results_high_anxiety)

  expect_true(any(grepl("High anxiety", interpretation)))
  expect_true(any(grepl("Low exploratory", interpretation)))
  expect_true(any(grepl("Strong thigmotaxis", interpretation)))

  # Low anxiety case (high center time)
  results_low_anxiety <- list(
    pct_time_in_center = 20.0,
    entries_to_center = 18,
    latency_to_center_sec = 5.0,
    total_distance_cm = 5000,
    total_duration_sec = 300,
    thigmotaxis_index = 0.2
  )

  interpretation2 <- interpret_oft_results(results_low_anxiety)

  expect_true(any(grepl("Low anxiety", interpretation2)))
  expect_true(any(grepl("High exploratory", interpretation2)))
  expect_true(any(grepl("Rapid center exploration", interpretation2)))
})

test_that("generate_oft_plots creates plot objects", {
  skip_if_not_installed("ggplot2")

  df <- data.frame(
    time = seq(0, by = 0.04, length.out = 100),
    x_center = rnorm(100, 50, 10),
    y_center = rnorm(100, 50, 10),
    zone_center = sample(c(0, 1), 100, replace = TRUE)
  )

  results <- analyze_oft(df, fps = 25)

  plots <- generate_oft_plots(df, results, subject_id = "TestSubject")

  expect_true(is.list(plots))
  expect_true("trajectory" %in% names(plots))
  expect_true("heatmap" %in% names(plots))
  expect_true("zone_time" %in% names(plots))

  expect_s3_class(plots$trajectory, "ggplot")
  expect_s3_class(plots$heatmap, "ggplot")
  expect_s3_class(plots$zone_time, "ggplot")
})

# ===== Integration Tests with Real Data =====

test_that("load_oft_data reads Ethovision file", {
  skip_if_no_test_data()

  oft_data <- load_oft_data(test_data_path, fps = 25)

  expect_true(is.list(oft_data))
  expect_true(length(oft_data) > 0)

  # Check structure of first arena
  arena1 <- oft_data[[1]]
  expect_true("data" %in% names(arena1))
  expect_true("arena_id" %in% names(arena1))
  expect_true("fps" %in% names(arena1))

  # Check data frame has required columns
  df <- arena1$data
  expect_true("time" %in% colnames(df))
  expect_true("x_center" %in% colnames(df))
  expect_true("y_center" %in% colnames(df))
  expect_true("zone_center" %in% colnames(df))
})

test_that("OFT pipeline works end-to-end with real data", {
  skip_if_no_test_data()

  # Load
  oft_data <- load_oft_data(test_data_path, fps = 25)
  expect_true(length(oft_data) >= 1)

  # Validate
  expect_true(validate_oft_data(oft_data))

  # Analyze single arena
  arena1 <- oft_data[[1]]
  results <- analyze_oft(arena1$data, fps = 25)

  expect_true(is.list(results))
  expect_true(results$time_in_center_sec >= 0)
  expect_true(results$pct_time_in_center >= 0)
  expect_true(results$pct_time_in_center <= 100)
  expect_true(results$entries_to_center >= 0)
  expect_true(results$total_distance_cm >= 0)

  # Batch analysis
  batch_results <- analyze_oft_batch(oft_data, fps = 25)
  expect_equal(nrow(batch_results), length(oft_data))
})

test_that("generate_oft_report creates all expected files", {
  skip_if_no_test_data()
  skip_if_not_installed("ggplot2")

  oft_data <- load_oft_data(test_data_path, fps = 25)
  arena1 <- oft_data[[1]]

  temp_dir <- tempfile()
  dir.create(temp_dir)

  report_files <- generate_oft_report(arena1, output_dir = temp_dir,
                                     subject_id = "TestReport", fps = 25)

  # Check that files were created
  expect_true(file.exists(report_files$trajectory))
  expect_true(file.exists(report_files$heatmap))
  expect_true(file.exists(report_files$zone_time))
  expect_true(file.exists(report_files$metrics_csv))
  expect_true(file.exists(report_files$summary_txt))

  # Clean up
  unlink(temp_dir, recursive = TRUE)
})

test_that("generate_oft_comparison_plots creates comparison plots", {
  skip_if_no_test_data()
  skip_if_not_installed("ggplot2")

  oft_data <- load_oft_data(test_data_path, fps = 25)
  batch_results <- analyze_oft_batch(oft_data, fps = 25)

  temp_dir <- tempfile()
  dir.create(temp_dir)

  comparison_files <- generate_oft_comparison_plots(batch_results, temp_dir)

  # Check that comparison plots were created
  expect_true(file.exists(comparison_files$center_time))
  expect_true(file.exists(comparison_files$distance))
  expect_true(file.exists(comparison_files$entries))
  expect_true(file.exists(comparison_files$velocity))

  # Clean up
  unlink(temp_dir, recursive = TRUE)
})

# ===== Edge Cases and Error Handling =====

test_that("analyze_oft handles missing coordinates gracefully", {
  df <- data.frame(
    time = seq(0, by = 0.04, length.out = 10),
    x_center = c(1, 2, NA, 4, 5, 6, NA, 8, 9, 10),
    y_center = c(1, 2, NA, 4, 5, 6, NA, 8, 9, 10),
    zone_center = rep(0, 10)
  )

  results <- analyze_oft(df, fps = 25)

  # Should complete without error
  expect_true(is.list(results))
  expect_true(is.numeric(results$total_distance_cm))
  expect_false(is.na(results$total_distance_cm))
})

test_that("analyze_oft handles all zeros in center zone", {
  df <- data.frame(
    time = seq(0, by = 0.04, length.out = 100),
    x_center = rep(50, 100),
    y_center = rep(50, 100),
    zone_center = rep(0, 100)  # Never in center
  )

  results <- analyze_oft(df, fps = 25)

  expect_equal(results$time_in_center_sec, 0)
  expect_equal(results$pct_time_in_center, 0)
  expect_equal(results$entries_to_center, 0)
  expect_true(is.na(results$latency_to_center_sec))
})

test_that("analyze_oft requires valid inputs", {
  # Non-data frame input
  expect_error(analyze_oft("not a data frame"), "must be a data frame")

  # Missing required columns
  df_missing <- data.frame(time = 1:10, x_center = 1:10)
  expect_error(analyze_oft(df_missing), "not found")
})
