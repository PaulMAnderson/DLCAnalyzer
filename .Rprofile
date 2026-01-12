# DLCAnalyzer R Package Development Environment Setup
# This file ensures all R operations use the 'r' conda environment

# Set environment message
message("DLCAnalyzer: Using conda 'r' environment")
message("R version: ", R.version.string)

# Add reminder about package installation
.First <- function() {
  cat("\n")
  cat("========================================================\n")
  cat(" DLCAnalyzer Development Environment\n")
  cat("========================================================\n")
  cat(" Using conda 'r' environment for all operations\n")
  cat(" Install packages with: install.packages('package_name')\n")
  cat(" All packages will be installed in the conda environment\n")
  cat("========================================================\n\n")
}

# Ensure packages are installed in conda environment
if (interactive()) {
  # Check for required packages
  required_packages <- c("readxl", "testthat", "ggplot2", "dplyr")
  missing_packages <- setdiff(required_packages, rownames(installed.packages()))

  if (length(missing_packages) > 0) {
    cat("Missing required packages:", paste(missing_packages, collapse = ", "), "\n")
    cat("Install them with: install.packages(c('",
        paste(missing_packages, collapse = "', '"), "'))\n", sep = "")
  }
}
