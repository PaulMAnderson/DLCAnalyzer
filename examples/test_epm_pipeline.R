#!/usr/bin/env Rscript
#' EPM Pipeline Example Script
#'
#' Demonstrates the complete EPM (Elevated Plus Maze) analysis pipeline
#' from loading DeepLabCut CSV data to generating reports.
#'
#' This script shows:
#' 1. Loading EPM data from DLC CSV files
#' 2. Analyzing anxiety and locomotor metrics
#' 3. Generating visualization plots and reports
#' 4. Batch processing multiple subjects
#'
#' @example
#' Rscript examples/test_epm_pipeline.R

# Load required packages
library(DLCAnalyzer)  # Or source individual files during development

# Set paths
data_dir <- "data/EPM/Example DLC Data/EPM 20250930"
output_dir <- "output/EPM_test"

cat("\n")
cat("========================================\n")
cat("  EPM Pipeline Demonstration\n")
cat("========================================\n\n")

# ==============================================================================
# Example 1: Single Subject Analysis
# ==============================================================================

cat("Example 1: Single Subject Analysis\n")
cat("-----------------------------------\n\n")

# Find first EPM CSV file
csv_files <- list.files(data_dir, pattern = "\\.csv$", full.names = TRUE)
if (length(csv_files) == 0) {
  stop("No CSV files found in ", data_dir)
}

test_file <- csv_files[1]
cat("Loading file:", basename(test_file), "\n\n")

# Load EPM data
# Note: Adjust pixels_per_cm based on your arena calibration
# Default is 5.3 pixels/cm, but this may vary
epm_data <- load_epm_data(
  file_path = test_file,
  fps = 25,
  pixels_per_cm = 5.3,  # ADJUST THIS based on your setup
  body_part = "mouse_center",
  likelihood_threshold = 0.9
)

# Display summary
cat("\n")
summarize_epm_data(epm_data)

# Analyze behavioral metrics
cat("\n")
cat("Analyzing EPM metrics...\n")
results <- analyze_epm(epm_data)

# Print results
print_epm_results(results, subject_id = epm_data$subject_id)

# Check anxiety assessment
anxiety_level <- interpret_epm_anxiety(
  results$open_arm_ratio,
  results$entries_ratio,
  results$total_arm_entries
)
cat("\nAnxiety Assessment:", anxiety_level, "\n")

# Generate report with plots
cat("\nGenerating report...\n")
subject_output_dir <- file.path(output_dir, "single_subject", epm_data$subject_id)
report_files <- generate_epm_report(
  epm_data,
  output_dir = subject_output_dir,
  subject_id = epm_data$subject_id
)

cat("\nReport files generated:\n")
for (file_type in names(report_files)) {
  cat(sprintf("  %s: %s\n", file_type, report_files[[file_type]]))
}


# ==============================================================================
# Example 2: Batch Processing Multiple Subjects
# ==============================================================================

cat("\n\n")
cat("Example 2: Batch Processing\n")
cat("----------------------------\n\n")

# Load multiple subjects (limit to first 3 for demo)
n_subjects <- min(3, length(csv_files))
cat(sprintf("Loading %d subjects...\n", n_subjects))

epm_data_list <- list()
for (i in 1:n_subjects) {
  cat(sprintf("  Loading subject %d/%d: %s\n", i, n_subjects, basename(csv_files[i])))

  tryCatch({
    epm_data_list[[i]] <- load_epm_data(
      file_path = csv_files[i],
      fps = 25,
      pixels_per_cm = 5.3,
      body_part = "mouse_center",
      likelihood_threshold = 0.9
    )
  }, error = function(e) {
    cat(sprintf("    ERROR: %s\n", e$message))
  })
}

# Remove any failed loads
epm_data_list <- epm_data_list[!sapply(epm_data_list, is.null)]

if (length(epm_data_list) == 0) {
  cat("No subjects loaded successfully. Skipping batch analysis.\n")
} else {
  cat(sprintf("\nSuccessfully loaded %d subjects\n\n", length(epm_data_list)))

  # Analyze batch
  cat("Analyzing batch data...\n")
  batch_results <- analyze_epm_batch(epm_data_list, min_exploration = 5)

  # Display batch results
  cat("\nBatch Results Summary:\n")
  print(batch_results[, c("subject_id", "open_arm_ratio", "entries_ratio",
                          "total_arm_entries", "total_distance_cm")])

  # Calculate group statistics
  cat("\n\nGroup Statistics:\n")
  cat(sprintf("  Mean Open Arm Ratio: %.3f ± %.3f (SD)\n",
              mean(batch_results$open_arm_ratio, na.rm = TRUE),
              sd(batch_results$open_arm_ratio, na.rm = TRUE)))
  cat(sprintf("  Mean Entries Ratio:  %.3f ± %.3f (SD)\n",
              mean(batch_results$entries_ratio, na.rm = TRUE),
              sd(batch_results$entries_ratio, na.rm = TRUE)))
  cat(sprintf("  Mean Total Distance: %.1f ± %.1f cm (SD)\n",
              mean(batch_results$total_distance_cm, na.rm = TRUE),
              sd(batch_results$total_distance_cm, na.rm = TRUE)))

  # Export batch results
  batch_csv_file <- file.path(output_dir, "batch", "EPM_batch_results.csv")
  dir.create(dirname(batch_csv_file), recursive = TRUE, showWarnings = FALSE)
  export_epm_results(batch_results, batch_csv_file)

  # Generate individual reports for each subject
  cat("\n\nGenerating individual reports...\n")
  batch_output_dir <- file.path(output_dir, "batch")
  batch_reports <- generate_epm_batch_report(
    epm_data_list,
    output_dir = batch_output_dir
  )

  cat("\nBatch reports generated in:", batch_output_dir, "\n")
}


# ==============================================================================
# Example 3: Custom Arena Configuration
# ==============================================================================

cat("\n\n")
cat("Example 3: Custom Arena Configuration\n")
cat("--------------------------------------\n\n")

# Define custom EPM dimensions (e.g., for a smaller maze)
custom_arena <- list(
  arm_length = 35,      # cm (shorter arms)
  arm_width = 6,        # cm (wider arms)
  center_size = 8,      # cm (smaller center)
  open_arms = c("north", "south"),
  closed_arms = c("east", "west")
)

cat("Loading with custom arena dimensions:\n")
cat(sprintf("  Arm length:  %d cm\n", custom_arena$arm_length))
cat(sprintf("  Arm width:   %d cm\n", custom_arena$arm_width))
cat(sprintf("  Center size: %d cm\n", custom_arena$center_size))

# Load with custom config
epm_custom <- load_epm_data(
  file_path = test_file,
  fps = 25,
  pixels_per_cm = 5.3,
  arena_config = custom_arena,
  body_part = "mouse_center"
)

cat("\nCustom configuration loaded successfully.\n")
cat("Zone occupancy with custom dimensions:\n")
summary <- summarize_epm_data(epm_custom)


# ==============================================================================
# Example 4: Quality Control Checks
# ==============================================================================

cat("\n\n")
cat("Example 4: Quality Control\n")
cat("--------------------------\n\n")

# Check data quality for all loaded subjects
if (length(epm_data_list) > 0) {
  cat("Quality control checks:\n\n")

  for (i in seq_along(epm_data_list)) {
    epm_data <- epm_data_list[[i]]
    results <- analyze_epm(epm_data)

    cat(sprintf("Subject %s:\n", epm_data$subject_id))

    # Check exploration
    if (results$total_arm_entries < 5) {
      cat("  ⚠️  WARNING: Low exploration (< 5 arm entries)\n")
    } else {
      cat("  ✓ Sufficient exploration\n")
    }

    # Check tracking quality
    mean_likelihood <- mean(epm_data$data$likelihood, na.rm = TRUE)
    if (mean_likelihood < 0.9) {
      cat(sprintf("  ⚠️  WARNING: Low tracking quality (mean likelihood: %.3f)\n", mean_likelihood))
    } else {
      cat(sprintf("  ✓ Good tracking quality (mean likelihood: %.3f)\n", mean_likelihood))
    }

    # Check for edge artifacts (time outside defined zones)
    pct_outside <- 100 - (results$pct_time_in_open + results$pct_time_in_closed + results$pct_time_in_center)
    if (pct_outside > 10) {
      cat(sprintf("  ⚠️  WARNING: %.1f%% of time outside defined zones\n", pct_outside))
    } else {
      cat(sprintf("  ✓ Most time in defined zones (%.1f%% outside)\n", pct_outside))
    }

    cat("\n")
  }
}


# ==============================================================================
# Summary
# ==============================================================================

cat("\n")
cat("========================================\n")
cat("  EPM Pipeline Demonstration Complete\n")
cat("========================================\n\n")

cat("What was demonstrated:\n")
cat("  ✓ Loading EPM data from DLC CSV files\n")
cat("  ✓ Calculating anxiety indices (open arm ratio, entries ratio)\n")
cat("  ✓ Analyzing locomotor activity\n")
cat("  ✓ Generating visualization plots and reports\n")
cat("  ✓ Batch processing multiple subjects\n")
cat("  ✓ Custom arena configurations\n")
cat("  ✓ Quality control checks\n\n")

cat("Output directory:", output_dir, "\n")
cat("  - Single subject reports\n")
cat("  - Batch analysis results\n")
cat("  - Individual subject plots\n\n")

cat("Key Metrics:\n")
cat("  - Open Arm Ratio: Primary anxiety index (lower = more anxiety)\n")
cat("  - Entries Ratio: Secondary anxiety index\n")
cat("  - Recommended: > 5 total arm entries for reliable results\n\n")

cat("Next Steps:\n")
cat("  1. Adjust pixels_per_cm based on your arena calibration\n")
cat("  2. Verify arm dimensions match your EPM setup\n")
cat("  3. Run quality control on all subjects\n")
cat("  4. Export results for statistical analysis\n\n")

cat("For more information, see QUICKSTART_EPM.md\n\n")
