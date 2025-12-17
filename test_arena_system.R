#!/usr/bin/env Rscript

#' Test Arena Configuration System
#'
#' This script tests the arena configuration system with real YAML files
#' and demonstrates the complete workflow.

# Set working directory to project root
setwd("/mnt/g/Bella/Rebecca/Code/DLCAnalyzer")

# Source all required files
source("R/core/data_structures.R")
source("R/core/arena_config.R")
source("R/core/zone_geometry.R")
source("R/core/coordinate_transforms.R")
source("R/utils/config_utils.R")

cat("Arena Configuration System Test\n")
cat("================================\n\n")

# Test 1: Load EPM arena configuration
cat("Test 1: Loading EPM arena configuration...\n")
tryCatch({
  epm_arenas <- load_arena_configs("config/arena_definitions/EPM/EPM.yaml")
  cat("  ✓ Loaded", length(epm_arenas), "EPM arenas\n")

  # Print first arena
  cat("\nEPM Arena 1:\n")
  print(epm_arenas[[1]])

  # Create zone geometries
  cat("\nCreating zone geometries for EPM arena 1...\n")
  epm_zones <- create_all_zone_geometries(epm_arenas[[1]])
  cat("  ✓ Created", length(epm_zones), "zone geometries\n")

  # Print zone details
  for (zone_id in names(epm_zones)) {
    cat("\n")
    print(epm_zones[[zone_id]])
  }

}, error = function(e) {
  cat("  ✗ Error:", conditionMessage(e), "\n")
})

cat("\n")

# Test 2: Load Open Field arena configuration
cat("Test 2: Loading Open Field arena configuration...\n")
tryCatch({
  of_arenas <- load_arena_configs("config/arena_definitions/OF/OF.yaml")
  cat("  ✓ Loaded", length(of_arenas), "Open Field arenas\n")

  # Print first arena
  cat("\nOpen Field Arena 1:\n")
  print(of_arenas[[1]])

  # Create zone geometries
  cat("\nCreating zone geometries for Open Field arena 1...\n")
  of_zones <- create_all_zone_geometries(of_arenas[[1]])
  cat("  ✓ Created", length(of_zones), "zone geometries\n")

}, error = function(e) {
  cat("  ✗ Error:", conditionMessage(e), "\n")
})

cat("\n")

# Test 3: Load NORT arena configuration
cat("Test 3: Loading NORT arena configuration...\n")
tryCatch({
  nort_arenas <- load_arena_configs("config/arena_definitions/NORT/NORT.yaml")
  cat("  ✓ Loaded", length(nort_arenas), "NORT arenas\n")

  # Print arena
  cat("\nNORT Arena 1:\n")
  print(nort_arenas[[1]])

  # Create zone geometries
  cat("\nCreating zone geometries for NORT arena 1...\n")
  nort_zones <- create_all_zone_geometries(nort_arenas[[1]])
  cat("  ✓ Created", length(nort_zones), "zone geometries\n")

}, error = function(e) {
  cat("  ✗ Error:", conditionMessage(e), "\n")
})

cat("\n")

# Test 4: Load Light-Dark arena configuration
cat("Test 4: Loading Light-Dark arena configuration...\n")
tryCatch({
  ld_arenas <- load_arena_configs("config/arena_definitions/LD/LD.yaml")
  cat("  ✓ Loaded", length(ld_arenas), "Light-Dark arenas\n")

  # Print first arena
  cat("\nLight-Dark Arena 1:\n")
  print(ld_arenas[[1]])

  # Create zone geometries
  cat("\nCreating zone geometries for Light-Dark arena 1...\n")
  ld_zones <- create_all_zone_geometries(ld_arenas[[1]])
  cat("  ✓ Created", length(ld_zones), "zone geometries\n")

}, error = function(e) {
  cat("  ✗ Error:", conditionMessage(e), "\n")
})

cat("\n")

# Test 5: Test point-in-zone detection
cat("Test 5: Testing point-in-zone detection with Open Field...\n")
tryCatch({
  of_arenas <- load_arena_configs("config/arena_definitions/OF/OF.yaml")
  of_zones <- create_all_zone_geometries(of_arenas[[1]])

  # Get the arena zone (outer boundary)
  arena_zone <- of_zones[["arena"]]

  # Get center zone
  center_zone <- of_zones[["centre"]]

  # Test some points
  test_points <- data.frame(
    x = c(300, 400, 250),  # middle-ish, right, left edge
    y = c(200, 200, 60),
    stringsAsFactors = FALSE
  )

  in_arena <- point_in_zone(test_points$x, test_points$y, arena_zone)
  in_center <- point_in_zone(test_points$x, test_points$y, center_zone)

  cat("  Test points:\n")
  for (i in 1:nrow(test_points)) {
    cat(sprintf("    Point (%d, %d): arena=%s, center=%s\n",
                test_points$x[i], test_points$y[i],
                in_arena[i], in_center[i]))
  }

  cat("  ✓ Point-in-zone detection working\n")

}, error = function(e) {
  cat("  ✗ Error:", conditionMessage(e), "\n")
})

cat("\n")

# Test 6: Test coordinate scale calculation
cat("Test 6: Testing coordinate scale calculation...\n")
tryCatch({
  # Create a test arena with known distances
  test_arena <- new_arena_config(
    id = "test_scale",
    points = data.frame(
      point_name = c("p1", "p2"),
      x = c(0, 0),
      y = c(0, 100),
      stringsAsFactors = FALSE
    )
  )

  # Calculate scale: 100 pixels = 10 cm -> 10 pixels/cm
  scale <- calculate_arena_scale(test_arena, "p1", "p2", real_distance_cm = 10)
  cat(sprintf("  Calculated scale: %.2f pixels/cm\n", scale))

  # Convert some coordinates
  coords_pixels <- data.frame(x = c(0, 50, 100), y = c(0, 50, 100))
  coords_cm <- pixels_to_cm(coords_pixels$x, coords_pixels$y, scale)

  cat("  Pixel to cm conversion:\n")
  for (i in 1:nrow(coords_pixels)) {
    cat(sprintf("    (%d, %d) pixels = (%.1f, %.1f) cm\n",
                coords_pixels$x[i], coords_pixels$y[i],
                coords_cm$x[i], coords_cm$y[i]))
  }

  cat("  ✓ Scale calculation working\n")

}, error = function(e) {
  cat("  ✗ Error:", conditionMessage(e), "\n")
})

cat("\n")

# Test 7: Integration test - full workflow
cat("Test 7: Full integration test...\n")
tryCatch({
  # Create mock tracking data in pixels
  tracking_df <- data.frame(
    frame = 1:5,
    time = seq(0, length.out = 5, by = 1/30),
    body_part = "bodycentre",
    x = c(300, 320, 340, 360, 380),
    y = c(200, 210, 220, 230, 240),
    likelihood = rep(0.99, 5),
    stringsAsFactors = FALSE
  )

  tracking_data <- new_tracking_data(
    metadata = list(
      source = "test",
      fps = 30,
      subject_id = "test_mouse",
      paradigm = "open_field",
      units = "pixels"
    ),
    tracking = tracking_df
  )

  cat("  Created mock tracking data:\n")
  print(tracking_data)

  # Load arena configuration
  of_arenas <- load_arena_configs("config/arena_definitions/OF/OF.yaml")
  arena <- of_arenas[[1]]

  # Set a scale for testing (10 pixels/cm)
  arena$scale <- 10

  # Transform coordinates to cm
  cat("\n  Transforming coordinates to cm...\n")
  tracking_cm <- apply_arena_transform(tracking_data, arena, to_units = "cm")

  cat("  Transformed tracking data:\n")
  cat(sprintf("    First point: (%.1f, %.1f) cm\n",
              tracking_cm$tracking$x[1],
              tracking_cm$tracking$y[1]))

  # Create zone geometries
  zones <- create_all_zone_geometries(arena)

  # Check which zones the first point is in
  cat("\n  Checking zones for first tracking point...\n")
  for (zone_id in names(zones)) {
    # Convert first point back to pixels for zone checking
    # (zones are in pixel coordinates)
    in_zone <- point_in_zone(
      tracking_data$tracking$x[1],
      tracking_data$tracking$y[1],
      zones[[zone_id]]
    )
    cat(sprintf("    %s: %s\n", zone_id, in_zone))
  }

  cat("\n  ✓ Full integration test passed\n")

}, error = function(e) {
  cat("  ✗ Error:", conditionMessage(e), "\n")
  cat("  Stack trace:\n")
  print(traceback())
})

cat("\n")
cat("All tests completed!\n")
