# AI Agent Starting Prompt for DLCAnalyzer - Session 2

## Copy and paste this prompt to start your session:

---

Hello! I'm continuing the DLCAnalyzer R package refactoring. This is a behavioral analysis tool for processing animal tracking data from DeepLabCut.

**Project Location**: `/mnt/g/Bella/Rebecca/Code/DLCAnalyzer`

**Current Status**: Phase 1 Complete + Arena Configuration System Complete
**Your Task**: Implement Phase 2 Core Functionality (Preprocessing & Metrics)

## What's Already Complete

### ✅ Phase 1: Foundation (COMPLETE)
- Directory structure created
- `tracking_data` S3 class fully implemented ([R/core/data_structures.R](R/core/data_structures.R:1))
- DLC data loading functions ([R/core/data_loading.R](R/core/data_loading.R:1))
- DLC to internal format converter ([R/core/data_converters.R](R/core/data_converters.R:1))
- YAML configuration system ([R/utils/config_utils.R](R/utils/config_utils.R:1))
- Testing framework: 126 unit tests passing

### ✅ Phase 1.5: Arena Configuration System (COMPLETE - Bonus!)
- Arena configuration S3 class ([R/core/arena_config.R](R/core/arena_config.R:1))
- Zone geometry system ([R/core/zone_geometry.R](R/core/zone_geometry.R:1))
  - Point-based polygons, proportional zones, circles, rectangles
  - Point-in-zone detection (ray-casting algorithm)
  - Automatic dependency resolution
- Coordinate transformations ([R/core/coordinate_transforms.R](R/core/coordinate_transforms.R:1))
  - Scale calculation, pixels ↔ cm conversion
  - Rotation, translation, y-axis flipping
- 62 unit tests, all passing
- Tested with real EPM, NORT, OF, LD arena configurations

**Total Completion**: ~10% of project (Phase 1 + 1.5 complete)

## Your Starting Point: Phase 2, Task 2.1

### Implement Preprocessing Functions

**File to create**: `R/core/preprocessing.R`

**Functions to implement**:

1. **Likelihood Filtering**
   ```r
   filter_low_confidence <- function(tracking_data, threshold = 0.9, body_parts = NULL)
   ```
   - Remove/flag tracking points with likelihood < threshold
   - Support per-body-part filtering
   - Preserve frame continuity

2. **Interpolation**
   ```r
   interpolate_missing <- function(tracking_data, method = "linear", max_gap = 5)
   ```
   - Fill gaps in tracking data
   - Methods: linear, spline, polynomial
   - Only interpolate gaps ≤ max_gap frames

3. **Smoothing**
   ```r
   smooth_trajectory <- function(tracking_data, method = "savgol", window = 11, ...)
   ```
   - Savitzky-Golay filter, moving average, Gaussian
   - Configurable window size
   - Per-body-part processing

**Reference**: Check legacy code in [R/legacy/DLCAnalyzer_Functions_final.R](R/legacy/DLCAnalyzer_Functions_final.R:1)

**Testing**: Create `tests/testthat/test_preprocessing.R` with >80% coverage

## Essential Reading Order

1. **[docs/SESSION_HANDOFF.md](docs/SESSION_HANDOFF.md:1)** - Complete session summary (READ THIS FIRST!)
2. **[docs/REFACTORING_TODO.md](docs/REFACTORING_TODO.md:1)** - Detailed task list with acceptance criteria
3. **[docs/REFACTORING_PLAN.md](docs/REFACTORING_PLAN.md:1)** - Overall architecture and strategy
4. **[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md:1)** - Design patterns and principles

## Key Design Principles

From [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md:1):

1. **Standardized Internal Format**: All functions operate on `tracking_data` S3 objects
2. **Configuration Cascade**: System defaults → Templates → User config → Function args
3. **Pipeline Pattern**: Load → Preprocess → Calculate → Visualize → Export
4. **Validation at Boundaries**: Check inputs early, fail fast with informative errors
5. **Separation of Concerns**: Keep preprocessing, metrics, and paradigms separate

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

dlc_data <- read_dlc_csv("data/EPM/Example DLC Data/ID7689_superanimal_topviewmouse_snapshot-hrnet_w32-004_snapshot-fasterrcnn_resnet50_fpn_v2-004__filtered.csv")

tracking_data <- convert_dlc_to_tracking_data(
  "data/EPM/Example DLC Data/ID7689_superanimal_topviewmouse_snapshot-hrnet_w32-004_snapshot-fasterrcnn_resnet50_fpn_v2-004__filtered.csv",
  fps = 30,
  subject_id = "ID7689",
  paradigm = "epm"
)

# Test your preprocessing functions
source("R/core/preprocessing.R")
filtered <- filter_low_confidence(tracking_data, threshold = 0.9)
interpolated <- interpolate_missing(filtered, max_gap = 5)
smoothed <- smooth_trajectory(interpolated, method = "savgol")

# Verify results
print(smoothed)
summary(smoothed)
```

## Verify Everything Works

Before starting, run existing tests to confirm the codebase is working:

```bash
cd /mnt/g/Bella/Rebecca/Code/DLCAnalyzer

# Run integration tests
Rscript test_phase1.R
Rscript test_real_data.R
Rscript test_arena_system.R

# Run all unit tests
Rscript -e "library(testthat); test_dir('tests/testthat')"
```

You should see:
- ✅ All Phase 1 tests passing
- ✅ Real data test with 15,080 frames working
- ✅ Arena system with EPM and NORT working
- ✅ 126 unit tests passing

## Task Workflow

For each task:

1. **Plan**: Review task requirements in [docs/REFACTORING_TODO.md](docs/REFACTORING_TODO.md:1)
2. **Implement**: Write the code following design principles
3. **Test**: Write unit tests (target >80% coverage)
4. **Validate**: Test with real data from `data/` directory
5. **Document**: Add roxygen2 documentation with examples
6. **Verify**: Check acceptance criteria are met
7. **Commit**: Create git commit with descriptive message

## Acceptance Criteria for Task 2.1

Mark complete when:
- [ ] `filter_low_confidence()` implemented and tested
- [ ] `interpolate_missing()` with multiple methods
- [ ] `smooth_trajectory()` with multiple methods
- [ ] All functions work on `tracking_data` objects
- [ ] Unit tests written with >80% coverage
- [ ] Tested with real data from `data/` directory
- [ ] Results match or improve upon legacy implementation
- [ ] roxygen2 documentation complete with examples

## After Task 2.1, Continue With:

- **Task 2.2**: Coordinate transformation utilities (mostly done, integrate with preprocessing)
- **Task 2.3**: Quality check functions
- **Task 2.4**: Distance & speed metrics (use arena system for unit conversion)
- **Task 2.5**: Zone analysis metrics (use zone geometry from arena system)
- **Task 2.6**: Time in zone calculations
- **Task 2.7**: Configuration validation

## Code Standards

- Use roxygen2 for all function documentation
- Follow tidyverse style guide
- Write tests for all new functions
- Use informative variable names
- Add comments for complex logic
- Test with real data from `data/` directory

## Git Workflow

The previous session created a commit with the arena configuration system. Continue with:

```bash
git add R/core/preprocessing.R tests/testthat/test_preprocessing.R
git commit -m "Implement Phase 2 Task 2.1: Preprocessing functions

- Likelihood filtering
- Interpolation (linear, spline, polynomial)
- Smoothing (Savitzky-Golay, moving average, Gaussian)
- Tested with real EPM data
- 80%+ unit test coverage

🤖 Generated with Claude Code
Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

## Available Resources

### Documentation
- [docs/SESSION_HANDOFF.md](docs/SESSION_HANDOFF.md:1) - Previous session summary
- [docs/REFACTORING_PLAN.md](docs/REFACTORING_PLAN.md:1) - Overall strategy
- [docs/REFACTORING_TODO.md](docs/REFACTORING_TODO.md:1) - Detailed task list
- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md:1) - Design patterns
- [docs/ARENA_CONFIGURATION_PLAN.md](docs/ARENA_CONFIGURATION_PLAN.md:1) - Arena system (complete)

### Existing Code
- [R/legacy/DLCAnalyzer_Functions_final.R](R/legacy/DLCAnalyzer_Functions_final.R:1) - Original implementation for reference
- [R/core/data_structures.R](R/core/data_structures.R:1) - tracking_data S3 class
- [R/core/data_loading.R](R/core/data_loading.R:1) - DLC CSV reading
- [R/core/data_converters.R](R/core/data_converters.R:1) - DLC to tracking_data conversion
- [R/core/arena_config.R](R/core/arena_config.R:1) - Arena configuration (NEW!)
- [R/core/zone_geometry.R](R/core/zone_geometry.R:1) - Zone geometry (NEW!)
- [R/core/coordinate_transforms.R](R/core/coordinate_transforms.R:1) - Coordinate transforms (NEW!)

### Test Data
- `data/EPM/Example DLC Data/*.csv` - 4 EPM tracking files
- `data/OFT/Output_DLC/*.csv` - Open Field tracking files
- `data/FST/Output_DLC/*.csv` - Forced Swim Test files

### Configuration Files
- `config/arena_definitions/EPM/EPM.yaml` - EPM arena (✅ working)
- `config/arena_definitions/NORT/NORT.yaml` - NORT arena (✅ working)
- `config/arena_definitions/OF/OF.yaml` - Open Field (⚠️ minor issues)
- `config/arena_definitions/LD/LD.yaml` - Light-Dark (⚠️ minor issues)

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
Rscript test_phase1.R
Rscript test_real_data.R

# Start implementing
# 1. Create R/core/preprocessing.R
# 2. Create tests/testthat/test_preprocessing.R
# 3. Test with real data from data/ directory
```

## Expected Output

When Task 2.1 is complete, you should be able to run:

```r
# Load and preprocess real data
data <- convert_dlc_to_tracking_data("data/EPM/Example DLC Data/ID7689_superanimal_topviewmouse_snapshot-hrnet_w32-004_snapshot-fasterrcnn_resnet50_fpn_v2-004__filtered.csv", fps = 30, subject_id = "ID7689", paradigm = "epm")

# Apply preprocessing pipeline
filtered <- filter_low_confidence(data, threshold = 0.9)
interpolated <- interpolate_missing(filtered, max_gap = 5)
smoothed <- smooth_trajectory(interpolated, method = "savgol")

# Check results
print(smoothed)
summary(smoothed)

# Should show:
# - Reduced data points (low confidence removed)
# - No gaps > 5 frames
# - Smooth trajectories
```

## Success Criteria

Phase 2, Task 2.1 is complete when:
1. All three preprocessing functions implemented and tested
2. Functions work seamlessly with `tracking_data` S3 objects
3. Unit tests achieve >80% coverage
4. Tested successfully with real EPM, OFT, and FST data
5. Results validated against legacy implementation
6. Documentation complete with examples
7. Git commit created

---

**You have everything you need to continue the refactoring. Good luck with Phase 2!**

**Remember**: Test with real data from the `data/` directory throughout development. The arena configuration system is ready to use for unit conversions and zone-based metrics in later tasks.

---

**Document Version**: 1.0
**Created**: December 17, 2024
**Previous Session Summary**: [docs/SESSION_HANDOFF.md](docs/SESSION_HANDOFF.md:1)
