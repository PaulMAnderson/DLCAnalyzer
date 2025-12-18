# Running DLCAnalyzer Tests

## Quick Start

```bash
# From project root
export PATH="/home/paul/miniforge3/envs/r/bin:$PATH"
Rscript -e "library(testthat); test_dir('tests/testthat')"
```

All R source files are automatically loaded by `tests/testthat/setup.R`.

## Test Organization

- `tests/testthat/` - Unit tests (483 tests)
- `tests/integration/` - Integration tests with real data
- `tests/testthat/helper.R` - Helper functions for creating mock data

## No Manual Sourcing Required!

The `setup.R` file automatically sources all necessary R files before tests run.
Individual test files should NOT manually source R files.

## Running Specific Tests

```bash
# Run all unit tests
Rscript -e "library(testthat); test_dir('tests/testthat')"

# Run integration tests
Rscript -e "library(testthat); test_dir('tests/integration')"

# Run a specific test file
Rscript -e "library(testthat); test_file('tests/testthat/test_arena_config.R')"
```

## Test Coverage

### Core Components (188 tests)
- `test_data_structures.R` - tracking_data S3 class (126 tests)
- `test_arena_config.R` - Arena configuration (62 tests)

### Preprocessing (57 tests)
- `test_preprocessing.R` - Likelihood filtering, interpolation, smoothing

### Quality Checks (130 tests)
- `test_quality_checks.R` - Quality assessment and outlier detection

### Metrics (108 tests)
- `test_zone_analysis.R` - Zone classification and occupancy (45 tests)
- `test_time_in_zone.R` - Entries, exits, latency, transitions (63 tests)

## Adding New Tests

When adding new R source files to the package, remember to add them to the `source_files` list in `tests/testthat/setup.R`.
