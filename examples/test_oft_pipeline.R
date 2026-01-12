#!/usr/bin/env Rscript
#' Test OFT Pipeline
#'
#' Quick test script to verify the OFT pipeline implementation.

# Set working directory to package root
setwd("/mnt/g/Bella/Rebecca/Code/DLCAnalyzer")

# Load all required functions
cat("Loading OFT pipeline functions...\n")
source("R/common/io.R")
source("R/common/geometry.R")
source("R/common/plotting.R")
source("R/ld/ld_analysis.R")  # For shared zone calculation functions
source("R/oft/oft_load.R")
source("R/oft/oft_analysis.R")
source("R/oft/oft_report.R")

# Test data path
test_file <- "data/OFT/OF 20250929/Raw data-OF RebeccaAndersonWagner-Trial     1 (3).xlsx"

if (!file.exists(test_file)) {
  stop("Test file not found: ", test_file)
}

cat("\n========================================\n")
cat("OFT Pipeline Test\n")
cat("========================================\n\n")

# Step 1: Load data
cat("Step 1: Loading OFT data...\n")
oft_data <- load_oft_data(test_file, fps = 25)
cat("  Loaded ", length(oft_data), " arenas\n")

# Step 2: Validate data
cat("\nStep 2: Validating data structure...\n")
is_valid <- validate_oft_data(oft_data)
if (is_valid) {
  cat("  ✓ Data validation passed\n")
} else {
  cat("  ✗ Data validation failed\n")
}

# Step 3: Summarize data
cat("\nStep 3: Data summary:\n")
summary <- summarize_oft_data(oft_data)
print(summary)

# Step 4: Analyze single arena
cat("\nStep 4: Analyzing Arena 1...\n")
arena1 <- oft_data[[1]]
results <- analyze_oft(arena1$data, fps = 25)

cat("\n  Metrics for Arena 1:\n")
cat(sprintf("    Duration: %.1f seconds\n", results$total_duration_sec))
cat(sprintf("    Time in center: %.1f sec (%.1f%%)\n",
            results$time_in_center_sec, results$pct_time_in_center))
cat(sprintf("    Time in periphery: %.1f sec (%.1f%%)\n",
            results$time_in_periphery_sec, results$pct_time_in_periphery))
cat(sprintf("    Entries to center: %d\n", results$entries_to_center))
cat(sprintf("    Latency to center: %.2f sec\n", results$latency_to_center_sec))
cat(sprintf("    Total distance: %.1f cm\n", results$total_distance_cm))
cat(sprintf("    Average velocity: %.1f cm/s\n", results$avg_velocity_cm_s))
cat(sprintf("    Distance in center: %.1f cm\n", results$distance_in_center_cm))
cat(sprintf("    Distance in periphery: %.1f cm\n", results$distance_in_periphery_cm))
if (!is.na(results$thigmotaxis_index)) {
  cat(sprintf("    Thigmotaxis index: %.3f\n", results$thigmotaxis_index))
}

# Step 5: Batch analysis
cat("\nStep 5: Batch analysis of all arenas...\n")
batch_results <- analyze_oft_batch(oft_data, fps = 25)
cat("\n  All Arenas Results:\n")
print(batch_results[, c("arena_name", "pct_time_in_center", "entries_to_center",
                        "total_distance_cm", "avg_velocity_cm_s")])

# Step 6: Export results
cat("\nStep 6: Exporting results to CSV...\n")
output_file <- "test_output/oft_test_results.csv"
export_oft_results(batch_results, output_file)
cat("  Results saved to:", output_file, "\n")

# Step 7: Generate plots (if ggplot2 available)
if (requireNamespace("ggplot2", quietly = TRUE)) {
  cat("\nStep 7: Generating plots...\n")

  output_dir <- "test_output/oft_test_report"
  report_files <- generate_oft_report(arena1, output_dir = output_dir,
                                     subject_id = "Arena_1_Test", fps = 25)

  cat("  Report generated in:", output_dir, "\n")
  cat("  Files created:\n")
  for (file_type in names(report_files)) {
    cat("    -", file_type, ":", basename(report_files[[file_type]]), "\n")
  }
} else {
  cat("\nStep 7: Skipping plots (ggplot2 not installed)\n")
}

# Step 8: Generate batch reports (optional - commented out for speed)
# Uncomment to test full batch report generation
# cat("\nStep 8: Generating batch reports...\n")
# batch_output_dir <- "test_output/oft_batch_reports"
# batch_results_full <- generate_oft_batch_report(oft_data, output_dir = batch_output_dir, fps = 25)
# cat("  Batch reports saved to:", batch_output_dir, "\n")

cat("\n========================================\n")
cat("OFT Pipeline Test Complete!\n")
cat("========================================\n\n")

# Return success
cat("✓ All steps completed successfully\n\n")
