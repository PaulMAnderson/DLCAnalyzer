# tests/test_reporting_epm.R
# Integration test for reporting system with real EPM data

# Source all R files
source("R/core/data_structures.R")
source("R/core/data_loading.R")
source("R/core/data_converters.R")
source("R/core/arena_config.R")
source("R/core/zone_geometry.R")
source("R/core/coordinate_transforms.R")
source("R/core/preprocessing.R")
source("R/core/quality_checks.R")
source("R/metrics/zone_analysis.R")
source("R/metrics/time_in_zone.R")
source("R/utils/config_utils.R")
source("R/reporting/generate_report.R")
source("R/visualization/plot_tracking.R")

# Load required libraries
if (!requireNamespace("ggplot2", quietly = TRUE)) {
  cat("WARNING: ggplot2 not installed. Installing now...\n")
  install.packages("ggplot2", repos = "https://cloud.r-project.org")
}
library(ggplot2)

cat("\n=== Testing DLCAnalyzer Reporting System with EPM Data ===\n\n")

# Find EPM data files
epm_files <- list.files("data/EPM/Example DLC Data/",
                       pattern = "\\.csv$",
                       full.names = TRUE)

if (length(epm_files) == 0) {
  stop("No EPM data files found!")
}

cat("Found", length(epm_files), "EPM data files\n")
cat("Using:", basename(epm_files[1]), "\n\n")

# Load EPM data
cat("Step 1: Loading tracking data...\n")
tracking_data <- convert_dlc_to_tracking_data(
  epm_files[1],
  fps = 30,
  subject_id = "ID7689_test",
  paradigm = "epm"
)

cat("  - Loaded", nrow(tracking_data$tracking), "frames\n")
cat("  - Body parts:", paste(unique(tracking_data$tracking$body_part), collapse = ", "), "\n\n")

# Load arena configuration
cat("Step 2: Loading arena configuration...\n")
arena_config_file <- "config/arena_definitions/EPM/EPM.yaml"

if (!file.exists(arena_config_file)) {
  stop("Arena configuration file not found: ", arena_config_file)
}

arena <- load_arena_configs(arena_config_file, arena_id = "arena1")
cat("  - Arena ID:", arena$id, "\n")
cat("  - Zones:", paste(names(arena$zones), collapse = ", "), "\n\n")

# Test visualization functions
cat("Step 3: Testing visualization functions...\n")

# Test heatmap
cat("  - Testing plot_heatmap()...\n")
tryCatch({
  p_heatmap <- plot_heatmap(tracking_data, arena, body_part = "mouse_center")
  cat("    SUCCESS: Heatmap created\n")
}, error = function(e) {
  cat("    ERROR:", e$message, "\n")
})

# Test trajectory
cat("  - Testing plot_trajectory()...\n")
tryCatch({
  p_trajectory <- plot_trajectory(tracking_data, arena, body_part = "mouse_center")
  cat("    SUCCESS: Trajectory plot created\n")
}, error = function(e) {
  cat("    ERROR:", e$message, "\n")
})

# Test zone occupancy calculation and plotting
cat("  - Testing zone occupancy calculation and plotting...\n")
tryCatch({
  occupancy <- calculate_zone_occupancy(tracking_data, arena, body_part = "mouse_center")
  cat("    SUCCESS: Zone occupancy calculated\n")
  print(occupancy)

  p_occupancy <- plot_zone_occupancy(occupancy, plot_type = "bar")
  cat("    SUCCESS: Occupancy plot created\n")
}, error = function(e) {
  cat("    ERROR:", e$message, "\n")
})

# Test zone transitions calculation and plotting
cat("  - Testing zone transitions calculation and plotting...\n")
tryCatch({
  transitions <- calculate_zone_transitions(tracking_data, arena, body_part = "mouse_center")
  cat("    SUCCESS: Zone transitions calculated\n")
  cat("    Total transitions:", sum(transitions$n_transitions), "\n")

  p_transitions <- plot_zone_transitions(transitions, plot_type = "matrix")
  cat("    SUCCESS: Transitions plot created\n")
}, error = function(e) {
  cat("    ERROR:", e$message, "\n")
})

# Test full report generation
cat("\nStep 4: Testing full report generation...\n")
output_dir <- "reports/test_epm_report"

tryCatch({
  report <- generate_subject_report(
    tracking_data,
    arena,
    output_dir = output_dir,
    body_part = "mouse_center",
    format = "html"
  )

  cat("\nREPORT GENERATION COMPLETE!\n")
  print(report)

  cat("\n=== Report Files ===\n")
  cat("Output directory:", output_dir, "\n")

  if (file.exists(output_dir)) {
    files <- list.files(output_dir, recursive = TRUE)
    cat("\nGenerated files:\n")
    for (f in files) {
      cat("  -", f, "\n")
    }
  }

}, error = function(e) {
  cat("ERROR generating report:", e$message, "\n")
  cat("Traceback:\n")
  print(traceback())
})

cat("\n=== Testing Complete ===\n")
