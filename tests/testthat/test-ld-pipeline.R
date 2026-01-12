#' Tests for LD Pipeline
#'
#' Comprehensive tests for the Light/Dark box analysis pipeline.

library(testthat)

# Test data path
test_data_path <- "../../data/LD/LD 20251001/Raw data-LD Rebecca 20251001-Trial     1 (2).xlsx"

# Skip tests if test data not available
skip_if_no_test_data <- function() {
  if (!file.exists(test_data_path)) {
    skip("Test data file not found")
  }
}

# ===== Common I/O Functions Tests =====

test_that("parse_ethovision_sheet_name extracts arena and subject IDs", {
  result <- parse_ethovision_sheet_name("Track-Arena 1-Subject 1")
  expect_equal(result$arena_id, 1)
  expect_equal(result$subject_id, 1)
  expect_equal(result$raw_name, "Track-Arena 1-Subject 1")

  result2 <- parse_ethovision_sheet_name("Track-Arena 4-Subject 12")
  expect_equal(result2$arena_id, 4)
  expect_equal(result2$subject_id, 12)
})

test_that("identify_zone_columns finds zone columns", {
  cols <- c(
    "Trial time",
    "X center",
    "Y center",
    "In zone(light floor 1 / Center-point)",
    "In zone(door area 1 / Center-point)",
    "In zone(Arena 1 / Center-point)"
  )

  zone_info <- identify_zone_columns(cols)

  expect_true(nrow(zone_info) >= 2)
  expect_true("zone_name" %in% colnames(zone_info))
  expect_true("body_part" %in% colnames(zone_info))
  expect_true("arena_number" %in% colnames(zone_info))

  # Should exclude parent Arena zone
  expect_false(any(grepl("^Arena[[:space:]]*[0-9]*$", zone_info$zone_name,
                         ignore.case = TRUE)))
})

test_that("identify_zone_columns filters by paradigm", {
  cols <- c(
    "In zone(light floor 1 / Center-point)",
    "In zone(center1 / Center-point)",
    "In zone(object left / Center-point)"
  )

  # LD paradigm should only get light floor
  ld_zones <- identify_zone_columns(cols, paradigm = "ld")
  expect_true(any(grepl("light floor", ld_zones$zone_name)))
  expect_false(any(grepl("center1", ld_zones$zone_name)))

  # OFT paradigm should only get center
  oft_zones <- identify_zone_columns(cols, paradigm = "oft")
  expect_true(any(grepl("center", oft_zones$zone_name)))
  expect_false(any(grepl("light floor", oft_zones$zone_name)))
})

# ===== Geometry Functions Tests =====

test_that("euclidean_distance calculates correctly", {
  expect_equal(euclidean_distance(0, 0, 3, 4), 5)
  expect_equal(euclidean_distance(0, 0, 0, 0), 0)
  expect_equal(euclidean_distance(1, 1, 4, 5), 5)
})

test_that("calculate_distances computes trajectory distances", {
  df <- data.frame(x = c(0, 1, 2, 3), y = c(0, 0, 0, 0))
  distances <- calculate_distances(df)
  expect_equal(length(distances), 3)
  expect_equal(distances, c(1, 1, 1))
})

test_that("calculate_total_distance sums correctly", {
  df <- data.frame(x = c(0, 1, 2, 3), y = c(0, 0, 0, 0))
  total <- calculate_total_distance(df)
  expect_equal(total, 3)
})

test_that("calculate_distance_by_zone filters by zone", {
  df <- data.frame(
    x = c(0, 1, 2, 3, 4),
    y = c(0, 0, 0, 0, 0),
    zone = c(1, 1, 1, 0, 0)
  )
  dist <- calculate_distance_by_zone(df, "zone")
  expect_equal(dist, 2)  # Only first 3 segments
})

# ===== LD Analysis Functions Tests =====

test_that("calculate_zone_time works correctly", {
  zone_vec <- c(0, 0, 1, 1, 1, 0, 1, 1)
  time_sec <- calculate_zone_time(zone_vec, fps = 25)
  expect_equal(time_sec, 5 / 25)  # 5 frames at 25 fps
})

test_that("detect_zone_entries counts transitions", {
  zone_vec <- c(0, 0, 1, 1, 1, 0, 1, 1, 0, 0, 1)
  entries <- detect_zone_entries(zone_vec)
  expect_equal(entries, 3)  # Three 0->1 transitions
})

test_that("calculate_zone_latency finds first entry", {
  zone_vec <- c(0, 0, 0, 1, 1, 0)
  latency <- calculate_zone_latency(zone_vec, fps = 25)
  expect_equal(latency, 3 / 25)  # Frame 3 at 25 fps

  # Test no entry case
  zone_vec_no_entry <- c(0, 0, 0, 0)
  latency_na <- calculate_zone_latency(zone_vec_no_entry, fps = 25)
  expect_true(is.na(latency_na))
})

test_that("calculate_distance_in_zone computes correctly", {
  x <- c(0, 1, 2, 3, 4)
  y <- c(0, 0, 0, 0, 0)
  zone <- c(1, 1, 1, 0, 0)

  dist <- calculate_distance_in_zone(x, y, zone)
  expect_equal(dist, 2)  # Distance for frames 1-2 only
})

# ===== Integration Tests with Real Data =====

test_that("load_ld_data reads Ethovision file", {
  skip_if_no_test_data()

  ld_data <- load_ld_data(test_data_path, fps = 25)

  expect_true(is.list(ld_data))
  expect_true(length(ld_data) > 0)

  # Check structure of first arena
  arena1 <- ld_data[[1]]
  expect_true("data" %in% names(arena1))
  expect_true("arena_id" %in% names(arena1))
  expect_true("fps" %in% names(arena1))

  # Check data frame structure
  df <- arena1$data
  expect_true(is.data.frame(df))
  expect_true("time" %in% colnames(df))
  expect_true("x_center" %in% colnames(df))
  expect_true("y_center" %in% colnames(df))

  # Check for zone columns
  zone_cols <- grep("^zone_", colnames(df), value = TRUE)
  expect_true(length(zone_cols) > 0)

  message("Loaded ", length(ld_data), " arenas")
  message("Zone columns found: ", paste(zone_cols, collapse = ", "))
})

test_that("validate_ld_data checks data structure", {
  skip_if_no_test_data()

  ld_data <- load_ld_data(test_data_path, fps = 25)
  is_valid <- validate_ld_data(ld_data)

  expect_true(is_valid)
})

test_that("summarize_ld_data provides summary", {
  skip_if_no_test_data()

  ld_data <- load_ld_data(test_data_path, fps = 25)
  summary <- summarize_ld_data(ld_data)

  expect_true(is.data.frame(summary))
  expect_true("arena" %in% colnames(summary))
  expect_true("n_frames" %in% colnames(summary))
  expect_true("duration_sec" %in% colnames(summary))
  expect_true("n_zones" %in% colnames(summary))

  print(summary)
})

test_that("analyze_ld computes all metrics", {
  skip_if_no_test_data()

  ld_data <- load_ld_data(test_data_path, fps = 25)
  arena1 <- ld_data[[1]]

  results <- analyze_ld(arena1$data, fps = 25)

  # Check all expected metrics are present
  expected_metrics <- c(
    "time_in_light_sec", "time_in_dark_sec",
    "pct_time_in_light", "pct_time_in_dark",
    "entries_to_light", "entries_to_dark",
    "latency_to_light_sec", "latency_to_dark_sec",
    "distance_in_light_cm", "distance_in_dark_cm",
    "total_distance_cm", "transitions", "total_duration_sec"
  )

  for (metric in expected_metrics) {
    expect_true(metric %in% names(results),
                info = paste("Missing metric:", metric))
  }

  # Check reasonable values
  expect_true(results$time_in_light_sec >= 0)
  expect_true(results$time_in_dark_sec >= 0)
  expect_true(results$pct_time_in_light >= 0 && results$pct_time_in_light <= 100)
  expect_true(results$entries_to_light >= 0)
  expect_true(results$total_distance_cm >= 0)

  message("Sample metrics:")
  message("  Time in light: ", round(results$time_in_light_sec, 2), " sec (",
          round(results$pct_time_in_light, 1), "%)")
  message("  Entries to light: ", results$entries_to_light)
  message("  Total distance: ", round(results$total_distance_cm, 2), " cm")
})

test_that("analyze_ld_batch processes multiple arenas", {
  skip_if_no_test_data()

  ld_data <- load_ld_data(test_data_path, fps = 25)
  batch_results <- analyze_ld_batch(ld_data, fps = 25)

  expect_true(is.data.frame(batch_results))
  expect_equal(nrow(batch_results), length(ld_data))

  expect_true("arena_name" %in% colnames(batch_results))
  expect_true("pct_time_in_light" %in% colnames(batch_results))
  expect_true("entries_to_light" %in% colnames(batch_results))

  print(batch_results[, c("arena_name", "pct_time_in_light",
                          "entries_to_light", "total_distance_cm")])
})

test_that("export_ld_results saves CSV", {
  skip_if_no_test_data()

  ld_data <- load_ld_data(test_data_path, fps = 25)
  batch_results <- analyze_ld_batch(ld_data, fps = 25)

  temp_file <- tempfile(fileext = ".csv")
  export_ld_results(batch_results, temp_file, overwrite = TRUE)

  expect_true(file.exists(temp_file))

  # Read back and verify
  loaded <- read.csv(temp_file)
  expect_equal(nrow(loaded), nrow(batch_results))

  # Clean up
  unlink(temp_file)
})

# ===== Plotting Tests =====

test_that("plotting functions create ggplot objects", {
  skip_if_not_installed("ggplot2")

  # Test data
  x <- rnorm(100, mean = 10, sd = 5)
  y <- rnorm(100, mean = 20, sd = 5)

  # Trajectory plot
  p1 <- plot_trajectory(x, y, title = "Test Trajectory")
  expect_s3_class(p1, "ggplot")

  # Heatmap
  p2 <- plot_heatmap(x, y, bins = 20, title = "Test Heatmap")
  expect_s3_class(p2, "ggplot")

  # Zone occupancy
  zone_times <- c(light = 120, dark = 180)
  p3 <- plot_zone_occupancy(zone_times)
  expect_s3_class(p3, "ggplot")
})

# ===== Report Generation Tests =====

test_that("generate_ld_report creates output files", {
  skip_if_no_test_data()
  skip_if_not_installed("ggplot2")

  ld_data <- load_ld_data(test_data_path, fps = 25)
  arena1 <- ld_data[[1]]

  temp_dir <- tempfile()
  dir.create(temp_dir)

  output <- generate_ld_report(arena1, output_dir = temp_dir,
                               subject_id = "TestSubject")

  # Check that files were created
  expect_true(file.exists(output$trajectory))
  expect_true(file.exists(output$heatmap))
  expect_true(file.exists(output$zone_time))
  expect_true(file.exists(output$metrics_csv))
  expect_true(file.exists(output$summary_txt))

  # Verify metrics CSV
  metrics <- read.csv(output$metrics_csv)
  expect_true(nrow(metrics) > 0)

  # Clean up
  unlink(temp_dir, recursive = TRUE)
})

test_that("generate_ld_batch_report processes all arenas", {
  skip_if_no_test_data()
  skip_if_not_installed("ggplot2")

  ld_data <- load_ld_data(test_data_path, fps = 25)

  temp_dir <- tempfile()
  dir.create(temp_dir)

  reports <- generate_ld_batch_report(ld_data, output_dir = temp_dir, fps = 25)

  # Check batch CSV
  expect_true(file.exists(reports$batch_csv))
  batch_data <- read.csv(reports$batch_csv)
  expect_equal(nrow(batch_data), length(ld_data))

  # Check individual reports
  expect_equal(length(reports$individual_reports), length(ld_data))

  # Clean up
  unlink(temp_dir, recursive = TRUE)
})

# ===== Print Summary =====

message("\n========================================")
message("LD Pipeline Tests Summary")
message("========================================")
message("Test data path: ", test_data_path)
message("Test data exists: ", file.exists(test_data_path))
message("========================================\n")
