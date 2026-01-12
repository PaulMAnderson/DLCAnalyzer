# Conda Environment Setup for DLCAnalyzer

## Required Environment

All R operations for this package MUST use the `r` conda environment.

## Setup Instructions

### 1. Activate the R environment
```bash
conda activate r
```

### 2. Start R
```bash
R
```

### 3. Install Required Packages
```r
# Required packages
install.packages(c("readxl", "testthat", "ggplot2", "dplyr", "devtools", "roxygen2"))
```

### 4. Development Workflow
```bash
# Always activate environment first
conda activate r

# Then run R commands
R CMD check .
R CMD INSTALL .
Rscript tests/testthat.R
```

## Package Dependencies

The package requires:
- **readxl**: For reading Ethovision Excel files
- **testthat**: For unit testing
- **ggplot2**: For visualization
- **dplyr**: For data manipulation
- **devtools**: For package development
- **roxygen2**: For documentation generation

All dependencies should be installed in the conda `r` environment.

## Automatic Environment Loading

The `.Rprofile` file in this directory automatically:
- Displays environment information when R starts
- Checks for missing required packages
- Ensures all operations use the conda environment

## Troubleshooting

If you encounter package installation issues:
```bash
# Reinstall R in conda environment
conda install -c conda-forge r-base r-essentials

# Or create fresh environment
conda create -n r r-base r-essentials
conda activate r
```
