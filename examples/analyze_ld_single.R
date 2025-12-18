#!/usr/bin/env Rscript
# Example: Single Subject Light/Dark Box Analysis
#
# Light/Dark (LD) box test analysis from Ethovision Excel exports.
# Calculates time in light vs dark compartments, transitions, and anxiety-related metrics.

# ============================================================================
# SETUP
# ============================================================================

setwd("/mnt/g/Bella/Rebecca/Code/DLCAnalyzer")
source("tests/testthat/setup.R")

if (!requireNamespace("readxl", quietly = TRUE)) {
  stop("Package 'readxl' is required. Install with: install.packages('readxl')")
}

# ============================================================================
# CONFIGURATION
# ============================================================================

# Subject information
excel_file <- "data/LD/Example Exported Data/Raw data-LD Rebecca 20251022-Trial     1.xlsx"
paradigm <- "light_dark"
fps <- 30

# Arena configuration
arena_config_file <- "config/arena_definitions/LD/ld_standard.yaml"
output_dir <- "reports/ld/trial1"

body_part <- "mouse_center"

# ============================================================================
# STEP 1: LOAD DATA
# ============================================================================

cat("\n=== STEP 1: Loading Light/Dark Box Data ===\n")

cat(sprintf("Loading Excel file: %s\n", basename(excel_file)))

tracking_data <- convert_ethovision_to_tracking_data(
  excel_file,
  fps = fps,
  paradigm = paradigm
)

subject_id <- gsub("Raw data-|.xlsx", "", basename(excel_file))
subject_id <- gsub("-Trial.*", "", subject_id)
tracking_data$metadata$subject_id <- subject_id

cat(sprintf("  Subject: %s\n", subject_id))
cat(sprintf("  Duration: %.2f seconds\n", nrow(tracking_data$tracking) / fps))

# Load or create arena configuration
cat(sprintf("\nLoading arena config: %s\n", basename(arena_config_file)))

if (!file.exists(arena_config_file)) {
  cat("  WARNING: Arena config not found. Creating default LD arena...\n")

  # Create default LD arena (light and dark compartments)
  arena <- new_arena_config(
    arena_id = "ld_default",
    dimensions = list(width = 640, height = 480),
    zones = list(
      light = list(
        type = "rectangle",
        x_min = 0,
        y_min = 0,
        x_max = 320,
        y_max = 480
      ),
      dark = list(
        type = "rectangle",
        x_min = 320,
        y_min = 0,
        x_max = 640,
        y_max = 480
      ),
      transition = list(
        type = "rectangle",
        x_min = 300,
        y_min = 0,
        x_max = 340,
        y_max = 480
      )
    )
  )
} else {
  arena <- load_arena_configs(arena_config_file, arena_id = "ld_standard")
}

cat(sprintf("  Zones: %s\n", paste(names(arena$zones), collapse = ", ")))

# ============================================================================
# STEP 2: QUALITY ASSESSMENT
# ============================================================================

cat("\n=== STEP 2: Quality Assessment ===\n")

quality <- assess_tracking_quality(tracking_data, body_part = body_part)
cat(sprintf("  Quality score: %.2f%%\n", quality$overall_quality * 100))

if (quality$missing_pct > 0) {
  cat("  Interpolating missing data...\n")
  tracking_data <- interpolate_missing(tracking_data, method = "linear")
}

# ============================================================================
# STEP 3: CALCULATE LD-SPECIFIC METRICS
# ============================================================================

cat("\n=== STEP 3: Calculating Light/Dark Box Metrics ===\n")

# Zone occupancy
cat("  Calculating time in compartments...\n")
occupancy <- calculate_zone_occupancy(tracking_data, arena, body_part = body_part)

light_time <- occupancy$time_in_zone[occupancy$zone_id == "light"]
dark_time <- occupancy$time_in_zone[occupancy$zone_id == "dark"]

if (length(light_time) == 0) light_time <- 0
if (length(dark_time) == 0) dark_time <- 0

light_pct <- occupancy$percentage[occupancy$zone_id == "light"]
dark_pct <- occupancy$percentage[occupancy$zone_id == "dark"]

if (length(light_pct) == 0) light_pct <- 0
if (length(dark_pct) == 0) dark_pct <- 0

# Zone entries and transitions
cat("  Calculating transitions...\n")
entries <- calculate_zone_entries(tracking_data, arena, body_part = body_part)
transitions <- calculate_zone_transitions(tracking_data, arena, body_part = body_part)

light_entries <- entries$entry_count[entries$zone_id == "light"]
dark_entries <- entries$entry_count[entries$zone_id == "dark"]

if (length(light_entries) == 0) light_entries <- 0
if (length(dark_entries) == 0) dark_entries <- 0

# Latency to light compartment
latency <- calculate_zone_latency(tracking_data, arena, body_part = body_part)
light_latency <- latency$first_entry_time[latency$zone_id == "light"]

if (length(light_latency) == 0) light_latency <- NA

# Movement metrics
distance <- calculate_distance_traveled(tracking_data, body_part = body_part)

# Calculate average duration per light visit
avg_light_duration <- if (light_entries > 0) {
  light_time / light_entries
} else {
  0
}

# ============================================================================
# RESULTS DISPLAY
# ============================================================================

cat("\n", rep("=", 70), "\n", sep = "")
cat("LIGHT/DARK BOX ANALYSIS RESULTS\n")
cat(rep("=", 70), "\n\n", sep = "")

cat("Subject:", subject_id, "\n")
cat("Duration:", sprintf("%.2f seconds", nrow(tracking_data$tracking) / fps), "\n\n")

cat("Compartment Occupancy:\n")
cat(sprintf("  Light compartment: %.2f sec (%.2f%%)\n", light_time, light_pct))
cat(sprintf("  Dark compartment:  %.2f sec (%.2f%%)\n", dark_time, dark_pct))

cat("\nAnxiety-Related Metrics:\n")
cat(sprintf("  Latency to light: %.2f sec\n", light_latency))
cat(sprintf("  Light entries:    %d\n", light_entries))
cat(sprintf("  Dark entries:     %d\n", dark_entries))
cat(sprintf("  Total transitions: %d\n", light_entries + dark_entries))
cat(sprintf("  Avg light visit:  %.2f sec\n", avg_light_duration))

# Interpretation
cat("\nInterpretation:\n")
if (light_pct > 50) {
  cat("  ✓ Exploratory behavior (>50% in light)\n")
} else if (light_pct < 20) {
  cat("  ⚠ Anxiety-like behavior (<20% in light)\n")
} else {
  cat("  = Normal behavior (20-50% in light)\n")
}

if (light_entries < 3) {
  cat("  ⚠ Low exploratory activity (<3 light entries)\n")
} else {
  cat("  ✓ Normal exploratory activity\n")
}

cat("\nLocomotor Activity:\n")
cat(sprintf("  Total distance: %.2f pixels\n", distance$total_distance))

# ============================================================================
# STEP 4: GENERATE REPORT
# ============================================================================

cat("\n=== Generating Report ===\n")

report <- generate_subject_report(
  tracking_data,
  arena,
  output_dir = output_dir,
  body_part = body_part,
  format = "html"
)

# Save LD-specific metrics
ld_metrics <- data.frame(
  subject_id = subject_id,
  light_time_sec = light_time,
  light_percent = light_pct,
  dark_time_sec = dark_time,
  dark_percent = dark_pct,
  latency_to_light_sec = light_latency,
  light_entries = light_entries,
  dark_entries = dark_entries,
  total_transitions = light_entries + dark_entries,
  avg_light_visit_sec = avg_light_duration,
  total_distance = distance$total_distance
)

metrics_file <- file.path(output_dir, sprintf("%s_ld_metrics.csv", subject_id))
write.csv(ld_metrics, metrics_file, row.names = FALSE)

cat("\nLD-specific metrics saved to:", metrics_file, "\n")
cat("Full report:", file.path(output_dir, sprintf("%s_report.html", subject_id)), "\n")

cat("\n", rep("=", 70), "\n", sep = "")
