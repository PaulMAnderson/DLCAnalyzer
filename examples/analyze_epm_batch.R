#!/usr/bin/env Rscript
# Example: Batch EPM Analysis
#
# This script processes multiple EPM subjects and generates individual reports
# for each, plus a summary comparison table.

# ============================================================================
# SETUP
# ============================================================================

setwd("/mnt/g/Bella/Rebecca/Code/DLCAnalyzer")
source("tests/testthat/setup.R")

# ============================================================================
# CONFIGURATION
# ============================================================================

# Data directory
data_dir <- "data/EPM/Example DLC Data"
arena_config <- "config/arena_definitions/EPM/EPM.yaml"
output_base_dir <- "reports/epm_batch"

# Analysis parameters
fps <- 30
body_part <- "mouse_center"
paradigm <- "epm"

# ============================================================================
# FIND ALL EPM DATA FILES
# ============================================================================

cat("=== Batch EPM Analysis ===\n\n")

# Find all CSV files
dlc_files <- list.files(
  data_dir,
  pattern = "\\.csv$",
  full.names = TRUE
)

cat(sprintf("Found %d EPM data files:\n", length(dlc_files)))
for (i in seq_along(dlc_files)) {
  cat(sprintf("  %d. %s\n", i, basename(dlc_files[i])))
}

# Load arena configuration once
cat("\nLoading arena configuration...\n")
arena <- load_arena_configs(arena_config, arena_id = "arena1")

# ============================================================================
# PROCESS EACH SUBJECT
# ============================================================================

cat("\n=== Processing Subjects ===\n\n")

# Storage for results
all_metrics <- list()
all_reports <- list()

for (i in seq_along(dlc_files)) {
  file <- dlc_files[i]

  # Extract subject ID from filename
  subject_id <- gsub("_superanimal.*", "", basename(file))

  cat(sprintf("[%d/%d] Processing %s...\n", i, length(dlc_files), subject_id))

  tryCatch({
    # Load data
    tracking_data <- convert_dlc_to_tracking_data(
      file,
      fps = fps,
      subject_id = subject_id,
      paradigm = paradigm
    )

    # Quality check
    quality <- check_tracking_quality(tracking_data, body_part = body_part)
    cat(sprintf("  Quality: %.1f%%\n", quality$overall_quality * 100))

    # Calculate metrics
    occupancy <- calculate_zone_occupancy(tracking_data, arena, body_part = body_part)
    entries <- calculate_zone_entries(tracking_data, arena, body_part = body_part)
    latency <- calculate_zone_latency(tracking_data, arena, body_part = body_part)
    distance <- calculate_distance_traveled(tracking_data, body_part = body_part)

    # Store metrics
    all_metrics[[subject_id]] <- list(
      subject_id = subject_id,
      quality_score = quality$overall_quality,
      total_distance = distance$total_distance,
      open_arm_time = sum(occupancy$time_in_zone[occupancy$zone_id %in% c("open_arm_1", "open_arm_2")]),
      open_arm_pct = sum(occupancy$percentage[occupancy$zone_id %in% c("open_arm_1", "open_arm_2")]),
      closed_arm_time = sum(occupancy$time_in_zone[occupancy$zone_id %in% c("closed_arm_1", "closed_arm_2")]),
      closed_arm_pct = sum(occupancy$percentage[occupancy$zone_id %in% c("closed_arm_1", "closed_arm_2")]),
      center_time = occupancy$time_in_zone[occupancy$zone_id == "center"],
      center_pct = occupancy$percentage[occupancy$zone_id == "center"],
      open_arm_entries = sum(entries$entry_count[entries$zone_id %in% c("open_arm_1", "open_arm_2")]),
      occupancy = occupancy,
      entries = entries,
      latency = latency
    )

    # Generate individual report
    output_dir <- file.path(output_base_dir, subject_id)
    report <- generate_subject_report(
      tracking_data,
      arena,
      output_dir = output_dir,
      body_part = body_part,
      format = "html"
    )

    all_reports[[subject_id]] <- report
    cat(sprintf("  Report saved: %s\n", file.path(output_dir, sprintf("%s_report.html", subject_id))))

  }, error = function(e) {
    cat(sprintf("  ERROR: %s\n", e$message))
  })

  cat("\n")
}

# ============================================================================
# CREATE SUMMARY TABLE
# ============================================================================

cat("=== Creating Summary Table ===\n")

# Convert metrics to data frame
summary_df <- data.frame(
  Subject_ID = sapply(all_metrics, function(x) x$subject_id),
  Quality_Score = sapply(all_metrics, function(x) round(x$quality_score * 100, 1)),
  Distance_Traveled = sapply(all_metrics, function(x) round(x$total_distance, 1)),
  Open_Arm_Time_sec = sapply(all_metrics, function(x) round(x$open_arm_time, 2)),
  Open_Arm_Percent = sapply(all_metrics, function(x) round(x$open_arm_pct, 2)),
  Closed_Arm_Time_sec = sapply(all_metrics, function(x) round(x$closed_arm_time, 2)),
  Closed_Arm_Percent = sapply(all_metrics, function(x) round(x$closed_arm_pct, 2)),
  Center_Time_sec = sapply(all_metrics, function(x) round(x$center_time, 2)),
  Center_Percent = sapply(all_metrics, function(x) round(x$center_pct, 2)),
  Open_Arm_Entries = sapply(all_metrics, function(x) x$open_arm_entries),
  stringsAsFactors = FALSE
)

# Save summary table
summary_file <- file.path(output_base_dir, "summary_metrics.csv")
write.csv(summary_df, summary_file, row.names = FALSE)

cat("\nSummary Table:\n")
print(summary_df)

cat(sprintf("\nSummary saved to: %s\n", summary_file))

# ============================================================================
# SUMMARY STATISTICS
# ============================================================================

cat("\n=== Summary Statistics ===\n\n")

cat("Open Arm Time (%):\n")
cat(sprintf("  Mean: %.2f ± %.2f SD\n",
            mean(summary_df$Open_Arm_Percent),
            sd(summary_df$Open_Arm_Percent)))
cat(sprintf("  Range: %.2f - %.2f\n",
            min(summary_df$Open_Arm_Percent),
            max(summary_df$Open_Arm_Percent)))

cat("\nOpen Arm Entries:\n")
cat(sprintf("  Mean: %.2f ± %.2f SD\n",
            mean(summary_df$Open_Arm_Entries),
            sd(summary_df$Open_Arm_Entries)))
cat(sprintf("  Range: %d - %d\n",
            min(summary_df$Open_Arm_Entries),
            max(summary_df$Open_Arm_Entries)))

cat("\nTotal Distance (pixels):\n")
cat(sprintf("  Mean: %.2f ± %.2f SD\n",
            mean(summary_df$Distance_Traveled),
            sd(summary_df$Distance_Traveled)))

# ============================================================================
# COMPLETION MESSAGE
# ============================================================================

cat("\n", rep("=", 70), "\n", sep = "")
cat("BATCH ANALYSIS COMPLETE!\n")
cat(rep("=", 70), "\n\n", sep = "")

cat(sprintf("Processed: %d subjects\n", length(all_metrics)))
cat(sprintf("Output directory: %s\n", output_base_dir))
cat(sprintf("Summary table: %s\n", summary_file))

cat("\nIndividual reports:\n")
for (subject_id in names(all_reports)) {
  cat(sprintf("  %s: %s/%s/%s_report.html\n",
              subject_id, output_base_dir, subject_id, subject_id))
}

cat("\n", rep("=", 70), "\n", sep = "")
