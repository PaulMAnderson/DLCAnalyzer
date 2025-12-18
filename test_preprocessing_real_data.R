# Test preprocessing functions with real EPM data
# This script tests the preprocessing pipeline with actual DLC tracking data

library(testthat)

# Load required functions
source("R/core/data_structures.R")
source("R/core/data_loading.R")
source("R/core/data_converters.R")
source("R/core/preprocessing.R")

cat("================================================================================\n")
cat("Testing Preprocessing Functions with Real EPM Data\n")
cat("================================================================================\n\n")

# Load real EPM data
cat("1. Loading real EPM DLC file...\n")
dlc_file <- "data/EPM/Example DLC Data/ID7689_superanimal_topviewmouse_snapshot-hrnet_w32-004_snapshot-fasterrcnn_resnet50_fpn_v2-004__filtered.csv"

# Load and parse DLC data manually to handle -1 likelihood values
dlc_raw <- read_dlc_csv(dlc_file, fps = 30)
tracking_df <- parse_dlc_data(dlc_raw)

# DLC filtered files use -1 for filtered/low confidence points - convert to NA
tracking_df$likelihood[tracking_df$likelihood < 0] <- NA

# Create tracking_data object manually
metadata <- list(
  source = "deeplabcut",
  fps = 30,
  subject_id = "ID7689",
  session_id = NULL,
  paradigm = "epm",
  timestamp = Sys.time(),
  original_file = dlc_file,
  units = "pixels"
)

arena_dims <- infer_arena_dimensions(tracking_df)
arena <- list(
  dimensions = list(
    width = arena_dims$width,
    height = arena_dims$height,
    units = "pixels"
  ),
  reference_points = NULL,
  zones = NULL
)

tracking_data <- new_tracking_data(metadata, tracking_df, arena)
validate_tracking_data(tracking_data)

cat(sprintf("   Loaded %d frames with %d body parts\n",
            length(unique(tracking_data$tracking$frame)),
            length(unique(tracking_data$tracking$body_part))))
cat(sprintf("   Body parts: %s\n",
            paste(unique(tracking_data$tracking$body_part), collapse = ", ")))

# Check likelihood distribution before filtering
cat("\n2. Checking data quality before preprocessing...\n")
likelihood_summary <- summary(tracking_data$tracking$likelihood)
cat("   Likelihood distribution:\n")
print(likelihood_summary)

low_conf_count <- sum(tracking_data$tracking$likelihood < 0.9, na.rm = TRUE)
total_count <- sum(!is.na(tracking_data$tracking$likelihood))
cat(sprintf("   Points with likelihood < 0.9: %d of %d (%.2f%%)\n",
            low_conf_count, total_count, 100*low_conf_count/total_count))

# Step 1: Filter low confidence points
cat("\n3. Filtering low confidence points (threshold = 0.9)...\n")
filtered <- filter_low_confidence(tracking_data, threshold = 0.9, verbose = TRUE)

# Check how many points were filtered
na_count_before <- sum(is.na(tracking_data$tracking$x))
na_count_after <- sum(is.na(filtered$tracking$x))
cat(sprintf("   NA count: %d -> %d (added %d NAs)\n",
            na_count_before, na_count_after, na_count_after - na_count_before))

# Step 2: Interpolate missing values
cat("\n4. Interpolating missing values (max_gap = 5, method = linear)...\n")
interpolated <- interpolate_missing(filtered, method = "linear", max_gap = 5, verbose = TRUE)

na_count_interpolated <- sum(is.na(interpolated$tracking$x))
cat(sprintf("   NA count after interpolation: %d\n", na_count_interpolated))
cat(sprintf("   Successfully interpolated: %d values\n",
            na_count_after - na_count_interpolated))

# Step 3: Smooth trajectory
cat("\n5. Smoothing trajectory (method = savgol, window = 11)...\n")
smoothed <- smooth_trajectory(interpolated, method = "savgol", window = 11, verbose = TRUE)

# Check trajectory smoothness by comparing displacement variance
cat("\n6. Checking smoothing effectiveness...\n")
for (part in unique(tracking_data$tracking$body_part)[1:3]) {  # Test first 3 parts
  part_original <- tracking_data$tracking[tracking_data$tracking$body_part == part, ]
  part_smoothed <- smoothed$tracking[smoothed$tracking$body_part == part, ]

  # Calculate displacement (frame-to-frame movement)
  dx_original <- diff(part_original$x)
  dy_original <- diff(part_original$y)
  displacement_original <- sqrt(dx_original^2 + dy_original^2)

  dx_smoothed <- diff(part_smoothed$x)
  dy_smoothed <- diff(part_smoothed$y)
  displacement_smoothed <- sqrt(dx_smoothed^2 + dy_smoothed^2)

  sd_original <- sd(displacement_original, na.rm = TRUE)
  sd_smoothed <- sd(displacement_smoothed, na.rm = TRUE)

  cat(sprintf("   %s: displacement SD %.2f -> %.2f (%.1f%% reduction)\n",
              part, sd_original, sd_smoothed,
              100 * (sd_original - sd_smoothed) / sd_original))
}

# Compare different smoothing methods
cat("\n7. Comparing smoothing methods...\n")
test_part <- unique(tracking_data$tracking$body_part)[1]
part_data <- interpolated$tracking[interpolated$tracking$body_part == test_part, ]

smoothed_ma <- smooth_trajectory(interpolated, method = "ma", window = 11, body_parts = test_part)
smoothed_gaussian <- smooth_trajectory(interpolated, method = "gaussian", window = 11, body_parts = test_part)
smoothed_savgol <- smooth_trajectory(interpolated, method = "savgol", window = 11, body_parts = test_part)

part_ma <- smoothed_ma$tracking[smoothed_ma$tracking$body_part == test_part, ]
part_gaussian <- smoothed_gaussian$tracking[smoothed_gaussian$tracking$body_part == test_part, ]
part_savgol <- smoothed_savgol$tracking[smoothed_savgol$tracking$body_part == test_part, ]

cat(sprintf("   Testing smoothing on body part: %s\n", test_part))
cat(sprintf("   Moving average:    displacement SD = %.2f\n",
            sd(sqrt(diff(part_ma$x)^2 + diff(part_ma$y)^2), na.rm = TRUE)))
cat(sprintf("   Gaussian:          displacement SD = %.2f\n",
            sd(sqrt(diff(part_gaussian$x)^2 + diff(part_gaussian$y)^2), na.rm = TRUE)))
cat(sprintf("   Savitzky-Golay:    displacement SD = %.2f\n",
            sd(sqrt(diff(part_savgol$x)^2 + diff(part_savgol$y)^2), na.rm = TRUE)))

# Final summary
cat("\n8. Pipeline summary:\n")
cat(sprintf("   Original data: %d frames, %d body parts\n",
            length(unique(tracking_data$tracking$frame)),
            length(unique(tracking_data$tracking$body_part))))
cat(sprintf("   After filtering: %d NA values added\n",
            na_count_after - na_count_before))
cat(sprintf("   After interpolation: %d NA values remaining\n",
            na_count_interpolated))
cat(sprintf("   Final data quality: %.2f%% complete\n",
            100 * (1 - na_count_interpolated / nrow(smoothed$tracking))))

# Verify structure integrity
cat("\n9. Verifying data structure integrity...\n")
stopifnot(inherits(smoothed, "tracking_data"))
stopifnot(nrow(smoothed$tracking) == nrow(tracking_data$tracking))
stopifnot(all(names(smoothed) == names(tracking_data)))
stopifnot(smoothed$metadata$subject_id == tracking_data$metadata$subject_id)
cat("   ✓ Data structure preserved correctly\n")

cat("\n================================================================================\n")
cat("✓ All preprocessing tests passed successfully!\n")
cat("================================================================================\n")
