# EPM Pipeline Implementation - TODO List

**Phase:** 4
**Paradigm:** EPM (Elevated Plus Maze)
**Estimated Time:** 3-4 hours
**Date Started:** TBD

---

## 🎯 Overview

Implement EPM pipeline that:
- ✅ Uses existing DLC CSV functions (don't reinvent!)
- ✅ Converts pixel coordinates to cm
- ✅ Calculates zones from geometry
- ✅ Matches LD/OFT/NORT output format
- ✅ Cleans up legacy/duplicate code

---

## 📋 Pre-Implementation Tasks

### [ ] Task 0: Audit Existing Code (30 min)

**Purpose:** Identify what we can reuse before writing new code

```bash
# 0.1 Find CSV readers
grep -r "read.*csv\|read\.csv" R/core/ R/legacy/ R/utils/

# 0.2 Find pixel conversion
grep -r "pixel" R/ --include="*.R"

# 0.3 Find likelihood filtering
grep -r "likelihood\|filter_low" R/core/

# 0.4 Check preprocessing functions
cat R/core/preprocessing.R | head -100
```

**Deliverables:**
- [ ] List of reusable CSV reading functions
- [ ] List of coordinate conversion utilities
- [ ] List of preprocessing/filtering functions
- [ ] Decision: which functions to import vs rewrite

**Questions:**
- Do we have a standard DLC CSV reader?
- Is there pixel-to-cm conversion code?
- What likelihood threshold is used elsewhere?

---

## 📂 Task 1: Locate and Inspect EPM Data (15 min)

### [ ] Task 1.1: Find EPM Files

```bash
cd /mnt/g/Bella/Rebecca/Code/DLCAnalyzer

# Find EPM data directory
find data/ -type d -name "*EPM*"

# List CSV files
find data/EPM -name "*.csv" | head -10

# Check directory structure
ls -la data/EPM/Example\ DLC\ Data/
```

**Deliverables:**
- [ ] Path to EPM CSV files confirmed
- [ ] Number of test files identified
- [ ] Directory structure documented

---

### [ ] Task 1.2: Inspect CSV Structure

```bash
# Look at first 30 lines of CSV
head -30 "data/EPM/[first_file].csv"

# Count columns
head -1 "data/EPM/[first_file].csv" | tr ',' '\n' | wc -l

# Check for body parts
head -1 "data/EPM/[first_file].csv" | grep -o "[a-z_]*_x" | sed 's/_x//'
```

**Deliverables:**
- [ ] CSV header structure documented
- [ ] Body parts identified (nose, center, tail, etc.)
- [ ] Column naming pattern understood
- [ ] Number of frames/rows noted

**Questions:**
- How many header rows?
- Which body part(s) to use for analysis?
- Are likelihood columns present?

---

### [ ] Task 1.3: Check Coordinate Ranges

```r
# Quick R script to check ranges
source("R/core/preprocessing.R")  # If has CSV reader

df <- read.csv("data/EPM/.../file.csv", skip = ?)
summary(df$center_x)  # or appropriate body part
summary(df$center_y)

# Estimate arena size in pixels
max_x <- max(df$center_x, na.rm = TRUE)
max_y <- max(df$center_y, na.rm = TRUE)
```

**Deliverables:**
- [ ] Pixel coordinate ranges documented
- [ ] Estimated arena size (pixels)
- [ ] Calibration factor needed (pixels/cm)

---

## 🔧 Task 2: Create R/epm/epm_load.R (60-90 min)

### [ ] Task 2.1: Import Reusable Functions

```r
# At top of epm_load.R
# Source or import functions identified in Task 0

# From R/core/preprocessing.R (if applicable)
# From R/legacy/data_converters.R (if applicable)
# From R/common/io.R (column standardization patterns)
```

**Deliverables:**
- [ ] Necessary imports identified
- [ ] Dependencies documented
- [ ] Roxygen @import tags added

---

### [ ] Task 2.2: Implement load_epm_data()

```r
#' Load EPM data from DLC CSV file
#'
#' @param file_path Character. Path to DLC CSV file
#' @param fps Numeric. Frames per second (default: 25)
#' @param pixels_per_cm Numeric. Pixel-to-cm conversion (default: 10)
#' @param arena_config List. EPM arena dimensions (optional)
#' @param body_part Character. Body part to use (default: "center")
#' @param likelihood_threshold Numeric. Minimum confidence (default: 0.9)
#'
#' @return List with standard format matching LD/OFT/NORT
#'
#' @export
load_epm_data <- function(file_path, fps = 25, pixels_per_cm = 10,
                          arena_config = NULL, body_part = "center",
                          likelihood_threshold = 0.9) {
  # TODO: Implement
  # 1. Read CSV (use existing function if available)
  # 2. Filter by likelihood
  # 3. Convert pixels to cm
  # 4. Calculate arm zones
  # 5. Standardize column names
  # 6. Return in standard format
}
```

**Deliverables:**
- [ ] Function signature defined
- [ ] CSV reading implemented
- [ ] Likelihood filtering applied
- [ ] Pixel-to-cm conversion working
- [ ] Function returns standard format
- [ ] Roxygen documentation complete

**Test:**
```r
epm_data <- load_epm_data("data/EPM/.../file.csv")
str(epm_data)  # Should match LD/OFT/NORT structure
```

---

### [ ] Task 2.3: Implement Zone Calculation

```r
#' Define EPM arm zones from coordinates
#'
#' @param x Numeric vector. X coordinates (in cm)
#' @param y Numeric vector. Y coordinates (in cm)
#' @param arena_config List. Arena dimensions
#'
#' @return Data frame with zone columns:
#'   - zone_open_arms (0/1)
#'   - zone_closed_arms (0/1)
#'   - zone_center (0/1)
#'
#' @keywords internal
define_epm_zones <- function(x, y, arena_config = NULL) {
  # Default EPM geometry if not provided
  if (is.null(arena_config)) {
    arena_config <- list(
      arm_length = 30,   # cm
      arm_width = 5,     # cm
      center_size = 5    # cm
    )
  }

  # TODO: Calculate zone membership
  # North arm (open): y > threshold, |x| < arm_width/2
  # South arm (open): y < -threshold, |x| < arm_width/2
  # East arm (closed): x > threshold, |y| < arm_width/2
  # West arm (closed): x < -threshold, |y| < arm_width/2
  # Center: sqrt(x^2 + y^2) < center_size

  # Return zones
}
```

**Deliverables:**
- [ ] Zone geometry implemented
- [ ] Tested with sample coordinates
- [ ] Returns binary zone vectors
- [ ] No overlapping zones

---

### [ ] Task 2.4: Add Helper Functions

```r
standardize_epm_columns(df)
validate_epm_data(epm_data)
summarize_epm_data(epm_data)
```

**Deliverables:**
- [ ] Column standardization works
- [ ] Validation checks implemented
- [ ] Summary function provides useful stats

---

## 📊 Task 3: Create R/epm/epm_analysis.R (60-90 min)

### [ ] Task 3.1: Implement analyze_epm()

```r
#' Analyze EPM behavioral metrics
#'
#' @param df Data frame. EPM tracking data with zone columns
#' @param fps Numeric. Frames per second (default: 25)
#'
#' @return List with EPM metrics matching LD/OFT/NORT format
#'
#' @export
analyze_epm <- function(df, fps = 25) {
  # Reuse zone calculation functions from R/ld/ld_analysis.R
  # - calculate_zone_time()
  # - detect_zone_entries()
  # - calculate_zone_latency()

  # Calculate EPM-specific metrics
  # - Open arm ratio
  # - Entries ratio
  # - Distance/velocity using R/common/geometry.R

  # Return in standard format
}
```

**Deliverables:**
- [ ] Core analysis function implemented
- [ ] Reuses zone utility functions
- [ ] Calculates anxiety indices
- [ ] Returns standard format
- [ ] Roxygen documentation complete

**Test:**
```r
results <- analyze_epm(epm_data$data, fps = 25)
results$open_arm_ratio  # Should be 0-1
results$entries_ratio   # Should be 0-1
```

---

### [ ] Task 3.2: Implement Anxiety Index Calculations

```r
calculate_open_arm_ratio(time_open, time_closed)
calculate_entries_ratio(entries_open, entries_closed)
```

**Deliverables:**
- [ ] Formulas implemented correctly
- [ ] Edge cases handled (division by zero)
- [ ] Returns values in 0-1 range
- [ ] Unit tests written

---

### [ ] Task 3.3: Implement Batch Processing

```r
analyze_epm_batch(epm_data_list, fps = 25)
export_epm_results(results, output_file)
```

**Deliverables:**
- [ ] Batch analysis works
- [ ] CSV export functions
- [ ] Follows LD/OFT/NORT patterns

---

## 📈 Task 4: Create R/epm/epm_report.R (60-90 min)

### [ ] Task 4.1: Implement generate_epm_report()

```r
generate_epm_report(epm_data, output_dir, subject_id, fps = 25)
```

**Deliverables:**
- [ ] Report generation works
- [ ] Creates all expected files
- [ ] Matches LD/OFT/NORT structure

---

### [ ] Task 4.2: Implement EPM Plots

```r
generate_epm_plots(df, results, subject_id)
  # - Trajectory with arm boundaries
  # - Heatmap
  # - Zone time bar chart
```

**Deliverables:**
- [ ] Trajectory plot shows arm layout
- [ ] Heatmap generated
- [ ] Zone comparison chart created
- [ ] Reuses R/common/plotting.R functions

---

### [ ] Task 4.3: Implement Interpretation

```r
interpret_epm_results(results)
```

**Deliverables:**
- [ ] Anxiety interpretation based on open arm ratio
- [ ] Text summary generated
- [ ] Follows OFT interpretation pattern

---

## 🧪 Task 5: Create Test Suite (60 min)

### [ ] Task 5.1: Unit Tests

```r
# tests/testthat/test-epm-pipeline.R

test_that("EPM data loading works", { ... })
test_that("Pixel-to-cm conversion correct", { ... })
test_that("Zone calculation accurate", { ... })
test_that("Open arm ratio 0-1 range", { ... })
test_that("Entries ratio 0-1 range", { ... })
```

**Deliverables:**
- [ ] 15+ unit tests written
- [ ] All tests pass
- [ ] Edge cases covered

---

### [ ] Task 5.2: Integration Test

```r
test_that("Full EPM pipeline works with real data", {
  epm_data <- load_epm_data("data/EPM/.../file.csv")
  results <- analyze_epm(epm_data$data)
  expect_true(results$open_arm_ratio >= 0 && results$open_arm_ratio <= 1)
  # More assertions...
})
```

**Deliverables:**
- [ ] End-to-end test with real data
- [ ] Output format validated
- [ ] Metrics in expected ranges

---

## 📖 Task 6: Documentation (30 min)

### [ ] Task 6.1: Create examples/test_epm_pipeline.R

```r
# Demo script following LD/OFT/NORT pattern
# Should be runnable and demonstrate all features
```

**Deliverables:**
- [ ] Complete demo script
- [ ] Commented and clear
- [ ] Runs successfully

---

### [ ] Task 6.2: Create QUICKSTART_EPM.md

```markdown
# Quick Start: EPM Analysis

## Key Differences
- CSV format (not Excel)
- Pixel coordinates (converted to cm)
- Zones calculated from geometry

## Example Workflow
[Complete example]
```

**Deliverables:**
- [ ] User guide written
- [ ] Follows LD/OFT/NORT pattern
- [ ] Includes troubleshooting

---

## 🗑️ Task 7: Code Cleanup (30-45 min)

### [ ] Task 7.1: Identify Redundant Code

```bash
# Find duplicate CSV readers
grep -r "read\.csv\|read_csv" R/ --include="*.R" | grep -v test

# Find duplicate pixel conversions
grep -r "pixel\|conversion" R/ --include="*.R"

# Check for unused legacy functions
# Compare with what EPM actually uses
```

**Deliverables:**
- [ ] List of duplicate functions
- [ ] Consolidation plan
- [ ] Functions marked for deprecation

---

### [ ] Task 7.2: Refactor Common Functions

```r
# If found multiple CSV readers, consolidate to:
# R/common/io.R: read_dlc_csv()

# If found multiple pixel converters, consolidate to:
# R/common/geometry.R: pixels_to_cm()
```

**Deliverables:**
- [ ] Common functions extracted
- [ ] All pipelines updated to use them
- [ ] Duplicates removed

---

### [ ] Task 7.3: Update Legacy Code

```r
# Mark deprecated functions
#' @deprecated Use read_dlc_csv() from R/common/io.R instead

# Add deprecation warnings
.Deprecated("read_dlc_csv")
```

**Deliverables:**
- [ ] Legacy functions marked
- [ ] Migration guide for any users
- [ ] Removal timeline documented

---

## ✅ Task 8: Final Integration (30 min)

### [ ] Task 8.1: Update PROJECT_ROADMAP.md

- [ ] Mark Phase 4 (EPM) as complete
- [ ] Update statistics (4 of 7 pipelines)
- [ ] Add EPM achievements

---

### [ ] Task 8.2: Create PHASE4_SUMMARY.md

- [ ] Document EPM implementation
- [ ] Note code cleanup completed
- [ ] List reused vs new code

---

### [ ] Task 8.3: Run Full Test Suite

```bash
# Run all EPM tests
Rscript -e "testthat::test_file('tests/testthat/test-epm-pipeline.R')"

# Run demo
Rscript examples/test_epm_pipeline.R

# Check consistency with other pipelines
Rscript examples/test_ld_pipeline.R
Rscript examples/test_oft_pipeline.R
Rscript examples/test_nort_pipeline.R
```

**Deliverables:**
- [ ] All tests pass
- [ ] Demo runs successfully
- [ ] No regressions in other pipelines

---

## 📊 Success Checklist

Implementation is complete when:

**Core Functionality:**
- [ ] Loads DLC CSV files
- [ ] Converts pixels to cm
- [ ] Calculates arm zones from geometry
- [ ] Computes anxiety indices (open arm ratio, entries ratio)
- [ ] Generates trajectory plots with arm boundaries
- [ ] Creates heatmaps and zone comparison charts
- [ ] Produces text reports with anxiety interpretation

**Code Quality:**
- [ ] Reuses existing functions (doesn't duplicate)
- [ ] Output format matches LD/OFT/NORT
- [ ] Roxygen documentation complete
- [ ] All tests pass (15+ tests)
- [ ] Demo script runs successfully

**Documentation:**
- [ ] QUICKSTART_EPM.md written
- [ ] PHASE4_SUMMARY.md created
- [ ] PROJECT_ROADMAP.md updated
- [ ] Code comments clear

**Cleanup:**
- [ ] Redundant code identified
- [ ] Common functions consolidated
- [ ] Legacy code marked/deprecated

---

## 🎯 Time Estimates by Task

| Task | Estimated Time |
|------|----------------|
| 0. Audit existing code | 30 min |
| 1. Inspect EPM data | 15 min |
| 2. Create epm_load.R | 60-90 min |
| 3. Create epm_analysis.R | 60-90 min |
| 4. Create epm_report.R | 60-90 min |
| 5. Create tests | 60 min |
| 6. Documentation | 30 min |
| 7. Code cleanup | 30-45 min |
| 8. Final integration | 30 min |
| **TOTAL** | **~6-7 hours** |

**Note:** May be faster if existing functions work well!

---

## 🚀 Ready to Start!

Begin with Task 0 (audit existing code) to maximize reuse and minimize new code. The goal is integration and cleanup, not wholesale rewriting.

**First command:**
```bash
cd /mnt/g/Bella/Rebecca/Code/DLCAnalyzer
conda activate r
grep -r "read.*csv" R/core/ R/legacy/ R/utils/
```

Good luck! 🎯
