# AI Agent Starting Prompt for DLCAnalyzer - Session 6

## Copy and paste this prompt to start your session:

---

Hello! I'm continuing the DLCAnalyzer R package refactoring. This is a behavioral analysis tool for processing animal tracking data from DeepLabCut AND Ethovision.

**Project Location**: `/mnt/g/Bella/Rebecca/Code/DLCAnalyzer`

**Current Status**: Phase 2 Tasks 2.5, 2.6, 2.10 & 2.11 Complete
**Your Task**: Implement Ethovision data loading and cross-validate with DLC data (Tasks 2.7-2.9 with Ethovision focus)

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
- Coordinate transformations ([R/core/coordinate_transforms.R](R/core/coordinate_transforms.R:1))
- 62 unit tests, all passing

### ✅ Phase 2 Tasks 2.1, 2.3, 2.5, 2.6 (COMPLETE)
- Preprocessing functions: filtering, interpolation, smoothing ([R/core/preprocessing.R](R/core/preprocessing.R:1))
- Quality check functions ([R/core/quality_checks.R](R/core/quality_checks.R:1))
- Zone analysis functions ([R/metrics/zone_analysis.R](R/metrics/zone_analysis.R:1))
- Time in zone metrics ([R/metrics/time_in_zone.R](R/metrics/time_in_zone.R:1))
- Total: 295 unit tests passing

### ✅ Phase 2 Tasks 2.10 & 2.11 (COMPLETE)
- **Test Infrastructure** ([tests/testthat/setup.R](tests/testthat/setup.R:1), [tests/README.md](tests/README.md:1))
  - Automatic sourcing of all R files before tests
  - No manual sourcing required
  - 534 unit tests passing

- **Integration Tests** ([tests/integration/](tests/integration/))
  - EPM: Complete end-to-end pipeline tests (5 test cases, all passing)
  - OFT, NORT, LD: Placeholder tests ready for data

**Total Progress**: ~27-30% of project
**Total Tests Passing**: 534 unit tests + 36 integration test assertions

---

## Your Starting Point: Ethovision Integration & Cross-Validation

You have FOUR interconnected priority areas:

### Priority 1: Implement Ethovision Data Loading (NEW CRITICAL TASK)

**Problem**: We have Ethovision Excel data for OFT, NORT, and LD paradigms but no way to load it into our `tracking_data` format.

**Available Ethovision Data**:
- **OFT**: 3 files in `data/OFT/Example Exported Data/`
  - `Raw data-Rebecca OF Oct20th2025-Trial     1.xlsx`
  - `Raw data-Rebecca OF Oct20th2025-Trial     2.xlsx`
  - `Raw data-Rebecca OF Oct20th2025-Trial     3.xlsx`

- **NORT**: 4 files in `data/NORT/Example Exported Data/`
  - `Raw data-NORT D3 20251003-Trial     1 (1).xlsx`
  - `Raw data-NORT D3 20251003-Trial     2 (1).xlsx`
  - `Raw data-NORT D3 20251003-Trial     3 (1).xlsx`
  - `Raw data-NORT D3 20251003-Trial     4 (1).xlsx`

- **LD**: 3 files in `data/LD/Example Exported Data/`
  - `Raw data-LD Rebecca 20251022-Trial     1.xlsx`
  - `Raw data-LD Rebecca 20251022-Trial     2.xlsx`
  - `Raw data-LD Rebecca 20251022-Trial     3.xlsx`

**File to create**: `R/core/ethovision_loading.R`

**Key Functions to Implement**:

```r
#' Load Ethovision Excel export file
#'
#' Reads Ethovision XT exported Excel files and extracts tracking data.
#' Ethovision files typically have metadata rows at the top, then a header row,
#' then the actual data.
#'
#' @param file_path Path to Ethovision Excel file (.xlsx)
#' @param body_part Name to assign to this tracking point (default: "center_point")
#' @param fps Frames per second (will attempt to extract from metadata if NULL)
#' @param paradigm Experimental paradigm (e.g., "open_field", "nort", "light_dark")
#' @param skip_rows Number of metadata rows to skip before finding header (default: auto-detect)
#'
#' @return A data frame with columns: frame, time, x, y, and metadata
#'
#' @details
#' Ethovision Excel files typically have this structure:
#' - Rows 1-N: Metadata (Trial Control, Arena Settings, etc.)
#' - Row N+1: Column headers (Trial time, Recording time, X center, Y center, etc.)
#' - Rows N+2+: Actual tracking data
#'
#' The function auto-detects the header row by looking for common Ethovision column names.
#'
#' @export
load_ethovision_excel <- function(file_path, body_part = "center_point",
                                  fps = NULL, paradigm = NULL,
                                  skip_rows = NULL) {
  # 1. Read Excel file using readxl::read_excel()
  # 2. Auto-detect metadata vs data sections
  # 3. Extract fps from metadata if present
  # 4. Parse tracking columns (typically "X center", "Y center", "Trial time")
  # 5. Return data frame with standardized column names
}

#' Convert Ethovision data to tracking_data object
#'
#' Converts raw Ethovision data to the internal tracking_data S3 class format.
#'
#' @param ethovision_data Data frame from load_ethovision_excel()
#' @param fps Frames per second
#' @param subject_id Subject identifier
#' @param paradigm Experimental paradigm
#' @param session_id Optional session identifier
#' @param body_part Body part name (default: "center_point")
#'
#' @return A tracking_data S3 object
#'
#' @export
convert_ethovision_to_tracking_data <- function(ethovision_data, fps,
                                                subject_id = NULL,
                                                paradigm = NULL,
                                                session_id = NULL,
                                                body_part = "center_point") {
  # Create tracking_data object compatible with our existing pipeline
  # Use new_tracking_data() constructor
  # Format: frame, time, body_part, x, y, likelihood (set to 1.0 for Ethovision)
}
```

**Implementation Notes**:
- Use `readxl` package for reading Excel files (already in dependencies)
- Ethovision typically tracks a single center point, not multiple body parts
- Set `likelihood = 1.0` for all Ethovision data (it's deterministic tracking)
- Extract metadata from top rows: fps, arena dimensions, trial duration, etc.
- Common Ethovision column names:
  - "Trial time" or "Recording time" → `time`
  - "X center" or "Center-point X" → `x`
  - "Y center" or "Center-point Y" → `y`

**Testing Strategy**:
Create `tests/testthat/test_ethovision_loading.R`:

```r
test_that("Ethovision Excel files load correctly", {
  # Use actual OFT file as test
  oft_file <- "data/OFT/Example Exported Data/Raw data-Rebecca OF Oct20th2025-Trial     1.xlsx"

  skip_if(!file.exists(oft_file), "OFT data file not found")

  etho_data <- load_ethovision_excel(oft_file, paradigm = "open_field")

  expect_true(is.data.frame(etho_data))
  expect_true("frame" %in% colnames(etho_data))
  expect_true("time" %in% colnames(etho_data))
  expect_true("x" %in% colnames(etho_data))
  expect_true("y" %in% colnames(etho_data))
  expect_gt(nrow(etho_data), 0)
})

test_that("Ethovision data converts to tracking_data format", {
  oft_file <- "data/OFT/Example Exported Data/Raw data-Rebecca OF Oct20th2025-Trial     1.xlsx"
  skip_if(!file.exists(oft_file), "OFT data file not found")

  etho_data <- load_ethovision_excel(oft_file)
  tracking_data <- convert_ethovision_to_tracking_data(
    etho_data,
    fps = 30,  # or extract from metadata
    subject_id = "OFT_01",
    paradigm = "open_field"
  )

  expect_s3_class(tracking_data, "tracking_data")
  expect_true("center_point" %in% unique(tracking_data$tracking$body_part))
  expect_equal(tracking_data$tracking$likelihood, rep(1.0, nrow(tracking_data$tracking)))
})
```

---

### Priority 2: Update Integration Tests with Ethovision Data

**Update**: `tests/integration/test_oft_real_data.R`

Add tests for Ethovision Excel files:

```r
test_that("OFT Ethovision data loads and processes correctly", {
  oft_dir <- file.path(pkg_root, "data/OFT/Example Exported Data")

  skip_if(!dir.exists(oft_dir), "OFT data directory not found")

  oft_files <- list.files(oft_dir, pattern = "\\.xlsx$", full.names = TRUE)

  skip_if(length(oft_files) == 0, "No OFT Excel files found")

  cat("\nTesting", length(oft_files), "OFT Ethovision files\n")

  for (file_path in oft_files) {
    cat("  Loading:", basename(file_path), "\n")

    etho_data <- load_ethovision_excel(file_path, paradigm = "open_field")
    tracking_data <- convert_ethovision_to_tracking_data(
      etho_data,
      fps = 30,
      subject_id = basename(file_path),
      paradigm = "open_field"
    )

    expect_s3_class(tracking_data, "tracking_data")
    expect_gt(nrow(tracking_data$tracking), 0)

    cat("    - Frames:", nrow(tracking_data$tracking), "\n")
    cat("    - Duration:", max(tracking_data$tracking$time), "seconds\n")
  }
})
```

**Similarly update**:
- `tests/integration/test_nort_real_data.R`
- `tests/integration/test_ld_real_data.R`

---

### Priority 3: Cross-Validation Testing (CRITICAL FOR SCIENTIFIC VALIDITY)

**Problem**: We need to ensure that data from Ethovision and DLC produce comparable results when analyzing the same behavior.

**File to create**: `tests/integration/test_cross_validation.R`

**What to test**:

```r
#' Cross-validation test comparing DLC and Ethovision data
#'
#' This test ensures that our analysis pipeline produces comparable results
#' regardless of whether data comes from DLC or Ethovision.
#'
#' We can't test on the SAME subject (we don't have both DLC and Ethovision
#' for the same animal), but we can test that:
#' 1. Both data types load into the same tracking_data format
#' 2. Zone analysis works with both
#' 3. Metrics are calculated correctly for both
#' 4. Results are in the same ballpark (similar ranges and distributions)

test_that("DLC and Ethovision data are compatible with analysis pipeline", {
  # Load EPM data from DLC
  epm_dlc_file <- "data/EPM/Example DLC Data/ID7689...csv"
  skip_if(!file.exists(epm_dlc_file), "EPM DLC data not found")

  dlc_data <- convert_dlc_to_tracking_data(epm_dlc_file, fps = 30, paradigm = "epm")

  # Load OFT data from Ethovision
  oft_etho_file <- "data/OFT/Example Exported Data/Raw data-Rebecca OF Oct20th2025-Trial     1.xlsx"
  skip_if(!file.exists(oft_etho_file), "OFT Ethovision data not found")

  etho_data <- load_ethovision_excel(oft_etho_file)
  ethovision_tracking <- convert_ethovision_to_tracking_data(
    etho_data,
    fps = 30,
    paradigm = "open_field"
  )

  # Both should have the same structure
  expect_equal(class(dlc_data), class(ethovision_tracking))
  expect_equal(names(dlc_data), names(ethovision_tracking))
  expect_equal(colnames(dlc_data$tracking), colnames(ethovision_tracking$tracking))

  # Both should work with quality checks
  dlc_quality <- check_tracking_quality(dlc_data)
  etho_quality <- check_tracking_quality(ethovision_tracking)

  expect_equal(names(dlc_quality), names(etho_quality))

  cat("\n=== Cross-Validation Results ===\n")
  cat("DLC Data:\n")
  cat("  - Frames:", nrow(dlc_data$tracking), "\n")
  cat("  - Body parts:", length(unique(dlc_data$tracking$body_part)), "\n")
  cat("  - Mean likelihood:", mean(dlc_data$tracking$likelihood, na.rm = TRUE), "\n")

  cat("\nEthovision Data:\n")
  cat("  - Frames:", nrow(ethovision_tracking$tracking), "\n")
  cat("  - Body parts:", length(unique(ethovision_tracking$tracking$body_part)), "\n")
  cat("  - Mean likelihood:", mean(ethovision_tracking$tracking$likelihood, na.rm = TRUE), "\n")
})

test_that("Zone analysis produces comparable results for both data types", {
  # This test ensures that zone occupancy calculations work correctly
  # for both DLC multi-body-part data and Ethovision single-point data

  # Load EPM DLC data with arena
  epm_dlc_file <- "data/EPM/Example DLC Data/ID7689...csv"
  epm_arena <- load_arena_configs("config/arena_definitions/EPM/EPM.yaml", "arena1")
  skip_if(!file.exists(epm_dlc_file), "EPM DLC data not found")

  dlc_data <- convert_dlc_to_tracking_data(epm_dlc_file, fps = 30)
  dlc_occupancy <- calculate_zone_occupancy(dlc_data, epm_arena, body_part = "mouse_center")

  # Load OFT Ethovision data with arena (need to create OF arena config!)
  oft_etho_file <- "data/OFT/Example Exported Data/Raw data-Rebecca OF Oct20th2025-Trial     1.xlsx"
  skip_if(!file.exists(oft_etho_file), "OFT Ethovision data not found")

  # TODO: Create config/arena_definitions/OF/of_standard.yaml first!
  skip("Need to create OF arena configuration")

  # When arena config is available:
  # oft_arena <- load_arena_configs("config/arena_definitions/OF/of_standard.yaml", "arena1")
  # etho_data <- load_ethovision_excel(oft_etho_file)
  # ethovision_tracking <- convert_ethovision_to_tracking_data(etho_data, fps = 30)
  # etho_occupancy <- calculate_zone_occupancy(ethovision_tracking, oft_arena, body_part = "center_point")

  # Both should produce data frames with same structure
  # expect_equal(colnames(dlc_occupancy), colnames(etho_occupancy))
  # expect_true(all(dlc_occupancy$percentage >= 0 & dlc_occupancy$percentage <= 100))
  # expect_true(all(etho_occupancy$percentage >= 0 & etho_occupancy$percentage <= 100))
})

test_that("Preprocessing works identically for both data types", {
  # Test that smoothing, interpolation, filtering work the same way
  # This is important because Ethovision data has likelihood = 1.0
  # while DLC data has variable likelihood

  # DLC data
  epm_dlc_file <- "data/EPM/Example DLC Data/ID7689...csv"
  skip_if(!file.exists(epm_dlc_file), "EPM DLC data not found")
  dlc_data <- convert_dlc_to_tracking_data(epm_dlc_file, fps = 30)

  # Ethovision data
  oft_etho_file <- "data/OFT/Example Exported Data/Raw data-Rebecca OF Oct20th2025-Trial     1.xlsx"
  skip_if(!file.exists(oft_etho_file), "OFT Ethovision data not found")
  etho_data <- load_ethovision_excel(oft_etho_file)
  ethovision_tracking <- convert_ethovision_to_tracking_data(etho_data, fps = 30)

  # Both should survive preprocessing
  dlc_smoothed <- smooth_trajectory(dlc_data, body_part = "mouse_center", method = "savgol")
  etho_smoothed <- smooth_trajectory(ethovision_tracking, body_part = "center_point", method = "savgol")

  expect_s3_class(dlc_smoothed, "tracking_data")
  expect_s3_class(etho_smoothed, "tracking_data")

  # Neither should introduce NAs where there weren't any
  expect_equal(
    sum(is.na(dlc_data$tracking$x)),
    sum(is.na(dlc_smoothed$tracking$x))
  )
  expect_equal(
    sum(is.na(ethovision_tracking$tracking$x)),
    sum(is.na(etho_smoothed$tracking$x))
  )
})
```

**Documentation to create**: `docs/ETHOVISION_DLC_COMPARISON.md`

Document the differences and compatibility:

```markdown
# Ethovision vs DLC Data Comparison

## Data Source Differences

| Feature | DLC | Ethovision |
|---------|-----|------------|
| **Tracking Method** | Pose estimation (deep learning) | Video tracking (centroid/threshold) |
| **Body Parts** | Multiple (nose, tail, center, limbs, etc.) | Single point (usually center) |
| **Confidence Score** | Yes (likelihood 0-1) | No (deterministic) |
| **Output Format** | CSV (multi-column) | Excel (structured metadata + data) |
| **Data Quality** | Variable (depends on model & video quality) | High (but only tracks visible subjects) |
| **Typical Use Case** | Detailed pose/movement analysis | General behavior/zone occupancy |

## DLCAnalyzer Compatibility

Both data types are converted to the same internal `tracking_data` format:

- **DLC data**: Multiple body parts with likelihood scores
- **Ethovision data**: Single body part ("center_point") with likelihood = 1.0

## Analysis Compatibility

✅ **Compatible**:
- Zone occupancy calculations
- Time in zone metrics
- Distance and speed calculations
- Trajectory smoothing and interpolation
- Quality checks

⚠️ **Different**:
- DLC: Can analyze specific body parts (nose trajectory, tail movement, etc.)
- Ethovision: Only center point available

## Best Practices

1. **Use DLC when**: You need detailed pose information or tracking of specific body parts
2. **Use Ethovision when**: You need high-confidence center-point tracking for zone analysis
3. **Both are valid**: For basic zone occupancy and locomotion metrics
4. **Cross-validate**: When possible, compare results from both systems on same paradigm
```

---

### Priority 4: Create Arena Configurations for OFT, NORT, LD

**Files to create**:

1. **`config/arena_definitions/OF/of_standard.yaml`**

```yaml
arenas:
  - id: arena1
    name: "Open Field Standard"
    image: null
    points:
      # Define outer boundary of open field (typically square or circular)
      top_left: [50, 50]
      top_right: [550, 50]
      bottom_right: [550, 550]
      bottom_left: [50, 550]

    zones:
      # Entire open field
      - id: field
        name: "Entire Field"
        type: points
        point_names: ["top_left", "top_right", "bottom_right", "bottom_left"]

      # Center zone (typically 50% of total area, or 25% in each dimension)
      - id: center
        name: "Center Zone"
        type: proportion
        parent_zone: field
        proportion: [0.25, 0.25, 0.75, 0.75]  # Central 50% x 50%

      # Periphery (inverse of center)
      - id: periphery
        name: "Periphery"
        type: proportion
        parent_zone: field
        proportion: [0, 0, 1, 1]  # Will be calculated as field - center
        exclude_zones: ["center"]

    scale: null
    metadata:
      paradigm: open_field
      units: pixels
      description: "Standard open field arena with center and periphery zones"
```

2. **`config/arena_definitions/NORT/nort_standard.yaml`**

```yaml
arenas:
  - id: arena1
    name: "Novel Object Recognition Test"
    image: null
    points:
      # Define arena boundary
      top_left: [50, 50]
      top_right: [550, 50]
      bottom_right: [550, 550]
      bottom_left: [50, 550]

      # Object locations (example - adjust based on actual setup)
      object1_center: [200, 300]
      object2_center: [400, 300]

    zones:
      # Entire arena
      - id: arena
        name: "Entire Arena"
        type: points
        point_names: ["top_left", "top_right", "bottom_right", "bottom_left"]

      # Object 1 zone (familiar object)
      - id: object1_zone
        name: "Object 1 Zone"
        type: circle
        center_point: object1_center
        radius: 50  # pixels, adjust as needed

      # Object 2 zone (novel object)
      - id: object2_zone
        name: "Object 2 Zone"
        type: circle
        center_point: object2_center
        radius: 50

      # Center zone (area between objects)
      - id: center
        name: "Center Zone"
        type: proportion
        parent_zone: arena
        proportion: [0.3, 0.3, 0.7, 0.7]

    scale: null
    metadata:
      paradigm: novel_object_recognition
      units: pixels
      description: "NORT arena with two object zones"
      notes: "Object positions should be updated based on actual experimental setup"
```

3. **`config/arena_definitions/LD/ld_standard.yaml`**

```yaml
arenas:
  - id: arena1
    name: "Light/Dark Box"
    image: null
    points:
      # Light box (typically one half)
      light_top_left: [50, 50]
      light_top_right: [300, 50]
      light_bottom_right: [300, 550]
      light_bottom_left: [50, 550]

      # Dark box (other half)
      dark_top_left: [300, 50]
      dark_top_right: [550, 50]
      dark_bottom_right: [550, 550]
      dark_bottom_left: [300, 550]

      # Door/opening between compartments
      door_top: [300, 250]
      door_bottom: [300, 350]

    zones:
      # Light compartment
      - id: light
        name: "Light Compartment"
        type: points
        point_names: ["light_top_left", "light_top_right", "light_bottom_right", "light_bottom_left"]

      # Dark compartment
      - id: dark
        name: "Dark Compartment"
        type: points
        point_names: ["dark_top_left", "dark_top_right", "dark_bottom_right", "dark_bottom_left"]

      # Transition zone (door area)
      - id: transition
        name: "Transition Zone"
        type: rectangle
        x_min: 280
        x_max: 320
        y_min: 230
        y_max: 370

    scale: null
    metadata:
      paradigm: light_dark
      units: pixels
      description: "Light/Dark box with two compartments"
      notes: "Adjust dimensions based on actual apparatus"
```

---

## Suggested Implementation Order

### Session Start (15 min)
1. Verify current state: run unit and integration tests
2. Review git log and status
3. Examine one Ethovision Excel file to understand structure

### Task 1: Ethovision Data Loading (3-4 hours) - DO THIS FIRST
1. Examine Ethovision Excel file structure manually
2. Create `R/core/ethovision_loading.R`
3. Implement `load_ethovision_excel()`
4. Implement `convert_ethovision_to_tracking_data()`
5. Create tests in `tests/testthat/test_ethovision_loading.R`
6. Test with all 3 OFT Excel files
7. Commit: "Implement Ethovision Excel data loading"

### Task 2: Arena Configurations (1-2 hours)
1. Create `config/arena_definitions/OF/of_standard.yaml`
2. Create `config/arena_definitions/NORT/nort_standard.yaml`
3. Create `config/arena_definitions/LD/ld_standard.yaml`
4. Test loading each configuration
5. Commit: "Add arena configurations for OFT, NORT, and LD paradigms"

### Task 3: Update Integration Tests (2-3 hours)
1. Update `tests/integration/test_oft_real_data.R` with Ethovision tests
2. Update `tests/integration/test_nort_real_data.R` with Ethovision tests
3. Update `tests/integration/test_ld_real_data.R` with Ethovision tests
4. Run all integration tests with real data
5. Commit: "Update integration tests with Ethovision data"

### Task 4: Cross-Validation Testing (2-3 hours)
1. Create `tests/integration/test_cross_validation.R`
2. Implement structure comparison tests
3. Implement quality check compatibility tests
4. Implement preprocessing compatibility tests
5. Create `docs/ETHOVISION_DLC_COMPARISON.md`
6. Run cross-validation tests
7. Commit: "Add cross-validation tests for DLC and Ethovision data compatibility"

---

## Validation Checklist

### Ethovision Loading Complete When:
- [ ] `R/core/ethovision_loading.R` exists with both functions
- [ ] Can load all 3 OFT Excel files successfully
- [ ] Can load all 4 NORT Excel files successfully
- [ ] Can load all 3 LD Excel files successfully
- [ ] Converts to `tracking_data` S3 class correctly
- [ ] Unit tests pass (at least 20 new tests)
- [ ] Git commit created

### Arena Configurations Complete When:
- [ ] OF arena config loads successfully
- [ ] NORT arena config loads successfully
- [ ] LD arena config loads successfully
- [ ] All zones are properly defined
- [ ] Coordinates are reasonable for typical video dimensions
- [ ] Git commit created

### Integration Tests Complete When:
- [ ] OFT integration tests work with Ethovision data
- [ ] NORT integration tests work with Ethovision data
- [ ] LD integration tests work with Ethovision data
- [ ] Can calculate zone occupancy for all paradigms
- [ ] Can calculate time in zone metrics
- [ ] All integration tests pass
- [ ] Git commit created

### Cross-Validation Complete When:
- [ ] DLC and Ethovision data have same `tracking_data` structure
- [ ] Both work with all analysis functions
- [ ] Quality checks work for both
- [ ] Preprocessing works for both
- [ ] Zone analysis works for both
- [ ] Documentation explains differences and compatibility
- [ ] All cross-validation tests pass
- [ ] Git commit created

---

## Important Implementation Notes

### Ethovision Excel File Structure

Typical Ethovision file layout:
```
Row 1-10: Metadata (Trial name, arena name, animal ID, etc.)
Row 11: Column headers
Row 12+: Data

Common columns:
- "Trial time" - Time since trial start (seconds)
- "Recording time" - Absolute recording time
- "X center" - X coordinate of center point
- "Y center" - Y coordinate of center point
- "Area" - Size of tracked subject
- "Velocity" - Movement speed
- "Distance moved" - Cumulative distance
```

**Auto-detection strategy**:
1. Read first 50 rows
2. Look for row containing "Trial time" or "Recording time"
3. That's your header row
4. Everything above is metadata
5. Everything below is data

### Handling Missing Data

- **DLC**: Low confidence points may be set to NA
- **Ethovision**: Missing data when subject not detected (outside arena, hiding, etc.)
- **Solution**: Both should use same interpolation/filtering pipeline

### Coordinate Systems

- **DLC**: Origin typically top-left, Y increases downward
- **Ethovision**: Origin can be configured, check metadata
- **Solution**: May need coordinate transformation based on arena config

### FPS Extraction

Ethovision metadata may contain:
- "Sample rate" or "Frame rate"
- "Acquisition rate"

Extract this if possible, otherwise require user to specify.

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

# Run existing tests (should pass 534 unit tests)
Rscript -e "library(testthat); test_dir('tests/testthat')"

# Run EPM integration tests
Rscript tests/integration/test_epm_real_data.R

# After implementing Ethovision loading:
Rscript -e "library(testthat); test_file('tests/testthat/test_ethovision_loading.R')"

# Run OFT integration tests
Rscript tests/integration/test_oft_real_data.R
```

---

## Expected Outcomes

After completing this session, you should be able to:

```r
# Load Ethovision data
library(readxl)
oft_data <- load_ethovision_excel(
  "data/OFT/Example Exported Data/Raw data-Rebecca OF Oct20th2025-Trial     1.xlsx"
)

# Convert to tracking_data
tracking <- convert_ethovision_to_tracking_data(
  oft_data,
  fps = 30,
  subject_id = "OFT_Trial1",
  paradigm = "open_field"
)

# Load arena
oft_arena <- load_arena_configs(
  "config/arena_definitions/OF/of_standard.yaml",
  arena_id = "arena1"
)

# Analyze
occupancy <- calculate_zone_occupancy(tracking, oft_arena, body_part = "center_point")
entries <- calculate_zone_entries(tracking, oft_arena, body_part = "center_point")

# Results:
# occupancy shows time in center vs periphery
# entries shows number of center entries and latency

# Cross-validate with DLC data
epm_dlc <- convert_dlc_to_tracking_data("data/EPM/.../ID7689.csv", fps = 30)
epm_arena <- load_arena_configs("config/arena_definitions/EPM/EPM.yaml", "arena1")

dlc_occupancy <- calculate_zone_occupancy(epm_dlc, epm_arena, body_part = "mouse_center")
etho_occupancy <- calculate_zone_occupancy(tracking, oft_arena, body_part = "center_point")

# Both should have same column structure:
# zone_id, n_frames, time_seconds, percentage
```

---

## Available Resources

### Documentation
- [docs/REFACTORING_TODO.md](docs/REFACTORING_TODO.md:1) - Full task list
- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md:1) - Design principles
- [tests/README.md](tests/README.md:1) - Testing guide

### Existing Code
- [R/core/data_structures.R](R/core/data_structures.R:1) - tracking_data S3 class
- [R/core/data_loading.R](R/core/data_loading.R:1) - DLC loading functions
- [R/core/data_converters.R](R/core/data_converters.R:1) - DLC conversion
- [R/metrics/zone_analysis.R](R/metrics/zone_analysis.R:1) - Zone analysis
- [R/metrics/time_in_zone.R](R/metrics/time_in_zone.R:1) - Time metrics

### Test Data
- **EPM (DLC)**: `data/EPM/Example DLC Data/*.csv` (4 files, fully tested)
- **OFT (Ethovision)**: `data/OFT/Example Exported Data/*.xlsx` (3 files, ready to use)
- **NORT (Ethovision)**: `data/NORT/Example Exported Data/*.xlsx` (4 files, ready to use)
- **LD (Ethovision)**: `data/LD/Example Exported Data/*.xlsx` (3 files, ready to use)

### Arena Configs (Existing)
- `config/arena_definitions/EPM/EPM.yaml` (complete, tested)

### Arena Configs (To Create)
- `config/arena_definitions/OF/of_standard.yaml`
- `config/arena_definitions/NORT/nort_standard.yaml`
- `config/arena_definitions/LD/ld_standard.yaml`

---

## Success Metrics

- ✅ Can load all 10 Ethovision Excel files (3 OFT + 4 NORT + 3 LD)
- ✅ All data converts to `tracking_data` format successfully
- ✅ Arena configurations load for all 3 new paradigms
- ✅ Zone analysis works with Ethovision data
- ✅ Integration tests pass for OFT, NORT, and LD
- ✅ Cross-validation tests confirm DLC and Ethovision compatibility
- ✅ Documentation explains differences between data sources
- ✅ At least 50 new unit tests passing
- ✅ At least 3 new integration test files with real data

---

**You have everything you need to integrate Ethovision data! This is a critical milestone that will enable analysis of all available experimental data, not just DLC-tracked sessions. Focus on data compatibility and scientific validity through cross-validation. Good luck!**

**Document Version**: 1.0
**Created**: December 18, 2024
**Previous Session**: Tasks 2.10 & 2.11 completed (Test infrastructure and EPM integration tests)
**Next Priority**: Ethovision data integration with cross-validation testing
