# Arena/Maze Configuration System - Implementation Status

**STATUS: ✅ IMPLEMENTED**
**Date Completed**: December 17, 2024
**Implementation**: See R/core/arena_config.R, R/core/zone_geometry.R, R/core/coordinate_transforms.R

## Overview

This document outlines the design for the arena/maze configuration system that allows users to define experimental environments using reference points from images, and specify zones using either polygon mappings or proportional definitions.

**The system has been fully implemented and tested with the existing arena configuration files.**

## Use Cases

### Primary Use Case: DLC Data (Pixel Coordinates)
- User has tracking data in pixels from DeepLabCut
- User has a reference image of the arena/maze
- User needs to define:
  1. Reference points on the maze (e.g., corners, arm endpoints)
  2. Real-world scale (pixels → cm conversion)
  3. Zones for behavioral analysis (center, arms, periphery, etc.)

### Secondary Use Case: Ethovision Data (Already in cm)
- Data already in cm units
- May still need zone definitions
- Can skip pixel-to-cm conversion

## Configuration Architecture

### 1. Point-Based Arena Definition

Users will define **reference points** that describe the maze structure.

#### Example: Elevated Plus Maze
```yaml
arena_definition:
  name: "Elevated Plus Maze"
  paradigm: "epm"

  # Reference image for point selection
  reference_image: "path/to/arena_image.png"

  # Named reference points (in pixels, selected from image)
  reference_points:
    center: {x: 512, y: 384}
    north_arm_end: {x: 512, y: 100}
    south_arm_end: {x: 512, y: 668}
    east_arm_end: {x: 812, y: 384}
    west_arm_end: {x: 212, y: 384}

  # Scale calibration (real-world distance between two points)
  calibration:
    point1: "center"
    point2: "north_arm_end"
    real_distance_cm: 25.0  # Distance in cm

  # Derived measurements (optional, calculated from points)
  dimensions:
    arm_length_cm: 25.0
    arm_width_cm: 5.0
    center_size_cm: 5.0
```

### 2. Zone Definition Methods

#### Method A: Polygon Zones (Point References)
Define zones by connecting reference points:

```yaml
zones:
  # Rectangular zones defined by opposite corners
  - name: "north_open_arm"
    type: "rectangle"
    paradigm_role: "open_arm"
    points: ["center", "north_arm_end"]
    width_cm: 5.0  # Width perpendicular to length

  # Polygonal zones defined by multiple points
  - name: "center_zone"
    type: "polygon"
    paradigm_role: "center"
    points: ["center_north", "center_east", "center_south", "center_west"]

  # Circular zones
  - name: "object_interaction_zone"
    type: "circle"
    paradigm_role: "object_zone"
    center_point: "object_location"
    radius_cm: 5.0
```

#### Method B: Proportional Zones
Define zones as proportions of the arena:

```yaml
zones:
  # For Open Field Test
  - name: "center"
    type: "proportional_rectangle"
    paradigm_role: "center"
    center_proportion: 0.5  # 50% of arena dimensions
    # Creates rectangle with width = 0.5 * arena_width, height = 0.5 * arena_height

  - name: "periphery"
    type: "inverse"
    paradigm_role: "periphery"
    exclude_zones: ["center"]  # Everything except center

  # For circular arenas
  - name: "center_circle"
    type: "proportional_circle"
    paradigm_role: "center"
    center: {x: 0.5, y: 0.5}  # Proportional coordinates (0-1)
    radius_proportion: 0.3  # 30% of arena radius
```

### 3. Configuration File Structure

Full YAML configuration example:

```yaml
# config/arena_definitions/my_epm_arena.yml

metadata:
  paradigm: "elevated_plus_maze"
  experimenter: "John Doe"
  date_created: "2024-12-17"
  description: "EPM maze for anxiety testing, 4 arms + center"

# Reference image and points
reference:
  image: "images/epm_reference.png"
  image_dimensions: {width: 1024, height: 768}  # pixels

  # Named points in pixel coordinates
  points:
    center: {x: 512, y: 384}
    north_end: {x: 512, y: 100}
    south_end: {x: 512, y: 668}
    east_end: {x: 812, y: 384}
    west_end: {x: 212, y: 384}

  # Scale calibration
  scale:
    method: "two_point"  # or "known_dimension"
    point1: "center"
    point2: "north_end"
    real_distance_cm: 25.0
    # Calculated: pixels_per_cm = distance_pixels / distance_cm

# Zone definitions
zones:
  - name: "north_arm"
    type: "rectangle"
    role: "open_arm"
    center_line: ["center", "north_end"]
    width_cm: 5.0

  - name: "south_arm"
    type: "rectangle"
    role: "open_arm"
    center_line: ["center", "south_end"]
    width_cm: 5.0

  - name: "east_arm"
    type: "rectangle"
    role: "closed_arm"
    center_line: ["center", "east_end"]
    width_cm: 5.0

  - name: "west_arm"
    type: "rectangle"
    role: "closed_arm"
    center_line: ["center", "west_end"]
    width_cm: 5.0

  - name: "center_platform"
    type: "circle"
    role: "center"
    center_point: "center"
    radius_cm: 2.5

# Optional: Behavioral metrics specific to this arena
metrics:
  primary:
    - "time_in_open_arms"
    - "time_in_closed_arms"
    - "open_arm_entries"
  secondary:
    - "center_time"
    - "arm_transitions"
```

## Code Components Needed

### 1. Data Structures (R/core/arena_config.R)

```r
# S3 class for arena configuration
arena_config <- list(
  metadata = list(...),
  reference = list(
    image = "path/to/image.png",
    points = data.frame(name, x, y),
    scale = list(pixels_per_cm = 10.5)
  ),
  zones = list(
    zone1 = list(type, role, geometry, ...),
    zone2 = ...
  )
)
class(arena_config) <- c("arena_config", "list")
```

### 2. Configuration Loader (R/utils/arena_config_loader.R)

```r
#' Load arena configuration from YAML
load_arena_config <- function(config_file) {
  # Read YAML
  # Validate structure
  # Create arena_config object
  # Return validated config
}

#' Validate arena configuration
validate_arena_config <- function(config) {
  # Check required fields
  # Validate point definitions
  # Validate zone definitions
  # Check for logical consistency
}
```

### 3. Coordinate Transformation (R/core/coordinate_transforms.R)

```r
#' Calculate pixels per cm from calibration
calculate_scale <- function(point1, point2, real_distance_cm) {
  pixel_distance <- sqrt((p2$x - p1$x)^2 + (p2$y - p1$y)^2)
  pixels_per_cm <- pixel_distance / real_distance_cm
  return(pixels_per_cm)
}

#' Transform pixel coordinates to cm
transform_pixels_to_cm <- function(tracking_data, arena_config) {
  scale <- arena_config$reference$scale$pixels_per_cm
  tracking_data$x <- tracking_data$x / scale
  tracking_data$y <- tracking_data$y / scale
  return(tracking_data)
}
```

### 4. Zone Geometry (R/core/zone_geometry.R)

```r
#' Create zone geometry from configuration
create_zone_geometry <- function(zone_config, reference_points, scale) {
  switch(zone_config$type,
    "rectangle" = create_rectangle_zone(...),
    "polygon" = create_polygon_zone(...),
    "circle" = create_circle_zone(...),
    "proportional_rectangle" = create_proportional_rectangle(...)
  )
}

#' Check if point is in zone
point_in_zone <- function(x, y, zone_geometry) {
  # Implement point-in-polygon test
  # Return TRUE/FALSE
}
```

### 5. Interactive Point Selection Tool (Optional - R Shiny or Python)

For future enhancement: GUI tool to:
- Load arena image
- Click to select reference points
- Preview zone definitions
- Export YAML configuration

Could be implemented as:
- R Shiny app: `R/tools/arena_point_selector.R`
- Python script: `tools/select_arena_points.py`
- Or manual: User selects points in image viewer and enters coordinates

## User Workflow

### Step 1: Prepare Reference Image
- Take photo/screenshot of empty arena
- Save as PNG/JPEG

### Step 2: Select Reference Points
Option A (Manual):
- Open image in any image viewer
- Note pixel coordinates of key points
- Write YAML configuration file

Option B (Interactive - future):
- Run point selection tool
- Click points on image
- Tool generates YAML automatically

### Step 3: Define Zones
- Edit YAML to add zone definitions
- Either reference points or use proportions
- Specify paradigm-specific roles

### Step 4: Validate Configuration
```r
config <- load_arena_config("my_arena.yml")
validate_arena_config(config)
plot_arena_config(config)  # Visual preview
```

### Step 5: Use in Analysis
```r
tracking_data <- load_tracking_data(
  "dlc_output.csv",
  arena_config = "my_arena.yml",
  fps = 30,
  paradigm = "epm"
)
# Automatically applies coordinate transformation and zone definitions
```

## Implementation Status

### ✅ Phase 1: Core Configuration System (COMPLETED)
1. ✅ Define arena_config S3 class structure
2. ✅ Implement YAML loader with validation
3. ✅ Implement pixel-to-cm transformation
4. ✅ Basic zone geometry (rectangle, circle, polygon)

### ✅ Phase 2: Zone Analysis Integration (COMPLETED)
5. ✅ Point-in-zone detection (ray-casting algorithm for polygons, distance for circles)
6. ⏳ Zone transition detection (TO DO - Phase 2 Task 2.6)
7. ⏳ Integration with paradigm modules (TO DO - Phase 3)

### ✅ Phase 3: Advanced Features (COMPLETED)
8. ✅ Proportional zone definitions (supports values >1 for expansion)
9. ✅ Complex polygon zones with dependency resolution
10. ⏳ Interactive point selection tool (optional - future enhancement)

## Testing Strategy

### Unit Tests
- YAML parsing and validation
- Coordinate transformations (known conversions)
- Zone geometry calculations
- Point-in-polygon algorithms

### Integration Tests
- Load real DLC data with arena config
- Apply transformations
- Verify zones are correctly defined
- Check behavioral metrics

### Validation Data
- Create test arenas with known dimensions
- Simulate tracking data with known paths
- Verify calculated metrics match expected values

## Example Configurations to Create

1. **Elevated Plus Maze** (EPM)
2. **Open Field Test** (OFT) - rectangular and circular variants
3. **Novel Object Recognition** (NORT) - with object locations
4. **Light-Dark Box** (LDB)
5. **T-Maze / Y-Maze**
6. **Barnes Maze**

## File Organization

```
config/
  arena_definitions/
    examples/
      epm_standard.yml
      oft_rectangular.yml
      oft_circular.yml
      nort_standard.yml
      ldb_standard.yml
    user/
      my_epm_2024.yml
      ...

images/
  arena_references/
    epm_reference.png
    oft_reference.png
    ...
```

## Notes for Implementation

1. **Coordinate Systems**:
   - Image coordinates: (0,0) at top-left
   - Arena coordinates: May need origin transformation
   - Consider allowing user to specify origin location

2. **Scale Validation**:
   - Allow multiple calibration methods
   - Validate scale is consistent across points
   - Warning if scale seems unreasonable

3. **Zone Overlap**:
   - Detect and warn about overlapping zones
   - Allow intentional overlaps (e.g., hierarchical zones)

4. **Backwards Compatibility**:
   - Support both new config system and old hardcoded approach
   - Gradual migration path

5. **Documentation**:
   - Clear examples for each paradigm
   - Troubleshooting guide
   - Best practices for reference images

---

**Document Version**: 1.0
**Date**: December 17, 2024
**Status**: Planning - Ready for Implementation
