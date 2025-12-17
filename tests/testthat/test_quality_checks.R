# Tests for quality_checks.R

library(testthat)

# Source required files (relative to tests/testthat directory)
source("../../R/core/data_structures.R")
source("../../R/core/quality_checks.R")

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

  body_parts <- paste0("part", 1:n_parts)

  tracking <- data.frame(
    frame = rep(1:n_frames, each = n_parts),
    time = rep(seq(0, length.out = n_frames, by = 1/30), each = n_parts),
    body_part = rep(body_parts, times = n_frames),
    x = rnorm(n_frames * n_parts, 250, 50),
    y = rnorm(n_frames * n_parts, 250, 50),
    likelihood = runif(n_frames * n_parts, 0.85, 1.0),
    stringsAsFactors = FALSE
  )

  new_tracking_data(metadata, tracking)
}

# =============================================================================
# Tests for check_tracking_quality()
# =============================================================================

context("check_tracking_quality")

test_that("check_tracking_quality returns correct structure", {
  data <- create_test_tracking_data()
  result <- check_tracking_quality(data)

  expect_s3_class(result, "quality_report")
  expect_type(result, "list")
  expect_named(result, c("overall", "likelihood", "missing_data", "recommendations"))

  expect_named(result$overall, c("total_frames", "body_parts", "fps", "duration_seconds"))
  expect_equal(result$overall$total_frames, 100)
  expect_equal(result$overall$fps, 30)
})

test_that("check_tracking_quality calculates likelihood statistics correctly", {
  data <- create_test_tracking_data(n_frames = 100)
  result <- check_tracking_quality(data)

  expect_true(is.data.frame(result$likelihood))
  expect_equal(nrow(result$likelihood), 2)  # 2 body parts
  expect_true(all(c("body_part", "mean_likelihood", "median_likelihood",
                    "min_likelihood", "q25", "q75") %in% names(result$likelihood)))

  # Check values are in valid range
  expect_true(all(result$likelihood$mean_likelihood >= 0 &
                  result$likelihood$mean_likelihood <= 1))
})

test_that("check_tracking_quality calculates missing data correctly", {
  data <- create_test_tracking_data()

  # Add some missing data
  data$tracking$x[1:10] <- NA
  data$tracking$y[101:110] <- NA

  result <- check_tracking_quality(data)

  expect_true(is.data.frame(result$missing_data))
  expect_equal(nrow(result$missing_data), 2)  # 2 body parts
  expect_true(all(c("body_part", "n_missing", "pct_missing") %in%
                  names(result$missing_data)))

  # Check that missing data was detected
  expect_true(any(result$missing_data$n_missing > 0))
})

test_that("check_tracking_quality generates recommendations", {
  data <- create_test_tracking_data()

  # Set low likelihood values
  data$tracking$likelihood[data$tracking$body_part == "part1"] <- 0.7

  result <- check_tracking_quality(data)

  expect_type(result$recommendations, "character")
  expect_true(length(result$recommendations) > 0)
  expect_true(any(grepl("filter", result$recommendations, ignore.case = TRUE)))
})

test_that("check_tracking_quality handles body_parts parameter", {
  data <- create_test_tracking_data(n_parts = 3)

  # Analyze only specific body parts
  result <- check_tracking_quality(data, body_parts = c("part1", "part2"))

  expect_equal(nrow(result$likelihood), 2)
  expect_equal(nrow(result$missing_data), 2)
  expect_true(all(result$likelihood$body_part %in% c("part1", "part2")))
})

test_that("check_tracking_quality validates input", {
  expect_error(check_tracking_quality("not tracking data"),
               "Input must be a tracking_data object")

  data <- create_test_tracking_data()
  expect_warning(check_tracking_quality(data, body_parts = c("nonexistent")),
                 "not found in the data")
})

test_that("check_tracking_quality warns about high missing data", {
  data <- create_test_tracking_data()

  # Add lots of missing data (>30%)
  idx <- data$tracking$body_part == "part1"
  data$tracking$x[idx][1:35] <- NA

  result <- check_tracking_quality(data)

  expect_true(any(grepl("WARNING.*30%", result$recommendations)))
})

# =============================================================================
# Tests for detect_outliers()
# =============================================================================

context("detect_outliers")

test_that("detect_outliers returns correct structure", {
  data <- create_test_tracking_data()
  result <- detect_outliers(data, method = "iqr")

  expect_true(is.data.frame(result))
  expect_true("is_outlier" %in% names(result))
  expect_type(result$is_outlier, "logical")
  expect_equal(nrow(result), nrow(data$tracking))
})

test_that("detect_outliers IQR method works correctly", {
  data <- create_test_tracking_data(n_frames = 100)

  # Add clear outliers
  data$tracking$x[1] <- 1000
  data$tracking$y[2] <- 1000

  result <- detect_outliers(data, method = "iqr", threshold = 1.5)

  expect_true(any(result$is_outlier))
  expect_true(result$is_outlier[1])  # First point should be outlier
  expect_true(result$is_outlier[2])  # Second point should be outlier
})

test_that("detect_outliers zscore method works correctly", {
  data <- create_test_tracking_data(n_frames = 100)

  # Add clear outliers
  data$tracking$x[1] <- 1000

  result <- detect_outliers(data, method = "zscore", threshold = 3)

  expect_true(any(result$is_outlier))
  expect_true(result$is_outlier[1])
})

test_that("detect_outliers MAD method works correctly", {
  data <- create_test_tracking_data(n_frames = 100)

  # Add clear outliers
  data$tracking$y[1] <- -500

  result <- detect_outliers(data, method = "mad", threshold = 3.5)

  expect_true(any(result$is_outlier))
  expect_true(result$is_outlier[1])
})

test_that("detect_outliers uses default thresholds", {
  data <- create_test_tracking_data()

  # Should not error with NULL threshold
  result_iqr <- detect_outliers(data, method = "iqr", threshold = NULL)
  result_z <- detect_outliers(data, method = "zscore", threshold = NULL)
  result_mad <- detect_outliers(data, method = "mad", threshold = NULL)

  expect_true(is.data.frame(result_iqr))
  expect_true(is.data.frame(result_z))
  expect_true(is.data.frame(result_mad))
})

test_that("detect_outliers handles missing data", {
  data <- create_test_tracking_data()

  # Add missing data
  data$tracking$x[1:10] <- NA
  data$tracking$y[11:20] <- NA

  result <- detect_outliers(data, method = "iqr")

  # Should not flag NA values as outliers
  expect_false(any(result$is_outlier[is.na(data$tracking$x)], na.rm = TRUE))
})

test_that("detect_outliers validates input", {
  data <- create_test_tracking_data()

  expect_error(detect_outliers("not tracking data"),
               "Input must be a tracking_data object")

  expect_error(detect_outliers(data, method = "invalid"),
               "method must be one of")

  expect_error(detect_outliers(data, threshold = -1),
               "threshold must be a positive numeric value")
})

test_that("detect_outliers handles body_parts parameter", {
  data <- create_test_tracking_data(n_parts = 3)

  # Add outlier to part1
  idx <- which(data$tracking$body_part == "part1")[1]
  data$tracking$x[idx] <- 1000

  result <- detect_outliers(data, method = "iqr", body_parts = "part1")

  # Should detect outlier in part1
  expect_true(any(result$is_outlier[data$tracking$body_part == "part1"]))
})

test_that("detect_outliers handles constant values", {
  data <- create_test_tracking_data()

  # Set all x values to constant (for one body part)
  idx <- data$tracking$body_part == "part1"
  data$tracking$x[idx] <- 100

  # Should not error
  result <- detect_outliers(data, method = "zscore")
  result2 <- detect_outliers(data, method = "mad")

  expect_true(is.data.frame(result))
  expect_true(is.data.frame(result2))
})

# =============================================================================
# Tests for calculate_missing_data_summary()
# =============================================================================

context("calculate_missing_data_summary")

test_that("calculate_missing_data_summary returns correct structure", {
  data <- create_test_tracking_data()

  # Add some missing data
  data$tracking$x[1:10] <- NA

  result <- calculate_missing_data_summary(data)

  expect_s3_class(result, "missing_data_summary")
  expect_type(result, "list")
  expect_named(result, c("summary", "gap_distribution", "longest_gaps"))

  expect_true(is.data.frame(result$summary))
  expect_true(is.data.frame(result$gap_distribution))
  expect_true(is.data.frame(result$longest_gaps))
})

test_that("calculate_missing_data_summary calculates statistics correctly", {
  data <- create_test_tracking_data(n_frames = 100)

  # Add missing data: 10 consecutive frames for part1
  idx <- which(data$tracking$body_part == "part1")[1:10]
  data$tracking$x[idx] <- NA
  data$tracking$y[idx] <- NA

  result <- calculate_missing_data_summary(data)

  # Check summary
  expect_equal(nrow(result$summary), 2)  # 2 body parts
  expect_true(all(c("body_part", "total_points", "n_missing",
                    "pct_missing", "n_gaps", "mean_gap_length") %in%
                  names(result$summary)))

  # Part1 should have missing data
  part1_summary <- result$summary[result$summary$body_part == "part1", ]
  expect_equal(part1_summary$n_missing, 10)
  expect_equal(part1_summary$pct_missing, 10)
  expect_equal(part1_summary$n_gaps, 1)
  expect_equal(part1_summary$mean_gap_length, 10)
})

test_that("calculate_missing_data_summary detects multiple gaps", {
  data <- create_test_tracking_data(n_frames = 100)

  # Add two gaps
  idx1 <- which(data$tracking$body_part == "part1")[1:5]
  idx2 <- which(data$tracking$body_part == "part1")[20:25]
  data$tracking$x[c(idx1, idx2)] <- NA

  result <- calculate_missing_data_summary(data)

  part1_summary <- result$summary[result$summary$body_part == "part1", ]
  expect_equal(part1_summary$n_gaps, 2)
  expect_equal(part1_summary$n_missing, 11)  # 5 + 6 missing points
})

test_that("calculate_missing_data_summary creates gap distribution", {
  data <- create_test_tracking_data(n_frames = 100)

  # Add gaps of different lengths
  idx1 <- which(data$tracking$body_part == "part1")[1:5]   # Gap of 5
  idx2 <- which(data$tracking$body_part == "part1")[20:22] # Gap of 3
  idx3 <- which(data$tracking$body_part == "part2")[10:14] # Gap of 5
  data$tracking$x[c(idx1, idx2, idx3)] <- NA

  result <- calculate_missing_data_summary(data)

  expect_true(nrow(result$gap_distribution) > 0)
  expect_true(all(c("gap_length", "frequency") %in% names(result$gap_distribution)))

  # Should have gaps of length 3 (freq 1) and 5 (freq 2)
  expect_true(3 %in% result$gap_distribution$gap_length)
  expect_true(5 %in% result$gap_distribution$gap_length)
})

test_that("calculate_missing_data_summary finds longest gaps", {
  data <- create_test_tracking_data(n_frames = 100)

  # Add gaps of different lengths
  idx1 <- which(data$tracking$body_part == "part1")[10:20]  # Gap of 11
  idx2 <- which(data$tracking$body_part == "part2")[30:35]  # Gap of 6
  data$tracking$x[c(idx1, idx2)] <- NA

  result <- calculate_missing_data_summary(data)

  expect_equal(nrow(result$longest_gaps), 2)  # One per body part
  expect_true(all(c("body_part", "gap_length", "start_frame", "end_frame") %in%
                  names(result$longest_gaps)))

  part1_longest <- result$longest_gaps[result$longest_gaps$body_part == "part1", ]
  expect_equal(part1_longest$gap_length, 11)
  expect_equal(part1_longest$start_frame, 10)
  expect_equal(part1_longest$end_frame, 20)
})

test_that("calculate_missing_data_summary handles no missing data", {
  data <- create_test_tracking_data()

  result <- calculate_missing_data_summary(data)

  expect_equal(nrow(result$summary), 2)
  expect_true(all(result$summary$n_missing == 0))
  expect_true(all(result$summary$n_gaps == 0))
  expect_equal(nrow(result$gap_distribution), 0)
  expect_equal(nrow(result$longest_gaps), 0)
})

test_that("calculate_missing_data_summary validates input", {
  expect_error(calculate_missing_data_summary("not tracking data"),
               "Input must be a tracking_data object")

  data <- create_test_tracking_data()
  expect_warning(calculate_missing_data_summary(data, body_parts = c("nonexistent")),
                 "not found in the data")
})

test_that("calculate_missing_data_summary handles body_parts parameter", {
  data <- create_test_tracking_data(n_parts = 3)

  # Add missing data to part1
  idx <- which(data$tracking$body_part == "part1")[1:10]
  data$tracking$x[idx] <- NA

  result <- calculate_missing_data_summary(data, body_parts = c("part1", "part2"))

  expect_equal(nrow(result$summary), 2)
  expect_true(all(result$summary$body_part %in% c("part1", "part2")))
})

# =============================================================================
# Tests for flag_suspicious_jumps()
# =============================================================================

context("flag_suspicious_jumps")

test_that("flag_suspicious_jumps returns correct structure", {
  data <- create_test_tracking_data()
  result <- flag_suspicious_jumps(data)

  expect_true(is.data.frame(result))
  expect_true(all(c("displacement", "is_suspicious_jump") %in% names(result)))
  expect_type(result$displacement, "double")
  expect_type(result$is_suspicious_jump, "logical")
  expect_equal(nrow(result), nrow(data$tracking))
})

test_that("flag_suspicious_jumps calculates displacement correctly", {
  # Create data with known displacement
  metadata <- list(source = "test", fps = 30, subject_id = "test",
                  session_id = "test", paradigm = "test",
                  timestamp = Sys.time(), original_file = "test.csv",
                  units = "pixels")

  tracking <- data.frame(
    frame = 1:3,
    time = c(0, 1/30, 2/30),
    body_part = "part1",
    x = c(0, 3, 0),  # Move 3 pixels right, then back
    y = c(0, 4, 0),  # Move 4 pixels up, then back
    likelihood = c(1, 1, 1),
    stringsAsFactors = FALSE
  )

  data <- new_tracking_data(metadata, tracking)
  result <- flag_suspicious_jumps(data, max_displacement = 10)

  # First frame should have NA displacement
  expect_true(is.na(result$displacement[1]))

  # Second frame: sqrt(3^2 + 4^2) = 5
  expect_equal(result$displacement[2], 5)

  # Third frame: sqrt(3^2 + 4^2) = 5
  expect_equal(result$displacement[3], 5)
})

test_that("flag_suspicious_jumps detects jumps with manual threshold", {
  data <- create_test_tracking_data(n_frames = 100)

  # Add a large jump
  idx <- which(data$tracking$body_part == "part1")[50]
  data$tracking$x[idx] <- data$tracking$x[idx-1] + 200  # Jump 200 pixels

  result <- flag_suspicious_jumps(data, max_displacement = 100)

  expect_true(any(result$is_suspicious_jump))
  expect_true(result$is_suspicious_jump[idx])

  # Check threshold is stored
  expect_equal(attr(result, "max_displacement"), 100)
})

test_that("flag_suspicious_jumps auto-calculates threshold", {
  data <- create_test_tracking_data(n_frames = 100)

  # Add a large jump
  idx <- which(data$tracking$body_part == "part1")[50]
  data$tracking$x[idx] <- data$tracking$x[idx-1] + 500

  result <- flag_suspicious_jumps(data, max_displacement = NULL)

  # Should detect the jump
  expect_true(any(result$is_suspicious_jump))

  # Threshold should be calculated (99th percentile)
  threshold <- attr(result, "max_displacement")
  expect_true(!is.null(threshold))
  expect_true(is.numeric(threshold))
  expect_true(threshold > 0)
})

test_that("flag_suspicious_jumps handles missing data", {
  data <- create_test_tracking_data(n_frames = 100)

  # Add missing data
  idx <- which(data$tracking$body_part == "part1")[10:20]
  data$tracking$x[idx] <- NA
  data$tracking$y[idx] <- NA

  result <- flag_suspicious_jumps(data)

  # Displacement should be NA for missing points
  expect_true(all(is.na(result$displacement[idx])))

  # Should not flag missing points as suspicious
  expect_false(any(result$is_suspicious_jump[idx]))
})

test_that("flag_suspicious_jumps validates input", {
  data <- create_test_tracking_data()

  expect_error(flag_suspicious_jumps("not tracking data"),
               "Input must be a tracking_data object")

  expect_error(flag_suspicious_jumps(data, max_displacement = -10),
               "max_displacement must be a positive numeric value")
})

test_that("flag_suspicious_jumps handles body_parts parameter", {
  data <- create_test_tracking_data(n_parts = 3)

  # Add jump to part1
  idx <- which(data$tracking$body_part == "part1")[50]
  data$tracking$x[idx] <- data$tracking$x[idx-1] + 500

  result <- flag_suspicious_jumps(data, body_parts = c("part1"))

  # Should have displacement calculated for part1
  expect_true(any(!is.na(result$displacement[data$tracking$body_part == "part1"])))

  # Should detect jump in part1
  expect_true(any(result$is_suspicious_jump[data$tracking$body_part == "part1"]))
})

test_that("flag_suspicious_jumps handles first frame correctly", {
  data <- create_test_tracking_data()
  result <- flag_suspicious_jumps(data)

  # First frame of each body part should have NA displacement
  first_frames <- !duplicated(result$body_part)
  expect_true(all(is.na(result$displacement[first_frames])))
  expect_false(any(result$is_suspicious_jump[first_frames]))
})

# =============================================================================
# Tests for generate_quality_report()
# =============================================================================

context("generate_quality_report")

test_that("generate_quality_report returns list format correctly", {
  data <- create_test_tracking_data()
  result <- generate_quality_report(data, output_format = "list")

  expect_type(result, "list")
  expect_named(result, c("quality", "outliers", "missing_data", "jumps"))

  expect_s3_class(result$quality, "quality_report")
  expect_type(result$outliers, "list")
  expect_s3_class(result$missing_data, "missing_data_summary")
  expect_type(result$jumps, "list")
})

test_that("generate_quality_report returns text format correctly", {
  data <- create_test_tracking_data()
  result <- generate_quality_report(data, output_format = "text")

  expect_type(result, "character")
  expect_true(length(result) > 0)

  # Check for key sections
  report_text <- paste(result, collapse = " ")
  expect_true(grepl("QUALITY REPORT", report_text, ignore.case = TRUE))
  expect_true(grepl("OVERALL STATISTICS", report_text, ignore.case = TRUE))
  expect_true(grepl("MISSING DATA", report_text, ignore.case = TRUE))
})

test_that("generate_quality_report includes all metrics", {
  data <- create_test_tracking_data()

  # Add some issues
  data$tracking$x[1:10] <- NA  # Missing data
  data$tracking$x[50] <- 1000  # Outlier
  # Set low likelihood for part1
  idx_part1 <- data$tracking$body_part == "part1"
  data$tracking$likelihood[idx_part1] <- 0.7  # Low likelihood

  result <- generate_quality_report(data, output_format = "list")

  # Check all components are present
  expect_true(result$outliers$n_outliers > 0)
  expect_true(any(result$missing_data$summary$n_missing > 0))
  expect_true(length(result$quality$recommendations) > 0)
})

test_that("generate_quality_report validates input", {
  expect_error(generate_quality_report("not tracking data"),
               "Input must be a tracking_data object")

  data <- create_test_tracking_data()
  expect_error(generate_quality_report(data, output_format = "invalid"),
               "output_format must be either 'text' or 'list'")
})

# =============================================================================
# Tests for print methods
# =============================================================================

context("print methods")

test_that("print.quality_report works", {
  data <- create_test_tracking_data()
  quality <- check_tracking_quality(data)

  # Should not error
  expect_output(print(quality), "Quality Report")
})

test_that("print.missing_data_summary works", {
  data <- create_test_tracking_data()
  data$tracking$x[1:10] <- NA

  missing <- calculate_missing_data_summary(data)

  # Should not error
  expect_output(print(missing), "Missing Data Summary")
})

# =============================================================================
# Integration tests
# =============================================================================

context("Integration tests")

test_that("Quality check functions work together", {
  # Create realistic data
  data <- create_test_tracking_data(n_frames = 300, n_parts = 3)

  # Add various issues
  # 1. Low likelihood for part1
  idx_part1 <- data$tracking$body_part == "part1"
  data$tracking$likelihood[idx_part1] <- runif(sum(idx_part1), 0.5, 0.7)

  # 2. Missing data
  idx2 <- 50:60
  data$tracking$x[idx2] <- NA
  data$tracking$y[idx2] <- NA

  # 3. Outlier
  idx3 <- 100
  data$tracking$x[idx3] <- 1000

  # 4. Large jump
  idx4 <- 200
  data$tracking$x[idx4] <- data$tracking$x[idx4-1] + 300

  # Run all checks
  quality <- check_tracking_quality(data)
  outliers <- detect_outliers(data, method = "iqr")
  missing <- calculate_missing_data_summary(data)
  jumps <- flag_suspicious_jumps(data)
  report <- generate_quality_report(data, output_format = "list")

  # Verify all checks detected issues
  expect_true(length(quality$recommendations) > 0)
  expect_true(sum(outliers$is_outlier) > 0)
  expect_true(any(missing$summary$n_missing > 0))
  expect_true(sum(jumps$is_suspicious_jump, na.rm = TRUE) > 0)

  # Verify report includes all
  expect_true(report$outliers$n_outliers > 0)
  expect_true(report$jumps$n_suspicious_jumps > 0)
})

test_that("Quality checks handle edge case: all missing data", {
  data <- create_test_tracking_data()

  # Make all data for one part missing
  idx <- data$tracking$body_part == "part1"
  data$tracking$x[idx] <- NA
  data$tracking$y[idx] <- NA

  # Should not error
  quality <- check_tracking_quality(data)
  outliers <- detect_outliers(data)
  missing <- calculate_missing_data_summary(data)
  jumps <- flag_suspicious_jumps(data)

  expect_s3_class(quality, "quality_report")
  expect_true(is.data.frame(outliers))
  expect_s3_class(missing, "missing_data_summary")
  expect_true(is.data.frame(jumps))
})

test_that("Quality checks handle edge case: perfect data", {
  # Create data with no outliers - use constant values
  metadata <- list(source = "test", fps = 30, subject_id = "test",
                  session_id = "test", paradigm = "test",
                  timestamp = Sys.time(), original_file = "test.csv",
                  units = "pixels")

  tracking <- data.frame(
    frame = rep(1:100, each = 2),
    time = rep(seq(0, length.out = 100, by = 1/30), each = 2),
    body_part = rep(c("part1", "part2"), times = 100),
    x = rep(250, 200),  # Constant values - no outliers
    y = rep(250, 200),
    likelihood = 1.0,
    stringsAsFactors = FALSE
  )

  data <- new_tracking_data(metadata, tracking)

  quality <- check_tracking_quality(data)
  outliers <- detect_outliers(data)
  missing <- calculate_missing_data_summary(data)
  jumps <- flag_suspicious_jumps(data)

  # Should have no issues
  expect_equal(sum(outliers$is_outlier), 0)
  expect_true(all(missing$summary$n_missing == 0))
  expect_true(all(quality$missing_data$pct_missing == 0))
})
