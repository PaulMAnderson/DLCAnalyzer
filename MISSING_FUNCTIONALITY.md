# Missing Functionality & Improvements

**Date:** 2026-01-09
**Context:** Comprehensive analysis script `analyze_all_behavioral_data.Rmd` created

---

## Missing Plotting Functions

### 1. Common Plotting Functions (HIGH PRIORITY)

**Status:** Partially duplicated across paradigm-specific report files

**Need to consolidate into `R/common/plotting.R`:**

- [ ] `plot_trajectory()` - Generic trajectory plotting
  - Currently duplicated in LD, OFT, NORT, EPM report files
  - Should accept: x, y, color_by (zone/time), zone_boundaries
  - Returns: ggplot object

- [ ] `plot_heatmap()` - Position density heatmap
  - Currently duplicated across paradigms
  - Should accept: x, y, bins, zone_boundaries (optional)
  - Returns: ggplot object

- [ ] `plot_zone_occupancy()` - Bar chart for time in zones
  - Currently has different implementations
  - Should accept: zone_times (named vector), zone_labels, colors
  - Returns: ggplot object

- [ ] `save_plot()` - Consistent plot saving
  - Currently inconsistent across paradigms
  - Should accept: plot, filename, width, height, dpi
  - Handles directory creation

### 2. Cross-Paradigm Comparison Plots (MEDIUM PRIORITY)

- [ ] `plot_paradigm_comparison()` - Compare metrics across paradigms
  - Box plots with overlaid points
  - Accepts: results_list, metric_name, paradigm_names

- [ ] `plot_group_comparison()` - Compare experimental groups
  - Side-by-side comparisons
  - Statistical annotations (t-test, ANOVA)

- [ ] `plot_correlation_matrix()` - Correlations between metrics
  - Heatmap of metric correlations
  - Within or across paradigms

### 3. Individual Animal Reports (LOW PRIORITY)

- [ ] `generate_animal_card()` - Single-page summary per animal
  - Combines trajectory, heatmap, key metrics
  - Consistent across paradigms

- [ ] `plot_timeline()` - Show metric changes over sessions/days
  - For longitudinal studies
  - Line plots with confidence intervals

---

## Missing Analysis Functions

### 1. Quality Control (HIGH PRIORITY)

- [ ] `check_tracking_quality()` - Automated QC across all data
  - Check likelihood scores (for DLC data)
  - Detect outliers in distance/velocity
  - Flag low exploration subjects
  - Returns: QC report data frame

- [ ] `validate_zone_assignments()` - Verify zone calculations
  - Check for missing zones
  - Detect zone assignment errors
  - Visual verification plots

### 2. Statistical Analysis (MEDIUM PRIORITY)

- [ ] `compare_groups()` - Statistical comparisons
  - t-tests, ANOVA, non-parametric tests
  - Effect sizes (Cohen's d, eta-squared)
  - Multiple comparison corrections

- [ ] `calculate_power()` - Power analysis
  - Estimate required sample sizes
  - Post-hoc power calculations

### 3. Data Export (LOW PRIORITY)

- [ ] `export_publication_ready()` - Format for papers
  - Clean column names
  - Add descriptions
  - Include units

- [ ] `generate_supplementary_tables()` - Full data tables
  - All metrics per subject
  - Session information
  - Quality flags

---

## R Markdown Improvements

### 1. Error Handling

- [ ] Add try-catch blocks around all load/analyze operations
- [ ] Collect and display errors in summary section
- [ ] Continue analysis even if some files fail

### 2. Progress Tracking

- [ ] Add progress bars for long operations
- [ ] Estimate remaining time
- [ ] Real-time status updates

### 3. Parameterization

- [ ] Make R Markdown parameters for:
  - Output directory
  - FPS (default 25)
  - Pixels per cm (for EPM)
  - Novel side (for NORT)
  - Minimum exploration threshold

### 4. Caching

- [ ] Cache loaded data to speed up re-runs
- [ ] Cache analysis results
- [ ] Implement smart cache invalidation

---

## Documentation Gaps

### 1. Arena Calibration

- [ ] Detailed guide for EPM pixel-to-cm calibration
- [ ] Standard arena dimensions reference
- [ ] Calibration verification tools

### 2. Novel Side Specification (NORT)

- [ ] How to determine novel side for each trial
- [ ] Batch specification (CSV file?)
- [ ] Automated detection from file names

### 3. Multi-Session Handling

- [ ] How to link habituation and test phases (NORT)
- [ ] Longitudinal data organization
- [ ] Session naming conventions

---

## Technical Debt

### 1. Code Duplication

**High duplication in:**
- Plot generation across paradigms
- Report generation structure
- Data validation functions

**Action:** Refactor into shared utilities

### 2. Inconsistent Naming

**Issues:**
- Some functions use snake_case, others camelCase
- Inconsistent parameter names
- Variable naming differs by paradigm

**Action:** Standardize to snake_case throughout

### 3. Hard-Coded Values

**Found in:**
- Arena dimensions (EPM, OFT)
- Default FPS (should be configurable)
- Color schemes for plots
- Threshold values (exploration minimums)

**Action:** Move to configuration files

---

## Feature Requests

### 1. Batch Configuration

- [ ] CSV file to specify parameters per file
  - File path, paradigm, FPS, novel side, pixels/cm, etc.
- [ ] Automatic parameter detection from file names

### 2. Interactive Dashboard

- [ ] Shiny app for exploring results
- [ ] Real-time plot customization
- [ ] Export selected plots/data

### 3. Integration with Statistical Software

- [ ] Export to SPSS format
- [ ] Generate R scripts for common analyses
- [ ] Prism/GraphPad compatible output

---

## Priority Summary

**Implement Immediately:**
1. ✅ Consolidate plotting functions to R/common/plotting.R
2. ✅ Improve error handling in R Markdown
3. ✅ Add QC functions

**Implement Soon:**
4. Statistical comparison functions
5. Better parameter configuration
6. Batch specification file support

**Nice to Have:**
7. Interactive dashboard
8. Power analysis tools
9. Advanced visualization options

---

## Notes

- Most critical gap: **Consolidated plotting functions**
  - Currently 4x duplication across paradigms
  - Makes maintenance difficult
  - Inconsistent plot styles

- Second priority: **Quality control automation**
  - Need standardized QC across all data
  - Automated outlier detection
  - Visual QC reports

- Third priority: **Configuration management**
  - Too many hard-coded parameters
  - Need flexible configuration system
  - Per-experiment parameter files
