# DLCAnalyzer Documentation

Welcome to the DLCAnalyzer documentation. This folder contains comprehensive planning and reference documents for the refactoring project.

## Planning Documents

### For Project Management

?? **[REFACTORING_PLAN.md](REFACTORING_PLAN.md)**
- Executive summary of the refactoring project
- Current state assessment
- Target architecture overview
- Migration strategy with 5 phases
- Success criteria and risk assessment
- **Read this first** for project overview

?? **[REFACTORING_TODO.md](REFACTORING_TODO.md)**
- Detailed task breakdown for AI agents
- ~150+ specific tasks across 5 phases
- Clear acceptance criteria for each task
- Dependencies and priorities
- Task status tracking
- **Use this for implementation** - contains specific instructions

### For Development

??? **[ARCHITECTURE.md](ARCHITECTURE.md)**
- System architecture diagrams
- Module dependency structure
- Core data structures
- Design patterns and principles
- Extension points for adding features
- Error handling and testing strategies
- **Essential reading for developers**

?? **[EXAMPLE_CONFIGS.md](EXAMPLE_CONFIGS.md)**
- Complete YAML configuration examples
- Templates for all paradigms:
  - Open Field Test
  - Elevated Plus Maze
  - Novel Object Recognition
  - Light-Dark Box
- Preprocessing parameter configurations
- Body part mapping examples
- **Reference for configuration format**

## Document Organization

\\\
docs/
+-- README.md                   (this file)
+-- REFACTORING_PLAN.md        (project overview & strategy)
+-- REFACTORING_TODO.md        (detailed task list)
+-- ARCHITECTURE.md            (technical architecture)
+-- EXAMPLE_CONFIGS.md         (configuration templates)
\\\

## Quick Start Guide for AI Agents

### Phase 1: Foundation (Start Here)

1. **Read**: REFACTORING_PLAN.md - Phase 1 section
2. **Consult**: ARCHITECTURE.md - Data Flow section
3. **Execute**: REFACTORING_TODO.md - Tasks 1.1 through 1.6
4. **Reference**: EXAMPLE_CONFIGS.md as needed for config structure

### Phase 2-5: Follow TODO Sequentially

For each phase:
1. Review phase goals in REFACTORING_PLAN.md
2. Execute tasks in REFACTORING_TODO.md in order
3. Consult ARCHITECTURE.md for design patterns
4. Use EXAMPLE_CONFIGS.md for configuration formats
5. Update task status in REFACTORING_TODO.md

## Key Design Principles

From ARCHITECTURE.md, remember:

1. **Standardized Internal Format**: All data sources convert to 	racking_data S3 class
2. **Configuration Cascade**: System defaults ? Templates ? User config ? Function args
3. **Pipeline Pattern**: Load ? Preprocess ? Calculate ? Visualize ? Export
4. **Validation at Boundaries**: Check inputs early, fail fast
5. **Separation of Concerns**: Data, processing, metrics, paradigms, and visualization are separate

## Configuration System

The system uses YAML configuration files organized in two categories:

### Arena Definitions
\config/arena_definitions/\
- Define physical arena layout
- Specify zones and reference points
- Configure paradigm-specific zones
- Example: \open_field_template.yml\

### Analysis Parameters  
\config/analysis_parameters/\
- Preprocessing settings
- Metric calculation parameters
- Quality check thresholds
- Example: \default_preprocessing.yml\

See EXAMPLE_CONFIGS.md for complete examples.

## Data Flow Overview

\\\
External Data ? Data Loaders ? Internal Format (tracking_data) ? Preprocessing ? 
Metrics Calculation ? Paradigm Analysis ? Visualization ? Export
\\\

Each stage is modular and can be customized through configuration.

## Testing Strategy

From ARCHITECTURE.md:

- **Unit Tests**: Individual function testing (~80% of tests)
- **Integration Tests**: End-to-end workflow testing
- **Regression Tests**: Validate against legacy implementation
- **Validation Tests**: Compare to known ground truth

Target: >80% code coverage

## Module Dependency Layers

`
Layer 8: Workflows         (run_*.R scripts)
Layer 7: Visualization     (trajectory, heatmaps, summaries)
Layer 6: Paradigms         (OFT, EPM, NOR, LDB)
Layer 5: Metrics           (distance, speed, zones, time)
Layer 4: Core Processing   (preprocessing, transforms, QC)
Layer 3: Data Import       (loading, converters)
Layer 2: Configuration     (config utils, validation)
Layer 1: Foundation        (data structures, helpers, logging)
\\\

Respect layer dependencies - higher layers can use lower layers, not vice versa.

## Current Status

**Project Status**: Planning Complete, Implementation Not Started  
**Next Step**: Begin Phase 1 - Task 1.1 (Directory Structure Setup)  
**Current Phase**: 0/5 Phases Complete

## Success Metrics

The refactoring will be considered successful when:

### Functionality
- [ ] All original analysis capabilities preserved
- [ ] Four paradigms fully implemented (OFT, EPM, NOR, LDB)
- [ ] DLC and Ethovision import working
- [ ] Configuration system operational
- [ ] All workflows executable end-to-end

### Code Quality
- [ ] >80% test coverage
- [ ] All functions documented with roxygen2
- [ ] No circular dependencies
- [ ] Consistent naming conventions
- [ ] Proper error handling throughout

### Usability
- [ ] Clear configuration templates for all paradigms
- [ ] Working examples for each paradigm
- [ ] Migration path for existing users
- [ ] Comprehensive documentation

## Getting Help

### For Understanding Architecture
? Read ARCHITECTURE.md sections on:
- Core Data Structure
- Design Patterns
- Module Dependencies

### For Implementation Details
? Consult REFACTORING_TODO.md for:
- Specific task requirements
- Acceptance criteria
- Code templates
- Testing checklists

### For Configuration Format
? Reference EXAMPLE_CONFIGS.md for:
- YAML structure examples
- Parameter descriptions
- Common configurations

### For Project Context
? Review REFACTORING_PLAN.md for:
- Why we're refactoring
- Migration strategy
- Risk assessment
- Timeline

## Document Maintenance

### Updating Documents

As implementation progresses:

1. **REFACTORING_TODO.md**:
   - Update task statuses [x], [>], [!], [?]
   - Add notes on blockers or issues
   - Update completion metrics

2. **ARCHITECTURE.md**:
   - Keep architecture diagrams current
   - Document any architectural decisions
   - Update examples if patterns change

3. **EXAMPLE_CONFIGS.md**:
   - Add new configuration examples
   - Update templates as features are added

4. **REFACTORING_PLAN.md**:
   - Generally stable, update only for major changes
   - Track phase completion

## Additional Documentation (To Be Created)

These documents will be created during Phase 5:

- \API_REFERENCE.md\ - Generated from roxygen2 documentation
- \CONFIGURATION_GUIDE.md\ - Comprehensive configuration guide for users
- \MIGRATION_GUIDE.md\ - Guide for users migrating from legacy code
- \TROUBLESHOOTING.md\ - Common issues and solutions
- \CONTRIBUTING.md\ - Guidelines for contributors

## Questions or Issues?

For AI agents working on this project:
- Check relevant planning document first
- Update TODO with blockers using [!] status
- Flag for human review using [?] status
- Add clarifying notes to task sections

For human reviewers:
- Review flagged [?] tasks
- Approve/reject architectural decisions
- Provide guidance on blocked [!] tasks
- Update planning documents as needed

---

**Last Updated**: December 2024  
**Project Phase**: Planning Complete  
**Ready for Implementation**: ? Yes  
**Lead Documents**: REFACTORING_PLAN.md, REFACTORING_TODO.md
