# Test script for oft_analysis.R
# Verify analysis calculations work correctly

# Source required files
source("R/common/io.R")
source("R/ld/ld_analysis.R")  # For shared functions
source("R/oft/oft_load.R")
source("R/oft/oft_analysis.R")

cat("=== Testing OFT Analysis Functions ===\n\n")

# Test file
oft_file <- "data/OFT/OF 20250929/Raw data-OF RebeccaAndersonWagner-Trial     1 (3).xlsx"

# Load data
cat("Loading OFT data...\n")
oft_data <- load_oft_data(oft_file, fps = 25)

# Analyze single arena
cat("\n=== Single Arena Analysis ===\n")
arena1 <- oft_data$Arena_1
results1 <- analyze_oft(arena1$data, fps = 25)

cat("Arena 1 Results:\n")
cat("  Time in center:", round(results1$time_in_center_sec, 2), "sec (",
    round(results1$pct_time_in_center, 1), "%)\n")
cat("  Time in periphery:", round(results1$time_in_periphery_sec, 2), "sec (",
    round(results1$pct_time_in_periphery, 1), "%)\n")
cat("  Entries to center:", results1$entries_to_center, "\n")
cat("  Latency to center:", round(results1$latency_to_center_sec, 2), "sec\n")
cat("  Total distance:", round(results1$total_distance_cm, 2), "cm\n")
cat("  Avg velocity:", round(results1$avg_velocity_cm_s, 2), "cm/s\n")
cat("  Thigmotaxis index:", round(results1$thigmotaxis_index, 3), "\n")

# Batch analysis
cat("\n=== Batch Analysis ===\n")
batch_results <- analyze_oft_batch(oft_data, fps = 25)

cat("Number of arenas analyzed:", nrow(batch_results), "\n\n")

# Display key metrics
cat("Summary of key metrics across arenas:\n")
print(batch_results[, c("arena_name", "pct_time_in_center", "entries_to_center",
                        "total_distance_cm", "avg_velocity_cm_s")])

# Export results
cat("\n=== Exporting Results ===\n")
output_file <- "output/test_oft_results.csv"
export_oft_results(batch_results, output_file)

cat("\n=== Test Complete ===\n")
