# Quick Start Guide: OFT (Open Field Test) Analysis

## Overview

This guide shows how to analyze Open Field Test (OFT) data using the DLCAnalyzer package. The OFT pipeline analyzes anxiety-like behavior, locomotor activity, and exploratory behavior in rodents.

## Setup

```r
# Activate conda environment first (in terminal)
# conda activate r

# Load required functions
source("R/common/io.R")
source("R/common/geometry.R")
source("R/common/plotting.R")
source("R/ld/ld_analysis.R")  # For shared zone calculation functions
source("R/oft/oft_load.R")
source("R/oft/oft_analysis.R")
source("R/oft/oft_report.R")
```

## Quick Example

```r
# 1. Load OFT data (supports multi-arena files)
oft_data <- load_oft_data("data/OFT/your_file.xlsx", fps = 25)

# 2. Analyze all arenas
results <- analyze_oft_batch(oft_data, fps = 25)

# 3. View key metrics
print(results[, c("arena_name", "pct_time_in_center", "entries_to_center",
                  "total_distance_cm", "avg_velocity_cm_s")])

# 4. Generate reports with plots
generate_oft_batch_report(oft_data, output_dir = "output/OFT_reports", fps = 25)
```

## What Gets Analyzed

### Zone Metrics
- **Time in center**: Seconds and percentage of time in the center zone
- **Time in periphery**: Seconds and percentage of time in the periphery
- **Entries to center**: Number of times the animal entered the center
- **Latency to center**: Time until first center entry

### Locomotor Activity
- **Total distance**: Total distance traveled (cm)
- **Average velocity**: Mean velocity (cm/s)
- **Distance in zones**: Distance traveled in center vs periphery

### Anxiety-Like Behavior
- **Thigmotaxis index**: Proportion of time spent near walls (wall-hugging)
- **Center avoidance**: <5% time in center indicates high anxiety

## Step-by-Step Workflow

### 1. Load and Validate Data

```r
# Load data from Ethovision Excel file
oft_data <- load_oft_data("data/OFT/experiment.xlsx", fps = 25)

# Check data structure
summary <- summarize_oft_data(oft_data)
print(summary)

# Validate data quality
validate_oft_data(oft_data)
```

### 2. Analyze Single Arena

```r
# Get first arena
arena1 <- oft_data$Arena_1

# Analyze
results <- analyze_oft(arena1$data, fps = 25)

# View results
print(results$pct_time_in_center)    # % time in center
print(results$entries_to_center)      # Number of entries
print(results$total_distance_cm)      # Total distance
print(results$thigmotaxis_index)      # Wall-hugging behavior
```

### 3. Batch Analysis

```r
# Analyze all arenas at once
batch_results <- analyze_oft_batch(oft_data, fps = 25)

# Export to CSV
export_oft_results(batch_results, "output/oft_metrics.csv")

# View summary
print(batch_results)
```

### 4. Generate Reports

```r
# Generate report for single arena
report_files <- generate_oft_report(
  arena_data = oft_data$Arena_1,
  output_dir = "output/Arena_1_report",
  subject_id = "Subject_1",
  fps = 25
)

# Generate batch reports (all arenas)
batch_results <- generate_oft_batch_report(
  oft_data = oft_data,
  output_dir = "output/OFT_batch_reports",
  fps = 25
)
```

## Understanding the Output

### Metrics CSV
Contains one row per arena with columns:
- `arena_name`: Arena identifier
- `pct_time_in_center`: Percentage of time in center zone
- `entries_to_center`: Number of entries to center
- `latency_to_center_sec`: Time to first center entry
- `total_distance_cm`: Total distance traveled
- `avg_velocity_cm_s`: Average velocity
- `thigmotaxis_index`: Wall-hugging index (0-1)

### Report Files (per arena)
- **trajectory.png**: Movement path colored by zone
- **heatmap.png**: Position heatmap showing preferred locations
- **zone_time.png**: Bar plot of time in center vs periphery
- **metrics.csv**: All calculated metrics
- **summary.txt**: Human-readable summary with interpretation

### Behavioral Interpretation

The analysis provides automatic interpretation:

**High anxiety-like behavior:**
- Time in center < 5%
- Few entries to center (<5)
- High latency to center (>60s)
- High thigmotaxis index (>0.8)

**Low anxiety-like behavior:**
- Time in center > 15%
- Many entries to center (>15)
- Low latency to center (<10s)
- Low thigmotaxis index (<0.3)

## Common Use Cases

### Compare Treatment Groups

```r
# Load multiple files
control_data <- load_oft_data("control_experiment.xlsx")
treated_data <- load_oft_data("treated_experiment.xlsx")

# Analyze
control_results <- analyze_oft_batch(control_data)
treated_results <- analyze_oft_batch(treated_data)

# Compare center time
mean(control_results$pct_time_in_center)
mean(treated_results$pct_time_in_center)

# Statistical test (example)
t.test(control_results$pct_time_in_center,
       treated_results$pct_time_in_center)
```

### Check Data Quality

```r
# Load data
oft_data <- load_oft_data("experiment.xlsx")

# Get summary
summary <- summarize_oft_data(oft_data)

# Check for issues
if (any(summary$pct_missing_coords > 10)) {
  warning("Some arenas have >10% missing coordinates")
}

# Check trial duration
if (any(summary$duration_sec < 300)) {
  warning("Some trials are shorter than 5 minutes")
}
```

### Export for Statistical Analysis

```r
# Analyze all experiments
exp1 <- analyze_oft_batch(load_oft_data("exp1.xlsx"))
exp2 <- analyze_oft_batch(load_oft_data("exp2.xlsx"))

# Add group labels
exp1$group <- "Control"
exp2$group <- "Treated"

# Combine
all_results <- rbind(exp1, exp2)

# Export for stats software
write.csv(all_results, "oft_for_stats.csv", row.names = FALSE)
```

## Data Requirements

### Expected File Format
- **Format**: Ethovision Excel (.xlsx)
- **Structure**: Multi-arena file with 4 arenas (typical)
- **Zones**: Must have center zone defined (e.g., "center1", "center2")
- **Optional**: Floor, wall zones for thigmotaxis calculation
- **Body part**: Typically "Center-point"

### Zone Naming Patterns
The analysis looks for these zone patterns:
- Center zones: "center1", "center2", "center3", "center4"
- Floor zones: "floor1", "floor2", etc.
- Wall zones: "wall1", "wall2", etc.

## Troubleshooting

### "No zone columns found"
**Problem**: Zone data not detected
**Solution**: Check that zones are defined in Ethovision and named correctly (e.g., "center1", "floor1")

### "Missing required columns: x_center"
**Problem**: Coordinate columns not found
**Solution**: Ensure Ethovision export includes X/Y coordinates for center-point

### High percentage of missing coordinates
**Problem**: Tracking quality issues
**Solution**:
1. Check video quality
2. Verify DLC model performance
3. Consider re-tracking or filtering bad frames

### Results seem incorrect
**Problem**: Metrics don't match expected values
**Solution**:
1. Check FPS parameter matches your recording
2. Verify zone definitions in Ethovision
3. Inspect plots to visually verify zones
4. Check for arena numbering mismatches

## Advanced Usage

### Custom Body Part

```r
# Use nose-point instead of center-point
oft_data <- load_oft_data("file.xlsx", body_part = "Nose-point")
results <- analyze_oft(arena$data, body_part = "nose")
```

### Thigmotaxis Analysis

```r
# Calculate thigmotaxis if wall zones available
arena1 <- oft_data$Arena_1
thigmo <- calculate_thigmotaxis_index(arena1$data, fps = 25)
print(thigmo)  # 0.8 means 80% time near walls
```

### Access Zone Names

```r
# See what zones are available
zones <- get_oft_zone_names(oft_data$Arena_1)
print(zones)
```

## Tips for Success

1. **Check your data first**: Always run `summarize_oft_data()` to check quality
2. **Verify FPS**: Make sure the FPS parameter matches your recording
3. **Inspect plots**: Visual verification is important for catching issues
4. **Compare to manual scoring**: Validate automated results against manual checks
5. **Document zone definitions**: Keep records of how zones were defined in Ethovision

## Example Output

```
  arena_name pct_time_in_center entries_to_center total_distance_cm avg_velocity_cm_s
1    Arena_1               2.0                 7          2434.62            410.88
2    Arena_2               3.6                11          3047.07            520.75
3    Arena_3               6.5                14          3661.42            593.94
4    Arena_4               3.7                 9          1976.95            327.96
```

**Interpretation**: Arena 3 shows the highest center exploration (6.5% time, 14 entries), suggesting lower anxiety-like behavior compared to Arena 1 (2% time, 7 entries).

## Next Steps

- See [PROJECT_ROADMAP.md](PROJECT_ROADMAP.md) for implementation details
- Check [test_oft_pipeline.R](examples/test_oft_pipeline.R) for a complete working example
- Run tests with `Rscript -e "testthat::test_file('tests/testthat/test-oft-pipeline.R')"`

## Support

For issues or questions:
1. Check test files for working examples
2. Review code documentation (roxygen2 comments)
3. Consult PROJECT_ROADMAP.md for technical details
