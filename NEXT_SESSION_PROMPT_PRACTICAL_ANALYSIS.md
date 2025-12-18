# AI Agent Starting Prompt - Practical Analysis & Cleanup Session

## Copy and paste this prompt to start your session:

---

Hello! I'm continuing the DLCAnalyzer R package development. This is a behavioral analysis tool that processes tracking data from **DeepLabCut (CSV)** and **Ethovision XT (Excel)**.

**Project Location**: `/mnt/g/Bella/Rebecca/Code/DLCAnalyzer`

**Current Status**: Core infrastructure is complete. Now we need to make it **PRACTICALLY USABLE** with real data.

**Your Task**: Create analysis workflows, test with real data, clean up codebase, and prepare for actual use.

---

## What's Already Complete ✅

### Phase 1: Foundation (100%)
- S3 data structures (`tracking_data`, `arena_config`)
- Data loading for **CSV (DLC)** and **Excel (Ethovision)**
- YAML arena configuration system
- Coordinate transformations
- **537+ unit tests passing**

### Phase 2: Core Analysis (40%)
**Completed:**
- ✅ Preprocessing (filtering, interpolation, smoothing)
- ✅ Quality checks (outliers, missing data)
- ✅ Zone analysis (occupancy, entries, exits, latency, transitions)
- ✅ Movement metrics (distance, velocity, acceleration, bouts)
- ✅ Reporting system (HTML reports with plots)
- ✅ Group comparisons (statistical tests, effect sizes)

**Still Needed:**
- Freezing detection
- Additional behavioral metrics
- Paradigm-specific workflows

### Test Data Available

**EPM (Elevated Plus Maze):**
- Format: CSV (DeepLabCut)
- Files: 4 subjects (ID7689, ID7693, ID7694, ID7697)
- Location: `data/EPM/Example DLC Data/*.csv`
- Arena config: `config/arena_definitions/EPM/EPM.yaml` ✅

**OFT (Open Field Test):**
- Format: Excel (Ethovision)
- Files: 3 trials
- Location: `data/OFT/Example Exported Data/*.xlsx`
- Arena config: `config/arena_definitions/OF/` (may need adjustment)

**NORT (Novel Object Recognition):**
- Format: Excel (Ethovision)
- Files: 4 trials
- Location: `data/NORT/Example Exported Data/*.xlsx`
- Arena config: `config/arena_definitions/NORT/` (may need adjustment)

**LD (Light/Dark Box):**
- Format: Excel (Ethovision)
- Files: 3 trials
- Location: `data/LD/Example Exported Data/*.xlsx`
- Arena config: `config/arena_definitions/LD/` (may need adjustment)

---

## Your Tasks - Priority Order

### 🎯 PRIORITY 1: Create Practical Analysis Scripts (START HERE!)

Create user-friendly scripts that researchers can run to analyze their data.

#### Task 1.1: Single Subject Analysis Script

**File to create**: `workflows/analyze_single_subject.R`

This script should:
1. Load tracking data (auto-detect CSV or Excel)
2. Load arena configuration
3. Calculate all metrics (quality, zones, movement)
4. Generate comprehensive HTML report with plots
5. Save metrics to CSV

**Template**:
```r
#!/usr/bin/env Rscript
# workflows/analyze_single_subject.R
# Analyze a single subject and generate comprehensive report

# Usage:
#   Rscript workflows/analyze_single_subject.R <data_file> <arena_config> <output_dir>
#
# Example:
#   Rscript workflows/analyze_single_subject.R \
#     "data/EPM/Example DLC Data/ID7689_*.csv" \
#     "config/arena_definitions/EPM/EPM.yaml" \
#     "results/EPM/ID7689"

# Load all DLCAnalyzer functions
source("R/core/data_structures.R")
source("R/core/data_loading.R")
source("R/core/data_converters.R")
source("R/core/arena_config.R")
source("R/core/zone_geometry.R")
source("R/core/preprocessing.R")
source("R/core/quality_checks.R")
source("R/metrics/zone_analysis.R")
source("R/metrics/movement_metrics.R")
source("R/metrics/time_in_zone.R")
source("R/reporting/generate_report.R")
source("R/visualization/plot_tracking.R")
source("R/utils/config_utils.R")

# Parse command line arguments
args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 3) {
  cat("Usage: Rscript analyze_single_subject.R <data_file> <arena_config> <output_dir>\n")
  quit(status = 1)
}

data_file <- args[1]
arena_file <- args[2]
output_dir <- args[3]

# Step 1: Load data (auto-detect format)
cat("\n=== DLCAnalyzer: Single Subject Analysis ===\n\n")
cat("Step 1: Loading tracking data...\n")

if (grepl("\\.csv$", data_file, ignore.case = TRUE)) {
  # DeepLabCut CSV
  tracking_data <- convert_dlc_to_tracking_data(data_file, fps = 30)
} else if (grepl("\\.xlsx?$", data_file, ignore.case = TRUE)) {
  # Ethovision Excel
  tracking_data <- convert_ethovision_to_tracking_data(data_file, fps = 25)
} else {
  stop("Unsupported file format. Use .csv (DLC) or .xlsx (Ethovision)")
}

cat("  ✓ Loaded", nrow(tracking_data$tracking), "frames\n")

# Step 2: Load arena
cat("\nStep 2: Loading arena configuration...\n")
arena <- load_arena_configs(arena_file, arena_id = "arena1")
cat("  ✓ Arena:", arena$id, "\n")
cat("  ✓ Zones:", paste(names(arena$zones), collapse = ", "), "\n")

# Step 3: Generate report
cat("\nStep 3: Generating comprehensive report...\n")
report <- generate_subject_report(
  tracking_data,
  arena,
  output_dir = output_dir,
  body_part = "mouse_center",  # or "Center-point" for Ethovision
  format = "html",
  scale_factor = 10  # 10 pixels/cm, adjust as needed
)

cat("\n=== Analysis Complete! ===\n")
cat("Output directory:", output_dir, "\n")
cat("View report:", file.path(output_dir, paste0(tracking_data$metadata$subject_id, "_report.html")), "\n\n")
```

**Test it with**:
```bash
Rscript workflows/analyze_single_subject.R \
  "data/EPM/Example DLC Data/ID7689_*.csv" \
  "config/arena_definitions/EPM/EPM.yaml" \
  "results/EPM/ID7689"
```

---

#### Task 1.2: Batch Analysis Script

**File to create**: `workflows/analyze_batch.R`

Analyze multiple subjects in one paradigm and create group comparisons.

**Features**:
- Process all files in a directory
- Generate individual reports for each subject
- Create group comparison report
- Export combined metrics CSV

**Template structure**:
```r
# 1. Find all data files in directory
# 2. Loop through each file:
#    - Load and analyze
#    - Generate individual report
#    - Collect metrics
# 3. Perform group comparisons
# 4. Generate group summary report
```

---

#### Task 1.3: Paradigm-Specific Scripts

Create quick-start scripts for each paradigm:

**Files to create**:
1. `workflows/analyze_epm.R` - EPM-specific with anxiety metrics
2. `workflows/analyze_oft.R` - OFT-specific with center vs periphery
3. `workflows/analyze_nort.R` - NORT-specific with object zones
4. `workflows/analyze_ld.R` - LD-specific with light/dark preference

Each should:
- Have paradigm-specific default settings
- Use appropriate arena config
- Calculate paradigm-specific metrics
- Generate paradigm-appropriate plots

---

### 🎯 PRIORITY 2: Test with Real Data

#### Task 2.1: Test EPM Analysis

Run full analysis on all 4 EPM subjects:
```bash
# Test with DLC CSV data
for file in data/EPM/Example\ DLC\ Data/*.csv; do
  subject_id=$(basename "$file" | cut -d'_' -f1)
  Rscript workflows/analyze_single_subject.R \
    "$file" \
    "config/arena_definitions/EPM/EPM.yaml" \
    "results/EPM/$subject_id"
done
```

**Verify**:
- All reports generate successfully
- Plots display correctly
- Metrics are reasonable (distance, velocity, zone times)
- No errors or warnings

---

#### Task 2.2: Test Ethovision Excel Loading

Test with OFT, NORT, and LD Excel files:

```r
# Test Ethovision loading
library(readxl)

# Test OFT
oft_file <- "data/OFT/Example Exported Data/Raw data-Rebecca OF Oct20th2025-Trial     1.xlsx"
oft_data <- convert_ethovision_to_tracking_data(oft_file, fps = 25, paradigm = "open_field")

# Verify structure
str(oft_data)
summary(oft_data)

# Test with analysis workflow
# ... run through analyze_single_subject.R
```

**Fix any issues** with:
- Sheet detection
- Column name variations
- Coordinate systems
- Missing data handling

---

#### Task 2.3: Verify Arena Configurations

Check all arena configs match actual data:

```r
# For each paradigm:
# 1. Load sample data
# 2. Load arena config
# 3. Plot coordinates with zone overlays
# 4. Verify zones align with actual arena

# Example verification script
tracking_data <- convert_dlc_to_tracking_data("data/EPM/Example DLC Data/ID7689_*.csv", fps = 30)
arena <- load_arena_configs("config/arena_definitions/EPM/EPM.yaml", arena_id = "arena1")

# Plot to verify
library(ggplot2)
track_sample <- tracking_data$tracking[tracking_data$tracking$body_part == "mouse_center", ]
track_sample <- track_sample[seq(1, nrow(track_sample), by = 100), ]  # Downsample

ggplot(track_sample, aes(x = x, y = y)) +
  geom_path(alpha = 0.3) +
  geom_point(size = 0.5) +
  coord_fixed() +
  ggtitle("Verify arena zones align with tracking data")

# Add zone boundaries manually and check alignment
```

---

### 🎯 PRIORITY 3: Clean Up Codebase

#### Task 3.1: Remove Temporary Files

Delete or move to archive:
```bash
# Session prompts (keep latest only)
rm NEXT_SESSION_PROMPT.md
rm NEXT_SESSION_PROMPT_TASK_2.7-2.13.md
mv SESSION_SUMMARY_*.md archive/

# Test files in root (move to tests/)
mv test_preprocessing_real_data.R tests/

# Reports from testing (optional: delete or archive)
# rm -rf reports/test_*
```

**Create**: `archive/` directory for old session documents

---

#### Task 3.2: Update Documentation

**Files to update**:

1. **docs/REFACTORING_TODO.md**
   - Mark Tasks 2.2, 2.10, 2.11, 2.12 as [x] Complete
   - Update Phase 2 progress: ~40% complete
   - Add new section for practical workflows

2. **README.md** (create if doesn't exist)
   - Project overview
   - Quick start guide
   - Installation instructions
   - Example usage
   - Available paradigms

3. **docs/USER_GUIDE.md** (create)
   - How to analyze single subject
   - How to batch analyze
   - How to interpret reports
   - Troubleshooting common issues

---

#### Task 3.3: Create Package Structure

Prepare for R package installation:

**Files to create/update**:

1. **DESCRIPTION** file:
```
Package: DLCAnalyzer
Title: Behavioral Analysis for DeepLabCut and Ethovision Data
Version: 0.5.0
Authors@R: person("Rebecca", "Bella", email = "...", role = c("aut", "cre"))
Description: Analyze animal tracking data from DeepLabCut and Ethovision XT.
    Supports multiple behavioral paradigms including EPM, OFT, NORT, LD, and FST.
License: MIT
Depends: R (>= 4.0)
Imports:
    yaml,
    readxl,
    ggplot2
Suggests:
    testthat,
    rmarkdown,
    knitr
```

2. **NAMESPACE** file (or use roxygen2)

3. **man/** directory for documentation

---

### 🎯 PRIORITY 4: Create Quick Reference

#### Task 4.1: Cheat Sheet

**File to create**: `docs/CHEAT_SHEET.md`

```markdown
# DLCAnalyzer Quick Reference

## Analyze Single Subject
```bash
Rscript workflows/analyze_single_subject.R <data_file> <arena_config> <output_dir>
```

## Analyze Multiple Subjects
```bash
Rscript workflows/analyze_batch.R <data_directory> <arena_config> <output_dir>
```

## Key Functions

### Data Loading
- `convert_dlc_to_tracking_data()` - Load DeepLabCut CSV
- `convert_ethovision_to_tracking_data()` - Load Ethovision Excel
- `load_arena_configs()` - Load arena configuration

### Analysis
- `calculate_zone_occupancy()` - Time in each zone
- `calculate_distance_traveled()` - Total distance
- `calculate_velocity()` - Speed over time
- `detect_movement_bouts()` - Movement vs immobility

### Reporting
- `generate_subject_report()` - Individual report
- `generate_group_report()` - Group comparison
- `compare_groups()` - Statistical tests

## Output Files
- `*_report.html` - Interactive report
- `*_metrics.csv` - All metrics
- `plots/*.png` - Visualizations
```

---

## Success Criteria

### ✅ Session Complete When:

1. **Practical Workflows Created**
   - [ ] `analyze_single_subject.R` works with both CSV and Excel
   - [ ] `analyze_batch.R` processes multiple files
   - [ ] Paradigm-specific scripts exist for EPM, OFT, NORT, LD

2. **Real Data Testing**
   - [ ] All 4 EPM subjects analyzed successfully
   - [ ] At least 1 Excel file (Ethovision) analyzed successfully
   - [ ] Reports generate correctly with plots
   - [ ] Metrics are biologically reasonable

3. **Cleanup Complete**
   - [ ] Temporary files removed or archived
   - [ ] Documentation updated (TODO, README, USER_GUIDE)
   - [ ] Git history is clean

4. **Ready for Use**
   - [ ] User can run analysis with single command
   - [ ] Cheat sheet provides quick reference
   - [ ] Error messages are helpful

---

## Quick Start Commands

```bash
# Set environment
cd /mnt/g/Bella/Rebecca/Code/DLCAnalyzer
export PATH="/home/paul/miniforge3/envs/r/bin:$PATH"

# Test single subject analysis
Rscript workflows/analyze_single_subject.R \
  "data/EPM/Example DLC Data/ID7689_superanimal_topviewmouse_snapshot-hrnet_w32-004_snapshot-fasterrcnn_resnet50_fpn_v2-004__filtered.csv" \
  "config/arena_definitions/EPM/EPM.yaml" \
  "results/EPM/ID7689_test"

# Check output
ls -la results/EPM/ID7689_test/
cat results/EPM/ID7689_test/ID7689_metrics.csv
```

---

## Known Issues to Address

1. **plot_comparisons.R syntax error** - Fix or remove
2. **Some unit tests failing** (10 failures in arena_config, coordinate_transforms, data_converters)
3. **Arena configs** may need adjustment for Ethovision data
4. **Body part names** differ between DLC ("mouse_center") and Ethovision ("Center-point")

---

## Package Dependencies

Ensure these are installed:
```r
install.packages(c("yaml", "readxl", "ggplot2", "testthat", "rmarkdown", "knitr"))
```

---

**Focus**: Make DLCAnalyzer **immediately usable** by researchers. They should be able to:
1. Drop in their data files (CSV or Excel)
2. Run a single command
3. Get comprehensive HTML reports with publication-ready plots

**Philosophy**: Prioritize practical utility over perfect code. Get it working, then refine.

---

**Document Version**: 1.0
**Created**: December 18, 2024
**Session Focus**: Practical Analysis & Real Data Testing
