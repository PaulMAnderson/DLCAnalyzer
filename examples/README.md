# DLCAnalyzer Example Scripts

This directory contains example scripts for analyzing behavioral tracking data across different paradigms.

---

## 📁 Available Examples

### Single Subject Analysis

| Script | Paradigm | Data Format | Description |
|--------|----------|-------------|-------------|
| [analyze_epm_single.R](analyze_epm_single.R) | EPM | DeepLabCut CSV | Analyze single EPM subject |
| [analyze_oft_single.R](analyze_oft_single.R) | Open Field | Ethovision Excel | Center vs periphery analysis |
| [analyze_nort_single.R](analyze_nort_single.R) | NORT | Ethovision Excel | Novel object recognition |
| [analyze_ld_single.R](analyze_ld_single.R) | Light/Dark | Ethovision Excel | Anxiety-like behavior |

### Batch Analysis

| Script | Description |
|--------|-------------|
| [analyze_epm_batch.R](analyze_epm_batch.R) | Process all EPM subjects, create summary table |
| [analyze_all_paradigms.R](analyze_all_paradigms.R) | Process all paradigms in one run |

---

## 🚀 Quick Start

### Prerequisites

```r
# Install required R packages
install.packages(c('testthat', 'yaml', 'ggplot2', 'rmarkdown', 'knitr', 'readxl'))
```

### Running an Example

```bash
# Set up environment
cd /mnt/g/Bella/Rebecca/Code/DLCAnalyzer
export PATH="/home/paul/miniforge3/envs/r/bin:$PATH"

# Run a single subject EPM analysis
Rscript examples/analyze_epm_single.R

# Run batch analysis of all EPM subjects
Rscript examples/analyze_epm_batch.R

# Process all paradigms at once
Rscript examples/analyze_all_paradigms.R
```

### Interactive Analysis

```r
# From R console
setwd("/mnt/g/Bella/Rebecca/Code/DLCAnalyzer")
source("examples/analyze_epm_single.R")
```

---

## 📊 Script Details

### EPM Analysis (`analyze_epm_single.R`)

**Data**: DeepLabCut CSV tracking files

**Metrics Calculated**:
- Time in open arms vs closed arms (%)
- Center time
- Zone entries and exits
- Latency to first entry
- Zone transitions
- Total distance traveled

**Output**:
- HTML report with plots
- CSV file with all metrics
- High-resolution plots (heatmap, trajectory, occupancy, transitions)

**Example Usage**:
```r
# Edit the script to change:
dlc_file <- "path/to/your/dlc_output.csv"
subject_id <- "YourSubjectID"
output_dir <- "reports/epm/YourSubjectID"

# Then run:
Rscript examples/analyze_epm_single.R
```

---

### OFT Analysis (`analyze_oft_single.R`)

**Data**: Ethovision Excel export files

**Metrics Calculated**:
- Time in center zone (%)
- Entries to center
- Latency to center
- Total distance and velocity

**Key Interpretation**:
- Higher center time = less anxiety-like behavior
- More center entries = higher exploratory behavior

**Example Usage**:
```r
excel_file <- "data/OFT/Example Exported Data/Raw data-Rebecca OF Oct20th2025-Trial     1.xlsx"

# Run:
Rscript examples/analyze_oft_single.R
```

---

### NORT Analysis (`analyze_nort_single.R`)

**Data**: Ethovision Excel export files

**Metrics Calculated**:
- Novel object exploration time
- Familiar object exploration time
- **Discrimination Index** (DI): `(Novel - Familiar) / (Novel + Familiar)`
- **Preference Ratio** (PR): `Novel / (Novel + Familiar)`
- Entries to each object

**Interpretation**:
- DI > 0.1: Preference for novel object (good memory)
- DI ≈ 0: No preference (no memory)
- DI < -0.1: Preference for familiar object (unusual)

**Example Usage**:
```r
excel_file <- "data/NORT/Example Exported Data/Raw data-NORT D3 20251003-Trial     1 (1).xlsx"

Rscript examples/analyze_nort_single.R
```

---

### Light/Dark Box Analysis (`analyze_ld_single.R`)

**Data**: Ethovision Excel export files

**Metrics Calculated**:
- Time in light compartment (%)
- Time in dark compartment (%)
- Latency to enter light
- Number of transitions
- Average duration per light visit

**Interpretation**:
- >50% in light: Exploratory/low anxiety
- <20% in light: High anxiety-like behavior
- More transitions: Higher exploratory activity

**Example Usage**:
```r
excel_file <- "data/LD/Example Exported Data/Raw data-LD Rebecca 20251022-Trial     1.xlsx"

Rscript examples/analyze_ld_single.R
```

---

### Batch EPM Analysis (`analyze_epm_batch.R`)

**Purpose**: Process all EPM subjects at once and create summary statistics

**Features**:
- Processes all CSV files in `data/EPM/Example DLC Data/`
- Generates individual reports for each subject
- Creates summary table with key metrics
- Calculates group statistics (mean, SD, range)

**Output**:
```
reports/epm_batch/
├── summary_metrics.csv          # Summary table
├── ID7689/
│   ├── ID7689_report.html
│   ├── ID7689_metrics.csv
│   └── plots/
├── ID7693/
│   └── ...
└── ID7694/
    └── ...
```

**Example Usage**:
```bash
Rscript examples/analyze_epm_batch.R
```

---

### All Paradigms Analysis (`analyze_all_paradigms.R`)

**Purpose**: One-click processing of all available data

**Features**:
- Automatically detects and processes EPM, OFT, NORT, and LD data
- Generates individual reports for each subject
- Creates paradigm-specific summaries
- Reports processing time and success rate

**Output Structure**:
```
reports/batch_all_paradigms/
├── epm/
│   ├── ID7689/
│   └── ID7693/
├── oft/
│   └── trial1/
├── nort/
│   └── trial1/
└── ld/
    └── trial1/
```

**Example Usage**:
```bash
# Process everything at once
Rscript examples/analyze_all_paradigms.R

# Expected output:
# - Processes ~10-15 subjects
# - Takes 5-10 minutes
# - Generates ~10-15 HTML reports
```

---

## 🎯 Customizing the Scripts

### Changing Arena Definitions

Edit the arena configuration files:
- EPM: `config/arena_definitions/EPM/EPM.yaml`
- OFT: `config/arena_definitions/OF/of_standard.yaml`
- NORT: `config/arena_definitions/NORT/nort_standard.yaml`
- LD: `config/arena_definitions/LD/ld_standard.yaml`

Or create a custom arena in the script:

```r
arena <- new_arena_config(
  arena_id = "my_custom_arena",
  dimensions = list(width = 800, height = 600),
  zones = list(
    my_zone = list(
      type = "circle",
      center_x = 400,
      center_y = 300,
      radius = 100
    )
  )
)
```

### Changing Analysis Parameters

```r
# FPS (frames per second)
fps <- 30  # Change to match your recording

# Body part to track
body_part <- "mouse_center"  # Or "nose", "tail_base", etc.

# Likelihood threshold for filtering
likelihood_threshold <- 0.9  # 0.0 to 1.0

# Interpolation settings
max_gap <- 10  # Maximum frames to interpolate
```

### Changing Output Options

```r
# Output format
format <- "html"  # Or "pdf" or "both"

# Output directory
output_dir <- "reports/my_analysis"

# Plot resolution
dpi <- 300  # For publication-quality plots
```

---

## 📈 Expected Output

Each script generates:

### 1. HTML Report
Interactive report with:
- Session metadata
- Data quality assessment
- Zone occupancy tables and plots
- Entry/exit analysis
- Latency statistics
- Transition diagrams
- Trajectory visualization
- Heatmap of spatial occupancy

### 2. Metrics CSV
All calculated metrics in tabular format:
- Zone occupancy times and percentages
- Entry counts and durations
- Latency values
- Transition counts
- Movement metrics

### 3. High-Resolution Plots
Individual plot files (PNG, 300 DPI):
- `heatmap.png` - Spatial density
- `trajectory.png` - Movement path
- `occupancy.png` - Zone occupancy bar chart
- `transitions.png` - Transition matrix

---

## 🔧 Troubleshooting

### Error: "File not found"
- Check file paths are correct
- Ensure working directory is set to package root
- Verify data files exist in expected locations

### Error: "Package not found"
```r
# Install missing packages
install.packages(c('ggplot2', 'rmarkdown', 'knitr', 'readxl'))
```

### Error: "Arena config not found"
- Scripts will create default arenas automatically
- Or create custom arena configurations in `config/arena_definitions/`

### Low Quality Score
- Check DLC confidence thresholds
- Review original tracking data
- Consider using interpolation for missing data

### No Zones Detected
- Verify arena dimensions match video resolution
- Check zone coordinates are within arena bounds
- Review arena YAML configuration syntax

---

## 💡 Tips for Success

### 1. Start Small
Begin with a single subject analysis before batch processing:
```bash
Rscript examples/analyze_epm_single.R
```

### 2. Check Data Quality
Review the quality assessment section of reports:
- Overall quality should be >90%
- Low confidence <5%
- Missing data <10%

### 3. Validate Results
Compare generated metrics with expected values:
- EPM: Open arm time typically 5-50%
- OFT: Center time typically 10-40%
- NORT: Discrimination index typically 0-0.6

### 4. Customize for Your Needs
Copy and modify scripts for your specific:
- Arena dimensions
- Zone definitions
- Analysis parameters
- Output formats

---

## 📚 Further Reading

- **Main README**: [../README.md](../README.md)
- **Architecture Guide**: [../docs/ARCHITECTURE.md](../docs/ARCHITECTURE.md)
- **Full Task List**: [../docs/REFACTORING_TODO.md](../docs/REFACTORING_TODO.md)
- **Next Steps**: [../NEXT_STEPS_SIMPLE.md](../NEXT_STEPS_SIMPLE.md)

---

## 🤝 Getting Help

1. Check error messages carefully
2. Review example data file formats
3. Verify R package versions
4. Consult function documentation with `?function_name`

---

**Happy Analyzing! 🎉**
