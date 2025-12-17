# Example Configuration Files

This document provides example configuration files for different paradigms and use cases.

## Table of Contents

1. [Open Field Test Configuration](#open-field-test)
2. [Elevated Plus Maze Configuration](#elevated-plus-maze)
3. [Novel Object Recognition Configuration](#novel-object-recognition)
4. [Light-Dark Box Configuration](#light-dark-box)
5. [Preprocessing Parameters](#preprocessing-parameters)
6. [Custom Body Part Mapping](#custom-body-part-mapping)

---

## Open Field Test

### Basic Configuration

**File**: \config/arena_definitions/open_field_basic.yml\

\\\yaml
# Open Field Test - Basic Configuration
arena_name: "standard_open_field"
paradigm: "open_field"
version: "1.0"

# Arena physical dimensions
dimensions:
  width: 500                    # pixels or cm
  height: 500
  units: "pixels"               # or "cm"

# Reference points (corners) - OPTIONAL
# These can be tracked or manually defined
reference_points:
  enabled: false                # Set to true if tracking maze corners
  detection_method: "tracked"   # "tracked" or "manual"
  points:
    - name: "top_left"
      abbreviation: "tl"
      role: "corner"
    - name: "top_right"
      abbreviation: "tr"
      role: "corner"
    - name: "bottom_left"
      abbreviation: "bl"
      role: "corner"
    - name: "bottom_right"
      abbreviation: "br"
      role: "corner"

# Zone definitions
zones:
  # Center zone (typically 50% of arena)
  - name: "center"
    type: "rectangle"
    definition:
      method: "proportion"      # proportion of total arena
      x_min: 0.25               # 25% from left
      x_max: 0.75               # 75% from left  
      y_min: 0.25               # 25% from top
      y_max: 0.75               # 75% from top
    metrics:
      time_in_zone: true
      entries: true
      latency: true
  
  # Periphery zone (inverse of center)
  - name: "periphery"
    type: "inverse"
    definition:
      method: "inverse"
      reference_zone: "center"
    metrics:
      time_in_zone: true
      entries: true
  
  # Corner zones
  - name: "corner_tl"
    type: "rectangle"
    definition:
      method: "proportion"
      x_min: 0.0
      x_max: 0.15
      y_min: 0.0
      y_max: 0.15
    metrics:
      time_in_zone: true
  
  - name: "corner_tr"
    type: "rectangle"
    definition:
      method: "proportion"
      x_min: 0.85
      x_max: 1.0
      y_min: 0.0
      y_max: 0.15
    metrics:
      time_in_zone: true
  
  - name: "corner_bl"
    type: "rectangle"
    definition:
      method: "proportion"
      x_min: 0.0
      x_max: 0.15
      y_min: 0.85
      y_max: 1.0
    metrics:
      time_in_zone: true
  
  - name: "corner_br"
    type: "rectangle"
    definition:
      method: "proportion"
      x_min: 0.85
      x_max: 1.0
      y_min: 0.85
      y_max: 1.0
    metrics:
      time_in_zone: true

# Body part configuration
body_parts:
  primary_tracking_point: "bodycentre"    # Main point for analysis
  required_points:
    - "bodycentre"
  optional_points:
    - "nose"
    - "tailbase"
    - "headcentre"
  point_groups:
    head: ["nose", "headcentre", "neck"]
    body: ["bodycentre", "bcl", "bcr"]
    tail: ["tailbase", "tailcentre", "tailtip"]

# Paradigm-specific metrics
metrics:
  thigmotaxis:
    enabled: true
    periphery_zone: "periphery"
  
  center_exploration:
    enabled: true
    center_zone: "center"
  
  corner_preference:
    enabled: true
    corner_zones: ["corner_tl", "corner_tr", "corner_bl", "corner_br"]
\\\

---

## Elevated Plus Maze

### Standard Configuration

**File**: \config/arena_definitions/epm_standard.yml\

\\\yaml
# Elevated Plus Maze - Standard Configuration
arena_name: "standard_epm"
paradigm: "elevated_plus_maze"
version: "1.0"

# Arena physical dimensions
dimensions:
  width: 800
  height: 800
  units: "pixels"
  
  # EPM-specific measurements
  arm_length: 300               # pixels
  arm_width: 80                 # pixels
  center_size: 80               # pixels x pixels

# Reference points - crucial for EPM
reference_points:
  enabled: true
  detection_method: "tracked"
  points:
    - name: "left_tip"
      abbreviation: "lt"
      role: "arm_end"
    - name: "right_tip"
      abbreviation: "rt"
      role: "arm_end"
    - name: "top_tip"
      abbreviation: "tt"
      role: "arm_end"
    - name: "bottom_tip"
      abbreviation: "bt"
      role: "arm_end"
    - name: "center_tl"
      abbreviation: "ctl"
      role: "center_corner"
    - name: "center_tr"
      abbreviation: "ctr"
      role: "center_corner"
    - name: "center_bl"
      abbreviation: "cbl"
      role: "center_corner"
    - name: "center_br"
      abbreviation: "cbr"
      role: "center_corner"

# Zone definitions
zones:
  # Center platform
  - name: "center"
    type: "rectangle"
    definition:
      method: "reference_points"
      points: ["ctl", "ctr", "cbl", "cbr"]
    metrics:
      time_in_zone: true
      entries: true
  
  # Open arm - Left
  - name: "open_left"
    type: "rectangle"
    definition:
      method: "reference_points"
      points: ["lt", "cbl", "ctl"]
    arm_type: "open"
    metrics:
      time_in_zone: true
      entries: true
      latency: true
  
  # Open arm - Right
  - name: "open_right"
    type: "rectangle"
    definition:
      method: "reference_points"
      points: ["rt", "cbr", "ctr"]
    arm_type: "open"
    metrics:
      time_in_zone: true
      entries: true
      latency: true
  
  # Closed arm - Top
  - name: "closed_top"
    type: "rectangle"
    definition:
      method: "reference_points"
      points: ["tt", "ctl", "ctr"]
    arm_type: "closed"
    metrics:
      time_in_zone: true
      entries: true
  
  # Closed arm - Bottom
  - name: "closed_bottom"
    type: "rectangle"
    definition:
      method: "reference_points"
      points: ["bt", "cbl", "cbr"]
    arm_type: "closed"
    metrics:
      time_in_zone: true
      entries: true

# Aggregate zone groups
zone_groups:
  open_arms: ["open_left", "open_right"]
  closed_arms: ["closed_top", "closed_bottom"]
  all_arms: ["open_left", "open_right", "closed_top", "closed_bottom"]

# Body part configuration
body_parts:
  primary_tracking_point: "bodycentre"
  required_points:
    - "bodycentre"
  optional_points:
    - "nose"
    - "headcentre"
    - "tailbase"

# Paradigm-specific metrics
metrics:
  open_arm_preference:
    enabled: true
    open_zones: ["open_left", "open_right"]
    closed_zones: ["closed_top", "closed_bottom"]
  
  arm_entries:
    enabled: true
    minimum_body_proportion: 0.5  # 50% of body must enter
  
  head_dipping:
    enabled: true                 # Requires nose or headcentre tracking
    tracking_point: "nose"
    arm_edge_distance: 20         # pixels from arm edge
  
  risk_assessment:
    enabled: true
    stretch_attend_threshold: 50  # pixel distance from body to head
  
  anxiety_index:
    enabled: true
    formula: "time_open / (time_open + time_closed)"
\\\

---

## Novel Object Recognition

### Two-Object Configuration

**File**: \config/arena_definitions/nor_two_object.yml\

\\\yaml
# Novel Object Recognition - Two Object Configuration
arena_name: "nor_two_object"
paradigm: "novel_object_recognition"
version: "1.0"

# Arena physical dimensions
dimensions:
  width: 500
  height: 500
  units: "cm"

# Reference points (optional)
reference_points:
  enabled: false

# Zone definitions
zones:
  # Exploration arena
  - name: "arena"
    type: "rectangle"
    definition:
      method: "proportion"
      x_min: 0.0
      x_max: 1.0
      y_min: 0.0
      y_max: 1.0
  
  # Object 1 zone (familiar)
  - name: "object_1"
    type: "circle"
    definition:
      method: "absolute"
      center_x: 150               # cm from left
      center_y: 250               # cm from top
      radius: 50                  # cm
    object_type: "familiar"
    metrics:
      time_in_zone: true
      entries: true
      investigation_episodes: true
  
  # Object 2 zone (novel or familiar, depending on phase)
  - name: "object_2"
    type: "circle"
    definition:
      method: "absolute"
      center_x: 350
      center_y: 250
      radius: 50
    object_type: "novel"          # Or "familiar" for familiarization phase
    metrics:
      time_in_zone: true
      entries: true
      investigation_episodes: true

# Body part configuration
body_parts:
  primary_tracking_point: "nose"  # Nose tracking recommended for NOR
  required_points:
    - "nose"
  optional_points:
    - "headcentre"
    - "bodycentre"
  investigation_point: "nose"     # Point used to detect object interaction

# Paradigm-specific metrics
metrics:
  investigation_threshold:
    distance: 10                  # cm - max distance to count as investigation
    minimum_duration: 0.5         # seconds - minimum investigation bout
  
  discrimination_index:
    enabled: true
    formula: "(time_novel - time_familiar) / (time_novel + time_familiar)"
  
  preference_ratio:
    enabled: true
    novel_object: "object_2"
    familiar_object: "object_1"
  
  exploration_score:
    enabled: true
    total_investigation_time: true
    investigation_episodes: true

# Experimental phases
phases:
  familiarization:
    objects: ["object_1", "object_2"]
    object_types: ["familiar", "familiar"]
    duration: 600                 # seconds (10 minutes)
  
  test:
    objects: ["object_1", "object_2"]
    object_types: ["familiar", "novel"]
    duration: 300                 # seconds (5 minutes)
    delay_from_familiarization: 3600  # seconds (1 hour)
\\\

---

## Light-Dark Box

### Standard Configuration

**File**: \config/arena_definitions/ldb_standard.yml\

\\\yaml
# Light-Dark Box - Standard Configuration
arena_name: "standard_ldb"
paradigm: "light_dark_box"
version: "1.0"

# Arena physical dimensions
dimensions:
  width: 600                    # Total apparatus width
  height: 300                   # Apparatus depth
  units: "pixels"

# Compartment specifications
compartments:
  light:
    proportion: 0.67            # 2/3 of total width
    color: "white"
    illumination: "bright"
  
  dark:
    proportion: 0.33            # 1/3 of total width
    color: "black"
    illumination: "none"
  
  transition_zone:
    enabled: true
    width: 30                   # pixels - opening between compartments

# Reference points
reference_points:
  enabled: false

# Zone definitions
zones:
  # Light compartment
  - name: "light"
    type: "rectangle"
    definition:
      method: "proportion"
      x_min: 0.0
      x_max: 0.67
      y_min: 0.0
      y_max: 1.0
    compartment_type: "light"
    metrics:
      time_in_zone: true
      entries: true
      latency: true
  
  # Dark compartment
  - name: "dark"
    type: "rectangle"
    definition:
      method: "proportion"
      x_min: 0.67
      x_max: 1.0
      y_min: 0.0
      y_max: 1.0
    compartment_type: "dark"
    metrics:
      time_in_zone: true
      entries: true
      latency: true
  
  # Transition zone (doorway)
  - name: "transition"
    type: "rectangle"
    definition:
      method: "absolute"
      x_min: 370                # pixels
      x_max: 400
      y_min: 0
      y_max: 300
    compartment_type: "transition"
    metrics:
      time_in_zone: true
      entries: true

# Body part configuration
body_parts:
  primary_tracking_point: "bodycentre"
  required_points:
    - "bodycentre"
  optional_points:
    - "nose"
    - "tailbase"

# Paradigm-specific metrics
metrics:
  anxiety_index:
    enabled: true
    formula: "time_dark / total_time"
  
  transitions:
    enabled: true
    minimum_duration_in_zone: 1.0  # seconds
    count_partial_body: false      # Require full body entry
  
  light_avoidance:
    enabled: true
    latency_to_light: true
    time_in_light: true
  
  risk_assessment:
    enabled: true
    transition_zone_time: true
    head_pokes_to_light: true     # Requires nose tracking

# Starting position
starting_position:
  zone: "light"                   # Or "dark" depending on protocol
  center_subject: true
\\\

---

## Preprocessing Parameters

### Default Preprocessing Configuration

**File**: \config/analysis_parameters/default_preprocessing.yml\

\\\yaml
# Default Preprocessing Parameters
preprocessing:
  version: "1.0"
  
  # Likelihood filtering
  likelihood_threshold:
    enabled: true
    threshold: 0.9              # Remove points with likelihood < 0.9
    method: "hard"              # "hard" (remove) or "soft" (flag)
    apply_to: "all"             # "all" or list of specific body parts
  
  # Missing data interpolation
  interpolation:
    enabled: true
    method: "linear"            # "linear", "spline", "polynomial"
    max_gap: 5                  # frames - maximum gap to interpolate
    boundary_handling: "extrapolate"  # "extrapolate", "na", or "edge"
    apply_to: "all"
  
  # Trajectory smoothing
  smoothing:
    enabled: true
    method: "savitzky_golay"    # "savgol", "moving_average", "gaussian"
    
    # Savitzky-Golay parameters
    window_length: 11           # Must be odd number
    polyorder: 3                # Polynomial order
    
    # Alternative: Moving average parameters
    # window_length: 5
    
    # Alternative: Gaussian parameters
    # sigma: 2.0
    
    apply_to: "all"
    preserve_endpoints: true
  
  # Outlier detection
  outlier_detection:
    enabled: true
    method: "displacement"      # "displacement", "zscore", "iqr"
    threshold: 100              # pixels - max single-frame movement
    action: "flag"              # "flag", "remove", or "replace"
    replacement_method: "interpolate"  # If action is "replace"
  
  # Coordinate transformations
  transformations:
    # Pixel to cm conversion
    pixel_to_cm:
      enabled: false
      scale_factor: 0.1         # cm per pixel
      method: "constant"        # "constant" or "reference_points"
    
    # Coordinate centering
    center_coordinates:
      enabled: false
      reference_point: "center" # Point name or zone name
      center_x: true
      center_y: true
    
    # Rotation correction
    rotation:
      enabled: false
      angle: 0                  # degrees
      center: "arena_center"    # Point to rotate around

# Quality checks
quality_checks:
  enabled: true
  
  # Data completeness
  completeness:
    minimum_frames: 100
    minimum_proportion: 0.7     # 70% of frames must have valid data
  
  # Tracking quality
  tracking_quality:
    max_missing_consecutive: 10  # frames
    max_missing_proportion: 0.3  # 30% per body part
    min_average_likelihood: 0.8
  
  # Arena containment
  arena_check:
    enabled: true
    tolerance: 20               # pixels outside arena before warning
    action: "warn"              # "warn" or "error"
  
  # Reports
  generate_report: true
  report_format: "text"         # "text", "html", or "both"
  save_filtered_data: false
\\\

---

## Custom Body Part Mapping

### Mapping for Different DLC Models

**File**: \config/body_part_mappings.yml\

\\\yaml
# Body Part Mappings for Different DLC Models
# Use this when your DLC model uses different body part names

mappings:
  # Standard DLC mouse model (used by default)
  standard_mouse:
    bodycentre: "bodycentre"
    nose: "nose"
    headcentre: "headcentre"
    neck: "neck"
    tailbase: "tailbase"
    tailcentre: "tailcentre"
    tailtip: "tailtip"
  
  # Alternative naming convention
  alternative_mouse:
    bodycentre: "body_center"
    nose: "snout"
    headcentre: "head_center"
    neck: "neck_base"
    tailbase: "tail_root"
    tailcentre: "tail_mid"
    tailtip: "tail_end"
  
  # Minimal tracking (3-point)
  minimal_mouse:
    bodycentre: "center"
    nose: "front"
    tailbase: "back"
  
  # Custom model with additional points
  custom_detailed:
    bodycentre: "body_center"
    nose: "nose_tip"
    headcentre: "head_center"
    neck: "neck"
    shoulders: "shoulder_center"
    spine: "mid_spine"
    hips: "hip_center"
    tailbase: "tail_start"
    tailmid: "tail_middle"
    tailtip: "tail_tip"
    
# How to use a mapping:
# In your analysis script:
# config\ <- "alternative_mouse"
\\\

---

## Complete Analysis Configuration

### Example: Full Open Field Analysis

**File**: \my_experiment/oft_analysis_config.yml\

\\\yaml
# Complete Open Field Test Analysis Configuration
analysis_name: "My OFT Experiment"
experiment_date: "2024-01-15"
researcher: "Lab Member Name"

# Data source
data:
  source_type: "deeplabcut"
  file_pattern: "*.csv"
  directory: "data/raw/oft/"
  fps: 30                       # Frames per second
  recording_duration: 600       # seconds (10 minutes)

# Import arena configuration
arena_config: "config/arena_definitions/open_field_basic.yml"

# Import preprocessing configuration
preprocessing_config: "config/analysis_parameters/default_preprocessing.yml"

# Override specific preprocessing settings
preprocessing_overrides:
  likelihood_threshold:
    threshold: 0.95             # More stringent than default
  smoothing:
    window_length: 7            # Smaller window

# Subject information
subjects:
  - id: "mouse_001"
    group: "control"
    sex: "male"
    age_weeks: 8
    weight_g: 25.3
  
  - id: "mouse_002"
    group: "treatment"
    sex: "male"
    age_weeks: 8
    weight_g: 24.8

# Analysis parameters
analysis:
  time_bins:
    enabled: true
    bin_size: 60                # seconds (1-minute bins)
  
  metrics_to_calculate:
    - "total_distance"
    - "average_velocity"
    - "time_in_center"
    - "center_entries"
    - "thigmotaxis_index"
    - "corner_time"
  
  body_part_for_analysis: "bodycentre"

# Visualization
visualization:
  trajectory_plot:
    enabled: true
    color_by: "velocity"
    show_zones: true
  
  heatmap:
    enabled: true
    resolution: 50              # 50x50 grid
    type: "occupancy"
  
  summary_plots:
    enabled: true
    group_by: "group"
    error_bars: "sem"           # "sem", "sd", or "ci95"

# Output
output:
  directory: "results/oft_analysis/"
  formats:
    csv: true
    rds: true
    plots: true
  
  report:
    enabled: true
    format: "html"
    include_quality_checks: true
    include_raw_data_summary: true
\\\

---

## Configuration Validation

When loading configurations, the system validates:

1. **Required fields are present**
2. **Data types are correct** (numeric, character, logical, etc.)
3. **Values are within valid ranges**
4. **Referenced files exist** (for file paths)
5. **Body parts match available tracking data**
6. **Zone definitions are geometrically valid**
7. **Metric parameters are compatible**

Example validation errors:

\\\
Error: Invalid configuration file 'my_config.yml'
  - zones[1].definition.x_min: Must be between 0 and 1 for proportional method (got -0.1)
  - body_parts.primary_tracking_point: 'bodycenter' not found in tracking data
    Did you mean: 'bodycentre'?
  - preprocessing.smoothing.window_length: Must be an odd number (got 10)
\\\

---

**Document Version**: 1.0  
**Last Updated**: 2024  
**Status**: REFERENCE
