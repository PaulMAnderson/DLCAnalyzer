# tests/test_movement_epm.R
# Integration test for movement metrics with real EPM data

# Source all R files
source("R/core/data_structures.R")
source("R/core/data_loading.R")
source("R/core/data_converters.R")
source("R/core/arena_config.R")
source("R/core/zone_geometry.R")
source("R/core/coordinate_transforms.R")
source("R/utils/config_utils.R")
source("R/metrics/zone_analysis.R")
source("R/metrics/movement_metrics.R")

cat("\n=== Testing Movement Metrics with Real EPM Data ===\n\n")

# Find EPM data files
epm_files <- list.files("data/EPM/Example DLC Data/",
                       pattern = "\\.csv$",
                       full.names = TRUE)

if (length(epm_files) == 0) {
  stop("No EPM data files found!")
}

cat("Found", length(epm_files), "EPM data files\n")
cat("Using:", basename(epm_files[1]), "\n\n")

# Load EPM data
cat("Step 1: Loading tracking data...\n")
tracking_data <- convert_dlc_to_tracking_data(
  epm_files[1],
  fps = 30,
  subject_id = "ID7689_movement_test",
  paradigm = "epm"
)

cat("  - Loaded", nrow(tracking_data$tracking), "frames\n")
cat("  - Duration:", round(max(tracking_data$tracking$time), 2), "seconds\n")
cat("  - Body parts:", paste(unique(tracking_data$tracking$body_part), collapse = ", "), "\n\n")

# Test 1: Calculate total distance traveled
cat("Step 2: Testing calculate_distance_traveled()...\n")
tryCatch({
  distance_pixels <- calculate_distance_traveled(tracking_data, body_part = "mouse_center")
  cat("  - Total distance (pixels):", round(distance_pixels, 2), "\n")

  # With scale factor (assuming 10 pixels/cm for EPM)
  distance_cm <- calculate_distance_traveled(tracking_data, body_part = "mouse_center",
                                            scale_factor = 10)
  cat("  - Total distance (cm):", round(distance_cm, 2), "\n")
  cat("  SUCCESS: Distance calculation\n\n")
}, error = function(e) {
  cat("  ERROR:", e$message, "\n\n")
})

# Test 2: Calculate velocity
cat("Step 3: Testing calculate_velocity()...\n")
tryCatch({
  velocity <- calculate_velocity(tracking_data, body_part = "mouse_center",
                                 scale_factor = 10, smooth = TRUE)

  cat("  - Mean velocity (cm/s):", round(mean(velocity$velocity, na.rm = TRUE), 2), "\n")
  cat("  - Max velocity (cm/s):", round(max(velocity$velocity, na.rm = TRUE), 2), "\n")
  cat("  - Median velocity (cm/s):", round(median(velocity$velocity, na.rm = TRUE), 2), "\n")
  cat("  - Data points with velocity:", sum(!is.na(velocity$velocity)), "\n")
  cat("  SUCCESS: Velocity calculation\n\n")
}, error = function(e) {
  cat("  ERROR:", e$message, "\n\n")
})

# Test 3: Calculate acceleration
cat("Step 4: Testing calculate_acceleration()...\n")
tryCatch({
  acceleration <- calculate_acceleration(tracking_data, body_part = "mouse_center",
                                        scale_factor = 10, smooth = TRUE)

  cat("  - Mean |acceleration| (cm/s^2):",
      round(mean(abs(acceleration$acceleration), na.rm = TRUE), 2), "\n")
  cat("  - Max acceleration (cm/s^2):",
      round(max(acceleration$acceleration, na.rm = TRUE), 2), "\n")
  cat("  - Data points with acceleration:", sum(!is.na(acceleration$acceleration)), "\n")
  cat("  SUCCESS: Acceleration calculation\n\n")
}, error = function(e) {
  cat("  ERROR:", e$message, "\n\n")
})

# Test 4: Calculate movement summary
cat("Step 5: Testing calculate_movement_summary()...\n")
tryCatch({
  summary <- calculate_movement_summary(tracking_data, body_part = "mouse_center",
                                       scale_factor = 10)

  cat("  Movement Summary:\n")
  cat("  - Total distance:", round(summary$total_distance, 2), summary$distance_units, "\n")
  cat("  - Mean velocity:", round(summary$mean_velocity, 2), summary$velocity_units, "\n")
  cat("  - Median velocity:", round(summary$median_velocity, 2), summary$velocity_units, "\n")
  cat("  - Max velocity:", round(summary$max_velocity, 2), summary$velocity_units, "\n")
  cat("  - Duration:", round(summary$duration_seconds, 2), "seconds\n")
  cat("  - % time moving:", round(summary$percent_time_moving, 2), "%\n")
  cat("  SUCCESS: Movement summary\n\n")
}, error = function(e) {
  cat("  ERROR:", e$message, "\n\n")
})

# Test 5: Detect movement bouts
cat("Step 6: Testing detect_movement_bouts()...\n")
tryCatch({
  # Use a reasonable velocity threshold (2 cm/s)
  bouts <- detect_movement_bouts(tracking_data, body_part = "mouse_center",
                                velocity_threshold = 2.0,
                                min_bout_duration = 0.5,
                                scale_factor = 10)

  cat("  - Number of movement bouts detected:", nrow(bouts), "\n")

  if (nrow(bouts) > 0) {
    cat("  - Mean bout duration:", round(mean(bouts$duration), 2), "seconds\n")
    cat("  - Median bout duration:", round(median(bouts$duration), 2), "seconds\n")
    cat("  - Total time in bouts:", round(sum(bouts$duration), 2), "seconds\n")

    # Show first few bouts
    cat("\n  First 5 bouts:\n")
    print(head(bouts, 5))
  }

  cat("  SUCCESS: Bout detection\n\n")
}, error = function(e) {
  cat("  ERROR:", e$message, "\n\n")
})

# Test 6: Distance by zone (if arena config available)
cat("Step 7: Testing calculate_distance_traveled() by zone...\n")
arena_config_file <- "config/arena_definitions/EPM/EPM.yaml"

if (file.exists(arena_config_file)) {
  tryCatch({
    arena <- load_arena_configs(arena_config_file, arena_id = "arena1")

    distance_by_zone <- calculate_distance_traveled(tracking_data,
                                                    body_part = "mouse_center",
                                                    scale_factor = 10,
                                                    by_zone = TRUE,
                                                    arena_config = arena)

    cat("  Distance traveled by zone:\n")
    print(distance_by_zone)
    cat("  SUCCESS: Distance by zone\n\n")
  }, error = function(e) {
    cat("  ERROR:", e$message, "\n\n")
  })
} else {
  cat("  SKIPPED: Arena config not found\n\n")
}

# Velocity distribution analysis
cat("Step 8: Velocity distribution analysis...\n")
tryCatch({
  velocity <- calculate_velocity(tracking_data, body_part = "mouse_center",
                                 scale_factor = 10, smooth = TRUE)

  # Calculate percentiles
  vel_values <- velocity$velocity[!is.na(velocity$velocity)]
  percentiles <- quantile(vel_values, probs = c(0.25, 0.50, 0.75, 0.90, 0.95, 0.99))

  cat("  Velocity percentiles (cm/s):\n")
  cat("    25th:", round(percentiles[1], 2), "\n")
  cat("    50th:", round(percentiles[2], 2), "\n")
  cat("    75th:", round(percentiles[3], 2), "\n")
  cat("    90th:", round(percentiles[4], 2), "\n")
  cat("    95th:", round(percentiles[5], 2), "\n")
  cat("    99th:", round(percentiles[6], 2), "\n")

  # Calculate % time in different velocity ranges
  pct_low <- 100 * sum(vel_values < 1) / length(vel_values)
  pct_med <- 100 * sum(vel_values >= 1 & vel_values < 5) / length(vel_values)
  pct_high <- 100 * sum(vel_values >= 5) / length(vel_values)

  cat("\n  Time in velocity ranges:\n")
  cat("    Low (<1 cm/s):", round(pct_low, 2), "%\n")
  cat("    Medium (1-5 cm/s):", round(pct_med, 2), "%\n")
  cat("    High (>=5 cm/s):", round(pct_high, 2), "%\n")

  cat("  SUCCESS: Velocity distribution analysis\n\n")
}, error = function(e) {
  cat("  ERROR:", e$message, "\n\n")
})

cat("=== Movement Metrics Testing Complete ===\n")
