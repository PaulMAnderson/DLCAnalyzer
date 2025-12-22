#!/usr/bin/env Rscript
# Example: Single Subject NORT Analysis
#
# Novel Object Recognition Test (NORT) analysis from Ethovision Excel exports.
# Calculates exploration time, discrimination index, and object preference.

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
excel_file <- "data/NORT/Example Exported Data/Raw data-NORT D3 20251003-Trial     1 (1).xlsx"
paradigm <- "nort"
fps <- 30

# Arena configuration
arena_config_file <- "config/arena_definitions/NORT/nort_standard.yaml"
output_dir <- "reports/nort/trial1"

body_part <- "mouse_center"

# ============================================================================
# STEP 1: LOAD DATA
# ============================================================================

cat("\n=== STEP 1: Loading NORT Data ===\n")

cat(sprintf("Loading Excel file: %s\n", basename(excel_file)))

tracking_data <- convert_ethovision_to_tracking_data(
  excel_file,
  fps = fps,
  paradigm = paradigm
)

subject_id <- gsub("Raw data-|.xlsx|\\(1\\)", "", basename(excel_file))
subject_id <- gsub("-Trial.*", "", subject_id)
tracking_data$metadata$subject_id <- subject_id

cat(sprintf("  Subject: %s\n", subject_id))
cat(sprintf("  Duration: %.2f seconds\n", nrow(tracking_data$tracking) / fps))

# Load or create arena configuration
cat(sprintf("\nLoading arena config: %s\n", basename(arena_config_file)))

if (!file.exists(arena_config_file)) {
  cat("  WARNING: Arena config not found. Creating default NORT arena...\n")

  # Create default NORT arena with novel and familiar object zones
  arena <- new_arena_config(
    arena_id = "nort_default",
    dimensions = list(width = 640, height = 480),
    zones = list(
      novel_object = list(
        type = "circle",
        center_x = 200,
        center_y = 240,
        radius = 50
      ),
      familiar_object = list(
        type = "circle",
        center_x = 440,
        center_y = 240,
        radius = 50
      ),
      center = list(
        type = "circle",
        center_x = 320,
        center_y = 240,
        radius = 80
      )
    )
  )
} else {
  arena <- load_arena_configs(arena_config_file, arena_id = "arena1")
}

cat(sprintf("  Zones: %s\n", paste(names(arena$zones), collapse = ", ")))

# ============================================================================
# STEP 2: QUALITY ASSESSMENT
# ============================================================================

cat("\n=== STEP 2: Quality Assessment ===\n")

quality <- check_tracking_quality(tracking_data, body_part = body_part)
cat(sprintf("  Quality score: %.2f%%\n", quality$overall_quality * 100))

if (quality$missing_pct > 0) {
  cat("  Interpolating missing data...\n")
  tracking_data <- interpolate_missing(tracking_data, method = "linear")
}

# ============================================================================
# STEP 3: CALCULATE NORT-SPECIFIC METRICS
# ============================================================================

cat("\n=== STEP 3: Calculating NORT Metrics ===\n")

# Zone occupancy
cat("  Calculating exploration time...\n")
occupancy <- calculate_zone_occupancy(tracking_data, arena, body_part = body_part)

# Extract times for each object
novel_time <- occupancy$time_in_zone[occupancy$zone_id == "novel_object"]
familiar_time <- occupancy$time_in_zone[occupancy$zone_id == "familiar_object"]

if (length(novel_time) == 0) novel_time <- 0
if (length(familiar_time) == 0) familiar_time <- 0

# Calculate discrimination index
# DI = (Novel - Familiar) / (Novel + Familiar)
total_exploration <- novel_time + familiar_time
discrimination_index <- if (total_exploration > 0) {
  (novel_time - familiar_time) / total_exploration
} else {
  0
}

# Calculate preference ratio
# PR = Novel / (Novel + Familiar)
preference_ratio <- if (total_exploration > 0) {
  novel_time / total_exploration
} else {
  0
}

# Zone entries
entries <- calculate_zone_entries(tracking_data, arena, body_part = body_part)

novel_entries <- entries$entry_count[entries$zone_id == "novel_object"]
familiar_entries <- entries$entry_count[entries$zone_id == "familiar_object"]

if (length(novel_entries) == 0) novel_entries <- 0
if (length(familiar_entries) == 0) familiar_entries <- 0

# Latency to objects
latency <- calculate_zone_latency(tracking_data, arena, body_part = body_part)

# Movement metrics
distance <- calculate_distance_traveled(tracking_data, body_part = body_part)

# ============================================================================
# RESULTS DISPLAY
# ============================================================================

cat("\n", rep("=", 70), "\n", sep = "")
cat("NORT ANALYSIS RESULTS\n")
cat(rep("=", 70), "\n\n", sep = "")

cat("Subject:", subject_id, "\n")
cat("Duration:", sprintf("%.2f seconds", nrow(tracking_data$tracking) / fps), "\n\n")

cat("Object Exploration:\n")
cat(sprintf("  Novel object time:    %.2f sec (%.1f%%)\n",
            novel_time,
            (novel_time / total_exploration) * 100))
cat(sprintf("  Familiar object time: %.2f sec (%.1f%%)\n",
            familiar_time,
            (familiar_time / total_exploration) * 100))
cat(sprintf("  Total exploration:    %.2f sec\n", total_exploration))

cat("\nNORT Indices:\n")
cat(sprintf("  Discrimination Index: %.3f\n", discrimination_index))
cat(sprintf("  Preference Ratio:     %.3f\n", preference_ratio))

# Interpretation
cat("\nInterpretation:\n")
if (discrimination_index > 0.1) {
  cat("  ✓ Preference for novel object (DI > 0.1)\n")
} else if (discrimination_index < -0.1) {
  cat("  ✗ Preference for familiar object (DI < -0.1)\n")
} else {
  cat("  = No clear preference (DI ≈ 0)\n")
}

cat("\nObject Approaches:\n")
cat(sprintf("  Novel object entries:    %d\n", novel_entries))
cat(sprintf("  Familiar object entries: %d\n", familiar_entries))

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

# Save NORT-specific metrics
nort_metrics <- data.frame(
  subject_id = subject_id,
  novel_time_sec = novel_time,
  familiar_time_sec = familiar_time,
  total_exploration_sec = total_exploration,
  discrimination_index = discrimination_index,
  preference_ratio = preference_ratio,
  novel_entries = novel_entries,
  familiar_entries = familiar_entries,
  total_distance = distance$total_distance
)

metrics_file <- file.path(output_dir, sprintf("%s_nort_metrics.csv", subject_id))
write.csv(nort_metrics, metrics_file, row.names = FALSE)

cat("\nNORT-specific metrics saved to:", metrics_file, "\n")
cat("Full report:", file.path(output_dir, sprintf("%s_report.html", subject_id)), "\n")

cat("\n", rep("=", 70), "\n", sep = "")
