# Test quality check functions with real EPM data

# Source required files
source("R/core/data_structures.R")
source("R/core/data_loading.R")
source("R/core/data_converters.R")
source("R/core/quality_checks.R")

cat("=" %R% 80, "\n")
cat("TESTING QUALITY CHECK FUNCTIONS WITH REAL EPM DATA\n")
cat("=" %R% 80, "\n\n")

# Load a real DLC file
dlc_file <- "data/EPM/Example DLC Data/ID7689_superanimal_topviewmouse_snapshot-hrnet_w32-004_snapshot-fasterrcnn_resnet50_fpn_v2-004__filtered.csv"

cat("Loading DLC file:", dlc_file, "\n")
tracking_data <- convert_dlc_to_tracking_data(
  dlc_file,
  fps = 30,
  subject_id = "ID7689",
  paradigm = "epm"
)

cat("Data loaded successfully!\n")
cat("Total frames:", max(tracking_data$tracking$frame), "\n")
cat("Body parts:", paste(unique(tracking_data$tracking$body_part), collapse = ", "), "\n\n")

# Test 1: Overall quality check
cat("-" %R% 80, "\n")
cat("TEST 1: check_tracking_quality()\n")
cat("-" %R% 80, "\n")
quality <- check_tracking_quality(tracking_data)
print(quality)
cat("\n")

# Test 2: Outlier detection
cat("-" %R% 80, "\n")
cat("TEST 2: detect_outliers() - IQR method\n")
cat("-" %R% 80, "\n")
outliers_iqr <- detect_outliers(tracking_data, method = "iqr", threshold = 1.5)
cat("Outliers detected (IQR):", sum(outliers_iqr$is_outlier), "\n")
cat("Outliers by body part:\n")
outlier_summary <- aggregate(is_outlier ~ body_part, data = outliers_iqr, FUN = sum)
print(outlier_summary)
cat("\n")

# Test 3: Outlier detection with different methods
cat("-" %R% 80, "\n")
cat("TEST 3: detect_outliers() - Z-score method\n")
cat("-" %R% 80, "\n")
outliers_z <- detect_outliers(tracking_data, method = "zscore", threshold = 3)
cat("Outliers detected (Z-score):", sum(outliers_z$is_outlier), "\n\n")

cat("-" %R% 80, "\n")
cat("TEST 4: detect_outliers() - MAD method\n")
cat("-" %R% 80, "\n")
outliers_mad <- detect_outliers(tracking_data, method = "mad", threshold = 3.5)
cat("Outliers detected (MAD):", sum(outliers_mad$is_outlier), "\n\n")

# Test 5: Missing data summary
cat("-" %R% 80, "\n")
cat("TEST 5: calculate_missing_data_summary()\n")
cat("-" %R% 80, "\n")
missing <- calculate_missing_data_summary(tracking_data)
print(missing)
cat("\n")

# Test 6: Suspicious jumps
cat("-" %R% 80, "\n")
cat("TEST 6: flag_suspicious_jumps() - Auto threshold\n")
cat("-" %R% 80, "\n")
jumps <- flag_suspicious_jumps(tracking_data)
cat("Auto-calculated threshold:", attr(jumps, "max_displacement"), "pixels\n")
cat("Suspicious jumps detected:", sum(jumps$is_suspicious_jump, na.rm = TRUE), "\n")
cat("Jumps by body part:\n")
jump_summary <- aggregate(is_suspicious_jump ~ body_part, data = jumps, FUN = sum)
print(jump_summary)
cat("\n")

# Test 7: Comprehensive quality report (text format)
cat("-" %R% 80, "\n")
cat("TEST 7: generate_quality_report() - Text format\n")
cat("-" %R% 80, "\n")
report_text <- generate_quality_report(tracking_data, output_format = "text")
cat(report_text, sep = "\n")
cat("\n")

# Test 8: Comprehensive quality report (list format)
cat("-" %R% 80, "\n")
cat("TEST 8: generate_quality_report() - List format\n")
cat("-" %R% 80, "\n")
report_list <- generate_quality_report(tracking_data, output_format = "list")
cat("Report components:\n")
cat("  - Quality metrics:", length(report_list$quality$recommendations), "recommendations\n")
cat("  - Outliers:", report_list$outliers$n_outliers, "detected\n")
cat("  - Suspicious jumps:", report_list$jumps$n_suspicious_jumps, "detected\n")
cat("\n")

# Test 9: Quality check on specific body parts
cat("-" %R% 80, "\n")
cat("TEST 9: Quality check on specific body parts\n")
cat("-" %R% 80, "\n")
body_parts <- unique(tracking_data$tracking$body_part)
if (length(body_parts) >= 2) {
  selected_parts <- body_parts[1:min(2, length(body_parts))]
  cat("Selected body parts:", paste(selected_parts, collapse = ", "), "\n\n")

  quality_subset <- check_tracking_quality(tracking_data, body_parts = selected_parts)
  cat("Quality check results:\n")
  print(quality_subset$likelihood)
  cat("\n")
}

cat("=" %R% 80, "\n")
cat("ALL TESTS COMPLETED SUCCESSFULLY!\n")
cat("=" %R% 80, "\n")

# Helper function for string repetition
`%R%` <- function(x, n) {
  paste(rep(x, n), collapse = "")
}
