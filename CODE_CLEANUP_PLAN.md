# Code Cleanup Plan

**Date:** 2026-01-09
**Goal:** Remove unnecessary/duplicate code, consolidate functions, improve maintainability

---

## Phase 1: Identify Redundant Directories (IMMEDIATE)

### 1.1 Empty/Placeholder Directories

**Remove these directories (contain only .gitkeep):**
```
R/paradigms/          # Empty - paradigms are in R/{ld,oft,nort,epm}/
R/utils/.gitkeep      # Only has config_utils.R - move to R/core/
R/metrics/.gitkeep    # Has 3 files - should be integrated into paradigm analysis
R/visualization/      # Only has plot_tracking.R - move to R/common/plotting.R
```

**Action:**
```bash
# Backup first
git mv R/paradigms/ _archived/paradigms/

# Integrate useful files
git mv R/utils/config_utils.R R/core/config_utils.R
git mv R/visualization/plot_tracking.R R/common/plotting_tracking.R

# Move metrics files to appropriate locations
git mv R/metrics/movement_metrics.R R/common/geometry.R  # merge/integrate
git mv R/metrics/time_in_zone.R R/ld/ld_analysis.R      # already duplicated there
git mv R/metrics/zone_analysis.R R/common/zones.R       # merge/integrate
```

### 1.2 Legacy Code

**R/legacy/DLCAnalyzer_Functions_final.R (76KB)**
- **Status:** Outdated, superseded by new pipeline architecture
- **Action:** Move to `_archived/legacy/` for reference
- **Reason:** All functionality has been reimplemented in new structure

```bash
mkdir -p _archived/legacy/
git mv R/legacy/ _archived/legacy/
```

---

## Phase 2: Consolidate Duplicate Functions (HIGH PRIORITY)

### 2.1 Plotting Functions

**Current situation:** Duplicated across 4 paradigm report files

**Files with duplicates:**
- `R/ld/ld_report.R` - Lines 99-150 (plot generation)
- `R/oft/oft_report.R` - Lines 98-170 (plot generation)
- `R/nort/nort_report.R` - Lines 100-250 (plot generation)
- `R/epm/epm_report.R` - Lines 99-350 (plot generation)

**Plan:**

1. **Create unified plotting module:**
   ```
   R/common/plotting.R (NEW/ENHANCED)
   ├── plot_trajectory()
   ├── plot_heatmap()
   ├── plot_zone_occupancy()
   ├── plot_time_series()
   ├── save_plot()
   └── apply_standard_theme()
   ```

2. **Update paradigm report files to use common functions:**
   ```r
   # OLD (in R/epm/epm_report.R):
   plot_epm_trajectory <- function(df, arena_config, subject_id) {
     # 50 lines of ggplot code
   }

   # NEW (in R/epm/epm_report.R):
   plot_epm_trajectory <- function(df, arena_config, subject_id) {
     plot_trajectory(df$x, df$y,
                    color_by = df$zone_open_arms,
                    boundaries = epm_boundaries(arena_config),
                    title = paste(subject_id, "- EPM Trajectory"))
   }
   ```

**Estimated reduction:** ~400 lines of duplicate code

### 2.2 Report Generation Structure

**Current situation:** Similar structure across all report files

**Common pattern:**
```r
generate_X_report() {
  # Load data
  # Run analysis
  # Generate plots
  # Save plots
  # Save CSV
  # Generate text summary
}
```

**Plan:**

1. **Create generic report template:**
   ```
   R/common/report_utils.R (NEW)
   ├── generate_base_report()  # Generic report structure
   ├── create_report_directory()
   ├── save_report_plots()
   ├── export_metrics_csv()
   └── generate_text_summary()
   ```

2. **Paradigm-specific reports call base functions:**
   ```r
   generate_epm_report <- function(data, output_dir, subject_id) {
     # Setup
     dir <- create_report_directory(output_dir, subject_id)

     # Paradigm-specific analysis
     results <- analyze_epm(data)
     plots <- generate_epm_plots(data, results)

     # Use generic save functions
     save_report_plots(plots, dir, subject_id)
     export_metrics_csv(results, dir, subject_id)
     generate_text_summary(results, dir, subject_id, template = "epm")
   }
   ```

**Estimated reduction:** ~300 lines of duplicate code

### 2.3 Zone Calculation Functions

**Current situation:**
- `R/ld/ld_analysis.R` has `calculate_zone_time()`, `detect_zone_entries()`, etc.
- These are reused by OFT, NORT, EPM
- But also exist in `R/metrics/time_in_zone.R` (duplicate!)

**Plan:**

1. **Keep functions in R/ld/ld_analysis.R** (they work well)
2. **Delete R/metrics/time_in_zone.R** (24KB duplicate)
3. **Import from ld_analysis in other paradigms**

```bash
git rm R/metrics/time_in_zone.R
```

**Estimated reduction:** ~600 lines of duplicate code

---

## Phase 3: Reorganize R/ Directory Structure (MEDIUM PRIORITY)

### 3.1 Proposed New Structure

```
R/
├── core/                    # Core data structures and loading (KEEP)
│   ├── data_loading.R       ✓ Keep - DLC and Ethovision loaders
│   ├── data_structures.R    ✓ Keep - tracking_data class
│   ├── preprocessing.R      ✓ Keep - filtering, smoothing
│   ├── coordinate_transforms.R  ✓ Keep - pixel conversion, rotation
│   ├── arena_config.R       ✓ Keep - arena definitions
│   ├── quality_checks.R     ✓ Keep - QC functions
│   └── config_utils.R       ← MOVE from R/utils/
│
├── common/                  # Shared utilities (CONSOLIDATE)
│   ├── io.R                 ✓ Keep - Ethovision helpers
│   ├── geometry.R           ✓ Keep + merge R/metrics/movement_metrics.R
│   ├── zones.R              ✓ Keep + merge R/metrics/zone_analysis.R
│   ├── plotting.R           ✓ EXPAND - consolidate all plot functions
│   └── report_utils.R       ← NEW - shared report generation
│
├── ld/                      # LD paradigm (CLEAN)
│   ├── ld_load.R            ✓ Keep
│   ├── ld_analysis.R        ✓ Keep - has zone functions used by others
│   └── ld_report.R          ⚠ REFACTOR - use common plotting
│
├── oft/                     # OFT paradigm (CLEAN)
│   ├── oft_load.R           ✓ Keep
│   ├── oft_analysis.R       ✓ Keep
│   └── oft_report.R         ⚠ REFACTOR - use common plotting
│
├── nort/                    # NORT paradigm (CLEAN)
│   ├── nort_load.R          ✓ Keep
│   ├── nort_analysis.R      ✓ Keep
│   └── nort_report.R        ⚠ REFACTOR - use common plotting
│
├── epm/                     # EPM paradigm (CLEAN)
│   ├── epm_load.R           ✓ Keep
│   ├── epm_analysis.R       ✓ Keep
│   └── epm_report.R         ⚠ REFACTOR - use common plotting
│
└── _archived/               # OLD/UNUSED CODE (ARCHIVE)
    ├── legacy/              ← Move R/legacy/ here
    ├── paradigms/           ← Move empty R/paradigms/ here
    ├── reporting/           ← Integrate or archive R/reporting/
    ├── utils/               ← After extracting useful files
    └── metrics/             ← After integrating into common/

```

### 3.2 Files to Archive or Delete

**Archive (keep for reference):**
```
_archived/
├── legacy/DLCAnalyzer_Functions_final.R  # Old monolithic file
├── reporting/generate_report.R           # Superseded by paradigm reports
├── reporting/group_comparisons.R         # Integrate into common/stats.R
└── metrics/                              # Integrated into common/
```

**Delete (truly unused):**
```
R/paradigms/           # Empty placeholder
R/*/. gitkeep          # Placeholders no longer needed
```

---

## Phase 4: Code Style Standardization (LOW PRIORITY)

### 4.1 Naming Conventions

**Current issues:**
- Mix of snake_case and camelCase
- Inconsistent parameter naming

**Standard to adopt:** `snake_case` (matches R community conventions)

**Examples to fix:**
```r
# Before
analyze_LD()          # Mixed case in name
calcOpenArmRatio()    # camelCase

# After
analyze_ld()          # All lowercase
calculate_open_arm_ratio()  # snake_case
```

### 4.2 Function Documentation

**Ensure all exported functions have:**
- [ ] @title
- [ ] @description
- [ ] @param for each parameter
- [ ] @return
- [ ] @examples
- [ ] @export tag

---

## Implementation Plan

### Week 1: Critical Cleanup (Do This First)

**Day 1:**
- [ ] Create `_archived/` directory
- [ ] Move `R/legacy/` to `_archived/legacy/`
- [ ] Move `R/paradigms/` to `_archived/paradigms/`

**Day 2:**
- [ ] Consolidate plotting functions into `R/common/plotting.R`
- [ ] Update `R/epm/epm_report.R` to use consolidated functions
- [ ] Test EPM pipeline still works

**Day 3:**
- [ ] Update remaining report files (LD, OFT, NORT) to use consolidated plotting
- [ ] Test all pipelines
- [ ] Remove duplicate plot code

**Day 4:**
- [ ] Delete `R/metrics/time_in_zone.R` (duplicate)
- [ ] Integrate `R/metrics/movement_metrics.R` into `R/common/geometry.R`
- [ ] Integrate `R/metrics/zone_analysis.R` into `R/common/zones.R`
- [ ] Delete `R/metrics/` directory

**Day 5:**
- [ ] Create `R/common/report_utils.R` with shared report functions
- [ ] Refactor one paradigm report to use new structure
- [ ] Test and validate

### Week 2: Structural Improvements

- [ ] Move `R/visualization/plot_tracking.R` to `R/common/`
- [ ] Move `R/utils/config_utils.R` to `R/core/`
- [ ] Delete now-empty directories
- [ ] Update all imports/source statements
- [ ] Run full test suite

### Week 3: Documentation & Polish

- [ ] Update NAMESPACE (if creating proper package)
- [ ] Standardize function names to snake_case
- [ ] Complete all Roxygen documentation
- [ ] Create CODE_STRUCTURE.md documenting new organization

---

## Expected Outcomes

**Code Reduction:**
- Remove ~76KB legacy code
- Eliminate ~1,000 lines of duplicate code
- Net reduction: ~30-40% of R/ directory

**Maintainability:**
- Single source of truth for plotting
- Consistent report generation
- Easier to add new paradigms

**Testing:**
- Fewer functions to test
- Shared functions tested once
- Higher test coverage possible

---

## Rollback Plan

**If something breaks:**

1. Git history is preserved - can revert any change
2. Old code is in `_archived/` not deleted
3. Test after each consolidation step
4. Can always restore from archive

---

## Checklist for Each Consolidation

Before consolidating any code:
- [ ] Verify current code works
- [ ] Create new consolidated version
- [ ] Update all callers to use new version
- [ ] Test that all paradigms still work
- [ ] Only then delete old code
- [ ] Commit with clear message

---

## Notes

**Priority Order:**
1. Move legacy/unused code to archive (safest)
2. Consolidate plotting (highest impact)
3. Consolidate report generation (good impact)
4. Clean up directory structure (organizational)
5. Standardize naming (polish)

**Risk Level:**
- Low risk: Moving to archive, deleting empty folders
- Medium risk: Consolidating plotting functions
- Higher risk: Changing function signatures, renaming

**Always test after each step!**
