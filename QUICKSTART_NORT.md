# Quick Start Guide: NORT (Novel Object Recognition Test) Analysis

## Overview

This guide shows how to analyze Novel Object Recognition Test (NORT) data using the DLCAnalyzer package. The NORT pipeline analyzes memory and discrimination through object exploration patterns, calculating discrimination indices and preference scores.

## Setup

```r
# Activate conda environment first (in terminal)
# conda activate r

# Load required functions
source("R/common/io.R")
source("R/common/geometry.R")
source("R/common/plotting.R")
source("R/ld/ld_analysis.R")  # For shared zone calculation functions
source("R/nort/nort_load.R")
source("R/nort/nort_analysis.R")
source("R/nort/nort_report.R")
```

## Quick Example

```r
# 1. Load NORT test phase data (specify which side is novel)
nort_data <- load_nort_data("data/NORT/test_file.xlsx", fps = 25, novel_side = "left")

# 2. Analyze all arenas
results <- analyze_nort_batch(nort_data, fps = 25, novel_sides = "left")

# 3. View key memory metrics
print(results[, c("arena_name", "discrimination_index", "preference_score",
                  "total_exploration_sec", "is_valid_trial")])

# 4. Generate reports with discrimination analysis
generate_nort_batch_report(nort_data, output_dir = "output/NORT_reports",
                           novel_sides = "left", fps = 25)
```

## What Gets Analyzed

### Object Exploration
- **Novel object time**: Time exploring the novel object (seconds)
- **Familiar object time**: Time exploring the familiar object (seconds)
- **Total exploration**: Total object exploration time (seconds)
- **Object approaches**: Number of approaches to each object

### Memory Discrimination Indices
- **Discrimination Index (DI)**: (Novel - Familiar) / (Novel + Familiar)
  - Range: -1 to +1
  - >0.2: Intact memory (novelty preference)
  - ~0: No discrimination
  - <-0.1: Familiarity preference or neophobia
- **Preference Score**: % of time with novel object (0-100%)
- **Recognition Index**: Ratio of novel exploration to total (0-1)

### Locomotor Activity
- **Total distance**: Distance traveled (cm) using center-point
- **Average velocity**: Mean velocity (cm/s)
- **Time in center**: Time in center zone (locomotor metric)

### Quality Metrics
- **Trial validity**: Total exploration ≥10 seconds recommended
- **Data completeness**: % of missing coordinates for both body parts

## NORT-Specific Features

### Dual Body Part Tracking
NORT uses **two body parts**:
- **Nose-point**: For object exploration zones
- **Center-point**: For locomotion and arena metrics

This is automatic - the pipeline handles both body parts internally.

### Novel Side Specification
You **must** specify which side has the novel object:

```r
# Novel object on LEFT
nort_data <- load_nort_data("test.xlsx", novel_side = "left")

# Novel object on RIGHT
nort_data <- load_nort_data("test.xlsx", novel_side = "right")

# Habituation phase (both objects identical or empty)
nort_data <- load_nort_data("habituation.xlsx", novel_side = "neither")
```

## Step-by-Step Workflow

### 1. Load and Validate Data

```r
# Load NORT test phase data
nort_data <- load_nort_data("data/NORT/test_phase.xlsx",
                           fps = 25,
                           novel_side = "left")

# Check data structure and exploration times
summary <- summarize_nort_data(nort_data)
print(summary)

# Validate data quality (checks for both nose and center coordinates)
validate_nort_data(nort_data)
```

### 2. Analyze Single Arena

```r
# Get first arena
arena1 <- nort_data$Arena_1

# Analyze
results <- analyze_nort(arena1$data, fps = 25, novel_side = "left")

# View memory metrics
print(paste("Discrimination Index:", results$discrimination_index))
print(paste("Preference Score:", results$preference_score, "%"))
print(paste("Novel object time:", results$novel_object_time_sec, "sec"))
print(paste("Familiar object time:", results$familiar_object_time_sec, "sec"))
print(paste("Trial valid:", results$is_valid_trial))

# Interpret results
interpretation <- interpret_nort_di(results$discrimination_index)
print(interpretation)
```

### 3. Batch Analysis

```r
# Analyze all arenas with different novel sides (if applicable)
batch_results <- analyze_nort_batch(
  nort_data,
  fps = 25,
  novel_sides = c("left", "left", "right", "left")  # One per arena
)

# Or use same novel side for all
batch_results <- analyze_nort_batch(nort_data, fps = 25, novel_sides = "left")

# Export to CSV
export_nort_results(batch_results, "output/nort_metrics.csv")

# View summary
print(batch_results)
```

### 4. Generate Reports

```r
# Single arena report
generate_nort_report(
  arena_data = nort_data$Arena_1,
  output_dir = "output/Arena_1",
  novel_side = "left",
  fps = 25
)

# Batch reports for all arenas
generate_nort_batch_report(
  nort_data,
  output_dir = "output/NORT_batch",
  novel_sides = "left",
  fps = 25
)
```

## Analyzing Habituation + Test Pairs

NORT experiments typically include:
1. **Habituation phase**: Explore 2 identical objects (or empty arena)
2. **Test phase**: Explore 1 familiar + 1 novel object

```r
# Load both phases together
paired_data <- load_nort_paired_data(
  hab_file = "data/NORT/habituation_D1.xlsx",
  test_file = "data/NORT/test_D3.xlsx",
  fps = 25,
  novel_side = "left"
)

# Access each phase
hab_arena1 <- paired_data$habituation$Arena_1
test_arena1 <- paired_data$test$Arena_1

# Analyze test phase
results <- analyze_nort(test_arena1$data, fps = 25, novel_side = "left")
print(results$discrimination_index)
```

## Understanding Outputs

### Discrimination Index Interpretation

```r
# DI = 0.45  →  Strong novelty preference - intact memory
# DI = 0.15  →  Moderate novelty preference - likely intact
# DI = 0.05  →  Weak/no discrimination - impaired or no learning
# DI = -0.20 →  Familiarity preference - neophobia or alternate strategy
```

### Trial Validity

```r
# A valid trial requires:
# - Total exploration ≥ 10 seconds (customizable)
# - Subject must interact with objects enough for reliable assessment

results$is_valid_trial  # TRUE/FALSE
results$total_exploration_sec  # Check exploration time
```

### Generated Plots

Reports include:
1. **Trajectory plot**: Overlaid nose (exploration) + center (locomotion) paths
2. **Heatmap**: Position density based on center-point
3. **Object exploration**: Bar chart comparing novel vs familiar exploration
4. **Batch comparison**: DI across all subjects

## Advanced Usage

### Custom Exploration Threshold

```r
# Require 15 seconds minimum (instead of default 10)
results <- analyze_nort(arena_data$data,
                       fps = 25,
                       novel_side = "left",
                       min_exploration = 15)
```

### Different Novel Sides Per Arena

```r
# If different arenas had novel object on different sides
batch_results <- analyze_nort_batch(
  nort_data,
  fps = 25,
  novel_sides = c("left", "right", "left", "right")
)
```

### Access Individual Metrics

```r
results <- analyze_nort(arena_data$data, fps = 25, novel_side = "left")

# Exploration metrics
results$novel_object_time_sec
results$familiar_object_time_sec
results$total_exploration_sec
results$novel_entries
results$familiar_entries

# Memory indices
results$discrimination_index    # -1 to +1
results$preference_score        # 0 to 100%
results$recognition_index       # 0 to 1

# Locomotor
results$total_distance_cm
results$avg_velocity_cm_s

# Quality
results$is_valid_trial
```

## Example Complete Workflow

```r
# 1. Load test phase data
nort_data <- load_nort_data("data/NORT/NORT_test_20251003.xlsx",
                           fps = 25,
                           novel_side = "left")

# 2. Quick data check
summary <- summarize_nort_data(nort_data)
print(summary)

# 3. Batch analysis
results <- analyze_nort_batch(nort_data, fps = 25, novel_sides = "left")

# 4. Check which trials are valid
print(results[, c("arena_name", "total_exploration_sec", "is_valid_trial")])

# 5. View memory performance
print(results[, c("arena_name", "discrimination_index", "preference_score")])

# 6. Generate reports
generate_nort_batch_report(
  nort_data,
  output_dir = "output/NORT_20251003",
  novel_sides = "left",
  fps = 25
)

# 7. Export data
export_nort_results(results, "output/nort_results_20251003.csv")
```

## Troubleshooting

### Low Exploration Time
```r
# If total exploration < 10 seconds:
# - Trial marked as invalid
# - Results may not be reliable
# - Subject may have been anxious, unmotivated, or fatigued
# - Check if objects were salient/interesting enough
```

### Missing Body Part Coordinates
```r
# NORT requires BOTH nose and center coordinates
# Check for missing data:
summary <- summarize_nort_data(nort_data)
print(summary$pct_missing_nose)    # Should be low
print(summary$pct_missing_center)  # Should be low
```

### No Object Zones Detected
```r
# Ensure your Ethovision file has object zones named like:
# - "round object left"
# - "round object right"
# - "object left"
# - "object right"
#
# Check zone detection:
source("R/common/io.R")
library(readxl)
col_names <- read_excel("file.xlsx", sheet = 1, skip = 36, n_max = 1)
grep("object", names(col_names), ignore.case = TRUE, value = TRUE)
```

## Tips for Best Results

1. **Specify novel side correctly**: Double-check which side has the novel object in your experimental design
2. **Check exploration time**: Trials with <10 seconds may not be reliable
3. **Validate data quality**: Run `validate_nort_data()` before analysis
4. **Use appropriate threshold**: Adjust `min_exploration` based on your protocol
5. **Interpret cautiously**: Low DI may indicate impaired memory OR low motivation/anxiety

## Next Steps

- See `examples/test_nort_pipeline.R` for a complete demo
- Check `tests/testthat/test-nort-pipeline.R` for detailed function tests
- Review generated summary .txt files for interpretation guidelines
- Compare with LD (`QUICKSTART_LD.md`) and OFT (`QUICKSTART_OFT.md`) pipelines

## References

**Discrimination Index Formula:**
- DI = (T_novel - T_familiar) / (T_novel + T_familiar)
- Introduced by: Ennaceur & Delacour (1988), Behav Brain Res

**Interpretation Guidelines:**
- DI > 0.2: Commonly accepted threshold for intact memory
- Total exploration ≥ 10s: Recommended minimum for valid trials
