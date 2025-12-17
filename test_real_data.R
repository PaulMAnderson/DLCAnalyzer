# Test with Real DLC Data
# Tests loading an actual EPM DLC file from the project

cat("=================================================\n")
cat("Testing with Real DLC Data\n")
cat("=================================================\n\n")

# Source modules
source("R/core/data_structures.R")
source("R/core/data_loading.R")
source("R/core/data_converters.R")

# Find a real DLC file
dlc_file <- "data/EPM/Output_DLC/EPM_10DeepCut_resnet50_epmMay17shuffle1_1030000.csv"

if (!file.exists(dlc_file)) {
  cat("Real data file not found:", dlc_file, "\n")
  cat("Skipping real data test\n")
  quit(save = "no")
}

cat("Loading real EPM data file...\n")
cat("File:", dlc_file, "\n\n")

# Define EPM reference point names
epm_ref_points <- c("tl", "tr", "bl", "br", "lt", "lb", "rt", "rb",
                    "ctl", "ctr", "cbl", "cbr")

# Load the data
cat("Converting to tracking_data format...\n")
tracking_data <- convert_dlc_to_tracking_data(
  dlc_file,
  fps = 30,
  subject_id = "EPM_10",
  paradigm = "elevated_plus_maze",
  reference_point_names = epm_ref_points,
  units = "pixels"
)

cat("✓ Data loaded successfully!\n\n")

# Print summary
cat("=================================================\n")
print(tracking_data)
cat("=================================================\n\n")

# Get detailed summary
cat("Detailed Summary:\n")
cat("=================================================\n")
summary(tracking_data)
cat("=================================================\n\n")

# Check body parts
cat("Body Parts (Animal Tracking):\n")
bodyparts <- get_bodyparts(tracking_data)
cat("  -", paste(bodyparts, collapse = "\n  - "), "\n\n")

# Check reference points
cat("Reference Points (Arena Markers):\n")
ref_points <- get_reference_points(tracking_data)
if (!is.null(ref_points)) {
  cat("  -", paste(ref_points, collapse = "\n  - "), "\n\n")

  # Show reference point positions
  cat("Reference Point Positions:\n")
  print(tracking_data$arena$reference_points)
  cat("\n")
}

# Data quality check
cat("Data Quality Check:\n")
cat("-------------------\n")
total_frames <- length(unique(tracking_data$tracking$frame))
cat("Total frames:", total_frames, "\n")

for (bp in bodyparts) {
  bp_data <- tracking_data$tracking[tracking_data$tracking$body_part == bp, ]
  n_frames <- nrow(bp_data)
  avg_likelihood <- mean(bp_data$likelihood, na.rm = TRUE)
  low_conf <- sum(bp_data$likelihood < 0.9, na.rm = TRUE)

  cat(sprintf("%-15s: %d frames, avg likelihood = %.3f, low confidence = %d (%.1f%%)\n",
              bp, n_frames, avg_likelihood, low_conf, 100*low_conf/n_frames))
}

cat("\n✓ Real data test completed successfully!\n")
cat("The refactored code successfully handles actual DLC output.\n\n")
