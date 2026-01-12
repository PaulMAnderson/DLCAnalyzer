# Quick Start: EPM (Elevated Plus Maze) Analysis

**DLCAnalyzer Phase 4 - EPM Pipeline**

This guide provides a quick introduction to analyzing EPM behavioral data using the DLCAnalyzer package.

---

## Table of Contents

1. [Key Differences from Other Paradigms](#key-differences)
2. [Installation](#installation)
3. [Quick Example](#quick-example)
4. [Data Requirements](#data-requirements)
5. [Core Functions](#core-functions)
6. [Key Metrics](#key-metrics)
7. [Complete Workflow](#complete-workflow)
8. [Arena Calibration](#arena-calibration)
9. [Quality Control](#quality-control)
10. [Batch Processing](#batch-processing)
11. [Troubleshooting](#troubleshooting)

---

## Key Differences from Other Paradigms {#key-differences}

**EPM uses a different data format than LD/OFT/NORT:**

| Feature | LD/OFT/NORT | EPM |
|---------|-------------|-----|
| **Input Format** | Ethovision Excel (.xlsx) | DeepLabCut CSV (.csv) |
| **Coordinates** | Centimeters (pre-converted) | Pixels (requires conversion) |
| **Zones** | Pre-computed zone columns | Calculated from geometry |
| **Likelihood** | Always 1.0 (assumed perfect) | 0-1 confidence scores |
| **Data Loader** | `read_ethovision_excel()` | `read_dlc_csv()` |

**Why CSV instead of Excel?**
EPM data comes from DeepLabCut video analysis, which outputs CSV files with frame-by-frame tracking coordinates and confidence scores.

---

## Installation {#installation}

```r
# Install DLCAnalyzer (adjust path as needed)
devtools::install_github("username/DLCAnalyzer")

# Or load during development
source("R/core/data_loading.R")
source("R/core/coordinate_transforms.R")
source("R/ld/ld_analysis.R")  # For zone calculation functions
source("R/epm/epm_load.R")
source("R/epm/epm_analysis.R")
source("R/epm/epm_report.R")

# Required packages
library(ggplot2)  # For plotting
```

---

## Quick Example {#quick-example}

```r
# Load EPM data
epm_data <- load_epm_data(
  file_path = "data/EPM/ID7687_DLC_output.csv",
  fps = 25,
  pixels_per_cm = 5.3  # IMPORTANT: Calibrate for your setup
)

# Analyze behavioral metrics
results <- analyze_epm(epm_data)

# View results
print_epm_results(results, subject_id = "ID7687")

# Key anxiety index (lower = more anxiety)
print(results$open_arm_ratio)  # e.g., 0.35

# Generate report with plots
generate_epm_report(
  epm_data,
  output_dir = "output/EPM_ID7687",
  subject_id = "ID7687"
)
```

**That's it!** You now have anxiety metrics and visualization plots.

---

## Data Requirements {#data-requirements}

### Input File Format

EPM pipeline requires **DeepLabCut CSV files** with this structure:

```
scorer,DLC_model_name,...
bodyparts,nose,nose,nose,mouse_center,mouse_center,mouse_center,...
coords,x,y,likelihood,x,y,likelihood,...
0,245.3,412.7,0.95,280.1,450.2,0.98,...
1,246.1,413.2,0.96,281.0,451.1,0.99,...
...
```

**Required columns:**
- Row 1: Scorer info
- Row 2: Body part names
- Row 3: Coordinate types (x, y, likelihood)
- Row 4+: Frame-by-frame tracking data

**Recommended body parts:** `mouse_center`, `center`, `body_center`, or equivalent

---

## Core Functions {#core-functions}

### 1. `load_epm_data()` - Load and Prepare Data

```r
epm_data <- load_epm_data(
  file_path = "path/to/dlc_output.csv",
  fps = 25,                      # Frames per second
  pixels_per_cm = 5.3,           # Calibration factor (CRITICAL!)
  arena_config = NULL,           # Use default EPM geometry
  body_part = "mouse_center",    # Body part to track
  likelihood_threshold = 0.9     # Filter low-confidence points
)
```

**What it does:**
- Reads DLC CSV file
- Converts pixels to cm
- Filters low-confidence tracking points
- Calculates arm zones from geometry
- Centers coordinates
- Returns standardized format

### 2. `analyze_epm()` - Calculate Behavioral Metrics

```r
results <- analyze_epm(
  epm_data,
  fps = 25,              # Optional if already in epm_data
  min_exploration = 5    # Minimum arm entries for reliable results
)
```

**Returns anxiety indices and activity metrics** (see [Key Metrics](#key-metrics))

### 3. `generate_epm_report()` - Create Visualizations

```r
report_files <- generate_epm_report(
  epm_data,
  output_dir = "output/EPM_reports",
  subject_id = "ID7687"
)
```

**Generates:**
- Trajectory plot with arm boundaries
- Position heatmap
- Zone occupancy bar chart
- Metrics CSV
- Summary text report

---

## Key Metrics {#key-metrics}

### Primary Anxiety Indices

#### 1. **Open Arm Ratio** (Most Important)

```r
open_arm_ratio = time_in_open_arms / (time_in_open_arms + time_in_closed_arms)
```

**Interpretation:**
- **< 0.15**: High anxiety
- **0.15 - 0.25**: Moderate-high anxiety
- **0.25 - 0.40**: Moderate anxiety
- **0.40 - 0.55**: Moderate-low anxiety
- **> 0.55**: Low anxiety

**Why it matters:** Anxious animals avoid open arms (prefer closed arms with walls). This ratio quantifies anxiety-like behavior.

#### 2. **Entries Ratio** (Secondary Index)

```r
entries_ratio = entries_to_open_arms / (entries_to_open_arms + entries_to_closed_arms)
```

Similar interpretation to open arm ratio. Complements time-based measure with entry-based measure.

### Other Metrics

- **Time in zones**: Seconds and percentages in open/closed/center
- **Entry counts**: Number of entries into each zone
- **Latency**: Time to first open arm entry
- **Locomotor activity**: Total distance, velocity, distance per zone

### Minimum Exploration Criterion

**⚠️ Important:** Requires **≥ 5 total arm entries** for reliable anxiety assessment.

If exploration < 5 entries:
- Results flagged as unreliable
- May indicate procedural issues or extreme anxiety

---

## Complete Workflow {#complete-workflow}

### Single Subject Analysis

```r
# 1. Load data
epm_data <- load_epm_data(
  "data/EPM/ID7687_DLC.csv",
  fps = 25,
  pixels_per_cm = 5.3
)

# 2. Check data quality
summarize_epm_data(epm_data)

# 3. Analyze metrics
results <- analyze_epm(epm_data)

# 4. Print results
print_epm_results(results, subject_id = "ID7687")

# 5. Interpret anxiety
anxiety_level <- interpret_epm_anxiety(
  results$open_arm_ratio,
  results$entries_ratio,
  results$total_arm_entries
)
print(anxiety_level)  # e.g., "Moderate anxiety"

# 6. Generate report
generate_epm_report(
  epm_data,
  output_dir = "output/EPM_ID7687",
  subject_id = "ID7687"
)
```

---

## Arena Calibration {#arena-calibration}

### Critical: Pixels per CM

**The most important parameter is `pixels_per_cm`** - this converts pixel coordinates from DeepLabCut into centimeters.

#### Method 1: Measure from Known Distance

```r
# If you know the arena dimensions:
# Example: EPM arm is 40 cm and spans 212 pixels in video
pixels_per_cm <- 212 / 40  # = 5.3
```

#### Method 2: Use Reference Points

```r
# Measure two points with known distance
# Example: Two corners of center platform are 10 cm apart, 53 pixels in video
pixels_per_cm <- 53 / 10  # = 5.3
```

#### Method 3: Check After Loading

```r
# Load data and check coordinate ranges
epm_data <- load_epm_data("file.csv", pixels_per_cm = 5.3)

# After centering, arms should extend ~40 cm from center
range(epm_data$data$x)  # Should be approximately [-40, 40]
range(epm_data$data$y)  # Should be approximately [-40, 40]

# If ranges are wrong, adjust pixels_per_cm
```

### Custom Arena Dimensions

If your EPM has non-standard dimensions:

```r
custom_arena <- list(
  arm_length = 35,      # cm (shorter than standard 40)
  arm_width = 6,        # cm (wider than standard 5)
  center_size = 8,      # cm (smaller than standard 10)
  open_arms = c("north", "south"),
  closed_arms = c("east", "west")
)

epm_data <- load_epm_data(
  "file.csv",
  fps = 25,
  pixels_per_cm = 5.3,
  arena_config = custom_arena
)
```

---

## Quality Control {#quality-control}

### Check Tracking Quality

```r
# Mean likelihood should be > 0.9
mean(epm_data$data$likelihood, na.rm = TRUE)

# Percentage of low-confidence points
sum(epm_data$data$likelihood < 0.9, na.rm = TRUE) / nrow(epm_data$data) * 100
```

**If tracking quality is poor:**
- Retrain DLC model with more labeled frames
- Adjust likelihood threshold: `likelihood_threshold = 0.85`
- Check video quality (lighting, resolution, contrast)

### Check Exploration

```r
results <- analyze_epm(epm_data)

# Should have ≥ 5 arm entries
if (results$total_arm_entries < 5) {
  warning("Low exploration - results may not be reliable")
}

# Check if animal never entered open arms
if (results$entries_to_open == 0) {
  warning("Never entered open arms - extreme anxiety or procedural issue")
}
```

### Check Zone Assignment

```r
# Most time should be in defined zones
pct_in_zones <- results$pct_time_in_open +
                results$pct_time_in_closed +
                results$pct_time_in_center

if (pct_in_zones < 90) {
  warning("Only ", round(pct_in_zones, 1), "% of time in defined zones")
  warning("Check pixels_per_cm and arena_config settings")
}
```

---

## Batch Processing {#batch-processing}

### Analyze Multiple Subjects

```r
# Get all CSV files
csv_files <- list.files("data/EPM", pattern = "\\.csv$", full.names = TRUE)

# Load all subjects
epm_data_list <- lapply(csv_files, function(file) {
  load_epm_data(file, fps = 25, pixels_per_cm = 5.3)
})

# Name by subject ID
names(epm_data_list) <- sapply(epm_data_list, function(x) x$subject_id)

# Analyze batch
batch_results <- analyze_epm_batch(epm_data_list)

# View results table
print(batch_results)

# Export to CSV
export_epm_results(batch_results, "output/EPM_batch_results.csv")

# Generate individual reports
generate_epm_batch_report(
  epm_data_list,
  output_dir = "output/EPM_batch"
)
```

### Group Comparisons

```r
# Example: Compare treatment groups
control <- batch_results[batch_results$subject_id %in% c("ID7687", "ID7688", "ID7689"), ]
treatment <- batch_results[batch_results$subject_id %in% c("ID7690", "ID7691"), ]

# Compare open arm ratios
mean(control$open_arm_ratio)
mean(treatment$open_arm_ratio)

# Statistical test
t.test(control$open_arm_ratio, treatment$open_arm_ratio)
```

---

## Troubleshooting {#troubleshooting}

### Problem: Coordinates Are Way Too Large/Small

**Cause:** Incorrect `pixels_per_cm`

**Solution:**
```r
# Check coordinate ranges after loading
range(epm_data$data$x)  # Should be roughly [-40, 40] for standard EPM

# Adjust pixels_per_cm
# If ranges are too large (e.g., [-200, 200]), pixels_per_cm is too small
# If ranges are too small (e.g., [-5, 5]), pixels_per_cm is too large
```

### Problem: Most Time Spent "Outside" Defined Zones

**Cause:** Arena dimensions don't match actual maze

**Solution:**
```r
# Check actual dimensions of your EPM
# Adjust arena_config
custom_arena <- list(
  arm_length = 35,  # Measure your actual arm length
  arm_width = 6,    # Measure your actual arm width
  center_size = 8   # Measure your actual center diameter
)

epm_data <- load_epm_data("file.csv", arena_config = custom_arena)
```

### Problem: Body Part Not Found

**Error:** `Body part 'mouse_center' not found`

**Solution:**
```r
# Check available body parts
dlc_raw <- read_dlc_csv("file.csv")
get_dlc_bodyparts(dlc_raw)

# Use an available body part
epm_data <- load_epm_data("file.csv", body_part = "center")
```

### Problem: Low Likelihood / Many Filtered Points

**Cause:** Poor tracking quality from DLC

**Solution:**
```r
# Option 1: Lower threshold
epm_data <- load_epm_data("file.csv", likelihood_threshold = 0.85)

# Option 2: Check specific body part quality
dlc_raw <- read_dlc_csv("file.csv")
summarize_dlc_tracking(dlc_raw)  # Shows likelihood per body part

# Option 3: Retrain DLC model with more labeled frames
```

### Problem: Open Arm Ratio is NA

**Cause:** Animal never entered any arms (stayed in center or outside)

**Check:**
```r
results$entries_to_open   # Should be > 0
results$entries_to_closed # Should be > 0

# If both are 0, animal didn't explore
# Check video - was animal placed correctly? Was it moving?
```

---

## Advanced Usage

### Access Raw Zone Vectors

```r
# Get frame-by-frame zone membership
df <- epm_data$data

# Points where animal was in open arms
open_frames <- df$frame[df$zone_open_arms == 1]

# Specific arm occupancy
north_frames <- df$frame[df$arm_id == "north"]
```

### Custom Metric Calculations

```r
# Calculate velocity over time
df$velocity <- c(NA, sqrt(diff(df$x)^2 + diff(df$y)^2) * epm_data$fps)

# Identify high-velocity periods (e.g., running)
running_threshold <- 20  # cm/s
df$running <- df$velocity > running_threshold

# Count running bouts in open vs closed arms
sum(df$running & df$zone_open_arms == 1, na.rm = TRUE)
sum(df$running & df$zone_closed_arms == 1, na.rm = TRUE)
```

---

## Key References

**EPM Anxiety Literature:**
- Rodgers & Dalvi (1997). "Anxiety, defence and the elevated plus-maze." *Neuroscience & Biobehavioral Reviews*, 21(6), 801-810.
- Walf & Frye (2007). "The use of the elevated plus maze as an assay of anxiety-related behavior in rodents." *Nature Protocols*, 2(2), 322-328.

**Typical EPM Parameters:**
- **Trial duration:** 5-10 minutes
- **Open arm ratio:** 0.25-0.40 for untreated mice (moderate anxiety)
- **Minimum exploration:** ≥ 5 total arm entries
- **Frame rate:** 25-30 fps typical for video analysis

---

## Summary Checklist

Before analyzing EPM data, ensure:

- [x] DLC CSV files are available
- [x] `pixels_per_cm` is calibrated for your setup
- [x] Arena dimensions match your EPM
- [x] Body part is reliably tracked (mean likelihood > 0.9)
- [x] Trials are 5-10 minutes duration
- [x] Animals explore sufficiently (≥ 5 arm entries)

---

## Getting Help

**Documentation:**
- See `?load_epm_data` for function help
- See `?analyze_epm` for metrics details
- See `?generate_epm_report` for plotting options

**Example Script:**
```r
# Run complete demo
source("examples/test_epm_pipeline.R")
```

**Common Issues:**
- Coordinate scaling → Adjust `pixels_per_cm`
- Zone assignment → Adjust `arena_config`
- Tracking quality → Lower `likelihood_threshold` or retrain DLC

---

**Need more help?** Check the main project documentation or open an issue on GitHub.
