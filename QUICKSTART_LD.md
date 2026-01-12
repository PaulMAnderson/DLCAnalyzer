# Quick Start Guide: LD (Light/Dark Box) Analysis

## Setup

### 1. Activate Conda Environment
```bash
conda activate r
```

### 2. Install Required Packages
```r
install.packages(c("readxl", "ggplot2", "dplyr", "testthat"))
```

### 3. Set Working Directory
```r
setwd("/path/to/DLCAnalyzer")
```

## Basic Usage

### Load Functions
```r
# Load all LD pipeline functions
source("R/common/io.R")
source("R/common/geometry.R")
source("R/common/plotting.R")
source("R/ld/ld_load.R")
source("R/ld/ld_analysis.R")
source("R/ld/ld_report.R")
```

### Analyze Single File

```r
# Load data from Ethovision Excel file
ld_data <- load_ld_data("data/LD/LD 20251001/Raw data-LD Rebecca 20251001-Trial     1 (2).xlsx",
                        fps = 25)

# Check what was loaded
summary <- summarize_ld_data(ld_data)
print(summary)

# Analyze all arenas
results <- analyze_ld_batch(ld_data, fps = 25)
print(results)

# Export to CSV
export_ld_results(results, "output/ld_results.csv", overwrite = TRUE)

# Generate full reports with plots
reports <- generate_ld_batch_report(ld_data,
                                    output_dir = "output/LD_reports",
                                    fps = 25)
```

### Analyze Single Arena

```r
# Load data
ld_data <- load_ld_data("your_file.xlsx", fps = 25)

# Get first arena
arena1 <- ld_data$Arena_1

# Analyze
results <- analyze_ld(arena1$data, fps = 25)

# View key metrics
cat("Time in light:", results$time_in_light_sec, "sec\n")
cat("Percentage in light:", results$pct_time_in_light, "%\n")
cat("Entries to light:", results$entries_to_light, "\n")
cat("Total distance:", results$total_distance_cm, "cm\n")

# Generate report
generate_ld_report(arena1,
                  output_dir = "output/arena1_report",
                  subject_id = "Arena_1",
                  fps = 25)
```

## Understanding the Output

### Data Structure

When you load an LD file, you get a list with one entry per arena:

```r
ld_data
├── Arena_1
│   ├── data          # Data frame with tracking and zone columns
│   ├── arena_id      # Arena number (1-4)
│   ├── subject_id    # Subject number
│   ├── metadata      # Experiment metadata
│   └── fps           # Frames per second
├── Arena_2
├── Arena_3
└── Arena_4
```

### Data Frame Columns

Each `data` frame contains:
- **frame**: Frame number (0-indexed)
- **time**: Time in seconds
- **x_center, y_center**: Center-point coordinates
- **x_nose, y_nose**: Nose-point coordinates
- **x_tail, y_tail**: Tail-point coordinates
- **zone_light_floor**: Binary (0/1) - in light zone
- **zone_door_area**: Binary (0/1) - in door/transition zone

### Analysis Results

The `analyze_ld()` function returns:

```r
$time_in_light_sec       # Time in light (seconds)
$time_in_dark_sec        # Time in dark (seconds)
$pct_time_in_light       # Percentage in light
$pct_time_in_dark        # Percentage in dark
$entries_to_light        # Number of entries to light
$entries_to_dark         # Number of entries to dark
$latency_to_light_sec    # Latency to first light entry
$latency_to_dark_sec     # Latency to first dark entry
$distance_in_light_cm    # Distance traveled in light
$distance_in_dark_cm     # Distance traveled in dark
$total_distance_cm       # Total distance
$transitions             # Total zone transitions
$total_duration_sec      # Trial duration
```

### Report Files

`generate_ld_report()` creates:
- **trajectory.png**: Movement path colored by zone
- **heatmap.png**: Position density heatmap
- **zone_time.png**: Bar chart of time in zones
- **metrics.csv**: All metrics in CSV format
- **summary.txt**: Human-readable summary with interpretation

## Batch Processing Multiple Files

```r
# List all LD files
ld_files <- list.files("data/LD",
                       pattern = "Raw data.*\\.xlsx$",
                       full.names = TRUE,
                       recursive = TRUE)

# Process each file
all_results <- list()

for (file in ld_files) {
  cat("\nProcessing:", basename(file), "\n")

  # Load data
  ld_data <- load_ld_data(file, fps = 25)

  # Analyze
  results <- analyze_ld_batch(ld_data, fps = 25)

  # Add file identifier
  results$file <- basename(file)

  # Store results
  all_results[[basename(file)]] <- results
}

# Combine all results
combined_results <- do.call(rbind, all_results)

# Export
write.csv(combined_results, "output/all_LD_results.csv", row.names = FALSE)
```

## Group Comparisons

```r
# After batch analysis, add group labels
combined_results$group <- NA
combined_results$group[1:4] <- "Control"
combined_results$group[5:8] <- "Treatment"

# Compare groups
library(ggplot2)

# Time in light comparison
ggplot(combined_results, aes(x = group, y = pct_time_in_light, fill = group)) +
  geom_boxplot() +
  geom_jitter(width = 0.2) +
  labs(title = "% Time in Light by Group",
       y = "% Time in Light",
       x = "Group") +
  theme_minimal()

# Statistical test
t.test(pct_time_in_light ~ group, data = combined_results)
```

## Troubleshooting

### Missing Coordinates

If you see warnings about missing coordinates:
```
Arena Arena_1 has 21318 frames (59.21%) with missing coordinates
```

This is normal and handled automatically. It occurs when:
- Tracking failed for some frames
- Animal left the visible arena
- Occlusion occurred

**Impact:**
- Time-in-zone metrics: NOT affected (zone columns still valid)
- Distance metrics: Slightly underestimated (gaps not counted)

### Column Name Issues

If you get "column not found" errors:
1. Check your Ethovision export settings
2. Run the debug script:
```r
source("examples/debug_columns.R")
```
3. Update `standardize_ld_columns()` in `R/ld/ld_load.R` if needed

### No Zone Columns Found

If no zones are extracted:
1. Ensure zones are defined in Ethovision before export
2. Check zone names contain "light floor" or "door area"
3. Verify export includes zone data

## Advanced Usage

### Custom Zone Selection

```r
# Load with specific body part
ld_data <- load_ld_data("file.xlsx",
                        fps = 25,
                        body_part = "Nose-point")  # Instead of Center-point
```

### Manual Zone Analysis

```r
# Access raw data
df <- ld_data$Arena_1$data

# Custom zone metric
frames_in_door <- sum(df$zone_door_area == 1)
door_time <- frames_in_door / 25  # If fps = 25

# Custom distance calculation
library(dplyr)
door_distance <- df %>%
  filter(zone_door_area == 1) %>%
  mutate(dist = sqrt(diff(c(NA, x_center))^2 + diff(c(NA, y_center))^2)) %>%
  summarize(total = sum(dist, na.rm = TRUE))
```

### Visualize Specific Arena

```r
arena1 <- ld_data$Arena_1

# Custom trajectory plot
plot_trajectory(arena1$data$x_center,
                arena1$data$y_center,
                color_by = "zone",
                zone_data = arena1$data$zone_light_floor,
                title = "Arena 1 Movement Pattern")
```

## Getting Help

- View function documentation: `?load_ld_data`
- Run example script: `Rscript examples/test_ld_pipeline.R`
- Check test file: `tests/testthat/test-ld-pipeline.R`
- Read full documentation: `PHASE1_SUMMARY.md`

## Tips for Success

1. **Always use conda environment**: `conda activate r`
2. **Check fps value**: Typically 25 for Ethovision
3. **Validate data first**: Use `validate_ld_data()` before analysis
4. **Save intermediate results**: Export CSVs at each step
5. **Check zone coverage**: Time in light + dark may not equal 100% (door area)
6. **Inspect plots**: Visual check for data quality issues
7. **Use meaningful subject IDs**: Helps with data organization

## Example Workflow

```r
# Complete analysis workflow
setwd("/mnt/g/Bella/Rebecca/Code/DLCAnalyzer")

# 1. Load functions
source("R/common/io.R")
source("R/common/geometry.R")
source("R/common/plotting.R")
source("R/ld/ld_load.R")
source("R/ld/ld_analysis.R")
source("R/ld/ld_report.R")

# 2. Load and validate data
ld_data <- load_ld_data("data/LD/your_file.xlsx", fps = 25)
validate_ld_data(ld_data)

# 3. Quick check
summary <- summarize_ld_data(ld_data)
print(summary)

# 4. Analyze
results <- analyze_ld_batch(ld_data, fps = 25)

# 5. Export and visualize
export_ld_results(results, "output/results.csv", overwrite = TRUE)
generate_ld_batch_report(ld_data, output_dir = "output/reports")

# 6. Review outputs
cat("\nAnalysis complete! Check outputs in:\n")
cat("  - output/results.csv\n")
cat("  - output/reports/\n")
```

## Need More Help?

Check the full implementation summary: [PHASE1_SUMMARY.md](PHASE1_SUMMARY.md)
