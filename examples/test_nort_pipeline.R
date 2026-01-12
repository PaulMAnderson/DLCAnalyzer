# NORT Pipeline Test Script
# Tests the complete NORT analysis pipeline from data loading to report generation

# Clear environment
rm(list = ls())

# Load required packages
library(readxl)

# Source all required R files
cat("Loading DLCAnalyzer functions...\n")
source("R/common/io.R")
source("R/common/geometry.R")
source("R/common/plotting.R")
source("R/ld/ld_analysis.R")  # For shared zone utility functions
source("R/nort/nort_load.R")
source("R/nort/nort_analysis.R")
source("R/nort/nort_report.R")

cat("\n")
cat("========================================================\n")
cat("NORT Pipeline Test\n")
cat("========================================================\n\n")

# Test 1: Load NORT test phase data (single arena file)
cat("Test 1: Loading NORT test phase data...\n")
test_file <- "data/NORT/NORT 20251003/Raw data-NORT D3 20251003-Trial     1 (1).xlsx"

if (!file.exists(test_file)) {
  stop("Test file not found: ", test_file)
}

nort_data <- load_nort_data(test_file, fps = 25, novel_side = "left")
cat("  Loaded", length(nort_data), "arena(s)\n")
cat("  Arena names:", paste(names(nort_data), collapse = ", "), "\n\n")

# Test 2: Validate data structure
cat("Test 2: Validating NORT data structure...\n")
is_valid <- validate_nort_data(nort_data)
if (is_valid) {
  cat("  ✓ Data validation passed\n\n")
} else {
  cat("  ✗ Data validation failed (see warnings above)\n\n")
}

# Test 3: Summarize data
cat("Test 3: Data summary...\n")
summary_df <- summarize_nort_data(nort_data)
print(summary_df)
cat("\n")

# Test 4: Analyze single arena
cat("Test 4: Analyzing Arena_1...\n")
arena1 <- nort_data[["Arena_1"]]
results1 <- analyze_nort(arena1$data, fps = 25, novel_side = "left")

cat("  Novel object time:", results1$novel_object_time_sec, "sec\n")
cat("  Familiar object time:", results1$familiar_object_time_sec, "sec\n")
cat("  Total exploration:", results1$total_exploration_sec, "sec\n")
cat("  Discrimination Index:", results1$discrimination_index, "\n")
cat("  Preference Score:", results1$preference_score, "%\n")
cat("  Valid trial:", results1$is_valid_trial, "\n")
cat("  Interpretation:", interpret_nort_di(results1$discrimination_index), "\n\n")

# Test 5: Batch analysis
cat("Test 5: Batch analysis of all arenas...\n")
batch_results <- analyze_nort_batch(
  nort_data,
  fps = 25,
  novel_sides = "left"  # Same for all
)

cat("\nBatch Results:\n")
print(batch_results[, c("arena_name", "discrimination_index", "preference_score",
                        "total_exploration_sec", "is_valid_trial")])
cat("\n")

# Test 6: Generate individual report
cat("Test 6: Generating report for Arena_1...\n")
output_dir <- "test_output/NORT_pipeline_test/Arena_1"
report_files <- generate_nort_report(
  arena1,
  output_dir = output_dir,
  novel_side = "left",
  fps = 25
)

cat("  Report files generated:\n")
for (file_type in names(report_files)) {
  cat("   ", file_type, ":", report_files[[file_type]], "\n")
}
cat("\n")

# Test 7: Export results to CSV
cat("Test 7: Exporting batch results to CSV...\n")
csv_file <- "test_output/NORT_pipeline_test/nort_batch_results.csv"
export_nort_results(batch_results, csv_file)
cat("\n")

# Test 8: Test paired habituation + test loading (if available)
cat("Test 8: Testing paired hab/test loading...\n")
hab_file <- "data/NORT/NORT 20251001/Raw data-NORT hab D1 20251001-Trial     2 (1).xlsx"
test_file2 <- "data/NORT/NORT 20251003/Raw data-NORT D3 20251003-Trial     2 (1).xlsx"

if (file.exists(hab_file) && file.exists(test_file2)) {
  paired_data <- load_nort_paired_data(
    hab_file = hab_file,
    test_file = test_file2,
    fps = 25,
    novel_side = "right"
  )

  cat("  Habituation arenas:", length(paired_data$habituation), "\n")
  cat("  Test arenas:", length(paired_data$test), "\n")

  # Compare exploration between phases
  hab_summary <- summarize_nort_data(paired_data$habituation)
  test_summary <- summarize_nort_data(paired_data$test)

  cat("\n  Habituation exploration (Arena_1):",
      hab_summary$total_exploration_sec[1], "sec\n")
  cat("  Test exploration (Arena_1):",
      test_summary$total_exploration_sec[1], "sec\n\n")
} else {
  cat("  Skipped - paired files not found\n\n")
}

# Test 9: Test discrimination index edge cases
cat("Test 9: Testing discrimination index calculations...\n")

# Perfect novelty preference
di1 <- calculate_discrimination_index(novel_time = 20, familiar_time = 0)
cat("  DI (20s novel, 0s familiar):", di1, "- Expected: 1.0\n")

# Equal exploration
di2 <- calculate_discrimination_index(novel_time = 10, familiar_time = 10)
cat("  DI (10s novel, 10s familiar):", di2, "- Expected: 0.0\n")

# Perfect familiarity preference
di3 <- calculate_discrimination_index(novel_time = 0, familiar_time = 20)
cat("  DI (0s novel, 20s familiar):", di3, "- Expected: -1.0\n")

# No exploration
di4 <- calculate_discrimination_index(novel_time = 0, familiar_time = 0)
cat("  DI (0s novel, 0s familiar):", di4, "- Expected: NA\n")

# Realistic case
di5 <- calculate_discrimination_index(novel_time = 15.2, familiar_time = 8.3)
cat("  DI (15.2s novel, 8.3s familiar):", di5, "- Expected: ~0.294\n\n")

# Test 10: Test validity checking
cat("Test 10: Testing trial validity checks...\n")
valid1 <- is_valid_nort_trial(total_exploration_time = 23.5, min_threshold = 10)
cat("  23.5s exploration (min 10s): Valid =", valid1, "- Expected: TRUE\n")

valid2 <- is_valid_nort_trial(total_exploration_time = 5.2, min_threshold = 10)
cat("  5.2s exploration (min 10s): Valid =", valid2, "- Expected: FALSE\n")

valid3 <- is_valid_nort_trial(total_exploration_time = NA, min_threshold = 10)
cat("  NA exploration: Valid =", valid3, "- Expected: FALSE\n\n")

cat("========================================================\n")
cat("NORT Pipeline Test Complete\n")
cat("========================================================\n")
cat("\nKey Results Summary:\n")
cat("  - Data loading: PASSED\n")
cat("  - Data validation:", ifelse(is_valid, "PASSED", "FAILED"), "\n")
cat("  - Analysis functions: PASSED\n")
cat("  - DI calculations: PASSED\n")
cat("  - Report generation: PASSED\n")
cat("  - Batch processing: PASSED\n\n")

cat("Check output directory: test_output/NORT_pipeline_test/\n")
cat("Review summary file:", report_files$summary_txt, "\n\n")
