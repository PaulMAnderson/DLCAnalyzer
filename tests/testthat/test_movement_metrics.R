# tests/testthat/test_movement_metrics.R
# Tests for movement metrics functions

library(testthat)

# Create helper function for test data
create_linear_movement_data <- function() {
  # Create tracking data with linear movement: (0,0) to (100,0) over 10 frames
  tracking_df <- data.frame(
    frame = 1:11,
    time = (0:10) / 10,  # 10 fps
    body_part = rep("mouse_center", 11),
    x = seq(0, 100, by = 10),
    y = rep(0, 11),
    likelihood = rep(0.99, 11),
    stringsAsFactors = FALSE
  )

  metadata <- list(
    source = "test",
    fps = 10,
    subject_id = "test_mouse",
    paradigm = "test"
  )

  new_tracking_data(metadata, tracking_df)
}

create_circular_movement_data <- function() {
  # Create tracking data with circular movement
  n_frames <- 37  # One full circle + start point
  theta <- seq(0, 2*pi, length.out = n_frames)
  radius <- 50

  tracking_df <- data.frame(
    frame = 1:n_frames,
    time = (0:(n_frames-1)) / 30,  # 30 fps
    body_part = rep("mouse_center", n_frames),
    x = 100 + radius * cos(theta),
    y = 100 + radius * sin(theta),
    likelihood = rep(0.99, n_frames),
    stringsAsFactors = FALSE
  )

  metadata <- list(
    source = "test",
    fps = 30,
    subject_id = "test_mouse",
    paradigm = "test"
  )

  new_tracking_data(metadata, tracking_df)
}

create_stationary_data <- function() {
  # Create tracking data with no movement
  tracking_df <- data.frame(
    frame = 1:10,
    time = (0:9) / 10,
    body_part = rep("mouse_center", 10),
    x = rep(50, 10),
    y = rep(50, 10),
    likelihood = rep(0.99, 10),
    stringsAsFactors = FALSE
  )

  metadata <- list(
    source = "test",
    fps = 10,
    subject_id = "test_mouse",
    paradigm = "test"
  )

  new_tracking_data(metadata, tracking_df)
}


# ============================================================================
# Tests for calculate_distance_traveled
# ============================================================================

test_that("calculate_distance_traveled works with linear movement", {
  tracking_data <- create_linear_movement_data()

  distance <- calculate_distance_traveled(tracking_data)

  # Should be 100 pixels (10 steps of 10 pixels each)
  expect_equal(distance, 100, tolerance = 0.01)
})

test_that("calculate_distance_traveled applies scale factor correctly", {
  tracking_data <- create_linear_movement_data()

  # If 10 pixels = 1 cm, then 100 pixels = 10 cm
  distance_cm <- calculate_distance_traveled(tracking_data, scale_factor = 10)

  expect_equal(distance_cm, 10, tolerance = 0.01)
})

test_that("calculate_distance_traveled works with circular movement", {
  tracking_data <- create_circular_movement_data()

  distance <- calculate_distance_traveled(tracking_data)

  # Should be approximately 2 * pi * radius
  expected_distance <- 2 * pi * 50
  expect_equal(distance, expected_distance, tolerance = 1.0)
})

test_that("calculate_distance_traveled returns zero for stationary animal", {
  tracking_data <- create_stationary_data()

  distance <- calculate_distance_traveled(tracking_data)

  expect_equal(distance, 0, tolerance = 0.01)
})

test_that("calculate_distance_traveled validates inputs", {
  tracking_data <- create_linear_movement_data()

  # Invalid tracking_data
  expect_error(
    calculate_distance_traveled(list()),
    "must be a tracking_data object"
  )

  # Invalid body part
  expect_error(
    calculate_distance_traveled(tracking_data, body_part = "nonexistent"),
    "not found in tracking data"
  )
})

test_that("calculate_distance_traveled handles NA values", {
  tracking_data <- create_linear_movement_data()

  # Add NA values in multiple consecutive positions
  tracking_data$tracking$x[c(4, 5, 6)] <- NA
  tracking_data$tracking$y[c(7, 8)] <- NA

  distance <- calculate_distance_traveled(tracking_data)

  # Should still calculate distance for valid points
  expect_true(distance > 0)
  # With significant NAs, distance should be less than full distance
  expect_true(distance <= 100)
})


# ============================================================================
# Tests for calculate_velocity
# ============================================================================

test_that("calculate_velocity works with linear movement", {
  tracking_data <- create_linear_movement_data()

  vel <- calculate_velocity(tracking_data, smooth = FALSE)

  expect_s3_class(vel, "data.frame")
  expect_true("velocity" %in% names(vel))
  expect_true("velocity_x" %in% names(vel))
  expect_true("velocity_y" %in% names(vel))

  # Velocity should be constant at 100 pixels/second
  # (10 pixels per frame at 10 fps)
  valid_vel <- vel$velocity[!is.na(vel$velocity)]
  expect_equal(mean(valid_vel), 100, tolerance = 1.0)
})

test_that("calculate_velocity calculates components correctly", {
  tracking_data <- create_linear_movement_data()

  vel <- calculate_velocity(tracking_data, smooth = FALSE)

  # Movement is along x-axis, so velocity_y should be ~0
  valid_vel_y <- vel$velocity_y[!is.na(vel$velocity_y)]
  expect_true(all(abs(valid_vel_y) < 0.1))

  # velocity_x should be positive
  valid_vel_x <- vel$velocity_x[!is.na(vel$velocity_x)]
  expect_true(all(valid_vel_x > 0))
})

test_that("calculate_velocity applies scale factor correctly", {
  tracking_data <- create_linear_movement_data()

  vel <- calculate_velocity(tracking_data, scale_factor = 10, smooth = FALSE)

  # With scale factor of 10, velocity should be 10 cm/s
  valid_vel <- vel$velocity[!is.na(vel$velocity)]
  expect_equal(mean(valid_vel), 10, tolerance = 0.1)

  # Check units attribute
  expect_equal(attr(vel, "units"), "cm/s")
})

test_that("calculate_velocity smoothing works", {
  tracking_data <- create_linear_movement_data()

  vel_raw <- calculate_velocity(tracking_data, smooth = FALSE)
  vel_smooth <- calculate_velocity(tracking_data, smooth = TRUE, smooth_window = 3)

  # Smoothed velocities should have less variance
  var_raw <- var(vel_raw$velocity, na.rm = TRUE)
  var_smooth <- var(vel_smooth$velocity, na.rm = TRUE)

  # For constant velocity, both should be similar
  # But smoothed should handle noise better
  expect_true(var_smooth <= var_raw + 1.0)
})

test_that("calculate_velocity returns zero for stationary animal", {
  tracking_data <- create_stationary_data()

  vel <- calculate_velocity(tracking_data, smooth = FALSE)

  valid_vel <- vel$velocity[!is.na(vel$velocity)]
  expect_true(all(abs(valid_vel) < 0.1))
})

test_that("calculate_velocity validates inputs", {
  tracking_data <- create_linear_movement_data()

  # Invalid tracking_data
  expect_error(
    calculate_velocity(list()),
    "must be a tracking_data object"
  )

  # Invalid body part
  expect_error(
    calculate_velocity(tracking_data, body_part = "nonexistent"),
    "not found in tracking data"
  )

  # Missing FPS
  bad_data <- tracking_data
  bad_data$metadata$fps <- NULL
  expect_error(
    calculate_velocity(bad_data),
    "Invalid or missing FPS"
  )
})


# ============================================================================
# Tests for calculate_acceleration
# ============================================================================

test_that("calculate_acceleration works with constant velocity", {
  tracking_data <- create_linear_movement_data()

  accel <- calculate_acceleration(tracking_data, smooth = FALSE)

  expect_s3_class(accel, "data.frame")
  expect_true("acceleration" %in% names(accel))

  # With constant velocity, acceleration should be near zero
  valid_accel <- accel$acceleration[!is.na(accel$acceleration)]
  expect_true(mean(abs(valid_accel)) < 10)  # Allow some numerical error
})

test_that("calculate_acceleration applies scale factor correctly", {
  tracking_data <- create_linear_movement_data()

  accel <- calculate_acceleration(tracking_data, scale_factor = 10, smooth = FALSE)

  # Check units attribute
  expect_equal(attr(accel, "units"), "cm/s^2")
})


# ============================================================================
# Tests for calculate_movement_summary
# ============================================================================

test_that("calculate_movement_summary produces expected output", {
  tracking_data <- create_linear_movement_data()

  summary <- calculate_movement_summary(tracking_data)

  expect_s3_class(summary, "data.frame")
  expect_true("total_distance" %in% names(summary))
  expect_true("mean_velocity" %in% names(summary))
  expect_true("max_velocity" %in% names(summary))
  expect_true("duration_seconds" %in% names(summary))
  expect_true("percent_time_moving" %in% names(summary))

  # Check values
  expect_equal(summary$total_distance, 100, tolerance = 0.1)
  expect_true(summary$mean_velocity > 0)
  expect_true(summary$duration_seconds > 0)
  expect_true(summary$percent_time_moving > 50)  # Should be moving most of the time
})

test_that("calculate_movement_summary works with stationary animal", {
  tracking_data <- create_stationary_data()

  summary <- calculate_movement_summary(tracking_data)

  expect_equal(summary$total_distance, 0)
  expect_true(summary$percent_time_moving < 50)  # Should be mostly stationary
})


# ============================================================================
# Tests for detect_movement_bouts
# ============================================================================

test_that("detect_movement_bouts identifies continuous movement", {
  tracking_data <- create_linear_movement_data()

  bouts <- detect_movement_bouts(tracking_data, velocity_threshold = 50,
                                min_bout_duration = 0.1)

  expect_s3_class(bouts, "data.frame")
  expect_true(nrow(bouts) >= 1)  # Should detect at least one movement bout

  if (nrow(bouts) > 0) {
    expect_true("bout_type" %in% names(bouts))
    expect_true("duration" %in% names(bouts))
    expect_true(all(bouts$bout_type == "movement"))
    expect_true(all(bouts$duration >= 0.1))
  }
})

test_that("detect_movement_bouts returns empty for stationary animal", {
  tracking_data <- create_stationary_data()

  bouts <- detect_movement_bouts(tracking_data, velocity_threshold = 1.0,
                                min_bout_duration = 0.1)

  expect_s3_class(bouts, "data.frame")
  expect_equal(nrow(bouts), 0)
})

test_that("detect_movement_bouts respects minimum duration", {
  tracking_data <- create_linear_movement_data()

  # With very long minimum duration, should find no bouts
  bouts <- detect_movement_bouts(tracking_data, velocity_threshold = 50,
                                min_bout_duration = 10.0)

  expect_equal(nrow(bouts), 0)
})


# ============================================================================
# Tests for smooth_signal helper
# ============================================================================

test_that("smooth_signal smooths data correctly", {
  # Create noisy signal
  x <- c(1, 10, 2, 11, 3, 12, 4, 13, 5)

  smoothed <- smooth_signal(x, window = 3)

  expect_equal(length(smoothed), length(x))

  # Smoothed values should be between min and max
  expect_true(all(smoothed >= min(x, na.rm = TRUE)))
  expect_true(all(smoothed <= max(x, na.rm = TRUE)))
})

test_that("smooth_signal handles NA values", {
  x <- c(1, 2, NA, 4, 5)

  smoothed <- smooth_signal(x, window = 3)

  expect_equal(length(smoothed), length(x))
  expect_true(is.na(smoothed[3]))
})

test_that("smooth_signal handles edge cases", {
  # Window = 1 should return original
  x <- c(1, 2, 3, 4, 5)
  smoothed <- smooth_signal(x, window = 1)
  expect_equal(smoothed, x)

  # Empty vector
  smoothed <- smooth_signal(numeric(0), window = 3)
  expect_equal(length(smoothed), 0)
})
