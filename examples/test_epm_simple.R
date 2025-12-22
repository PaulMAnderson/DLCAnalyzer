#!/usr/bin/env Rscript
# Simple EPM Analysis Test
# Quick test to verify the pipeline works

setwd("/mnt/g/Bella/Rebecca/Code/DLCAnalyzer")
source("tests/testthat/setup.R")

cat("\n=== Simple EPM Analysis Test ===\n\n")

# Load data
cat("1. Loading data...\n")
tracking_data <- convert_dlc_to_tracking_data(
  "data/EPM/Example DLC Data/ID7689_superanimal_topviewmouse_snapshot-hrnet_w32-004_snapshot-fasterrcnn_resnet50_fpn_v2-004__filtered.csv",
  fps = 30,
  subject_id = "ID7689",
  paradigm = "epm"
)
cat(sprintf("   Loaded %d frames\n", nrow(tracking_data$tracking)))

# Load arena
cat("\n2. Loading arena...\n")
arena <- load_arena_configs(
  "config/arena_definitions/EPM/EPM.yaml",
  arena_id = "arena1"
)
cat(sprintf("   Arena has %d zones\n", length(arena$zones)))

# Calculate metrics
cat("\n3. Calculating metrics...\n")
occupancy <- calculate_zone_occupancy(tracking_data, arena, body_part = "mouse_center")
cat("   Zone occupancy:\n")
print(occupancy)

# Generate report
cat("\n4. Generating report...\n")
report <- generate_subject_report(
  tracking_data,
  arena,
  output_dir = "reports/test_simple",
  body_part = "mouse_center",
  format = "html"
)

cat("\n=== TEST COMPLETE ===\n")
cat(sprintf("Report: %s\n", file.path("reports/test_simple", "ID7689_report.html")))
