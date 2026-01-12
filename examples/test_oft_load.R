# Test script for oft_load.R
# Verify data loading works before implementing analysis

# Source required files
source("R/common/io.R")
source("R/oft/oft_load.R")

cat("=== Testing OFT Data Loading ===\n\n")

# Test file
oft_file <- "data/OFT/OF 20250929/Raw data-OF RebeccaAndersonWagner-Trial     1 (3).xlsx"

cat("Loading OFT data from:", oft_file, "\n")

# Load data
oft_data <- load_oft_data(oft_file, fps = 25)

cat("\n=== Data Structure ===\n")
cat("Number of arenas:", length(oft_data), "\n")
cat("Arena names:", paste(names(oft_data), collapse = ", "), "\n\n")

# Check first arena
arena1 <- oft_data[[1]]
cat("=== Arena 1 Details ===\n")
cat("Arena ID:", arena1$arena_id, "\n")
cat("Subject ID:", arena1$subject_id, "\n")
cat("Number of frames:", arena1$n_frames, "\n")
cat("FPS:", arena1$fps, "\n")
cat("Duration:", round(max(arena1$data$time, na.rm = TRUE), 2), "seconds\n\n")

cat("Columns in data:\n")
print(colnames(arena1$data))
cat("\n")

# Check zone columns
zone_cols <- grep("^zone_", colnames(arena1$data), value = TRUE)
cat("Zone columns found:\n")
for (zcol in zone_cols) {
  n_in_zone <- sum(arena1$data[[zcol]], na.rm = TRUE)
  pct_in_zone <- (n_in_zone / nrow(arena1$data)) * 100
  cat("  ", zcol, ":", n_in_zone, "frames (", round(pct_in_zone, 1), "%)\n", sep = "")
}
cat("\n")

# Validate data
cat("=== Validating Data ===\n")
validate_oft_data(oft_data)
cat("Validation passed!\n\n")

# Summarize data
cat("=== Data Summary ===\n")
summary <- summarize_oft_data(oft_data)
print(summary)

cat("\n=== Test Complete ===\n")
