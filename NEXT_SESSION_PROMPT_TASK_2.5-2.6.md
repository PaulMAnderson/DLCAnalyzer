# AI Agent Starting Prompt for DLCAnalyzer - Session 4

## Copy and paste this prompt to start your session:

---

Hello! I'm continuing the DLCAnalyzer R package refactoring. This is a behavioral analysis tool for processing animal tracking data from DeepLabCut.

**Project Location**: `/mnt/g/Bella/Rebecca/Code/DLCAnalyzer`

**Current Status**: Phase 2 Task 2.3 Complete (Quality Check Functions)
**Your Task**: Implement Phase 2 Tasks 2.5 & 2.6 (Zone Analysis and Time in Zone Metrics)

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
  - **`create_zone_geometry()`** - Creates zone from arena definition
  - **`point_in_zone()`** - Tests if x,y coordinates are inside zone
  - Support for polygon, circle, rectangle, and proportional zones
- Coordinate transformations ([R/core/coordinate_transforms.R](R/core/coordinate_transforms.R:1))
- 62 unit tests, all passing
- Tested with real EPM, NORT, OF, LD arena configurations

### ✅ Phase 2 Task 2.1: Preprocessing Functions (COMPLETE)
- Likelihood filtering ([R/core/preprocessing.R](R/core/preprocessing.R:1))
- Interpolation with multiple methods (linear, spline, polynomial)
- Smoothing with multiple methods (Savitzky-Golay, moving average, Gaussian)
- 57 unit tests, all passing

### ✅ Phase 2 Task 2.3: Quality Check Functions (COMPLETE)
- Overall quality assessment ([R/core/quality_checks.R](R/core/quality_checks.R:1))
  - `check_tracking_quality()` - Comprehensive quality metrics
  - `detect_outliers()` - IQR, z-score, MAD methods
  - `calculate_missing_data_summary()` - Gap analysis
  - `flag_suspicious_jumps()` - Movement anomaly detection
  - `generate_quality_report()` - Text and structured reports
- 130 unit tests, all passing
- Tested with real EPM data (9,688 frames, 39 body parts)

**Total Completion**: ~18-20% of project (Phases 1, 1.5, 2.1, 2.3 complete)
**Total Tests Passing**: 375 tests (126 + 62 + 57 + 130)

---

## Your Starting Point: Phase 2, Tasks 2.5 & 2.6

### Task 2.5: Zone Analysis Functions

**File to create**: `R/metrics/zone_analysis.R`

**Functions to implement**:

1. **Zone Classification**
   ```r
   classify_points_by_zone <- function(tracking_data, arena_config, body_part = NULL)
   ```
   - For each tracking point, determine which zone it's in
   - Use existing `point_in_zone()` from zone_geometry.R
   - Handle multiple zones (zones can overlap)
   - Return data frame with frame, body_part, zone_id columns
   - Support analyzing specific body parts or all

2. **Zone Occupancy**
   ```r
   calculate_zone_occupancy <- function(tracking_data, arena_config, body_part = NULL)
   ```
   - Calculate percentage of time spent in each zone
   - Use fps from metadata to convert frames to time
   - Return data frame with zone_id, time_seconds, percentage columns
   - Per-body-part analysis support

**Key Design Points**:
- Leverage existing arena_config system (don't recreate zone definitions)
- Use `create_zone_geometry()` to convert arena zones to geometries
- Use `point_in_zone()` for testing (already implemented and tested)
- Handle edge cases: points outside all zones, points in multiple overlapping zones
- Return structured data frames, not just printed output

---

### Task 2.6: Time in Zone Functions

**File to create**: `R/metrics/time_in_zone.R`

**Functions to implement**:

1. **Zone Entry Detection**
   ```r
   calculate_zone_entries <- function(tracking_data, arena_config, body_part = NULL, min_duration = 0)
   ```
   - Count number of times animal enters each zone
   - Entry = transition from outside zone to inside zone
   - Support minimum duration threshold (ignore brief entries)
   - Return data frame with zone_id, n_entries, mean_duration columns

2. **Zone Exit Detection**
   ```r
   calculate_zone_exits <- function(tracking_data, arena_config, body_part = NULL)
   ```
   - Count number of times animal exits each zone
   - Exit = transition from inside zone to outside zone
   - Return data frame with zone_id, n_exits columns

3. **Zone Entry Latency**
   ```r
   calculate_zone_latency <- function(tracking_data, arena_config, body_part = NULL)
   ```
   - Calculate time to first entry into each zone
   - Return NA if zone never entered
   - Return data frame with zone_id, latency_seconds, first_entry_frame columns

4. **Zone Transitions**
   ```r
   calculate_zone_transitions <- function(tracking_data, arena_config, body_part = NULL, min_duration = 0)
   ```
   - Track all zone-to-zone transitions
   - Create transition matrix (from_zone -> to_zone)
   - Support minimum duration (ignore brief visits)
   - Return data frame with from_zone, to_zone, n_transitions columns

**Key Design Points**:
- Use `classify_points_by_zone()` as foundation
- Detect transitions by comparing consecutive frames
- Handle missing data (NA zones) gracefully
- Use fps for time calculations
- Support minimum duration filters to avoid noise

---

## Essential Reading Order

1. **[docs/SESSION_HANDOFF_2024-12-17_QUALITY_CHECKS.md](docs/SESSION_HANDOFF_2024-12-17_QUALITY_CHECKS.md:1)** - Most recent session (if exists)
2. **[docs/REFACTORING_TODO.md](docs/REFACTORING_TODO.md:324-371)** - Tasks 2.5 & 2.6 details
3. **[R/core/zone_geometry.R](R/core/zone_geometry.R:1)** - Existing zone system (USE THIS!)
4. **[R/core/arena_config.R](R/core/arena_config.R:1)** - Arena configuration structure
5. **[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md:1)** - Design principles

---

## Key Design Principles

From [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md:1):

1. **Use Existing Systems**: Don't recreate zone geometry - use `create_zone_geometry()` and `point_in_zone()`
2. **Standardized Internal Format**: All functions operate on `tracking_data` S3 objects
3. **Arena Integration**: Use `arena_config` objects for zone definitions
4. **Validation at Boundaries**: Check inputs early, fail fast with informative errors
5. **Clear Output**: Return structured data frames with clear column names
6. **Per-Body-Part Analysis**: Support analyzing specific body parts or all

---

## Testing with Real Data

**IMPORTANT**: Test all functions with real DLC files and arena configurations.

### Available Test Data

```
data/
├── EPM/Example DLC Data/    # 4 EPM tracking CSV files (tested)
├── OFT/Output_DLC/          # Open field tracking files
└── FST/Output_DLC/          # Forced swim test files

config/arena_definitions/
├── epm_standard.yaml         # EPM arena with open/closed arm zones
├── open_field_standard.yaml  # OF arena with center/periphery zones
├── nort_standard.yaml        # NORT arena with object zones
└── light_dark_standard.yaml  # LD arena with light/dark zones
```

### Example Test Workflow

```r
# Set R environment
export PATH="/home/paul/miniforge3/envs/r/bin:$PATH"

# Load dependencies
source("R/core/data_structures.R")
source("R/core/data_loading.R")
source("R/core/data_converters.R")
source("R/core/arena_config.R")
source("R/core/zone_geometry.R")
source("R/utils/config_utils.R")

# Load real DLC data
tracking_data <- convert_dlc_to_tracking_data(
  "data/EPM/Example DLC Data/ID7689_superanimal_topviewmouse_snapshot-hrnet_w32-004_snapshot-fasterrcnn_resnet50_fpn_v2-004__filtered.csv",
  fps = 30,
  subject_id = "ID7689",
  paradigm = "epm"
)

# Load arena configuration
arena <- load_arena_config("config/arena_definitions/epm_standard.yaml")

# Test your zone analysis functions
source("R/metrics/zone_analysis.R")
source("R/metrics/time_in_zone.R")

# Classify points
classifications <- classify_points_by_zone(tracking_data, arena, body_part = "mouse_center")
print(head(classifications))

# Calculate occupancy
occupancy <- calculate_zone_occupancy(tracking_data, arena, body_part = "mouse_center")
print(occupancy)

# Count entries
entries <- calculate_zone_entries(tracking_data, arena, body_part = "mouse_center")
print(entries)

# Calculate latency
latency <- calculate_zone_latency(tracking_data, arena, body_part = "mouse_center")
print(latency)

# Get transitions
transitions <- calculate_zone_transitions(tracking_data, arena, body_part = "mouse_center")
print(transitions)
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

# Should show: 375 tests passing (126 Phase 1 + 62 Arena + 57 Preprocessing + 130 Quality)
```

---

## Implementation Strategy

### Step 1: Understand Existing Zone System

First, study how the zone system works:

```r
# Example: How to use existing zone functions
source("R/core/zone_geometry.R")
source("R/core/arena_config.R")

# Load an arena
arena <- load_arena_config("config/arena_definitions/epm_standard.yaml")

# Get a zone
zone_def <- get_arena_zone(arena, "open_arm_north")

# Create geometry
geometry <- create_zone_geometry(zone_def, arena)

# Test points
x <- c(100, 200, 300)
y <- c(100, 200, 300)
in_zone <- point_in_zone(x, y, geometry)
print(in_zone)  # Logical vector
```

### Step 2: Implement Zone Classification (Foundation)

This is the critical function - all others depend on it:

```r
classify_points_by_zone <- function(tracking_data, arena_config, body_part = NULL) {
  # 1. Validate inputs
  # 2. Filter to specific body part if requested
  # 3. Get all zones from arena_config
  # 4. For each zone:
  #    - Create geometry with create_zone_geometry()
  #    - Test all points with point_in_zone()
  #    - Record which points are in zone
  # 5. Return data frame with columns: frame, body_part, x, y, zone_id
  #    - zone_id = NA for points outside all zones
  #    - If overlapping zones, can include multiple rows per point
}
```

### Step 3: Build on Classification

Once classification works, other functions become simpler:

```r
calculate_zone_entries <- function(tracking_data, arena_config, body_part = NULL) {
  # 1. Get classifications
  classifications <- classify_points_by_zone(tracking_data, arena_config, body_part)

  # 2. Sort by body_part and frame
  # 3. For each body_part and zone:
  #    - Detect transitions: outside -> inside (entry)
  #    - Count entries
  #    - Calculate duration of each visit
  # 4. Return summary data frame
}
```

---

## Acceptance Criteria for Tasks 2.5 & 2.6

Mark complete when:

### Task 2.5 (Zone Analysis)
- [x] `classify_points_by_zone()` implemented and tested
- [x] `calculate_zone_occupancy()` implemented and tested
- [x] Functions work with existing `arena_config` objects
- [x] Unit tests written with >80% coverage
- [x] Tested with real EPM data showing open/closed arm occupancy
- [x] Handles edge cases (outside all zones, overlapping zones)
- [x] roxygen2 documentation complete with examples

### Task 2.6 (Time in Zone)
- [x] `calculate_zone_entries()` with min_duration support
- [x] `calculate_zone_exits()` implemented and tested
- [x] `calculate_zone_latency()` handles never-entered zones
- [x] `calculate_zone_transitions()` creates transition matrix
- [x] All functions use `classify_points_by_zone()` as foundation
- [x] Unit tests written with >80% coverage
- [x] Tested with real EPM data showing arm transitions
- [x] roxygen2 documentation complete with examples

---

## Expected Output Examples

When Tasks 2.5 & 2.6 are complete, you should be able to run:

```r
# Load EPM data and arena
data <- convert_dlc_to_tracking_data("data/EPM/...ID7689...csv", fps = 30)
arena <- load_arena_config("config/arena_definitions/epm_standard.yaml")

# Zone occupancy
occupancy <- calculate_zone_occupancy(data, arena, body_part = "mouse_center")
# Expected output:
#   zone_id          time_seconds  percentage
#   open_arm_north   45.2         14.0%
#   open_arm_south   38.7         12.0%
#   closed_arm_east  123.5        38.2%
#   closed_arm_west  89.3         27.7%
#   center           26.2          8.1%

# Zone entries
entries <- calculate_zone_entries(data, arena, body_part = "mouse_center")
# Expected output:
#   zone_id          n_entries  mean_duration
#   open_arm_north   12         3.77
#   open_arm_south   10         3.87
#   closed_arm_east  15         8.23
#   closed_arm_west  14         6.38
#   center           28         0.94

# Zone latency
latency <- calculate_zone_latency(data, arena, body_part = "mouse_center")
# Expected output:
#   zone_id          latency_seconds  first_entry_frame
#   open_arm_north   45.3            1359
#   open_arm_south   12.8            384
#   closed_arm_east  2.1             63
#   closed_arm_west  5.4             162
#   center           0.5             15

# Zone transitions
transitions <- calculate_zone_transitions(data, arena, body_part = "mouse_center")
# Expected output (partial):
#   from_zone        to_zone          n_transitions
#   center           open_arm_north   12
#   center           open_arm_south   10
#   center           closed_arm_east  15
#   open_arm_north   center           11
#   ...
```

---

## Code Standards

- Use roxygen2 for all function documentation
- Follow tidyverse style guide
- Write tests for all new functions (target >80% coverage)
- Use informative variable names
- Add comments for complex logic
- Test with real data from `data/` directory
- Return structured data frames with clear column names
- Include examples in documentation

---

## Git Workflow

Create two commits - one for each task:

```bash
# After Task 2.5
git add R/metrics/zone_analysis.R tests/testthat/test_zone_analysis.R
git commit -m "Implement Phase 2 Task 2.5: Zone analysis functions

- classify_points_by_zone() using existing zone geometry system
- calculate_zone_occupancy() with time and percentage metrics
- Full integration with arena_config system
- Tested with real EPM data
- 80%+ unit test coverage

🤖 Generated with Claude Code
Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"

# After Task 2.6
git add R/metrics/time_in_zone.R tests/testthat/test_time_in_zone.R
git commit -m "Implement Phase 2 Task 2.6: Time in zone functions

- calculate_zone_entries() with min_duration filter
- calculate_zone_exits() for exit counting
- calculate_zone_latency() for first entry time
- calculate_zone_transitions() for transition matrix
- Tested with real EPM data showing arm transitions
- 80%+ unit test coverage

🤖 Generated with Claude Code
Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## After Tasks 2.5 & 2.6, Continue With:

- **Task 2.4**: Distance & speed metrics (skipped for now - less critical)
- **Task 2.7**: Configuration validation
- **Task 3.1**: Open Field paradigm module (uses zone metrics)
- **Task 3.2**: EPM paradigm module (uses zone metrics)

---

## Available Resources

### Documentation
- [docs/REFACTORING_TODO.md](docs/REFACTORING_TODO.md:324-371) - Task 2.5 & 2.6 details
- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md:1) - Design patterns
- [docs/SESSION_HANDOFF.md](docs/SESSION_HANDOFF.md:1) - Arena system completion
- Arena system plan: [docs/ARENA_CONFIGURATION_PLAN.md](docs/ARENA_CONFIGURATION_PLAN.md:1)

### Existing Code (STUDY THESE!)
- [R/core/zone_geometry.R](R/core/zone_geometry.R:1) - **KEY**: Zone creation and point_in_zone()
- [R/core/arena_config.R](R/core/arena_config.R:1) - Arena structure
- [R/core/quality_checks.R](R/core/quality_checks.R:1) - Reference for code style
- [R/core/preprocessing.R](R/core/preprocessing.R:1) - Reference for function patterns

### Test Data
- `data/EPM/Example DLC Data/*.csv` - 4 EPM files (ID7689 tested extensively)
- `config/arena_definitions/*.yaml` - EPM, OF, NORT, LD arena configs

### Helper Scripts
- `test_quality_checks_real_data.R` - Example of testing with real data
- `test_arena_system.R` - Example of arena/zone testing

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

# Run existing tests (should pass 375 tests)
Rscript -e "library(testthat); test_dir('tests/testthat')"

# Create metrics directory if it doesn't exist
mkdir -p R/metrics

# Start implementing
# 1. Create R/metrics/zone_analysis.R
# 2. Create tests/testthat/test_zone_analysis.R
# 3. Test with real EPM data
# 4. Create R/metrics/time_in_zone.R
# 5. Create tests/testthat/test_time_in_zone.R
# 6. Test with real EPM data
```

---

## Critical Implementation Notes

### 1. Don't Recreate Zone Geometry!

The zone geometry system is already implemented and tested. **Use it**:

```r
# GOOD - Use existing system
geometry <- create_zone_geometry(zone_def, arena)
in_zone <- point_in_zone(x, y, geometry)

# BAD - Don't recreate
# Don't write your own point-in-polygon algorithm
# Don't create new zone data structures
```

### 2. Arena Config Structure

Arena configs contain zones like this:

```yaml
zones:
  - id: open_arm_north
    name: "North Open Arm"
    type: points
    point_names: [oa_n_left, oa_n_right, oa_n_tip_right, oa_n_tip_left]
```

Access zones with:
```r
zones <- arena$zones  # List of zone definitions
zone <- get_arena_zone(arena, "open_arm_north")  # Specific zone
```

### 3. Handle Missing Data

Tracking points can have NA coordinates. Handle gracefully:

```r
# Points with NA x or y should have zone_id = NA
# Don't count NA positions as zone entries/exits
```

### 4. Performance Considerations

With 9,688 frames and 39 body parts (377,832 points), efficiency matters:
- Vectorize operations where possible
- Don't loop over every point individually
- Use `point_in_zone()` which is already vectorized

---

## Success Criteria

Tasks 2.5 & 2.6 are complete when:

1. ✅ All 6 functions implemented (2 in zone_analysis.R, 4 in time_in_zone.R)
2. ✅ Functions seamlessly integrate with `arena_config` system
3. ✅ Unit tests achieve >80% coverage for both files
4. ✅ Tested successfully with real EPM data showing realistic metrics
5. ✅ Returns structured, actionable data frames
6. ✅ Documentation complete with examples
7. ✅ Two git commits created

---

**You have everything you need to implement zone entry/exit statistics. Good luck with Phase 2 Tasks 2.5 & 2.6!**

**Remember**:
- Use existing `point_in_zone()` - don't recreate it
- Build `classify_points_by_zone()` first - it's the foundation
- Test with real EPM data throughout development
- The arena configuration system is ready to use

---

**Document Version**: 1.0
**Created**: December 17, 2024
**Previous Session Summary**: Quality check functions completed (Task 2.3)
