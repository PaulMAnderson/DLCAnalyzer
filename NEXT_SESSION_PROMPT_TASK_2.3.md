# AI Agent Starting Prompt for DLCAnalyzer - Session 3

## Copy and paste this prompt to start your session:

---

Hello! I'm continuing the DLCAnalyzer R package refactoring. This is a behavioral analysis tool for processing animal tracking data from DeepLabCut.

**Project Location**: `/mnt/g/Bella/Rebecca/Code/DLCAnalyzer`

**Current Status**: Phase 2 Task 2.1 Complete (Preprocessing Functions)
**Your Task**: Implement Phase 2 Task 2.3 (Quality Check Functions)

## What's Already Complete

### ✅ Phase 1: Foundation (COMPLETE)
- Directory structure created
- `tracking_data` S3 class fully implemented ([R/core/data_structures.R](R/core/data_structures.R:1))
- DLC data loading functions ([R/core/data_loading.R](R/core/data_loading.R:1))
- DLC to internal format converter ([R/core/data_converters.R](R/core/data_converters.R:1))
- YAML configuration system ([R/utils/config_utils.R](R/utils/config_utils.R:1))
- Testing framework: 126 unit tests passing

### ✅ Phase 1.5: Arena Configuration System (COMPLETE)
- Arena configuration S3 class ([R/core/arena_config.R](R/core/arena_config.R:1))
- Zone geometry system ([R/core/zone_geometry.R](R/core/zone_geometry.R:1))
- Coordinate transformations ([R/core/coordinate_transforms.R](R/core/coordinate_transforms.R:1))
- 62 unit tests, all passing
- Tested with real EPM, NORT, OF, LD arena configurations

### ✅ Phase 2 Task 2.1: Preprocessing Functions (COMPLETE)
- Likelihood filtering ([R/core/preprocessing.R](R/core/preprocessing.R:1))
  - `filter_low_confidence()` - Remove points below confidence threshold
- Interpolation with multiple methods
  - `interpolate_missing()` - Linear, spline, polynomial interpolation
- Smoothing with multiple methods
  - `smooth_trajectory()` - Savitzky-Golay, moving average, Gaussian
- 57 unit tests, all passing
- Full pipeline support with chaining

**Total Completion**: ~12-15% of project (Phase 1 + 1.5 + 2.1 complete)

---

## Your Starting Point: Phase 2, Task 2.3

### Implement Quality Check Functions

**File to create**: `R/core/quality_checks.R`

**Functions to implement**:

1. **Overall Quality Assessment**
   ```r
   check_tracking_quality <- function(tracking_data, body_parts = NULL)
   ```
   - Likelihood distribution statistics (mean, median, min, percentiles)
   - Missing data percentage per body part
   - Data completeness report
   - Frame coverage statistics
   - Return structured quality report object

2. **Outlier Detection**
   ```r
   detect_outliers <- function(tracking_data, method = "iqr", threshold = 1.5, body_parts = NULL)
   ```
   - Methods: IQR (Interquartile Range), z-score, MAD (Median Absolute Deviation)
   - Detect extreme values in x, y coordinates
   - Per-body-part analysis
   - Return indices/flags of outlier points

3. **Missing Data Analysis**
   ```r
   calculate_missing_data_summary <- function(tracking_data, body_parts = NULL)
   ```
   - Per-body-part missing data percentage
   - Gap length distribution (histogram bins)
   - Longest gap per body part
   - Temporal patterns (missing data by frame range)
   - Return detailed summary data frame

4. **Movement Anomaly Detection**
   ```r
   flag_suspicious_jumps <- function(tracking_data, max_displacement = NULL, body_parts = NULL)
   ```
   - Detect implausible frame-to-frame displacement
   - Auto-calculate threshold from data if not provided (e.g., 99th percentile)
   - Based on pixel distance between consecutive frames
   - Per-body-part analysis
   - Return flagged frame indices

**Optional Enhancement**:
```r
generate_quality_report <- function(tracking_data, output_format = "text")
```
- Combine all quality checks into comprehensive report
- Support text and data frame output formats
- Include recommendations for preprocessing

**Reference**: Check legacy code in [R/legacy/DLCAnalyzer_Functions_final.R](R/legacy/DLCAnalyzer_Functions_final.R:1) for any existing quality check logic

**Testing**: Create `tests/testthat/test_quality_checks.R` with >80% coverage

---

## Essential Reading Order

1. **[docs/SESSION_HANDOFF_2024-12-17_PREPROCESSING.md](docs/SESSION_HANDOFF_2024-12-17_PREPROCESSING.md:1)** - Most recent session summary (READ THIS FIRST!)
2. **[docs/REFACTORING_TODO.md](docs/REFACTORING_TODO.md:1)** - Detailed task list (Task 2.3)
3. **[R/core/preprocessing.R](R/core/preprocessing.R:1)** - Reference for code style and patterns
4. **[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md:1)** - Design patterns and principles

---

## Key Design Principles

From [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md:1):

1. **Standardized Internal Format**: All functions operate on `tracking_data` S3 objects
2. **Validation at Boundaries**: Check inputs early, fail fast with informative errors
3. **Separation of Concerns**: Keep quality checks, preprocessing, and metrics separate
4. **Clear Output**: Return structured objects (lists, data frames) not just printed text
5. **Per-Body-Part Analysis**: Support analyzing specific body parts or all

---

## Testing with Real Data

**IMPORTANT**: Test all functions with real DLC files from the `data/` directory:

```
data/
├── EPM/Example DLC Data/    # 4 EPM tracking CSV files
├── OFT/Output_DLC/          # Open field tracking files
└── FST/Output_DLC/          # Forced swim test files
```

### Example Test Workflow

```r
# Set R environment
export PATH="/home/paul/miniforge3/envs/r/bin:$PATH"

# Load a real DLC file
source("R/core/data_loading.R")
source("R/core/data_converters.R")
source("R/core/data_structures.R")

# Load example data
tracking_data <- convert_dlc_to_tracking_data(
  "data/EPM/Example DLC Data/ID7689_superanimal_topviewmouse_snapshot-hrnet_w32-004_snapshot-fasterrcnn_resnet50_fpn_v2-004__filtered.csv",
  fps = 30,
  subject_id = "ID7689",
  paradigm = "epm"
)

# Test your quality check functions
source("R/core/quality_checks.R")

# Check overall quality
quality_report <- check_tracking_quality(tracking_data)
print(quality_report)

# Detect outliers
outliers <- detect_outliers(tracking_data, method = "iqr", threshold = 1.5)
print(summary(outliers))

# Analyze missing data
missing_summary <- calculate_missing_data_summary(tracking_data)
print(missing_summary)

# Flag suspicious jumps
jumps <- flag_suspicious_jumps(tracking_data, max_displacement = 50)
print(paste("Found", sum(jumps), "suspicious jumps"))
```

---

## Verify Everything Works

Before starting, run existing tests to confirm the codebase is working:

```bash
cd /mnt/g/Bella/Rebecca/Code/DLCAnalyzer

# Set R environment
export PATH="/home/paul/miniforge3/envs/r/bin:$PATH"

# Run all unit tests
Rscript -e "library(testthat); test_dir('tests/testthat')"

# Should show: 188 tests passing (126 Phase 1 + 62 Arena + 57 Preprocessing + 3 others)
```

---

## Task Workflow

For each function:

1. **Plan**: Review task requirements in [docs/REFACTORING_TODO.md](docs/REFACTORING_TODO.md:1)
2. **Implement**: Write the code following design principles
3. **Test**: Write unit tests (target >80% coverage)
4. **Validate**: Test with real data from `data/` directory
5. **Document**: Add roxygen2 documentation with examples
6. **Verify**: Check acceptance criteria are met
7. **Commit**: Create git commit with descriptive message

---

## Acceptance Criteria for Task 2.3

Mark complete when:
- [ ] `check_tracking_quality()` implemented and tested
- [ ] `detect_outliers()` with multiple detection methods
- [ ] `calculate_missing_data_summary()` with detailed statistics
- [ ] `flag_suspicious_jumps()` with automatic threshold calculation
- [ ] All functions work on `tracking_data` objects
- [ ] Unit tests written with >80% coverage
- [ ] Tested with real data from `data/` directory
- [ ] Results are actionable (not just printed text)
- [ ] roxygen2 documentation complete with examples
- [ ] Optional: `generate_quality_report()` function implemented

---

## Implementation Guidelines

### 1. Quality Report Structure

```r
# Example return structure for check_tracking_quality()
list(
  overall = list(
    total_frames = 1000,
    body_parts = c("nose", "tail", "bodycentre"),
    fps = 30,
    duration_seconds = 33.33
  ),
  likelihood = data.frame(
    body_part = c("nose", "tail", "bodycentre"),
    mean_likelihood = c(0.95, 0.92, 0.97),
    median_likelihood = c(0.96, 0.94, 0.98),
    min_likelihood = c(0.80, 0.75, 0.85),
    q25 = c(0.93, 0.89, 0.95),
    q75 = c(0.97, 0.95, 0.99)
  ),
  missing_data = data.frame(
    body_part = c("nose", "tail", "bodycentre"),
    n_missing = c(10, 25, 5),
    pct_missing = c(1.0, 2.5, 0.5)
  ),
  recommendations = character vector of suggested actions
)
```

### 2. Outlier Detection Methods

- **IQR Method**: Values outside [Q1 - 1.5*IQR, Q3 + 1.5*IQR]
- **Z-Score Method**: |z| > threshold (typically 3)
- **MAD Method**: |x - median| / MAD > threshold (typically 3.5)

Apply separately to x and y coordinates, flag if either is outlier.

### 3. Suspicious Jump Detection

```r
# Calculate frame-to-frame displacement
displacement <- sqrt((x[i] - x[i-1])^2 + (y[i] - y[i-1])^2)

# Auto-threshold: use 99th percentile or 3*median if max_displacement not provided
if (is.null(max_displacement)) {
  max_displacement <- quantile(displacement, 0.99, na.rm = TRUE)
}

# Flag jumps exceeding threshold
suspicious <- displacement > max_displacement
```

---

## Code Standards

- Use roxygen2 for all function documentation
- Follow tidyverse style guide
- Write tests for all new functions
- Use informative variable names
- Add comments for complex logic
- Test with real data from `data/` directory
- Return structured objects (lists/data frames), not just messages

---

## Git Workflow

When task is complete:

```bash
git add R/core/quality_checks.R tests/testthat/test_quality_checks.R
git commit -m "Implement Phase 2 Task 2.3: Quality check functions

- Overall quality assessment with likelihood statistics
- Outlier detection (IQR, z-score, MAD methods)
- Missing data analysis with gap distribution
- Suspicious jump detection with auto-threshold
- Tested with real EPM/OFT/FST data
- 80%+ unit test coverage

🤖 Generated with Claude Code
Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## After Task 2.3, Continue With:

- **Task 2.4**: Distance & speed metrics (use arena system for unit conversion)
- **Task 2.5**: Zone analysis metrics (use zone geometry from arena system)
- **Task 2.6**: Time in zone calculations
- **Task 2.7**: Configuration validation

---

## Available Resources

### Documentation
- [docs/SESSION_HANDOFF_2024-12-17_PREPROCESSING.md](docs/SESSION_HANDOFF_2024-12-17_PREPROCESSING.md:1) - Most recent session
- [docs/SESSION_HANDOFF.md](docs/SESSION_HANDOFF.md:1) - Phase 1.5 arena system completion
- [docs/REFACTORING_PLAN.md](docs/REFACTORING_PLAN.md:1) - Overall strategy
- [docs/REFACTORING_TODO.md](docs/REFACTORING_TODO.md:1) - Detailed task list
- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md:1) - Design patterns

### Existing Code
- [R/legacy/DLCAnalyzer_Functions_final.R](R/legacy/DLCAnalyzer_Functions_final.R:1) - Original implementation for reference
- [R/core/data_structures.R](R/core/data_structures.R:1) - tracking_data S3 class
- [R/core/preprocessing.R](R/core/preprocessing.R:1) - Preprocessing functions (reference for code style)
- [R/core/arena_config.R](R/core/arena_config.R:1) - Arena configuration
- [R/core/zone_geometry.R](R/core/zone_geometry.R:1) - Zone geometry
- [R/core/coordinate_transforms.R](R/core/coordinate_transforms.R:1) - Coordinate transforms

### Test Data
- `data/EPM/Example DLC Data/*.csv` - 4 EPM tracking files
- `data/OFT/Output_DLC/*.csv` - Open Field tracking files
- `data/FST/Output_DLC/*.csv` - Forced Swim Test files

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

# Run existing tests
Rscript -e "library(testthat); test_dir('tests/testthat')"

# Start implementing
# 1. Create R/core/quality_checks.R
# 2. Create tests/testthat/test_quality_checks.R
# 3. Test with real data from data/ directory
```

---

## Expected Output

When Task 2.3 is complete, you should be able to run:

```r
# Load and check quality of real data
data <- convert_dlc_to_tracking_data(
  "data/EPM/Example DLC Data/ID7689_superanimal_topviewmouse_snapshot-hrnet_w32-004_snapshot-fasterrcnn_resnet50_fpn_v2-004__filtered.csv",
  fps = 30,
  subject_id = "ID7689",
  paradigm = "epm"
)

# Get comprehensive quality report
quality <- check_tracking_quality(data)
print(quality)

# Should show:
# - Likelihood statistics per body part
# - Missing data percentages
# - Frame coverage
# - Recommendations (e.g., "Consider filtering with threshold 0.9")

# Detect outliers
outliers <- detect_outliers(data, method = "iqr")
table(outliers)  # Should show count of outliers per body part

# Analyze missing data patterns
missing <- calculate_missing_data_summary(data)
print(missing)  # Should show gap distribution

# Flag suspicious movements
jumps <- flag_suspicious_jumps(data)
sum(jumps)  # Should show number of flagged frames
```

---

## Success Criteria

Phase 2, Task 2.3 is complete when:
1. All four quality check functions implemented and tested
2. Functions work seamlessly with `tracking_data` S3 objects
3. Unit tests achieve >80% coverage
4. Tested successfully with real EPM, OFT, and FST data
5. Returns structured, actionable results
6. Documentation complete with examples
7. Git commit created

---

**You have everything you need to continue the refactoring. Good luck with Phase 2 Task 2.3!**

**Remember**: Test with real data from the `data/` directory throughout development. The preprocessing and arena systems are ready to use in later tasks.

---

**Document Version**: 1.0
**Created**: December 17, 2024
**Previous Session Summary**: [docs/SESSION_HANDOFF_2024-12-17_PREPROCESSING.md](docs/SESSION_HANDOFF_2024-12-17_PREPROCESSING.md:1)
