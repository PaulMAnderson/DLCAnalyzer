The repository in 'G:\Bella\Rebecca\Code\DLCAnalyzer' contains existing code to process deeplabcut output for various behavioural paradigms.  am adapting this code for my own purposes. I want to make several seperate use cases, where I handle different animal behavioural paradigms; Open Field, Novel Object Recognition, Elevated Plus Maze, Light Dark Box. I also want to completely refactor the code along these lines: 



Repository Structure

project-root/ ├── R/ │   ├── core/ │   │   ├── data_loading.R │   │   ├── preprocessing.R │   │   ├── coordinate_transforms.R │   │   └── quality_checks.R │   ├── paradigms/ │   │   ├── open_field.R │   │   ├── novel_object.R │   │   ├── elevated_plus_maze.R │   │   └── light_dark_box.R │   ├── metrics/ │   │   ├── distance_speed.R │   │   ├── zone_analysis.R │   │   ├── time_in_zone.R │   │   └── body_part_specific.R │   └── visualization/ │       ├── trajectory_plots.R │       ├── heatmaps.R │       └── summary_plots.R ├── config/ │   ├── arena_definitions.yml │   └── analysis_parameters.yml ├── workflows/ │   ├── run_open_field.R │   ├── run_novel_object.R │   ├── run_epm.R │   └── run_light_dark.R ├── tests/ ├── docs/ ├── data/ │   └── raw/ └── outputs/

Key Organizational Principles

1. Separate shared functionality from paradigm-specific code

core/ contains functions used across all paradigms (loading DLC output, filtering low-confidence points, coordinate transformations)

paradigms/ contains paradigm-specific logic (zone definitions, behavioral metrics unique to each test)

2. Use configuration files Rather than hardcoding arena dimensions or analysis parameters, use YAML or JSON configs that define zones, thresholds, and parameters for each paradigm. This makes your code more adaptable.

3. Create workflow scripts Each paradigm gets a top-level workflow script that orchestrates the analysis pipeline, making it clear how to run each analysis from start to finish.

4. Modularize metrics Common metrics (distance traveled, velocity, time in zones) go in metrics/. This promotes code reuse—open field and novel object tests might both calculate distance traveled.



Importantly the exisitng code often assumes there are tracking points in each recording for the maze, I want to remove this assumption and use more flexible configuration files. I also want to be able to import and convert other data types (Ethovision exports etc.) and process these all in the same way, so we need a common internal data format and conversion functions. We also need to be able to handle different tracked points than the hardcoded versions in the exisitng code. 



Can you help me plan the changes neccessary and create a structured approach to do so. Make sure to create some planning and todo documents that AI agents can use to track the process and continue as needed without the full context explained here