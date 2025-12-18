# AI Agent Starting Prompt for DLCAnalyzer - Session 5

## Copy and paste this prompt to start your session:

---

Hello! I'm continuing the DLCAnalyzer R package refactoring. This is a behavioral analysis tool for processing animal tracking data from DeepLabCut.

**Project Location**: `/mnt/g/Bella/Rebecca/Code/DLCAnalyzer`

**Current Status**: Phase 2 Tasks 2.5 & 2.6 Complete (Zone Analysis and Time in Zone)
**Your Task**: Implement infrastructure improvements and reporting system (Tasks 2.7-2.13)

## What's Already Complete

### ✅ Phase 1: Foundation (COMPLETE)
- Directory structure created
- `tracking_data` S3 class fully implemented ([R/core/data_structures.R](R/core/data_structures.R:1))
- DLC data loading and conversion ([R/core/data_loading.R](R/core/data_loading.R:1), [R/core/data_converters.R](R/core/data_converters.R:1))
- YAML configuration system ([R/utils/config_utils.R](R/utils/config_utils.R:1))
- Testing framework: 126 unit tests passing

### ✅ Phase 1.5: Arena Configuration System (COMPLETE)
- Arena configuration S3 class ([R/core/arena_config.R](R/core/arena_config.R:1))
- Zone geometry system ([R/core/zone_geometry.R](R/core/zone_geometry.R:1))
  - `create_zone_geometry()` - Creates zone from arena definition
  - `point_in_zone()` - Tests if x,y coordinates are inside zone
  - Support for polygon, circle, rectangle, and proportional zones
- Coordinate transformations ([R/core/coordinate_transforms.R](R/core/coordinate_transforms.R:1))
- 62 unit tests, all passing

### ✅ Phase 2 Task 2.1: Preprocessing Functions (COMPLETE)
- Likelihood filtering, interpolation, smoothing ([R/core/preprocessing.R](R/core/preprocessing.R:1))
- 57 unit tests, all passing

### ✅ Phase 2 Task 2.3: Quality Check Functions (COMPLETE)
- Quality assessment, outlier detection, missing data analysis ([R/core/quality_checks.R](R/core/quality_checks.R:1))
- 130 unit tests, all passing

### ✅ Phase 2 Tasks 2.5 & 2.6: Zone Analysis and Time in Zone (COMPLETE)
- **Zone Analysis** ([R/metrics/zone_analysis.R](R/metrics/zone_analysis.R:1))
  - `classify_points_by_zone()` - Classifies points into zones
  - `calculate_zone_occupancy()` - Time and percentage in each zone
  - 45 unit tests, all passing

- **Time in Zone** ([R/metrics/time_in_zone.R](R/metrics/time_in_zone.R:1))
  - `calculate_zone_entries()` - Count entries with duration statistics
  - `calculate_zone_exits()` - Count exits
  - `calculate_zone_latency()` - Time to first entry
  - `calculate_zone_transitions()` - Transition matrix
  - 63 unit tests, all passing

**Total Completion**: ~22-25% of project
**Total Tests Passing**: 483 tests (126 + 62 + 57 + 130 + 45 + 63)

---

## Your Starting Point: Phase 2.5 Infrastructure & Reporting

You have THREE priority areas to tackle:

### Priority 1: Fix Test Infrastructure (Task 2.10) - START HERE!
**This is critical and should be done FIRST**

**Current Problem**: Every testing session requires manually sourcing R files, causing confusion and errors.

**Solution**: Create automatic test setup infrastructure.

**File to create**: `tests/testthat/setup.R`

**Implementation**:
```r
# tests/testthat/setup.R
# This file is automatically sourced by testthat before running tests

# Source all R files needed for tests
source_files <- c(
  # Core data structures and I/O
  "R/core/data_structures.R",
  "R/core/data_loading.R",
  "R/core/data_converters.R",

  # Arena and geometry
  "R/core/arena_config.R",
  "R/core/zone_geometry.R",
  "R/core/coordinate_transforms.R",

  # Analysis functions
  "R/core/preprocessing.R",
  "R/core/quality_checks.R",

  # Metrics
  "R/metrics/zone_analysis.R",
  "R/metrics/time_in_zone.R",

  # Utilities
  "R/utils/config_utils.R"
)

# Source each file
for (file in source_files) {
  if (file.exists(file)) {
    source(file)
  } else {
    warning(sprintf("File not found: %s", file))
  }
}

# Inform user
message("DLCAnalyzer test environment loaded successfully")
message(sprintf("  - %d R source files loaded", length(source_files)))
```

**Also create**: `tests/README.md`
```markdown
# Running DLCAnalyzer Tests

## Quick Start

```bash
# From project root
export PATH="/home/paul/miniforge3/envs/r/bin:$PATH"
Rscript -e "library(testthat); test_dir('tests/testthat')"
```

All R source files are automatically loaded by `tests/testthat/setup.R`.

## Test Organization

- `tests/testthat/` - Unit tests (483 tests)
- `tests/integration/` - Integration tests with real data
- `tests/testthat/helper.R` - Helper functions for creating mock data

## No Manual Sourcing Required!

The `setup.R` file automatically sources all necessary R files before tests run.
Individual test files should NOT manually source R files.
```

**Verify**: After creating setup.R, run all tests and confirm 483 tests pass without manual sourcing.

---

### Priority 2: Add Real Data Integration Tests (Task 2.11)

**Current Problem**: Only EPM data is tested. Other paradigms (OFT, NORT, LD) have data but no tests.

**Directory to create**: `tests/integration/`

**Files to create**:

1. **`tests/integration/test_epm_real_data.R`** (formalize existing code)
2. **`tests/integration/test_oft_real_data.R`** (Open Field Test)
3. **`tests/integration/test_nort_real_data.R`** (Novel Object Recognition)
4. **`tests/integration/test_ld_real_data.R`** (Light/Dark Box)

**Available Data**:
- EPM: `data/EPM/Example DLC Data/*.csv` (4 files)
- OFT: `data/OFT/Output_DLC/*.csv`

**Arena Configs**:
- `config/arena_definitions/EPM/EPM.yaml`
- `config/arena_definitions/OF/` (may need to create)
- `config/arena_definitions/NORT/`
- `config/arena_definitions/LD/`

**Template for Integration Tests**:
```r
# tests/integration/test_oft_real_data.R
# Integration test for Open Field Test with real DLC data

# Load required libraries
library(testthat)

# Source all R files (if not using setup.R)
source("R/core/data_structures.R")
source("R/core/data_loading.R")
source("R/core/data_converters.R")
source("R/core/arena_config.R")
source("R/core/zone_geometry.R")
source("R/utils/config_utils.R")
source("R/metrics/zone_analysis.R")
source("R/metrics/time_in_zone.R")

test_that("OFT real data loads and processes correctly", {
  # Find OFT data files
  oft_files <- list.files("data/OFT/Output_DLC/",
                         pattern = "\\.csv$",
                         full.names = TRUE)

  skip_if(length(oft_files) == 0, "No OFT data files found")

  # Test with first file
  tracking_data <- convert_dlc_to_tracking_data(
    oft_files[1],
    fps = 30,
    paradigm = "open_field"
  )

  expect_s3_class(tracking_data, "tracking_data")
  expect_gt(nrow(tracking_data$tracking), 0)
})

test_that("OFT zone analysis works with real data", {
  oft_files <- list.files("data/OFT/Output_DLC/",
                         pattern = "\\.csv$",
                         full.names = TRUE)
  skip_if(length(oft_files) == 0, "No OFT data files found")

  # Load data
  tracking_data <- convert_dlc_to_tracking_data(oft_files[1], fps = 30)

  # Load or create arena config
  # arena <- load_arena_config("config/arena_definitions/OF/of_standard.yaml")
  # For now, skip if no arena config exists
  skip("Need to create OF arena configuration")

  # Test zone analysis
  # occupancy <- calculate_zone_occupancy(tracking_data, arena, body_part = "mouse_center")
  # expect_true(is.data.frame(occupancy))
  # expect_true("center" %in% occupancy$zone_id)
  # expect_true("periphery" %in% occupancy$zone_id)
})
```

**Acceptance Criteria**:
- All available data files are tested
- Tests skip gracefully if data/config missing
- Integration tests document expected patterns
- Can run: `Rscript tests/integration/test_oft_real_data.R`

---

### Priority 3: Build Reporting and Visualization System (Task 2.12)

**This is the BIG task - creates output for users**

**Files to create**:

#### 1. `R/reporting/generate_report.R`

**Functions to implement**:

```r
#' Generate subject report
#'
#' Creates comprehensive analysis report for a single subject
#'
#' @param tracking_data tracking_data object
#' @param arena_config arena_config object
#' @param output_dir Directory for output files
#' @param body_part Body part to analyze (default: "mouse_center")
#' @param format Report format: "html", "pdf", or "both"
#'
#' @return Path to generated report file(s)
#'
#' @export
generate_subject_report <- function(tracking_data, arena_config,
                                    output_dir = "reports",
                                    body_part = "mouse_center",
                                    format = "html") {
  # 1. Create output directory
  # 2. Run quality checks
  # 3. Calculate all metrics (occupancy, entries, exits, latency, transitions)
  # 4. Generate plots (heatmap, trajectory, occupancy bars, transitions)
  # 5. Compile into R Markdown report
  # 6. Render to HTML/PDF
  # 7. Save metrics as CSV
  # Return list of output files
}

#' Generate group comparison report
#'
#' Compares multiple subjects or groups
#'
#' @param tracking_data_list List of tracking_data objects
#' @param arena_config arena_config object
#' @param group_info Data frame with columns: subject_id, group, treatment, etc.
#' @param output_dir Directory for output
#' @param comparisons List of comparisons to make (e.g., list(c("control", "treatment")))
#' @param format Report format
#'
#' @return Path to generated report
#'
#' @export
generate_group_report <- function(tracking_data_list, arena_config,
                                  group_info, output_dir = "reports",
                                  comparisons = NULL, format = "html") {
  # 1. Generate individual metrics for each subject
  # 2. Combine metrics into group summaries
  # 3. Perform statistical tests (t-test, ANOVA, etc.)
  # 4. Calculate effect sizes
  # 5. Generate comparison plots
  # 6. Compile into report
  # 7. Return report path
}

#' Compare subjects
#'
#' Statistical comparison of metrics between subjects
#'
#' @param subject_list List of subject IDs or tracking_data objects
#' @param metrics Character vector of metrics to compare
#' @param test_type Statistical test: "t.test", "wilcox.test", "anova"
#' @param output_file Output CSV file path
#'
#' @return Data frame with comparison results
#'
#' @export
compare_subjects <- function(subject_list, metrics = "all",
                            test_type = "t.test", output_file = NULL) {
  # Perform statistical comparisons
  # Return results data frame
}

#' Compare groups
#'
#' Statistical comparison between groups
#'
#' @param group_a Vector of subject IDs in group A
#' @param group_b Vector of subject IDs in group B
#' @param metrics Metrics to compare
#' @param test_type Statistical test type
#' @param correction Multiple comparison correction: "bonferroni", "fdr", "none"
#' @param output_file Output file path
#'
#' @return Data frame with test results and effect sizes
#'
#' @export
compare_groups <- function(group_a, group_b, metrics = "all",
                          test_type = "t.test", correction = "fdr",
                          output_file = NULL) {
  # Perform group comparisons with corrections
  # Calculate effect sizes (Cohen's d, etc.)
  # Return results
}
```

#### 2. `R/visualization/plot_tracking.R`

**Visualization functions**:

```r
#' Plot tracking heatmap
#'
#' @param tracking_data tracking_data object
#' @param arena_config arena_config object
#' @param body_part Body part to plot
#' @param bins Number of bins for heatmap (default: 50)
#'
#' @return ggplot object
#'
#' @export
plot_heatmap <- function(tracking_data, arena_config,
                        body_part = "mouse_center", bins = 50) {
  # Use ggplot2 to create 2D density heatmap
  # Overlay arena zones
  # Add colorbar showing occupancy
}

#' Plot trajectory
#'
#' @param tracking_data tracking_data object
#' @param arena_config arena_config object
#' @param body_part Body part to plot
#' @param color_by_time Color trajectory by time (default: TRUE)
#' @param max_points Maximum points to plot (for performance)
#'
#' @return ggplot object
#'
#' @export
plot_trajectory <- function(tracking_data, arena_config,
                           body_part = "mouse_center",
                           color_by_time = TRUE, max_points = 5000) {
  # Plot x,y path
  # Color by time or velocity
  # Overlay arena zones
}

#' Plot zone occupancy
#'
#' @param occupancy_data Data frame from calculate_zone_occupancy()
#' @param plot_type "bar", "pie", or "both"
#'
#' @return ggplot object or list of ggplot objects
#'
#' @export
plot_zone_occupancy <- function(occupancy_data, plot_type = "bar") {
  # Bar chart of time/percentage per zone
  # Or pie chart
}

#' Plot zone transitions
#'
#' @param transition_data Data frame from calculate_zone_transitions()
#' @param plot_type "network", "chord", or "matrix"
#' @param min_transitions Minimum transitions to show (filter noise)
#'
#' @return ggplot object or network diagram
#'
#' @export
plot_zone_transitions <- function(transition_data, plot_type = "network",
                                  min_transitions = 5) {
  # Network diagram showing zone-to-zone transitions
  # Node size = time in zone
  # Edge thickness = number of transitions
}
```

#### 3. `R/visualization/plot_comparisons.R`

**Group comparison plots**:

```r
#' Plot group comparison
#'
#' @param metric_data Data frame with columns: subject_id, group, metric_value
#' @param groups Vector of group names
#' @param test_results Data frame from compare_groups()
#' @param plot_type "violin", "box", "bar", or "dot"
#'
#' @return ggplot object with significance indicators
#'
#' @export
plot_group_comparison <- function(metric_data, groups, test_results = NULL,
                                  plot_type = "violin") {
  # Violin/box/dot plot comparing groups
  # Add significance stars/bars if test_results provided
  # Show individual data points
  # Add error bars (mean ± SEM)
}

#' Plot metric distribution
#'
#' @param metric_data Data frame with metric values
#' @param by_group Logical, facet by group?
#' @param plot_type "histogram", "density", or "both"
#'
#' @return ggplot object
#'
#' @export
plot_metric_distribution <- function(metric_data, by_group = TRUE,
                                     plot_type = "both") {
  # Distribution plots
  # Overlay normal curve if appropriate
}
```

#### 4. R Markdown Template: `inst/templates/subject_report.Rmd`

```rmarkdown
---
title: "DLC Analysis Report: {{subject_id}}"
date: "{{date}}"
output:
  html_document:
    toc: true
    toc_float: true
    theme: flatly
---

# Session Information

- **Subject ID**: {{subject_id}}
- **Paradigm**: {{paradigm}}
- **Date**: {{date}}
- **Duration**: {{duration}} seconds ({{n_frames}} frames at {{fps}} fps)

# Data Quality

{{quality_summary}}

# Zone Occupancy

## Summary Table

{{occupancy_table}}

## Visualization

{{occupancy_plot}}

# Zone Entry/Exit Analysis

{{entries_table}}

{{exits_table}}

# Zone Latencies

{{latency_table}}

# Zone Transitions

{{transitions_plot}}

# Trajectory and Heatmap

{{trajectory_plot}}

{{heatmap}}

# Appendix: Raw Data

{{raw_metrics}}
```

**Testing the Reporting System**:

Create test script: `tests/test_reporting_epm.R`

```r
# Test reporting with EPM data
source("R/core/data_structures.R")
# ... (source all files or use setup.R)
source("R/reporting/generate_report.R")
source("R/visualization/plot_tracking.R")

# Load EPM data
tracking_data <- convert_dlc_to_tracking_data(
  "data/EPM/Example DLC Data/ID7689_superanimal_topviewmouse_snapshot-hrnet_w32-004_snapshot-fasterrcnn_resnet50_fpn_v2-004__filtered.csv",
  fps = 30,
  subject_id = "ID7689",
  paradigm = "epm"
)

arena <- load_arena_config("config/arena_definitions/EPM/EPM.yaml")

# Generate report
report_file <- generate_subject_report(
  tracking_data,
  arena,
  output_dir = "reports/test",
  body_part = "mouse_center",
  format = "html"
)

cat("Report generated:", report_file, "\n")
```

---

## Suggested Implementation Order

### Session Start (30 min)
1. **Verify current state**: Run all existing tests to confirm 483 tests pass
2. **Review recent changes**: Check git log and understand Tasks 2.5 & 2.6

### Task 2.10: Test Infrastructure (1-2 hours) - DO THIS FIRST
1. Create `tests/testthat/setup.R`
2. Create `tests/README.md`
3. Verify all 483 tests pass without manual sourcing
4. Commit: "Fix test infrastructure with automatic sourcing"

### Task 2.11: Integration Tests (2-3 hours)
1. Create `tests/integration/` directory
2. Create integration tests for each paradigm
3. Test with available real data
4. Document expected outputs
5. Commit: "Add real data integration tests for all paradigms"

### Task 2.12: Reporting System (4-6 hours)
Start with basics, expand later:

**Phase 1: Basic Reporting (2-3 hours)**
1. Create `R/reporting/generate_report.R` with `generate_subject_report()`
2. Create basic R Markdown template
3. Test with EPM data
4. Commit: "Add basic subject reporting system"

**Phase 2: Visualization (2-3 hours)**
1. Create `R/visualization/plot_tracking.R`
2. Implement `plot_heatmap()` and `plot_trajectory()`
3. Implement `plot_zone_occupancy()`
4. Test and commit: "Add tracking visualization functions"

**Phase 3: Comparisons (later session)**
1. Implement group comparison functions
2. Statistical testing
3. Comparison plots

---

## Code Standards and Best Practices

- Use **ggplot2** for all plots
- Use **rmarkdown** for reports
- Use **roxygen2** for documentation
- Follow tidyverse style guide
- Test all functions with real EPM data
- Include examples in documentation
- Create publication-ready plots (high DPI, proper labels)

---

## Example Output

After completing Tasks 2.10-2.12, you should be able to run:

```r
# Load and analyze EPM data
tracking_data <- convert_dlc_to_tracking_data("data/EPM/.../ID7689...csv", fps = 30)
arena <- load_arena_config("config/arena_definitions/EPM/EPM.yaml")

# Generate comprehensive report
report <- generate_subject_report(
  tracking_data,
  arena,
  output_dir = "reports/ID7689",
  body_part = "mouse_center",
  format = "html"
)

# Output:
# reports/ID7689/
#   ├── ID7689_report.html        # Interactive HTML report
#   ├── ID7689_metrics.csv        # All metrics as CSV
#   ├── plots/
#   │   ├── heatmap.png
#   │   ├── trajectory.png
#   │   ├── occupancy.png
#   │   └── transitions.png
```

---

## Quick Start Commands

```bash
# Set working directory
cd /mnt/g/Bella/Rebecca/Code/DLCAnalyzer

# Set R environment
export PATH="/home/paul/miniforge3/envs/r/bin:$PATH"

# Verify current state
git log --oneline -5
git status

# Run existing tests (should pass 483 tests)
Rscript -e "library(testthat); test_dir('tests/testthat')"

# After creating setup.R, tests should work without manual sourcing!
```

---

## Success Criteria

### Task 2.10 Complete When:
- [ ] `tests/testthat/setup.R` exists and sources all R files
- [ ] `tests/README.md` explains how to run tests
- [ ] All 483 tests pass without manual sourcing
- [ ] Git commit created

### Task 2.11 Complete When:
- [ ] Integration tests exist for all paradigms with data
- [ ] Tests run successfully with real data
- [ ] Expected outputs documented
- [ ] Git commit created

### Task 2.12 Complete When:
- [ ] Can generate HTML report for single subject
- [ ] Report includes quality metrics, zone analysis, and plots
- [ ] All visualization functions work
- [ ] Tested with real EPM data
- [ ] Git commit created

---

## Available Resources

### Documentation
- [docs/REFACTORING_TODO.md](docs/REFACTORING_TODO.md:1) - Full task list
- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md:1) - Design principles

### Existing Code
- [R/metrics/zone_analysis.R](R/metrics/zone_analysis.R:1) - Zone analysis functions
- [R/metrics/time_in_zone.R](R/metrics/time_in_zone.R:1) - Time in zone functions
- [R/core/quality_checks.R](R/core/quality_checks.R:1) - Quality metrics

### Test Data
- EPM: `data/EPM/Example DLC Data/*.csv` (4 files, extensively tested)
- OFT: `data/OFT/Output_DLC/*.csv`

### Arena Configs
- `config/arena_definitions/EPM/EPM.yaml`
- `config/arena_definitions/NORT/`
- `config/arena_definitions/LD/`
- `config/arena_definitions/OF/`

---

**You have everything you need! Start with Task 2.10 (test infrastructure), then move to Task 2.11 (integration tests), and finally Task 2.12 (reporting). Good luck!**

**Document Version**: 1.0
**Created**: December 17, 2024
**Previous Session**: Tasks 2.5 & 2.6 completed (Zone analysis and time in zone metrics)
