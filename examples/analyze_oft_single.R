#!/usr/bin/env Rscript
# Example: Single Subject Open Field Test (OFT) Analysis
#
# This script demonstrates how to analyze OFT data from Ethovision Excel exports.
# It loads tracking data, calculates behavioral metrics for center vs periphery zones,
# and generates a comprehensive report.

# ============================================================================
# SETUP
# ============================================================================

setwd("/mnt/g/Bella/Rebecca/Code/DLCAnalyzer")
source("tests/testthat/setup.R")

# Check for required packages
if (!requireNamespace("readxl", quietly = TRUE)) {
  stop("Package 'readxl' is required. Install with: install.packages('readxl')")
}

# ============================================================================
# CONFIGURATION
# ============================================================================

# Subject information
excel_file <- "data/OFT/Example Exported Data/Raw data-Rebecca OF Oct20th2025-Trial     1.xlsx"
paradigm <- "open_field"
fps <- 30  # Frames per second (adjust based on your recording)

# Arena configuration
arena_config_file <- "config/arena_definitions/OF/of_standard.yaml"
output_dir <- "reports/oft/trial1"

# Analysis parameters
body_part <- "mouse_center"

# ============================================================================
# STEP 1: LOAD DATA
# ============================================================================

cat("\n=== STEP 1: Loading Ethovision Data ===\n")

cat(sprintf("Loading Excel file: %s\n", basename(excel_file)))

# Load Ethovision data and convert to tracking_data format
tracking_data <- convert_ethovision_to_tracking_data(
  excel_file,
  fps = fps,
  paradigm = paradigm
)

# Extract subject ID from filename
subject_id <- gsub("Raw data-|.xlsx", "", basename(excel_file))
subject_id <- gsub("-Trial.*", "", subject_id)
tracking_data$metadata$subject_id <- subject_id

cat(sprintf("  Subject: %s\n", subject_id))
cat(sprintf("  Loaded %d frames (%.2f seconds)\n",
            nrow(tracking_data$tracking),
            nrow(tracking_data$tracking) / fps))

# Load arena configuration
cat(sprintf("\nLoading arena config: %s\n", basename(arena_config_file)))

# Check if arena config exists
if (!file.exists(arena_config_file)) {
  cat("  WARNING: Arena config not found. Creating default OF arena...\n")

  # Create a default open field arena (adjust dimensions as needed)
  arena <- new_arena_config(
    arena_id = "of_default",
    dimensions = list(width = 640, height = 480),  # Adjust to your video size
    zones = list(
      center = list(
        type = "circle",
        center_x = 320,
        center_y = 240,
        radius = 120
      ),
      periphery = list(
        type = "rectangle",
        x_min = 0,
        y_min = 0,
        x_max = 640,
        y_max = 480,
        exclude_zones = "center"  # Everything except center
      )
    )
  )
} else {
  arena <- load_arena_configs(arena_config_file, arena_id = "of_standard")
}

cat(sprintf("  Zones: %s\n", paste(names(arena$zones), collapse = ", ")))

# ============================================================================
# STEP 2: QUALITY ASSESSMENT
# ============================================================================

cat("\n=== STEP 2: Quality Assessment ===\n")

quality <- assess_tracking_quality(tracking_data, body_part = body_part)

cat(sprintf("  Overall quality: %.2f%%\n", quality$overall_quality * 100))
cat(sprintf("  Missing data: %.2f%%\n", quality$missing_pct))

# Interpolate if needed
if (quality$missing_pct > 0) {
  cat("  Interpolating missing data...\n")
  tracking_data <- interpolate_missing(tracking_data, method = "linear", max_gap = 10)
}

# ============================================================================
# STEP 3: CALCULATE METRICS
# ============================================================================

cat("\n=== STEP 3: Calculating OFT Metrics ===\n")

# Zone occupancy
cat("  Calculating zone occupancy...\n")
occupancy <- calculate_zone_occupancy(tracking_data, arena, body_part = body_part)
print(occupancy)

# Center vs periphery analysis
center_time <- occupancy$time_in_zone[occupancy$zone_id == "center"]
center_pct <- occupancy$percentage[occupancy$zone_id == "center"]

cat(sprintf("\n  Center zone:\n"))
cat(sprintf("    Time: %.2f seconds (%.2f%%)\n", center_time, center_pct))

# Zone entries
cat("\n  Calculating zone entries...\n")
entries <- calculate_zone_entries(tracking_data, arena, body_part = body_part)

center_entries <- entries$entry_count[entries$zone_id == "center"]
cat(sprintf("    Entries to center: %d\n", center_entries))

# Latency to center
latency <- calculate_zone_latency(tracking_data, arena, body_part = body_part)
center_latency <- latency$first_entry_time[latency$zone_id == "center"]
cat(sprintf("    Latency to center: %.2f seconds\n", center_latency))

# Movement metrics
cat("\n  Calculating movement metrics...\n")
distance <- calculate_distance_traveled(tracking_data, body_part = body_part)
velocity <- calculate_velocity(tracking_data, body_part = body_part)

cat(sprintf("    Total distance: %.2f pixels\n", distance$total_distance))
cat(sprintf("    Average velocity: %.2f pixels/sec\n", velocity$mean_velocity))

# ============================================================================
# STEP 4: GENERATE REPORT
# ============================================================================

cat("\n=== STEP 4: Generating Report ===\n")

report <- generate_subject_report(
  tracking_data,
  arena,
  output_dir = output_dir,
  body_part = body_part,
  format = "html"
)

# ============================================================================
# RESULTS SUMMARY
# ============================================================================

cat("\n", rep("=", 70), "\n", sep = "")
cat("OPEN FIELD TEST ANALYSIS COMPLETE!\n")
cat(rep("=", 70), "\n\n", sep = "")

cat("Subject:", subject_id, "\n")
cat("Duration:", sprintf("%.2f seconds", nrow(tracking_data$tracking) / fps), "\n\n")

cat("Key OFT Metrics:\n")
cat(sprintf("  - Time in center: %.2f%% (%.2f sec)\n", center_pct, center_time))
cat(sprintf("  - Entries to center: %d\n", center_entries))
cat(sprintf("  - Latency to center: %.2f sec\n", center_latency))
cat(sprintf("  - Total distance: %.2f pixels\n", distance$total_distance))
cat(sprintf("  - Average velocity: %.2f pixels/sec\n", velocity$mean_velocity))

cat("\nGenerated Files:\n")
cat(sprintf("  Report: %s\n", file.path(output_dir, sprintf("%s_report.html", subject_id))))
cat(sprintf("  Metrics: %s\n", file.path(output_dir, sprintf("%s_metrics.csv", subject_id))))

cat("\n", rep("=", 70), "\n", sep = "")
