# DLCAnalyzer Redesign Project Roadmap

## Project Overview

Redesigning the DLCAnalyzer R package to use a paradigm-first architecture that leverages Ethovision's pre-computed zone membership columns, eliminating complex zone geometry calculations.

## Current Status: Phase 4 Complete ✅

**Completed:** January 9, 2026

### Phase 1: LD (Light/Dark Box) Pilot Pipeline ✅

**Status:** Fully implemented and tested
**Code:** ~2,515 lines
**Files Created:**
- R/common/io.R (426 lines)
- R/common/geometry.R (314 lines)
- R/common/plotting.R (299 lines)
- R/ld/ld_load.R (273 lines)
- R/ld/ld_analysis.R (390 lines)
- R/ld/ld_report.R (384 lines)
- tests/testthat/test-ld-pipeline.R (429 lines)
- examples/test_ld_pipeline.R

**Key Achievements:**
- ✅ Enhanced Ethovision reading with automatic zone extraction
- ✅ Multi-arena support (4 simultaneous subjects)
- ✅ Arena-specific zone filtering
- ✅ Complete LD metrics (time, entries, latency, distance)
- ✅ Automated report generation with plots
- ✅ Comprehensive test coverage
- ✅ Successfully tested with real data

### Phase 2: OFT (Open Field Test) Pipeline ✅

**Status:** Fully implemented and tested
**Code:** ~1,400 lines
**Files Created:**
- R/oft/oft_load.R (287 lines)
- R/oft/oft_analysis.R (325 lines)
- R/oft/oft_report.R (412 lines)
- tests/testthat/test-oft-pipeline.R (603 lines)
- examples/test_oft_pipeline.R (117 lines)

**Key Achievements:**
- ✅ OFT data loading with zone extraction (center, floor, wall)
- ✅ Multi-arena support (4 simultaneous subjects)
- ✅ Complete OFT metrics (time in center/periphery, entries, latency, distance, velocity)
- ✅ Thigmotaxis index calculation (wall-hugging behavior)
- ✅ Automated report generation with behavioral interpretation
- ✅ Comparison plots across subjects
- ✅ Successfully tested with real data

**Test Results:**
- Processed 4-arena file (8,700-9,250 frames per arena)
- All metrics calculated correctly
- Example results: 2-6.5% time in center, 7-14 entries, appropriate latencies
- Reports generated successfully with plots and interpretation

### Phase 3: NORT (Novel Object Recognition Test) Pipeline ✅

**Status:** Fully implemented and tested
**Code:** ~1,850 lines
**Files Created:**
- R/nort/nort_load.R (427 lines)
- R/nort/nort_analysis.R (464 lines)
- R/nort/nort_report.R (624 lines)
- tests/testthat/test-nort-pipeline.R (481 lines)
- examples/test_nort_pipeline.R (187 lines)
- QUICKSTART_NORT.md (340 lines)
- PHASE3_SUMMARY.md

**Key Achievements:**
- ✅ NORT data loading with dual body part handling (nose + center)
- ✅ Multi-arena support (1-4 simultaneous subjects)
- ✅ Discrimination Index (DI) calculation and interpretation
- ✅ Preference Score and Recognition Index metrics
- ✅ Novel side specification (left/right/neither)
- ✅ Paired habituation + test phase loading
- ✅ Trial validity checking (minimum exploration threshold)
- ✅ Automated report generation with dual trajectory plots
- ✅ Object exploration comparison plots
- ✅ Comprehensive testing with real data

**Test Results:**
- Processed single-arena NORT file (9,002 frames)
- Detected 2 object zones (left and right) with nose-point
- Calculated DI: -0.421 (familiarity preference detected)
- Trial validity: Correctly flagged low exploration (6.08s < 10s minimum)
- All plots and reports generated successfully
- 18 test suites passed

**Novel Features:**
- **Dual body part tracking**: Nose-point for exploration, center-point for locomotion
- **Memory discrimination indices**: DI, preference score, recognition index
- **Flexible novel side**: Specify which object is novel per trial
- **Quality assessment**: Automatic validity checking based on exploration time

---

### Phase 4: EPM (Elevated Plus Maze) Pipeline ✅

**Status:** Fully implemented and tested
**Code:** ~1,850 lines
**Files Created:**
- R/epm/epm_load.R (700 lines)
- R/epm/epm_analysis.R (600 lines)
- R/epm/epm_report.R (550 lines)
- tests/testthat/test-epm-pipeline.R (350 lines)
- examples/test_epm_pipeline.R (300 lines)
- QUICKSTART_EPM.md (520 lines)

**Key Achievements:**
- ✅ DeepLabCut CSV data loading (different from LD/OFT/NORT)
- ✅ Pixel-to-cm coordinate conversion
- ✅ Dynamic zone calculation from maze geometry
- ✅ Open arm ratio and entries ratio (anxiety indices)
- ✅ Arm-specific metrics (open vs closed arms)
- ✅ Latency to first open arm entry
- ✅ Locomotor activity (distance, velocity)
- ✅ Automated report generation with EPM-specific plots
- ✅ Arena calibration and custom configurations
- ✅ Batch processing support
- ✅ Quality control validation

**Test Results:**
- Processed DeepLabCut CSV with 26 body parts
- Calculated zones from EPM geometry (40 cm arms, 10 cm center)
- Successfully converted pixel coordinates to cm
- Comprehensive test coverage (integration + unit tests)
- All plots and reports generated successfully

**Novel Features:**
- **DLC CSV support**: First paradigm to use DeepLabCut format
- **Geometric zone calculation**: No pre-computed zones - calculates from coordinates
- **Pixel conversion**: Handles pixel-to-cm transformation with calibration
- **Anxiety indices**: Open arm ratio as primary anxiety metric
- **Custom arenas**: Flexible arm dimensions and orientations
- **Likelihood filtering**: Uses DLC confidence scores for quality control

**Key Differences from Other Paradigms:**
- Data format: CSV (not Excel like LD/OFT/NORT)
- Coordinate units: Pixels requiring conversion (not cm)
- Zones: Calculated from geometry (not pre-computed in data)
- Tracking quality: Likelihood-based filtering

---

## Next Phases

---

### Phase 3: NORT (Novel Object Recognition Test) Pipeline

**Priority:** MEDIUM-HIGH
**Estimated Complexity:** Medium-High
**Estimated Time:** 3-4 hours

#### Objectives
Implement NORT analysis with object zone detection and discrimination index calculation.

#### Data Characteristics
- **Arenas:** Typically 1 per file
- **Sessions:** Multiple sessions per subject
  - Habituation Day 1
  - Habituation Day 2
  - Test Day 3
- **Zones per arena:**
  - "round object left" / "round object right" (or similar)
  - Both Center-point and **Nose-point** zones available
- **Zone naming:** Object-based (no arena numbers typically)
- **Body part:** **Nose-point recommended** for more accurate exploration detection

#### Key Metrics to Calculate
1. **Object exploration time:**
   - Time near object 1 (familiar)
   - Time near object 2 (novel)
   - Total exploration time

2. **Discrimination metrics:**
   - Discrimination index: (T_novel - T_familiar) / (T_novel + T_familiar)
   - Preference ratio: T_novel / (T_novel + T_familiar)
   - Recognition memory (> 0.5 indicates preference for novel)

3. **Exploration behavior:**
   - Number of approaches to each object
   - Latency to first exploration (each object)
   - Average bout duration

4. **Locomotion:**
   - Total distance traveled
   - Distance near objects vs arena

#### Files to Create
```
R/nort/
├── nort_load.R          # NORT data loading
├── nort_analysis.R      # NORT metrics calculation
└── nort_report.R        # NORT report generation

tests/testthat/
└── test-nort-pipeline.R # NORT tests

examples/
└── test_nort_pipeline.R # NORT demo script
```

#### Implementation Steps
1. Create R/nort/nort_load.R
   - `load_nort_session()` - Load single session
   - `load_nort_experiment()` - Load hab + test sessions
   - `link_nort_sessions()` - Match habituation to test
   - `identify_object_type()` - Determine familiar/novel

2. Create R/nort/nort_analysis.R
   - `analyze_nort_test()` - Test session analysis
   - `calculate_discrimination_index()` - DI calculation
   - `calculate_preference_ratio()` - PR calculation
   - `analyze_nort_batch()` - Multi-subject analysis

3. Create R/nort/nort_report.R
   - `generate_nort_report()` - Individual report
   - `generate_nort_plots()` - Object zones, exploration time
   - `interpret_nort_results()` - Memory assessment

4. Create tests and examples

#### Special Considerations
- **Multi-session handling:** Need to link habituation and test sessions
- **Object identification:** Determine which object is familiar/novel
- **Nose-point zones:** Use for more accurate exploration detection
- **Session metadata:** Track which day, which objects used

#### Test Data
- Files: `data/NORT/[NORT files]`
- Multiple files per subject (hab, test)
- Need session linking logic

#### Success Criteria
- [ ] Load habituation and test sessions
- [ ] Extract object zone columns (nose-point)
- [ ] Link sessions correctly
- [ ] Calculate discrimination index
- [ ] Calculate preference ratio
- [ ] Identify novel object preference
- [ ] Generate object-focused visualizations
- [ ] Pass all tests

---

### Phase 4: EPM (Elevated Plus Maze) Pipeline (Optional)

**Priority:** LOW-MEDIUM
**Estimated Complexity:** High
**Estimated Time:** 4-5 hours

#### Objectives
Implement EPM analysis supporting both DLC CSV and Ethovision Excel formats.

#### Data Characteristics
- **Two data sources:**
  1. **DLC CSV:** 27 body parts, pixel coordinates, likelihood scores
  2. **Ethovision Excel:** 3 body parts (center, nose, tail), cm coordinates
- **Arenas:** Typically 1 per file
- **Zones:** 5 zones
  - 2 closed arms
  - 2 open arms
  - center
- **Challenge:** May need zone geometry for DLC data (no pre-computed zones)

#### Key Metrics to Calculate
1. **Time in arms:**
   - Time in open arms (seconds & %)
   - Time in closed arms (seconds & %)
   - Open/closed ratio

2. **Arm entries:**
   - Entries to open arms
   - Entries to closed arms
   - Total arm entries

3. **Anxiety index:**
   - Multiple formulas possible
   - Typically: Time_closed / (Time_open + Time_closed)

4. **Locomotion:**
   - Total distance traveled
   - Distance in open vs closed arms

5. **Risk assessment:**
   - Head dips from open arms (if tracking nose)
   - Stretch-attend postures (if tracking body elongation)

#### Files to Create
```
R/epm/
├── epm_load.R           # EPM data loading (DLC + Ethovision)
├── epm_preprocess.R     # DLC-specific preprocessing
├── epm_zones.R          # Zone definitions (may need geometry)
├── epm_analysis.R       # EPM metrics calculation
└── epm_report.R         # EPM report generation

tests/testthat/
└── test-epm-pipeline.R  # EPM tests

examples/
└── test_epm_pipeline.R  # EPM demo script
```

#### Implementation Challenges
1. **Dual format support:** DLC vs Ethovision
2. **DLC preprocessing:** Likelihood filtering, interpolation, smoothing
3. **Zone definition:** May need YAML configs for DLC (pixel coords)
4. **Coordinate systems:** Pixels (DLC) vs cm (Ethovision)

#### Decision Needed
- If Ethovision has pre-computed EPM zones, much simpler
- If DLC only, need to implement zone geometry (more complex)
- Recommend starting with Ethovision-only if possible

#### Success Criteria
- [ ] Load DLC and/or Ethovision EPM data
- [ ] Handle coordinate transformations
- [ ] Define/extract arm zones
- [ ] Calculate anxiety index
- [ ] Calculate all EPM metrics
- [ ] Generate arm-focused visualizations
- [ ] Pass all tests

---

### Phase 5: Group Statistics & Comparisons

**Priority:** MEDIUM
**Estimated Complexity:** Medium
**Estimated Time:** 2-3 hours

#### Objectives
Add group comparison functionality across all paradigms.

#### Features to Implement
1. **Statistical tests:**
   - T-tests (two groups)
   - ANOVA (multiple groups)
   - Post-hoc tests (Tukey, Bonferroni)
   - Effect size calculations (Cohen's d, eta-squared)

2. **Comparison visualizations:**
   - Grouped boxplots
   - Violin plots
   - Individual data points overlay
   - Error bars (SE, SD, CI)

3. **Batch processing:**
   - Load multiple experiments
   - Assign group labels
   - Compile metrics across subjects
   - Statistical comparisons

4. **Report generation:**
   - Group comparison tables
   - Statistical test results
   - Publication-quality figures

#### Files to Create/Enhance
```
R/common/
└── stats.R              # Statistical comparison functions

R/[paradigm]/
└── [paradigm]_report.R  # Add group comparison functions

examples/
└── group_comparison_example.R  # Demo workflow
```

#### Implementation Steps
1. Create R/common/stats.R
   - `compare_groups_ttest()` - T-test wrapper
   - `compare_groups_anova()` - ANOVA wrapper
   - `calculate_effect_size()` - Effect size metrics
   - `post_hoc_tests()` - Multiple comparisons
   - `compile_paradigm_metrics()` - Combine subjects

2. Enhance each paradigm's report.R
   - Add group comparison plotting functions
   - Add group statistics tables
   - Add p-value annotations to plots

3. Create example workflow
   - Load multiple files
   - Assign groups
   - Run comparisons
   - Generate report

#### Success Criteria
- [ ] T-tests working for two groups
- [ ] ANOVA working for 3+ groups
- [ ] Effect sizes calculated correctly
- [ ] Group comparison plots generated
- [ ] Statistical results exported to CSV
- [ ] Publication-quality figures

---

## Long-Term Goals

### Phase 6: Package Finalization

1. **Documentation:**
   - Complete Roxygen2 documentation
   - Create vignettes for each paradigm
   - Update main README
   - Create tutorial videos (optional)

2. **Package structure:**
   - DESCRIPTION file
   - NAMESPACE (exports)
   - Package installation support
   - Dependencies management

3. **Legacy code:**
   - Deprecate old unified pipeline
   - Migration guide for existing users
   - Backward compatibility (if needed)

---

## Technical Debt & Improvements

### Known Issues to Address
1. **Missing coordinates handling:**
   - Current: Simple `na.rm = TRUE`
   - Improvement: Interpolation for small gaps, warn for large gaps

2. **ggplot2 warnings:**
   - Update `size` to `linewidth` in line plots
   - Use `annotate()` instead of `geom_rect()` for zone boundaries

3. **Zone filtering edge cases:**
   - Handle missing arena numbers in zone names
   - Support alternative zone naming conventions

### Potential Enhancements
1. **Performance:**
   - Parallel processing for batch analysis
   - Progress bars for long operations
   - Caching intermediate results

2. **Flexibility:**
   - Custom metric calculations
   - User-defined zone combinations
   - Configurable analysis parameters

3. **Integration:**
   - RMarkdown templates for reports
   - Shiny dashboard for interactive exploration
   - API for Python integration

---

## Resource Requirements

### Required Packages
- **Core:** readxl, ggplot2
- **Optional:** dplyr, tidyr, patchwork, testthat
- **Statistics:** stats (built-in), car (for ANOVA), effsize

### Test Data Needed
- [x] LD: Available (tested)
- [ ] OFT: Check availability
- [ ] NORT: Check availability
- [ ] EPM: Check availability

### Environment
- Conda environment 'r' with R 4.5.2
- Packages installed in conda environment
- .Rprofile handles automatic activation

---

## Decision Points

### Immediate Decisions Needed (Before Phase 2)
1. **OFT data availability:** Confirm OFT test files exist and accessible
2. **OFT zone names:** Verify actual zone naming in OFT files
3. **Periphery definition:** Confirm how to calculate periphery (floor - center?)

### Future Decisions
1. **EPM approach:** Ethovision-only or support DLC too?
2. **Group labels:** How should users specify experimental groups?
3. **NORT session linking:** Automatic or manual object identification?
4. **Package distribution:** CRAN submission or GitHub-only?

---

## Success Metrics

### Phase Completion Criteria
Each phase is considered complete when:
- [ ] All functions implemented and documented
- [ ] Comprehensive tests passing
- [ ] Successfully processes real data
- [ ] Reports generate without errors
- [ ] Code reviewed and cleaned up
- [ ] Examples working
- [ ] Documentation updated

### Overall Project Success
- All 4 behavioral paradigms supported
- Group comparison functionality working
- Package installable and usable
- Documentation complete
- Migration from old package possible

---

## Timeline Estimates

- **Phase 2 (OFT):** 2-3 hours
- **Phase 3 (NORT):** 3-4 hours
- **Phase 4 (EPM):** 4-5 hours (if DLC support)
- **Phase 5 (Stats):** 2-3 hours
- **Phase 6 (Finalization):** 4-6 hours

**Total estimated time:** 15-21 hours remaining

---

## Contact & References

**Plan File Location:** `/home/paul/.claude/plans/enumerated-scribbling-castle.md`
**Package Location:** `/mnt/g/Bella/Rebecca/Code/DLCAnalyzer/`
**Test Data:** `/mnt/g/Bella/Rebecca/Code/DLCAnalyzer/data/`

**Key References:**
- Phase 1 Summary: [PHASE1_SUMMARY.md](PHASE1_SUMMARY.md)
- Quick Start: [QUICKSTART_LD.md](QUICKSTART_LD.md)
- Conda Setup: [README_CONDA.md](README_CONDA.md)
- Original Plan: `/home/paul/.claude/plans/enumerated-scribbling-castle.md`
