# DLCAnalyzer Refactoring Plan

## Executive Summary

This document outlines the comprehensive refactoring plan for the DLCAnalyzer repository to transform it from a monolithic codebase into a modular, flexible behavioral analysis framework supporting multiple paradigms and data sources.

## Current State Assessment

### Existing Structure
- Single monolithic R script: `R/DLCAnalyzer_Functions_final.R` (29,143 tokens)
- Paradigm examples: OFT (Open Field Test), EPM (Elevated Plus Maze), FST (Forced Swim Test)
- Hardcoded assumptions about:
  - Maze tracking points being present in all recordings
  - Specific body part names (nose, headcentre, neck, etc.)
  - Fixed point configurations per paradigm
- Data format: DeepLabCut CSV exports with multi-level headers

### Key Issues to Address
1. **Hardcoded dependencies**: Assumes maze points are always tracked
2. **Inflexible body part mapping**: Specific body part names are hardcoded
3. **Limited data source support**: Only DLC CSV format currently supported
4. **Monolithic code**: All functionality in one large file
5. **Mixed concerns**: Data loading, processing, analysis, and visualization all intermingled

## Target Architecture

### Repository Structure
```
project-root/
├── R/
│   ├── core/
│   │   ├── data_loading.R          # Import functions for all data types
│   │   ├── data_converters.R       # Convert external formats to internal format
│   │   ├── preprocessing.R         # Filtering, interpolation, smoothing
│   │   ├── coordinate_transforms.R # Coordinate system conversions
│   │   └── quality_checks.R        # Data quality assessment
│   ├── paradigms/
│   │   ├── open_field.R            # Open Field Test specific logic
│   │   ├── novel_object.R          # Novel Object Recognition
│   │   ├── elevated_plus_maze.R    # EPM specific logic
│   │   └── light_dark_box.R        # Light-Dark Box test
│   ├── metrics/
│   │   ├── distance_speed.R        # Distance and velocity calculations
│   │   ├── zone_analysis.R         # Zone-based metrics
│   │   ├── time_in_zone.R          # Time in zone calculations
│   │   └── body_part_specific.R    # Body part-specific metrics
│   └── visualization/
│       ├── trajectory_plots.R      # Trajectory visualizations
│       ├── heatmaps.R              # Heatmap generation
│       └── summary_plots.R         # Summary statistics plots
├── config/
│   ├── arena_definitions/
│   │   ├── open_field_template.yml
│   │   ├── novel_object_template.yml
│   │   ├── elevated_plus_maze_template.yml
│   │   └── light_dark_box_template.yml
│   └── analysis_parameters/
│       ├── default_preprocessing.yml
│       ├── default_metrics.yml
│       └── paradigm_specific.yml
├── workflows/
│   ├── run_open_field.R
│   ├── run_novel_object.R
│   ├── run_epm.R
│   └── run_light_dark.R
├── utils/
│   ├── config_validation.R         # Validate configuration files
│   ├── logging.R                   # Logging utilities
│   └── helpers.R                   # General helper functions
├── tests/
│   ├── testthat/
│   │   ├── test_data_loading.R
│   │   ├── test_converters.R
│   │   ├── test_preprocessing.R
│   │   └── test_metrics.R
├── docs/
│   ├── REFACTORING_PLAN.md         # This file
│   ├── REFACTORING_TODO.md         # Detailed task list
│   ├── MIGRATION_GUIDE.md          # Guide for existing users
│   ├── API_REFERENCE.md            # Function documentation
│   └── CONFIGURATION_GUIDE.md      # How to configure experiments
├── data/
│   ├── raw/                        # Raw input data
│   └── examples/                   # Example datasets
└── outputs/                        # Analysis outputs
```

## Core Design Principles

### 1. Standardized Internal Data Format

All data sources (DLC, Ethovision, etc.) will be converted to a common internal format:

**Tracking Data Format:**
```r
# S3 class: tracking_data
list(
  metadata = list(
    source = "deeplabcut",          # Data source
    fps = 30,                        # Frames per second
    subject_id = "mouse_01",         # Subject identifier
    session_id = "session_20240101", # Session identifier
    paradigm = "open_field",         # Behavioral paradigm
    timestamp = Sys.time()           # Import timestamp
  ),
  
  tracking = data.frame(
    frame = 1:n,                     # Frame number
    time = seq(0, length.out=n, by=1/fps), # Time in seconds
    body_part = "bodycentre",        # Body part name
    x = numeric(n),                  # X coordinate
    y = numeric(n),                  # Y coordinate
    likelihood = numeric(n)          # Confidence (if available)
  ),
  
  arena = list(
    dimensions = list(
      width = 500,                   # Arena width in pixels or cm
      height = 500                   # Arena height in pixels or cm
    ),
    reference_points = data.frame(  # Optional reference points
      point_name = c("tl", "tr", "bl", "br"),
      x = c(...),
      y = c(...),
      likelihood = c(...)            # May be NA for manual points
    ),
    zones = list(...)                # Zone definitions (optional)
  ),
  
  config = list(...)                 # Paradigm-specific configuration
)
```

### 2. Flexible Configuration System

**Arena Definition Example (YAML):**
```yaml
arena_name: "open_field_standard"
paradigm: "open_field"

dimensions:
  width: 500
  height: 500
  units: "pixels"
  
reference_points:
  required: false  # Maze points are optional
  detection_method: "tracked"  # or "manual"
  points:
    - name: "top_left"
      abbreviation: "tl"
      role: "corner"
    - name: "top_right"
      abbreviation: "tr"
      role: "corner"

zones:
  - name: "center"
    type: "rectangle"
    definition:
      method: "proportion"  # or "absolute", "reference_points"
      x_min: 0.25
      x_max: 0.75
      y_min: 0.25
      y_max: 0.75
  
  - name: "periphery"
    type: "polygon"
    definition:
      method: "inverse"
      reference_zone: "center"

body_parts:
  primary_tracking_point: "bodycentre"  # Main point for analysis
  required_points:
    - "bodycentre"
  optional_points:
    - "nose"
    - "tailbase"
  point_groups:
    head: ["nose", "headcentre", "neck"]
    body: ["bodycentre", "bcl", "bcr"]
    tail: ["tailbase", "tailcentre", "tailtip"]
```

**Analysis Parameters Example (YAML):**
```yaml
preprocessing:
  likelihood_threshold: 0.9
  interpolation:
    enabled: true
    method: "linear"
    max_gap: 5  # frames
  smoothing:
    enabled: true
    method: "savitzky_golay"
    window_length: 11
    polyorder: 3
    
metrics:
  distance:
    enabled: true
    body_part: "bodycentre"
    units: "cm"
    
  velocity:
    enabled: true
    smoothing_window: 5
    
  time_in_zone:
    enabled: true
    zones: ["center", "periphery"]
    
  zone_transitions:
    enabled: true
    minimum_duration: 1.0  # seconds
```

### 3. Data Source Converters

Each data source gets its own converter to the internal format:

**Supported Formats:**
- DeepLabCut CSV exports (current)
- Ethovision XT Excel/CSV exports
- BORIS event logs (future)
- Custom CSV formats (user-defined)

**Converter Interface:**
```r
# Generic converter function signature
convert_to_tracking_data <- function(
  file_path,
  source_type = c("deeplabcut", "ethovision", "custom"),
  config = NULL,
  ...
) {
  # Returns: tracking_data object
}
```

### 4. Paradigm-Specific Modules

Each paradigm implements:
1. Zone definition helpers
2. Paradigm-specific metrics
3. Default configuration templates
4. Validation rules

**Common Interface:**
```r
# Each paradigm exports these functions:
- setup_<paradigm>_arena()
- validate_<paradigm>_config()
- calculate_<paradigm>_metrics()
- visualize_<paradigm>_results()
```

## Migration Strategy

### Phase 1: Foundation (Weeks 1-2)
1. Create new directory structure
2. Implement internal data format (S3 classes)
3. Extract and refactor data loading functions
4. Create DLC converter
5. Implement basic configuration system
6. Set up testing framework

### Phase 2: Core Functionality (Weeks 3-4)
1. Extract preprocessing functions
2. Implement coordinate transformation utilities
3. Create quality check functions
4. Develop common metrics (distance, speed, zones)
5. Build configuration validation

### Phase 3: Paradigm Implementation (Weeks 5-7)
1. Implement Open Field paradigm module
2. Implement Elevated Plus Maze module
3. Implement Novel Object Recognition module
4. Implement Light-Dark Box module
5. Create paradigm-specific configurations

### Phase 4: Additional Features (Weeks 8-9)
1. Implement Ethovision converter
2. Add custom CSV converter
3. Enhance visualization functions
4. Create workflow scripts
5. Build comprehensive examples

### Phase 5: Documentation & Testing (Week 10)
1. Complete API documentation
2. Write configuration guide
3. Create migration guide for existing users
4. Comprehensive testing
5. Performance optimization

## Backward Compatibility

### Maintaining Existing Functionality
- Keep original `DLCAnalyzer_Functions_final.R` in `R/legacy/` with deprecation warnings
- Provide wrapper functions that translate old API to new API
- Include migration examples in documentation

### Example Wrapper:
```r
# Legacy function wrapper
old_function_name <- function(...) {
  .Deprecated("new_function_name", 
              msg = "This function is deprecated. See migration guide.")
  # Call new implementation
  new_function_name(...)
}
```

## Testing Strategy

### Unit Tests
- Test each core function independently
- Validate data converters with example files
- Test configuration parsing and validation
- Verify metric calculations against known results

### Integration Tests
- Test complete workflows for each paradigm
- Verify pipeline from raw data to final outputs
- Test with multiple data sources

### Validation Tests
- Compare results with original implementation
- Validate against published behavioral metrics
- Cross-validate with manual scoring (where available)

## Documentation Requirements

### For Developers
- API reference for all public functions
- Architecture overview
- Contribution guidelines
- Code style guide

### For Users
- Quick start guide for each paradigm
- Configuration file templates and examples
- Troubleshooting guide
- Migration guide from old version

### For AI Agents
- Task breakdown with clear acceptance criteria
- Module dependencies diagram
- Function signature specifications
- Example usage for each function

## Success Criteria

### Functionality
- [ ] All original analysis capabilities preserved
- [ ] Four paradigms fully implemented
- [ ] DLC and Ethovision import working
- [ ] Configuration system operational
- [ ] All workflows executable

### Code Quality
- [ ] >80% test coverage
- [ ] All functions documented
- [ ] No circular dependencies
- [ ] Consistent naming conventions
- [ ] Proper error handling throughout

### Usability
- [ ] Clear configuration templates
- [ ] Working examples for each paradigm
- [ ] Migration path for existing users
- [ ] Comprehensive documentation

## Risk Assessment

### High Risk
1. **Breaking existing workflows**: Mitigation - maintain legacy wrappers
2. **Performance regression**: Mitigation - benchmark against original
3. **Configuration complexity**: Mitigation - provide simple defaults

### Medium Risk
1. **Incomplete paradigm coverage**: Mitigation - prioritize core paradigms
2. **Data converter edge cases**: Mitigation - comprehensive test datasets

### Low Risk
1. **Documentation gaps**: Mitigation - continuous documentation updates
2. **Testing overhead**: Mitigation - automate testing where possible

## Next Steps

1. Review and approve this plan
2. Create detailed task breakdown (see REFACTORING_TODO.md)
3. Set up project tracking system
4. Begin Phase 1 implementation

---

**Document Version**: 1.0  
**Last Updated**: 2024  
**Status**: DRAFT - Pending Approval
