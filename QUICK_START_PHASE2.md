# Quick Start - Phase 2 Development

**Last Updated**: December 17, 2024
**Current Status**: Phase 1 Complete ✓ | Phase 2 Ready to Start
**Git Commit**: 2068330

---

## For AI Agents - Copy This Prompt

```
Hello! I'm continuing the DLCAnalyzer refactoring project.

**Current Status**: Phase 1 is complete. I need to continue with Phase 2.

**Please read these files to understand where we are**:
1. docs/AI_AGENT_PROMPT.md - Full continuation instructions
2. docs/REFACTORING_TODO.md - Check Phase 2 tasks (starting at Task 2.1)
3. PHASE1_SUMMARY.md - What was accomplished in Phase 1

**Then proceed with Phase 2, Task 2.1**: Extract and Refactor Preprocessing Functions

**Important Setup**:
- R environment: export PATH="/home/paul/miniforge3/envs/r/bin:$PATH"
- Test first: Rscript test_phase1.R
- Verify all Phase 1 tests pass before starting Phase 2
```

---

## For Human Developers

### Verify Phase 1 Status
```bash
cd /mnt/g/Bella/Rebecca/Code/DLCAnalyzer

# Activate R environment
export PATH="/home/paul/miniforge3/envs/r/bin:$PATH"

# Run integration test
Rscript test_phase1.R

# Expected: All tests passing, no errors
```

### Start Phase 2 Development

**Next Task**: Extract Preprocessing Functions (Task 2.1)

**Location**: Create `R/core/preprocessing.R`

**Functions to Implement**:
1. `filter_low_confidence(tracking_data, threshold, body_parts)`
2. `interpolate_missing(tracking_data, method, max_gap)`
3. `smooth_trajectory(tracking_data, method, window, ...)`

**Reference**:
- Legacy code: `R/legacy/DLCAnalyzer_Functions_final.R` (lines ~100-300)
- Config template: `config/analysis_parameters/default_preprocessing.yml`
- Architecture: `docs/ARCHITECTURE.md` (Preprocessing section)

---

## Project Structure (Phase 1 Complete)

```
DLCAnalyzer/
├── R/
│   ├── core/
│   │   ├── data_structures.R      ✓ tracking_data S3 class
│   │   ├── data_loading.R         ✓ DLC CSV reader
│   │   ├── data_converters.R      ✓ Format converters
│   │   └── preprocessing.R        ← NEXT: Create this
│   ├── utils/
│   │   └── config_utils.R         ✓ YAML config system
│   └── legacy/
│       └── DLCAnalyzer_Functions_final.R  ✓ Preserved
├── config/
│   ├── arena_definitions/
│   │   └── open_field_template.yml  ✓
│   └── analysis_parameters/
│       └── default_preprocessing.yml  ✓
├── tests/
│   └── testthat/
│       ├── test_data_structures.R   ✓ 22 tests
│       ├── test_data_loading.R      ✓ 42 tests
│       └── test_data_converters.R   ✓ 17 tests
├── docs/
│   ├── AI_AGENT_PROMPT.md          ✓ Start here for AI
│   ├── REFACTORING_TODO.md         ✓ Task list
│   └── ARCHITECTURE.md             ✓ Design docs
├── test_phase1.R                   ✓ Integration test
├── test_real_data.R                ✓ Real data test
└── PHASE1_SUMMARY.md               ✓ What's done
```

---

## Quick Commands

### Testing
```bash
# Full integration test
Rscript test_phase1.R

# Real data test (EPM, 15,080 frames)
Rscript test_real_data.R

# Unit tests for specific module
Rscript -e "library(testthat); source('R/core/data_structures.R'); test_file('tests/testthat/test_data_structures.R')"
```

### Check Progress
```bash
# View Phase 2 tasks
grep -A5 "Phase 2" docs/REFACTORING_TODO.md | head -20

# View completion metrics
grep -A10 "TRACKING METRICS" docs/REFACTORING_TODO.md
```

### Load Example Data
```R
source("R/core/data_structures.R")
source("R/core/data_loading.R")
source("R/core/data_converters.R")

# Load real EPM data
data <- load_tracking_data(
  "data/EPM/Output_DLC/EPM_10DeepCut_resnet50_epmMay17shuffle1_1030000.csv",
  fps = 30,
  subject_id = "EPM_10",
  paradigm = "elevated_plus_maze",
  reference_point_names = c("tl", "tr", "bl", "br", "lt", "lb", "rt", "rb",
                            "ctl", "ctr", "cbl", "cbr")
)

# View summary
print(data)
summary(data)
```

---

## Phase 2 Roadmap

| Task | Description | Files to Create | Est. Time |
|------|-------------|-----------------|-----------|
| 2.1 | Preprocessing | R/core/preprocessing.R | 8 hrs |
| 2.2 | Coordinate transforms | R/core/coordinate_transforms.R | 6 hrs |
| 2.3 | Quality checks | R/core/quality_checks.R | 4 hrs |
| 2.4 | Distance/speed | R/metrics/distance_speed.R | 6 hrs |
| 2.5 | Zone analysis | R/metrics/zone_analysis.R | 8 hrs |
| 2.6 | Time in zone | R/metrics/time_in_zone.R | 6 hrs |
| 2.7 | Config validation | R/utils/config_validation.R | 4 hrs |

**Total Estimated**: ~42 hours

---

## Key Files Reference

| Need to... | Look at... |
|------------|------------|
| Understand data format | `R/core/data_structures.R` |
| See how DLC loads | `R/core/data_loading.R` |
| Add new data source | `R/core/data_converters.R` |
| Modify config system | `R/utils/config_utils.R` |
| Add tests | `tests/testthat/helper.R` |
| Check architecture | `docs/ARCHITECTURE.md` |
| See task details | `docs/REFACTORING_TODO.md` |
| Continue with AI | `docs/AI_AGENT_PROMPT.md` |

---

## Success Criteria for Phase 2

When Phase 2 is complete, you should be able to:
- ✓ Filter tracking data by likelihood threshold
- ✓ Interpolate missing data points
- ✓ Smooth trajectories with multiple methods
- ✓ Convert pixels to cm using scale factors
- ✓ Detect outliers and suspicious jumps
- ✓ Calculate distance traveled and velocity
- ✓ Define zones (rectangular, circular, polygonal)
- ✓ Calculate time in zones
- ✓ All with >80% test coverage

---

**Status**: Ready to begin Phase 2! 🚀
