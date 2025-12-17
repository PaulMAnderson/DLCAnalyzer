# This file is part of the standard testthat testing setup
library(testthat)

# Source all R files from the package
source_files <- list.files("../../R", recursive = TRUE, pattern = "\\.R$", full.names = TRUE)
for (file in source_files) {
  source(file)
}

# Run all tests
test_check("DLCAnalyzer")
