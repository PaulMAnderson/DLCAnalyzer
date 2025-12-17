# DLCAnalyzer Architecture Overview

## System Architecture

This document describes the architectural design of the refactored DLCAnalyzer system.

## Architecture Diagram

\\\
+-----------------------------------------------------------------+
¦                         USER INTERFACE                          ¦
¦                     (Workflow Scripts)                          ¦
+-----------------------------------------------------------------¦
¦  run_open_field.R  ¦  run_epm.R  ¦  run_nor.R  ¦  run_ldb.R    ¦
+-----------------------------------------------------------------+
               ¦                                  ¦
               v                                  v
+------------------------------+    +---------------------------+
¦   PARADIGM-SPECIFIC MODULES  ¦    ¦  VISUALIZATION MODULES    ¦
+------------------------------¦    +---------------------------¦
¦  • open_field.R              ¦    ¦  • trajectory_plots.R     ¦
¦  • elevated_plus_maze.R      ¦    ¦  • heatmaps.R             ¦
¦  • novel_object.R            ¦    ¦  • summary_plots.R        ¦
¦  • light_dark_box.R          ¦    ¦                           ¦
+------------------------------+    +---------------------------+
               ¦                                ¦
               v                                v
+-----------------------------------------------------------------+
¦                      METRICS MODULES                            ¦
+-----------------------------------------------------------------¦
¦  • distance_speed.R  ¦  • zone_analysis.R  ¦  • time_in_zone.R ¦
+-----------------------------------------------------------------+
               ¦
               v
+-----------------------------------------------------------------+
¦                      CORE PROCESSING                            ¦
+-----------------------------------------------------------------¦
¦  • preprocessing.R          ¦  • coordinate_transforms.R        ¦
¦  • quality_checks.R         ¦  • data_structures.R              ¦
+-----------------------------------------------------------------+
               ¦
               v
+-----------------------------------------------------------------+
¦                      DATA LAYER                                 ¦
+-----------------------------------------------------------------¦
¦  • data_loading.R           ¦  • data_converters.R              ¦
¦     - read_dlc_csv()        ¦     - convert_dlc_to_internal()   ¦
¦     - read_ethovision()     ¦     - convert_ethovision()        ¦
¦     - read_custom_csv()     ¦     - convert_custom()            ¦
+-----------------------------------------------------------------+
               ¦
               v
+-----------------------------------------------------------------+
¦                    CONFIGURATION SYSTEM                         ¦
+-----------------------------------------------------------------¦
¦  • config_utils.R           ¦  • config_validation.R            ¦
¦  • YAML Templates           ¦                                   ¦
+-----------------------------------------------------------------+
               ¦
               v
+-----------------------------------------------------------------+
¦                      UTILITIES                                  ¦
+-----------------------------------------------------------------¦
¦  • logging.R                ¦  • helpers.R                      ¦
+-----------------------------------------------------------------+
\\\

## Data Flow

\\\
Raw Data Files                Internal Format              Results
(DLC, Ethovision, etc.)      (tracking_data)              (Metrics, Plots)
         ¦                           ¦                           ¦
         v                           v                           v
+----------------+      +---------------------+      +------------------+
¦  Data Loaders  ¦------>¦  Standardized       ¦------>¦  Preprocessing   ¦
¦  - DLC         ¦      ¦  tracking_data      ¦      ¦  - Filter        ¦
¦  - Ethovision  ¦      ¦  object with:       ¦      ¦  - Interpolate   ¦
¦  - Custom CSV  ¦      ¦  - metadata         ¦      ¦  - Smooth        ¦
+----------------+      ¦  - tracking df      ¦      +------------------+
                        ¦  - arena info       ¦               ¦
                        ¦  - config           ¦               v
                        +---------------------+      +------------------+
                                                     ¦  Metrics         ¦
                                                     ¦  - Distance      ¦
                                                     ¦  - Speed         ¦
                                                     ¦  - Zones         ¦
                                                     +------------------+
                                                              ¦
                                                              v
                                                     +------------------+
                                                     ¦  Visualization   ¦
                                                     ¦  + Export        ¦
                                                     +------------------+
\\\

## Module Dependencies

### Layer 1: Foundation (No dependencies on other modules)
- R/core/data_structures.R - Internal data format definitions
- R/utils/helpers.R - General utility functions
- R/utils/logging.R - Logging utilities

### Layer 2: Configuration (Depends on Layer 1)
- R/utils/config_utils.R - Configuration reading/merging
- R/utils/config_validation.R - Configuration validation

### Layer 3: Data Import (Depends on Layers 1-2)
- R/core/data_loading.R - Raw data file readers
- R/core/data_converters.R - Format converters to internal format

### Layer 4: Core Processing (Depends on Layers 1-3)
- R/core/preprocessing.R - Filtering, interpolation, smoothing
- R/core/coordinate_transforms.R - Coordinate system utilities
- R/core/quality_checks.R - Data quality assessment

### Layer 5: Metrics (Depends on Layers 1-4)
- R/metrics/distance_speed.R - Movement metrics
- R/metrics/zone_analysis.R - Zone definition and classification
- R/metrics/time_in_zone.R - Zone-based temporal metrics
- R/metrics/body_part_specific.R - Multi-point analyses

### Layer 6: Paradigms (Depends on Layers 1-5)
- R/paradigms/open_field.R - OFT-specific analysis
- R/paradigms/elevated_plus_maze.R - EPM-specific analysis
- R/paradigms/novel_object.R - NOR-specific analysis
- R/paradigms/light_dark_box.R - LDB-specific analysis

### Layer 7: Visualization (Depends on Layers 1-5)
- R/visualization/trajectory_plots.R - Path visualizations
- R/visualization/heatmaps.R - Occupancy/velocity heatmaps
- R/visualization/summary_plots.R - Summary statistics plots

### Layer 8: Workflows (Depends on all previous layers)
- workflows/run_open_field.R - End-to-end OFT pipeline
- workflows/run_epm.R - End-to-end EPM pipeline
- workflows/run_novel_object.R - End-to-end NOR pipeline
- workflows/run_light_dark.R - End-to-end LDB pipeline

## Core Data Structure

The central data structure is the \	racking_data\ S3 class:

\\\
tracking_data_object <- list(
  metadata = list(
    source = character,           # "deeplabcut", "ethovision", etc.
    fps = numeric,                # Frames per second
    subject_id = character,       # Subject identifier
    session_id = character,       # Session identifier
    paradigm = character,         # "open_field", "epm", etc.
    timestamp = POSIXct,          # Import timestamp
    original_file = character,    # Path to source file
    units = character             # "pixels", "cm", etc.
  ),
  
  tracking = data.frame(
    frame = integer,              # Frame number (1-indexed)
    time = numeric,               # Time in seconds
    body_part = character,        # Name of tracked point
    x = numeric,                  # X coordinate
    y = numeric,                  # Y coordinate
    likelihood = numeric          # Confidence (0-1, NA if not available)
  ),
  
  arena = list(
    dimensions = list(
      width = numeric,            # Arena width
      height = numeric,           # Arena height
      units = character           # "pixels", "cm"
    ),
    
    reference_points = data.frame(  # Optional
      point_name = character,
      x = numeric,
      y = numeric,
      likelihood = numeric        # May be NA
    ),
    
    zones = list(                 # Optional, defined by paradigm
      zone_name = list(
        type = character,         # "rectangle", "circle", "polygon"
        definition = list(...)     # Zone-specific parameters
      )
    )
  ),
  
  config = list(                  # Paradigm-specific configuration
    ...
  )
)

class(tracking_data_object) <- "tracking_data"
\\\

## Key Design Patterns

### 1. Converter Pattern
All external data formats are converted to the internal \	racking_data\ format:

\\\
# Generic interface
data <- load_tracking_data(
  file_path = "path/to/file",
  source_type = "deeplabcut",  # Auto-detect or specify
  config = config_list
)
# Returns: tracking_data object
\\\

### 2. Configuration Cascade
Configurations merge in this order (later overrides earlier):
1. System defaults (hardcoded)
2. Template configuration file
3. User configuration file
4. Function arguments

\\\
final_config <- merge_configs(
  system_defaults,
  read_config("template.yml"),
  read_config("user_config.yml"),
  list(override_param = value)
)
\\\

### 3. Pipeline Pattern
Each paradigm workflow follows a consistent pipeline:

\\\
# 1. Load configuration
config <- load_config("config/my_experiment.yml")

# 2. Import data
data <- load_tracking_data(file_path, config = config)

# 3. Preprocess
data <- preprocess_tracking_data(data, config)

# 4. Calculate metrics
metrics <- calculate_paradigm_metrics(data, config)

# 5. Visualize
plots <- generate_paradigm_plots(data, metrics, config)

# 6. Export
export_results(metrics, plots, output_dir)
\\\

### 4. Validation at Boundaries
Validate data at system boundaries:
- When importing external data
- When reading configurations
- When accepting user parameters
- Before expensive computations

### 5. Separation of Concerns
- **Data layer**: Only handles file I/O and format conversion
- **Core layer**: Generic processing, no paradigm knowledge
- **Metrics layer**: Reusable calculations across paradigms
- **Paradigm layer**: Paradigm-specific logic and metrics
- **Visualization layer**: Only plotting, no calculations

## Extension Points

### Adding a New Paradigm

1. Create paradigm module: \R/paradigms/new_paradigm.R\
2. Implement required functions:
   - \setup_<paradigm>_arena()\
   - \alidate_<paradigm>_config()\
   - \calculate_<paradigm>_metrics()\
   - \isualize_<paradigm>_results()\
3. Create config template: \config/arena_definitions/new_paradigm_template.yml\
4. Create workflow: \workflows/run_new_paradigm.R\
5. Add tests: \	ests/testthat/test_new_paradigm.R\
6. Document in paradigm-specific guide

### Adding a New Data Source

1. Add reader to \R/core/data_loading.R\:
   - \ead_<source>_format(file_path)\
2. Add converter to \R/core/data_converters.R\:
   - \convert_<source>_to_tracking_data(data, config)\
3. Update \load_tracking_data()\ to support new source type
4. Add tests with example files
5. Document data source requirements

### Adding a New Metric

1. Determine if metric is:
   - **Generic**: Add to appropriate file in \R/metrics/\
   - **Paradigm-specific**: Add to paradigm module
2. Implement metric function following standard signature
3. Add to paradigm \calculate_<paradigm>_metrics()\ if appropriate
4. Add tests
5. Document metric calculation and interpretation

## Error Handling Strategy

### Levels of Error Handling

1. **Input Validation**: Check inputs early, fail fast
2. **Graceful Degradation**: Continue with warnings when possible
3. **Informative Messages**: Explain what went wrong and how to fix it
4. **Recovery Suggestions**: Suggest next steps or alternatives

### Example Error Handling

\\\
load_tracking_data <- function(file_path, source_type = NULL, ...) {
  # Validate inputs
  if (!file.exists(file_path)) {
    stop("File not found: ", file_path, 
         "\nPlease check the file path and try again.")
  }
  
  # Auto-detect source if not specified
  if (is.null(source_type)) {
    source_type <- detect_source_type(file_path)
    if (is.null(source_type)) {
      stop("Could not auto-detect data source type for: ", file_path,
           "\nPlease specify source_type explicitly.",
           "\nSupported types: ", paste(supported_types(), collapse=", "))
    }
    message("Auto-detected source type: ", source_type)
  }
  
  # Try to load with informative errors
  tryCatch(
    {
      # Loading logic...
    },
    error = function(e) {
      stop("Failed to load tracking data from ", file_path,
           "\nError: ", conditionMessage(e),
           "\nSource type: ", source_type,
           "\nPlease check the file format matches the source type.")
    }
  )
}
\\\

## Performance Considerations

### Optimization Priorities

1. **Correctness first**: Get it right before making it fast
2. **Profile before optimizing**: Measure to find bottlenecks
3. **Vectorize operations**: Use R's vector operations
4. **Avoid copies**: Work in place when possible
5. **Cache expensive computations**: Store reusable results

### Expected Bottlenecks

- **Large dataset loading**: Consider chunked reading
- **Zone calculations**: Vectorize point-in-polygon tests
- **Smoothing operations**: Use efficient implementations
- **Visualization**: Downsample for plotting if needed

### Memory Management

- Use data.table for very large datasets (>1M rows)
- Clear large intermediate objects
- Process files in batches if needed
- Monitor memory with periodic checks

## Testing Strategy

### Test Pyramid

\\\
                    +-------------+
                    ¦   Manual    ¦  (Minimal)
                    ¦   Testing   ¦
                    +-------------+
                +---------------------+
                ¦   Integration       ¦
                ¦   Tests             ¦
                +---------------------+
          +-------------------------------+
          ¦     Unit Tests               ¦  (Most tests)
          +-------------------------------+
\\\

### Test Types

1. **Unit Tests**: Test individual functions in isolation
2. **Integration Tests**: Test workflows end-to-end
3. **Regression Tests**: Ensure results match legacy implementation
4. **Validation Tests**: Compare to known ground truth

### Test Data

- Keep test datasets small (<100 frames)
- Create synthetic data for edge cases
- Include real data samples for validation
- Document expected results

## Documentation Standards

### Code Documentation (Roxygen2)

\\\
#' Brief description (one line)
#'
#' Detailed description (multiple lines if needed).
#' Explain what the function does, not how it does it.
#'
#' @param param_name Description of parameter
#' @param another_param Description with details about format, range, etc.
#'
#' @return Description of return value, including structure and type
#'
#' @examples
#' # Example 1: Basic usage
#' result <- function_name(param = value)
#'
#' # Example 2: Advanced usage
#' result <- function_name(param1 = value1, param2 = value2)
#'
#' @seealso \code{\link{related_function}}
#'
#' @export
function_name <- function(param_name, another_param = default) {
  # Implementation
}
\\\

### User Documentation

- **README**: Quick start and overview
- **Vignettes**: Tutorial-style guides for each paradigm
- **API Reference**: Generated from roxygen2
- **Configuration Guide**: Detailed configuration documentation
- **Migration Guide**: Help for existing users

---

**Document Version**: 1.0  
**Last Updated**: 2024  
**Status**: ACTIVE
