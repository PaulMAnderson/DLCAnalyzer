#!/usr/bin/env Rscript
#' Test LD Pipeline
#'
#' Quick test script to verify the LD pipeline implementation.

# Set working directory to package root
setwd("/mnt/g/Bella/Rebecca/Code/DLCAnalyzer")

# Load all required functions
cat("Loading LD pipeline functions...\n")
source("R/common/io.R")
source("R/common/geometry.R")
source("R/common/plotting.R")
source("R/ld/ld_load.R")
source("R/ld/ld_analysis.R")
source("R/ld/ld_report.R")

# Test data path
test_file <- "data/LD/LD 20251001/Raw data-LD Rebecca 20251001-Trial     1 (2).xlsx"

if (!file.exists(test_file)) {
  stop("Test file not found: ", test_file)
}

cat("\n========================================\n")
cat("LD Pipeline Test\n")
cat("========================================\n\n")

# Step 1: Load data
cat("Step 1: Loading LD data...\n")
ld_data <- load_ld_data(test_file, fps = 25)
cat("  Loaded ", length(ld_data), " arenas\n")

# Step 2: Validate data
cat("\nStep 2: Validating data structure...\n")
is_valid <- validate_ld_data(ld_data)
if (is_valid) {
  cat("  ✓ Data validation passed\n")
} else {
  cat("  ✗ Data validation failed\n")
}

# Step 3: Summarize data
cat("\nStep 3: Data summary:\n")
summary <- summarize_ld_data(ld_data)
print(summary)

# Step 4: Analyze single arena
cat("\nStep 4: Analyzing Arena 1...\n")
arena1 <- ld_data[[1]]
results <- analyze_ld(arena1$data, fps = 25)

cat("\n  Metrics for Arena 1:\n")
cat(sprintf("    Duration: %.1f seconds\n", results$total_duration_sec))
cat(sprintf("    Time in light: %.1f sec (%.1f%%)\n",
            results$time_in_light_sec, results$pct_time_in_light))
cat(sprintf("    Time in dark: %.1f sec (%.1f%%)\n",
            results$time_in_dark_sec, results$pct_time_in_dark))
cat(sprintf("    Entries to light: %d\n", results$entries_to_light))
cat(sprintf("    Latency to light: %.2f sec\n", results$latency_to_light_sec))
cat(sprintf("    Total distance: %.1f cm\n", results$total_distance_cm))
cat(sprintf("    Distance in light: %.1f cm\n", results$distance_in_light_cm))
cat(sprintf("    Distance in dark: %.1f cm\n", results$distance_in_dark_cm))

# Step 5: Batch analysis
cat("\nStep 5: Batch analysis of all arenas...\n")
batch_results <- analyze_ld_batch(ld_data, fps = 25)
cat("\n  All Arenas Results:\n")
print(batch_results[, c("arena_name", "pct_time_in_light", "entries_to_light",
                        "total_distance_cm")])

# Step 6: Export results
cat("\nStep 6: Exporting results to CSV...\n")
output_file <- "test_output/ld_test_results.csv"
export_ld_results(batch_results, output_file, overwrite = TRUE)
cat("  Results saved to:", output_file, "\n")

# Step 7: Generate plots (if ggplot2 available)
if (requireNamespace("ggplot2", quietly = TRUE)) {
  cat("\nStep 7: Generating plots...\n")

  output_dir <- "test_output/ld_test_report"
  report_files <- generate_ld_report(arena1, output_dir = output_dir,
                                     subject_id = "Arena_1_Test", fps = 25)

  cat("  Report generated in:", output_dir, "\n")
  cat("  Files created:\n")
  for (file_type in names(report_files)) {
    cat("    -", file_type, ":", basename(report_files[[file_type]]), "\n")
  }
} else {
  cat("\nStep 7: Skipping plots (ggplot2 not installed)\n")
}

cat("\n========================================\n")
cat("LD Pipeline Test Complete!\n")
cat("========================================\n\n")

# Return success
cat("✓ All steps completed successfully\n\n")
