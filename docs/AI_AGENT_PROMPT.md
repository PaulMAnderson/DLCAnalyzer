# AI Agent Starting Prompt for DLCAnalyzer Refactoring

## Copy and paste this prompt to start a new AI session:

---

Hello! I need your help refactoring the DLCAnalyzer R package. This is a behavioral analysis tool for processing animal tracking data from DeepLabCut and other sources.

**Project Location**: `G:\Bella\Rebecca\Code\DLCAnalyzer`

**Your Task**: Help implement a comprehensive refactoring to transform this from a monolithic codebase into a modular, flexible behavioral analysis framework.

## Getting Started

### Step 1: Read the Planning Documents

All planning documents are located in the `docs/` folder. Please start by reading them in this order:

1. **First, read**: `docs/README.md` 
   - This gives you an overview of all documentation and how to use it

2. **Then read**: `docs/REFACTORING_PLAN.md`
   - Understand the project goals, current state, and target architecture
   - Review the 5-phase migration strategy

3. **Then read**: `docs/REFACTORING_TODO.md`
   - This contains the detailed task list you'll be executing
   - Each task has clear acceptance criteria and dependencies
   - You'll update task statuses as you complete work

4. **Keep handy**: `docs/ARCHITECTURE.md`
   - Reference this for architectural decisions
   - Contains design patterns and data structures
   - Shows module dependencies

5. **Keep handy**: `docs/EXAMPLE_CONFIGS.md`
   - Reference for YAML configuration format
   - Contains templates for all paradigms

### Step 2: Understand the Current State

**✓ PHASE 1 COMPLETE!**

The project has completed Phase 1 (Foundation). Current status:
- **Legacy code**: Preserved in `R/legacy/DLCAnalyzer_Functions_final.R`
- **Modular structure**: New directory structure created
- **Core modules**: Data structures, loading, converters, config utils implemented
- **Testing**: 64 unit tests passing, 2 integration tests, validated with real EPM data
- **Example data**: Located in `data/` directory (EPM, OFT, FST folders)

### Step 3: Continue Implementation

**Start with Phase 2, Task 2.1** from `docs/REFACTORING_TODO.md`:
- Extract and refactor preprocessing functions
- Implement likelihood filtering, interpolation, smoothing
- Write comprehensive unit tests

**What's Already Complete (Phase 1)**:
- ✓ Task 1.1: Directory structure setup
- ✓ Task 1.2: tracking_data S3 class defined
- ✓ Task 1.3: DLC data loading functions
- ✓ Task 1.4: DLC to internal format converter
- ✓ Task 1.5: Basic configuration system (YAML)
- ✓ Task 1.6: Testing framework setup

**Important**:
- Complete tasks in order (they have dependencies)
- Update task statuses in `docs/REFACTORING_TODO.md` as you work
- Follow the acceptance criteria for each task
- Write tests for all new code (target >80% coverage)
- Document all functions with roxygen2

### Step 4: Key Principles to Follow

From `docs/ARCHITECTURE.md`:

1. **Standardized Internal Format**: All data sources convert to `tracking_data` S3 class
2. **Configuration Cascade**: System defaults ? Templates ? User config ? Function args  
3. **Pipeline Pattern**: Load ? Preprocess ? Calculate ? Visualize ? Export
4. **Separation of Concerns**: Keep data, processing, metrics, paradigms, and visualization separate
5. **Validation at Boundaries**: Check inputs early, fail fast with informative errors

### Step 5: Task Workflow

For each task:
1. Mark status as `[>]` (In Progress) in `REFACTORING_TODO.md`
2. Implement the functionality following the task description
3. Write unit tests (target >80% coverage)
4. Add roxygen2 documentation
5. Verify acceptance criteria are met
6. Mark status as `[x]` (Completed)
7. Move to next task

### Step 6: Getting Help

If you encounter issues:
- Check the relevant planning document first
- Review legacy code in `R/DLCAnalyzer_Functions_final.R` for reference
- Look at example data in `example/` directory
- Flag unclear tasks with `[?]` status for human review
- Mark blocked tasks with `[!]` status and add notes

## What I Need From You

1. **Confirm you've read the planning documents** by summarizing:
   - The overall goal of the refactoring
   - What Phase 2 accomplishes
   - Current project status

2. **Then proceed with Phase 2, Task 2.1**: Extract Preprocessing Functions
   - Extract likelihood filtering from legacy code
   - Implement interpolation functions
   - Implement smoothing functions
   - Write comprehensive unit tests
   - Update the task status in `REFACTORING_TODO.md`

3. **Continue through Phase 2 tasks sequentially** (Tasks 2.1 through 2.7)

4. **Keep me updated** on progress and any blockers

## Testing Information

**R Environment**: Use the mamba environment at `/home/paul/miniforge3/envs/r`
- Activate with: `export PATH="/home/paul/miniforge3/envs/r/bin:$PATH"`
- Run tests with: `Rscript test_phase1.R` (integration test)
- Run unit tests with: `Rscript -e "library(testthat); test_file('tests/testthat/test_*.R')"`

**Test Files Available**:
- `test_phase1.R` - Phase 1 integration test (all tests passing)
- `test_real_data.R` - Real EPM DLC data test (15,080 frames, working perfectly)
- Unit tests in `tests/testthat/` (64 tests, all passing)

## Project Goals Reminder

We're transforming DLCAnalyzer to:
- Support multiple data sources (DLC, Ethovision, custom CSV)
- Remove hardcoded assumptions (maze points optional, flexible body parts)
- Enable multiple behavioral paradigms (OFT, EPM, NOR, LDB)
- Use YAML configuration for flexibility
- Maintain all existing functionality
- Provide clear documentation and examples

## Success Criteria

The refactoring is successful when:
- All 4 paradigms work end-to-end
- >80% test coverage achieved
- All functions documented
- Configuration system operational
- Example workflows run successfully
- Legacy functionality preserved

## Ready?

Please start by reading `docs/README.md` and `docs/REFACTORING_PLAN.md`, then confirm your understanding before beginning implementation.

Let's build a robust, flexible behavioral analysis framework!

---

**Document Version**: 1.1
**Last Updated**: December 2024
**Status**: Phase 1 Complete - Ready for Phase 2
**Completion**: 6/28 tasks (21% of foundation work), 4% overall
