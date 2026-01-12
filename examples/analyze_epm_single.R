#!/usr/bin/env Rscript
# Example: Single Subject EPM Analysis
#
# This script demonstrates how to analyze a single EPM (Elevated Plus Maze) subject
# using DLCAnalyzer. It loads DLC tracking data, applies quality checks, calculates
# behavioral metrics, and generates a comprehensive HTML report.

# ============================================================================
# SETUP
# ============================================================================

# Set working directory to package root
setwd("/mnt/g/Bella/Rebecca/Code/DLCAnalyzer")

# Source all DLCAnalyzer functions
cat("Loading DLCAnalyzer functions...\n")
source("tests/testthat/setup.R")

# ============================================================================
# CONFIGURATION
# ============================================================================

# Subject information
subject_id <- "ID7689"
paradigm <- "epm"
fps <- 30  # Frames per second

# File paths
dlc_file <- "data/EPM/Example DLC Data/ID7689_superanimal_topviewmouse_snapshot-hrnet_w32-004_snapshot-fasterrcnn_resnet50_fpn_v2-004__filtered.csv"
arena_config_file <- "config/arena_definitions/EPM/EPM.yaml"
output_dir <- "reports/epm/ID7689"

# Analysis parameters
body_part <- "mouse_center"  # Which body part to analyze
likelihood_threshold <- 0.9  # Confidence threshold for filtering

# ============================================================================
# STEP 1: LOAD DATA
# ============================================================================

cat("\n=== STEP 1: Loading Data ===\n")

# Load DLC tracking data
cat(sprintf("Loading DLC data: %s\n", basename(dlc_file)))
tracking_data <- convert_dlc_to_tracking_data(
  dlc_file,
  fps = fps,
  subject_id = subject_id,
  paradigm = paradigm
)

cat(sprintf("  Loaded %d frames (%.2f seconds)\n",
            nrow(tracking_data$tracking),
            nrow(tracking_data$tracking) / fps))
cat(sprintf("  Body parts: %s\n",
            paste(unique(tracking_data$tracking$body_part), collapse = ", ")))

# Load arena configuration
cat(sprintf("\nLoading arena config: %s\n", basename(arena_config_file)))
arena <- load_arena_configs(
  arena_config_file,
  arena_id = "arena1"
)

cat(sprintf("  Arena dimensions: %.1f x %.1f pixels\n",
            arena$dimensions$width,
            arena$dimensions$height))
cat(sprintf("  Zones defined: %s\n",
            paste(names(arena$zones), collapse = ", ")))

# ============================================================================
# STEP 2: QUALITY ASSESSMENT
# ============================================================================

cat("\n=== STEP 2: Quality Assessment ===\n")

# Assess tracking quality
quality <- check_tracking_quality(
  tracking_data,
  body_part = body_part
)

# Display quality metrics
if (nrow(quality$likelihood) > 0) {
  cat("  Likelihood statistics:\n")
  print(quality$likelihood)
}

if (nrow(quality$missing_data) > 0) {
  cat("\n  Missing data:\n")
  print(quality$missing_data)

  # Get missing percentage for the body part we're analyzing
  missing_pct <- quality$missing_data$pct_missing[quality$missing_data$body_part == body_part]
  if (length(missing_pct) == 0) missing_pct <- 0
}

# Optional: Filter low confidence points
if (nrow(quality$likelihood) > 0) {
  mean_likelihood <- quality$likelihood$mean_likelihood[quality$likelihood$body_part == body_part]
  if (length(mean_likelihood) > 0 && mean_likelihood < 0.9) {
    cat("\n  Filtering low confidence points...\n")
    tracking_data <- filter_low_confidence(
      tracking_data,
      threshold = likelihood_threshold
    )
  }
}

# Optional: Interpolate missing data
if (exists("missing_pct") && missing_pct > 0) {
  cat("  Interpolating missing data...\n")
  tracking_data <- interpolate_missing(
    tracking_data,
    method = "linear",
    max_gap = 10
  )
}

# ============================================================================
# STEP 3: CALCULATE METRICS
# ============================================================================

cat("\n=== STEP 3: Calculating Behavioral Metrics ===\n")

# Zone occupancy
cat("  Calculating zone occupancy...\n")
occupancy <- calculate_zone_occupancy(
  tracking_data,
  arena,
  body_part = body_part
)

print(occupancy)

# Zone entries
cat("\n  Calculating zone entries...\n")
entries <- calculate_zone_entries(
  tracking_data,
  arena,
  body_part = body_part
)

cat(sprintf("    Total entries to open arms: %d\n",
            sum(entries$n_entries[entries$zone_id %in% c("open_left", "open_right")])))

# Zone latency
cat("\n  Calculating zone latencies...\n")
latency <- calculate_zone_latency(
  tracking_data,
  arena,
  body_part = body_part,
  min_duration = 0.5  # Filter out brief tracking glitches (<0.5 sec)
)

print(latency)

# Zone transitions
cat("  Calculating zone transitions...\n")
transitions <- calculate_zone_transitions(
  tracking_data,
  arena,
  body_part = body_part
)

# Movement metrics
cat("  Calculating movement metrics...\n")
distance <- calculate_distance_traveled(
  tracking_data,
  body_part = body_part
)

cat(sprintf("    Total distance traveled: %.2f pixels (%.2f cm)\n",
            distance,
            distance * 0.1))  # Assuming 0.1 cm/pixel

# ============================================================================
# STEP 4: GENERATE REPORT
# ============================================================================

cat("\n=== STEP 4: Generating Report ===\n")

# Generate comprehensive HTML report with plots
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

cat("\n" , rep("=", 70), "\n", sep = "")
cat("ANALYSIS COMPLETE!\n")
cat(rep("=", 70), "\n\n", sep = "")

cat("Subject ID:", subject_id, "\n")
cat("Paradigm:", toupper(paradigm), "\n")
cat("Duration:", sprintf("%.2f seconds", nrow(tracking_data$tracking) / fps), "\n\n")

cat("Key Findings:\n")
cat(sprintf("  - Time in open arms: %.2f%% (%.2f sec)\n",
            sum(occupancy$percentage[occupancy$zone_id %in% c("open_left", "open_right")]),
            sum(occupancy$time_in_zone[occupancy$zone_id %in% c("open_left", "open_right")])))
cat(sprintf("  - Time in closed arms: %.2f%% (%.2f sec)\n",
            sum(occupancy$percentage[occupancy$zone_id %in% c("closed_top", "closed_bottom")]),
            sum(occupancy$time_in_zone[occupancy$zone_id %in% c("closed_top", "closed_bottom")])))
cat(sprintf("  - Total distance: %.2f pixels\n", distance))

cat("\nGenerated Files:\n")
cat(sprintf("  Report: %s\n", file.path(output_dir, sprintf("%s_report.html", subject_id))))
cat(sprintf("  Metrics: %s\n", file.path(output_dir, sprintf("%s_metrics.csv", subject_id))))
cat(sprintf("  Plots: %s/plots/\n", output_dir))

cat("\nOpen the HTML report in your browser:\n")
cat(sprintf("  file://%s/%s_report.html\n",
            normalizePath(output_dir),
            subject_id))

cat("\n", rep("=", 70), "\n", sep = "")
