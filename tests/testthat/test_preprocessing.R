# Tests for preprocessing.R

library(testthat)

# Source required files (relative to project root)
source("../../R/core/data_structures.R")
source("../../R/core/preprocessing.R")

# Helper function to create test tracking data
create_test_tracking_data <- function(n_frames = 100, n_parts = 2) {
  metadata <- list(
    source = "test",
    fps = 30,
    subject_id = "test_subject",
    session_id = "test_session",
    paradigm = "test",
    timestamp = Sys.time(),
    original_file = "test.csv",
    units = "pixels"
  )

  tracking <- data.frame(
    frame = rep(1:n_frames, n_parts),
    time = rep(seq(0, length.out = n_frames, by = 1/30), n_parts),
    body_part = rep(c("nose", "tail"), each = n_frames),
    x = rnorm(n_frames * n_parts, 250, 50),
    y = rnorm(n_frames * n_parts, 250, 50),
    likelihood = runif(n_frames * n_parts, 0.8, 1.0)
  )

  new_tracking_data(metadata, tracking)
}

# ============================================================================
# Tests for filter_low_confidence()
# ============================================================================

test_that("filter_low_confidence validates input", {
  expect_error(
    filter_low_confidence(list(not = "tracking_data")),
    "tracking_data object"
  )

  data <- create_test_tracking_data()
  expect_error(
    filter_low_confidence(data, threshold = -0.1),
    "between 0 and 1"
  )

  expect_error(
    filter_low_confidence(data, threshold = 1.5),
    "between 0 and 1"
  )
})

test_that("filter_low_confidence filters all body parts by default", {
  data <- create_test_tracking_data(n_frames = 50)

  # Set some likelihoods below threshold
  data$tracking$likelihood[1:5] <- 0.5
  data$tracking$likelihood[51:55] <- 0.6

  result <- filter_low_confidence(data, threshold = 0.9)

  # Check that low confidence points are now NA
  expect_true(is.na(result$tracking$x[1]))
  expect_true(is.na(result$tracking$y[1]))
  expect_true(is.na(result$tracking$x[51]))

  # Check that high confidence points are preserved
  expect_false(is.na(result$tracking$x[10]))
  expect_false(is.na(result$tracking$y[10]))

  # Likelihood values should be preserved
  expect_equal(result$tracking$likelihood[1], 0.5)
})

test_that("filter_low_confidence respects body_parts parameter", {
  data <- create_test_tracking_data(n_frames = 50)

  # Set low likelihoods for both parts
  data$tracking$likelihood[1:5] <- 0.5   # nose
  data$tracking$likelihood[51:55] <- 0.5 # tail

  # Filter only nose
  result <- filter_low_confidence(data, threshold = 0.9, body_parts = "nose")

  # Nose should be filtered
  expect_true(is.na(result$tracking$x[1]))

  # Tail should NOT be filtered
  expect_false(is.na(result$tracking$x[51]))
})

test_that("filter_low_confidence handles invalid body parts gracefully", {
  data <- create_test_tracking_data()

  expect_warning(
    filter_low_confidence(data, body_parts = "nonexistent"),
    "not found"
  )
})

test_that("filter_low_confidence preserves structure", {
  data <- create_test_tracking_data()
  result <- filter_low_confidence(data, threshold = 0.9)

  expect_s3_class(result, "tracking_data")
  expect_equal(nrow(result$tracking), nrow(data$tracking))
  expect_equal(result$metadata, data$metadata)
})

test_that("filter_low_confidence verbose mode works", {
  data <- create_test_tracking_data(n_frames = 50)
  data$tracking$likelihood[1:5] <- 0.5

  expect_message(
    filter_low_confidence(data, threshold = 0.9, verbose = TRUE),
    "Filtered"
  )
})

test_that("filter_low_confidence handles edge cases", {
  data <- create_test_tracking_data(n_frames = 10)

  # All high confidence - nothing should be filtered
  data$tracking$likelihood <- 0.99
  result <- filter_low_confidence(data, threshold = 0.9)
  expect_equal(sum(is.na(result$tracking$x)), 0)

  # All low confidence - everything should be filtered
  data$tracking$likelihood <- 0.5
  result <- filter_low_confidence(data, threshold = 0.9)
  expect_equal(sum(is.na(result$tracking$x)), nrow(data$tracking))
})

# ============================================================================
# Tests for interpolate_missing()
# ============================================================================

test_that("interpolate_missing validates input", {
  expect_error(
    interpolate_missing(list(not = "tracking_data")),
    "tracking_data object"
  )

  data <- create_test_tracking_data()
  expect_error(
    interpolate_missing(data, method = "invalid"),
    "must be one of"
  )

  expect_error(
    interpolate_missing(data, max_gap = -1),
    "positive integer"
  )
})

test_that("interpolate_missing performs linear interpolation", {
  data <- create_test_tracking_data(n_frames = 10, n_parts = 1)

  # Create a simple pattern with a gap
  data$tracking$x <- c(1, 2, NA, NA, 5, 6, 7, 8, 9, 10)
  data$tracking$y <- c(1, 2, NA, NA, 5, 6, 7, 8, 9, 10)

  result <- interpolate_missing(data, method = "linear", max_gap = 5)

  # Check interpolated values
  expect_equal(result$tracking$x[3], 3, tolerance = 0.01)
  expect_equal(result$tracking$x[4], 4, tolerance = 0.01)
  expect_equal(result$tracking$y[3], 3, tolerance = 0.01)
})

test_that("interpolate_missing respects max_gap", {
  data <- create_test_tracking_data(n_frames = 15, n_parts = 1)

  # Create a small gap and a large gap
  data$tracking$x <- c(1, 2, NA, NA, 5, 6, NA, NA, NA, NA, NA, NA, 13, 14, 15)

  # max_gap = 2, only first gap should be filled
  result <- interpolate_missing(data, method = "linear", max_gap = 2)

  expect_false(is.na(result$tracking$x[3]))  # Should be interpolated
  expect_false(is.na(result$tracking$x[4]))  # Should be interpolated
  expect_true(is.na(result$tracking$x[7]))   # Should NOT be interpolated (gap too long)
})

test_that("interpolate_missing handles multiple methods", {
  data <- create_test_tracking_data(n_frames = 10, n_parts = 1)
  data$tracking$x <- c(1, 2, NA, NA, 5, 6, 7, 8, 9, 10)

  # Test each method runs without error
  result_linear <- interpolate_missing(data, method = "linear", max_gap = 5)
  expect_false(is.na(result_linear$tracking$x[3]))

  result_spline <- interpolate_missing(data, method = "spline", max_gap = 5)
  expect_false(is.na(result_spline$tracking$x[3]))

  result_poly <- interpolate_missing(data, method = "polynomial", max_gap = 5)
  expect_false(is.na(result_poly$tracking$x[3]))
})

test_that("interpolate_missing processes multiple body parts independently", {
  data <- create_test_tracking_data(n_frames = 10, n_parts = 2)

  # Add gaps to each body part at different locations
  nose_idx <- data$tracking$body_part == "nose"
  tail_idx <- data$tracking$body_part == "tail"

  data$tracking$x[nose_idx][3:4] <- NA
  data$tracking$x[tail_idx][6:7] <- NA

  result <- interpolate_missing(data, method = "linear", max_gap = 5)

  # Both gaps should be filled
  nose_data <- result$tracking[nose_idx, ]
  tail_data <- result$tracking[tail_idx, ]

  expect_false(is.na(nose_data$x[3]))
  expect_false(is.na(tail_data$x[6]))
})

test_that("interpolate_missing handles edge cases", {
  data <- create_test_tracking_data(n_frames = 5, n_parts = 1)

  # All NA
  data$tracking$x <- NA
  result <- interpolate_missing(data, method = "linear", max_gap = 5)
  expect_true(all(is.na(result$tracking$x)))

  # No NA
  data$tracking$x <- 1:5
  result <- interpolate_missing(data, method = "linear", max_gap = 5)
  expect_equal(result$tracking$x, 1:5)

  # NA at start (can't interpolate)
  data$tracking$x <- c(NA, NA, 3, 4, 5)
  result <- interpolate_missing(data, method = "linear", max_gap = 5)
  expect_true(is.na(result$tracking$x[1]))

  # NA at end (can't interpolate)
  data$tracking$x <- c(1, 2, 3, NA, NA)
  result <- interpolate_missing(data, method = "linear", max_gap = 5)
  expect_true(is.na(result$tracking$x[4]))
})

test_that("interpolate_missing verbose mode works", {
  data <- create_test_tracking_data(n_frames = 10, n_parts = 1)
  data$tracking$x[3:4] <- NA

  expect_message(
    interpolate_missing(data, method = "linear", max_gap = 5, verbose = TRUE),
    "Interpolated"
  )
})

# ============================================================================
# Tests for smooth_trajectory()
# ============================================================================

test_that("smooth_trajectory validates input", {
  expect_error(
    smooth_trajectory(list(not = "tracking_data")),
    "tracking_data object"
  )

  data <- create_test_tracking_data()
  expect_error(
    smooth_trajectory(data, method = "invalid"),
    "must be one of"
  )

  expect_error(
    smooth_trajectory(data, window = 4),
    "odd integer"
  )

  expect_error(
    smooth_trajectory(data, window = 2),
    "odd integer"
  )

  expect_error(
    smooth_trajectory(data, method = "savgol", window = 5, polynomial = 10),
    "polynomial"
  )
})

test_that("smooth_trajectory applies moving average smoothing", {
  data <- create_test_tracking_data(n_frames = 20, n_parts = 1)

  # Create noisy data
  data$tracking$x <- c(1:10, 10:1) + rnorm(20, 0, 0.1)
  original_x <- data$tracking$x

  result <- smooth_trajectory(data, method = "ma", window = 5)

  # Smoothed data should be less variable
  original_sd <- sd(diff(original_x), na.rm = TRUE)
  smoothed_sd <- sd(diff(result$tracking$x), na.rm = TRUE)

  expect_lt(smoothed_sd, original_sd)
})

test_that("smooth_trajectory applies all smoothing methods", {
  data <- create_test_tracking_data(n_frames = 20, n_parts = 1)
  data$tracking$x <- c(1:10, 10:1) + rnorm(20, 0, 0.1)

  # Test each method runs without error
  result_ma <- smooth_trajectory(data, method = "ma", window = 5)
  expect_s3_class(result_ma, "tracking_data")

  result_gaussian <- smooth_trajectory(data, method = "gaussian", window = 5)
  expect_s3_class(result_gaussian, "tracking_data")

  result_savgol <- smooth_trajectory(data, method = "savgol", window = 5, polynomial = 2)
  expect_s3_class(result_savgol, "tracking_data")
})

test_that("smooth_trajectory preserves data structure", {
  data <- create_test_tracking_data()
  result <- smooth_trajectory(data, method = "ma", window = 5)

  expect_s3_class(result, "tracking_data")
  expect_equal(nrow(result$tracking), nrow(data$tracking))
  expect_equal(names(result), names(data))
})

test_that("smooth_trajectory handles body_parts parameter", {
  data <- create_test_tracking_data(n_frames = 20, n_parts = 2)

  # Add noise to both parts
  data$tracking$x <- data$tracking$x + rnorm(40, 0, 5)

  # Smooth only one body part
  result <- smooth_trajectory(data, method = "ma", window = 5, body_parts = "nose")

  # Check that only nose was smoothed (tail should be unchanged)
  nose_original <- data$tracking$x[data$tracking$body_part == "nose"]
  nose_smoothed <- result$tracking$x[result$tracking$body_part == "nose"]
  tail_original <- data$tracking$x[data$tracking$body_part == "tail"]
  tail_smoothed <- result$tracking$x[result$tracking$body_part == "tail"]

  expect_false(identical(nose_original, nose_smoothed))
  expect_identical(tail_original, tail_smoothed)
})

test_that("smooth_trajectory handles NA values", {
  data <- create_test_tracking_data(n_frames = 20, n_parts = 1)
  data$tracking$x[5:7] <- NA

  result <- smooth_trajectory(data, method = "ma", window = 5)

  # NA values should remain NA
  expect_true(is.na(result$tracking$x[5]))
  expect_true(is.na(result$tracking$x[6]))
  expect_true(is.na(result$tracking$x[7]))

  # Non-NA values should be smoothed
  expect_false(is.na(result$tracking$x[1]))
})

test_that("smooth_trajectory window size affects smoothing strength", {
  data <- create_test_tracking_data(n_frames = 50, n_parts = 1)
  data$tracking$x <- sin(seq(0, 4*pi, length.out = 50)) + rnorm(50, 0, 0.2)

  # Small window = less smoothing
  result_small <- smooth_trajectory(data, method = "ma", window = 3)
  sd_small <- sd(diff(result_small$tracking$x), na.rm = TRUE)

  # Large window = more smoothing
  result_large <- smooth_trajectory(data, method = "ma", window = 11)
  sd_large <- sd(diff(result_large$tracking$x), na.rm = TRUE)

  expect_lt(sd_large, sd_small)
})

test_that("smooth_trajectory verbose mode works", {
  data <- create_test_tracking_data()

  expect_message(
    smooth_trajectory(data, method = "ma", window = 5, verbose = TRUE),
    "Applied"
  )
})

test_that("smooth_trajectory Savitzky-Golay polynomial order works", {
  data <- create_test_tracking_data(n_frames = 30, n_parts = 1)
  data$tracking$x <- sin(seq(0, 2*pi, length.out = 30)) + rnorm(30, 0, 0.1)

  # Different polynomial orders should give different results
  result_poly1 <- smooth_trajectory(data, method = "savgol", window = 7, polynomial = 1)
  result_poly3 <- smooth_trajectory(data, method = "savgol", window = 7, polynomial = 3)

  # Results should be different
  expect_false(identical(result_poly1$tracking$x, result_poly3$tracking$x))
})

# ============================================================================
# Integration tests - Full preprocessing pipeline
# ============================================================================

test_that("full preprocessing pipeline works", {
  # Create realistic test data
  data <- create_test_tracking_data(n_frames = 100)

  # Add some low confidence points
  data$tracking$likelihood[seq(5, 100, by = 10)] <- 0.5

  # Step 1: Filter low confidence
  step1 <- filter_low_confidence(data, threshold = 0.9)
  expect_s3_class(step1, "tracking_data")
  expect_true(any(is.na(step1$tracking$x)))

  # Step 2: Interpolate missing
  step2 <- interpolate_missing(step1, method = "linear", max_gap = 5)
  expect_s3_class(step2, "tracking_data")

  # Step 3: Smooth trajectory
  step3 <- smooth_trajectory(step2, method = "savgol", window = 11)
  expect_s3_class(step3, "tracking_data")

  # Final result should have fewer NAs than step1
  expect_lt(sum(is.na(step3$tracking$x)), sum(is.na(step1$tracking$x)))
})

test_that("preprocessing preserves metadata and structure", {
  data <- create_test_tracking_data(n_frames = 50)
  data$tracking$likelihood[5:10] <- 0.5

  result <- data %>%
    filter_low_confidence(threshold = 0.9) %>%
    interpolate_missing(method = "linear", max_gap = 5) %>%
    smooth_trajectory(method = "ma", window = 5)

  # Check structure preserved
  expect_s3_class(result, "tracking_data")
  expect_equal(result$metadata$subject_id, data$metadata$subject_id)
  expect_equal(result$metadata$fps, data$metadata$fps)
  expect_equal(nrow(result$tracking), nrow(data$tracking))
})

# ============================================================================
# Edge cases and error handling
# ============================================================================

test_that("preprocessing handles single frame data", {
  data <- create_test_tracking_data(n_frames = 1)

  # These should not error
  result1 <- filter_low_confidence(data, threshold = 0.9)
  expect_s3_class(result1, "tracking_data")

  # Smoothing with window larger than data should handle gracefully
  # (though may not do much)
  expect_no_error(
    smooth_trajectory(data, method = "ma", window = 5)
  )
})

test_that("preprocessing handles empty gaps correctly", {
  data <- create_test_tracking_data(n_frames = 20, n_parts = 1)

  # Create multiple small gaps
  data$tracking$x[c(5, 10, 15)] <- NA

  result <- interpolate_missing(data, method = "linear", max_gap = 1)

  # Single-frame gaps should be interpolated
  expect_false(is.na(result$tracking$x[5]))
  expect_false(is.na(result$tracking$x[10]))
  expect_false(is.na(result$tracking$x[15]))
})

test_that("preprocessing maintains frame order", {
  data <- create_test_tracking_data(n_frames = 50)

  # Shuffle data (should be reordered internally)
  shuffled_idx <- sample(1:nrow(data$tracking))
  data$tracking <- data$tracking[shuffled_idx, ]

  result <- smooth_trajectory(data, method = "ma", window = 5)

  # Check each body part is in frame order
  for (part in unique(result$tracking$body_part)) {
    part_data <- result$tracking[result$tracking$body_part == part, ]
    expect_true(all(diff(part_data$frame) > 0))
  }
})
