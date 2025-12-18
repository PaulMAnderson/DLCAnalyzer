# DLCAnalyzer Quick Start Guide

Get started analyzing your behavioral data in **3 simple steps**.

---

## ⚡ 3-Minute Quick Start

### 1. Install R Packages (One Time)

```r
install.packages(c('testthat', 'yaml', 'ggplot2', 'rmarkdown', 'knitr', 'readxl'))
```

### 2. Choose Your Analysis Script

| Your Data | Script to Run |
|-----------|---------------|
| EPM (DLC CSV) | `examples/analyze_epm_single.R` |
| Open Field (Excel) | `examples/analyze_oft_single.R` |
| NORT (Excel) | `examples/analyze_nort_single.R` |
| Light/Dark (Excel) | `examples/analyze_ld_single.R` |

### 3. Run the Script

```bash
cd /mnt/g/Bella/Rebecca/Code/DLCAnalyzer
export PATH="/home/paul/miniforge3/envs/r/bin:$PATH"

# For EPM analysis:
Rscript examples/analyze_epm_single.R

# For OFT analysis:
Rscript examples/analyze_oft_single.R
```

**Done!** Check `reports/` for your HTML report with plots and metrics.

---

## 📋 What You Get

Each analysis produces:

1. **HTML Report** (`*_report.html`)
   - Interactive report with all metrics
   - Embedded plots and visualizations
   - Data quality assessment
   - Open in any web browser

2. **Metrics CSV** (`*_metrics.csv`)
   - All calculated values in table format
   - Import into Excel, GraphPad, etc.

3. **High-Resolution Plots** (`plots/`)
   - Heatmap (spatial density)
   - Trajectory (movement path)
   - Occupancy (time in zones)
   - Transitions (zone changes)

---

## 🎯 Analyzing Your Own Data

### Option 1: Edit the Example Script

Open the relevant example script and change these lines:

```r
# FOR EPM (DLC CSV):
dlc_file <- "path/to/your/dlc_output.csv"
subject_id <- "YourSubjectID"

# FOR OFT/NORT/LD (Excel):
excel_file <- "path/to/your/ethovision_export.xlsx"
```

Then run the script.

### Option 2: Use R Console Interactively

```r
# Load all functions
setwd("/mnt/g/Bella/Rebecca/Code/DLCAnalyzer")
source("tests/testthat/setup.R")

# Load your data
tracking_data <- convert_dlc_to_tracking_data(
  "your_data.csv",
  fps = 30,
  subject_id = "mouse01"
)

# Load arena
arena <- load_arena_configs(
  "config/arena_definitions/EPM/EPM.yaml",
  arena_id = "epm_standard"
)

# Generate report
report <- generate_subject_report(
  tracking_data,
  arena,
  output_dir = "reports/mouse01"
)
```

---

## 📊 Example Metrics

### EPM (Elevated Plus Maze)
- **Open Arm Time**: % time in anxiety-provoking zones
- **Open Arm Entries**: Number of explorations
- **Center Time**: Transition zone occupancy
- **Total Distance**: Overall activity level

### OFT (Open Field Test)
- **Center Time**: % time in anxiogenic center zone
- **Center Entries**: Exploration attempts
- **Latency to Center**: Time to first entry
- **Total Distance**: Locomotor activity

### NORT (Novel Object Recognition)
- **Discrimination Index**: (Novel - Familiar) / Total
  - >0.1 = good memory
  - ≈0 = no preference
- **Preference Ratio**: Novel / Total

### LD (Light/Dark Box)
- **Light Time**: % in anxiogenic bright compartment
- **Transitions**: Light↔Dark crossings
- **Latency to Light**: Time to first exploration
- **Average Light Visit**: Duration per entry

---

## 🔄 Batch Processing

Process multiple subjects at once:

```bash
# Process all EPM subjects
Rscript examples/analyze_epm_batch.R

# Process all paradigms
Rscript examples/analyze_all_paradigms.R
```

Creates summary tables with group statistics.

---

## ⚙️ Common Customizations

### Change FPS
```r
fps <- 30  # Match your recording frame rate
```

### Change Body Part
```r
body_part <- "mouse_center"  # Or "nose", "tail_base", etc.
```

### Change Output Format
```r
format <- "html"  # Or "pdf" or "both"
```

### Filter Low Confidence Points
```r
tracking_data <- filter_low_confidence(
  tracking_data,
  threshold = 0.9  # Keep only points with >90% confidence
)
```

### Interpolate Missing Data
```r
tracking_data <- interpolate_missing(
  tracking_data,
  method = "linear",
  max_gap = 10  # Interpolate gaps up to 10 frames
)
```

---

## 🐛 Troubleshooting

### "Package not found"
```r
install.packages('package_name')
```

### "File not found"
- Check file path is correct
- Use absolute path or set working directory
- Verify file exists with `list.files("directory")`

### "No zones detected"
- Arena dimensions may not match video
- Check arena YAML configuration
- Scripts auto-create default arenas if missing

### Low Quality Score (<90%)
- Review original DLC tracking
- Check confidence thresholds
- Use interpolation for missing data

---

## 📚 Next Steps

- **More Examples**: See [examples/README.md](examples/README.md)
- **Full Documentation**: See [README.md](README.md)
- **Arena Configuration**: See `config/arena_definitions/`
- **Detailed Guide**: See [ASSESSMENT_SUMMARY.md](ASSESSMENT_SUMMARY.md)

---

## 💡 Pro Tips

1. **Start with example data** to verify setup
2. **Check quality metrics** in reports (aim for >90%)
3. **Validate results** against expected ranges
4. **Customize arenas** to match your specific setup
5. **Save scripts** for your specific workflows

---

## 🎓 Example Workflows

### Workflow 1: Single EPM Subject
```bash
Rscript examples/analyze_epm_single.R
# Opens: reports/epm/ID7689/ID7689_report.html
```

### Workflow 2: Compare EPM Groups
```r
# Process control group
Rscript examples/analyze_epm_batch.R

# Edit group_info to specify treatment groups
# Generate group comparison report
```

### Workflow 3: Multi-Paradigm Study
```bash
# One command to process all paradigms
Rscript examples/analyze_all_paradigms.R

# Results in: reports/batch_all_paradigms/
```

---

**Ready to analyze? Start with the example data:**

```bash
cd /mnt/g/Bella/Rebecca/Code/DLCAnalyzer
Rscript examples/analyze_epm_single.R
```

**That's it! Check `reports/` for your results.**

---

Questions? See [examples/README.md](examples/README.md) for detailed documentation.
