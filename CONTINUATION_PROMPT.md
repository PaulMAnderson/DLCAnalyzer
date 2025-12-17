# DLCAnalyzer - Arena Configuration System Implementation

## Session Status: Ready for Arena Configuration Development

**Last Session Completed**: Ethovision XT import functionality
**Next Task**: Implement arena/maze configuration system

---

## What Was Just Completed

### Ethovision XT Import Functionality ✅

Successfully implemented full support for Ethovision XT Excel file import:

1. **Data Loading** ([R/core/data_loading.R](R/core/data_loading.R:313-674))
   - `read_ethovision_excel()` - Single sheet reader with metadata extraction
   - `read_ethovision_excel_multi()` - Multi-animal file support
   - `parse_ethovision_data()` - Convert to internal format
   - `is_ethovision_excel()` - Auto-detection

2. **Data Conversion** ([R/core/data_converters.R](R/core/data_converters.R:373-582))
   - `convert_ethovision_to_tracking_data()` - Single animal
   - `convert_ethovision_multi()` - Batch conversion
   - Updated `load_tracking_data()` for auto-detection
   - Fixed arena dimension inference for negative coordinates

3. **Testing** ([test_ethovision.R](test_ethovision.R))
   - **26/26 tests passing (100%)**
   - Validated with OFT, NORT, and LD data
   - Multi-animal support tested (4 animals)
   - All paradigms working

**Key Features**:
- Handles Excel files with multiple sheets (one per animal/arena)
- Automatically extracts metadata (experiment, subject, trial info)
- Skips control sheets automatically
- Data already in centimeters (no conversion needed)
- Tracks 3 body parts: center, nose, tail

---

## Current Project State

### Completed (Phase 1 + Ethovision)
- ✅ Modular directory structure
- ✅ tracking_data S3 class with validation
- ✅ DLC CSV import
- ✅ **Ethovision XT Excel import**
- ✅ Configuration system (basic YAML support)
- ✅ Testing framework (64 unit tests + integration tests)
- ✅ Support for multiple data sources (DLC + Ethovision)

### Next: Arena Configuration System

**Goal**: Allow users to define experimental arenas/mazes using reference points from images, with zone definitions for behavioral analysis.

**Planning Document**: [docs/ARENA_CONFIGURATION_PLAN.md](docs/ARENA_CONFIGURATION_PLAN.md)

---

## Your Task: Implement Arena Configuration System

### Background

Users have two types of tracking data:
1. **DLC data**: In pixels - needs calibration to convert to cm
2. **Ethovision data**: Already in cm - just needs zone definitions

Both need **arena/maze configuration** to:
- Define reference points (corners, arm endpoints, etc.)
- Specify real-world scale (pixels → cm conversion)
- Define behavioral zones (center, arms, periphery, object locations, etc.)

### Implementation Approach

Users will create YAML configuration files that specify:

1. **Reference Points** (in pixels, from arena image)
   ```yaml
   reference_points:
     center: {x: 512, y: 384}
     north_arm_end: {x: 512, y: 100}
     east_arm_end: {x: 812, y: 384}
   ```

2. **Scale Calibration** (pixel → cm conversion)
   ```yaml
   calibration:
     point1: "center"
     point2: "north_arm_end"
     real_distance_cm: 25.0
   ```

3. **Zone Definitions** (two methods)
   - **Point-based**: Define zones using reference points (polygons, rectangles, circles)
   - **Proportional**: Define zones as proportions of arena (e.g., center = 50% of dimensions)

### Tasks to Complete

**Please read [docs/ARENA_CONFIGURATION_PLAN.md](docs/ARENA_CONFIGURATION_PLAN.md) for full details**, then:

1. **Core Configuration System**:
   - Create `arena_config` S3 class ([R/core/arena_config.R](R/core/arena_config.R))
   - Implement YAML loader with validation ([R/utils/arena_config_loader.R](R/utils/arena_config_loader.R))
   - Add coordinate transformation functions ([R/core/coordinate_transforms.R](R/core/coordinate_transforms.R))

2. **Zone Geometry**:
   - Implement zone creation from config ([R/core/zone_geometry.R](R/core/zone_geometry.R))
   - Point-in-polygon detection
   - Support rectangle, circle, polygon zones

3. **Integration**:
   - Integrate with `load_tracking_data()` to apply transformations
   - Update `tracking_data` to include arena configuration
   - Apply zone definitions to tracking data

4. **Testing**:
   - Unit tests for coordinate transformations
   - Tests for zone geometry calculations
   - Integration tests with real data

5. **Examples**:
   - Create example configurations for EPM, OFT, NORT, LDB
   - Provide templates in `config/arena_definitions/examples/`

### Important Notes

- **Start by reading** [docs/ARENA_CONFIGURATION_PLAN.md](docs/ARENA_CONFIGURATION_PLAN.md)
- User will provide example arena images and point coordinates
- Keep backwards compatibility - old code should still work
- Document all functions with roxygen2
- Write tests for everything
- Follow the existing code style

### File Locations

```
R/core/
  arena_config.R          (NEW - arena_config S3 class)
  zone_geometry.R         (NEW - zone creation and point-in-zone)
  coordinate_transforms.R (EXISTING - will be extended)

R/utils/
  arena_config_loader.R   (NEW - YAML loading and validation)

config/arena_definitions/
  examples/
    epm_standard.yml      (NEW - example configurations)
    oft_rectangular.yml
    nort_standard.yml
    ldb_standard.yml

tests/testthat/
  test_arena_config.R     (NEW - unit tests)
  test_zone_geometry.R    (NEW - geometry tests)
```

---

## Getting Started

1. **Read the planning document**:
   ```bash
   cat docs/ARENA_CONFIGURATION_PLAN.md
   ```

2. **Check current code**:
   - Review `R/core/data_structures.R` (tracking_data class)
   - Review `R/utils/config_utils.R` (existing YAML support)
   - Review `R/core/data_converters.R` (infer_arena_dimensions function)

3. **Start implementation**:
   - Begin with `arena_config` S3 class
   - Then YAML loader
   - Then coordinate transformations
   - Then zone geometry

4. **Test as you go**:
   ```bash
   export PATH="/home/paul/miniforge3/envs/r/bin:$PATH"
   Rscript test_your_new_tests.R
   ```

---

## Success Criteria

The arena configuration system is complete when:
- [  ] Users can define arenas via YAML configuration
- [  ] Point-based zone definitions work (polygons, rectangles, circles)
- [  ] Proportional zone definitions work
- [  ] Pixel-to-cm coordinate transformation works
- [  ] Zone membership detection works (point-in-zone)
- [  ] Integration with tracking_data is seamless
- [  ] Example configurations exist for all major paradigms
- [  ] Unit tests pass (>80% coverage)
- [  ] Integration tests work with real data
- [  ] Documentation is complete

---

## Questions to Ask if Unclear

- What format should the reference images be in?
- How should overlapping zones be handled?
- Should we support coordinate system transformations (origin relocation)?
- Do we need rotation/affine transformations?
- How to handle proportional zones in non-rectangular arenas?

---

## Useful Commands

```bash
# Activate R environment
export PATH="/home/paul/miniforge3/envs/r/bin:$PATH"

# Run tests
Rscript test_phase1.R
Rscript test_ethovision.R

# Load R functions for interactive testing
Rscript -e "source('R/core/data_structures.R'); source('R/core/data_loading.R')"
```

---

**Ready to begin!** Start by reading [docs/ARENA_CONFIGURATION_PLAN.md](docs/ARENA_CONFIGURATION_PLAN.md), then begin implementing the core configuration system.

Good luck! 🚀
