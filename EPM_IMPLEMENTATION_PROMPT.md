# AI Agent Prompt: EPM Pipeline Phase 4 Implementation

## Context

You are implementing **Phase 4: EPM (Elevated Plus Maze) Pipeline** for the DLCAnalyzer R package. **Phases 1-3 (LD, OFT, NORT) are complete and working.** EPM has a **different data format** than previous pipelines but can leverage existing functions.

## Project Location

- **Working Directory:** `/mnt/g/Bella/Rebecca/Code/DLCAnalyzer/`
- **Current Branch:** Main development
- **Conda Environment:** `r` (R 4.5.2)

## What Makes EPM Different (CRITICAL)

### 🔴 Key Differences from LD/OFT/NORT:

1. **Data Format:** CSV files with DLCDeepLabCut output (NOT Ethovision Excel)
2. **Coordinates:** Pixel coordinates (NOT cm) - requires conversion
3. **Zone Definition:** NO pre-computed zone columns - must calculate from geometry
4. **Existing Functions:** Many functions in `R/core/` and `R/legacy/` already handle this!

### ✅ What We Can Reuse:

The codebase already has functions for DLC CSV data:
- `R/core/preprocessing.R` - Likelihood filtering, interpolation
- `R/core/data_structures.R` - DLC data structures
- `R/legacy/data_converters.R` - CSV reading functions
- Pixel-to-cm conversion utilities
- Zone geometry calculations

## Your Task

**Create a streamlined EPM pipeline that:**
1. ✅ Leverages existing DLC CSV functions (don't reinvent!)
2. ✅ Matches output format of LD/OFT/NORT pipelines
3. ✅ Removes/refactors any duplicate or unnecessary legacy code
4. ✅ Calculates EPM-specific anxiety metrics

**Goal:** Minimal new code, maximum reuse, clean integration with existing architecture.

---

## EPM-Specific Requirements

### Data Characteristics

**Input Files:**
- **Format:** CSV files from DeepLabCut
- **Location:** `data/EPM/Example DLC Data/EPM 20250930/`, `EPM 20251021/`
- **Structure:**
  - Multiple body parts (nose, center, tail, etc.)
  - Columns: `bodypart_x`, `bodypart_y`, `bodypart_likelihood`
  - Pixel coordinates (NOT cm)
  - Frame-by-frame tracking

**Arena Geometry:**
- 4 arms: 2 open (no walls), 2 closed (with walls)
- Center platform where arms meet
- Standard dimensions (need pixel-to-cm conversion)

### Key Metrics to Calculate

1. **Time in Zones:**
   - Open arms (seconds & %)
   - Closed arms (seconds & %)
   - Center platform (seconds & %)

2. **Anxiety Indices:**
   - **Open arm ratio:** Time_open / (Time_open + Time_closed)
   - **Open arm entries ratio:** Entries_open / Total_entries
   - Lower values = higher anxiety

3. **Risk Assessment:**
   - Head dips (if trackable)
   - Entries to center platform
   - Latency to first open arm entry

4. **Locomotor Activity:**
   - Total distance traveled
   - Velocity (cm/s after pixel conversion)
   - Distance per arm type

---

## Files to Create/Modify

### 1. R/epm/epm_load.R (~250-300 lines)

**Purpose:** Load EPM CSV data and convert to standard format

**Key Functions:**
```r
load_epm_data(file_path, fps = 25, pixels_per_cm = 10, arena_config = NULL)
  # Load DLC CSV
  # Convert pixels to cm
  # Calculate arm zones from geometry
  # Return standard format matching LD/OFT/NORT

standardize_epm_columns(df)
  # Map DLC column names to standard

define_epm_zones(x, y, arena_config)
  # Calculate which arm (open/closed) or center
  # Return zone membership vectors

validate_epm_data(epm_data)
  # Check required body parts
  # Validate likelihood scores

summarize_epm_data(epm_data)
  # Quick stats
```

**Leverage Existing:**
- Use functions from `R/core/preprocessing.R` for likelihood filtering
- Use existing CSV readers if available
- Reuse coordinate transformation utilities

### 2. R/epm/epm_analysis.R (~300-350 lines)

**Purpose:** Calculate EPM anxiety and locomotion metrics

**Key Functions:**
```r
analyze_epm(df, fps = 25, arm_zones, min_exploration = 5)
  # Calculate all EPM metrics
  # Return list matching LD/OFT/NORT format

calculate_open_arm_ratio(time_open, time_closed)
  # Anxiety index

calculate_entries_ratio(entries_open, entries_closed)
  # Behavioral index

analyze_epm_batch(epm_data, fps = 25)
  # Process multiple subjects

export_epm_results(results, output_file)
  # CSV export
```

**Leverage Existing:**
- Reuse zone calculation functions from `R/ld/ld_analysis.R`
- Use `calculate_zone_time()`, `detect_zone_entries()`, etc.
- Adapt distance/velocity from `R/common/geometry.R`

### 3. R/epm/epm_report.R (~300-350 lines)

**Purpose:** Generate EPM reports matching other pipelines

**Key Functions:**
```r
generate_epm_report(epm_data, output_dir, subject_id, fps = 25)
  # Match LD/OFT/NORT report structure

generate_epm_plots(df, results, subject_id)
  # Trajectory with arm boundaries
  # Heatmap
  # Time in zones bar chart

interpret_epm_results(results)
  # Anxiety assessment based on open arm ratio

generate_epm_batch_report(epm_data, output_dir, fps = 25)
  # Batch reports with comparisons
```

**Leverage Existing:**
- Reuse `plot_trajectory()`, `plot_heatmap()` from `R/common/plotting.R`
- Adapt zone occupancy plots
- Follow report format from OFT (similar anxiety paradigm)

### 4. tests/testthat/test-epm-pipeline.R (~400+ lines)

**Test Coverage:**
- CSV loading and pixel conversion
- Zone geometry calculations
- Anxiety index calculations
- Open arm ratio (0-1 range)
- Integration with real EPM data
- Output format consistency with other pipelines

### 5. examples/test_epm_pipeline.R (~100-120 lines)

**Demonstration:**
- Load EPM CSV data
- Calculate anxiety metrics
- Generate reports
- Show open arm ratio interpretation

---

## Critical Implementation Guidelines

### 🔴 PRIORITY 1: Leverage Existing Code

**Before writing new functions, CHECK:**
```r
# Already exists in R/core/ or R/legacy/?
- CSV reading functions
- Pixel-to-cm conversion
- Likelihood filtering
- Data structure definitions
- Coordinate transformations
```

**Strategy:**
1. Audit `R/core/`, `R/legacy/`, `R/utils/` for reusable functions
2. Import/adapt existing functions rather than rewrite
3. Refactor duplicates - consolidate into common functions
4. Remove obsolete code from legacy if fully replaced

### 🟡 PRIORITY 2: Match Output Format

EPM results should match LD/OFT/NORT structure:
```r
# analyze_epm() returns:
list(
  time_in_open_arms_sec = ...,
  time_in_closed_arms_sec = ...,
  pct_time_in_open = ...,
  open_arm_ratio = ...,      # Key anxiety index
  entries_to_open = ...,
  entries_to_closed = ...,
  entries_ratio = ...,
  total_distance_cm = ...,
  avg_velocity_cm_s = ...,
  latency_to_open_sec = ...,
  total_duration_sec = ...
)
```

### 🟢 PRIORITY 3: Zone Geometry

EPM requires calculating zones from coordinates:
```r
# Standard EPM geometry (adjust based on actual arena)
arm_length <- 30  # cm
arm_width <- 5    # cm
center_size <- 5  # cm

# Define arm boundaries
# Arm 1 (North, open): y > center + margin, |x| < arm_width/2
# Arm 2 (East, closed): x > center + margin, |y| < arm_width/2
# etc.

# Calculate zone membership
zone_open_arms <- (in_north_arm | in_south_arm) & !in_center
zone_closed_arms <- (in_east_arm | in_west_arm) & !in_center
zone_center <- sqrt(x^2 + y^2) < center_radius
```

---

## Code Cleanup Priorities

### 🗑️ Remove/Consolidate:

1. **Duplicate CSV readers** - Keep one, remove others
2. **Multiple pixel conversion functions** - Consolidate
3. **Unused legacy functions** - If EPM doesn't need them, document for removal
4. **Redundant zone calculations** - Use shared functions

### ✨ Refactor Opportunities:

1. **Extract common zone logic:**
   ```r
   # Create R/common/zones.R if not exists
   calculate_zone_membership(x, y, zone_geometry)
   ```

2. **Standardize data loaders:**
   ```r
   # Generic loader that handles both Ethovision and DLC
   load_behavioral_data(file_path, format = c("ethovision", "dlc"))
   ```

3. **Unified preprocessing:**
   ```r
   # Common pipeline: load → filter → convert → analyze
   preprocess_tracking_data(raw_data, likelihood_threshold, pixels_per_cm)
   ```

---

## Testing Strategy

### Phase 1: Data Loading
```bash
# 1. Find EPM CSV files
find data/EPM -name "*.csv"

# 2. Load and inspect
Rscript -e "
source('R/epm/epm_load.R')
source('R/core/preprocessing.R')
epm_data <- load_epm_data('data/EPM/.../file.csv', fps = 25)
str(epm_data)
"

# 3. Check coordinate conversion
# Verify pixel → cm conversion
# Validate zone assignments
```

### Phase 2: Analysis
```bash
# 4. Calculate metrics
Rscript -e "
results <- analyze_epm(epm_data$data, fps = 25)
print(results$open_arm_ratio)  # Should be 0-1
print(results$entries_ratio)   # Should be 0-1
"
```

### Phase 3: Integration
```bash
# 5. Run full pipeline
Rscript examples/test_epm_pipeline.R

# 6. Compare output format with OFT
# Should have similar structure for consistency
```

---

## Expected Output Format

### Console Output:
```r
EPM Analysis Results - Subject 1:
  Open Arm Ratio: 0.35 (moderate anxiety)
  Entries Ratio: 0.42
  Time in Open Arms: 52.3 sec (17.4%)
  Time in Closed Arms: 97.2 sec (32.4%)
  Time in Center: 20.1 sec (6.7%)
  Total Distance: 2847.3 cm
```

### CSV Export:
```
subject_id,open_arm_ratio,entries_ratio,time_open_sec,time_closed_sec,distance_cm
Subject_1,0.35,0.42,52.3,97.2,2847.3
```

### Report Files:
- `Subject_1_trajectory.png` - Path with arm boundaries overlaid
- `Subject_1_heatmap.png` - Position density
- `Subject_1_zone_time.png` - Bar chart: open vs closed vs center
- `Subject_1_metrics.csv` - All numeric results
- `Subject_1_summary.txt` - Text interpretation

---

## Key Validation Checks

### Data Quality:
- [ ] All likelihood scores > 0.9 (or filter low confidence)
- [ ] Coordinate ranges match expected arena size
- [ ] No excessive NAs after pixel conversion
- [ ] Zone assignments sum correctly (no overlaps)

### Metric Validity:
- [ ] Open arm ratio between 0 and 1
- [ ] Entries ratio between 0 and 1
- [ ] Time percentages sum to ~100%
- [ ] Distance and velocity reasonable
- [ ] Latencies < total duration

### Consistency:
- [ ] Output format matches LD/OFT/NORT
- [ ] Column names consistent across paradigms
- [ ] Plot styles match other pipelines
- [ ] Documentation follows established patterns

---

## Documentation Requirements

### QUICKSTART_EPM.md Structure:
```markdown
# Quick Start: EPM Analysis

## Data Format Note
EPM uses CSV files from DeepLabCut (not Ethovision Excel like LD/OFT/NORT)

## Loading Data
`load_epm_data()` handles:
- CSV reading
- Pixel-to-cm conversion
- Zone calculation from geometry

## Key Metrics
- Open arm ratio: Primary anxiety measure
- Lower values = higher anxiety
- Typical range: 0.2-0.5 for normal mice

## Example Workflow
[Include complete example]
```

---

## Common Pitfalls to Avoid

1. **Don't duplicate CSV readers** - Use existing functions
2. **Don't hardcode arena dimensions** - Make configurable
3. **Don't forget pixel conversion** - Consistent units with other pipelines
4. **Don't reinvent zone calculations** - Reuse from ld_analysis.R
5. **Don't skip likelihood filtering** - DLC data needs quality control

---

## Success Criteria

Your EPM implementation is complete when:
- [ ] Loads DLC CSV files correctly
- [ ] Converts pixels to cm accurately
- [ ] Calculates arm zones from geometry
- [ ] Computes anxiety indices (open arm ratio, entries ratio)
- [ ] Output format matches LD/OFT/NORT structure
- [ ] Generates plots and reports like other pipelines
- [ ] Tests pass with real EPM data
- [ ] Documentation complete (QUICKSTART_EPM.md)
- [ ] Legacy/duplicate code identified for cleanup
- [ ] Example script runs successfully

---

## Quick Reference: Existing Functions to Use

### From R/core/preprocessing.R:
- `filter_low_confidence()` - Remove low likelihood points
- `interpolate_missing()` - Fill gaps in tracking
- `smooth_trajectory()` - Reduce jitter

### From R/common/geometry.R:
- Distance and velocity calculations

### From R/ld/ld_analysis.R:
- `calculate_zone_time()`
- `detect_zone_entries()`
- `calculate_zone_latency()`

### From R/common/plotting.R:
- `plot_trajectory()`
- `plot_heatmap()`
- `plot_zone_occupancy()`

---

## Getting Started Commands

```bash
# 1. Activate environment
conda activate r

# 2. Create EPM directory
mkdir -p R/epm

# 3. Find test data
find data/EPM -name "*.csv" | head -5

# 4. Inspect CSV structure
head -20 data/EPM/.../[first_file].csv

# 5. Check existing functions
grep -r "read.*csv" R/core/ R/legacy/
grep -r "pixel" R/

# 6. Start with epm_load.R
# Import necessary functions
# Implement load_epm_data()
# Test with one file
```

---

## Key Questions to Answer During Implementation

1. **What's the CSV structure?** (header rows, column names)
2. **Which body part to use?** (nose, center, tail-base?)
3. **Pixels per cm ratio?** (may need calibration from arena size)
4. **Arm dimensions?** (length, width in cm)
5. **Existing functions available?** (audit R/core/, R/legacy/)

---

**Remember:** This is about **integration and cleanup**, not wholesale rewriting. Use what exists, adapt it to match the EPM paradigm, and clean up legacy code along the way.

Good luck! The architecture from LD/OFT/NORT is proven - EPM should slot in smoothly with the right data transformations. 🚀
