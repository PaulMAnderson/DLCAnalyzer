# AI Agent Prompt: DLCAnalyzer Phase 3 Implementation

## Context

You are continuing work on the DLCAnalyzer R package redesign. **Phase 1 (LD Pipeline) and Phase 2 (OFT Pipeline) are complete and working.** You are now implementing **Phase 3: NORT (Novel Object Recognition Test) Pipeline**.

## Project Location

- **Working Directory:** `/mnt/g/Bella/Rebecca/Code/DLCAnalyzer/`
- **Current Branch:** Main development
- **Conda Environment:** `r` (R 4.5.2)

## What Has Been Done (Phases 1 & 2)

✅ **Phase 1 - LD Pipeline (Complete):**
- R/common/io.R - Enhanced Ethovision reader with zone extraction
- R/common/geometry.R - Distance and velocity calculations
- R/common/plotting.R - Trajectory, heatmap, zone occupancy plots
- R/ld/ld_load.R - LD data loading with multi-arena support
- R/ld/ld_analysis.R - LD metrics (time, entries, latency, distance)
- R/ld/ld_report.R - LD report generation
- tests/testthat/test-ld-pipeline.R - Comprehensive LD tests
- ~2,515 lines of working code

✅ **Phase 2 - OFT Pipeline (Complete):**
- R/oft/oft_load.R - OFT data loading with zone extraction
- R/oft/oft_analysis.R - OFT metrics (center/periphery time, thigmotaxis)
- R/oft/oft_report.R - OFT report generation with behavioral interpretation
- tests/testthat/test-oft-pipeline.R - Comprehensive OFT tests
- ~1,744 lines of working code

✅ **Key Architectural Achievements:**
- Paradigm-first design (zone detection is paradigm-aware)
- Leverages Ethovision's pre-computed zone columns
- Handles 4 simultaneous arenas per file
- Filters zones by arena number automatically
- High code reuse (~45% reuse ratio)
- Successfully tested with real data
- **Proven scalable architecture**

## Your Task: Implement Phase 3 - NORT Pipeline

### Objective

Create a complete NORT (Novel Object Recognition Test) analysis pipeline following the same proven architecture as LD and OFT pipelines.

### NORT-Specific Requirements

**Data Characteristics:**
- Multi-arena Ethovision Excel files (4 simultaneous subjects)
- Two testing phases per experiment:
  - **Habituation**: Subject explores arena with 2 identical objects (or empty)
  - **Test**: Subject explores arena with 1 familiar + 1 novel object
- Zone columns: "In zone(object left / Nose-point)", "In zone(object right / Nose-point)", "In zone(center / Center-point)", etc.
- ~6-10 zones per arena (object zones, center, floor, possibly walls)
- **Critical Body Part**: Nose-point (for object interaction) AND Center-point (for locomotion)

**Key Metrics to Calculate:**

1. **Object Exploration:**
   - Time exploring novel object (seconds & %)
   - Time exploring familiar object (seconds & %)
   - Total exploration time (seconds)
   - Number of approaches to each object

2. **Memory & Discrimination:**
   - **Discrimination Index (DI)**: (Novel - Familiar) / (Novel + Familiar)
   - **Preference Score**: Novel / (Novel + Familiar) × 100
   - **Recognition Index**: Time with Novel / Total Exploration Time

3. **Locomotor Activity:**
   - Total distance traveled (cm)
   - Average velocity (cm/s)
   - Time in center vs periphery

4. **Quality Metrics:**
   - Total exploration time (must be >minimum threshold, e.g., 10s)
   - Number of valid trials
   - Data completeness

**Zone Logic:**
- Object zones: Direct from "In zone(object left / Nose-point)" and "object right"
- Novel vs Familiar: User must specify which side is novel (varies by trial)
- Exploration defined as nose-point in object zone
- Center/periphery: Use center-point (same as OFT)

**NORT-Specific Challenges:**
1. **Dual Body Parts**: Nose for exploration, center-point for locomotion
2. **Phase Tracking**: Need to handle habituation vs test phase separately
3. **Object Identity**: Must know which object is novel (metadata or user input)
4. **Minimum Exploration**: Trials with <10s total exploration may be invalid

### Files to Create

Create these files in order:

1. **R/nort/nort_load.R** (~300-350 lines)
   - `load_nort_data(file_path, fps = 25, novel_side = "left")` - Specify which side is novel
   - `load_nort_paired_data(hab_file, test_file, fps = 25)` - Load hab + test pair
   - `standardize_nort_columns(df)` - Handle dual body parts
   - `validate_nort_data(nort_data)` - Check required columns
   - `summarize_nort_data(nort_data)` - Quick stats with exploration times

2. **R/nort/nort_analysis.R** (~400-450 lines)
   - `analyze_nort(df, fps = 25, novel_zone = "zone_object_left")` - Core analysis
   - `calculate_discrimination_index(novel_time, familiar_time)` - DI calculation
   - `calculate_preference_score(novel_time, familiar_time)` - Preference %
   - `calculate_recognition_index(novel_time, total_time)` - Recognition ratio
   - `analyze_nort_batch(nort_data, fps = 25)` - Batch processing
   - `export_nort_results(results, output_file)` - CSV export
   - `is_valid_nort_trial(total_exploration_time, min_threshold = 10)` - Quality check

3. **R/nort/nort_report.R** (~450-500 lines)
   - `generate_nort_report(arena_data, output_dir, subject_id, novel_side, fps = 25)`
   - `generate_nort_plots(df, results, subject_id)` - Trajectory (nose + center), heatmap, object exploration
   - `generate_nort_summary_text(results, output_file, subject_id)` - Text summary
   - `interpret_nort_results(results)` - Behavioral interpretation (memory assessment)
   - `generate_nort_batch_report(nort_data, output_dir, novel_sides, fps = 25)`
   - `generate_nort_comparison_plots(batch_results, output_dir)` - Compare DI across subjects
   - `plot_object_exploration_comparison(novel_time, familiar_time, subject_id)` - Bar plot

4. **tests/testthat/test-nort-pipeline.R** (~500+ lines)
   - Unit tests for all functions
   - Test discrimination index calculations (DI = -1 to +1 range)
   - Test with various novel_side configurations
   - Test dual body part handling
   - Integration tests with real data
   - Validation of memory metrics

5. **examples/test_nort_pipeline.R** (~120-150 lines)
   - End-to-end demo script
   - Show habituation + test phase analysis
   - Demonstrate DI calculation
   - Follow pattern from test_ld_pipeline.R and test_oft_pipeline.R

### Implementation Guidelines

**Leverage Existing Code:**
- Reuse functions from R/common/ (io.R, geometry.R, plotting.R)
- Reuse zone functions from R/ld/ld_analysis.R (calculate_zone_time, detect_zone_entries, etc.)
- Follow the exact same pattern as LD and OFT pipelines
- Use `read_ethovision_excel_multi_enhanced()` with `paradigm = "nort"`

**Zone Column Extraction:**
```r
# In R/common/io.R, identify_zone_columns() supports NORT
# It will filter for: "object", "center", "floor" patterns
# Use: paradigm = "nort"
# Look for both Nose-point and Center-point zones
```

**Dual Body Part Handling:**
```r
# NORT requires TWO body parts:
# 1. Nose-point for object exploration zones
# 2. Center-point for locomotion and arena metrics

# In standardize_nort_columns():
col_mapping <- list(
  time = c("Trial time", "Recording time", "Trial.time", "Recording.time"),
  # Nose coordinates (for exploration)
  x_nose = c("X nose", "X Nose", "X.nose"),
  y_nose = c("Y nose", "Y Nose", "Y.nose"),
  # Center coordinates (for locomotion)
  x_center = c("X center", "X Center", "X.center"),
  y_center = c("Y center", "Y Center", "Y.center"),
  # Both are required!
)
```

**Novel Side Specification:**
```r
# User must specify which side is novel (varies by experiment)
load_nort_data("test_file.xlsx", novel_side = "left")  # or "right"

# In analyze_nort():
if (novel_side == "left") {
  novel_zone <- "zone_object_left"
  familiar_zone <- "zone_object_right"
} else {
  novel_zone <- "zone_object_right"
  familiar_zone <- "zone_object_left"
}
```

**Discrimination Index Calculation:**
```r
# DI = (Time_Novel - Time_Familiar) / (Time_Novel + Time_Familiar)
# Range: -1 (only familiar) to +1 (only novel)
# 0 = no preference
# >0 = novelty preference (intact memory)
# <0 = familiarity preference (impaired memory or neophobia)

calculate_discrimination_index <- function(novel_time, familiar_time) {
  total_time <- novel_time + familiar_time
  if (total_time == 0) return(NA_real_)
  di <- (novel_time - familiar_time) / total_time
  return(di)
}
```

**Testing Strategy:**
1. First, check if NORT test data exists:
   ```bash
   ls -la data/NORT/
   ```
2. Inspect zone columns (look for "object" zones):
   ```r
   source("R/common/io.R")
   library(readxl)
   sheets <- excel_sheets("data/NORT/[first_nort_file].xlsx")
   col_names <- read_excel(file, sheet = sheets[1], skip = 36, n_max = 1)
   grep("object", names(col_names), ignore.case = TRUE, value = TRUE)
   ```
3. Test with different novel_side values ("left" vs "right")
4. Validate DI is in range -1 to +1
5. Check that trials with low exploration are flagged

### Success Criteria

Your implementation is complete when:
- [ ] All 5 files created and functional
- [ ] `load_nort_data()` successfully loads multi-arena NORT files
- [ ] Dual body part tracking (nose + center) works correctly
- [ ] Zone columns extracted correctly (object left, object right, center)
- [ ] Novel side can be specified ("left" or "right")
- [ ] All NORT metrics calculated (DI, preference, recognition, exploration times)
- [ ] Discrimination Index in valid range (-1 to +1)
- [ ] Quality checks identify low-exploration trials
- [ ] Plots generated (trajectory with both body parts, heatmap, object exploration bar chart)
- [ ] Reports created with memory assessment interpretation
- [ ] Tests pass with real data
- [ ] Example script runs successfully
- [ ] Code follows LD and OFT pipeline patterns

### Important Notes

**Environment Setup:**
```bash
# Always use conda environment
conda activate r

# All R operations automatically use this environment via .Rprofile
```

**Code Style:**
- Follow existing roxygen2 documentation patterns
- Use `@export` for user-facing functions
- Use `@keywords internal` for internal helpers
- Include `@examples` sections
- Comment complex logic (especially DI calculation)

**Testing:**
- Write tests as you implement (TDD approach)
- Test with real data, not synthetic
- Test both novel_side = "left" and "right"
- Validate DI calculations with known values
- Handle missing coordinates gracefully (`na.rm = TRUE`)
- Warn but don't fail on data quality issues

**Error Handling:**
- Validate inputs (file exists, required columns present)
- Check that novel_side is "left" or "right"
- Provide helpful error messages
- Warn about low exploration time (<10s)
- Warn about missing body part coordinates
- Use `stop()` for fatal errors, `warning()` for issues

### Debugging Tips

**If object zone columns aren't found:**
```r
# Debug script to inspect columns
library(readxl)
sheets <- excel_sheets("data/NORT/your_file.xlsx")
col_names <- read_excel(file, sheet = sheets[1], skip = 36, n_max = 1)
grep("object|left|right", names(col_names), ignore.case = TRUE, value = TRUE)
```

**If body part columns are missing:**
```r
# Check for both nose and center
df <- load_nort_data("file.xlsx")
cat("Nose columns:", grep("nose", colnames(df$Arena_1$data), value = TRUE), "\n")
cat("Center columns:", grep("center", colnames(df$Arena_1$data), value = TRUE), "\n")
```

**If DI seems incorrect:**
```r
# Manually validate DI calculation
df <- nort_data$Arena_1$data
novel_time <- sum(df$zone_object_left, na.rm = TRUE) / fps  # Example: left is novel
familiar_time <- sum(df$zone_object_right, na.rm = TRUE) / fps
di <- (novel_time - familiar_time) / (novel_time + familiar_time)
cat("Novel:", novel_time, "Familiar:", familiar_time, "DI:", di, "\n")
# DI should be between -1 and +1
```

**If exploration times are too low:**
```r
# Check total exploration
total_exploration <- novel_time + familiar_time
if (total_exploration < 10) {
  warning("Low exploration time: ", total_exploration, " seconds. Trial may be invalid.")
}
```

### Resources

**Reference Files:**
- LD implementation: `R/ld/*.R` (template for structure)
- OFT implementation: `R/oft/*.R` (template for anxiety metrics)
- Common functions: `R/common/*.R` (reuse these)
- LD tests: `tests/testthat/test-ld-pipeline.R` (pattern to follow)
- OFT tests: `tests/testthat/test-oft-pipeline.R` (pattern to follow)
- Project roadmap: `PROJECT_ROADMAP.md` (full context)
- Phase 1 summary: `PHASE1_SUMMARY.md`
- Phase 2 summary: `PHASE2_SUMMARY.md`

**Test Data:**
- Check: `/mnt/g/Bella/Rebecca/Code/DLCAnalyzer/data/NORT/`
- Look for habituation and test phase files

**Documentation:**
- Quick start guides: `QUICKSTART_LD.md`, `QUICKSTART_OFT.md` (adapt for NORT)
- Conda setup: `README_CONDA.md`

### Workflow

1. **Setup:**
   ```bash
   cd /mnt/g/Bella/Rebecca/Code/DLCAnalyzer
   conda activate r
   ```

2. **Create directory structure:**
   ```bash
   mkdir -p R/nort
   ```

3. **Implement in order:**
   - nort_load.R (start here - handle dual body parts)
   - nort_analysis.R (implement DI calculation carefully)
   - nort_report.R (add object exploration plots)
   - test-nort-pipeline.R (test as you go)
   - test_nort_pipeline.R (demo script last)

4. **Test frequently:**
   ```bash
   Rscript examples/test_nort_pipeline.R
   ```

5. **Document completion:**
   - Update PROJECT_ROADMAP.md (mark Phase 3 complete)
   - Create QUICKSTART_NORT.md
   - Create PHASE3_SUMMARY.md

### Questions to Ask User (if needed)

Before starting, you may want to clarify:
1. "Do NORT test data files exist? Where are they located?"
2. "Are habituation and test phases in separate files or same file?"
3. "What are the exact zone names for objects? (object left, object right, etc.)"
4. "Is there a standard for which side is novel, or does it vary by trial?"
5. "What is the minimum exploration time threshold for valid trials?"

### Getting Started

Start with:
```r
# 1. Check for NORT test data
list.files("data/NORT/", recursive = TRUE)

# 2. Inspect a NORT file
source("R/common/io.R")
library(readxl)
sheets <- excel_sheets("data/NORT/[first_nort_file].xlsx")
print(sheets)

# 3. Check zone columns
col_names <- read_excel("data/NORT/[file].xlsx", sheet = sheets[1], skip = 36, n_max = 1)
grep("object|zone", names(col_names), ignore.case = TRUE, value = TRUE)

# 4. Check body part columns
grep("nose|center", names(col_names), ignore.case = TRUE, value = TRUE)

# 5. Start implementing nort_load.R
```

### Final Notes

- **Follow LD and OFT patterns** - They're proven and working
- **Handle dual body parts carefully** - Nose for exploration, center for locomotion
- **DI calculation is critical** - Double-check the formula and range
- **Novel side specification is important** - Must be flexible
- **Test with real data** - Validate against expected behavior
- **Reuse R/common/ and zone functions** - Don't reinvent
- **Test incrementally** - Don't wait until everything is done
- **Document as you go** - Roxygen2 comments
- **Ask questions early** - If stuck, ask user

Good luck! The LD and OFT pipelines are your blueprints. Phase 3 should follow the same proven architecture with NORT-specific additions.

---

## Quick Reference Commands

```bash
# Activate environment
conda activate r

# Run test
Rscript examples/test_nort_pipeline.R

# Check test data
ls -la data/NORT/

# Run R interactively
R

# Install package if needed
install.packages("package_name")
```

## Expected Output

When Phase 3 is complete, you should be able to run:

```r
source("R/common/io.R")
source("R/common/geometry.R")
source("R/common/plotting.R")
source("R/ld/ld_analysis.R")  # For shared zone functions
source("R/nort/nort_load.R")
source("R/nort/nort_analysis.R")
source("R/nort/nort_report.R")

# Load NORT data (specify which side is novel)
nort_data <- load_nort_data("data/NORT/test_file.xlsx", fps = 25, novel_side = "left")

# Analyze
results <- analyze_nort_batch(nort_data, fps = 25, novel_sides = c("left", "left", "right", "left"))
print(results[, c("arena_name", "discrimination_index", "preference_score", "total_exploration_time")])

# Generate reports
generate_nort_batch_report(nort_data, output_dir = "output/NORT_reports", novel_sides = c("left", "left", "right", "left"))
```

Expected metrics output:
```
  arena_name discrimination_index preference_score total_exploration_time
1    Arena_1                 0.45             72.5                   25.3
2    Arena_2                 0.62             81.0                   18.7
3    Arena_3                 0.15             57.5                   32.1
4    Arena_4                 0.33             66.5                   21.9
```

**Interpretation:**
- DI > 0.2 typically indicates intact memory (novelty preference)
- DI < 0.1 may indicate impaired memory or no discrimination
- Total exploration > 10s required for valid trial
- Preference score is intuitive percentage (>50% = novelty preference)
